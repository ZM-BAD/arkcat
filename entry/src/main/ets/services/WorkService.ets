/**
 * Home 工作区列表服务（Spec 017-023）。
 * 跨仓库 Issues/PRs/Discussions 走 GraphQL search（type: ISSUE/PR/DISCUSSION）；
 * Projects/TopRepos/Orgs/Starred 走 viewer 连接。
 */
import { graphql } from './GitHttpClient';
import { fetchAllPages, Page } from 'graphql';
import { Json, JsonMap } from '../utils/Json';
import { FRAG_PAGE_INFO, FRAG_VIEWER_LOGIN } from './GqlFragments';
import {
  WorkIssuesPage, WorkPrsPage, WorkDiscussionsPage, WorkProjectsPage,
  WorkOrgsPage, WorkTopReposPage, WorkStarredPage, WorkUserList, WorkListDetail,
  buildWorkIssuesQuery, buildWorkPrsQuery, buildWorkDiscussionsQuery,
  mapWorkIssuesPage, mapWorkPrsPage, mapWorkDiscussionsPage,
  mapWorkProjectsPage, mapWorkOrgsPage, mapWorkTopReposPage, mapWorkStarredPage,
  mapWorkUserLists, mapWorkListDetail, RepoLabelItem, mapRepoLabels,
  RepoCategoryItem, mapRepoCategories
} from '../models/WorkModels';

const VIEWER_LOGIN_QUERY = `
query ViewerLogin {
  ${FRAG_VIEWER_LOGIN}
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
          ${FRAG_PAGE_INFO}
          nodes { ... on Repository { id } }
        }
      }
    }
  }
}`;

/** 他人 Starred 页 Lists 区（Spec 023 他人视角）：user(login).lists，服务端仅返回公开列表；只读展示不取成员游标 */
const USER_LISTS_BY_LOGIN_QUERY = `
query UserListsByLogin($login: String!, $first: Int = 50) {
  user(login: $login) {
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

const USER_LIST_ITEMS_QUERY = `
query UserListItems($id: ID!, $after: String) {
  node(id: $id) {
    ... on UserList {
      items(first: 100, after: $after) {
        totalCount
        ${FRAG_PAGE_INFO}
        nodes { ... on Repository { id } }
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
      user { login avatarUrl }
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
    ${FRAG_PAGE_INFO}
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
    ${FRAG_PAGE_INFO}
    nodes {
      ... on PullRequest {
        id number title state merged isDraft createdAt
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
    ${FRAG_PAGE_INFO}
    nodes {
      ... on Discussion {
        id number title createdAt
        repository { nameWithOwner }
        category { name }
        comments { totalCount }
        author { login avatarUrl ... on User { name } }
        labels(first: 8) { nodes { name color } }
      }
    }
  }
}`;

const REPO_LABELS_QUERY = `
query RepoLabels($owner: String!, $name: String!) {
  repository(owner: $owner, name: $name) {
    labels(first: 50, orderBy: { field: NAME, direction: ASC }) { nodes { name color } }
  }
}`;

const REPO_DISCUSSION_CATEGORIES_QUERY = `
query RepoDiscussionCategories($owner: String!, $name: String!) {
  repository(owner: $owner, name: $name) {
    discussionCategories(first: 25) { nodes { name description emoji } }
  }
}`;

const WORK_PROJECTS_QUERY = `
query WorkProjects($first: Int = 30, $after: String) {
  viewer {
    login
    projectsV2(first: $first, after: $after) {
      totalCount
      ${FRAG_PAGE_INFO}
      nodes {
        title number closed template createdAt updatedAt
        owner { ... on Organization { login } ... on User { login } }
      }
    }
  }
}`;

const WORK_TOP_REPOS_QUERY = `
query WorkTopRepositories($first: Int = 50, $after: String, $isArchived: Boolean, $isFork: Boolean,
  $privacy: RepositoryPrivacy) {
  viewer {
    repositories(first: $first, after: $after, orderBy: { field: PUSHED_AT, direction: DESC },
      isArchived: $isArchived, isFork: $isFork, privacy: $privacy) {
      totalCount
      ${FRAG_PAGE_INFO}
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
      ${FRAG_PAGE_INFO}
      nodes { login name avatarUrl }
    }
  }
}`;

const WORK_STARRED_QUERY = `
query WorkStarred($first: Int = 30, $after: String) {
  viewer {
    login
    starredRepositories(first: $first, after: $after,
      orderBy: { field: STARRED_AT, direction: DESC }) {
      totalCount
      ${FRAG_PAGE_INFO}
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
  ${FRAG_VIEWER_LOGIN}
  user(login: $login) {
    login
    starredRepositories(first: $first, after: $after,
      orderBy: { field: STARRED_AT, direction: DESC }) {
      totalCount
      ${FRAG_PAGE_INFO}
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
    sortKey: string, cursor: string, repo: string = '', author: string = '', label: string = '',
    category: string = ''): Promise<WorkDiscussionsPage> {
    const variables: Record<string, Object> = {
      'query': buildWorkDiscussionsQuery(state, scope, unanswered, sortKey, repo, author, label, category),
      'first': 25
    };
    if (cursor !== '') {
      variables['after'] = cursor;
    }
    const data = await graphql(WORK_DISCUSSIONS_QUERY, variables, token);
    return mapWorkDiscussionsPage(data);
  }

  /** 仓库 labels 全集（Spec 065：Discussions Label 弹层；公开数据无 scope 要求） */
  static async fetchRepoLabels(token: string, owner: string, name: string): Promise<RepoLabelItem[]> {
    const variables: Record<string, Object> = { 'owner': owner, 'name': name };
    const data = await graphql(REPO_LABELS_QUERY, variables, token);
    return mapRepoLabels(data);
  }

  /** 仓库 Discussion 分类全集（Spec 065：Category 弹层；公开数据无 scope 要求） */
  static async fetchDiscussionCategories(token: string, owner: string, name: string): Promise<RepoCategoryItem[]> {
    const variables: Record<string, Object> = { 'owner': owner, 'name': name };
    const data = await graphql(REPO_DISCUSSION_CATEGORIES_QUERY, variables, token);
    return mapRepoCategories(data);
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
  /**
   * Top Repositories（viewer.repositories）。typeKey 为空=不筛（筛选面板的候选列表用全量）；
   * 传值时把可下推的 Type 项交给服务端（实测支持 isArchived/isFork/privacy），
   * Mirror/Template 无可下推参数，仍由调用方客户端兜底。
   */
  static async fetchTopRepositories(token: string, cursor: string,
    typeKey: string = ''): Promise<WorkTopReposPage> {
    const variables: Record<string, Object> = { 'first': 50 };
    if (cursor !== '') {
      variables['after'] = cursor;
    }
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

  /** viewer 的星标列表（名称/数量/成员仓库 id；>100 成员分页补全，review G5/D16） */
  static async fetchUserLists(token: string): Promise<WorkUserList[]> {
    const data = await graphql(USER_LISTS_QUERY, {}, token);
    const lists = mapWorkUserLists(data);
    for (const list of lists) {
      // items(first:100) 只取首页：成员不全会导致勾选态错判 + 全量替换 mutation 误删成员。
      // 初始查询已带 pageInfo，从其游标续拉（复核修正：不再重拉 page1）
      if (list.repoHasNext) {
        const firstCursor = list.repoCursor;
        const extraIds = await fetchAllPages<string>(async (cursor): Promise<Page<string>> => {
          const after = cursor !== null ? cursor : firstCursor;
          const variables: Record<string, Object> = { 'id': list.id, 'after': after };
          const pageData = await graphql(USER_LIST_ITEMS_QUERY, variables, token);
          const node = Json.obj(pageData, 'node') ?? ({} as JsonMap);
          const itemsWrap = Json.obj(node, 'items') ?? ({} as JsonMap);
          const ids: string[] = [];
          for (const item of Json.arr(itemsWrap, 'nodes')) {
            const id = Json.str(item as JsonMap, 'id');
            if (id !== '') {
              ids.push(id);
            }
          }
          const pageInfo = Json.obj(itemsWrap, 'pageInfo') ?? ({} as JsonMap);
          return {
            items: ids,
            hasNextPage: Json.bool(pageInfo, 'hasNextPage'),
            endCursor: Json.str(pageInfo, 'endCursor')
          };
        });
        for (const id of extraIds) {
          if (!list.repoIds.includes(id)) {
            list.repoIds.push(id);
          }
        }
      }
    }
    return lists;
  }

  /** 他人（指定 login）的星标列表：Lists 区只读展示用，无成员切换故不做 repoIds 分页补全 */
  static async fetchUserListsForLogin(token: string, login: string): Promise<WorkUserList[]> {
    const variables: Record<string, Object> = { 'login': login };
    const data = await graphql(USER_LISTS_BY_LOGIN_QUERY, variables, token);
    return mapWorkUserLists(data, 'user');
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
