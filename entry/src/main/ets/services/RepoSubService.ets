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
  mapTriageUsers, mapTriageLabels, mapTriageMilestones, mapTriageLinked, mapTriageProjects,
  RepoFormPage, EditableContent, PickerRepo, IssueCreated,
  mapRepoForm, mapEditable, mapPickerRepos, mapPickerSearch,
  IssueTemplateExtras, parseContactLinks, parseIssueFormMeta
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
      # 编辑权限门（Spec 043：编辑/关闭入口显隐）
      viewerCanUpdate
      author { login avatarUrl }
      labels(first: 10) { nodes { name } }
      comments(first: $first, after: $after) {
        totalCount
        ${FRAG_PAGE_INFO}
        nodes {
          id body bodyHTML createdAt
          author { __typename login avatarUrl }
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
      # 编辑权限门（Spec 043：编辑/关闭/draft 切换入口显隐）
      viewerCanUpdate
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
            nodes { id body bodyHTML createdAt author { __typename login avatarUrl } viewerDidAuthor }
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
            commit { oid messageHeadline author { avatarUrl } }
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
          ... on LabeledEvent { id createdAt actor { __typename login } label { name } }
          ... on UnlabeledEvent { id createdAt actor { __typename login } label { name } }
          ... on AssignedEvent {
            id createdAt
            actor { __typename login }
            assignee { __typename ... on User { login } ... on Bot { login } ... on Mannequin { login } ... on Organization { name } }
          }
          ... on UnassignedEvent {
            id createdAt
            actor { __typename login }
            assignee { __typename ... on User { login } ... on Bot { login } ... on Mannequin { login } ... on Organization { name } }
          }
          ... on ReviewRequestedEvent {
            id createdAt
            actor { __typename login }
            requestedReviewer { __typename ... on User { login } ... on Bot { login } ... on Mannequin { login } ... on Team { name } }
          }
          ... on ReviewRequestRemovedEvent {
            id createdAt
            actor { __typename login }
            requestedReviewer { __typename ... on User { login } ... on Bot { login } ... on Mannequin { login } ... on Team { name } }
          }
          ... on MergedEvent { id createdAt actor { __typename login } commit { abbreviatedOid } mergeRefName }
          ... on ClosedEvent { id createdAt actor { __typename login } }
          ... on ReopenedEvent { id createdAt actor { __typename login } }
          ... on ConvertToDraftEvent { id createdAt actor { __typename login } }
          ... on ReadyForReviewEvent { id createdAt actor { __typename login } }
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

// ─────────────── Spec 043：Issue/PR 创建与编辑 ───────────────

/** 表单基础数据（New Issue / New PR 共用）：仓库 id/默认分支 + 官方 Issue 模板 + 分支列表 + 安全政策 */
const REPO_FORM_QUERY = `
query RepoForm($owner: String!, $name: String!) {
  repository(owner: $owner, name: $name) {
    id
    defaultBranchRef { name }
    issueTemplates {
      name title body filename about
      labels(first: 10) { nodes { name } }
      assignees(first: 10) { nodes { login } }
    }
    refs(refPrefix: "refs/heads/", first: 100) {
      nodes { name target { oid } }
    }
    securityPolicyUrl
  }
}`;

/** 编辑 Issue 回填（标题/正文 + viewerCanUpdate 权限门） */
const ISSUE_EDIT_QUERY = `
query IssueEdit($owner: String!, $name: String!, $number: Int!) {
  repository(owner: $owner, name: $name) {
    issue(number: $number) { id title body viewerCanUpdate }
  }
}`;

/** 编辑 PR 回填（标题/正文 + viewerCanUpdate 权限门） */
const PR_EDIT_QUERY = `
query PullRequestEdit($owner: String!, $name: String!, $number: Int!) {
  repository(owner: $owner, name: $name) {
    pullRequest(number: $number) { id title body viewerCanUpdate }
  }
}`;

/** Home「+」Choose a repository 选仓库页候选（本人/协作/组织成员仓库 + 本人参与过的仓库，按最近推送序；
 *  官方列表口径 = 两者并集——公开仓库如 hypit-ai/hypit 即来自 contributedTo） */
const VIEWER_REPOS_QUERY = `
query PickerRepos($first: Int = 100) {
  viewer {
    repositories(first: $first, affiliations: [OWNER, COLLABORATOR, ORGANIZATION_MEMBER], orderBy: { field: PUSHED_AT, direction: DESC }) {
      nodes { id name owner { login avatarUrl } }
    }
    repositoriesContributedTo(first: $first, includeUserRepositories: false) {
      nodes { id name owner { login avatarUrl } }
    }
  }
}`;

/** 选仓库页搜索（官方为服务端全网仓库检索，公开仓库亦可建 Issue） */
const SEARCH_PICKER_REPOS_QUERY = `
query SearchPickerRepos($query: String!, $first: Int = 20) {
  search(query: $query, type: REPOSITORY, first: $first) {
    nodes { ... on Repository { id name owner { login avatarUrl } } }
  }
}`;

/** 新建 Issue（成功后调用方按返回 number 跳详情；id 供创建后挂 Project） */
const CREATE_ISSUE_MUTATION = `
mutation CreateIssue($repositoryId: ID!, $title: String!, $body: String!) {
  createIssue(input: { repositoryId: $repositoryId, title: $title, body: $body }) {
    issue { id number }
  }
}`;

/** 新建 Issue + 创建即选属性（官方表单底部 Assignee/Label/Milestone 芯片；Project 创建后单独挂） */
const CREATE_ISSUE_ATTRS_MUTATION = `
mutation CreateIssueWithAttrs($repositoryId: ID!, $title: String!, $body: String!, $assigneeIds: [ID!], $labelIds: [ID!], $milestoneId: ID) {
  createIssue(input: { repositoryId: $repositoryId, title: $title, body: $body, assigneeIds: $assigneeIds, labelIds: $labelIds, milestoneId: $milestoneId }) {
    issue { id number }
  }
}`;

/** 新建 PR（base/head 为分支名；head 不存在由服务端 422，客户端提交前校验） */
const CREATE_PULL_REQUEST_MUTATION = `
mutation CreatePullRequest($repositoryId: ID!, $base: String!, $head: String!, $title: String!, $body: String!) {
  createPullRequest(input: { repositoryId: $repositoryId, baseRefName: $base, headRefName: $head, title: $title, body: $body }) {
    pullRequest { id number }
  }
}`;

/** 编辑 Issue 标题/正文（id = Issue 节点 id；body 传空串即清空正文，与官方语义一致） */
const UPDATE_ISSUE_MUTATION = `
mutation UpdateIssueTitleBody($id: ID!, $title: String!, $body: String!) {
  updateIssue(input: { id: $id, title: $title, body: $body }) { issue { id } }
}`;

/** 编辑 PR 标题/正文 */
const UPDATE_PULL_REQUEST_MUTATION = `
mutation UpdatePullRequestTitleBody($pullRequestId: ID!, $title: String!, $body: String!) {
  updatePullRequest(input: { pullRequestId: $pullRequestId, title: $title, body: $body }) { pullRequest { id } }
}`;

/** 关闭 Issue（官方两档关闭原因：COMPLETED / NOT_PLANNED） */
const CLOSE_ISSUE_MUTATION = `
mutation CloseIssue($issueId: ID!, $stateReason: IssueStateReason!) {
  closeIssue(input: { issueId: $issueId, stateReason: $stateReason }) {
    issue { id state stateReason }
  }
}`;

const REOPEN_ISSUE_MUTATION = `
mutation ReopenIssue($issueId: ID!) {
  reopenIssue(input: { issueId: $issueId }) { issue { id state } }
}`;

const CLOSE_PULL_REQUEST_MUTATION = `
mutation ClosePullRequest($pullRequestId: ID!) {
  closePullRequest(input: { pullRequestId: $pullRequestId }) { pullRequest { id state } }
}`;

const REOPEN_PULL_REQUEST_MUTATION = `
mutation ReopenPullRequest($pullRequestId: ID!) {
  reopenPullRequest(input: { pullRequestId: $pullRequestId }) { pullRequest { id state } }
}`;

/** PR 转 draft */
const CONVERT_TO_DRAFT_MUTATION = `
mutation ConvertPullRequestToDraft($pullRequestId: ID!) {
  convertPullRequestToDraft(input: { pullRequestId: $pullRequestId }) { pullRequest { id isDraft } }
}`;

/** draft 转待审查 */
const MARK_READY_MUTATION = `
mutation MarkPullRequestReadyForReview($pullRequestId: ID!) {
  markPullRequestReadyForReview(input: { pullRequestId: $pullRequestId }) { pullRequest { id isDraft } }
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

  // ─────────────── Spec 043：Issue/PR 创建与编辑 ───────────────

  /** 表单基础数据：仓库 id/默认分支/官方 Issue 模板/分支列表 */
  static async fetchRepoForm(token: string, owner: string, name: string): Promise<RepoFormPage> {
    const variables: Record<string, Object> = { 'owner': owner, 'name': name };
    const data = await graphql(REPO_FORM_QUERY, variables, token);
    return mapRepoForm(data);
  }

  /**
   * .github/ISSUE_TEMPLATE 目录补全（Spec 043：GraphQL issueTemplates 不含 issue forms(.yml)
   * 与 config.yml 联系链接——官方模板页同样展示，forms/联系链接均外链跳网页）。
   * 目录不存在（无模板仓库 404）返回空聚合；单文件失败跳过不阻断。
   */
  static async fetchIssueTemplateExtras(token: string, owner: string, name: string): Promise<IssueTemplateExtras> {
    const out: IssueTemplateExtras = { forms: [], contactLinks: [] };
    const files: string[] = [];
    try {
      const listing = await restGet(`/repos/${owner}/${name}/contents/.github/ISSUE_TEMPLATE`, token);
      const arr: Object[] = JSON.parse(listing.body) as Object[];
      for (const node of arr) {
        const fileName = Json.str(node as JsonMap, 'name');
        if (fileName.endsWith('.yml') || fileName.endsWith('.yaml')) {
          files.push(fileName);
        }
      }
    } catch (e) {
      return out;
    }
    for (const fileName of files) {
      try {
        const resp = await restGet(`/repos/${owner}/${name}/contents/.github/ISSUE_TEMPLATE/${fileName}`,
          token, 'application/vnd.github.raw');
        if (fileName === 'config.yml' || fileName === 'config.yaml') {
          out.contactLinks = parseContactLinks(resp.body);
        } else {
          const meta = parseIssueFormMeta(resp.body, fileName);
          if (meta !== null) {
            out.forms.push(meta);
          }
        }
      } catch (e) {
        // 单文件拉取失败跳过
      }
    }
    return out;
  }

  /**
   * 是否需要 Choose Template 选模板页（Spec 043 官方动线判定，所有 Create Issue 入口共用）：
   * 经典模板 / issue forms / 联系链接任一存在即 true；查询失败按 false（直达表单，服务端兜底）。
   */
  static async hasTemplateChooser(token: string, owner: string, name: string): Promise<boolean> {
    try {
      const page = await RepoSubService.fetchRepoForm(token, owner, name);
      if (page.templates.length > 0) {
        return true;
      }
      const extras = await RepoSubService.fetchIssueTemplateExtras(token, owner, name);
      return extras.forms.length > 0 || extras.contactLinks.length > 0;
    } catch (e) {
      return false;
    }
  }

  /** 编辑 Issue 回填（id/title/body/viewerCanUpdate） */
  static async fetchIssueEdit(token: string, owner: string, name: string, number: number): Promise<EditableContent> {
    const variables: Record<string, Object> = { 'owner': owner, 'name': name, 'number': number };
    const data = await graphql(ISSUE_EDIT_QUERY, variables, token);
    return mapEditable(data, 'issue');
  }

  /** 编辑 PR 回填 */
  static async fetchPrEdit(token: string, owner: string, name: string, number: number): Promise<EditableContent> {
    const variables: Record<string, Object> = { 'owner': owner, 'name': name, 'number': number };
    const data = await graphql(PR_EDIT_QUERY, variables, token);
    return mapEditable(data, 'pullRequest');
  }

  /** Home「+」仓库候选（本人/协作/组织成员/参与过的仓库并集，按最近推送序） */
  static async fetchPickerRepos(token: string): Promise<PickerRepo[]> {
    const data = await graphql(VIEWER_REPOS_QUERY, { 'first': 100 }, token);
    return mapPickerRepos(data);
  }

  /** 选仓库页服务端仓库搜索（query 原样下发，官方按最佳匹配排序） */
  static async searchPickerRepos(token: string, keyword: string): Promise<PickerRepo[]> {
    const variables: Record<string, Object> = { 'query': keyword, 'first': 20 };
    const data = await graphql(SEARCH_PICKER_REPOS_QUERY, variables, token);
    return mapPickerSearch(data);
  }

  /** 新建 Issue：返回新 Issue 的 id + 编号（调用方跳详情 / 挂 Project） */
  static async createIssue(token: string, repositoryId: string, title: string, body: string,
    assigneeIds: string[], labelIds: string[], milestoneId: string): Promise<IssueCreated> {
    const base: Record<string, Object> = { 'repositoryId': repositoryId, 'title': title, 'body': body };
    let data: JsonMap;
    if (assigneeIds.length > 0 || labelIds.length > 0 || milestoneId !== '') {
      const vars: Record<string, Object> = base;
      if (assigneeIds.length > 0) {
        vars['assigneeIds'] = assigneeIds;
      }
      if (labelIds.length > 0) {
        vars['labelIds'] = labelIds;
      }
      if (milestoneId !== '') {
        vars['milestoneId'] = milestoneId;
      }
      data = await graphql(CREATE_ISSUE_ATTRS_MUTATION, vars, token);
    } else {
      data = await graphql(CREATE_ISSUE_MUTATION, base, token);
    }
    const issue = Json.obj(Json.obj(data, 'createIssue') ?? ({} as JsonMap), 'issue') ?? ({} as JsonMap);
    return { id: Json.str(issue, 'id'), number: Json.num(issue, 'number') };
  }

  /** 新建 PR：返回新 PR 编号（调用方跳详情） */
  static async createPullRequest(token: string, repositoryId: string, base: string, head: string,
    title: string, body: string): Promise<number> {
    const variables: Record<string, Object> = {
      'repositoryId': repositoryId, 'base': base, 'head': head, 'title': title, 'body': body
    };
    const data = await graphql(CREATE_PULL_REQUEST_MUTATION, variables, token);
    const pr = Json.obj(Json.obj(data, 'createPullRequest') ?? ({} as JsonMap), 'pullRequest') ?? ({} as JsonMap);
    return Json.num(pr, 'number');
  }

  /** 编辑 Issue 标题/正文 */
  static async updateIssue(token: string, issueId: string, title: string, body: string): Promise<void> {
    const variables: Record<string, Object> = { 'id': issueId, 'title': title, 'body': body };
    await graphql(UPDATE_ISSUE_MUTATION, variables, token);
  }

  /** 编辑 PR 标题/正文 */
  static async updatePullRequest(token: string, prId: string, title: string, body: string): Promise<void> {
    const variables: Record<string, Object> = { 'pullRequestId': prId, 'title': title, 'body': body };
    await graphql(UPDATE_PULL_REQUEST_MUTATION, variables, token);
  }

  /** 关闭 Issue（stateReason: COMPLETED / NOT_PLANNED，官方两档） */
  static async closeIssue(token: string, issueId: string, stateReason: string): Promise<void> {
    const variables: Record<string, Object> = { 'issueId': issueId, 'stateReason': stateReason };
    await graphql(CLOSE_ISSUE_MUTATION, variables, token);
  }

  /** 重开 Issue */
  static async reopenIssue(token: string, issueId: string): Promise<void> {
    const variables: Record<string, Object> = { 'issueId': issueId };
    await graphql(REOPEN_ISSUE_MUTATION, variables, token);
  }

  /** 关闭 PR */
  static async closePullRequest(token: string, prId: string): Promise<void> {
    const variables: Record<string, Object> = { 'pullRequestId': prId };
    await graphql(CLOSE_PULL_REQUEST_MUTATION, variables, token);
  }

  /** 重开 PR */
  static async reopenPullRequest(token: string, prId: string): Promise<void> {
    const variables: Record<string, Object> = { 'pullRequestId': prId };
    await graphql(REOPEN_PULL_REQUEST_MUTATION, variables, token);
  }

  /** PR 转 draft */
  static async convertPullRequestToDraft(token: string, prId: string): Promise<void> {
    const variables: Record<string, Object> = { 'pullRequestId': prId };
    await graphql(CONVERT_TO_DRAFT_MUTATION, variables, token);
  }

  /** draft 转待审查 */
  static async markPullRequestReadyForReview(token: string, prId: string): Promise<void> {
    const variables: Record<string, Object> = { 'pullRequestId': prId };
    await graphql(MARK_READY_MUTATION, variables, token);
  }
}
