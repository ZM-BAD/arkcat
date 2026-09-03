/**
 * 搜索服务（Spec 015 v2）：
 * - Code/Repository/Issue/PR/User 搜索走 GraphQL search（type 分派；PR 无独立枚举，用 ISSUE 后按 __typename 分诊）
 * - Organizations 无 GraphQL search type，走 REST /search/users?type=organization 兜底
 * - qualifier 快捷 chip（repo/user/org/path/symbol）+ 插入纯函数
 * - 搜索历史 Preferences 持久化（去重置顶、最多 10 条）
 */
import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { graphql, restGet, ApiError } from './GitHttpClient';
import { Json, JsonMap } from '../utils/Json';

/** 首页/建议行类型（与 SEARCH_SUGGESTION_TYPES 一致） */
export type SearchEntryKind = 'code' | 'repositories' | 'issues' | 'prs' | 'people' | 'orgs';

/** 建议列表：六类搜索入口（纯常量，顺序与官方一致） */
export const SEARCH_SUGGESTION_TYPES: string[] = [
  'code', 'repositories', 'issues', 'prs', 'people', 'orgs'
];

/** qualifier 快捷词汇（官方底部贴键盘行；含语法操作符与正则 token） */
export const QUALIFIER_CHIPS: string[] = [
  'repo', 'user', 'org', 'path', 'symbol', 'language', 'content', '/regex/', 'AND', 'OR', 'NOT'
];

/** 统一搜索结果项（页面据此渲染四类行） */
export interface SearchResultItem {
  kind: 'repository' | 'issue' | 'pr' | 'user' | 'organization';
  title: string;
  subtitle: string;
  state: string;
  avatarUrl: string;
  repoFullName: string;
  number: number;
  stars: number;
  forks: number;
  language: string;
  languageColor: string;
  bio: string;
  followers: number;
  following: number;
}

/** 搜索结果页（分页） */
export interface SearchResultPage {
  totalCount: number;
  hasNextPage: boolean;
  endCursor: string;
  items: SearchResultItem[];
}

/** 代码搜索结果项 */
export interface CodeSearchItem {
  repoFullName: string;
  path: string;
  name: string;
  isMarkdown: boolean;
}

const CODE_SEARCH_QUERY = `
query CodeSearch($query: String!, $first: Int = 10) {
  search(query: $query, type: CODE, first: $first) {
    codeCount
    nodes {
      ... on File {
        repository { nameWithOwner }
        path
        name
      }
    }
  }
}`;

const SEARCH_ALL_QUERY = `
query SearchAll($query: String!, $type: SearchType!, $first: Int = 20, $after: String) {
  search(query: $query, type: $type, first: $first, after: $after) {
    repositoryCount
    issueCount
    userCount
    pageInfo { hasNextPage endCursor }
    nodes {
      ... on Repository {
        __typename
        nameWithOwner description stargazerCount forkCount
        primaryLanguage { name color }
      }
      ... on Issue {
        __typename title state number
        repository { nameWithOwner }
      }
      ... on PullRequest {
        __typename title state number
        repository { nameWithOwner }
      }
      ... on User {
        __typename login name avatarUrl bio
        followers { totalCount } following { totalCount }
      }
    }
  }
}`;

const ORG_SEARCH_REST = '/search/users?type=organization&per_page=20&q=';

/** 构造搜索串（纯函数，便于单测）：关键词带引号，限定词不在引号内 */
export function buildCodeQuery(keyword: string): string {
  return `"${keyword}"`;
}

/** GraphQL CODE search 响应 → CodeSearchItem[] */
export function mapCodeSearch(data: JsonMap): CodeSearchItem[] {
  const search = Json.obj(data, 'search') ?? ({} as JsonMap);
  const items: CodeSearchItem[] = [];
  for (const nodeItem of Json.arr(search, 'nodes')) {
    const node = nodeItem as JsonMap;
    const repo = Json.obj(node, 'repository');
    let name = Json.str(node, 'name');
    const path = Json.str(node, 'path');
    // name 缺失时从 path 末段取
    if (name === '' && path !== '') {
      const parts = path.split('/');
      name = parts.length > 0 ? parts[parts.length - 1] : '';
    }
    items.push({
      repoFullName: repo ? Json.str(repo, 'nameWithOwner') : '',
      path: path,
      name: name,
      isMarkdown: name.toLowerCase().endsWith('.md')
    });
  }
  return items;
}

/** 节点 → 统一结果项（按 __typename 分诊，纯函数） */
export function mapSearchNode(node: JsonMap): SearchResultItem | null {
  const typename = Json.str(node, '__typename');
  if (typename === 'Repository') {
    const lang = Json.obj(node, 'primaryLanguage');
    return {
      kind: 'repository',
      title: Json.str(node, 'nameWithOwner'),
      subtitle: Json.str(node, 'description'),
      state: '',
      avatarUrl: '',
      repoFullName: '',
      number: 0,
      stars: Json.num(node, 'stargazerCount'),
      forks: Json.num(node, 'forkCount'),
      language: lang ? Json.str(lang, 'name') : '',
      languageColor: lang ? Json.str(lang, 'color') : '',
      bio: '',
      followers: 0,
      following: 0
    };
  }
  const repo = Json.obj(node, 'repository');
  if (typename === 'PullRequest' || typename === 'Issue') {
    return {
      kind: typename === 'PullRequest' ? 'pr' : 'issue',
      title: Json.str(node, 'title'),
      subtitle: repo ? Json.str(repo, 'nameWithOwner') : '',
      state: Json.str(node, 'state'),
      avatarUrl: '',
      repoFullName: repo ? Json.str(repo, 'nameWithOwner') : '',
      number: Json.num(node, 'number'),
      stars: 0,
      forks: 0,
      language: '',
      languageColor: '',
      bio: '',
      followers: 0,
      following: 0
    };
  }
  if (typename === 'User') {
    const followers = Json.obj(node, 'followers');
    const following = Json.obj(node, 'following');
    return {
      kind: 'user',
      title: Json.str(node, 'login'),
      subtitle: Json.str(node, 'name'),
      state: '',
      avatarUrl: Json.str(node, 'avatarUrl'),
      repoFullName: '',
      number: 0,
      stars: 0,
      forks: 0,
      language: '',
      languageColor: '',
      bio: Json.str(node, 'bio'),
      followers: followers ? Json.num(followers, 'totalCount') : 0,
      following: following ? Json.num(following, 'totalCount') : 0
    };
  }
  if (typename === 'Organization') {
    return {
      kind: 'organization',
      title: Json.str(node, 'login'),
      subtitle: Json.str(node, 'name'),
      state: '',
      avatarUrl: Json.str(node, 'avatarUrl'),
      repoFullName: '',
      number: 0,
      stars: 0,
      forks: 0,
      language: '',
      languageColor: '',
      bio: '',
      followers: 0,
      following: 0
    };
  }
  return null;
}

/** GraphQL search 响应 → SearchResultPage（纯函数） */
export function mapSearchResults(data: JsonMap): SearchResultPage {
  const search = Json.obj(data, 'search') ?? ({} as JsonMap);
  const page = Json.obj(search, 'pageInfo') ?? ({} as JsonMap);
  const items: SearchResultItem[] = [];
  for (const nodeItem of Json.arr(search, 'nodes')) {
    const item = mapSearchNode(nodeItem as JsonMap);
    if (item !== null) {
      items.push(item);
    }
  }
  // Connect 无通用 searchCount；按查询类型只有对应计数非零，求和即总数
  const totalCount = Json.num(search, 'repositoryCount') + Json.num(search, 'issueCount') + Json.num(search, 'userCount');
  return {
    totalCount: totalCount,
    hasNextPage: Json.bool(page, 'hasNextPage'),
    endCursor: Json.str(page, 'endCursor'),
    items: items
  };
}

/** REST org 搜索响应 → SearchResultItem[]（纯函数） */
export function mapOrgSearchResults(data: JsonMap): SearchResultItem[] {
  const items: SearchResultItem[] = [];
  for (const item of Json.arr(data, 'items')) {
    const node = item as JsonMap;
    items.push({
      kind: 'organization',
      title: Json.str(node, 'login'),
      subtitle: Json.str(node, 'name'),
      state: '',
      avatarUrl: Json.str(node, 'avatar_url'),
      repoFullName: '',
      number: 0,
      stars: 0,
      forks: 0,
      language: '',
      languageColor: '',
      bio: '',
      followers: 0,
      following: 0
    });
  }
  return items;
}

/**
 * qualifier chip → 插入后的搜索串（纯函数）。
 * 示例：("", "repo") → "repo:"；("foo", "repo") → "foo repo:"；("foo ", "repo") → "foo repo:"
 */
export function buildQualifierInsert(current: string, chip: string): string {
  const qualifier = `${chip}:`;
  if (current.trim() === '') {
    return qualifier;
  }
  const gap = current.endsWith(' ') || current.endsWith(':') ? '' : ' ';
  return `${current}${gap}${qualifier}`;
}

/** 搜索历史上限 */
export const SEARCH_HISTORY_MAX = 10;

/** 新历史条目：去重置顶 + 截断上限（纯函数） */
export function pushSearchHistory(entries: string[], keyword: string): string[] {
  const kw = keyword.trim();
  if (kw === '') {
    return entries;
  }
  const next = entries.filter((k: string) => k !== kw);
  next.unshift(kw);
  return next.slice(0, SEARCH_HISTORY_MAX);
}

const HISTORY_PREFS = 'starraft.search';
const HISTORY_KEY = 'recent';

/** 搜索历史持久化（Preferences；非敏感数据不走加密存储） */
export class SearchHistoryStore {
  /** 加载历史；异常返回空 */
  static async load(context: common.Context | undefined): Promise<string[]> {
    if (context === undefined) {
      return [];
    }
    try {
      const prefs = await preferences.getPreferences(context, HISTORY_PREFS);
      const value = await prefs.get(HISTORY_KEY, '[]');
      if (typeof value === 'string') {
        const parsed: Object | null = JSON.parse(value);
        if (parsed !== null && Array.isArray(parsed)) {
          return parsed as string[];
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /** 保存历史；失败静默 */
  static async save(context: common.Context | undefined, entries: string[]): Promise<void> {
    if (context === undefined) {
      return;
    }
    try {
      const prefs = await preferences.getPreferences(context, HISTORY_PREFS);
      await prefs.put(HISTORY_KEY, JSON.stringify(entries));
      await prefs.flush();
    } catch (e) {
      // 持久化失败不阻断交互
    }
  }
}

/** 入口类型 → GraphQL SearchType（PR 无独立枚举，用 ISSUE 后分诊） */
function searchGqlType(kind: SearchEntryKind): string {
  switch (kind) {
    case 'repositories':
      return 'REPOSITORY';
    case 'issues':
      return 'ISSUE';
    case 'prs':
      return 'ISSUE';
    case 'people':
      return 'USER';
    default:
      return 'REPOSITORY';
  }
}

export class SearchService {
  /** 代码搜索（GraphQL CODE） */
  static async fetchCodeResults(token: string, keyword: string): Promise<CodeSearchItem[]> {
    const variables: Record<string, Object> = {
      'query': buildCodeQuery(keyword),
      'first': 10
    };
    const data = await graphql(CODE_SEARCH_QUERY, variables, token);
    return mapCodeSearch(data);
  }

  /** Repository/Issue/PR/User 搜索（GraphQL search，type 分派，分页） */
  static async fetchSearchResults(token: string, kind: SearchEntryKind, keyword: string, after: string = ''): Promise<SearchResultPage> {
    const variables: Record<string, Object> = {
      'query': buildCodeQuery(keyword),
      'type': searchGqlType(kind),
      'first': 20
    };
    if (after !== '') {
      variables['after'] = after;
    }
    const data = await graphql(SEARCH_ALL_QUERY, variables, token);
    return mapSearchResults(data);
  }

  /** Organizations 搜索（REST 兜底） */
  static async fetchOrgResults(token: string, keyword: string): Promise<SearchResultItem[]> {
    const resp = await restGet(`${ORG_SEARCH_REST}${encodeURIComponent(keyword)}`, token);
    const data = Json.parse(resp.body);
    return data !== null ? mapOrgSearchResults(data) : [];
  }

  /** Jump to：首个匹配仓库（Repository 探测）→ nameWithOwner；无匹配抛错误 */
  static async fetchJumpToRepo(token: string, keyword: string): Promise<string> {
    const page = await SearchService.fetchSearchResults(token, 'repositories', keyword);
    if (page.items.length > 0 && page.items[0].kind === 'repository') {
      return page.items[0].title;
    }
    throw new ApiError(0, 'no match');
  }
}
