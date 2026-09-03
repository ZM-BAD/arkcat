/**
 * Home 工作区列表服务（Spec 017-023）。
 * 跨仓库 Issues/PRs/Discussions 走 GraphQL search（type: ISSUE/PR/DISCUSSION）；
 * Projects/TopRepos/Orgs/Starred 走 viewer 连接。
 */
import { graphql } from './GitHttpClient';
import { Json, JsonMap } from '../utils/Json';
import {
  WorkIssuesPage, WorkPrsPage, WorkDiscussionsPage, WorkProjectsPage,
  WorkOrgsPage, WorkTopReposPage, WorkStarredPage, WorkUserList, WorkListDetail,
  buildWorkIssuesQuery, buildWorkPrsQuery, buildWorkDiscussionsQuery,
  mapWorkIssuesPage, mapWorkPrsPage, mapWorkDiscussionsPage,
  mapWorkProjectsPage, mapWorkOrgsPage, mapWorkTopReposPage, mapWorkStarredPage,
  mapWorkUserLists, mapWorkListDetail
} from '../models/WorkModels';

const VIEWER_LOGIN_QUERY = `
query ViewerLogin {
  viewer { login }
}`;

const CREATE_LIST_MUTATION = `
mutation CreateUserList($name: String!, $description: String) {
  createUserList(input: { name: $name, description: $description }) { clientMutationId }
}`;

const USER_LISTS_QUERY = `
query ViewerLists($first: Int = 50) {
  viewer {
    lists(first: $first) {
      nodes {
        id name description
        items(first: 100) {
          totalCount
          nodes { ... on Repository { id } }
        }
      }
    }
  }
}`;

const UPDATE_USER_LISTS_FOR_ITEM_MUTATION = `
mutation UpdateUserListsForItem($itemId: ID!, $listIds: [ID!]!) {
  updateUserListsForItem(input: { itemId: $itemId, listIds: $listIds }) { clientMutationId }
}`;

const LIST_DETAIL_QUERY = `
query ListDetail($id: ID!, $first: Int = 100) {
  viewer { login avatarUrl }
  node(id: $id) {
    ... on UserList {
      id name description
      items(first: $first) {
        totalCount
        nodes { ... on Repository {
          id name nameWithOwner description stargazerCount
          owner { login avatarUrl }
          primaryLanguage { name color }
        } }
      }
    }
  }
}`;

const UPDATE_USER_LIST_MUTATION = `
mutation UpdateUserList($listId: ID!, $name: String!, $description: String) {
  updateUserList(input: { listId: $listId, name: $name, description: $description }) { clientMutationId }
}`;

const DELETE_USER_LIST_MUTATION = `
mutation DeleteUserList($listId: ID!) {
  deleteUserList(input: { listId: $listId }) { clientMutationId }
}`;

const WORK_ISSUES_QUERY = `
query WorkIssues($query: String!, $first: Int = 25, $after: String) {
  search(query: $query, type: ISSUE, first: $first, after: $after) {
    issueCount
    pageInfo { hasNextPage endCursor }
    nodes {
      ... on Issue {
        id number title state stateReason createdAt
        repository { nameWithOwner }
        labels(first: 5) { nodes { name color } }
        comments { totalCount }
      }
    }
  }
}`;

const WORK_PRS_QUERY = `
query WorkPullRequests($query: String!, $first: Int = 25, $after: String) {
  search(query: $query, type: ISSUE, first: $first, after: $after) {
    pageInfo { hasNextPage endCursor }
    nodes {
      ... on PullRequest {
        id number title state merged createdAt
        repository { nameWithOwner }
        comments { totalCount }
        reviewRequests(first: 10) { totalCount }
        statusCheckRollup { state }
      }
    }
  }
}`;

const WORK_DISCUSSIONS_QUERY = `
query WorkDiscussions($query: String!, $first: Int = 25, $after: String) {
  search(query: $query, type: DISCUSSION, first: $first, after: $after) {
    pageInfo { hasNextPage endCursor }
    nodes {
      ... on Discussion {
        id number title createdAt
        repository { nameWithOwner }
        category { name }
        comments { totalCount }
      }
    }
  }
}`;

const WORK_PROJECTS_QUERY = `
query WorkProjects($first: Int = 30, $after: String) {
  viewer {
    login
    projectsV2(first: $first, after: $after) {
      totalCount
      pageInfo { hasNextPage endCursor }
      nodes {
        title number closed template createdAt updatedAt
        owner { ... on Organization { login } ... on User { login } }
      }
    }
  }
}`;

const WORK_TOP_REPOS_QUERY = `
query WorkTopRepositories($first: Int = 50, $after: String) {
  viewer {
    repositories(first: $first, after: $after, orderBy: { field: PUSHED_AT, direction: DESC }) {
      totalCount
      pageInfo { hasNextPage endCursor }
      nodes {
        id name nameWithOwner isArchived isFork isMirror isTemplate visibility
        owner { login avatarUrl }
      }
    }
  }
}`;

const WORK_ORGS_QUERY = `
query WorkOrganizations($first: Int = 50, $after: String) {
  viewer {
    organizations(first: $first, after: $after) {
      totalCount
      pageInfo { hasNextPage endCursor }
      nodes { login name avatarUrl }
    }
  }
}`;

const WORK_STARRED_QUERY = `
query WorkStarred($first: Int = 30, $after: String) {
  viewer {
    login
    starredRepositories(first: $first, after: $after) {
      totalCount
      pageInfo { hasNextPage endCursor }
      nodes {
        id name nameWithOwner description stargazerCount
        owner { login avatarUrl }
        primaryLanguage { name color }
      }
    }
  }
}`;

// 用户星标（Spec 035：Profile Starred 入口，任意用户 profile 可看）
const USER_STARRED_QUERY = `
query UserStarred($login: String!, $first: Int = 30, $after: String) {
  viewer { login }
  user(login: $login) {
    login
    starredRepositories(first: $first, after: $after) {
      totalCount
      pageInfo { hasNextPage endCursor }
      nodes {
        id name nameWithOwner description stargazerCount
        owner { login avatarUrl }
        primaryLanguage { name color }
      }
    }
  }
}`;

export class WorkService {
  /** 工作区 Issue 列表（search type: ISSUE；排序/组织/仓库多选进服务端 qualifier） */
  static async fetchIssues(token: string, state: string, scope: string, visibility: string,
    sortKey: string, orgs: string[], repos: string[], cursor: string): Promise<WorkIssuesPage> {
    const variables: Record<string, Object> = {
      'query': buildWorkIssuesQuery(state, scope, visibility, sortKey, orgs, repos),
      'first': 25
    };
    if (cursor !== '') {
      variables['after'] = cursor;
    }
    const data = await graphql(WORK_ISSUES_QUERY, variables, token);
    return mapWorkIssuesPage(data);
  }

  /** 工作区 PR 列表（search type: PR；排序/组织/仓库多选进服务端 qualifier） */
  static async fetchPrs(token: string, state: string, scope: string, visibility: string,
    sortKey: string, orgs: string[], repos: string[], cursor: string): Promise<WorkPrsPage> {
    const variables: Record<string, Object> = {
      'query': buildWorkPrsQuery(state, scope, visibility, sortKey, orgs, repos),
      'first': 25
    };
    if (cursor !== '') {
      variables['after'] = cursor;
    }
    const data = await graphql(WORK_PRS_QUERY, variables, token);
    return mapWorkPrsPage(data);
  }

  /** 工作区 Discussion 列表（search type: DISCUSSION；排序 Sort: New / Top 时间窗进服务端） */
  static async fetchDiscussions(token: string, state: string, scope: string, unanswered: boolean,
    sortKey: string, cursor: string): Promise<WorkDiscussionsPage> {
    const variables: Record<string, Object> = {
      'query': buildWorkDiscussionsQuery(state, scope, unanswered, sortKey),
      'first': 25
    };
    if (cursor !== '') {
      variables['after'] = cursor;
    }
    const data = await graphql(WORK_DISCUSSIONS_QUERY, variables, token);
    return mapWorkDiscussionsPage(data);
  }

  /** 工作区 Projects（viewer.projectsV2；三态/范围/排序均在客户端） */
  static async fetchProjects(token: string, cursor: string): Promise<WorkProjectsPage> {
    const variables: Record<string, Object> = { 'first': 30 };
    if (cursor !== '') {
      variables['after'] = cursor;
    }
    const data = await graphql(WORK_PROJECTS_QUERY, variables, token);
    return mapWorkProjectsPage(data);
  }

  /** Top Repositories（viewer.repositories 全量，8 项仓库筛选维度在客户端） */
  static async fetchTopRepositories(token: string, cursor: string): Promise<WorkTopReposPage> {
    const variables: Record<string, Object> = { 'first': 50 };
    if (cursor !== '') {
      variables['after'] = cursor;
    }
    const data = await graphql(WORK_TOP_REPOS_QUERY, variables, token);
    return mapWorkTopReposPage(data);
  }

  /** 组织列表（viewer.organizations） */
  static async fetchOrganizations(token: string, cursor: string): Promise<WorkOrgsPage> {
    const variables: Record<string, Object> = { 'first': 50 };
    if (cursor !== '') {
      variables['after'] = cursor;
    }
    const data = await graphql(WORK_ORGS_QUERY, variables, token);
    return mapWorkOrgsPage(data);
  }

  /** viewer login（任何 scope 的 PAT 均可） */
  static async fetchViewerLogin(token: string): Promise<string> {
    const data = await graphql(VIEWER_LOGIN_QUERY, {}, token);
    const viewer = Json.obj(data, 'viewer') ?? ({} as JsonMap);
    return Json.str(viewer, 'login');
  }

  /** 创建星标列表（GraphQL createUserList） */
  static async createList(token: string, name: string, description: string): Promise<void> {
    const variables: Record<string, Object> = { 'name': name, 'description': description };
    await graphql(CREATE_LIST_MUTATION, variables, token);
  }

  /** viewer 的星标列表（名称/数量/前 100 个成员仓库 id） */
  static async fetchUserLists(token: string): Promise<WorkUserList[]> {
    const data = await graphql(USER_LISTS_QUERY, {}, token);
    return mapWorkUserLists(data);
  }

  /** 全量设置某仓库所属的列表集合（toggle = 重发完整 listIds） */
  static async updateUserListsForItem(token: string, repoId: string, listIds: string[]): Promise<void> {
    const variables: Record<string, Object> = { 'itemId': repoId, 'listIds': listIds };
    await graphql(UPDATE_USER_LISTS_FOR_ITEM_MUTATION, variables, token);
  }

  /** 列表详情（node(id) → UserList） */
  static async fetchListDetail(token: string, listId: string): Promise<WorkListDetail> {
    const variables: Record<string, Object> = { 'id': listId };
    const data = await graphql(LIST_DETAIL_QUERY, variables, token);
    return mapWorkListDetail(data);
  }

  /** 重命名/改描述已有列表 */
  static async updateUserList(token: string, listId: string, name: string, description: string): Promise<void> {
    const variables: Record<string, Object> = { 'listId': listId, 'name': name, 'description': description };
    await graphql(UPDATE_USER_LIST_MUTATION, variables, token);
  }

  /** 删除列表（仓库保持星标，仅移出列表） */
  static async deleteUserList(token: string, listId: string): Promise<void> {
    const variables: Record<string, Object> = { 'listId': listId };
    await graphql(DELETE_USER_LIST_MUTATION, variables, token);
  }

  /** 星标仓库列表：同 v1 走 viewer；传入 login 时展示目标用户星标（Spec 035） */
  static async fetchStarred(token: string, cursor: string, login: string = ''): Promise<WorkStarredPage> {
    const variables: Record<string, Object> = { 'first': 30 };
    if (cursor !== '') {
      variables['after'] = cursor;
    }
    if (login !== '') {
      variables['login'] = login;
    }
    const data = await graphql(login !== '' ? USER_STARRED_QUERY : WORK_STARRED_QUERY, variables, token);
    return mapWorkStarredPage(data);
  }
}
