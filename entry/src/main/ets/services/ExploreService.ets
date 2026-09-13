/**
 * Explore 服务（Spec 056）：Activity 动态流 + Trending/Awesome 列表。
 * Activity = REST received_events 过滤 merged PR 事件，GraphQL alias 单请求批量补详情；
 * Trending/Awesome 官方无公开 API，REST search 近似（Spec 056 边界）。
 */
import { ApiError, RawResponse, graphql, restGet } from './GitHttpClient';
import {
  ActivityPrRef, ExploreActivityEvent, mapActivityEvents, mapActivityEventsWithDetails
} from '../models/ExploreModels';
import { RepoSummary } from '../models/GitHubModels';
import { ExploreLanguage, programLanguageColor } from '../models/ExploreLanguages';
import { Json, JsonMap } from '../utils/Json';

const VIEWER_LOGIN_QUERY = `
query ViewerLogin {
  viewer { login }
}`;

/** Trending 筛选窗口（官方 Today/This week/This month → 天数；官方算法无 API，Spec 056 近似） */
export const TRENDING_WINDOW_DAYS = 7;
const SEARCH_PER_PAGE = 25;

/** GraphQL 字符串注入转义（alias 查询为拼接构造） */
function gqlEscape(value: string): string {
  return value.replace(/\\/g, '\\\\').replace(/"/g, '\\"').replace(/\n/g, ' ');
}

/** 事件详情 alias 查询：r0..rN 一次批量取标题/正文/作者/反应组 */
export function buildPrDetailsQuery(refs: ActivityPrRef[]): string {
  const parts: string[] = [];
  for (let i = 0; i < refs.length; i++) {
    const slash = refs[i].repoFullName.indexOf('/');
    const owner = gqlEscape(refs[i].repoFullName.substring(0, slash));
    const name = gqlEscape(refs[i].repoFullName.substring(slash + 1));
    parts.push(`r${i}: repository(owner: "${owner}", name: "${name}") { ` +
      `pullRequest(number: ${refs[i].number}) { id title body merged headRefName baseRefName ` +
      `author { login avatarUrl } reactionGroups { content viewerHasReacted reactors { totalCount } } } }`);
  }
  return `query ExploreActivity {\n  ${parts.join('\n  ')}\n}`;
}

/** 横幅图/Star 状态 alias 查询：r0..rN 一批补 openGraphImageUrl + viewerHasStarred */
export function buildRepoMetaQuery(repos: RepoSummary[]): string {
  const parts: string[] = [];
  for (let i = 0; i < repos.length; i++) {
    const slash = repos[i].nameWithOwner.indexOf('/');
    if (slash <= 0) {
      continue;
    }
    const owner = gqlEscape(repos[i].nameWithOwner.substring(0, slash));
    const name = gqlEscape(repos[i].nameWithOwner.substring(slash + 1));
    parts.push(`r${i}: repository(owner: "${owner}", name: "${name}") { openGraphImageUrl viewerHasStarred }`);
  }
  return `query ExploreRepoMeta {\n  ${parts.join('\n  ')}\n}`;
}

/** 搜索结果 + GraphQL 元信息合并（alias 为 null / 查询不命中时保留 REST 原值） */
export function mapRepoMeta(repos: RepoSummary[], data: JsonMap): RepoSummary[] {
  const merged: RepoSummary[] = [];
  for (let i = 0; i < repos.length; i++) {
    const node = Json.obj(data, `r${i}`);
    const repo = repos[i];
    if (node === null) {
      merged.push(repo);
      continue;
    }
    merged.push({
      id: repo.id,
      name: repo.name,
      nameWithOwner: repo.nameWithOwner,
      description: repo.description,
      stargazerCount: repo.stargazerCount,
      forkCount: repo.forkCount,
      primaryLanguage: repo.primaryLanguage,
      languageColor: repo.languageColor,
      isPrivate: repo.isPrivate,
      ownerLogin: repo.ownerLogin,
      ownerAvatarUrl: repo.ownerAvatarUrl,
      graphqlId: repo.graphqlId,
      openGraphImageUrl: Json.str(node, 'openGraphImageUrl'),
      viewerHasStarred: Json.bool(node, 'viewerHasStarred'),
      contributorCount: repo.contributorCount,
      isArchived: repo.isArchived,
      isFork: repo.isFork,
      isMirror: repo.isMirror,
      isTemplate: repo.isTemplate
    });
  }
  return merged;
}

/**
 * /contributors?per_page=1 的 Link 头 → 贡献者数（rel="last" 页数即总数）。
 * per_page=1 无分页时：body 空=0，非空=1；无 link 且响应异常按 0。
 */
export function contributorCount(body: string, link: string): number {
  const parsed: Object | null = JSON.parse(body);
  if (parsed === null || !Array.isArray(parsed)) {
    return 0;
  }
  if ((parsed as Object[]).length === 0) {
    return 0;
  }
  let last = 0;
  for (const seg of link.split(',')) {
    if (seg.indexOf('rel="last"') < 0) {
      continue;
    }
    const m = /page=(\d+)/.exec(seg);
    if (m !== null && m.length > 1) {
      last = parseInt(m[1], 10);
    }
  }
  return last > 0 ? last : 1;
}

/** 批量并发取贡献者数（一页 1 条 → Link last 页数）；单仓库失败按 0 降级不阻断 */
export async function fetchContributorCounts(
  token: string, repos: RepoSummary[]): Promise<Map<string, number>> {
  const counts = new Map<string, number>();
  const jobs: Promise<void>[] = [];
  for (const repo of repos) {
    jobs.push(
      restGet(`/repos/${repo.nameWithOwner}/contributors?per_page=1&anon=0`, token)
        .then((resp: RawResponse): void => {
          counts.set(repo.nameWithOwner, contributorCount(resp.body, resp.link ?? ''));
        })
        .catch((_e: Error): void => {
          // 404（无贡献者/空仓库）=0；网络失败同样按 0 降级
          counts.set(repo.nameWithOwner, 0);
        }));
  }
  await Promise.all(jobs);
  return counts;
}

/**
 * 列表搜索路径（kind=trending/awesome 共用）：
 * trending 用 pushed:>X 窗口近似（官方趋势算法无 API；pushed 窗口实测对语言/口语筛选
 * 有数据，created 窗口近 7 天新建会筛空——见 2026-09-07 用户实测 Chinese 修复）；qualifier 均服务端过滤。
 */
export function buildRepoListPath(
  kind: string, nowMs: number, daysWindow: number, language: string, spoken: string): string {
  const parts: string[] = [];
  if (kind === 'awesome') {
    parts.push('topic:awesome-list');
  } else {
    const since = new Date(nowMs - daysWindow * 86400000).toISOString().substring(0, 10);
    parts.push(`pushed:>${since}`);
  }
  if (language !== '') {
    parts.push(`language:${language}`);
  }
  if (spoken !== '') {
    parts.push(`spoken_language:${spoken}`);
  }
  const query = encodeURIComponent(parts.join(' '));
  return `/search/repositories?q=${query}&sort=stars&order=desc&per_page=${SEARCH_PER_PAGE}`;
}

/** Trending 搜索路径（纯函数便于单测；nowMs/daysWindow 注入；语言/口语可选） */
export function buildTrendingPath(nowMs: number, daysWindow: number, language: string = '', spoken: string = ''): string {
  return buildRepoListPath('trending', nowMs, daysWindow, language, spoken);
}

/** Awesome Lists 搜索路径（topic:awesome-list 按星近似官方精选；语言/口语可选） */
export function buildAwesomePath(language: string = '', spoken: string = ''): string {
  return buildRepoListPath('awesome', Date.now(), TRENDING_WINDOW_DAYS, language, spoken);
}

/** REST search 仓库条目 → RepoSummary（映射对齐 ProfileListService REST 兜底） */
export function mapSearchRepos(body: string): RepoSummary[] {
  const repos: RepoSummary[] = [];
  const parsed: Object | null = JSON.parse(body);
  // search 响应根为对象 {total_count, items}；数组/空直接返回
  if (parsed === null || Array.isArray(parsed)) {
    return repos;
  }
  const root = parsed as JsonMap;
  for (const itemObj of Json.arr(root, 'items')) {
    const item = itemObj as JsonMap;
    const language = Json.str(item, 'language');
    const owner = Json.obj(item, 'owner');
    repos.push({
      id: Json.str(item, 'id'),
      name: Json.str(item, 'name'),
      nameWithOwner: Json.str(item, 'full_name'),
      description: Json.str(item, 'description'),
      stargazerCount: Json.num(item, 'stargazers_count'),
      forkCount: Json.num(item, 'forks_count'),
      primaryLanguage: language,
      languageColor: programLanguageColor(language),
      isPrivate: Json.bool(item, 'private'),
      ownerLogin: owner !== null ? Json.str(owner, 'login') : '',
      ownerAvatarUrl: owner !== null ? Json.str(owner, 'avatar_url') : '',
      graphqlId: Json.str(item, 'node_id'),
      openGraphImageUrl: '',
      viewerHasStarred: false,
      contributorCount: 0,
      isArchived: Json.bool(item, 'archived'),
      isFork: Json.bool(item, 'fork'),
      isMirror: Json.str(item, 'mirror_url') !== '',
      isTemplate: Json.bool(item, 'is_template')
    });
  }
  return repos;
}

export class ExploreService {
  /** viewer 登录名缓存（received_events 路径参数；登录期不变） */
  private static viewerLogin: string = '';

  /** Activity 动态流：received_events merged PR → alias 批量补详情 */
  static async fetchActivity(token: string): Promise<ExploreActivityEvent[]> {
    if (ExploreService.viewerLogin === '') {
      const viewerData = await graphql(VIEWER_LOGIN_QUERY, null, token);
      const viewer = Json.obj(viewerData, 'viewer') ?? ({} as JsonMap);
      ExploreService.viewerLogin = Json.str(viewer, 'login');
    }
    const resp = await restGet(
      `/users/${ExploreService.viewerLogin}/received_events?per_page=60`, token);
    const parsed: Object | null = JSON.parse(resp.body);
    if (parsed === null || !Array.isArray(parsed)) {
      throw new ApiError(resp.code, 'Unexpected received_events payload');
    }
    const refs = mapActivityEvents(parsed as Object[]);
    if (refs.length === 0) {
      return [];
    }
    const data = await graphql(buildPrDetailsQuery(refs), null, token);
    return mapActivityEventsWithDetails(refs, data);
  }

  /**
   * Trending/Awesome 仓库列表：REST search 近似的首次数据，随后并行补全二阶元信息——
   * GraphQL alias 一次性补横幅图/Star 状态 + REST /contributors per_page=1 取 Link last 页
   * 估贡献者数；任一补全失败各自降级（无横幅/Star 态/计数 0），不阻断列表。
   */
  static async fetchRepoList(
    token: string, kind: string, daysWindow: number, language: string, spoken: string): Promise<RepoSummary[]> {
    const resp = await restGet(buildRepoListPath(kind, Date.now(), daysWindow, language, spoken), token);
    const repos = mapSearchRepos(resp.body);
    if (repos.length === 0) {
      return repos;
    }
    const metaTask: Promise<Object> = graphql(buildRepoMetaQuery(repos), null, token)
      .then((data: JsonMap): RepoSummary[] => mapRepoMeta(repos, data))
      .catch((_e: Error): RepoSummary[] => repos);
    const countTask: Promise<Object> = fetchContributorCounts(token, repos);
    const results = await Promise.all([metaTask, countTask]);
    const merged = results[0] as RepoSummary[];
    const counts = results[1] as Map<string, number>;
    return merged.map((repo: RepoSummary): RepoSummary => {
      return {
        id: repo.id,
        name: repo.name,
        nameWithOwner: repo.nameWithOwner,
        description: repo.description,
        stargazerCount: repo.stargazerCount,
        forkCount: repo.forkCount,
        primaryLanguage: repo.primaryLanguage,
        languageColor: repo.languageColor,
        isPrivate: repo.isPrivate,
        ownerLogin: repo.ownerLogin,
        ownerAvatarUrl: repo.ownerAvatarUrl,
        graphqlId: repo.graphqlId,
        openGraphImageUrl: repo.openGraphImageUrl,
        viewerHasStarred: repo.viewerHasStarred,
        contributorCount: counts.get(repo.nameWithOwner) ?? 0,
        isArchived: repo.isArchived,
        isFork: repo.isFork,
        isMirror: repo.isMirror,
        isTemplate: repo.isTemplate
      };
    });
  }

  /** Filter by language 全量语言（官方接口 GET /languages：免认证 833 项；ABAP/ABAP CDS 等全覆盖） */
  static async fetchAllLanguages(token: string): Promise<ExploreLanguage[]> {
    const resp = await restGet('/languages', token);
    const parsed: Object | null = JSON.parse(resp.body);
    if (parsed === null || !Array.isArray(parsed)) {
      throw new ApiError(resp.code, 'Unexpected /languages payload');
    }
    const list: ExploreLanguage[] = [];
    for (const item of parsed as Object[]) {
      const raw = item as JsonMap;
      const name = Json.str(raw, 'name');
      if (name !== '') {
        list.push({ name: name, color: programLanguageColor(name) });
      }
    }
    return list;
  }
}
