/**
 * 仓库二级页面服务（Spec 027-031）：
 * 仓库内 PR 列表 / Commits / Releases / Issue 详情 / PR 详情。
 */
import { graphql, restGet } from './GitHttpClient';
import { Json, JsonMap } from '../utils/Json';
import {
  RepoPrsPage, RepoCommitsPage, RepoReleasesPage, IssueDetailPage, PrDetailPage,
  mapRepoPrsPage, mapRepoCommitsPage, mapRepoReleasesPage, mapIssueDetail, mapPrDetail
} from '../models/RepoSubModels';
import { PrFilesPage, PrFileItem, mapPrFiles, applyRestPatch } from '../models/PrDiffModels';

const REPO_PRS_QUERY = `
query RepoPullRequests($owner: String!, $name: String!, $states: [PullRequestState!], $labels: [String!], $first: Int = 50, $after: String) {
  repository(owner: $owner, name: $name) {
    pullRequests(states: $states, labels: $labels, first: $first, after: $after, orderBy: { field: UPDATED_AT, direction: DESC }) {
      totalCount
      pageInfo { hasNextPage endCursor }
      nodes {
        id number title state merged createdAt
        labels(first: 8) { nodes { name color } }
        comments { totalCount }
        reviewRequests(first: 10) { totalCount }
        statusCheckRollup { state }
        author { login avatarUrl }
        assignees(first: 10) { nodes { login } }
      }
    }
    labels(first: 30) { nodes { name } }
  }
}`;

const REPO_COMMITS_QUERY = `
query RepoCommits($owner: String!, $name: String!, $first: Int = 40, $after: String) {
  repository(owner: $owner, name: $name) {
    defaultBranchRef {
      target {
        ... on Commit {
          history(first: $first, after: $after) {
            totalCount
            pageInfo { hasNextPage endCursor }
            nodes {
              oid messageHeadline committedDate
              author { login avatarUrl }
              statusCheckRollup { state }
            }
          }
        }
      }
    }
  }
}`;

const REPO_RELEASES_QUERY = `
query RepoReleases($owner: String!, $name: String!, $first: Int = 30, $after: String) {
  repository(owner: $owner, name: $name) {
    releases(first: $first, after: $after, orderBy: { field: CREATED_AT, direction: DESC }) {
      totalCount
      pageInfo { hasNextPage endCursor }
      nodes { id tagName isLatest createdAt description body bodyHTML author { login avatarUrl } }
    }
  }
}`;

const ISSUE_DETAIL_QUERY = `
query IssueDetail($owner: String!, $name: String!, $number: Int!, $first: Int = 20, $after: String) {
  repository(owner: $owner, name: $name) {
    issue(number: $number) {
      id title state stateReason body bodyHTML createdAt
      author { login avatarUrl }
      labels(first: 10) { nodes { name } }
      comments(first: $first, after: $after) {
        totalCount
        pageInfo { hasNextPage endCursor }
        nodes { id body bodyHTML createdAt author { login avatarUrl } }
      }
    }
  }
}`;

const PR_DETAIL_QUERY = `
query PullRequestDetail($owner: String!, $name: String!, $number: Int!) {
  repository(owner: $owner, name: $name) {
    pullRequest(number: $number) {
      id title state merged isDraft body bodyHTML createdAt mergedAt
      additions deletions
      author { login avatarUrl }
      headRefName baseRefName
      mergeCommit { abbreviatedOid }
      files { totalCount }
      commits { totalCount }
      reviews { totalCount }
      statusCheckRollup { state }
      comments(first: 15) { totalCount nodes { id body bodyHTML createdAt author { login avatarUrl } } }
    }
  }
}`;

const PR_FILES_QUERY = `
query PullRequestFiles($owner: String!, $name: String!, $number: Int!) {
  repository(owner: $owner, name: $name) {
    pullRequest(number: $number) {
      id
      files(first: 100) {
        totalCount
        nodes { path additions deletions status }
      }
    }
  }
}`;

const PR_ADD_COMMENT_MUTATION = `
mutation AddPrComment($subjectId: ID!, $body: String!) {
  addComment(input: { subjectId: $subjectId, body: $body }) {
    clientMutationId
  }
}`;

/** 仓库内 PR 列表（state: all/open/closed/merged；label 走 GraphQL，author/assignee 客户端过滤） */
export function repoPrsStates(states: string[] | null): string[] | null {
  return states;
}

export class RepoSubService {
  static async fetchRepoPrs(token: string, owner: string, name: string,
    state: string, label: string, cursor: string): Promise<RepoPrsPage> {
    const variables: Record<string, Object> = { 'owner': owner, 'name': name, 'first': 50 };
    if (state === 'open') {
      variables['states'] = ['OPEN'];
    } else if (state === 'closed') {
      variables['states'] = ['CLOSED'];
    } else if (state === 'merged') {
      variables['states'] = ['MERGED'];
    }
    if (label !== '') {
      variables['labels'] = [label];
    }
    if (cursor !== '') {
      variables['after'] = cursor;
    }
    const data = await graphql(REPO_PRS_QUERY, variables, token);
    return mapRepoPrsPage(data);
  }

  static async fetchCommits(token: string, owner: string, name: string, cursor: string): Promise<RepoCommitsPage> {
    const variables: Record<string, Object> = { 'owner': owner, 'name': name, 'first': 40 };
    if (cursor !== '') {
      variables['after'] = cursor;
    }
    const data = await graphql(REPO_COMMITS_QUERY, variables, token);
    return mapRepoCommitsPage(data);
  }

  static async fetchReleases(token: string, owner: string, name: string, cursor: string): Promise<RepoReleasesPage> {
    const variables: Record<string, Object> = { 'owner': owner, 'name': name, 'first': 30 };
    if (cursor !== '') {
      variables['after'] = cursor;
    }
    const data = await graphql(REPO_RELEASES_QUERY, variables, token);
    return mapRepoReleasesPage(data);
  }

  static async fetchIssueDetail(token: string, owner: string, name: string, number: number,
    cursor: string): Promise<IssueDetailPage> {
    const variables: Record<string, Object> = { 'owner': owner, 'name': name, 'number': number, 'first': 20 };
    if (cursor !== '') {
      variables['after'] = cursor;
    }
    const data = await graphql(ISSUE_DETAIL_QUERY, variables, token);
    return mapIssueDetail(data);
  }

  static async fetchPrDetail(token: string, owner: string, name: string, number: number): Promise<PrDetailPage> {
    const variables: Record<string, Object> = { 'owner': owner, 'name': name, 'number': number };
    const data = await graphql(PR_DETAIL_QUERY, variables, token);
    return mapPrDetail(data);
  }

  /**
   * PR 文件变更（Spec 010）：GraphQL 拿列表/计数（files(first:100)），
   * REST /pulls/{n}/files?per_page=100 按 filename 回填 patch（GraphQL 无 diff 字段）；
   * REST 失败时静默降级为纯列表（hunks 为空即不可预览）。
   */
  static async fetchPrFiles(token: string, owner: string, name: string, number: number): Promise<PrFilesPage> {
    const variables: Record<string, Object> = { 'owner': owner, 'name': name, 'number': number };
    const data = await graphql(PR_FILES_QUERY, variables, token);
    const page = mapPrFiles(data);
    try {
      const resp = await restGet(`/repos/${owner}/${name}/pulls/${number}/files?per_page=100`, token);
      const parsed: Object | null = JSON.parse(resp.body);
      const restItems = parsed as Object[];
      const itemByPath = new Map<string, JsonMap>();
      for (const node of restItems) {
        const item = node as JsonMap;
        itemByPath.set(Json.str(item, 'filename'), item);
      }
      const merged: PrFileItem[] = [];
      for (const f of page.files) {
        const rest = itemByPath.get(f.path);
        merged.push(rest !== undefined ? applyRestPatch(f, rest) : f);
      }
      page.files = merged;
    } catch (e) {
      // patch 拉取失败不阻断列表（行内评论等写操作与列表无关）
    }
    return page;
  }

  /** 全局评论提交（GraphQL addComment；041 评论区全链路前的最小实现） */
  static async addPrComment(token: string, subjectId: string, body: string): Promise<void> {
    const variables: Record<string, Object> = { 'subjectId': subjectId, 'body': body };
    await graphql(PR_ADD_COMMENT_MUTATION, variables, token);
  }
}
