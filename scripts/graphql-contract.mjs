/**
 * GraphQL 契约检查清单：scripts/check-graphql.sh 逐条 gh api graphql 实测（errors==null 即过）。
 * 约束：query 必须与生产常量一致（这里从 services/RepoSubService.ets 原样提取）；
 *       variables 引用值须真实存在（空节点子字段不被解析，验不到字段）。
 * 新增/修改 GraphQL 查询时：同步更新各服务的查询常量后，在本文件追加一条。
 * 设计动机：schema 字段漂移（历史事故：Release body 字段不存在、GitActor 无 login）→ 整页挂。
 */
export default [
  {
    name: 'REPO_COMMITS_QUERY',
    query: `query RepoCommits($owner: String!, $name: String!, $first: Int = 40, $after: String) {
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
}`,
    variables: {"owner": "ZM-BAD", "name": "arkcat", "first": 1}
  },
  {
    name: 'PR_DETAIL_QUERY',
    query: `query PullRequestDetail($owner: String!, $name: String!, $number: Int!, $after: String) {
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
        pageInfo { hasNextPage endCursor }
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
}`,
    variables: {"owner": "ZM-BAD", "name": "arkcat", "number": 1}
  },
  {
    name: 'PR_FILES_QUERY',
    query: `query PullRequestFiles($owner: String!, $name: String!, $number: Int!) {
  repository(owner: $owner, name: $name) {
    pullRequest(number: $number) {
      id
      additions
      deletions
      files(first: 100) {
totalCount
pageInfo { hasNextPage endCursor }
nodes { path additions deletions }
      }
    }
  }
}`,
    variables: {"owner": "ZM-BAD", "name": "arkcat", "number": 1}
  },
  {
    name: 'COMMIT_DETAIL_QUERY',
    query: `query CommitDetail($owner: String!, $name: String!, $oid: String!) {
  repository(owner: $owner, name: $name) {
    object(expression: $oid) {
      ... on Commit {
oid messageHeadline messageBodyHTML committedDate
author { name avatarUrl user { login } }
statusCheckRollup { state }
      }
    }
  }
}`,
    variables: {"owner": "ZM-BAD", "name": "arkcat", "oid": "115eb3488d24d06959d43a0552e5f296c59fcfd9"}
  },
  {
    name: 'ISSUE_DETAIL_QUERY',
    query: `query IssueDetail($owner: String!, $name: String!, $number: Int!, $first: Int = 20, $after: String) {
  repository(owner: $owner, name: $name) {
    issue(number: $number) {
      id title state stateReason body bodyHTML createdAt
      # 编辑权限门（Spec 043：编辑/关闭入口显隐）
      viewerCanUpdate
      author { login avatarUrl }
      labels(first: 10) { nodes { name } }
      comments(first: $first, after: $after) {
        totalCount
        pageInfo { hasNextPage endCursor }
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
}`,
    variables: {"owner": "ZM-BAD", "name": "arkcat", "number": 33}
  },
  {
    name: 'REPO_FORM_QUERY',
    query: `query RepoForm($owner: String!, $name: String!) {
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
}`,
    variables: {"owner": "ZM-BAD", "name": "arkcat"}
  },
  {
    name: 'BRANCH_REFS_QUERY',
    query: `query BranchRefs($owner: String!, $name: String!, $after: String) {
  repository(owner: $owner, name: $name) {
    defaultBranchRef { name }
    refs(refPrefix: "refs/heads/", first: 100, after: $after) {
      totalCount
      pageInfo { hasNextPage endCursor }
      nodes { name }
    }
  }
}`,
    variables: {"owner": "ZM-BAD", "name": "arkcat"}
  },
  {
    name: 'REF_TIP_QUERY',
    query: `query RefTip($owner: String!, $name: String!, $qualified: String!) {
  repository(owner: $owner, name: $name) {
    ref(qualifiedName: $qualified) { target { ... on Commit { oid committedDate } } }
  }
}`,
    variables: {"owner": "ZM-BAD", "name": "arkcat", "qualified": "refs/heads/develop"}
  },
  {
    name: 'ISSUE_EDIT_QUERY',
    query: `query IssueEdit($owner: String!, $name: String!, $number: Int!) {
  repository(owner: $owner, name: $name) {
    issue(number: $number) { id title body viewerCanUpdate }
  }
}`,
    variables: {"owner": "ZM-BAD", "name": "arkcat", "number": 33}
  },
  {
    name: 'PR_EDIT_QUERY',
    query: `query PullRequestEdit($owner: String!, $name: String!, $number: Int!) {
  repository(owner: $owner, name: $name) {
    pullRequest(number: $number) { id title body viewerCanUpdate }
  }
}`,
    variables: {"owner": "ZM-BAD", "name": "arkcat", "number": 51}
  },
  {
    name: 'VIEWER_REPOS_QUERY',
    query: `query PickerRepos($first: Int = 100) {
  viewer {
    repositories(first: $first, affiliations: [OWNER, COLLABORATOR, ORGANIZATION_MEMBER], orderBy: { field: PUSHED_AT, direction: DESC }) {
      nodes { id name owner { login avatarUrl } }
    }
    repositoriesContributedTo(first: $first, includeUserRepositories: false) {
      nodes { id name owner { login avatarUrl } }
    }
  }
}`,
    variables: {"first": 1}
  },
  {
    name: 'SEARCH_PICKER_REPOS_QUERY',
    query: `query SearchPickerRepos($query: String!, $first: Int = 20) {
  search(query: $query, type: REPOSITORY, first: $first) {
    nodes { ... on Repository { id name owner { login avatarUrl } } }
  }
}`,
    variables: {"query": "hypit in:name", "first": 1}
  },
];
