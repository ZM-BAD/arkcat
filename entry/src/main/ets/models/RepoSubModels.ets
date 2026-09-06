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
  isDraft: boolean;
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
  /** release 标题（GitHub name，如 1.3.2；tagName 为 v1.3.2） */
  name: string;
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

/** 反应用户（reactionGroups.users 前 8 位） */
export interface ReactionUser {
  login: string;
  avatarUrl: string;
}

/** emoji 反应组（Spec 041）：content 为 ReactionContent 枚举（THUMBS_UP 等） */
export interface ReactionGroup {
  content: string;
  count: number;
  viewerHasReacted: boolean;
  users: ReactionUser[];
}

/** Release 资产（Spec 047）：二进制下载段 */
export interface ReleaseAsset {
  id: string;
  name: string;
  size: number;
  downloadCount: number;
  contentType: string;
  /** API 下载端点（带 token GET） */
  url: string;
}

export interface ReleaseDetailPage {
  id: string;
  tagName: string;
  /** 发布页 HTML 直链（分享/复制用） */
  releaseUrl: string;
  name: string;
  isDraft: boolean;
  isPrerelease: boolean;
  /** 是否最新发布（绿色 Latest 徽章用；2026-09-06 gh api 实测字段存在） */
  isLatest: boolean;
  /** tag 指向 commit 完整 sha（Info 分区截短展示；tagCommit 实测存在） */
  tagSha: string;
  publishedAt: string;
  createdAt: string;
  body: string;
  bodyHTML: string;
  authorLogin: string;
  authorAvatar: string;
  assets: ReleaseAsset[];
}

/** 字节数 → 人类可读（B/KB/MB/GB，保留 1 位小数；未知回退 0 B） */
export function formatBytes(size: number): string {
  if (size <= 0) {
    return '0 B';
  }
  const units: string[] = ['B', 'KB', 'MB', 'GB', 'TB'];
  let value = size;
  let unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value = value / 1024;
    unit++;
  }
  const text = unit === 0 ? `${value}` : value.toFixed(1);
  return `${text} ${units[unit]}`;
}

/** 资产浏览器下载直链：github.com/{o}/{r}/releases/download/{tag}/{name}（GraphQL ReleaseAsset 无此字段，REST 特有） */
export function releaseAssetBrowserUrl(owner: string, repo: string, tag: string, name: string): string {
  const safeTag = encodeURIComponent(tag);
  const safeName = encodeURIComponent(name);
  return `https://github.com/${owner}/${repo}/releases/download/${safeTag}/${safeName}`;
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
  /** 仅本人显示编辑/删除（GraphQL viewerDidAuthor） */
  viewerDidAuthor: boolean;
  reactions: ReactionGroup[];
}

export interface IssueDetailPage {
  /** 评论发布用节点 id（SubjectId） */
  subjectId: string;
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
  /** 评论发布用节点 id（SubjectId） */
  subjectId: string;
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
  /** 评论分页（review B7：与 IssueDetail 对齐，>20 条可 Load more） */
  commentsHasNext: boolean;
  commentsCursor: string;
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
export function repoPrIconKey(state: string, merged: boolean, isDraft: boolean): string {
  if (merged || state === 'MERGED') {
    return 'merged';
  }
  if (state === 'OPEN' && isDraft) {
    return 'draft';
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

// ─────────────── Reaction 常量（Spec 041）───────────────

export interface ReactionMeta {
  content: string;
  emoji: string;
}

/** 8 种官方 reaction（顺序即面板展示顺序；content 为 GraphQL ReactionContent 枚举） */
export const REACTION_META: ReactionMeta[] = [
  { content: 'THUMBS_UP', emoji: '👍' },
  { content: 'THUMBS_DOWN', emoji: '👎' },
  { content: 'LAUGH', emoji: '😄' },
  { content: 'HOORAY', emoji: '🎉' },
  { content: 'CONFUSED', emoji: '😕' },
  { content: 'HEART', emoji: '❤️' },
  { content: 'ROCKET', emoji: '🚀' },
  { content: 'EYES', emoji: '👀' }
];

/** 枚举 → emoji；未知回退空串 */
export function reactionEmoji(content: string): string {
  for (const meta of REACTION_META) {
    if (meta.content === content) {
      return meta.emoji;
    }
  }
  return '';
}

/** 按 content 查找反应组；未命中返回 null */
export function findReactionGroup(groups: ReactionGroup[], content: string): ReactionGroup | null {
  for (const g of groups) {
    if (g.content === content) {
      return g;
    }
  }
  return null;
}

/** 本地翻转反应（mutation 成功后即时 UI 反馈；users 列表由下一次刷新校准） */
export function flipReactionGroups(groups: ReactionGroup[], content: string, added: boolean): ReactionGroup[] {
  const out: ReactionGroup[] = [];
  let touched = false;
  for (const g of groups) {
    if (g.content === content) {
      touched = true;
      out.push({
        content: g.content,
        count: Math.max(0, g.count + (added ? 1 : -1)),
        viewerHasReacted: added,
        users: g.users
      });
    } else {
      out.push(g);
    }
  }
  if (!touched) {
    out.push({ content: content, count: 1, viewerHasReacted: true, users: [] });
  }
  return out;
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
    isDraft: Json.bool(raw, 'isDraft'),
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
    name: Json.str(raw, 'name'),
    tagName: Json.str(raw, 'tagName'),
    isLatest: Json.bool(raw, 'isLatest'),
    createdAt: Json.str(raw, 'createdAt'),
    description: Json.str(raw, 'description'),
    // Release 无 body 字段（实测）：description 即正文原文；HTML 由页面 renderMarkdown 生成
    body: Json.str(raw, 'description'),
    bodyHTML: '',
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

function mapReactionGroup(raw: JsonMap): ReactionGroup {
  // 计数 = reactors.totalCount（ReactionGroup 无 count 字段，2026-09-04 实测）
  const reactors = Json.obj(raw, 'reactors') ?? ({} as JsonMap);
  const nodes: ReactionUser[] = [];
  for (const nodeItem of Json.arr(reactors, 'nodes')) {
    const node = nodeItem as JsonMap;
    nodes.push({
      login: Json.str(node, 'login'),
      avatarUrl: Json.str(node, 'avatarUrl')
    });
  }
  return {
    content: Json.str(raw, 'content'),
    count: Json.num(reactors, 'totalCount'),
    viewerHasReacted: Json.bool(raw, 'viewerHasReacted'),
    users: nodes
  };
}

function mapReleaseAsset(raw: JsonMap): ReleaseAsset {
  return {
    id: Json.str(raw, 'id'),
    name: Json.str(raw, 'name'),
    size: Json.num(raw, 'size'),
    downloadCount: Json.num(raw, 'downloadCount'),
    contentType: Json.str(raw, 'contentType'),
    url: Json.str(raw, 'url')
  };
}

export function mapReleaseDetail(data: JsonMap): ReleaseDetailPage | null {
  const repo = Json.obj(data, 'repository') ?? ({} as JsonMap);
  const release = Json.obj(repo, 'release');
  if (release === null) {
    return null;
  }
  const author = Json.obj(release, 'author');
  const tagCommit = Json.obj(release, 'tagCommit');
  const assetsWrap = Json.obj(release, 'releaseAssets') ?? ({} as JsonMap);
  const assets: ReleaseAsset[] = [];
  for (const nodeItem of Json.arr(assetsWrap, 'nodes')) {
    assets.push(mapReleaseAsset(nodeItem as JsonMap));
  }
  return {
    id: Json.str(release, 'id'),
    tagName: Json.str(release, 'tagName'),
    releaseUrl: Json.str(release, 'url'),
    name: Json.str(release, 'name'),
    isDraft: Json.bool(release, 'isDraft'),
    isPrerelease: Json.bool(release, 'isPrerelease'),
    isLatest: Json.bool(release, 'isLatest'),
    tagSha: tagCommit !== null ? Json.str(tagCommit, 'oid') : '',
    publishedAt: Json.str(release, 'publishedAt'),
    createdAt: Json.str(release, 'createdAt'),
    // Release 无 body/bodyHTML（实测）：description=正文原文；HTML 由页面 renderMarkdown 生成
    body: Json.str(release, 'description'),
    bodyHTML: '',
    authorLogin: author !== null ? Json.str(author, 'login') : '',
    authorAvatar: author !== null ? Json.str(author, 'avatarUrl') : '',
    assets: assets
  };
}


function mapComment(raw: JsonMap): RepoComment {
  const author = Json.obj(raw, 'author');
  const reactions: ReactionGroup[] = [];
  for (const nodeItem of Json.arr(raw, 'reactionGroups')) {
    reactions.push(mapReactionGroup(nodeItem as JsonMap));
  }
  return {
    id: Json.str(raw, 'id'),
    body: Json.str(raw, 'body'),
    bodyHTML: Json.str(raw, 'bodyHTML'),
    createdAt: Json.str(raw, 'createdAt'),
    authorLogin: author !== null ? Json.str(author, 'login') : '',
    authorAvatar: author !== null ? Json.str(author, 'avatarUrl') : '',
    viewerDidAuthor: Json.bool(raw, 'viewerDidAuthor'),
    reactions: reactions
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
    subjectId: Json.str(issue, 'id'),
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
    subjectId: Json.str(pr, 'id'),
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
    comments: comments,
    commentsHasNext: Json.bool(commentsWrap, 'hasNextPage'),
    commentsCursor: Json.str(Json.obj(commentsWrap, 'pageInfo') ?? ({} as JsonMap), 'endCursor')
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
