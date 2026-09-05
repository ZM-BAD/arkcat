/**
 * 仓库二级页面服务（Spec 027-031）：
 * 仓库内 PR 列表 / Commits / Releases / Issue 详情 / PR 详情。
 */
import { graphql, restGet } from './GitHttpClient';
import { Json, JsonMap } from '../utils/Json';
import {
  RepoPrsPage, RepoCommitsPage, RepoReleasesPage, IssueDetailPage, PrDetailPage,
  mapRepoPrsPage, mapRepoCommitsPage, mapRepoReleasesPage, mapIssueDetail, mapPrDetail, mapPrCommits
} from '../models/RepoSubModels';
import { PrFilesPage, PrFileItem, mapPrFiles, applyRestPatch, mapFilesCursor, mapFileNode } from '../models/PrDiffModels';
import { CommitDetailPage, mapCommitDetail } from '../models/PrDiffModels';
import { parseDiffPatch } from '../utils/Diff';

const REPO_PRS_QUERY = `
query RepoPullRequests($owner: String!, $name: String!, $states: [PullRequestState!], $labels: [String!], $first: Int = 50, $after: String) {
  repository(owner: $owner, name: $name) {
    pullRequests(states: $states, labels: $labels, first: $first, after: $after, orderBy: { field: UPDATED_AT, direction: DESC }) {
      totalCount
      pageInfo { hasNextPage endCursor }
      nodes {
        id number title state merged isDraft createdAt
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
              author { name avatarUrl user { login } }
              statusCheckRollup { state }
            }
          }
        }
      }
    }
  }
}`;

const PR_COMMITS_QUERY = `
query PrCommits($owner: String!, $name: String!, $number: Int!, $first: Int = 40, $after: String) {
  repository(owner: $owner, name: $name) {
    pullRequest(number: $number) {
      commits(first: $first, after: $after) {
        pageInfo { hasNextPage endCursor }
        nodes {
          commit {
            oid messageHeadline committedDate
            author { name avatarUrl user { login } }
            statusCheckRollup { state }
          }
        }
      }
    }
  }
}`;

const COMMIT_DETAIL_QUERY = `
query CommitDetail($owner: String!, $name: String!, $oid: String!) {
  repository(owner: $owner, name: $name) {
    object(expression: $oid) {
      ... on Commit {
        oid messageHeadline messageBodyHTML committedDate
        author { name avatarUrl user { login } }
        statusCheckRollup { state }
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
        nodes {
          id body bodyHTML createdAt
          author { login avatarUrl }
          viewerDidAuthor
          reactionGroups {
            content viewerHasReacted
            reactors(first: 8) {
              totalCount
              nodes {
                ... on User { login avatarUrl }
                ... on Bot { login avatarUrl }
                ... on Mannequin { login avatarUrl }
                ... on Organization { login avatarUrl }
              }
            }
          }
        }
      }
    }
  }
}`;

const PR_DETAIL_QUERY = `
query PullRequestDetail($owner: String!, $name: String!, $number: Int!, $after: String) {
  repository(owner: $owner, name: $name) {
    pullRequest(number: $number) {
      id title state merged isDraft body bodyHTML createdAt mergedAt
      additions deletions
      author { login avatarUrl }
      headRefName baseRefName
      mergedBy { login }
      mergeCommit { abbreviatedOid }
      files { totalCount }
      commits { totalCount }
      reviews { totalCount }
      statusCheckRollup {
        state
        contexts(first: 20) {
          totalCount
          nodes {
            ... on CheckRun { name status conclusion }
            ... on StatusContext { context state }
          }
        }
      }
      comments(first: 20, after: $after) {
        totalCount
        pageInfo { hasNextPage endCursor }
        nodes {
          id body bodyHTML createdAt
          author { login avatarUrl }
          viewerDidAuthor
          reactionGroups {
            content viewerHasReacted
            reactors(first: 8) {
              totalCount
              nodes {
                ... on User { login avatarUrl }
                ... on Bot { login avatarUrl }
                ... on Mannequin { login avatarUrl }
                ... on Organization { login avatarUrl }
              }
            }
          }
        }
      }
    }
  }
}`;

const PR_FILES_QUERY = `
query PullRequestFiles($owner: String!, $name: String!, $number: Int!) {
  repository(owner: $owner, name: $name) {
    pullRequest(number: $number) {
      id
      additions
      deletions
      files(first: 100) {
        totalCount
        nodes { path additions deletions }
      }
    }
  }
}`;


const PR_FILES_PAGE_QUERY = `
query PullRequestFilesPage($owner: String!, $name: String!, $number: Int!, $filesCursor: String!) {
  repository(owner: $owner, name: $name) {
    pullRequest(number: $number) {
      files(first: 100, after: $filesCursor) {
        totalCount
        pageInfo { hasNextPage endCursor }
        nodes { path additions deletions }
      }
    }
  }
}`;

const ADD_COMMENT_MUTATION = `
mutation AddComment($subjectId: ID!, $body: String!) {
  addComment(input: { subjectId: $subjectId, body: $body }) {
    commentEdge { node { id } }
  }
}`;

const UPDATE_COMMENT_MUTATION = `
mutation UpdateComment($id: ID!, $body: String!) {
  updateIssueComment(input: { id: $id, body: $body }) { clientMutationId }
}`;

const DELETE_COMMENT_MUTATION = `
mutation DeleteComment($id: ID!) {
  deleteIssueComment(input: { id: $id }) { clientMutationId }
}`;

const ADD_REACTION_MUTATION = `
mutation AddReaction($subjectId: ID!, $content: ReactionContent!) {
  addReaction(input: { subjectId: $subjectId, content: $content }) { reaction { id } }
}`;

const REMOVE_REACTION_MUTATION = `
mutation RemoveReaction($subjectId: ID!, $content: ReactionContent!) {
  removeReaction(input: { subjectId: $subjectId, content: $content }) { reaction { id } }
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

  /** PR 的 commits 列表（pullRequest.commits，节点包一层 commit） */
  static async fetchPrCommits(token: string, owner: string, name: string, number: number,
    cursor: string): Promise<RepoCommitsPage> {
    const variables: Record<string, Object> = { 'owner': owner, 'name': name, 'number': number, 'first': 40 };
    if (cursor !== '') {
      variables['after'] = cursor;
    }
    const data = await graphql(PR_COMMITS_QUERY, variables, token);
    return mapPrCommits(data);
  }

  /**
   * Commit 详情（官方 Commit 页）：GraphQL 取信息（oid/标题/正文 HTML/作者/checks）；
   * REST /commits/{sha} 回填 parents + files（含 patch），REST /commits/{sha}/pulls 回填关联 PR。
   */
  static async fetchCommitDetail(token: string, owner: string, name: string, oid: string): Promise<CommitDetailPage> {
    const data = await graphql(COMMIT_DETAIL_QUERY, { 'owner': owner, 'name': name, 'oid': oid }, token);
    const page = mapCommitDetail(data);
    try {
      const resp = await restGet(`/repos/${owner}/${name}/commits/${oid}`, token);
      const item = JSON.parse(resp.body) as JsonMap;
      const commit = Json.obj(item, 'commit') ?? ({} as JsonMap);
      page.message = Json.str(commit, 'message');
      page.parents = [];
      for (const p of Json.arr(item, 'parents')) {
        page.parents.push(Json.str(p as JsonMap, 'sha'));
      }
      page.files = [];
      for (const f of Json.arr(item, 'files')) {
        const fj = f as JsonMap;
        const patch = Json.str(fj, 'patch');
        page.files.push({
          path: Json.str(fj, 'filename'),
          status: Json.str(fj, 'status'),
          additions: Json.num(fj, 'additions'),
          deletions: Json.num(fj, 'deletions'),
          hunks: patch !== '' ? parseDiffPatch(patch) : []
        });
      }
    } catch (e) {
      // files/parents 保持空（降级为信息页）
    }
    try {
      const resp = await restGet(`/repos/${owner}/${name}/commits/${oid}/pulls`, token);
      const arr = JSON.parse(resp.body) as Object[];
      page.pullRequests = [];
      for (const node of arr) {
        const p = node as JsonMap;
        page.pullRequests.push({ number: Json.num(p, 'number'), title: Json.str(p, 'title') });
      }
    } catch (e) {
      // 关联 PR 保持空
    }
    return page;
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

  static async fetchPrDetail(token: string, owner: string, name: string, number: number,
    cursor: string): Promise<PrDetailPage> {
    const variables: Record<string, Object> = { 'owner': owner, 'name': name, 'number': number };
    if (cursor !== '') {
      variables['after'] = cursor;
    }
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
    // 文件 >100：GraphQL files 游标翻页补全列表（review G4/B16，上限 10 页防极端长 PR 拖死加载）
    let cursor = mapFilesCursor(data);
    let guard = 0;
    while (cursor !== '' && guard < 10) {
      guard += 1;
      const nextVars: Record<string, Object> = { 'owner': owner, 'name': name, 'number': number, 'filesCursor': cursor };
      const nextData = await graphql(PR_FILES_PAGE_QUERY, nextVars, token);
      const nextFiles = Json.obj(Json.obj(Json.obj(nextData, 'repository') ?? ({} as JsonMap), 'pullRequest')
        ?? ({} as JsonMap), 'files') ?? ({} as JsonMap);
      for (const node of Json.arr(nextFiles, 'nodes')) {
        page.files.push(mapFileNode(node as JsonMap));
      }
      cursor = mapFilesCursor(nextData);
    }
    try {
      // REST patch 回填同样按页翻全（per_page=100）
      const itemByPath = new Map<string, JsonMap>();
      let restPage = 1;
      while (restPage <= 10) {
        const resp = await restGet(`/repos/${owner}/${name}/pulls/${number}/files?per_page=100&page=${restPage}`, token);
        const parsed: Object | null = JSON.parse(resp.body);
        const restItems = (parsed ?? []) as Object[];
        for (const node of restItems) {
          const item = node as JsonMap;
          itemByPath.set(Json.str(item, 'filename'), item);
        }
        if (restItems.length < 100) {
          break;
        }
        restPage += 1;
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

  /** 发布评论（subjectId = Issue/PR 节点 id；成功后调用方刷新列表）
  /** 发布评论（subjectId = Issue/PR 节点 id；成功后调用方刷新列表） */
  static async addComment(token: string, subjectId: string, body: string): Promise<void> {
    const variables: Record<string, Object> = { 'subjectId': subjectId, 'body': body };
    await graphql(ADD_COMMENT_MUTATION, variables, token);
  }

  /** 编辑评论（updateIssueComment：Issue/PR 普通评论均为 IssueComment 节点） */
  static async updateComment(token: string, commentId: string, body: string): Promise<void> {
    const variables: Record<string, Object> = { 'id': commentId, 'body': body };
    await graphql(UPDATE_COMMENT_MUTATION, variables, token);
  }

  /** 删除评论（仅作者；deleteIssueComment） */
  static async deleteComment(token: string, commentId: string): Promise<void> {
    const variables: Record<string, Object> = { 'id': commentId };
    await graphql(DELETE_COMMENT_MUTATION, variables, token);
  }

  /** 添加 emoji 反应（subjectId = 评论/Issue/PR 节点 id；content 为 ReactionContent 枚举） */
  static async addReaction(token: string, subjectId: string, content: string): Promise<void> {
    const variables: Record<string, Object> = { 'subjectId': subjectId, 'content': content };
    await graphql(ADD_REACTION_MUTATION, variables, token);
  }

  /** 移除 emoji 反应（toggle 由调用方按 viewerHasReacted 决定） */
  static async removeReaction(token: string, subjectId: string, content: string): Promise<void> {
    const variables: Record<string, Object> = { 'subjectId': subjectId, 'content': content };
    await graphql(REMOVE_REACTION_MUTATION, variables, token);

  }
}
