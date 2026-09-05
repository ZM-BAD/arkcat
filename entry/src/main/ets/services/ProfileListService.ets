/**
 * Profile 列表链路服务（Spec 034-037）：用户列表（followers/following）、组织列表、
 * 组织主页、通用仓库列表（用户/组织）。
 *
 * 权限策略：Organizations(Organization 类型)的 GraphQL 字段要求 read:org scope，
 * 而项目 PAT 仅 repo scope——组织数据一律走 REST（公开字段无需额外 scope）：
 * 组织列表 = /users/{login}/orgs；组织主页 = /orgs/{login} + /repos/{login}/.github/readme；
 * 组织仓库列表 = GraphQL 优先（有权 token 享受完整筛选/分页），失败降级 REST 一页 100 +
 * 客户端语言/排序。Pinned（仅 GraphQL 供给）失败时清空隐藏。
 */
import { graphql, restGet } from './GitHttpClient';
import { Json, JsonMap } from '../utils/Json';
import {
  UserListPage, OrgListPage, OrgProfile, OrgSummary, RepoListPage, mapUserListPage
} from '../models/ProfileModels';
import { RepoSummary, mapRepo } from '../models/GitHubModels';
import { LANGUAGE_COLORS } from '../models/LanguageColors';

const ORG_REST_PAGE_LIMIT = 100;

const USER_FOLLOWERS_QUERY = `
query UserFollowers($login: String!, $first: Int = 25, $after: String) {
  user(login: $login) {
    followers(first: $first, after: $after) {
      pageInfo { hasNextPage endCursor }
      nodes { login name bio avatarUrl }
    }
  }
}`;

const USER_FOLLOWING_QUERY = `
query UserFollowing($login: String!, $first: Int = 25, $after: String) {
  user(login: $login) {
    following(first: $first, after: $after) {
      pageInfo { hasNextPage endCursor }
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
      pageInfo { hasNextPage endCursor }
      nodes { ... on Repository {
        id name nameWithOwner description stargazerCount forkCount isPrivate
        primaryLanguage { name color }
      } }
`;

// 注：当前 GitHub schema 的 repositories 连接不再支持 privacy/filterByLanguage 参数，
// 语言与隐私筛选在客户端执行（isPrivate 随行返回）。
const ORG_REPOS_QUERY = `
query OrgRepositories($login: String!, $first: Int = 25, $after: String,
  $orderBy: RepositoryOrder) {
  organization(login: $login) {
    repositories(first: $first, after: $after, orderBy: $orderBy) {
${REPO_LIST_FIELDS}
    }
  }
}`;

const USER_REPOS_QUERY = `
query UserRepositories($login: String!, $first: Int = 25, $after: String,
  $orderBy: RepositoryOrder) {
  user(login: $login) {
    repositories(first: $first, after: $after, orderBy: $orderBy) {
${REPO_LIST_FIELDS}
    }
  }
}`;

/** 排序映射：field 名（PUSHED_AT/STARGAZERS/NAME/UPDATED_AT）+ 方向 */
export interface RepoOrder {
  field: string;
  direction: string;
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

  /** 组织 Pinned：GraphQL（pinnedItems 权限受限时返回空 → 页面隐藏区块） */
  private static async fetchOrgPinned(token: string, login: string): Promise<RepoSummary[]> {
    const variables: Record<string, Object> = { 'login': login };
    try {
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
    } catch (e) {
      return [];
    }
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
    order: RepoOrder, lang: string, privacy: string): Promise<RepoListPage> {
    const page = await ProfileListService.fetchRepoListGql(token, owner, mode, cursor, order);
    return ProfileListService.filterRepoPage(page, lang, privacy);
  }

  /** 客户端语言/隐私筛选（已加载数据内；翻页后追加） */
  private static filterRepoPage(page: RepoListPage, lang: string, privacy: string): RepoListPage {
    const filtered: RepoSummary[] = [];
    for (const repo of page.repos) {
      if (lang !== '' && repo.primaryLanguage !== lang) {
        continue;
      }
      if (privacy === 'private' && !repo.isPrivate) {
        continue;
      }
      if (privacy === 'public' && repo.isPrivate) {
        continue;
      }
      filtered.push(repo);
    }
    return { repos: filtered, hasNextPage: page.hasNextPage, endCursor: page.endCursor };
  }

  /** GraphQL 仓库列表（用户/组织；仅 orderBy 分页——schema 不再支持 filterByLanguage/privacy） */
  private static async fetchRepoListGql(token: string, owner: string, mode: string, cursor: string,
    order: RepoOrder): Promise<RepoListPage> {
    const variables: Record<string, Object> = { 'login': owner, 'first': 25 };
    if (cursor !== '') {
      variables['after'] = cursor;
    }
    const orderObj: Record<string, Object> = { 'field': order.field, 'direction': order.direction };
    variables['orderBy'] = orderObj;
    if (mode !== 'org') {
      const data = await graphql(USER_REPOS_QUERY, variables, token);
      return ProfileListService.mapRepoListPage(data, 'user');
    }
    try {
      const data = await graphql(ORG_REPOS_QUERY, variables, token);
      return ProfileListService.mapRepoListPage(data, 'org');
    } catch (e) {
      // read:org 缺失等场景 → REST 兜底（一页 100 + 客户端排序后客户端过滤）
      const resp = await restGet(`/orgs/${owner}/repos?per_page=${ORG_REST_PAGE_LIMIT}`, token);
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
          ownerAvatarUrl: owner !== null ? Json.str(owner, 'avatar_url') : ''
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
