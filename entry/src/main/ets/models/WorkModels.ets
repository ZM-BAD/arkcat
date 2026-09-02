/**
 * Home 工作区列表数据模型（Spec 017-023）。
 * 跨仓库列表统一走 GraphQL search(type: ISSUE/PR/DISCUSSION)；
 * Projects/TopRepos/Orgs/Starred 走 viewer 连接。
 * 模型保持纯数据接口；映射/查询构建函数集中在此，便于单元测试。
 */
import { Json, JsonMap } from '../utils/Json';

/** 标签（名称 + 色值） */
export interface WorkLabel {
  name: string;
  color: string;
}

/** 工作区 Issue 行 */
export interface WorkIssueItem {
  id: string;
  number: number;
  title: string;
  state: string;
  /** open | completed | not_planned（由 state/stateReason 推导，UI 据此选字形） */
  iconKey: string;
  createdAt: string;
  repoFullName: string;
  labels: WorkLabel[];
  commentCount: number;
}

export interface WorkIssuesPage {
  hasNextPage: boolean;
  endCursor: string;
  issues: WorkIssueItem[];
}

/** 工作区 PR 行 */
export interface WorkPrItem {
  id: string;
  number: number;
  title: string;
  state: string;
  /** merged | open | closed（UI 据此选字形与颜色） */
  iconKey: string;
  createdAt: string;
  repoFullName: string;
  commentCount: number;
  reviewCount: number;
  /** SUCCESS/FAILURE/PENDING/ERROR；无 Checks 时为 '' */
  checksState: string;
}

export interface WorkPrsPage {
  hasNextPage: boolean;
  endCursor: string;
  prs: WorkPrItem[];
}

/** 工作区 Discussion 行 */
export interface WorkDiscussionItem {
  id: string;
  number: number;
  title: string;
  state: string;
  /** open | closed */
  iconKey: string;
  createdAt: string;
  repoFullName: string;
  category: string;
  replyCount: number;
}

export interface WorkDiscussionsPage {
  hasNextPage: boolean;
  endCursor: string;
  discussions: WorkDiscussionItem[];
}

/** 工作区 Project 行 */
export interface WorkProjectItem {
  id: string;
  number: number;
  title: string;
  closed: boolean;
  updatedAt: string;
  ownerLogin: string;
}

export interface WorkProjectsPage {
  hasNextPage: boolean;
  endCursor: string;
  projects: WorkProjectItem[];
  viewerLogin: string;
}

/** 组织行 */
export interface WorkOrgItem {
  id: string;
  login: string;
  name: string;
  avatarUrl: string;
}

export interface WorkOrgsPage {
  hasNextPage: boolean;
  endCursor: string;
  orgs: WorkOrgItem[];
}

/** Top Repositories 行 */
export interface WorkTopRepoItem {
  id: string;
  name: string;
  ownerLogin: string;
  ownerAvatar: string;
}

export interface WorkTopReposPage {
  hasNextPage: boolean;
  endCursor: string;
  repos: WorkTopRepoItem[];
}

/** Starred 仓库行 */
export interface WorkStarredRepoItem {
  id: string;
  name: string;
  description: string;
  stargazerCount: number;
  ownerLogin: string;
  ownerAvatar: string;
  language: string;
  languageColor: string;
}

export interface WorkStarredPage {
  hasNextPage: boolean;
  endCursor: string;
  viewerLogin: string;
  repos: WorkStarredRepoItem[];
}

// ────────────────────────── 查询串构建（纯函数） ──────────────────────────

/** Issue/PR 归属筛选 → search qualifier */
export function workScopeQualifier(scope: string): string {
  if (scope === 'assigned') {
    return 'assignee:@me';
  }
  if (scope === 'mentioned') {
    return 'mentions:@me';
  }
  if (scope === 'involved') {
    return 'involves:@me';
  }
  return 'author:@me';
}

/** 可见性筛选 → search qualifier */
export function workVisibilityQualifier(visibility: string): string {
  if (visibility === 'public') {
    return 'is:public';
  }
  if (visibility === 'private') {
    return 'is:private';
  }
  return '';
}

/** Issue 排序键 → search sort qualifier（官方 Sort by 四组；反应排序键与文档一致） */
export function workIssuesSortQualifier(sortKey: string): string {
  const map: Record<string, string> = {
    'newest': 'sort:created-desc',
    'oldest': 'sort:created-asc',
    'most_commented': 'sort:comments-desc',
    'least_commented': 'sort:comments-asc',
    'recently_updated': 'sort:updated-desc',
    'least_recently_updated': 'sort:updated-asc',
    'reactions:+1': 'sort:reactions-+1-desc',
    'reactions:-1': 'sort:reactions--1-desc',
    'reactions:laugh': 'sort:reactions-smile-desc',
    'reactions:hooray': 'sort:reactions-tada-desc',
    'reactions:heart': 'sort:reactions-heart-desc',
    'reactions:rocket': 'sort:reactions-rocket-desc',
    'reactions:eyes': 'sort:reactions-eyes-desc'
  };
  const qualifier = map[sortKey];
  return qualifier !== undefined ? qualifier : 'sort:created-desc';
}

/** 工作区 Issue 搜索串：is:issue + 状态 + 归属 + 可见性 + 组织/仓库（多值）+ 排序 */
export function buildWorkIssuesQuery(state: string, scope: string, visibility: string,
  sortKey: string, orgs: string[], repos: string[]): string {
  let query = 'is:issue';
  if (state === 'open') {
    query += ' is:open';
  } else if (state === 'closed') {
    query += ' is:closed';
  }
  query += ` ${workScopeQualifier(scope)}`;
  const vis = workVisibilityQualifier(visibility);
  if (vis !== '') {
    query += ` ${vis}`;
  }
  orgs.forEach((o: string) => {
    query += ` org:${o}`;
  });
  repos.forEach((r: string) => {
    query += ` repo:${r}`;
  });
  query += ` ${workIssuesSortQualifier(sortKey)}`;
  return query;
}

/** 工作区 PR 搜索串：is:pr + 状态（含 merged）+ 归属 + 可见性 */
export function buildWorkPrsQuery(state: string, scope: string, visibility: string): string {
  let query = 'is:pr';
  if (state === 'open') {
    query += ' is:open';
  } else if (state === 'closed') {
    query += ' is:closed';
  } else if (state === 'merged') {
    query += ' is:merged';
  }
  query += ` ${workScopeQualifier(scope)}`;
  const vis = workVisibilityQualifier(visibility);
  if (vis !== '') {
    query += ` ${vis}`;
  }
  return `${query} sort:updated-desc`;
}

/** 工作区 Discussion 搜索串：is:discussion + 状态 + 归属 + unanswered */
export function buildWorkDiscussionsQuery(state: string, scope: string, unanswered: boolean): string {
  let query = 'is:discussion';
  if (state === 'open') {
    query += ' is:open';
  } else if (state === 'closed') {
    query += ' is:closed';
  }
  query += ` ${workScopeQualifier(scope)}`;
  if (unanswered) {
    query += ' is:unanswered';
  }
  return query;
}

/** Top Repositories 可见性 → RepositoryPrivacy（'' 表示 All，不传变量） */
export function buildTopReposPrivacy(privacy: string): string {
  if (privacy === 'public') {
    return 'PUBLIC';
  }
  if (privacy === 'private') {
    return 'PRIVATE';
  }
  return '';
}

// ────────────────────────── 响应映射（纯函数） ──────────────────────────

/** search 响应公共分页结果 */
interface WorkPageInfo {
  hasNext: boolean;
  end: string;
}

/** search 响应公共分页壳 */
function mapSearchPage(data: JsonMap): WorkPageInfo {
  const search = Json.obj(data, 'search') ?? ({} as JsonMap);
  const pageInfo = Json.obj(search, 'pageInfo');
  return {
    hasNext: pageInfo !== null ? Json.bool(pageInfo, 'hasNextPage') : false,
    end: pageInfo !== null ? Json.str(pageInfo, 'endCursor') : ''
  };
}

/** state/stateReason → issue 图标键（UI 负责字形与颜色） */
export function workIssueIconKey(state: string, stateReason: string): string {
  if (state === 'OPEN') {
    return 'open';
  }
  return stateReason === 'NOT_PLANNED' ? 'not_planned' : 'completed';
}

/** PR 状态 → 图标键 */
export function workPrIconKey(state: string, merged: boolean): string {
  if (merged || state === 'MERGED') {
    return 'merged';
  }
  if (state === 'OPEN') {
    return 'open';
  }
  return 'closed';
}

/** search Issue 节点 → WorkIssueItem */
export function mapWorkIssue(raw: JsonMap): WorkIssueItem {
  const repo = Json.obj(raw, 'repository');
  const labelsWrap = Json.obj(raw, 'labels');
  const labels: WorkLabel[] = [];
  if (labelsWrap !== null) {
    for (const nodeItem of Json.arr(labelsWrap, 'nodes')) {
      const node = nodeItem as JsonMap;
      labels.push({ name: Json.str(node, 'name'), color: Json.str(node, 'color') });
    }
  }
  const comments = Json.obj(raw, 'comments');
  const state = Json.str(raw, 'state');
  const stateReason = Json.str(raw, 'stateReason');
  return {
    id: Json.str(raw, 'id'),
    number: Json.num(raw, 'number'),
    title: Json.str(raw, 'title'),
    state: state,
    iconKey: workIssueIconKey(state, stateReason),
    createdAt: Json.str(raw, 'createdAt'),
    repoFullName: repo !== null ? Json.str(repo, 'nameWithOwner') : '',
    labels: labels,
    commentCount: comments !== null ? Json.num(comments, 'totalCount') : 0
  };
}

/** search 响应 → WorkIssuesPage */
export function mapWorkIssuesPage(data: JsonMap): WorkIssuesPage {
  const search = Json.obj(data, 'search') ?? ({} as JsonMap);
  const issues: WorkIssueItem[] = [];
  for (const nodeItem of Json.arr(search, 'nodes')) {
    issues.push(mapWorkIssue(nodeItem as JsonMap));
  }
  const page = mapSearchPage(data);
  return { hasNextPage: page.hasNext, endCursor: page.end, issues: issues };
}

/** search PR 节点 → WorkPrItem */
export function mapWorkPr(raw: JsonMap): WorkPrItem {
  const repo = Json.obj(raw, 'repository');
  const comments = Json.obj(raw, 'comments');
  const reviews = Json.obj(raw, 'reviewRequests');
  const checks = Json.obj(raw, 'statusCheckRollup');
  const state = Json.str(raw, 'state');
  const merged = Json.bool(raw, 'merged');
  return {
    id: Json.str(raw, 'id'),
    number: Json.num(raw, 'number'),
    title: Json.str(raw, 'title'),
    state: state,
    iconKey: workPrIconKey(state, merged),
    createdAt: Json.str(raw, 'createdAt'),
    repoFullName: repo !== null ? Json.str(repo, 'nameWithOwner') : '',
    commentCount: comments !== null ? Json.num(comments, 'totalCount') : 0,
    reviewCount: reviews !== null ? Json.num(reviews, 'totalCount') : 0,
    checksState: checks !== null ? Json.str(checks, 'state') : ''
  };
}

/** search 响应 → WorkPrsPage */
export function mapWorkPrsPage(data: JsonMap): WorkPrsPage {
  const search = Json.obj(data, 'search') ?? ({} as JsonMap);
  const prs: WorkPrItem[] = [];
  for (const nodeItem of Json.arr(search, 'nodes')) {
    prs.push(mapWorkPr(nodeItem as JsonMap));
  }
  const page = mapSearchPage(data);
  return { hasNextPage: page.hasNext, endCursor: page.end, prs: prs };
}

/** search Discussion 节点 → WorkDiscussionItem */
export function mapDiscussion(raw: JsonMap): WorkDiscussionItem {
  const repo = Json.obj(raw, 'repository');
  const category = Json.obj(raw, 'category');
  const comments = Json.obj(raw, 'comments');
  const state = Json.str(raw, 'state');
  return {
    id: Json.str(raw, 'id'),
    number: Json.num(raw, 'number'),
    title: Json.str(raw, 'title'),
    state: state,
    iconKey: state === 'OPEN' ? 'open' : 'closed',
    createdAt: Json.str(raw, 'createdAt'),
    repoFullName: repo !== null ? Json.str(repo, 'nameWithOwner') : '',
    category: category !== null ? Json.str(category, 'name') : '',
    replyCount: comments !== null ? Json.num(comments, 'totalCount') : 0
  };
}

/** search 响应 → WorkDiscussionsPage */
export function mapWorkDiscussionsPage(data: JsonMap): WorkDiscussionsPage {
  const search = Json.obj(data, 'search') ?? ({} as JsonMap);
  const discussions: WorkDiscussionItem[] = [];
  for (const nodeItem of Json.arr(search, 'nodes')) {
    discussions.push(mapDiscussion(nodeItem as JsonMap));
  }
  const page = mapSearchPage(data);
  return { hasNextPage: page.hasNext, endCursor: page.end, discussions: discussions };
}

/** Project 客户端过滤（纯函数）：范围 + 状态，排序：Open 前置 + updatedAt 降序 */
export function filterWorkProjects(projects: WorkProjectItem[], ownedOnly: boolean,
  viewerLogin: string, closedOnly: boolean): WorkProjectItem[] {
  const result: WorkProjectItem[] = [];
  for (const project of projects) {
    if (ownedOnly && project.ownerLogin !== viewerLogin) {
      continue;
    }
    if (closedOnly !== project.closed) {
      continue;
    }
    result.push(project);
  }
  result.sort((a: WorkProjectItem, b: WorkProjectItem): number => {
    if (a.closed !== b.closed) {
      return a.closed ? 1 : -1;
    }
    return Date.parse(b.updatedAt) - Date.parse(a.updatedAt);
  });
  return result;
}

/** viewer.projectsV2 响应 → WorkProjectsPage */
export function mapWorkProjectsPage(data: JsonMap): WorkProjectsPage {
  const viewer = Json.obj(data, 'viewer') ?? ({} as JsonMap);
  const projectsWrap = Json.obj(viewer, 'projectsV2') ?? ({} as JsonMap);
  const pageInfo = Json.obj(projectsWrap, 'pageInfo');
  const projects: WorkProjectItem[] = [];
  for (const nodeItem of Json.arr(projectsWrap, 'nodes')) {
    const node = nodeItem as JsonMap;
    const owner = Json.obj(node, 'owner');
    projects.push({
      id: Json.str(node, 'id'),
      number: Json.num(node, 'number'),
      title: Json.str(node, 'title'),
      closed: Json.bool(node, 'closed'),
      updatedAt: Json.str(node, 'updatedAt'),
      ownerLogin: owner !== null ? Json.str(owner, 'login') : ''
    });
  }
  return {
    hasNextPage: pageInfo !== null ? Json.bool(pageInfo, 'hasNextPage') : false,
    endCursor: pageInfo !== null ? Json.str(pageInfo, 'endCursor') : '',
    projects: projects,
    viewerLogin: Json.str(viewer, 'login')
  };
}

/** 组织节点 → WorkOrgItem */
export function mapWorkOrg(raw: JsonMap): WorkOrgItem {
  const login = Json.str(raw, 'login');
  return {
    id: Json.str(raw, 'id'),
    login: login,
    name: Json.str(raw, 'name') !== '' ? Json.str(raw, 'name') : login,
    avatarUrl: Json.str(raw, 'avatarUrl')
  };
}

/** viewer.organizations 响应 → WorkOrgsPage */
export function mapWorkOrgsPage(data: JsonMap): WorkOrgsPage {
  const viewer = Json.obj(data, 'viewer') ?? ({} as JsonMap);
  const orgsWrap = Json.obj(viewer, 'organizations') ?? ({} as JsonMap);
  const pageInfo = Json.obj(orgsWrap, 'pageInfo');
  const orgs: WorkOrgItem[] = [];
  for (const nodeItem of Json.arr(orgsWrap, 'nodes')) {
    orgs.push(mapWorkOrg(nodeItem as JsonMap));
  }
  return {
    hasNextPage: pageInfo !== null ? Json.bool(pageInfo, 'hasNextPage') : false,
    endCursor: pageInfo !== null ? Json.str(pageInfo, 'endCursor') : '',
    orgs: orgs
  };
}

/** viewer.repositories 节点 → WorkTopRepoItem */
export function mapTopRepo(raw: JsonMap): WorkTopRepoItem {
  const owner = Json.obj(raw, 'owner');
  return {
    id: Json.str(raw, 'id'),
    name: Json.str(raw, 'name'),
    ownerLogin: owner !== null ? Json.str(owner, 'login') : '',
    ownerAvatar: owner !== null ? Json.str(owner, 'avatarUrl') : ''
  };
}

/** viewer.repositories 响应 → WorkTopReposPage */
export function mapWorkTopReposPage(data: JsonMap): WorkTopReposPage {
  const viewer = Json.obj(data, 'viewer') ?? ({} as JsonMap);
  const reposWrap = Json.obj(viewer, 'repositories') ?? ({} as JsonMap);
  const pageInfo = Json.obj(reposWrap, 'pageInfo');
  const repos: WorkTopRepoItem[] = [];
  for (const nodeItem of Json.arr(reposWrap, 'nodes')) {
    repos.push(mapTopRepo(nodeItem as JsonMap));
  }
  return {
    hasNextPage: pageInfo !== null ? Json.bool(pageInfo, 'hasNextPage') : false,
    endCursor: pageInfo !== null ? Json.str(pageInfo, 'endCursor') : '',
    repos: repos
  };
}

/** starredRepositories 节点 → WorkStarredRepoItem */
export function mapStarredRepo(raw: JsonMap): WorkStarredRepoItem {
  const owner = Json.obj(raw, 'owner');
  const lang = Json.obj(raw, 'primaryLanguage');
  return {
    id: Json.str(raw, 'id'),
    name: Json.str(raw, 'name'),
    description: Json.str(raw, 'description'),
    stargazerCount: Json.num(raw, 'stargazerCount'),
    ownerLogin: owner !== null ? Json.str(owner, 'login') : '',
    ownerAvatar: owner !== null ? Json.str(owner, 'avatarUrl') : '',
    language: lang !== null ? Json.str(lang, 'name') : '',
    languageColor: lang !== null ? Json.str(lang, 'color') : ''
  };
}

/** viewer / user(login) .starredRepositories 响应 → WorkStarredPage（Spec 035 双形状） */
export function mapWorkStarredPage(data: JsonMap): WorkStarredPage {
  const viewer = Json.obj(data, 'viewer') ?? ({} as JsonMap);
  let starredWrap = Json.obj(viewer, 'starredRepositories') ?? ({} as JsonMap);
  let login = Json.str(viewer, 'login');
  // user(login) 查询形状：viewer 无星标节点时读 user
  if (Json.obj(starredWrap, 'pageInfo') === null) {
    const userNode = Json.obj(data, 'user') ?? ({} as JsonMap);
    starredWrap = Json.obj(userNode, 'starredRepositories') ?? ({} as JsonMap);
    login = Json.str(userNode, 'login');
  }
  const pageInfo = Json.obj(starredWrap, 'pageInfo');
  const repos: WorkStarredRepoItem[] = [];
  for (const nodeItem of Json.arr(starredWrap, 'nodes')) {
    repos.push(mapStarredRepo(nodeItem as JsonMap));
  }
  return {
    hasNextPage: pageInfo !== null ? Json.bool(pageInfo, 'hasNextPage') : false,
    endCursor: pageInfo !== null ? Json.str(pageInfo, 'endCursor') : '',
    viewerLogin: login,
    repos: repos
  };
}
