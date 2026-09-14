/**
 * Issue 列表数据模型与映射（Spec 007）。
 */
import { Json, JsonMap } from '../utils/Json';
import { WorkLabel } from './WorkModels';

/** Issue 卡片数据 */
export interface IssueSummary {
  id: string;
  number: number;
  title: string;
  state: string;
  createdAt: string;
  authorLogin: string;
  /** 标签（带色：LabelPill 渲染用，DESIGN.md §1.2 数据色） */
  labels: WorkLabel[];
  commentCount: number;
  linkedPrCount: number;
  assignees: string[];
  /** 所属里程碑标题（无里程碑=''；仓库内 Issues 的 Milestone 筛选客户端过滤用） */
  milestoneTitle: string;
}

/** Issues 列表页数据（含分页游标） */
export interface IssuesPage {
  totalCount: number;
  hasNextPage: boolean;
  endCursor: string;
  issues: IssueSummary[];
  /** 仓库标签全集（带色：Label 筛选面板的 LabelPill 渲染用） */
  repoLabels: WorkLabel[];
}

/** GraphQL repository.issues 节点 → IssueSummary */
export function mapIssue(raw: JsonMap): IssueSummary {
  const author = Json.obj(raw, 'author');
  const labelsWrap = Json.obj(raw, 'labels');
  const labels: WorkLabel[] = [];
  if (labelsWrap !== null) {
    for (const nodeItem of Json.arr(labelsWrap, 'nodes')) {
      labels.push({ name: Json.str(nodeItem as JsonMap, 'name'), color: Json.str(nodeItem as JsonMap, 'color') });
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
  const milestone = Json.obj(raw, 'milestone');
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
    assignees: assignees,
    milestoneTitle: milestone ? Json.str(milestone, 'title') : ''
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
  const repoLabels: WorkLabel[] = [];
  if (labelsWrap !== null) {
    for (const nodeItem of Json.arr(labelsWrap, 'nodes')) {
      repoLabels.push({ name: Json.str(nodeItem as JsonMap, 'name'), color: Json.str(nodeItem as JsonMap, 'color') });
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
