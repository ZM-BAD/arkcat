/**
 * 仓库二级页面服务（Spec 027-031）：
 * 仓库内 PR 列表 / Commits / Releases / Issue 详情 / PR 详情。
 */
import { graphql, restGet } from './GitHttpClient';
import { fetchAllPages, Page } from 'graphql';
import { Json, JsonMap } from '../utils/Json';
import { repoIssueOrder } from './IssuesService';
import {
  RepoPrsPage, RepoCommitsPage, RepoReleasesPage, IssueDetailPage, PrDetailPage,
  mapRepoPrsPage, mapRepoCommitsPage, mapRepoReleasesPage, mapIssueDetail, mapPrDetail, mapPrCommits,
  ReleaseDetailPage, mapReleaseDetail, ReactionUsersPage, mapReactionUsersPage,
  TriageUser, TriageLabel, TriageMilestone, TriageLinkedItem, TriageProject,
  mapTriageUsers, mapTriageLabels, mapTriageMilestones, mapTriageLinked, mapTriageProjects
} from '../models/RepoSubModels';
import { PrFilesPage, PrFileItem, mapPrFiles, applyRestPatch, mapFilesCursor, mapFileNode } from '../models/PrDiffModels';
import { CommitDetailPage, mapCommitDetail } from '../models/PrDiffModels';
import { parseDiffPatch } from '../utils/Diff';
import { FRAG_PAGE_INFO } from './GqlFragments';

const REPO_PRS_QUERY = `
query RepoPullRequests($owner: String!, $name: String!, $states: [PullRequestState!], $labels: [String!], $first: Int = 50, $after: String, $orderBy: IssueOrder!) {
  repository(owner: $owner, name: $name) {
    pullRequests(states: $states, labels: $labels, first: $first, after: $after, orderBy: $orderBy) {
      totalCount
      ${FRAG_PAGE_INFO}
      nodes {
        id number title state merged isDraft createdAt
        milestone { title }
        labels(first: 8) { nodes { name color } }
        comments { totalCount }
        reviewRequests(first: 10) { totalCount }
        statusCheckRollup { state contexts(first: 1) { totalCount } }
        author { login avatarUrl }
        assignees(first: 10) { nodes { login } }
      }
    }
    labels(first: 30) { nodes { name color } }
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
            ${FRAG_PAGE_INFO}
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
        ${FRAG_PAGE_INFO}
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
      ${FRAG_PAGE_INFO}
      nodes { id name tagName isLatest createdAt description author { login avatarUrl } }
    }
  }
}`;

const RELEASE_DETAIL_QUERY = `
query ReleaseDetail($owner: String!, $name: String!, $tag: String!) {
  repository(owner: $owner, name: $name) {
    release(tagName: $tag) {
      id tagName name isDraft isPrerelease publishedAt createdAt url
      isLatest
      tagCommit { oid }
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
      author { login avatarUrl }
      description
      releaseAssets(first: 50) {
        nodes { id name size downloadCount contentType url }
      }
    }
  }
}`;

const REACTION_USERS_QUERY = `
query ReactionUsers($id: ID!, $first: Int = 50, $after: String) {
  node(id: $id) {
    ... on Release {
      reactionGroups {
        content
        reactors(first: $first, after: $after) {
          totalCount
          ${FRAG_PAGE_INFO}
          nodes {
            ... on User { login name avatarUrl }
            ... on Bot { login avatarUrl }
            ... on Mannequin { login avatarUrl }
            ... on Organization { login name avatarUrl }
          }
        }
      }
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
        ${FRAG_PAGE_INFO}
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
    # 合并权限门：PullRequest 无 viewerCanMerge 字段（2026-09-14 运行时实测），
    # 改用 Repository.viewerPermission ∈ ADMIN/MAINTAIN/WRITE 判定
    viewerPermission
    # 页头作者行=仓库上下文（官方口径）：owner 头像 + owner / repo #N
    owner { avatarUrl }
    # Merge options 页默认选中项（官方口径：仓库/账号默认合并方式，非固定 squash）
    viewerDefaultMergeMethod
    pullRequest(number: $number) {
      id title state merged isDraft body bodyHTML createdAt mergedAt
      additions deletions
      # 作者关联角色（页头正文卡角色胶囊：AuthorAssociation 全集）
      authorAssociation
      # 正文反应（正文卡反应行：笑脸钮 + 芯片；addReaction 的 subjectId 即本节点 id）
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
      author { login avatarUrl }
      headRefName baseRefName
      mergedBy { login }
      mergeCommit { abbreviatedOid }
      files { totalCount }
      commits { totalCount }
      mergeable mergeStateStatus
      # Merge options 页提交信息默认值（无 mergeMethod 参数，返回的是「默认合并方式」口径的文本）
      viewerMergeHeadlineText
      viewerMergeBodyText
      reviews { totalCount }
      reviewThreads(first: 50) {
        totalCount
        nodes {
          id path line isResolved isOutdated viewerCanResolve viewerCanUnresolve
          comments(first: 30) {
            totalCount
            nodes { id body bodyHTML createdAt author { login avatarUrl } viewerDidAuthor }
          }
        }
      }
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
      labels(first: 10) { nodes { id name color } }
      assignees(first: 10) { nodes { id login avatarUrl } }
      milestone { id title }
      # 会话时间轴（官方 Conversation）：事件 + 评论 + 审阅按时间序，单一游标分页。
      # itemTypes 限定为客户端已渲染的子集（GH 共 78 种时间轴类型，未列入的暂不取）。
      timelineItems(first: 30, after: $after, itemTypes: [
        PULL_REQUEST_COMMIT, ISSUE_COMMENT, PULL_REQUEST_REVIEW,
        LABELED_EVENT, UNLABELED_EVENT, ASSIGNED_EVENT, UNASSIGNED_EVENT,
        REVIEW_REQUESTED_EVENT, REVIEW_REQUEST_REMOVED_EVENT,
        MERGED_EVENT, CLOSED_EVENT, REOPENED_EVENT, CONVERT_TO_DRAFT_EVENT, READY_FOR_REVIEW_EVENT
      ]) {
        totalCount
        ${FRAG_PAGE_INFO}
        nodes {
          __typename
          ... on PullRequestCommit {
            id
            commit { oid abbreviatedOid messageHeadline author { name avatarUrl } }
          }
          ... on IssueComment {
            id body bodyHTML createdAt viewerDidAuthor
            author { __typename login avatarUrl }
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
          ... on PullRequestReview {
            id state body bodyHTML submittedAt viewerDidAuthor
            author { __typename login avatarUrl }
          }
          ... on LabeledEvent { id createdAt actor { __typename login avatarUrl } label { name color } }
          ... on UnlabeledEvent { id createdAt actor { __typename login avatarUrl } label { name color } }
          ... on AssignedEvent {
            id createdAt
            actor { __typename login avatarUrl }
            assignee { __typename ... on User { login } ... on Bot { login } ... on Mannequin { login } ... on Organization { name } }
          }
          ... on UnassignedEvent {
            id createdAt
            actor { __typename login avatarUrl }
            assignee { __typename ... on User { login } ... on Bot { login } ... on Mannequin { login } ... on Organization { name } }
          }
          ... on ReviewRequestedEvent {
            id createdAt
            actor { __typename login avatarUrl }
            requestedReviewer { __typename ... on User { login } ... on Bot { login } ... on Mannequin { login } ... on Team { name } }
          }
          ... on ReviewRequestRemovedEvent {
            id createdAt
            actor { __typename login avatarUrl }
            requestedReviewer { __typename ... on User { login } ... on Bot { login } ... on Mannequin { login } ... on Team { name } }
          }
          ... on MergedEvent { id createdAt actor { __typename login avatarUrl } commit { abbreviatedOid } mergeRefName }
          ... on ClosedEvent { id createdAt actor { __typename login avatarUrl } }
          ... on ReopenedEvent { id createdAt actor { __typename login avatarUrl } }
          ... on ConvertToDraftEvent { id createdAt actor { __typename login avatarUrl } }
          ... on ReadyForReviewEvent { id createdAt actor { __typename login avatarUrl } }
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
        ${FRAG_PAGE_INFO}
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
        ${FRAG_PAGE_INFO}
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

// ─────────────── Spec 042：PR 审阅与合并 ───────────────

/** 行内新建 review thread（del 行 side=LEFT、其余 RIGHT；line 由 diff 行号换算） */
const ADD_REVIEW_THREAD_MUTATION = `
mutation AddReviewThread($prId: ID!, $body: String!, $path: String!, $line: Int!, $side: DiffSide!) {
  addPullRequestReviewThread(input: { pullRequestId: $prId, body: $body, path: $path, line: $line, side: $side }) {
    thread { id path line }
  }
}`;

/** thread 回复（threadId + body，已提交 thread 场景） */
const REPLY_REVIEW_THREAD_MUTATION = `
mutation ReplyReviewThread($threadId: ID!, $body: String!) {
  addPullRequestReviewComment(input: { threadId: $threadId, body: $body }) { comment { id } }
}`;

/** 审阅汇总提交（三态：APPROVE / REQUEST_CHANGES / COMMENT） */
const SUBMIT_REVIEW_MUTATION = `
mutation SubmitPullRequestReview($prId: ID!, $event: PullRequestReviewEvent!, $body: String!) {
  submitPullRequestReview(input: { pullRequestId: $prId, event: $event, body: $body }) {
    pullRequestReview { id state submittedAt }
  }
}`;

/** 编辑本人已提交审阅的总结（Spec 042 元素6：仅 viewerDidAuthor 暴露入口） */
const UPDATE_REVIEW_MUTATION = `
mutation UpdatePullRequestReview($reviewId: ID!, $body: String!) {
  updatePullRequestReview(input: { pullRequestReviewId: $reviewId, body: $body }) {
    pullRequestReview { id body }
  }
}`;

const RESOLVE_THREAD_MUTATION = `
mutation ResolveReviewThread($threadId: ID!) {
  resolveReviewThread(input: { threadId: $threadId }) { thread { id isResolved } }
}`;

const UNRESOLVE_THREAD_MUTATION = `
mutation UnresolveReviewThread($threadId: ID!) {
  unresolveReviewThread(input: { threadId: $threadId }) { thread { id isResolved } }
}`;

/** 合并（官方默认 squash；mergeMethod 枚举真名 PullRequestMergeMethod，Spec 片段里的 MergeMethod! 是笔误） */
const MERGE_PULL_REQUEST_MUTATION = `
mutation MergePullRequest($prId: ID!, $method: PullRequestMergeMethod) {
  mergePullRequest(input: { pullRequestId: $prId, mergeMethod: $method }) {
    pullRequest { merged state mergedAt }
  }
}`;

/** 合并 + 自定义 commit message（官方 Merge sheet 的 EDIT 态，Android 截图对齐） */
const MERGE_WITH_MESSAGE_MUTATION = `
mutation MergePullRequestWithMessage($prId: ID!, $method: PullRequestMergeMethod, $headline: String!, $body: String!) {
  mergePullRequest(input: { pullRequestId: $prId, mergeMethod: $method, commitHeadline: $headline, commitBody: $body }) {
    pullRequest { merged state mergedAt }
  }
}`;

/** 仓库内 PR 列表（state: all/open/closed/merged；label 走 GraphQL，author/assignee 客户端过滤） */
export function repoPrsStates(states: string[] | null): string[] | null {
  return states;
}

// ─────────────── Spec 044 元数据编排（详情页 info → EDIT 编辑器）───────────────

/** 编辑器候选源：负责人（仓库可分配用户，搜索在客户端过滤） */
const TRIAGE_ASSIGNEES_QUERY = `
query TriageAssignees($owner: String!, $name: String!) {
  repository(owner: $owner, name: $name) {
    assignableUsers(first: 50) { nodes { id login avatarUrl } }
  }
}`;

/** 编辑器候选源：仓库全部标签（按名字升序，Spec 044） */
const TRIAGE_LABELS_QUERY = `
query TriageLabels($owner: String!, $name: String!) {
  repository(owner: $owner, name: $name) {
    labels(first: 50, orderBy: { field: NAME, direction: ASC }) { nodes { id name color } }
  }
}`;

/** 编辑器候选源：未关闭里程碑（Spec 044：只列 open） */
const TRIAGE_MILESTONES_QUERY = `
query TriageMilestones($owner: String!, $name: String!) {
  repository(owner: $owner, name: $name) {
    milestones(first: 30, states: OPEN) { nodes { id title } }
  }
}`;

/**
 * 编辑器候选源：Linked items 的 Suggestions。
 * 官方「linked items」是站内私有能力（无公开 GraphQL 关联字段/变更），
 * 这里按「仓库内最近更新的 issue（含 PR 自身排除由客户端做）」给出建议列表。
 */
const TRIAGE_LINKED_QUERY = `
query TriageLinked($owner: String!, $name: String!) {
  repository(owner: $owner, name: $name) {
    issues(first: 20, states: [OPEN, CLOSED], orderBy: { field: UPDATED_AT, direction: DESC }) {
      nodes { id number title state }
    }
  }
}`;

/** 编辑器候选源：项目（RECENT=仓库项目，USER=当前账号项目，复用 020 的 ProjectsV2 通道） */
const TRIAGE_PROJECTS_QUERY = `
query TriageProjects($owner: String!, $name: String!) {
  repository(owner: $owner, name: $name) {
    projectsV2(first: 20) { nodes { id title } }
  }
  viewer {
    projectsV2(first: 20) { nodes { id title } }
  }
}`;

/** 负责人保存：整组替换（UpdatePullRequestInput.assigneeIds） */
const SET_PR_ASSIGNEES_MUTATION = `
mutation SetPrAssignees($prId: ID!, $ids: [ID!]!) {
  updatePullRequest(input: { pullRequestId: $prId, assigneeIds: $ids }) { clientMutationId }
}`;

/** 里程碑保存（UpdatePullRequestInput.milestoneId） */
const SET_PR_MILESTONE_MUTATION = `
mutation SetPrMilestone($prId: ID!, $milestoneId: ID!) {
  updatePullRequest(input: { pullRequestId: $prId, milestoneId: $milestoneId }) { clientMutationId }
}`;

/** 里程碑清除（不带 milestoneId 键，等价服务端清空） */
const CLEAR_PR_MILESTONE_MUTATION = `
mutation ClearPrMilestone($prId: ID!) {
  updatePullRequest(input: { pullRequestId: $prId, milestoneId: null }) { clientMutationId }
}`;

/** 标签增删（labelable 对 Issue/PR 通用，差异分两次 mutation，Spec 044 元素2） */
const ADD_LABELS_MUTATION = `
mutation AddLabels($labelableId: ID!, $labelIds: [ID!]!) {
  addLabelsToLabelable(input: { labelableId: $labelableId, labelIds: $labelIds }) { clientMutationId }
}`;

const REMOVE_LABELS_MUTATION = `
mutation RemoveLabels($labelableId: ID!, $labelIds: [ID!]!) {
  removeLabelsFromLabelable(input: { labelableId: $labelableId, labelIds: $labelIds }) { clientMutationId }
}`;

/** 项目拉入（Spec 044 元素7：只做「加入项目」，字段/状态编辑归 P2） */
const ADD_PROJECT_ITEM_MUTATION = `
mutation AddProjectItem($projectId: ID!, $contentId: ID!) {
  addProjectV2ItemById(input: { projectId: $projectId, contentId: $contentId }) { item { id } }
}`;

export class RepoSubService {
  /** 仓库内 PR 列表：states/labels 服务端 + 排序（PullRequestOrder 与 IssueOrder 同构，复用 6 键映射） */
  static async fetchRepoPrs(token: string, owner: string, name: string,
    state: string, label: string, cursor: string, sortKey: string = 'newest'): Promise<RepoPrsPage> {
    const variables: Record<string, Object> = { 'owner': owner, 'name': name, 'first': 50,
      'orderBy': repoIssueOrder(sortKey) };
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

  /** Release 详情（tagName 定位；release 不存在返回 null） */
  static async fetchReleaseDetail(token: string, owner: string, name: string,
    tag: string): Promise<ReleaseDetailPage | null> {
    const variables: Record<string, Object> = { 'owner': owner, 'name': name, 'tag': tag };
    const data = await graphql(RELEASE_DETAIL_QUERY, variables, token);
    return mapReleaseDetail(data);
  }

  /** Reactees 整页：node 查 release 指定 content 的分页反应用户（2026-09-06 gh api 实测） */
  static async fetchReactionUsers(token: string, subjectId: string, content: string,
    cursor: string): Promise<ReactionUsersPage> {
    const variables: Record<string, Object> = { 'id': subjectId, 'first': 50 };
    if (cursor !== '') {
      variables['after'] = cursor;
    }
    const data = await graphql(REACTION_USERS_QUERY, variables, token);
    return mapReactionUsersPage(data, content);
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
    // 文件 >100：GraphQL files 游标翻页补全列表（review G4；hasNextPage 驱动——
    // 实测末页 endCursor 仍非空，用游标判停会多打一次空页；上限 10 页防极端长 PR 拖死加载）
    const dataFiles = Json.obj(Json.obj(Json.obj(Json.obj(data, 'repository') ?? ({} as JsonMap),
      'pullRequest') ?? ({} as JsonMap), 'files') ?? ({} as JsonMap), 'pageInfo') ?? ({} as JsonMap);
    if (Json.bool(dataFiles, 'hasNextPage')) {
      const firstCursor = mapFilesCursor(data);
      const moreFiles = await fetchAllPages<PrFileItem>(async (cursor): Promise<Page<PrFileItem>> => {
        try {
          const c = cursor !== null ? cursor : firstCursor;
          const nextVars: Record<string, Object> = { 'owner': owner, 'name': name, 'number': number, 'filesCursor': c };
          const nextData = await graphql(PR_FILES_PAGE_QUERY, nextVars, token);
          const nextPr = Json.obj(Json.obj(nextData, 'repository') ?? ({} as JsonMap), 'pullRequest') ?? ({} as JsonMap);
          const nextFiles = Json.obj(nextPr, 'files') ?? ({} as JsonMap);
          const nextItems: PrFileItem[] = [];
          for (const node of Json.arr(nextFiles, 'nodes')) {
            nextItems.push(mapFileNode(node as JsonMap));
          }
          const pageInfo = Json.obj(nextFiles, 'pageInfo') ?? ({} as JsonMap);
          return {
            items: nextItems,
            hasNextPage: Json.bool(pageInfo, 'hasNextPage'),
            endCursor: Json.str(pageInfo, 'endCursor')
          };
        } catch (e) {
          // 第 2+ 页失败降级为已取得的前 100 文件，不整页报错（复核修正）
          return { items: [], hasNextPage: false, endCursor: '' };
        }
      });
      for (const f of moreFiles) {
        page.files.push(f);
      }
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

  // ───────────── Spec 042：PR 审阅与合并 ─────────────

  /** 新建行内 review thread（path + diff 行号 + side；成功后调用方刷新详情） */
  static async addReviewThread(token: string, prId: string, body: string, path: string,
    line: number, side: string): Promise<void> {
    const variables: Record<string, Object> = {
      'prId': prId, 'body': body, 'path': path, 'line': line, 'side': side
    };
    await graphql(ADD_REVIEW_THREAD_MUTATION, variables, token);
  }

  /** thread 回复（追加评论，评论数 +1） */
  static async replyReviewThread(token: string, threadId: string, body: string): Promise<void> {
    const variables: Record<string, Object> = { 'threadId': threadId, 'body': body };
    await graphql(REPLY_REVIEW_THREAD_MUTATION, variables, token);
  }

  /** 提交审阅（event: APPROVE / REQUEST_CHANGES / COMMENT；body 可为空串） */
  static async submitReview(token: string, prId: string, event: string, body: string): Promise<void> {
    const variables: Record<string, Object> = { 'prId': prId, 'event': event, 'body': body };
    await graphql(SUBMIT_REVIEW_MUTATION, variables, token);
  }

  /** 编辑本人已提交审阅的总结 body */
  static async updateReview(token: string, reviewId: string, body: string): Promise<void> {
    const variables: Record<string, Object> = { 'reviewId': reviewId, 'body': body };
    await graphql(UPDATE_REVIEW_MUTATION, variables, token);
  }

  /** 解析/取消解析 thread（resolve=true → resolveReviewThread，否则 unresolve） */
  static async setThreadResolved(token: string, threadId: string, resolve: boolean): Promise<void> {
    const variables: Record<string, Object> = { 'threadId': threadId };
    await graphql(resolve ? RESOLVE_THREAD_MUTATION : UNRESOLVE_THREAD_MUTATION, variables, token);
  }

  /**
   * 合并 PR（method: SQUASH / MERGE / REBASE；成功后调用方刷新详情）。
   * headline/body 非空时走带 commit message 的 mutation（官方 Merge sheet EDIT 态）。
   */
  static async mergePullRequest(token: string, prId: string, method: string, headline: string,
    body: string): Promise<void> {
    if (headline !== '') {
      const vars: Record<string, Object> = {
        'prId': prId, 'method': method, 'headline': headline, 'body': body
      };
      await graphql(MERGE_WITH_MESSAGE_MUTATION, vars, token);
      return;
    }
    const variables: Record<string, Object> = { 'prId': prId, 'method': method };
    await graphql(MERGE_PULL_REQUEST_MUTATION, variables, token);
  }

  // ─────────────── Spec 044 元数据编辑器：候选拉取 ───────────────

  /** 负责人候选（assignableUsers；Spec 044 元素5） */
  static async fetchTriageAssignees(token: string, owner: string, name: string): Promise<TriageUser[]> {
    const variables: Record<string, Object> = { 'owner': owner, 'name': name };
    const data = await graphql(TRIAGE_ASSIGNEES_QUERY, variables, token);
    return mapTriageUsers(data);
  }

  /** 标签候选（仓库标签全集；Spec 044 元素2） */
  static async fetchTriageLabels(token: string, owner: string, name: string): Promise<TriageLabel[]> {
    const variables: Record<string, Object> = { 'owner': owner, 'name': name };
    const data = await graphql(TRIAGE_LABELS_QUERY, variables, token);
    return mapTriageLabels(data);
  }

  /** 里程碑候选（仅 open；Spec 044 元素6） */
  static async fetchTriageMilestones(token: string, owner: string, name: string): Promise<TriageMilestone[]> {
    const variables: Record<string, Object> = { 'owner': owner, 'name': name };
    const data = await graphql(TRIAGE_MILESTONES_QUERY, variables, token);
    return mapTriageMilestones(data);
  }

  /** Linked items 建议列表（最近更新的 issue；excludeId 用于排除 PR 自身） */
  static async fetchTriageLinked(token: string, owner: string, name: string,
    excludeId: string): Promise<TriageLinkedItem[]> {
    const variables: Record<string, Object> = { 'owner': owner, 'name': name };
    const data = await graphql(TRIAGE_LINKED_QUERY, variables, token);
    return mapTriageLinked(data, excludeId);
  }

  /** 项目候选（RECENT=仓库项目 / USER=当前账号项目） */
  static async fetchTriageProjects(token: string, owner: string, name: string,
    scope: string): Promise<TriageProject[]> {
    const variables: Record<string, Object> = { 'owner': owner, 'name': name };
    const data = await graphql(TRIAGE_PROJECTS_QUERY, variables, token);
    return mapTriageProjects(data, scope);
  }

  // ─────────────── Spec 044 元数据编辑器：保存 ───────────────

  /** 负责人保存（整组替换，官方多选语义） */
  static async setPrAssignees(token: string, prId: string, userIds: string[]): Promise<void> {
    const variables: Record<string, Object> = { 'prId': prId, 'ids': userIds };
    await graphql(SET_PR_ASSIGNEES_MUTATION, variables, token);
  }

  /** 里程碑保存（milestoneId='' 即清除） */
  static async setPrMilestone(token: string, prId: string, milestoneId: string): Promise<void> {
    // 传 null 即「清除里程碑」：Record<string, Object> 不收 null，故用不带该键的文档分支
    if (milestoneId === '') {
      const clearVars: Record<string, Object> = { 'prId': prId };
      await graphql(CLEAR_PR_MILESTONE_MUTATION, clearVars, token);
      return;
    }
    const variables: Record<string, Object> = { 'prId': prId, 'milestoneId': milestoneId };
    await graphql(SET_PR_MILESTONE_MUTATION, variables, token);
  }

  /** 标签保存：先加后删（差异推送） */
  static async setPrLabels(token: string, prId: string, addIds: string[], removeIds: string[]): Promise<void> {
    if (addIds.length > 0) {
      const addVars: Record<string, Object> = { 'labelableId': prId, 'labelIds': addIds };
      await graphql(ADD_LABELS_MUTATION, addVars, token);
    }
    if (removeIds.length > 0) {
      const removeVars: Record<string, Object> = { 'labelableId': prId, 'labelIds': removeIds };
      await graphql(REMOVE_LABELS_MUTATION, removeVars, token);
    }
  }

  /** 项目拉入（addProjectV2ItemById） */
  static async addPrToProject(token: string, prId: string, projectId: string): Promise<void> {
    const variables: Record<string, Object> = { 'projectId': projectId, 'contentId': prId };
    await graphql(ADD_PROJECT_ITEM_MUTATION, variables, token);
  }
}
