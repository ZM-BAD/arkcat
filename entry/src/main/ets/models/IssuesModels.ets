/**
 * Issue 列表数据模型与映射（Spec 007）。
 */
import { Json, JsonMap } from '../utils/Json';

/** Issue 卡片数据 */
export interface IssueSummary {
  id: string;
  number: number;
  title: string;
  state: string;
  createdAt: string;
  authorLogin: string;
  labels: string[];
  commentCount: number;
  linkedPrCount: number;
  assignees: string[];
}

/** Issues 列表页数据（含分页游标） */
export interface IssuesPage {
  totalCount: number;
  hasNextPage: boolean;
  endCursor: string;
  issues: IssueSummary[];
  repoLabels: string[];
}

/** GraphQL repository.issues 节点 → IssueSummary */
export function mapIssue(raw: JsonMap): IssueSummary {
  const author = Json.obj(raw, 'author');
  const labelsWrap = Json.obj(raw, 'labels');
  const labels: string[] = [];
  if (labelsWrap !== null) {
    for (const nodeItem of Json.arr(labelsWrap, 'nodes')) {
      labels.push(Json.str(nodeItem as JsonMap, 'name'));
    }
  }
  const comments = Json.obj(raw, 'comments');
  const assigneesWrap = Json.obj(raw, 'assignees');
  const assignees: string[] = [];
  if (assigneesWrap !== null) {
    for (const nodeItem of Json.arr(assigneesWrap, 'nodes')) {
      assignees.push(Json.str(nodeItem as JsonMap, 'login'));
    }
  }
  const timeline = Json.obj(raw, 'timelineItems');
  let linkedPrCount = 0;
  if (timeline !== null) {
    for (const nodeItem of Json.arr(timeline, 'nodes')) {
      const source = Json.obj(nodeItem as JsonMap, 'source');
      if (source !== null && Json.num(source, 'number') > 0) {
        linkedPrCount++;
      }
    }
  }
  return {
    id: Json.str(raw, 'id'),
    number: Json.num(raw, 'number'),
    title: Json.str(raw, 'title'),
    state: Json.str(raw, 'state'),
    createdAt: Json.str(raw, 'createdAt'),
    authorLogin: author ? Json.str(author, 'login') : '',
    labels: labels,
    commentCount: comments ? Json.num(comments, 'totalCount') : 0,
    linkedPrCount: linkedPrCount,
    assignees: assignees
  };
}

/** GraphQL IssuesList 响应 → IssuesPage */
export function mapIssuesPage(data: JsonMap): IssuesPage {
  const repo = Json.obj(data, 'repository') ?? ({} as JsonMap);
  const issuesWrap = Json.obj(repo, 'issues') ?? ({} as JsonMap);
  const pageInfo = Json.obj(issuesWrap, 'pageInfo');
  const issues: IssueSummary[] = [];
  for (const nodeItem of Json.arr(issuesWrap, 'nodes')) {
    issues.push(mapIssue(nodeItem as JsonMap));
  }
  const labelsWrap = Json.obj(repo, 'labels');
  const repoLabels: string[] = [];
  if (labelsWrap !== null) {
    for (const nodeItem of Json.arr(labelsWrap, 'nodes')) {
      repoLabels.push(Json.str(nodeItem as JsonMap, 'name'));
    }
  }
  return {
    totalCount: Json.num(issuesWrap, 'totalCount'),
    hasNextPage: pageInfo ? Json.bool(pageInfo, 'hasNextPage') : false,
    endCursor: pageInfo ? Json.str(pageInfo, 'endCursor') : '',
    issues: issues,
    repoLabels: repoLabels
  };
}
