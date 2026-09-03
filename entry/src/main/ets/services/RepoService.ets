/**
 * 仓库详情服务（Spec 006）：详情查询 + Star/Fork mutation + Spec 053 社交列表（stargazers/forks）。
 */
import { graphql } from './GitHttpClient';
import { RepoDetail, mapRepoDetail } from '../models/RepoDetailModels';
import { StargazerPage, ForkPage, mapStargazerPage, mapForkPage } from '../models/RepoSocialModels';

const REPO_QUERY = `
query RepositoryDetail($owner: String!, $name: String!) {
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
    repositoryTopics(first: 10) { nodes { topic { name } } }
    readme: object(expression: "HEAD:README.md") { ... on Blob { text } }
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
    releases(first: 5, orderBy: { field: CREATED_AT, direction: DESC }) {
      totalCount
      nodes { tagName publishedAt isLatest }
    }
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
    stargazers(first: $first, after: $after) {
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
}
