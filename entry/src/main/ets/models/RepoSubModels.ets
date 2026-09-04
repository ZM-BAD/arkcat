/**
 * 仓库二级页面数据模型与映射（Spec 027-031）。
 * 仓库内 PR 列表 / Commits / Releases / Issue 详情 / PR 详情。
 * 模型保持纯数据接口；映射/过滤器集中在此，便于单元测试。
 */
import { Json, JsonMap } from '../utils/Json';
import { WorkLabel } from './WorkModels';

/** 仓库内 PR 行 */
export interface RepoPrItem {
  id: string;
  number: number;
  title: string;
  state: string;
  merged: boolean;
  createdAt: string;
  labels: WorkLabel[];
  commentCount: number;
  reviewCount: number;
  checksState: string;
  authorLogin: string;
  authorAvatar: string;
  assignees: string[];
}

export interface RepoPrsPage {
  hasNextPage: boolean;
  endCursor: string;
  totalCount: number;
  prs: RepoPrItem[];
  labelOptions: string[];
  authorOptions: string[];
  assigneeOptions: string[];
}

/** Commits 行 */
export interface RepoCommitItem {
  oid: string;
  headline: string;
  committedDate: string;
  authorLogin: string;
  authorAvatar: string;
  /** SUCCESS 显示绿✓，其余空 */
  checksState: string;
}

export interface RepoCommitsPage {
  hasNextPage: boolean;
  endCursor: string;
  commits: RepoCommitItem[];
}

/** Release 行 */
export interface ReleaseItem {
  id: string;
  tagName: string;
  isLatest: boolean;
  createdAt: string;
  description: string;
  body: string;
  /** 官方渲染 HTML（Spec 040：MarkdownView 直渲，body 作降级） */
  bodyHTML: string;
  authorLogin: string;
  authorAvatar: string;
}

export interface RepoReleasesPage {
  hasNextPage: boolean;
  endCursor: string;
  releases: ReleaseItem[];
}

/** 评论（Issue/PR 通用，ArkTS 名义类型：单一 interface 复用） */
export interface RepoComment {
  id: string;
  body: string;
  /** 官方渲染 HTML（Spec 040），body 作降级 */
  bodyHTML: string;
  createdAt: string;
  authorLogin: string;
  authorAvatar: string;
}

export interface IssueDetailPage {
  number: number;
  title: string;
  state: string;
  stateReason: string;
  body: string;
  /** 官方渲染 HTML（Spec 040），body 作降级 */
  bodyHTML: string;
  createdAt: string;
  authorLogin: string;
  authorAvatar: string;
  labels: string[];
  commentCount: number;
  comments: RepoComment[];
  hasNextPage: boolean;
  endCursor: string;
}

/** Checks 列表行（statusCheckRollup.contexts：CheckRun/StatusContext 归一化） */
export interface StatusCheckItem {
  name: string;
  state: string;
}

export interface PrDetailPage {
  number: number;
  title: string;
  state: string;
  merged: boolean;
  isDraft: boolean;
  body: string;
  /** 官方渲染 HTML（Spec 040），body 作降级 */
  bodyHTML: string;
  createdAt: string;
  mergedAt: string;
  additions: number;
  deletions: number;
  authorLogin: string;
  authorAvatar: string;
  headRefName: string;
  baseRefName: string;
  mergeOid: string;
  mergedByLogin: string;
  filesCount: number;
  commitsCount: number;
  reviewsTotal: number;
  checksState: string;
  checks: StatusCheckItem[];
  comments: RepoComment[];
}

// ─────────────── 纯函数：客户端过滤 ───────────────

/** Author 客户端过滤（首屏作者集合） */
export function filterPrsByAuthor(prs: RepoPrItem[], author: string): RepoPrItem[] {
  const next: RepoPrItem[] = [];
  for (const pr of prs) {
    if (author === '' || pr.authorLogin === author) {
      next.push(pr);
    }
  }
  return next;
}

/** Assignee 客户端过滤（首屏分配人集合） */
export function filterPrsByAssignee(prs: RepoPrItem[], assignee: string): RepoPrItem[] {
  const next: RepoPrItem[] = [];
  for (const pr of prs) {
    if (assignee === '' || pr.assignees.indexOf(assignee) >= 0) {
      next.push(pr);
    }
  }
  return next;
}

/** PR 状态图（复用 018 规范）：merged/open/closed */
export function repoPrIconKey(state: string, merged: boolean): string {
  if (merged || state === 'MERGED') {
    return 'merged';
  }
  return state === 'OPEN' ? 'open' : 'closed';
}

/** ISO 日期 → "June 30"（官方 released this 用月名 + 日；未知解析回退空串） */
export function monthDayText(iso: string): string {
  const months = ['January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'];
  const t = Date.parse(iso);
  if (Number.isNaN(t)) {
    return '';
  }
  const d = new Date(t);
  return `${months[d.getMonth()]} ${d.getDate()}`;
}

// ─────────────── 响应映射 ───────────────

export function mapRepoPr(raw: JsonMap): RepoPrItem {
  const labelsWrap = Json.obj(raw, 'labels');
  const labels: WorkLabel[] = [];
  if (labelsWrap !== null) {
    for (const nodeItem of Json.arr(labelsWrap, 'nodes')) {
      const node = nodeItem as JsonMap;
      labels.push({ name: Json.str(node, 'name'), color: Json.str(node, 'color') });
    }
  }
  const comments = Json.obj(raw, 'comments');
  const reviews = Json.obj(raw, 'reviewRequests');
  const checks = Json.obj(raw, 'statusCheckRollup');
  const author = Json.obj(raw, 'author');
  const assigneesWrap = Json.obj(raw, 'assignees');
  const assignees: string[] = [];
  if (assigneesWrap !== null) {
    for (const nodeItem of Json.arr(assigneesWrap, 'nodes')) {
      assignees.push(Json.str(nodeItem as JsonMap, 'login'));
    }
  }
  const state = Json.str(raw, 'state');
  const merged = Json.bool(raw, 'merged');
  return {
    id: Json.str(raw, 'id'),
    number: Json.num(raw, 'number'),
    title: Json.str(raw, 'title'),
    state: state,
    merged: merged,
    createdAt: Json.str(raw, 'createdAt'),
    labels: labels,
    commentCount: comments !== null ? Json.num(comments, 'totalCount') : 0,
    reviewCount: reviews !== null ? Json.num(reviews, 'totalCount') : 0,
    checksState: checks !== null ? Json.str(checks, 'state') : '',
    authorLogin: author !== null ? Json.str(author, 'login') : '',
    authorAvatar: author !== null ? Json.str(author, 'avatarUrl') : '',
    assignees: assignees
  };
}

/** 页面主键（027 相关） */
export function mapRepoPrsPage(data: JsonMap): RepoPrsPage {
  const repo = Json.obj(data, 'repository') ?? ({} as JsonMap);
  const prsWrap = Json.obj(repo, 'pullRequests') ?? ({} as JsonMap);
  const pageInfo = Json.obj(prsWrap, 'pageInfo');
  const prs: RepoPrItem[] = [];
  for (const nodeItem of Json.arr(prsWrap, 'nodes')) {
    prs.push(mapRepoPr(nodeItem as JsonMap));
  }
  const authorSet: Set<string> = new Set();
  const assigneeSet: Set<string> = new Set();
  for (const pr of prs) {
    if (pr.authorLogin !== '') {
      authorSet.add(pr.authorLogin);
    }
    for (const a of pr.assignees) {
      assigneeSet.add(a);
    }
  }
  const labelsWrap = Json.obj(repo, 'labels');
  const labelOptions: string[] = [];
  if (labelsWrap !== null) {
    for (const nodeItem of Json.arr(labelsWrap, 'nodes')) {
      labelOptions.push(Json.str(nodeItem as JsonMap, 'name'));
    }
  }
  return {
    hasNextPage: pageInfo !== null ? Json.bool(pageInfo, 'hasNextPage') : false,
    endCursor: pageInfo !== null ? Json.str(pageInfo, 'endCursor') : '',
    totalCount: Json.num(prsWrap, 'totalCount'),
    prs: prs,
    labelOptions: labelOptions,
    authorOptions: Array.from(authorSet),
    assigneeOptions: Array.from(assigneeSet)
  };
}

export function mapRepoCommit(raw: JsonMap): RepoCommitItem {
  const author = Json.obj(raw, 'author');
  const authorUser = author !== null ? Json.obj(author, 'user') : null;
  const authorLogin = authorUser !== null && Json.str(authorUser, 'login') !== ''
    ? Json.str(authorUser, 'login')
    : (author !== null ? Json.str(author, 'name') : '');
  const checks = Json.obj(raw, 'statusCheckRollup');
  return {
    oid: Json.str(raw, 'oid'),
    headline: Json.str(raw, 'messageHeadline'),
    committedDate: Json.str(raw, 'committedDate'),
    authorLogin: authorLogin,
    authorAvatar: author !== null ? Json.str(author, 'avatarUrl') : '',
    checksState: checks !== null ? Json.str(checks, 'state') : ''
  };
}

export function mapRepoCommitsPage(data: JsonMap): RepoCommitsPage {
  const repo = Json.obj(data, 'repository') ?? ({} as JsonMap);
  const ref = Json.obj(repo, 'defaultBranchRef');
  const target = ref !== null ? Json.obj(ref, 'target') : null;
  const history = target !== null ? Json.obj(target, 'history') ?? ({} as JsonMap) : ({} as JsonMap);
  const pageInfo = Json.obj(history, 'pageInfo');
  const commits: RepoCommitItem[] = [];
  for (const nodeItem of Json.arr(history, 'nodes')) {
    commits.push(mapRepoCommit(nodeItem as JsonMap));
  }
  return {
    hasNextPage: pageInfo !== null ? Json.bool(pageInfo, 'hasNextPage') : false,
    endCursor: pageInfo !== null ? Json.str(pageInfo, 'endCursor') : '',
    commits: commits
  };
}

/** PR commits 分页映射（pullRequest.commits 节点嵌套 commit 层） */
export function mapPrCommits(data: JsonMap): RepoCommitsPage {
  const repo = Json.obj(data, 'repository') ?? ({} as JsonMap);
  const pr = Json.obj(repo, 'pullRequest') ?? ({} as JsonMap);
  const commitsConn = Json.obj(pr, 'commits') ?? ({} as JsonMap);
  const pageInfo = Json.obj(commitsConn, 'pageInfo');
  const commits: RepoCommitItem[] = [];
  for (const nodeItem of Json.arr(commitsConn, 'nodes')) {
    const commit = Json.obj(nodeItem as JsonMap, 'commit');
    if (commit !== null) {
      commits.push(mapRepoCommit(commit));
    }
  }
  return {
    hasNextPage: pageInfo !== null ? Json.bool(pageInfo, 'hasNextPage') : false,
    endCursor: pageInfo !== null ? Json.str(pageInfo, 'endCursor') : '',
    commits: commits
  };
}

export function mapRelease(raw: JsonMap): ReleaseItem {
  const author = Json.obj(raw, 'author');
  return {
    id: Json.str(raw, 'id'),
    tagName: Json.str(raw, 'tagName'),
    isLatest: Json.bool(raw, 'isLatest'),
    createdAt: Json.str(raw, 'createdAt'),
    description: Json.str(raw, 'description'),
    body: Json.str(raw, 'body'),
    bodyHTML: Json.str(raw, 'bodyHTML'),
    authorLogin: author !== null ? Json.str(author, 'login') : '',
    authorAvatar: author !== null ? Json.str(author, 'avatarUrl') : ''
  };
}

export function mapRepoReleasesPage(data: JsonMap): RepoReleasesPage {
  const repo = Json.obj(data, 'repository') ?? ({} as JsonMap);
  const releasesWrap = Json.obj(repo, 'releases') ?? ({} as JsonMap);
  const pageInfo = Json.obj(releasesWrap, 'pageInfo');
  const releases: ReleaseItem[] = [];
  for (const nodeItem of Json.arr(releasesWrap, 'nodes')) {
    releases.push(mapRelease(nodeItem as JsonMap));
  }
  return {
    hasNextPage: pageInfo !== null ? Json.bool(pageInfo, 'hasNextPage') : false,
    endCursor: pageInfo !== null ? Json.str(pageInfo, 'endCursor') : '',
    releases: releases
  };
}

function mapComment(raw: JsonMap): RepoComment {
  const author = Json.obj(raw, 'author');
  return {
    id: Json.str(raw, 'id'),
    body: Json.str(raw, 'body'),
    bodyHTML: Json.str(raw, 'bodyHTML'),
    createdAt: Json.str(raw, 'createdAt'),
    authorLogin: author !== null ? Json.str(author, 'login') : '',
    authorAvatar: author !== null ? Json.str(author, 'avatarUrl') : ''
  };
}

export function mapIssueDetail(data: JsonMap): IssueDetailPage {
  const repo = Json.obj(data, 'repository') ?? ({} as JsonMap);
  const issue = Json.obj(repo, 'issue') ?? ({} as JsonMap);
  const author = Json.obj(issue, 'author');
  const labelsWrap = Json.obj(issue, 'labels');
  const labels: string[] = [];
  if (labelsWrap !== null) {
    for (const nodeItem of Json.arr(labelsWrap, 'nodes')) {
      labels.push(Json.str(nodeItem as JsonMap, 'name'));
    }
  }
  const commentsWrap = Json.obj(issue, 'comments') ?? ({} as JsonMap);
  const pageInfo = Json.obj(commentsWrap, 'pageInfo');
  const comments: RepoComment[] = [];
  for (const nodeItem of Json.arr(commentsWrap, 'nodes')) {
    comments.push(mapComment(nodeItem as JsonMap));
  }
  return {
    number: Json.num(issue, 'number'),
    title: Json.str(issue, 'title'),
    state: Json.str(issue, 'state'),
    stateReason: Json.str(issue, 'stateReason'),
    body: Json.str(issue, 'body'),
    bodyHTML: Json.str(issue, 'bodyHTML'),
    createdAt: Json.str(issue, 'createdAt'),
    authorLogin: author !== null ? Json.str(author, 'login') : '',
    authorAvatar: author !== null ? Json.str(author, 'avatarUrl') : '',
    labels: labels,
    commentCount: Json.num(commentsWrap, 'totalCount'),
    comments: comments,
    hasNextPage: pageInfo !== null ? Json.bool(pageInfo, 'hasNextPage') : false,
    endCursor: pageInfo !== null ? Json.str(pageInfo, 'endCursor') : ''
  };
}

export function mapPrDetail(data: JsonMap): PrDetailPage {
  const repo = Json.obj(data, 'repository') ?? ({} as JsonMap);
  const pr = Json.obj(repo, 'pullRequest') ?? ({} as JsonMap);
  const author = Json.obj(pr, 'author');
  const mergedBy = Json.obj(pr, 'mergedBy');
  const mergeCommit = Json.obj(pr, 'mergeCommit');
  const files = Json.obj(pr, 'files');
  const commitsSum = Json.obj(pr, 'commits');
  const reviews = Json.obj(pr, 'reviews');
  const checks = Json.obj(pr, 'statusCheckRollup');
  const commentsWrap = Json.obj(pr, 'comments') ?? ({} as JsonMap);
  const comments: RepoComment[] = [];
  for (const nodeItem of Json.arr(commentsWrap, 'nodes')) {
    comments.push(mapComment(nodeItem as JsonMap));
  }
  return {
    number: Json.num(pr, 'number'),
    title: Json.str(pr, 'title'),
    state: Json.str(pr, 'state'),
    merged: Json.bool(pr, 'merged'),
    isDraft: Json.bool(pr, 'isDraft'),
    body: Json.str(pr, 'body'),
    bodyHTML: Json.str(pr, 'bodyHTML'),
    createdAt: Json.str(pr, 'createdAt'),
    mergedAt: Json.str(pr, 'mergedAt'),
    additions: Json.num(pr, 'additions'),
    deletions: Json.num(pr, 'deletions'),
    authorLogin: author !== null ? Json.str(author, 'login') : '',
    authorAvatar: author !== null ? Json.str(author, 'avatarUrl') : '',
    headRefName: Json.str(pr, 'headRefName'),
    baseRefName: Json.str(pr, 'baseRefName'),
    mergeOid: mergeCommit !== null ? Json.str(mergeCommit, 'abbreviatedOid') : '',
    mergedByLogin: mergedBy !== null ? Json.str(mergedBy, 'login') : '',
    filesCount: files !== null ? Json.num(files, 'totalCount') : 0,
    commitsCount: commitsSum !== null ? Json.num(commitsSum, 'totalCount') : 0,
    reviewsTotal: reviews !== null ? Json.num(reviews, 'totalCount') : 0,
    checksState: checks !== null ? Json.str(checks, 'state') : '',
    checks: mapStatusChecks(checks),
    comments: comments
  };
}

/** statusCheckRollup.contexts → 归一化行（CheckRun 用 conclusion，StatusContext 用 state） */
function mapStatusChecks(checks: JsonMap | null): StatusCheckItem[] {
  const items: StatusCheckItem[] = [];
  if (checks === null) {
    return items;
  }
  const conn = Json.obj(checks, 'contexts');
  if (conn === null) {
    return items;
  }
  for (const nodeItem of Json.arr(conn, 'nodes')) {
    const node = nodeItem as JsonMap;
    const name = Json.str(node, 'name') !== '' ? Json.str(node, 'name') : Json.str(node, 'context');
    const conclusion = Json.str(node, 'conclusion');
    const state = conclusion !== '' ? conclusion : Json.str(node, 'state');
    if (name !== '') {
      items.push({ name: name, state: state });
    }
  }
  return items;
}
