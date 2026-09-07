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
];
