/**
 * 搜索服务（Spec 015 v2 / Spec 046 结果页批）：
 * - Repository/Issue/PR/User/Org 搜索走 GraphQL search（type 分派；PR 无独立枚举，用 ISSUE + is:pr 分诊）
 * - Organization 无 GraphQL search type，用 USER + type:org 限定词兜底（官方语义等价）
 * - 聚合结果页：单次请求 6 路别名单（repos/issues/prs/users/orgs/codeFiles），code 正文走 CodeSearchService
 * - qualifier 快捷 chip（repo/user/org/path/symbol）+ 插入纯函数
 * - 搜索历史 Preferences 持久化（去重置顶、最多 10 条）
 */
import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { graphql, restGet, ApiError } from './GitHttpClient';
import { CodeFileResult, CodeSearchPage, CodeSearchService } from './CodeSearchService';
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

/** 标签（labelled pill） */
export interface SearchLabel {
  name: string;
  color: string;
}

/** 统一搜索结果项（页面据此渲染各类行） */
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
  /** issue/PR：ISO 时间戳（页面转相对时间） */
  createdAt: string;
  labels: SearchLabel[];
  commentCount: number;
  reactionCount: number;
  /** statusCheckRollup.state：SUCCESS/FAILURE/PENDING/EXPECTED/ERROR */
  checkState: string;
  reviewDecision: string;
}

/** 搜索结果页（分页） */
export interface SearchResultPage {
  totalCount: number;
  hasNextPage: boolean;
  endCursor: string;
  items: SearchResultItem[];
}

/** 聚合结果页数据（六区块） */
export interface SearchOverviewData {
  repoItems: SearchResultItem[];
  repoCount: number;
  issueItems: SearchResultItem[];
  issueCount: number;
  prItems: SearchResultItem[];
  prCount: number;
  userItems: SearchResultItem[];
  userCount: number;
  orgItems: SearchResultItem[];
  orgCount: number;
  /** code 文件（含内容窗口/高亮/Show more） */
  codeFiles: CodeFileResult[];
}

/** 代码搜索结果项（兼容旧单测：GraphQL CODE 元数据） */
export interface CodeSearchItem {
  repoFullName: string;
  path: string;
  name: string;
  isMarkdown: boolean;
}

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
        owner { avatarUrl(size: 48) }
      }
      ... on Issue {
        __typename title state number createdAt
        repository { nameWithOwner }
        labels(first: 5) { nodes { name color } }
        comments { totalCount }
        reactions { totalCount }
      }
      ... on PullRequest {
        __typename title state number createdAt
        repository { nameWithOwner }
        labels(first: 5) { nodes { name color } }
        comments { totalCount }
        reactions { totalCount }
        statusCheckRollup { state }
        reviewDecision
      }
      ... on User {
        __typename login name bio avatarUrl
        followers { totalCount } following { totalCount }
      }
      ... on Organization {
        __typename login name description avatarUrl
      }
    }
  }
}`;

const OVERVIEW_QUERY = `
query SearchOverview($q: String!, $issueQ: String!, $prQ: String!, $userQ: String!, $orgQ: String!, $first: Int = 3) {
  repos: search(query: $q, type: REPOSITORY, first: $first) {
    repositoryCount
    nodes { ... on Repository { __typename nameWithOwner description stargazerCount primaryLanguage { name color } owner { avatarUrl(size: 48) } } }
  }
  issues: search(query: $issueQ, type: ISSUE, first: $first) {
    issueCount
    nodes { ... on Issue { __typename title state number createdAt repository { nameWithOwner } labels(first: 3) { nodes { name color } } comments { totalCount } } }
  }
  prs: search(query: $prQ, type: ISSUE, first: $first) {
    issueCount
    nodes { ... on PullRequest { __typename title state number createdAt repository { nameWithOwner } labels(first: 3) { nodes { name color } } comments { totalCount } reactions { totalCount } statusCheckRollup { state } reviewDecision } }
  }
  users: search(query: $userQ, type: USER, first: $first) {
    userCount
    nodes { ... on User { __typename login name bio avatarUrl } ... on Organization { __typename login name description avatarUrl } }
  }
  orgs: search(query: $orgQ, type: USER, first: $first) {
    userCount
    nodes { ... on User { __typename login name bio avatarUrl } ... on Organization { __typename login name description avatarUrl } }
  }
}`;


/**
 * 构造搜索串（纯函数，便于单测）：关键词不带引号（保证 qualifier 能被解析）。
 */
export function buildCodeQuery(keyword: string): string {
  return keyword.trim();
}

/** 类型限定词（官方分页语义）：issues→is:issue、prs→is:pr、people→type:user、orgs→type:org */
export function buildSearchQuery(kind: SearchEntryKind, keyword: string): string {
  const kw = keyword.trim();
  switch (kind) {
    case 'issues':
      return `${kw} is:issue`;
    case 'prs':
      return `${kw} is:pr`;
    case 'people':
      return `${kw} type:user`;
    case 'orgs':
      return `${kw} type:org`;
    default:
      return kw;
  }
}

/**
 * 大数紧凑格式（See X more 行）：999→999、72k、2.2m、24.2m（整数去 .0）。
 */
export function formatBigCount(n: number): string {
  if (n <= 0) {
    return '0';
  }
  if (n >= 1000000) {
    const m = Math.round(n / 100000) / 10;
    return m % 1 === 0 ? `${m}m` : `${m.toFixed(1)}m`;
  }
  if (n >= 1000) {
    const k = Math.round(n / 100) / 10;
    return k % 1 === 0 ? `${k}k` : `${k.toFixed(1)}k`;
  }
  return `${n}`;
}

/** label 色（GraphQL #RRGGBB）是否浅色（决定白底 pill 文字颜色；纯函数） */
export function isLightHexColor(hex: string): boolean {
  if (hex.length !== 6) {
    return false;
  }
  const r = parseInt(hex.substring(0, 2), 16);
  const g = parseInt(hex.substring(2, 4), 16);
  const b = parseInt(hex.substring(4, 6), 16);
  if (Number.isNaN(r) || Number.isNaN(g) || Number.isNaN(b)) {
    return false;
  }
  const luma = 0.299 * r + 0.587 * g + 0.114 * b;
  return luma > 160;
}

/** labels 连接 → SearchLabel[]（纯函数） */
function mapSearchLabels(node: JsonMap, key: string): SearchLabel[] {
  const wrap = Json.obj(node, key);
  const out: SearchLabel[] = [];
  if (wrap !== null) {
    for (const nodeItem of Json.arr(wrap, 'nodes')) {
      const n = nodeItem as JsonMap;
      out.push({ name: Json.str(n, 'name'), color: Json.str(n, 'color') });
    }
  }
  return out;
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
    const owner = Json.obj(node, 'owner');
    return {
      kind: 'repository',
      title: Json.str(node, 'nameWithOwner'),
      subtitle: Json.str(node, 'description'),
      state: '',
      avatarUrl: owner ? Json.str(owner, 'avatarUrl') : '',
      repoFullName: '',
      number: 0,
      stars: Json.num(node, 'stargazerCount'),
      forks: Json.num(node, 'forkCount'),
      language: lang ? Json.str(lang, 'name') : '',
      languageColor: lang ? Json.str(lang, 'color') : '',
      bio: '',
      followers: 0,
      following: 0,
      createdAt: '',
      labels: [],
      commentCount: 0,
      reactionCount: 0,
      checkState: '',
      reviewDecision: ''
    };
  }
  const repo = Json.obj(node, 'repository');
  if (typename === 'PullRequest' || typename === 'Issue') {
    const comments = Json.obj(node, 'comments');
    const reactions = Json.obj(node, 'reactions');
    const check = Json.obj(node, 'statusCheckRollup');
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
      following: 0,
      createdAt: Json.str(node, 'createdAt'),
      labels: mapSearchLabels(node, 'labels'),
      commentCount: comments ? Json.num(comments, 'totalCount') : 0,
      reactionCount: reactions ? Json.num(reactions, 'totalCount') : 0,
      checkState: check ? Json.str(check, 'state') : '',
      reviewDecision: Json.str(node, 'reviewDecision')
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
      following: following ? Json.num(following, 'totalCount') : 0,
      createdAt: '',
      labels: [],
      commentCount: 0,
      reactionCount: 0,
      checkState: '',
      reviewDecision: ''
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
      bio: Json.str(node, 'description'),
      followers: 0,
      following: 0,
      createdAt: '',
      labels: [],
      commentCount: 0,
      reactionCount: 0,
      checkState: '',
      reviewDecision: ''
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

/** aggregate 单区块解析结果 */
export interface OverviewSection {
  count: number;
  items: SearchResultItem[];
}

/** 别名 search → { count, items }（纯函数） */
function mapOverviewSection(data: JsonMap, alias: string): OverviewSection {
  const search = Json.obj(data, alias) ?? ({} as JsonMap);
  const items: SearchResultItem[] = [];
  for (const nodeItem of Json.arr(search, 'nodes')) {
    const item = mapSearchNode(nodeItem as JsonMap);
    if (item !== null) {
      items.push(item);
    }
  }
  const count = Json.num(search, 'repositoryCount') + Json.num(search, 'issueCount') + Json.num(search, 'userCount');
  return { count: count, items: items };
}

/** 聚合搜索响应 → 六区块数据（纯函数；code 走 REST 另行填充） */
export function mapSearchOverview(data: JsonMap): SearchOverviewData {
  const repos = mapOverviewSection(data, 'repos');
  const issues = mapOverviewSection(data, 'issues');
  const prs = mapOverviewSection(data, 'prs');
  const users = mapOverviewSection(data, 'users');
  const orgs = mapOverviewSection(data, 'orgs');
  return {
    repoItems: repos.items,
    repoCount: repos.count,
    issueItems: issues.items,
    issueCount: issues.count,
    prItems: prs.items,
    prCount: prs.count,
    userItems: users.items,
    userCount: users.count,
    orgItems: orgs.items,
    orgCount: orgs.count,
    codeFiles: []
  };
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

const HISTORY_PREFS = 'arkcat.search';
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
          // 元素类型校验：prefs 被写坏成非字符串数组时不再渲染异常（review E12）
          const out: string[] = [];
          for (const item of parsed as Object[]) {
            if (typeof item === 'string') {
              out.push(item as string);
            }
          }
          return out;
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

  /** 追加一条历史：去重置顶、上限 10（review E17：结果页重搜/聚合页也记入历史） */
  static async remember(context: common.Context | undefined, keyword: string): Promise<void> {
    const kw = keyword.trim();
    if (context === undefined || kw === '') {
      return;
    }
    const old = await SearchHistoryStore.load(context);
    const next: string[] = [kw];
    for (const h of old) {
      if (h !== kw && next.length < 10) {
        next.push(h);
      }
    }
    await SearchHistoryStore.save(context, next);
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
    case 'orgs':
      return 'USER';
    default:
      return 'REPOSITORY';
  }
}

export class SearchService {
  /** 聚合结果页：6 路单请求 + code 全文（REST 兜底内容） */
  static async fetchOverview(token: string, keyword: string): Promise<SearchOverviewData> {
    const q = keyword.trim();
    const variables: Record<string, Object> = {
      'q': q,
      'issueQ': buildSearchQuery('issues', q),
      'prQ': buildSearchQuery('prs', q),
      'userQ': buildSearchQuery('people', q),
      'orgQ': buildSearchQuery('orgs', q),
      'first': 3
    };
    const data = await graphql(OVERVIEW_QUERY, variables, token);
    const overview = mapSearchOverview(data);
    const rawPage = await CodeSearchService.fetchCodeRaw(token, q, 1, 3);
    const repos: string[] = [];
    for (const raw of rawPage.raws) {
      repos.push(raw.repoFullName);
    }
    const avatarMap = await SearchService.loadCodeAvatars(token, repos);
    overview.codeFiles = await CodeSearchService.buildCodeResults(rawPage.raws, avatarMap, token);
    return overview;
  }

  /**
   * Repository/Issue/PR/User/Org 搜索（GraphQL search，type 分派，分页）。
   * kind='code' 时走 REST /search/code（正文高亮见 CodeSearchService）。
   */
  static async fetchSearchResults(token: string, kind: SearchEntryKind, keyword: string, after: string = ''): Promise<SearchResultPage> {
    const variables: Record<string, Object> = {
      'query': buildSearchQuery(kind, keyword),
      'type': searchGqlType(kind),
      'first': 20
    };
    if (after !== '') {
      variables['after'] = after;
    }
    const data = await graphql(SEARCH_ALL_QUERY, variables, token);
    return mapSearchResults(data);
  }

  /** 代码仓库 owner 头像查询（动态别名；最多 8 个仓库，其余空头像） */
  static async loadCodeAvatars(token: string, repoFullNames: string[]): Promise<Record<string, string>> {
    const names: string[] = [];
    for (const n of repoFullNames) {
      if (names.indexOf(n) < 0) {
        names.push(n);
      }
    }
    const avatarMap: Record<string, string> = {};
    if (names.length === 0) {
      return avatarMap;
    }
    let query = 'query RepoAvatars(';
    const variables: Record<string, Object> = {};
    let fields = '';
    for (let i = 0; i < names.length; i++) {
      const full = names[i];
      const slash = full.indexOf('/');
      const owner = slash >= 0 ? full.substring(0, slash) : '';
      const name = slash >= 0 ? full.substring(slash + 1) : full;
      variables[`o${i}`] = owner;
      variables[`n${i}`] = name;
      query += `$o${i}: String!, $n${i}: String!`;
      fields += ` r${i}: repository(owner: $o${i}, name: $n${i}) { owner { avatarUrl(size: 48) } }`;
      if (i < names.length - 1) {
        query += ', ';
      }
    }
    query += `) {${fields} }`;
    // 头像补全属装饰性数据：任一仓库已删/改名（索引滞后）返回 200+errors 会整单抛出，
    // 这里 catch 降级为空头像，不击穿搜索主流程（review G3）
    let data: JsonMap | null = null;
    try {
      data = await graphql(query, variables, token);
    } catch (e) {
      return avatarMap;
    }
    if (data === null) {
      return avatarMap;
    }
    for (let i = 0; i < names.length; i++) {
      const repo = Json.obj(data, `r${i}`);
      if (repo !== null) {
        const owner = Json.obj(repo, 'owner');
        avatarMap[names[i]] = owner !== null ? Json.str(owner, 'avatarUrl') : '';
      }
    }
    return avatarMap;
  }

  /** 代码搜索（REST text-match；分页 page） */
  static async fetchCodeResults(token: string, keyword: string, page: number = 1): Promise<CodeSearchPage> {
    const rawPage = await CodeSearchService.fetchCodeRaw(token, keyword.trim(), page, 10);
    const repos: string[] = [];
    for (const raw of rawPage.raws) {
      repos.push(raw.repoFullName);
    }
    const avatarMap = await SearchService.loadCodeAvatars(token, repos);
    const files = await CodeSearchService.buildCodeResults(rawPage.raws, avatarMap, token);
    return { files: files, hasMore: page * 10 < rawPage.totalCount };
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
