/**
 * Explore 服务（Spec 056）：Activity 动态流 + Trending/Awesome 列表。
 * Activity = REST received_events 过滤 merged PR 事件，GraphQL alias 单请求批量补详情；
 * Trending/Awesome 官方无公开 API，REST search 近似（Spec 056 边界）。
 */
import { ApiError, graphql, restGet } from './GitHttpClient';
import {
  ActivityPrRef, ExploreActivityEvent, mapActivityEvents, mapActivityEventsWithDetails
} from '../models/ExploreModels';
import { RepoSummary } from '../models/GitHubModels';
import { LANGUAGE_COLORS } from '../models/LanguageColors';
import { Json, JsonMap } from '../utils/Json';

const VIEWER_LOGIN_QUERY = `
query ViewerLogin {
  viewer { login }
}`;

/** Trending 近似窗口（天）：近 N 天新建仓库按星排序 */
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
      `pullRequest(number: ${refs[i].number}) { id title body merged ` +
      `author { login avatarUrl } reactionGroups { content viewerHasReacted reactors { totalCount } } } }`);
  }
  return `query ExploreActivity {\n  ${parts.join('\n  ')}\n}`;
}

/** Trending 搜索路径（纯函数便于单测；nowMs/daysWindow 注入） */
export function buildTrendingPath(nowMs: number, daysWindow: number): string {
  const since = new Date(nowMs - daysWindow * 86400000).toISOString().substring(0, 10);
  const query = encodeURIComponent(`created:>${since}`);
  return `/search/repositories?q=${query}&sort=stars&order=desc&per_page=${SEARCH_PER_PAGE}`;
}

/** Awesome Lists 搜索路径（topic:awesome-list 按星近似官方精选） */
export function buildAwesomePath(): string {
  const query = encodeURIComponent('topic:awesome-list');
  return `/search/repositories?q=${query}&sort=stars&order=desc&per_page=${SEARCH_PER_PAGE}`;
}

/** REST search 仓库条目 → RepoSummary（映射对齐 ProfileListService REST 兜底） */
export function mapSearchRepos(body: string): RepoSummary[] {
  const repos: RepoSummary[] = [];
  const parsed: Object | null = JSON.parse(body);
  if (parsed === null || !Array.isArray(parsed)) {
    return repos;
  }
  // Array.isArray 收窄后需经 Object 中转回 JsonMap（ArkTS 禁 any[] 直转）
  const root = parsed as Object as JsonMap;
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
      languageColor: LANGUAGE_COLORS[language] ?? '',
      isPrivate: Json.bool(item, 'private'),
      ownerLogin: owner !== null ? Json.str(owner, 'login') : '',
      ownerAvatarUrl: owner !== null ? Json.str(owner, 'avatar_url') : ''
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

  /** Trending 仓库（近 7 天新建按星近似，官方算法无 API） */
  static async fetchTrending(token: string): Promise<RepoSummary[]> {
    const resp = await restGet(buildTrendingPath(Date.now(), TRENDING_WINDOW_DAYS), token);
    return mapSearchRepos(resp.body);
  }

  /** Awesome Lists（topic:awesome-list 按星近似，官方精选无 API） */
  static async fetchAwesome(token: string): Promise<RepoSummary[]> {
    const resp = await restGet(buildAwesomePath(), token);
    return mapSearchRepos(resp.body);
  }
}
