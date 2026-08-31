/**
 * Home 工作区列表服务（Spec 017-023）。
 * 跨仓库 Issues/PRs/Discussions 走 GraphQL search（type: ISSUE/PR/DISCUSSION）；
 * Projects/TopRepos/Orgs/Starred 走 viewer 连接。
 */
import { graphql } from './GitHttpClient';
import {
  WorkIssuesPage, WorkPrsPage, WorkDiscussionsPage, WorkProjectsPage,
  WorkOrgsPage, WorkTopReposPage, WorkStarredPage,
  buildWorkIssuesQuery, buildWorkPrsQuery, buildWorkDiscussionsQuery, buildTopReposPrivacy,
  mapWorkIssuesPage, mapWorkPrsPage, mapWorkDiscussionsPage,
  mapWorkProjectsPage, mapWorkOrgsPage, mapWorkTopReposPage, mapWorkStarredPage
} from '../models/WorkModels';

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
  search(query: $query, type: PR, first: $first, after: $after) {
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
        id number title state createdAt
        repository { nameWithOwner }
        category { name }
        comments { totalCount }
      }
    }
  }
}`;

const WORK_PROJECTS_QUERY = `
query WorkProjects($first: Int = 30) {
  viewer {
    login
    projectsV2(first: $first) {
      totalCount
      pageInfo { hasNextPage endCursor }
      nodes {
        title number closed updatedAt
        owner { ... on Organization { login } ... on User { login } }
      }
    }
  }
}`;

const WORK_TOP_REPOS_QUERY = `
query WorkTopRepositories($privacy: RepositoryPrivacy, $first: Int = 50, $after: String) {
  viewer {
    repositories(first: $first, after: $after, orderBy: { field: PUSHED_AT, direction: DESC }, privacy: $privacy) {
      totalCount
      pageInfo { hasNextPage endCursor }
      nodes {
        id name nameWithOwner
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

export class WorkService {
  /** 工作区 Issue 列表（search type: ISSUE） */
  static async fetchIssues(token: string, state: string, scope: string, visibility: string,
    cursor: string): Promise<WorkIssuesPage> {
    const variables: Record<string, Object> = {
      'query': buildWorkIssuesQuery(state, scope, visibility),
      'first': 25
    };
    if (cursor !== '') {
      variables['after'] = cursor;
    }
    const data = await graphql(WORK_ISSUES_QUERY, variables, token);
    return mapWorkIssuesPage(data);
  }

  /** 工作区 PR 列表（search type: PR） */
  static async fetchPrs(token: string, state: string, scope: string, visibility: string,
    cursor: string): Promise<WorkPrsPage> {
    const variables: Record<string, Object> = {
      'query': buildWorkPrsQuery(state, scope, visibility),
      'first': 25
    };
    if (cursor !== '') {
      variables['after'] = cursor;
    }
    const data = await graphql(WORK_PRS_QUERY, variables, token);
    return mapWorkPrsPage(data);
  }

  /** 工作区 Discussion 列表（search type: DISCUSSION） */
  static async fetchDiscussions(token: string, state: string, scope: string, unanswered: boolean,
    cursor: string): Promise<WorkDiscussionsPage> {
    const variables: Record<string, Object> = {
      'query': buildWorkDiscussionsQuery(state, scope, unanswered),
      'first': 25
    };
    if (cursor !== '') {
      variables['after'] = cursor;
    }
    const data = await graphql(WORK_DISCUSSIONS_QUERY, variables, token);
    return mapWorkDiscussionsPage(data);
  }

  /** 工作区 Projects（viewer.projectsV2，排序/过滤在客户端） */
  static async fetchProjects(token: string, cursor: string): Promise<WorkProjectsPage> {
    const variables: Record<string, Object> = { 'first': 30 };
    if (cursor !== '') {
      variables['after'] = cursor;
    }
    const data = await graphql(WORK_PROJECTS_QUERY, variables, token);
    return mapWorkProjectsPage(data);
  }

  /** Top Repositories（viewer.repositories） */
  static async fetchTopRepositories(token: string, privacy: string, cursor: string): Promise<WorkTopReposPage> {
    const variables: Record<string, Object> = { 'first': 50 };
    const privacyEnum = buildTopReposPrivacy(privacy);
    if (privacyEnum !== '') {
      variables['privacy'] = privacyEnum;
    }
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

  /** 星标仓库列表（viewer.starredRepositories） */
  static async fetchStarred(token: string, cursor: string): Promise<WorkStarredPage> {
    const variables: Record<string, Object> = { 'first': 30 };
    if (cursor !== '') {
      variables['after'] = cursor;
    }
    const data = await graphql(WORK_STARRED_QUERY, variables, token);
    return mapWorkStarredPage(data);
  }
}
