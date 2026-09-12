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
/** Discussion 标签（name + GitHub 色，Author/Label 筛选用） */
export interface DiscussionLabel {
  name: string;
  color: string;
}

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
  /** 作者（Label/Author 筛选与作者弹层用；搜索结果缺省为空串） */
  authorLogin: string;
  authorName: string;
  authorAvatar: string;
  labels: DiscussionLabel[];
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
  /** 模板项目（ProjectV2.template；三态之一，见 filterWorkProjects） */
  template: boolean;
  createdAt: string;
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
  isArchived: boolean;
  isFork: boolean;
  isMirror: boolean;
  isTemplate: boolean;
  /** RepositoryVisibility：PUBLIC | PRIVATE | INTERNAL */
  visibility: string;
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
  if (scope === 'review_requested') {
    return 'review-requested:@me';
  }
  if (scope === 'commented') {
    return 'commenter:@me';
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

/** 工作区 PR 搜索串：is:pr + 状态（open/merged/closed/queued）+ 归属 + 可见性 + 组织/仓库（多值）+ 排序 */
export function buildWorkPrsQuery(state: string, scope: string, visibility: string,
  sortKey: string, orgs: string[], repos: string[]): string {
  let query = 'is:pr';
  if (state === 'open') {
    query += ' is:open';
  } else if (state === 'closed') {
    query += ' is:closed';
  } else if (state === 'merged') {
    query += ' is:merged';
  } else if (state === 'queued') {
    query += ' is:queued';
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

/** N 天前的日期（UTC YYYY-MM-DD，供 Top 时间窗 used qualifier） */
export function pastDate(days: number): string {
  return new Date(Date.now() - days * 86400000).toISOString().slice(0, 10);
}

/** Discussion 排序键 → search 片段（官方 Sort: New / Top: 时间窗；Top 用 interactions 加权近似） */
export function discussionSortQualifier(sortKey: string): string {
  if (sortKey === 'top_yesterday') {
    return `updated:>=${pastDate(1)} sort:interactions-desc`;
  }
  if (sortKey === 'top_week') {
    return `updated:>=${pastDate(7)} sort:interactions-desc`;
  }
  if (sortKey === 'top_month') {
    return `updated:>=${pastDate(30)} sort:interactions-desc`;
  }
  if (sortKey === 'top_year') {
    return `updated:>=${pastDate(365)} sort:interactions-desc`;
  }
  if (sortKey === 'top_all') {
    return 'sort:interactions-desc';
  }
  return 'sort:created-desc';
}

/** 工作区 Discussion 搜索串：is:discussion + 状态 + 归属 + unanswered + 排序（New/Top 时间窗）。
 * repo 非空（如 'ZM-BAD/arkcat'）时限定单仓库（Share Feedback 入口），跳过归属 qualifier——
 * 仓库讨论不应再叠加 author:@me 之类的个人过滤。
 * author/label：Author/Label 筛选 qualifier；label='none' 表示 Unlabeled（no:label）。 */
export function buildWorkDiscussionsQuery(state: string, scope: string, unanswered: boolean,
  sortKey: string, repo: string = '', author: string = '', label: string = ''): string {
  let query = 'is:discussion';
  if (state === 'open') {
    query += ' is:open';
  } else if (state === 'closed') {
    query += ' is:closed';
  }
  if (repo !== '') {
    query += ` repo:${repo}`;
  } else {
    query += ` ${workScopeQualifier(scope)}`;
  }
  if (author !== '') {
    query += ` author:${author}`;
  }
  if (label === 'none') {
    query += ' no:label';
  } else if (label !== '') {
    // 带空格/冒号的标签名需引号包裹
    query += label.match(/[ :]/) !== null ? ` label:"${label}"` : ` label:${label}`;
  }
  if (unanswered) {
    query += ' is:unanswered';
  }
  query += ` ${discussionSortQualifier(sortKey)}`;
  return query;
}

/** Discussion 搜索作者选项去重（纯函数）：Author 弹层选项 */
export function collectDiscussionAuthors(items: WorkDiscussionItem[]): WorkDiscussionItem[] {
  const seen: Set<string> = new Set();
  const result: WorkDiscussionItem[] = [];
  for (const item of items) {
    if (item.authorLogin !== '' && !seen.has(item.authorLogin)) {
      seen.add(item.authorLogin);
      result.push(item);
    }
  }
  return result;
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
export function workPrIconKey(state: string, merged: boolean, isDraft: boolean): string {
  if (merged || state === 'MERGED') {
    return 'merged';
  }
  if (state === 'OPEN' && isDraft) {
    return 'draft';
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
    iconKey: workPrIconKey(state, merged, Json.bool(raw, 'isDraft')),
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
  const author = Json.obj(raw, 'author');
  const labels: DiscussionLabel[] = [];
  const labelsWrap = Json.obj(raw, 'labels');
  if (labelsWrap !== null) {
    for (const nodeItem of Json.arr(labelsWrap, 'nodes')) {
      const l = nodeItem as JsonMap;
      labels.push({ name: Json.str(l, 'name'), color: Json.str(l, 'color') });
    }
  }
  return {
    id: Json.str(raw, 'id'),
    number: Json.num(raw, 'number'),
    title: Json.str(raw, 'title'),
    state: state,
    iconKey: state === 'OPEN' ? 'open' : 'closed',
    createdAt: Json.str(raw, 'createdAt'),
    repoFullName: repo !== null ? Json.str(repo, 'nameWithOwner') : '',
    category: category !== null ? Json.str(category, 'name') : '',
    replyCount: comments !== null ? Json.num(comments, 'totalCount') : 0,
    authorLogin: author !== null ? Json.str(author, 'login') : '',
    authorName: author !== null ? Json.str(author, 'name') : '',
    authorAvatar: author !== null ? Json.str(author, 'avatarUrl') : '',
    labels: labels
  };
}

/** 仓库 labels（含色值，Label 弹层用） */
export interface RepoLabelItem {
  name: string;
  color: string;
}

/** repository.labels 响应 → RepoLabelItem[]（纯函数） */
export function mapRepoLabels(data: JsonMap): RepoLabelItem[] {
  const repo = Json.obj(data, 'repository');
  const result: RepoLabelItem[] = [];
  const labels = repo !== null ? Json.obj(repo, 'labels') : null;
  if (labels !== null) {
    for (const nodeItem of Json.arr(labels, 'nodes')) {
      const l = nodeItem as JsonMap;
      result.push({ name: Json.str(l, 'name'), color: Json.str(l, 'color') });
    }
  }
  return result;
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
/** Projects 过滤（纯函数）：范围（全部/我创建）+ 三态（open/closed/template，官方 Template 项目） */
export function filterWorkProjects(projects: WorkProjectItem[], ownedOnly: boolean,
  viewerLogin: string, stateFilter: string): WorkProjectItem[] {
  const result: WorkProjectItem[] = [];
  for (const project of projects) {
    if (ownedOnly && project.ownerLogin !== viewerLogin) {
      continue;
    }
    if (stateFilter === 'closed' && !project.closed) {
      continue;
    }
    if (stateFilter === 'template' && !project.template) {
      continue;
    }
    if (stateFilter === 'open' && (project.closed || project.template)) {
      continue;
    }
    result.push(project);
  }
  return result;
}

/** Projects 排序（纯函数）：官方 8 项；viewed 两项以本会话浏览记录为准（无记录视为 0） */
export function sortWorkProjects(projects: WorkProjectItem[], sortKey: string,
  viewedAt: Record<string, number>): WorkProjectItem[] {
  const sorted: WorkProjectItem[] = [...projects];
  sorted.sort((a: WorkProjectItem, b: WorkProjectItem): number => {
    switch (sortKey) {
      case 'least_viewed':
        return (viewedAt[a.id] ?? 0) - (viewedAt[b.id] ?? 0);
      case 'updated_newest':
        return b.updatedAt.localeCompare(a.updatedAt);
      case 'updated_oldest':
        return a.updatedAt.localeCompare(b.updatedAt);
      case 'created_newest':
        return b.createdAt.localeCompare(a.createdAt);
      case 'created_oldest':
        return a.createdAt.localeCompare(b.createdAt);
      case 'title_az':
        return a.title.localeCompare(b.title);
      case 'title_za':
        return b.title.localeCompare(a.title);
      default:
        return (viewedAt[b.id] ?? 0) - (viewedAt[a.id] ?? 0);
    }
  });
  return sorted;
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
      template: Json.bool(node, 'template'),
      createdAt: Json.str(node, 'createdAt'),
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
    ownerAvatar: owner !== null ? Json.str(owner, 'avatarUrl') : '',
    isArchived: Json.bool(raw, 'isArchived'),
    isFork: Json.bool(raw, 'isFork'),
    isMirror: Json.bool(raw, 'isMirror'),
    isTemplate: Json.bool(raw, 'isTemplate'),
    visibility: Json.str(raw, 'visibility')
  };
}

/** 仓库筛选维度（官方 Top Repositories 下拉）：All/Archived/Fork/Mirror/Private/Public/Source/Template */
export function filterTopRepos(repos: WorkTopRepoItem[], filterKey: string): WorkTopRepoItem[] {
  return repos.filter((r: WorkTopRepoItem) => {
    if (filterKey === 'archived') {
      return r.isArchived;
    }
    if (filterKey === 'fork') {
      return r.isFork;
    }
    if (filterKey === 'mirror') {
      return r.isMirror;
    }
    if (filterKey === 'private') {
      return r.visibility === 'PRIVATE';
    }
    if (filterKey === 'public') {
      return r.visibility === 'PUBLIC' || r.visibility === 'INTERNAL';
    }
    if (filterKey === 'source') {
      return !r.isFork && !r.isMirror && !r.isArchived;
    }
    if (filterKey === 'template') {
      return r.isTemplate;
    }
    return true;
  });
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

/** 星标列表（viewer.lists 节点，Spec 023） */
export interface WorkUserList {
  id: string;
  name: string;
  description: string;
  /** 列表内仓库总数（items.totalCount） */
  itemCount: number;
  /** 列表内仓库节点 id（成员判断用；fetchUserLists 分页补全） */
  repoIds: string[];
  /** 成员分页续游标（review G5：初始查询即带 pageInfo，避免补页时重拉 page1） */
  repoHasNext: boolean;
  repoCursor: string;
}

/** viewer.lists 响应 → WorkUserList[]（成员=列表内仓库节点 id 集合） */
export function mapWorkUserLists(data: JsonMap): WorkUserList[] {
  const viewer = Json.obj(data, 'viewer') ?? ({} as JsonMap);
  const listsWrap = Json.obj(viewer, 'lists') ?? ({} as JsonMap);
  const result: WorkUserList[] = [];
  for (const nodeItem of Json.arr(listsWrap, 'nodes')) {
    const node = nodeItem as JsonMap;
    const itemsWrap = Json.obj(node, 'items') ?? ({} as JsonMap);
    const repoIds: string[] = [];
    for (const item of Json.arr(itemsWrap, 'nodes')) {
      const id = Json.str(item as JsonMap, 'id');
      if (id !== '') {
        repoIds.push(id);
      }
    }
    const itemsPageInfo = Json.obj(itemsWrap, 'pageInfo') ?? ({} as JsonMap);
    result.push({
      id: Json.str(node, 'id'),
      name: Json.str(node, 'name'),
      description: Json.str(node, 'description'),
      itemCount: Json.num(itemsWrap, 'totalCount'),
      repoIds: repoIds,
      repoHasNext: Json.bool(itemsPageInfo, 'hasNextPage'),
      repoCursor: Json.str(itemsPageInfo, 'endCursor')
    });
  }
  return result;
}

/** 列表详情（Spec 023）：名称/描述/成员仓库 + 归属人（viewer） */
export interface WorkListDetail {
  id: string;
  name: string;
  description: string;
  itemCount: number;
  viewerLogin: string;
  viewerAvatar: string;
  repos: WorkStarredRepoItem[];
}

/** node(id) + UserList 响应 → WorkListDetail（仓库节点复用 mapStarredRepo） */
export function mapWorkListDetail(data: JsonMap): WorkListDetail {
  const viewer = Json.obj(data, 'viewer') ?? ({} as JsonMap);
  const node = Json.obj(data, 'node') ?? ({} as JsonMap);
  const itemsWrap = Json.obj(node, 'items') ?? ({} as JsonMap);
  const repos: WorkStarredRepoItem[] = [];
  for (const item of Json.arr(itemsWrap, 'nodes')) {
    repos.push(mapStarredRepo(item as JsonMap));
  }
  return {
    id: Json.str(node, 'id'),
    name: Json.str(node, 'name'),
    description: Json.str(node, 'description'),
    itemCount: Json.num(itemsWrap, 'totalCount'),
    viewerLogin: Json.str(viewer, 'login'),
    viewerAvatar: Json.str(viewer, 'avatarUrl'),
    repos: repos
  };
}
