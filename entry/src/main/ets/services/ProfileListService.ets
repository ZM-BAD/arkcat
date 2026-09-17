/**
 * Profile 列表链路服务（Spec 034-037）：用户列表（followers/following）、组织列表、
 * 组织主页、通用仓库列表（用户/组织）。
 *
 * 权限策略：Organizations(Organization 类型)的 GraphQL 字段要求 read:org scope，
 * 组织列表/主页以 REST 为主（公开字段无需额外 scope）：
 * 组织列表 = /users/{login}/orgs；组织主页 = /orgs/{login} + /repos/{login}/.github/readme；
 * 组织仓库列表 = GraphQL 优先（有权 token 享受完整筛选/分页），失败降级 REST 一页 100 +
 * 客户端语言/排序。Pinned（仅 GraphQL 供给）失败时清空隐藏。
 */
import { graphql, restGet } from './GitHttpClient';
import { withFallback } from 'graphql';
import { Json, JsonMap } from '../utils/Json';
import {
  UserListPage, OrgListPage, OrgProfile, OrgSummary, RepoListPage, mapUserListPage
} from '../models/ProfileModels';
import { RepoSummary, filterReposByType, mapRepo } from '../models/GitHubModels';
import { LANGUAGE_COLORS } from '../models/LanguageColors';
import { FRAG_PAGE_INFO } from './GqlFragments';

const ORG_REST_PAGE_LIMIT = 100;

const USER_FOLLOWERS_QUERY = `
query UserFollowers($login: String!, $first: Int = 25, $after: String) {
  user(login: $login) {
    followers(first: $first, after: $after) {
      ${FRAG_PAGE_INFO}
      nodes { login name bio avatarUrl }
    }
  }
}`;

const USER_FOLLOWING_QUERY = `
query UserFollowing($login: String!, $first: Int = 25, $after: String) {
  user(login: $login) {
    following(first: $first, after: $after) {
      ${FRAG_PAGE_INFO}
      nodes { login name bio avatarUrl }
    }
  }
}`;

// Pinned 仅 GraphQL 提供；Organization.pinnedItems 无 read:org 时可能失败，失败即隐藏
const ORG_PINNED_QUERY = `
query OrgPinned($login: String!) {
  organization(login: $login) {
    pinnedItems(first: 6, types: [REPOSITORY]) {
      nodes { ... on Repository {
        id nameWithOwner description stargazerCount forkCount
        primaryLanguage { name color }
      } }
    }
  }
}`;

const REPO_LIST_FIELDS = `
      ${FRAG_PAGE_INFO}
      nodes { ... on Repository {
        id name nameWithOwner description stargazerCount forkCount isPrivate
        isArchived isFork isMirror isTemplate
        primaryLanguage { name color }
      } }
`;

// 注（2026-09-13 实测修正）：repositories 连接**支持** privacy/visibility/isArchived/isFork
// （此前误记为已移除，导致 Type 6 项白走客户端）；**不支持** filterByLanguage，也没有 isMirror/isTemplate。
// 故：Type 的可下推项走服务端（见 buildRepoTypeVars），语言、Mirror/Template 仍在客户端过滤。
const ORG_REPOS_QUERY = `
query OrgRepositories($login: String!, $first: Int = 25, $after: String,
  $orderBy: RepositoryOrder, $isArchived: Boolean, $isFork: Boolean,
  $privacy: RepositoryPrivacy) {
  organization(login: $login) {
    repositories(first: $first, after: $after, orderBy: $orderBy,
      isArchived: $isArchived, isFork: $isFork, privacy: $privacy) {
${REPO_LIST_FIELDS}
    }
  }
}`;

const USER_REPOS_QUERY = `
query UserRepositories($login: String!, $first: Int = 25, $after: String,
  $orderBy: RepositoryOrder, $isArchived: Boolean, $isFork: Boolean,
  $privacy: RepositoryPrivacy) {
  user(login: $login) {
    repositories(first: $first, after: $after, orderBy: $orderBy,
      isArchived: $isArchived, isFork: $isFork, privacy: $privacy) {
${REPO_LIST_FIELDS}
    }
  }
}`;

/** 排序映射：field 名（PUSHED_AT/STARGAZERS/NAME/UPDATED_AT）+ 方向 */
export interface RepoOrder {
  field: string;
  direction: string;
}

/**
 * 官方 Sort by 8 项 → 服务端 orderBy（Spec 037 仓库列表时；键为排序面板选项 key）。
 * 未知键回退默认「Recently pushed」（PUSHED_AT DESC）。
 */
export function repoOrderFromKey(sortKey: string): RepoOrder {
  const orders: Record<string, RepoOrder> = {
    'pushed_desc': { field: 'PUSHED_AT', direction: 'DESC' },
    'pushed_asc': { field: 'PUSHED_AT', direction: 'ASC' },
    'created_desc': { field: 'CREATED_AT', direction: 'DESC' },
    'created_asc': { field: 'CREATED_AT', direction: 'ASC' },
    'name_asc': { field: 'NAME', direction: 'ASC' },
    'name_desc': { field: 'NAME', direction: 'DESC' },
    'stars_desc': { field: 'STARGAZERS', direction: 'DESC' },
    'stars_asc': { field: 'STARGAZERS', direction: 'ASC' }
  };
  const order = orders[sortKey];
  return order !== undefined ? order : { field: 'PUSHED_AT', direction: 'DESC' };
}

/** 常用语言色（REST 兜底无 language color 字段，数据色板见 models/LanguageColors.ets） */

export class ProfileListService {
  /** followers/following 用户列表 */
  static async fetchUserList(token: string, login: string, kind: string, cursor: string): Promise<UserListPage> {
    const variables: Record<string, Object> = { 'login': login, 'first': 25 };
    if (cursor !== '') {
      variables['after'] = cursor;
    }
    const query = kind === 'following' ? USER_FOLLOWING_QUERY : USER_FOLLOWERS_QUERY;
    const data = await graphql(query, variables, token);
    return mapUserListPage(data, kind === 'following' ? 'following' : 'followers');
  }

  /** 用户 → 组织列表（REST 公开数据，无 scope 要求；一页 100 条） */
  static async fetchOrganizations(token: string, login: string, cursor: string): Promise<OrgListPage> {
    const resp = await restGet(`/users/${login}/orgs?per_page=${ORG_REST_PAGE_LIMIT}`, token);
    const orgs: OrgSummary[] = [];
    const parsed: Object | null = JSON.parse(resp.body);
    if (Array.isArray(parsed)) {
      for (const node of parsed as Object[]) {
        const item = node as JsonMap;
        orgs.push({
          login: Json.str(item, 'login'),
          name: Json.str(item, 'name'),
          description: Json.str(item, 'description'),
          avatarUrl: Json.str(item, 'avatar_url')
        });
      }
    }
    // REST 一页 100 条即为上限，无翻页
    return { orgs: orgs, hasNextPage: false, endCursor: '' };
  }

  /** 组织主页：REST /orgs/{login} 主数据 + README REST + Pinned GraphQL（失败清空）+ 跟随态探测 */
  static async fetchOrgProfile(token: string, login: string): Promise<OrgProfile> {
    let org: OrgProfile = {
      login: login,
      name: '',
      avatarUrl: '',
      description: '',
      websiteUrl: '',
      twitterUsername: '',
      email: '',
      pinned: [],
      repositoriesCount: 0,
      readmeText: '',
      viewerIsFollowing: false
    };
    try {
      const resp = await restGet(`/orgs/${login}`, token);
      const orgJson = Json.parse(resp.body);
      if (orgJson !== null) {
        org = {
          login: Json.str(orgJson, 'login'),
          name: Json.str(orgJson, 'name'),
          avatarUrl: Json.str(orgJson, 'avatar_url'),
          description: Json.str(orgJson, 'description'),
          websiteUrl: Json.str(orgJson, 'blog'),
          twitterUsername: Json.str(orgJson, 'twitter_username'),
          email: Json.str(orgJson, 'email'),
          pinned: [],
          repositoriesCount: Json.num(orgJson, 'public_repos'),
          readmeText: '',
          viewerIsFollowing: false
        };
      }
    } catch (e) {
      // 主数据失败直接抛错，由页面 StateView 呈现错误+重试（review D12：空骨架会让错误态不可达）
      throw e instanceof Error ? e : new Error(`Failed to fetch org profile: ${e}`);
    }
    org.pinned = await ProfileListService.fetchOrgPinned(token, login);
    org.readmeText = await ProfileListService.fetchOrgReadme(token, login);
    // GitHub 无组织关注 API（review D1）：viewerIsFollowing 恒 false，不再探测避免必 404 的请求
    org.viewerIsFollowing = false;
    return org;
  }

  /** 组织 Pinned：GraphQL（pinnedItems 权限受限时返回空 → 页面隐藏区块）；装饰性数据软失败为空列表 */
  private static async fetchOrgPinned(token: string, login: string): Promise<RepoSummary[]> {
    const raw = ProfileListService.fetchOrgPinnedRaw(token, login);
    return withFallback(raw, []);
  }

  private static async fetchOrgPinnedRaw(token: string, login: string): Promise<RepoSummary[]> {
    const variables: Record<string, Object> = { 'login': login };
    const data = await graphql(ORG_PINNED_QUERY, variables, token);
    const orgNode = Json.obj(data, 'organization') ?? ({} as JsonMap);
    const pinnedRaw = Json.obj(orgNode, 'pinnedItems');
    const pinned: RepoSummary[] = [];
    if (pinnedRaw !== null) {
      for (const node of Json.arr(pinnedRaw, 'nodes')) {
        pinned.push(mapRepo(node as JsonMap));
      }
    }
    return pinned;
  }

  /** 组织 README：.github 仓库 profile/README.md（官方组织主页内容）→ 根 README.md 兜底；404 → '' */
  private static async fetchOrgReadme(token: string, login: string): Promise<string> {
    try {
      const resp = await restGet(`/repos/${login}/.github/contents/profile/README.md`, token,
        'application/vnd.github.raw');
      return resp.body;
    } catch (e) {
      // 兼容旧格式：.github 仓库根 README.md
    }
    try {
      const resp = await restGet(`/repos/${login}/.github/readme`, token, 'application/vnd.github.raw');
      return resp.body;
    } catch (e) {
      return '';
    }
  }

  /** 通用仓库列表：GraphQL 优先；组织模式 GraphQL 失败（read:org 缺失）→ REST 一页 100 + 客户端筛选 */
  static async fetchRepoList(token: string, owner: string, mode: string, cursor: string,
    order: RepoOrder, lang: string, typeKey: string): Promise<RepoListPage> {
    const page = await ProfileListService.fetchRepoListGql(token, owner, mode, cursor, order, typeKey);
    // 客户端兜底过滤：服务端已下推的项会被再次命中（幂等），Mirror/Template 与语言靠它生效
    return ProfileListService.filterRepoPage(page, lang, typeKey);
  }

  /** 客户端语言/类型筛选（已加载数据内；翻页后追加） */
  private static filterRepoPage(page: RepoListPage, lang: string, typeKey: string): RepoListPage {
    const byLang: RepoSummary[] = [];
    for (const repo of page.repos) {
      if (lang !== '' && repo.primaryLanguage !== lang) {
        continue;
      }
      byLang.push(repo);
    }
    return {
      repos: filterReposByType(byLang, typeKey),
      hasNextPage: page.hasNextPage,
      endCursor: page.endCursor
    };
  }

  /**
   * Type 8 项 → 服务端 GraphQL 参数（实测可用项）；不可下推的项（mirror/template、
   * 以及 source 的 mirror 部分）仍由 filterReposByType 在客户端兜底，语义保持一致。
   */
  private static buildRepoTypeVars(typeKey: string, variables: Record<string, Object>): void {
    if (typeKey === 'archived') {
      variables['isArchived'] = true;
    } else if (typeKey === 'fork') {
      variables['isFork'] = true;
    } else if (typeKey === 'source') {
      variables['isFork'] = false;
      variables['isArchived'] = false;
    } else if (typeKey === 'private') {
      variables['privacy'] = 'PRIVATE';
    } else if (typeKey === 'public') {
      variables['privacy'] = 'PUBLIC';
    }
    // mirror / template / all：无可下推参数，交由客户端过滤
  }

  /** Type 8 项 → REST 兜底 type=（仅 4 项可映射；其余靠客户端过滤） */
  private static repoRestType(typeKey: string): string {
    if (typeKey === 'public') {
      return 'public';
    }
    if (typeKey === 'private') {
      return 'private';
    }
    if (typeKey === 'fork') {
      return 'forks';
    }
    if (typeKey === 'source') {
      return 'sources';
    }
    return 'all';
  }

  /** GraphQL 仓库列表（用户/组织；orderBy + 可下推的 Type 参数；语言/Mirror/Template 客户端过滤） */
  private static async fetchRepoListGql(token: string, owner: string, mode: string, cursor: string,
    order: RepoOrder, typeKey: string): Promise<RepoListPage> {
    const variables: Record<string, Object> = { 'login': owner, 'first': 25 };
    if (cursor !== '') {
      variables['after'] = cursor;
    }
    const orderObj: Record<string, Object> = { 'field': order.field, 'direction': order.direction };
    variables['orderBy'] = orderObj;
    ProfileListService.buildRepoTypeVars(typeKey, variables);
    if (mode !== 'org') {
      const data = await graphql(USER_REPOS_QUERY, variables, token);
      return ProfileListService.mapRepoListPage(data, 'user');
    }
    try {
      const data = await graphql(ORG_REPOS_QUERY, variables, token);
      return ProfileListService.mapRepoListPage(data, 'org');
    } catch (e) {
      // read:org 缺失等场景 → REST 兜底（一页 100 + 客户端排序后客户端过滤）
      // 服务端 sort 映射（review G6：此前未传 sort，pushed/updated 静默失效变默认 created 序）
      const sortMap: Record<string, string> = {
        'PUSHED_AT': 'pushed', 'UPDATED_AT': 'updated', 'NAME': 'full_name', 'CREATED_AT': 'created'
      };
      const sort = sortMap[order.field] ?? 'created';
      const dir = order.direction === 'ASC' ? 'asc' : 'desc';
      const restType = ProfileListService.repoRestType(typeKey);
      const resp = await restGet(
        `/orgs/${owner}/repos?per_page=${ORG_REST_PAGE_LIMIT}&type=${restType}&sort=${sort}&direction=${dir}`, token);
      return ProfileListService.mapOrgReposRest(resp.body, order);
    }
  }

  /** REST 兜底解析：一页 100（服务端 sort=pushed/updated），STARGAZERS/NAME 客户端排 */
  private static mapOrgReposRest(body: string, order: RepoOrder): RepoListPage {
    const items: RepoSummary[] = [];
    const parsed: Object | null = JSON.parse(body);
    if (Array.isArray(parsed)) {
      for (const node of parsed as Object[]) {
        const item = node as JsonMap;
        const language = Json.str(item, 'language');
        const owner = Json.obj(item, 'owner');
        items.push({
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
    }
    if (order.field === 'STARGAZERS' || order.field === 'NAME') {
      items.sort((a: RepoSummary, b: RepoSummary): number => {
        const cmp = order.field === 'STARGAZERS'
          ? a.stargazerCount - b.stargazerCount
          : a.name.localeCompare(b.name);
        return order.direction === 'ASC' ? cmp : -cmp;
      });
    }
    return { repos: items, hasNextPage: false, endCursor: '' };
  }

  private static mapRepoListPage(data: JsonMap, mode: string): RepoListPage {
    const holder = Json.obj(data, mode === 'org' ? 'organization' : 'user') ?? ({} as JsonMap);
    const conn = Json.obj(holder, 'repositories') ?? ({} as JsonMap);
    const pageInfo = Json.obj(conn, 'pageInfo') ?? ({} as JsonMap);
    const repos: RepoSummary[] = [];
    for (const node of Json.arr(conn, 'nodes')) {
      repos.push(mapRepo(node as JsonMap));
    }
    return {
      repos: repos,
      hasNextPage: Json.bool(pageInfo, 'hasNextPage'),
      endCursor: Json.str(pageInfo, 'endCursor')
    };
  }
}
