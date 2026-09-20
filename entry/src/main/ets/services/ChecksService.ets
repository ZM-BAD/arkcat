/**
 * Spec 048 Checks 服务：PR check runs 全量（GraphQL）+ Actions job 步骤与重跑（REST）。
 * Actions 特有端点/字段（actions/jobs、enable_debug_logging）只在本适配层出现。
 */
import { ApiError, graphql, restGet, restPost, RawResponse } from './GitHttpClient';
import { Json, JsonMap } from '../utils/Json';
import { StatusCheckItem, checkDisplayName } from '../models/RepoSubModels';
import { JobDetail, RunInfo, mapRestJob, mapRestRun } from '../models/ChecksModels';

/** Checks 页数据：全量行（Overview 全称口径）+ Details 分组 + 头提交 */
export interface PrChecksData {
  checks: StatusCheckItem[];
  /** Details 页签：按 workflow run 分组（官方 2026-09-20 截图）；status 裸行不进组 */
  groups: CheckRunGroup[];
  commitOid: string;
  commitHeadline: string;
}

/** Details 分组：Actions 组头带 SUMMARY（runId>0），外部 App（Codecov 等）组头仅展示 */
export interface CheckRunGroup {
  key: string;
  appLogo: string;
  /** 组头标题：workflow 名（Actions）或 App 名（Codecov 等） */
  title: string;
  /** WorkflowRun.databaseId，REST run id 同值；0=无 summary（外部 App） */
  runId: number;
  /** 组内行：裸 job 名（官方 Details 行不带 workflow 前缀） */
  checks: StatusCheckItem[];
}

/** run 汇总页数据（REST /actions/runs/{id} + /jobs + /artifacts） */
export interface RunSummaryData {
  workflowName: string;
  runNumber: number;
  /** 原始 event 词（push/pull_request…），触发文案换词用 */
  event: string;
  /** 提交标题大字（display_title，缺省回落 head_commit 首行） */
  displayTitle: string;
  headBranch: string;
  headSha: string;
  createdAt: string;
  /** 触发者（triggering_actor 优先，回落 actor） */
  actorLogin: string;
  status: string;
  conclusion: string;
  /** 时长区间（run_started_at → updated_at） */
  startedAt: string;
  completedAt: string;
  htmlUrl: string;
  /** 产物计数；-1=取数失败（展示 –） */
  artifacts: number;
  /** 面包屑 login（owner）头像；空串=取数失败（页面回落 App 图标） */
  ownerAvatar: string;
  jobs: JobDetail[];
}

/** PR 头提交全量 checks（Checks 页数据源）：checkSuites→checkRuns + 经典 status contexts */
const PR_CHECKS_QUERY = `
query PrChecks($owner: String!, $name: String!, $number: Int!) {
  repository(owner: $owner, name: $name) {
    pullRequest(number: $number) {
      commits(last: 1) {
        nodes {
          commit {
            oid abbreviatedOid messageHeadline
            # status.contexts 是普通列表（非 connection：无 first/totalCount/nodes 包裹）
            status { contexts { context state targetUrl } }
            checkSuites(first: 30) {
              nodes {
                app { name logoUrl }
                # workflowRun：行名全称素材 + Details 组头 SUMMARY 落点（databaseId=REST run id）
                workflowRun { databaseId event workflow { name } }
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
    // name=展示名（Actions 行「workflow 名 / job 名 (event)」全称，由调用方经 checkDisplayName 拼好）
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
  number: number): Promise<PrChecksData> {
  const vars: Record<string, Object> = { 'owner': owner, 'name': name, 'number': number };
  const data = await graphql(PR_CHECKS_QUERY, vars, token);
  const empty: PrChecksData = { checks: [], groups: [], commitOid: '', commitHeadline: '' };
  const repo = Json.obj(data, 'repository');
  const pr = repo !== null ? Json.obj(repo, 'pullRequest') : null;
  const commits = pr !== null ? Json.obj(pr, 'commits') : null;
  const commitNodes = commits !== null ? Json.arr(commits, 'nodes') : [];
  if (commitNodes.length === 0) {
    return empty;
  }
  const commit = (commitNodes[0] as JsonMap);
  const commitObj = Json.obj(commit, 'commit');
  if (commitObj === null) {
    return empty;
  }
  const out: PrChecksData = {
    checks: [],
    groups: [],
    commitOid: Json.str(commitObj, 'abbreviatedOid'),
    commitHeadline: Json.str(commitObj, 'messageHeadline')
  };
  // Actions / 外部 App check runs（suite 的 App 图标下发到每行）；同循环攒 Details 分组
  const suites = Json.obj(commitObj, 'checkSuites') ?? ({} as JsonMap);
  for (const suiteItem of Json.arr(suites, 'nodes')) {
    const suite = suiteItem as JsonMap;
    const app = Json.obj(suite, 'app');
    const appLogo = app !== null ? Json.str(app, 'logoUrl') : '';
    const wr = Json.obj(suite, 'workflowRun');
    const wf = wr !== null ? Json.obj(wr, 'workflow') : null;
    // 组头标题：workflow 名（Actions）优先，外部 App 回落 App 名
    const groupTitle = wf !== null && Json.str(wf, 'name') !== '' ? Json.str(wf, 'name')
      : (app !== null ? Json.str(app, 'name') : '');
    const group: CheckRunGroup = {
      key: `suite#${out.groups.length}`,
      appLogo: appLogo,
      title: groupTitle,
      runId: wr !== null ? Json.num(wr, 'databaseId') : 0,
      checks: []
    };
    const runs = Json.obj(suite, 'checkRuns') ?? ({} as JsonMap);
    for (const runItem of Json.arr(runs, 'nodes')) {
      const node = runItem as JsonMap;
      const runName = Json.str(node, 'name');
      if (runName === '') {
        continue;
      }
      const conclusion = Json.str(node, 'conclusion');
      const state = conclusion !== '' ? conclusion : Json.str(node, 'status');
      // Overview 行=全称；Details 组内行=裸 job 名（官方口径）
      out.checks.push(mapCheckRow(`${runName}#${out.checks.length}`, checkDisplayName(runName, suite), state, node, appLogo));
      group.checks.push(mapCheckRow(`${runName}#${group.checks.length}`, runName, state, node, appLogo));
    }
    if (group.checks.length > 0) {
      out.groups.push(group);
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
    out.checks.push({
      key: `${ctxName}#${out.checks.length}`,
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
  return out;
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

/** run 汇总页数据（run 概要 + jobs + 产物计数；Billable time 移动端 API 不下发，页面恒 –） */
export async function fetchRunSummary(token: string, owner: string, name: string,
  runId: number): Promise<RunSummaryData> {
  const resp = ensureOk(await restGet(`/repos/${owner}/${name}/actions/runs/${runId}`, token));
  const raw = Json.parse(resp.body);
  if (raw === null) {
    throw new ApiError(0, 'Checks run: empty body');
  }
  // 触发者：triggering_actor 优先（renovate[bot] 等机器人触发者），缺省回落 actor
  const trigger = Json.obj(raw, 'triggering_actor') ?? Json.obj(raw, 'actor');
  // 面包屑 login 头像（官方 run 汇总页顶行头像=owner 用户头像，非 App 图标）；软失败页面回落
  let ownerAvatar = '';
  try {
    const uResp = ensureOk(await restGet(`/users/${owner}`, token));
    const uRaw = Json.parse(uResp.body);
    if (uRaw !== null) {
      ownerAvatar = Json.str(uRaw, 'avatar_url');
    }
  } catch (e) {
    ownerAvatar = '';
  }
  // 产物计数软失败：-1 → 页面展示 –
  let artifacts = -1;
  try {
    const artResp = ensureOk(await restGet(`/repos/${owner}/${name}/actions/runs/${runId}/artifacts`, token));
    const artRaw = Json.parse(artResp.body);
    if (artRaw !== null) {
      artifacts = Json.num(artRaw, 'total_count');
    }
  } catch (e) {
    artifacts = -1;
  }
  const jobs: JobDetail[] = [];
  const jobsResp = ensureOk(await restGet(`/repos/${owner}/${name}/actions/runs/${runId}/jobs?per_page=100`, token));
  const jobsRaw = Json.parse(jobsResp.body);
  if (jobsRaw !== null) {
    for (const jobItem of Json.arr(jobsRaw, 'jobs')) {
      jobs.push(mapRestJob(jobItem as JsonMap));
    }
  }
  // 提交标题：display_title 优先，回落 head_commit 首行
  let displayTitle = Json.str(raw, 'display_title');
  if (displayTitle === '') {
    const hc = Json.obj(raw, 'head_commit');
    const msg = hc !== null ? Json.str(hc, 'message') : '';
    displayTitle = msg !== '' ? msg.split('\n')[0] : '';
  }
  return {
    workflowName: Json.str(raw, 'name'),
    runNumber: Json.num(raw, 'run_number'),
    event: Json.str(raw, 'event'),
    displayTitle: displayTitle,
    headBranch: Json.str(raw, 'head_branch'),
    headSha: Json.str(raw, 'head_sha'),
    createdAt: Json.str(raw, 'created_at'),
    actorLogin: trigger !== null ? Json.str(trigger, 'login') : '',
    status: Json.str(raw, 'status').toUpperCase(),
    conclusion: Json.str(raw, 'conclusion').toUpperCase(),
    startedAt: Json.str(raw, 'run_started_at'),
    completedAt: Json.str(raw, 'updated_at'),
    htmlUrl: Json.str(raw, 'html_url'),
    artifacts: artifacts,
    ownerAvatar: ownerAvatar,
    jobs: jobs
  };
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
