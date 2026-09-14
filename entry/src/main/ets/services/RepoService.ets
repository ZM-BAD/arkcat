/**
 * 仓库详情服务（Spec 006）：详情查询 + Star/Fork mutation + Spec 053 社交列表（stargazers/forks）
 * + Spec 054 社区列表（contributors/watchers）+ Spec 055 许可证。
 */
import { graphql, restGet, ApiError } from './GitHttpClient';
import { contributorCount } from './ExploreService';
import { Json, JsonMap } from '../utils/Json';
import { RepoDetail, mapRepoDetail } from '../models/RepoDetailModels';
import { StargazerPage, ForkPage, PeoplePage, mapStargazerPage, mapForkPage, mapWatcherPage, mapContributorPage } from '../models/RepoSocialModels';
import { LicenseInfo, mapLicenseInfo } from '../models/RepoLicenseModels';

const REPO_QUERY = `
query RepositoryDetail($owner: String!, $name: String!) {
  viewer { login }
  repository(owner: $owner, name: $name) {
    id
    name
    nameWithOwner
    description
    stargazerCount
    forkCount
    viewerHasStarred
    watchers { totalCount }
    owner { avatarUrl login }
    licenseInfo { name spdxId }
    # 详情页头部链接行（bio 下，2026-09-14）
    homepageUrl
    repositoryTopics(first: 10) { nodes { topic { name } } }
    readme: object(expression: "HEAD:README.md") { ... on Blob { text } }
    readmeLower: object(expression: "HEAD:readme.md") { ... on Blob { text } }
    readmeCap: object(expression: "HEAD:Readme.md") { ... on Blob { text } }
    fileTree: object(expression: "HEAD:") {
      ... on Tree { entries { name type } }
    }
    languages(first: 10, orderBy: { field: SIZE, direction: DESC }) {
      totalSize
      edges { size node { name color } }
    }
    defaultBranchRef {
      name
      target { ... on Commit { history(first: 1) { nodes { messageHeadline } } } }
    }
    issues { totalCount }
    pullRequests { totalCount }
    # 详情页 Discussions 行：仓库开启 Discussions 才显示（2026-09-14）
    hasDiscussionsEnabled
    discussions { totalCount }
    # 详情页 Issues/PRs 行的计数 = 列表页默认筛选（State=Open）下的数量（2026-09-14；
    # Repository 无 openIssues 计数字段，用连接的 states 参数）
    openIssues: issues(states: OPEN) { totalCount }
    openPullRequests: pullRequests(states: OPEN) { totalCount }
    releases { totalCount }
  }
}`;

const ADD_STAR_MUTATION = `
mutation AddStar($starrableId: ID!) {
  addStar(input: { starrableId: $starrableId }) { starrable { viewerHasStarred } }
}`;

const REMOVE_STAR_MUTATION = `
mutation RemoveStar($starrableId: ID!) {
  removeStar(input: { starrableId: $starrableId }) { starrable { viewerHasStarred } }
}`;

const CREATE_FORK_MUTATION = `
mutation ForkRepo($repositoryId: ID!) {
  createFork(input: { repositoryId: $repositoryId }) { repository { nameWithOwner } }
}`;

const STARGAZERS_QUERY = `
query RepoStargazers($owner: String!, $name: String!, $first: Int = 50, $after: String) {
  repository(owner: $owner, name: $name) {
    stargazers(first: $first, after: $after,
      orderBy: { field: STARRED_AT, direction: DESC }) {
      pageInfo { hasNextPage endCursor }
      nodes { login name bio avatarUrl }
    }
  }
}`;

const FORKS_QUERY = `
query RepoForks($owner: String!, $name: String!, $first: Int = 50, $after: String) {
  repository(owner: $owner, name: $name) {
    forks(first: $first, after: $after) {
      pageInfo { hasNextPage endCursor }
      nodes {
        name description stargazerCount
        primaryLanguage { name color }
        parent { name owner { login } }
        owner { login avatarUrl }
      }
    }
  }
}`;

const WATCHERS_QUERY = `
query RepoWatchers($owner: String!, $name: String!, $first: Int = 50, $after: String) {
  repository(owner: $owner, name: $name) {
    watchers(first: $first, after: $after) {
      pageInfo { hasNextPage endCursor }
      nodes { login name bio avatarUrl }
    }
  }
}`;

const LICENSE_QUERY = `
query RepoLicense($owner: String!, $name: String!) {
  repository(owner: $owner, name: $name) {
    licenseInfo { name spdxId body }
  }
}`;

/** REST 贡献者一页大小；响应长度达此值视为可能还有下一页 */
const CONTRIBUTORS_PER_PAGE = 50;

export class RepoService {
  /** 拉取仓库详情聚合 */
  static async fetchRepoDetail(token: string, owner: string, name: string): Promise<RepoDetail> {
    const variables: Record<string, Object> = { 'owner': owner, 'name': name };
    const data = await graphql(REPO_QUERY, variables, token);
    return mapRepoDetail(data);
  }

  /** Star/取消 Star，返回操作后的 viewerHasStarred */
  static async toggleStar(token: string, repoId: string, starred: boolean): Promise<boolean> {
    const variables: Record<string, Object> = { 'starrableId': repoId };
    const data = await graphql(starred ? REMOVE_STAR_MUTATION : ADD_STAR_MUTATION, variables, token);
    // 任一 mutation 返回即视为成功，状态以入参取反为准
    return !starred;
  }

  /** Fork 仓库 */
  static async createFork(token: string, repoId: string): Promise<void> {
    const variables: Record<string, Object> = { 'repositoryId': repoId };
    await graphql(CREATE_FORK_MUTATION, variables, token);
  }

  /** Stargazers 一页（Spec 053） */
  static async fetchStargazers(token: string, owner: string, name: string, cursor: string): Promise<StargazerPage> {
    const variables: Record<string, Object> = { 'owner': owner, 'name': name, 'first': 50 };
    if (cursor !== '') {
      variables['after'] = cursor;
    }
    const data = await graphql(STARGAZERS_QUERY, variables, token);
    return mapStargazerPage(data);
  }

  /** Forks 一页（Spec 053） */
  static async fetchForks(token: string, owner: string, name: string, cursor: string): Promise<ForkPage> {
    const variables: Record<string, Object> = { 'owner': owner, 'name': name, 'first': 50 };
    if (cursor !== '') {
      variables['after'] = cursor;
    }
    const data = await graphql(FORKS_QUERY, variables, token);
    return mapForkPage(data);
  }

  /** Watchers 一页（Spec 054） */
  static async fetchWatchers(token: string, owner: string, name: string, cursor: string): Promise<PeoplePage> {
    const variables: Record<string, Object> = { 'owner': owner, 'name': name, 'first': 50 };
    if (cursor !== '') {
      variables['after'] = cursor;
    }
    const data = await graphql(WATCHERS_QUERY, variables, token);
    return mapWatcherPage(data);
  }

  /**
   * Contributors 一页（Spec 054）：REST /contributors 取贡献数降序的 login 列表，
   * 再 GraphQL 单请求多 alias 批量补全 name/bio/avatarUrl；404（无贡献者）视为空态。
   */
  static async fetchContributors(token: string, owner: string, name: string, page: string): Promise<PeoplePage> {
    const pageNum = Number(page) || 1;
    const path = `/repos/${owner}/${name}/contributors?per_page=${CONTRIBUTORS_PER_PAGE}&page=${pageNum}&anon=0`;
    let restNodes: JsonMap[] = [];
    try {
      const resp = await restGet(path, token);
      // GitHub 对空仓库返回 204/空 body：视为无贡献者空态而非解析错误（review C6）
      if (resp.code === 204 || resp.body === '') {
        return { users: [], hasNextPage: false, endCursor: '' };
      }
      const parsed: Object | null = JSON.parse(resp.body);
      if (Array.isArray(parsed)) {
        for (const node of parsed as Object[]) {
          restNodes.push(node as JsonMap);
        }
      }
    } catch (e) {
      if (e instanceof ApiError) {
        if (e.code === 404) {
          return { users: [], hasNextPage: false, endCursor: '' };
        }
        throw e;
      }
      throw new Error(`Failed to fetch contributors: ${e}`);
    }
    const meta = await fetchContributorMeta(token, restNodes);
    return mapContributorPage(restNodes, meta, pageNum);
  }

  /**
   * 贡献者总数（详情页 More 区 Contributors 行右侧计数，2026-09-14）：
   * GraphQL 无字段，REST per_page=1 走 Link 头 last 页码（与 054 列表 anon=0 口径一致）；
   * 空仓库 404/204 由调用方降级为不显示数字。
   */
  static async fetchContributorCount(token: string, owner: string, name: string): Promise<number> {
    const resp = await restGet(`/repos/${owner}/${name}/contributors?per_page=1&anon=0`, token);
    return contributorCount(resp.body, resp.link ?? '');
  }

  /** License 信息（Spec 055）；仓库未声明许可证返回 null */
  static async fetchLicense(token: string, owner: string, name: string): Promise<LicenseInfo | null> {
    const variables: Record<string, Object> = { 'owner': owner, 'name': name };
    const data = await graphql(LICENSE_QUERY, variables, token);
    return mapLicenseInfo(data);
  }
}

/** 单请求多 alias 批量查询 user(login)（login 由 GitHub API 提供，仅含安全字符） */
async function fetchContributorMeta(token: string, restNodes: JsonMap[]): Promise<Map<string, JsonMap>> {
  const logins: string[] = [];
  for (const raw of restNodes) {
    const login = Json.str(raw, 'login');
    if (login !== '') {
      logins.push(login);
    }
  }
  if (logins.length === 0) {
    return new Map<string, JsonMap>();
  }
  let query = 'query ContributorsMeta {\n';
  for (let i = 0; i < logins.length; i++) {
    query += `u${i}: user(login: "${logins[i]}") { login name bio avatarUrl }\n`;
  }
  query += '}';
  try {
    const data = await graphql(query, null, token);
    const meta = new Map<string, JsonMap>();
    for (let i = 0; i < logins.length; i++) {
      const item: Object | undefined = data[`u${i}`];
      if (item !== undefined && item !== null) {
        meta.set(logins[i], item as JsonMap);
      }
    }
    return meta;
  } catch (e) {
    // 元信息补全失败：降级 REST-only（login+头像），不阻断列表
    return new Map<string, JsonMap>();
  }
}
