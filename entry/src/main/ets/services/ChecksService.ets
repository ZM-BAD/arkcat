/**
 * Spec 048 Checks 服务：PR check runs 全量（GraphQL）+ Actions job 步骤与重跑（REST）。
 * Actions 特有端点/字段（actions/jobs、enable_debug_logging）只在本适配层出现。
 */
import { ApiError, graphql, restGet, restPost, RawResponse } from './GitHttpClient';
import { Json, JsonMap } from '../utils/Json';
import { StatusCheckItem } from '../models/RepoSubModels';
import { JobDetail, RunInfo, mapRestJob, mapRestRun } from '../models/ChecksModels';

/** PR 头提交全量 checks（Checks 页数据源）：checkSuites→checkRuns + 经典 status contexts */
const PR_CHECKS_QUERY = `
query PrChecks($owner: String!, $name: String!, $number: Int!) {
  repository(owner: $owner, name: $name) {
    pullRequest(number: $number) {
      commits(last: 1) {
        nodes {
          commit {
            # status.contexts 是普通列表（非 connection：无 first/totalCount/nodes 包裹）
            status { contexts { context state targetUrl } }
            checkSuites(first: 30) {
              nodes {
                app { name logoUrl }
                checkRuns(first: 50) {
                  nodes { databaseId name status conclusion startedAt completedAt detailsUrl title }
                }
              }
            }
          }
        }
      }
    }
  }
}`;

/** REST 非 2xx → ApiError（语义码直透，页面按 friendlyError 分支） */
function ensureOk(resp: RawResponse): RawResponse {
  if (resp.code < 200 || resp.code >= 300) {
    throw new ApiError(resp.code, `GitHub REST HTTP ${resp.code}`);
  }
  return resp;
}

/** GraphQL 行 → 富行（state 归一口径同 rollup：conclusion 优先，缺省回落 status/context state） */
function mapCheckRow(key: string, name: string, state: string, node: JsonMap, appLogo: string): StatusCheckItem {
  return {
    key: key,
    name: name,
    state: state,
    checkRunId: Json.num(node, 'databaseId'),
    detailsUrl: Json.str(node, 'detailsUrl'),
    title: Json.str(node, 'title'),
    startedAt: Json.str(node, 'startedAt'),
    completedAt: Json.str(node, 'completedAt'),
    appLogo: appLogo
  };
}

/** PR 头提交全量 checks：先 check runs（带 App 图标），后经典 status contexts（无 job，不可进详情） */
export async function fetchPrChecks(token: string, owner: string, name: string,
  number: number): Promise<StatusCheckItem[]> {
  const vars: Record<string, Object> = { 'owner': owner, 'name': name, 'number': number };
  const data = await graphql(PR_CHECKS_QUERY, vars, token);
  const repo = Json.obj(data, 'repository');
  const pr = repo !== null ? Json.obj(repo, 'pullRequest') : null;
  const commits = pr !== null ? Json.obj(pr, 'commits') : null;
  const commitNodes = commits !== null ? Json.arr(commits, 'nodes') : [];
  if (commitNodes.length === 0) {
    return [];
  }
  const commit = (commitNodes[0] as JsonMap);
  const commitObj = Json.obj(commit, 'commit');
  const items: StatusCheckItem[] = [];
  if (commitObj === null) {
    return items;
  }
  // Actions / 外部 App check runs（suite 的 app 图标下发到每行）
  const suites = Json.obj(commitObj, 'checkSuites') ?? ({} as JsonMap);
  for (const suiteItem of Json.arr(suites, 'nodes')) {
    const suite = suiteItem as JsonMap;
    const app = Json.obj(suite, 'app');
    const appLogo = app !== null ? Json.str(app, 'logoUrl') : '';
    const runs = Json.obj(suite, 'checkRuns') ?? ({} as JsonMap);
    for (const runItem of Json.arr(runs, 'nodes')) {
      const node = runItem as JsonMap;
      const runName = Json.str(node, 'name');
      if (runName === '') {
        continue;
      }
      const conclusion = Json.str(node, 'conclusion');
      const state = conclusion !== '' ? conclusion : Json.str(node, 'status');
      items.push(mapCheckRow(`${runName}#${items.length}`, runName, state, node, appLogo));
    }
  }
  // 经典 commit status contexts：普通列表（非 connection）；无 databaseId（checkRunId=0 → 行不可进详情页）
  const status = Json.obj(commitObj, 'status');
  for (const ctxItem of Json.arr(status ?? ({} as JsonMap), 'contexts')) {
    const node = ctxItem as JsonMap;
    const ctxName = Json.str(node, 'context');
    if (ctxName === '') {
      continue;
    }
    items.push({
      key: `${ctxName}#${items.length}`,
      name: ctxName,
      state: Json.str(node, 'state'),
      checkRunId: 0,
      detailsUrl: Json.str(node, 'targetUrl'),
      title: '',
      startedAt: '',
      completedAt: '',
      appLogo: ''
    });
  }
  return items;
}

/** job 步骤详情；非 Actions 产出的 check run（外部 App）REST 404 → ApiError(404)，页面转空态 */
export async function fetchJob(token: string, owner: string, name: string, checkRunId: number): Promise<JobDetail> {
  const resp = ensureOk(await restGet(`/repos/${owner}/${name}/actions/jobs/${checkRunId}`, token));
  const raw = Json.parse(resp.body);
  if (raw === null) {
    throw new ApiError(0, 'Checks job: empty body');
  }
  return mapRestJob(raw);
}

/** workflow run 概要（弹层头部 `workflow 名 #run_number`；失败由页面降级为只显示 job 名） */
export async function fetchRunInfo(token: string, owner: string, name: string, runId: number): Promise<RunInfo> {
  const resp = ensureOk(await restGet(`/repos/${owner}/${name}/actions/runs/${runId}`, token));
  const raw = Json.parse(resp.body);
  if (raw === null) {
    throw new ApiError(0, 'Checks run: empty body');
  }
  return mapRestRun(raw);
}

/** 单 job 重跑（REST 无 body，2xx 即成功；无权限 → 403 由页面 toast） */
export async function rerunJob(token: string, owner: string, name: string, jobId: number): Promise<void> {
  ensureOk(await restPost(`/repos/${owner}/${name}/actions/jobs/${jobId}/rerun`, token, ''));
}

/** 全部 jobs 重跑（Enable Debug logging 开关值走 run 级 body 参数；job 级 API 无该参数） */
export async function rerunRun(token: string, owner: string, name: string, runId: number,
  debugLogging: boolean): Promise<void> {
  const body = `{"enable_debug_logging": ${debugLogging ? 'true' : 'false'}}`;
  ensureOk(await restPost(`/repos/${owner}/${name}/actions/runs/${runId}/rerun`, token, body));
}
