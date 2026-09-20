/**
 * 仓库二级页面数据模型与映射（Spec 027-031）。
 * 仓库内 PR 列表 / Commits / Releases / Issue 详情 / PR 详情。
 * 模型保持纯数据接口；映射/过滤器集中在此，便于单元测试。
 */
import { Json, JsonMap } from '../utils/Json';
import { WorkLabel } from './WorkModels';
import { NONE_FILTER_KEY } from '../utils/FilterLoading';

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
  /** Checks 通过数（rollup contexts 总数）。已入库备用：官方列表卡「绿圈勾 + N」口径未解（N 与 checks 总数对不上），UI 暂不展示 */
  checksCount: number;
  authorLogin: string;
  authorAvatar: string;
  assignees: string[];
  /** 所属里程碑标题（无里程碑=''；Milestone 筛选客户端过滤用，与 IssuesList 同款） */
  milestoneTitle: string;
}

export interface RepoPrsPage {
  hasNextPage: boolean;
  endCursor: string;
  totalCount: number;
  prs: RepoPrItem[];
  /** 仓库标签全集（带色：Label 面板 LabelPill 渲染用） */
  labelOptions: WorkLabel[];
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
  /** 显示名（union 片段仅 User/Organization 提供，可空；Reactees 页黑粗行） */
  name: string;
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
  /** release 正文反应组（Release 实现 Reactable，2026-09-06 gh api 实测） */
  reactions: ReactionGroup[];
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
  /** 作者是 Bot（GraphQL author.__typename = Bot）：官方显示 `login[bot]` */
  authorIsBot: boolean;
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
  /** 编辑权限门（viewerCanUpdate=作者或有写权限；Spec 043 编辑/关闭入口显隐） */
  viewerCanUpdate: boolean;
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

/** Checks 列表行（statusCheckRollup.contexts：CheckRun/StatusContext 归一化；Spec 048 富行） */
export interface StatusCheckItem {
  /** ForEach key（同名 check 可来自不同 suite/app，name 不足以唯一——映射时按序号定型） */
  key: string;
  name: string;
  state: string;
  /** check run 数据库 id（重跑/详情路由用）；0=StatusContext（无 job 数据，不可进详情页） */
  checkRunId: number;
  /** 官方详情页链接（CheckRun detailsUrl / StatusContext targetUrl；⋮ 浏览器兜底） */
  detailsUrl: string;
  /** check run 输出标题（如 Renovate 的描述文案；非空时副标题优先于结论文案） */
  title: string;
  startedAt: string;
  completedAt: string;
  /** 产出方 App 图标（GitHub Actions/Renovate 等；空串=无图标位） */
  appLogo: string;
}

/** PR 审阅卡行（Spec 042）：reviews(first) nodes 归一化 */
export interface PrReview {  id: string;
  /** APPROVED / CHANGES_REQUESTED / COMMENTED / DISMISSED / PENDING */
  state: string;
  body: string;
  bodyHTML: string;
  submittedAt: string;
  authorLogin: string;
  authorAvatar: string;
  /** 作者是 Bot（author.__typename = Bot）：官方显示 `login[bot]`（与 CommentCard 同口径） */
  authorIsBot: boolean;
  viewerDidAuthor: boolean;
}

/** Review thread 内评论行（无 reactionGroups，区别于会话区 RepoComment） */
export interface ReviewThreadComment {
  id: string;
  body: string;
  bodyHTML: string;
  createdAt: string;
  authorLogin: string;
  authorAvatar: string;
  /** 作者是 Bot（author.__typename = Bot）：官方显示 `login[bot]`（与 CommentCard 同口径） */
  authorIsBot: boolean;
  viewerDidAuthor: boolean;
}

/** Review thread（Spec 042）：diff 行内评论集合；line=0 表示文件级 thread */
export interface ReviewThread {
  id: string;
  path: string;
  line: number;
  isResolved: boolean;
  isOutdated: boolean;
  /** viewer 可否切换 resolve（权限由服务端判定） */
  viewerCanResolve: boolean;
  viewerCanUnresolve: boolean;
  comments: ReviewThreadComment[];
  commentsTotal: number;
}

/** Bot 登录名显示口径：GraphQL Bot 的 login 不带后缀，官方 UI 显示 `login[bot]` */
export function actorDisplayLogin(login: string, isBot: boolean): string {
  return isBot && login !== '' ? `${login}[bot]` : login;
}

/** 时间轴事件行文案段（官方口径：人物/对象用主色加粗，其余弱化灰） */
export interface PhraseSeg {
  text: string;
  emphasis: boolean;
}

/**
 * 拆 i18n 模板 `%1$s added the %2$s label` → 段序列（占位段 emphasis=true，供加粗上色）。
 * 纯函数：只认 `%N$s`（N 为 1-9），其它字符原样；占位序号越界时整段按普通文本处理。
 */
export function phraseSegments(template: string, args: string[]): PhraseSeg[] {
  const out: PhraseSeg[] = [];
  let plain = '';
  let i = 0;
  while (i < template.length) {
    const isPlaceholder = template.charAt(i) === '%' && i + 3 < template.length
      && template.charAt(i + 2) === '$' && template.charAt(i + 3) === 's';
    if (isPlaceholder) {
      const idx = template.charCodeAt(i + 1) - 48;
      if (idx >= 1 && idx <= args.length) {
        if (plain !== '') {
          out.push({ text: plain, emphasis: false });
          plain = '';
        }
        out.push({ text: args[idx - 1], emphasis: true });
        i += 4;
        continue;
      }
    }
    plain += template.charAt(i);
    i += 1;
  }
  if (plain !== '') {
    out.push({ text: plain, emphasis: false });
  }
  return out;
}

/**
 * 会话时间轴节点（Spec 031 重设计：官方 Conversation = 一条左侧竖线的时间轴）。
 * 不同 kind 渲染不同行：commit/label/assign 等事件行 vs comment/review 整卡。
 */
export interface TimelineNode {
  /** commit | comment | review | labeled | unlabeled | assigned | unassigned |
   *  review_requested | review_request_removed | merged | closed | reopened | draft | ready */
  kind: string;
  /** 节点 id（ForEach key 用；评论/审阅另拼可变数据） */
  id: string;
  /** 节点时间（官方事件行时间戳口径待定，UI 暂未渲染） */
  createdAt: string;
  /** 事件操作者（Bot 经 actorDisplayLogin 显示 login[bot]） */
  actorLogin: string;
  actorIsBot: boolean;
  /** commit 节点（PullRequestCommit） */
  commitOid: string;
  commitMessage: string;
  commitAuthorAvatar: string;
  /** label 节点（官方行内加粗 label name） */
  labelName: string;
  /** assign/unassign/review request 节点目标（User/Bot 取 login，Team/Organization 取 name） */
  targetLogin: string;
  targetIsBot: boolean;
  /** merged 节点（合并提交 + 目标分支） */
  mergeAbbrev: string;
  mergeRefName: string;
  /** comment 节点（整卡，复用 RepoComment） */
  comment: RepoComment | null;
  /** review 节点（整卡，复用 PrReview） */
  review: PrReview | null;
}

/** 空节点工厂（映射时逐类覆盖；避免 ArkTS 对象字面量缺字段） */
function blankTimelineNode(): TimelineNode {
  return {
    kind: '', id: '', createdAt: '',
    actorLogin: '', actorIsBot: false,
    commitOid: '', commitMessage: '', commitAuthorAvatar: '',
    labelName: '',
    targetLogin: '', targetIsBot: false,
    mergeAbbrev: '', mergeRefName: '',
    comment: null, review: null
  };
}

/** union 取显示名：User/Bot/Mannequin 有 login，Team/Organization 取 name */
function unionName(obj: JsonMap | null): string {
  if (obj === null) {
    return '';
  }
  const login = Json.str(obj, 'login');
  return login !== '' ? login : Json.str(obj, 'name');
}

/** 事件操作者（Actor 联合）填充 */
function fillActor(node: TimelineNode, raw: JsonMap): void {
  const actor = Json.obj(raw, 'actor');
  if (actor !== null) {
    node.actorLogin = unionName(actor);
    node.actorIsBot = Json.str(actor, '__typename') === 'Bot';
  }
}

/**
 * timelineItems nodes → 时间轴节点（官方 itemTypes 子集；未识别类型返回 kind='' 由调用方丢弃）。
 * 数据来源：GH 实测 PullRequestTimelineItems 共 78 种类型，本映射覆盖会话高频子集。
 */
export function mapTimeline(conn: JsonMap): TimelineNode[] {
  const out: TimelineNode[] = [];
  for (const item of Json.arr(conn, 'nodes')) {
    const raw = item as JsonMap;
    const type = Json.str(raw, '__typename');
    const node = blankTimelineNode();
    node.id = Json.str(raw, 'id');
    node.createdAt = Json.str(raw, 'createdAt');
    fillActor(node, raw);
    if (type === 'PullRequestCommit') {
      const commit = Json.obj(raw, 'commit');
      const author = commit !== null ? Json.obj(commit, 'author') : null;
      node.kind = 'commit';
      node.commitOid = commit !== null ? Json.str(commit, 'oid') : '';
      node.commitMessage = commit !== null ? Json.str(commit, 'messageHeadline') : '';
      node.commitAuthorAvatar = author !== null ? Json.str(author, 'avatarUrl') : '';
    } else if (type === 'IssueComment') {
      node.kind = 'comment';
      node.comment = mapComment(raw);
    } else if (type === 'PullRequestReview') {
      node.kind = 'review';
      node.review = mapReview(raw);
    } else if (type === 'LabeledEvent' || type === 'UnlabeledEvent') {
      node.kind = type === 'LabeledEvent' ? 'labeled' : 'unlabeled';
      const label = Json.obj(raw, 'label');
      node.labelName = label !== null ? Json.str(label, 'name') : '';
    } else if (type === 'AssignedEvent' || type === 'UnassignedEvent') {
      node.kind = type === 'AssignedEvent' ? 'assigned' : 'unassigned';
      const assignee = Json.obj(raw, 'assignee');
      node.targetLogin = unionName(assignee);
      node.targetIsBot = assignee !== null && Json.str(assignee, '__typename') === 'Bot';
    } else if (type === 'ReviewRequestedEvent' || type === 'ReviewRequestRemovedEvent') {
      node.kind = type === 'ReviewRequestedEvent' ? 'review_requested' : 'review_request_removed';
      const reviewer = Json.obj(raw, 'requestedReviewer');
      node.targetLogin = unionName(reviewer);
      node.targetIsBot = reviewer !== null && Json.str(reviewer, '__typename') === 'Bot';
    } else if (type === 'MergedEvent') {
      const commit = Json.obj(raw, 'commit');
      node.kind = 'merged';
      node.mergeAbbrev = commit !== null ? Json.str(commit, 'abbreviatedOid') : '';
      node.mergeRefName = Json.str(raw, 'mergeRefName');
    } else if (type === 'ClosedEvent') {
      node.kind = 'closed';
    } else if (type === 'ReopenedEvent') {
      node.kind = 'reopened';
    } else if (type === 'ConvertToDraftEvent') {
      node.kind = 'draft';
    } else if (type === 'ReadyForReviewEvent') {
      node.kind = 'ready';
    }
    if (node.kind !== '') {
      out.push(node);
    }
  }
  return out;
}

/** 元数据标签行（图1 概览面板 + 044 编辑器共用口径） */
export interface MetaLabel {  id: string;
  name: string;
  color: string;
}

/** 元数据负责人行 */
export interface MetaUser {
  id: string;
  login: string;
  avatarUrl: string;
}

/** 元数据里程碑行 */
export interface MetaMilestone {
  id: string;
  title: string;
}

export interface PrDetailPage {
  /** 评论发布用节点 id（SubjectId） */
  subjectId: string;
  number: number;
  title: string;
  state: string;
  merged: boolean;
  isDraft: boolean;
  /** 编辑权限门（viewerCanUpdate=作者或有写权限；Spec 043 编辑/关闭/draft 切换入口显隐） */
  viewerCanUpdate: boolean;
  body: string;
  /** 官方渲染 HTML（Spec 040），body 作降级 */
  bodyHTML: string;
  createdAt: string;
  mergedAt: string;
  additions: number;
  deletions: number;
  authorLogin: string;
  authorAvatar: string;
  /** 作者关联角色（AuthorAssociation 原值；NONE/未知不显示角色胶囊） */
  authorAssociation: string;
  /** 正文反应（正文卡反应行：subjectId 即 PR 节点 id） */
  reactions: ReactionGroup[];
  /** 仓库 owner 头像（页头作者行=仓库上下文：owner 头像 + `owner / repo #N`） */
  ownerAvatar: string;
  headRefName: string;
  baseRefName: string;
  mergeOid: string;
  mergedByLogin: string;
  filesCount: number;
  commitsCount: number;
  reviewsTotal: number;
  /** 会话时间轴（官方 Conversation：事件行 + 评论/审阅卡按时间序） */
  timeline: TimelineNode[];
  /** 时间轴分页（>30 条 Load more） */
  timelineHasNext: boolean;
  timelineCursor: string;
  checksState: string;
  checks: StatusCheckItem[];
  /** contexts.totalCount（展开态 View all 次行计数； Spec 048） */
  checksTotal: number;
  /** 元数据概览面板（info 钮 → 图1） */
  labelItems: MetaLabel[];
  assigneeItems: MetaUser[];
  milestoneItem: MetaMilestone | null;
  /** MERGEABLE / CONFLICTING / UNKNOWN（Spec 042 元素9） */
  mergeable: string;
  /** CLEAN / BLOCKED / DIRTY / BEHIND / UNSTABLE / DRAFT / HAS_HOOKS / UNKNOWN（元素10） */
  mergeStateStatus: string;
  /** ADMIN / MAINTAIN / WRITE / READ / NONE（合并权限门；PR 无 viewerCanMerge，用仓库级权限代替） */
  repoViewerPermission: string;
  /** 仓库/账号默认合并方式（MERGE/SQUASH/REBASE）：Merge options 页默认选中项 */
  defaultMergeMethod: string;
  /** 默认提交信息（官方 viewerMergeHeadlineText/BodyText，按默认合并方式口径返回） */
  mergeHeadline: string;
  mergeBody: string;
  threads: ReviewThread[];
}

// ─────────────── Spec 044 元数据编辑器候选 ───────────────

/** 编辑器候选：负责人 */
export interface TriageUser {
  id: string;
  login: string;
  avatarUrl: string;
}

/** 编辑器候选：标签（color 为 GitHub hex，不带 #） */
export interface TriageLabel {
  id: string;
  name: string;
  color: string;
}

/** 编辑器候选：里程碑 */
export interface TriageMilestone {
  id: string;
  title: string;
}

/** 编辑器候选：Linked items 建议（state=OPEN/CLOSED，用于状态字形） */
export interface TriageLinkedItem {
  id: string;
  number: number;
  title: string;
  state: string;
}

/** 编辑器候选：项目（ProjectsV2） */
export interface TriageProject {
  id: string;
  title: string;
}

/**
 * 编辑器行（元数据编辑器 Selected / 候选两个列表共用一种行形态）：
 * title=主文本（login / 标签名 / 里程碑名 / issue 标题 / 项目名）；
 * avatarUrl/标签色/状态字形三选一，决定行首渲染什么。
 */
export interface EditorRow {
  id: string;
  title: string;
  avatarUrl?: string;
  labelColor?: string;
  /** linked 行的 issue 状态（OPEN/CLOSED）→ 状态字形 */
  state?: string;
}

/** 候选列表按关键字过滤（客户端过滤：编辑器搜索框；空关键字原样返回） */
export function filterTriageByKeyword(names: string[], keyword: string): number[] {
  const hit: number[] = [];
  const k = keyword.trim().toLowerCase();
  for (let i = 0; i < names.length; i++) {
    if (k === '' || names[i].toLowerCase().indexOf(k) >= 0) {
      hit.push(i);
    }
  }
  return hit;
}

/** 单选保存时取选中项 id（未选中返回 ''，服务端按 null 清除） */
export function singlePickId(ids: string[]): string {
  return ids.length > 0 ? ids[0] : '';
}

/** 多选差异：add=目标有而原有没，remove=原有而目标没有（Spec 044 元素2 差异推送） */
export function diffSelection(before: string[], after: string[]): DiffIds {
  const add: string[] = [];
  const remove: string[] = [];
  for (const id of after) {
    if (before.indexOf(id) < 0) {
      add.push(id);
    }
  }
  for (const id of before) {
    if (after.indexOf(id) < 0) {
      remove.push(id);
    }
  }
  return { add: add, remove: remove };
}

export interface DiffIds {
  add: string[];
  remove: string[];
}

export function mapTriageUsers(data: JsonMap): TriageUser[] {
  const conn = Json.obj(Json.obj(data, 'repository') ?? ({} as JsonMap), 'assignableUsers') ?? ({} as JsonMap);
  const out: TriageUser[] = [];
  for (const node of Json.arr(conn, 'nodes')) {
    const it = node as JsonMap;
    out.push({ id: Json.str(it, 'id'), login: Json.str(it, 'login'), avatarUrl: Json.str(it, 'avatarUrl') });
  }
  return out;
}

export function mapTriageLabels(data: JsonMap): TriageLabel[] {
  const conn = Json.obj(Json.obj(data, 'repository') ?? ({} as JsonMap), 'labels') ?? ({} as JsonMap);
  const out: TriageLabel[] = [];
  for (const node of Json.arr(conn, 'nodes')) {
    const it = node as JsonMap;
    out.push({ id: Json.str(it, 'id'), name: Json.str(it, 'name'), color: Json.str(it, 'color') });
  }
  return out;
}

export function mapTriageMilestones(data: JsonMap): TriageMilestone[] {
  const conn = Json.obj(Json.obj(data, 'repository') ?? ({} as JsonMap), 'milestones') ?? ({} as JsonMap);
  const out: TriageMilestone[] = [];
  for (const node of Json.arr(conn, 'nodes')) {
    const it = node as JsonMap;
    out.push({ id: Json.str(it, 'id'), title: Json.str(it, 'title') });
  }
  return out;
}

/** Linked 建议：排除 PR 自身节点（excludeId） */
export function mapTriageLinked(data: JsonMap, excludeId: string): TriageLinkedItem[] {
  const conn = Json.obj(Json.obj(data, 'repository') ?? ({} as JsonMap), 'issues') ?? ({} as JsonMap);
  const out: TriageLinkedItem[] = [];
  for (const node of Json.arr(conn, 'nodes')) {
    const it = node as JsonMap;
    const id = Json.str(it, 'id');
    if (id === excludeId) {
      continue;
    }
    out.push({
      id: id, number: Json.num(it, 'number'), title: Json.str(it, 'title'), state: Json.str(it, 'state')
    });
  }
  return out;
}

/** 项目候选：scope='user' 取 viewer.projectsV2，其余取 repository.projectsV2 */
export function mapTriageProjects(data: JsonMap, scope: string): TriageProject[] {
  const wrap = scope === 'user'
    ? Json.obj(data, 'viewer')
    : Json.obj(data, 'repository');
  const conn = Json.obj(wrap ?? ({} as JsonMap), 'projectsV2') ?? ({} as JsonMap);
  const out: TriageProject[] = [];
  for (const node of Json.arr(conn, 'nodes')) {
    const it = node as JsonMap;
    out.push({ id: Json.str(it, 'id'), title: Json.str(it, 'title') });
  }
  return out;
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
    // 哨兵值=「Assigned to nobody」（filterBy 推不下去，客户端筛无 assignees 行）
    if (assignee === NONE_FILTER_KEY) {
      if (pr.assignees.length === 0) {
        next.push(pr);
      }
      continue;
    }
    if (assignee === '' || pr.assignees.indexOf(assignee) >= 0) {
      next.push(pr);
    }
  }
  return next;
}

/** Milestone 客户端过滤（服务端无参数）：''=不筛；哨兵值=「No milestone」只留无里程碑行 */
export function filterPrsByMilestone(prs: RepoPrItem[], milestone: string): RepoPrItem[] {
  const next: RepoPrItem[] = [];
  for (const pr of prs) {
    if (milestone === '') {
      next.push(pr);
      continue;
    }
    if (milestone === NONE_FILTER_KEY) {
      if (pr.milestoneTitle === '') {
        next.push(pr);
      }
      continue;
    }
    if (pr.milestoneTitle === milestone) {
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

/** Release 官方选择器子集：6 种正向反应（官方 release 详情面板无 👎/😕，走查修正九轮） */
export const RELEASE_REACTION_META: ReactionMeta[] = REACTION_META.filter((m: ReactionMeta) =>
  m.content !== 'THUMBS_DOWN' && m.content !== 'CONFUSED');

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
  const milestone = Json.obj(raw, 'milestone');
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
    checksCount: checks !== null ? Json.num(Json.obj(checks, 'contexts') ?? ({} as JsonMap), 'totalCount') : 0,
    authorLogin: author !== null ? Json.str(author, 'login') : '',
    authorAvatar: author !== null ? Json.str(author, 'avatarUrl') : '',
    assignees: assignees,
    milestoneTitle: milestone !== null ? Json.str(milestone, 'title') : ''
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
  const labelOptions: WorkLabel[] = [];
  if (labelsWrap !== null) {
    for (const nodeItem of Json.arr(labelsWrap, 'nodes')) {
      labelOptions.push({ name: Json.str(nodeItem as JsonMap, 'name'), color: Json.str(nodeItem as JsonMap, 'color') });
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
      name: Json.str(node, 'name'),
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

/** Reactees 整页（release 反应用户，走查九轮）：取指定 content 组的分页 reactors */
export interface ReactionUsersPage {
  totalCount: number;
  users: ReactionUser[];
  endCursor: string;
  hasNextPage: boolean;
}

export function mapReactionUsersPage(data: JsonMap, content: string): ReactionUsersPage {
  const node = Json.obj(data, 'node') ?? ({} as JsonMap);
  for (const groupItem of Json.arr(node, 'reactionGroups')) {
    const group = groupItem as JsonMap;
    if (Json.str(group, 'content') !== content) {
      continue;
    }
    const reactors = Json.obj(group, 'reactors') ?? ({} as JsonMap);
    const pageInfo = Json.obj(reactors, 'pageInfo') ?? ({} as JsonMap);
    const users: ReactionUser[] = [];
    for (const nodeItem of Json.arr(reactors, 'nodes')) {
      const raw = nodeItem as JsonMap;
      users.push({
        login: Json.str(raw, 'login'),
        name: Json.str(raw, 'name'),
        avatarUrl: Json.str(raw, 'avatarUrl')
      });
    }
    return {
      totalCount: Json.num(reactors, 'totalCount'),
      users: users,
      endCursor: Json.str(pageInfo, 'endCursor'),
      hasNextPage: Json.bool(pageInfo, 'hasNextPage')
    };
  }
  return { totalCount: 0, users: [], endCursor: '', hasNextPage: false };
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
  const reactions: ReactionGroup[] = [];
  for (const groupItem of Json.arr(release, 'reactionGroups')) {
    reactions.push(mapReactionGroup(groupItem as JsonMap));
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
    assets: assets,
    reactions: reactions
  };
}


/** reactionGroups 数组映射（Explore 信息流卡等复用，Spec 056） */
export function mapReactionGroups(raw: Object[]): ReactionGroup[] {
  const groups: ReactionGroup[] = [];
  for (const nodeItem of raw) {
    groups.push(mapReactionGroup(nodeItem as JsonMap));
  }
  return groups;
}

function mapComment(raw: JsonMap): RepoComment {
  const author = Json.obj(raw, 'author');
  const reactions = mapReactionGroups(Json.arr(raw, 'reactionGroups'));
  return {
    id: Json.str(raw, 'id'),
    body: Json.str(raw, 'body'),
    bodyHTML: Json.str(raw, 'bodyHTML'),
    createdAt: Json.str(raw, 'createdAt'),
    authorLogin: author !== null ? Json.str(author, 'login') : '',
    authorAvatar: author !== null ? Json.str(author, 'avatarUrl') : '',
    authorIsBot: author !== null && Json.str(author, '__typename') === 'Bot',
    viewerDidAuthor: Json.bool(raw, 'viewerDidAuthor'),
    reactions: reactions
  };
}

// ─────────────── Spec 043：Issue/PR 创建与编辑（表单数据模型）───────────────

/** 官方 Issue 模板（repository.issueTemplates，普通列表非 Connection；filename 为模板文件名） */
export interface IssueTemplateItem {
  name: string;
  title: string;
  body: string;
  filename: string;
  /** 模板描述行（Choose Template 页灰字） */
  about: string;
  /** 模板 YAML 预置标签名（创建时自动带上） */
  labels: string[];
  /** 模板 YAML 预置负责人 login（创建时自动带上） */
  assignees: string[];
}

/** 仓库分支行（refs(refPrefix:"refs/heads/")；New PR base/head 选择） */
export interface BranchRefItem {
  name: string;
  oid: string;
}

/** Home「+」→ Choose a repository 选仓库页行（官方两行：owner 头像/login 灰字 + 仓库名） */
export interface PickerRepo {
  id: string;
  ownerLogin: string;
  ownerAvatar: string;
  name: string;
}

/** `owner/name` 组合（候选过滤与展示共用） */
export function pickerRepoFullName(repo: PickerRepo): string {
  return `${repo.ownerLogin}/${repo.name}`;
}

export function mapIssueTemplates(data: JsonMap): IssueTemplateItem[] {
  const repo = Json.obj(data, 'repository') ?? ({} as JsonMap);
  const items: IssueTemplateItem[] = [];
  for (const nodeItem of Json.arr(repo, 'issueTemplates')) {
    const it = nodeItem as JsonMap;
    const labelNames: string[] = [];
    const labelsConn = Json.obj(it, 'labels');
    if (labelsConn !== null) {
      for (const l of Json.arr(labelsConn, 'nodes')) {
        labelNames.push(Json.str(l as JsonMap, 'name'));
      }
    }
    const assigneeLogins: string[] = [];
    const assigneesConn = Json.obj(it, 'assignees');
    if (assigneesConn !== null) {
      for (const a of Json.arr(assigneesConn, 'nodes')) {
        assigneeLogins.push(Json.str(a as JsonMap, 'login'));
      }
    }
    items.push({
      name: Json.str(it, 'name'),
      title: Json.str(it, 'title'),
      body: Json.str(it, 'body'),
      filename: Json.str(it, 'filename'),
      about: Json.str(it, 'about'),
      labels: labelNames,
      assignees: assigneeLogins
    });
  }
  return items;
}

export function mapBranchRefs(data: JsonMap): BranchRefItem[] {
  const repo = Json.obj(data, 'repository') ?? ({} as JsonMap);
  const refs = Json.obj(repo, 'refs') ?? ({} as JsonMap);
  const items: BranchRefItem[] = [];
  for (const nodeItem of Json.arr(refs, 'nodes')) {
    const it = nodeItem as JsonMap;
    const target = Json.obj(it, 'target');
    items.push({ name: Json.str(it, 'name'), oid: target !== null ? Json.str(target, 'oid') : '' });
  }
  return items;
}

/** 分支选择器候选（Compare changes 动线，Spec 043）：默认分支名 + refs 全量分支名 */
export interface BranchRefs {
  defaultBranch: string;
  names: string[];
}

/** 分支选择器单页（Compare changes 动线，Spec 043）：分支名数组 + 翻页信息 + 默认分支 */
export interface BranchNamesPage {
  names: string[];
  hasNextPage: boolean;
  endCursor: string;
  defaultBranch: string;
}

export function mapBranchNamesPage(data: JsonMap): BranchNamesPage {
  const repo = Json.obj(data, 'repository') ?? ({} as JsonMap);
  const dbr = Json.obj(repo, 'defaultBranchRef');
  const refs = Json.obj(repo, 'refs') ?? ({} as JsonMap);
  const pageInfo = Json.obj(refs, 'pageInfo') ?? ({} as JsonMap);
  const names: string[] = [];
  for (const nodeItem of Json.arr(refs, 'nodes')) {
    names.push(Json.str(nodeItem as JsonMap, 'name'));
  }
  return {
    names: names,
    hasNextPage: Json.bool(pageInfo, 'hasNextPage'),
    endCursor: Json.str(pageInfo, 'endCursor'),
    defaultBranch: dbr !== null ? Json.str(dbr, 'name') : ''
  };
}

/** Changes 汇总（REST compare 累加结果；commits 取 total_commits 精确值）。
 *  filesTruncated=true 表示命中 compare 300 文件上限、additions/deletions 仅为前 300 文件
 *  的部分和（files 已用 Git Trees diff 补成精确值）——UI 此时隐藏 +/- 行（产品口径：
 *  绝不给用户可疑数字，Spec 043 §五/§七） */
export interface CompareSummary {
  files: number;
  additions: number;
  deletions: number;
  commits: number;
  filesTruncated: boolean;
}

/** REST compare 单页解析：累加 files[] 的 additions/deletions，首页回填 total_commits；返回本页文件数供判停 */
export function mergeComparePage(acc: CompareSummary, body: string, isFirst: boolean): number {
  const page = JSON.parse(body) as JsonMap;
  if (isFirst) {
    acc.commits = Json.num(page, 'total_commits');
  }
  const files = Json.arr(page, 'files');
  for (const node of files) {
    const f = node as JsonMap;
    acc.additions += Json.num(f, 'additions');
    acc.deletions += Json.num(f, 'deletions');
  }
  return files.length;
}

/** REST compare 响应里的 base_commit.sha（Trees diff 的基树） */
export function parseCompareBaseSha(body: string): string {
  const page = JSON.parse(body) as JsonMap;
  const baseCommit = Json.obj(page, 'base_commit') ?? ({} as JsonMap);
  return Json.str(baseCommit, 'sha');
}

/** head 分支 tip（Changes 行相对时间 + Trees diff 的头树 oid） */
export interface RefTip {
  oid: string;
  date: string;
}

/** 递归树解析结果：path→对象 sha（blob 与子模块 commit 指针计入，tree 目录跳过）+ 截断标志 */
export interface TreeEntries {
  paths: Map<string, string>;
  truncated: boolean;
}

export function parseTreeEntries(body: string): TreeEntries {
  const page = JSON.parse(body) as JsonMap;
  const paths = new Map<string, string>();
  for (const node of Json.arr(page, 'tree')) {
    const e = node as JsonMap;
    if (Json.str(e, 'type') === 'tree') {
      continue;
    }
    paths.set(Json.str(e, 'path'), Json.str(e, 'sha'));
  }
  return { paths: paths, truncated: Json.bool(page, 'truncated') };
}

/** 两棵递归树的差异文件数（path 并集上 sha 不同或单侧独有） */
export function countTreeDiff(base: TreeEntries, head: TreeEntries): number {
  let count = 0;
  base.paths.forEach((sha: string, path: string): void => {
    const headSha = head.paths.get(path);
    if (headSha === undefined || headSha !== sha) {
      count += 1;
    }
  });
  head.paths.forEach((sha: string, path: string): void => {
    if (!base.paths.has(path)) {
      count += 1;
    }
  });
  return count;
}

export function mapPickerRepos(data: JsonMap): PickerRepo[] {
  const viewer = Json.obj(data, 'viewer') ?? ({} as JsonMap);
  const items: PickerRepo[] = [];
  const seen = new Set<string>();
  // 候选 = 自有/协作/组织成员仓库 ∪ 参与过的仓库（官方列表口径，去重）
  const collect = (connKey: string): void => {
    const conn = Json.obj(viewer, connKey) ?? ({} as JsonMap);
    for (const nodeItem of Json.arr(conn, 'nodes')) {
      const it = nodeItem as JsonMap;
      const owner = Json.obj(it, 'owner');
      const login = owner !== null ? Json.str(owner, 'login') : '';
      const name = Json.str(it, 'name');
      const full = `${login}/${name}`;
      if (login === '' || seen.has(full)) {
        continue;
      }
      seen.add(full);
      items.push({
        id: Json.str(it, 'id'),
        name: name,
        ownerLogin: login,
        ownerAvatar: owner !== null ? Json.str(owner, 'avatarUrl') : ''
      });
    }
  };
  collect('repositories');
  collect('repositoriesContributedTo');
  return items;
}

/** 服务端仓库搜索 → 候选（search.nodes 经 ... on Repository 内联片段返回字段） */
export function mapPickerSearch(data: JsonMap): PickerRepo[] {
  const search = Json.obj(data, 'search') ?? ({} as JsonMap);
  const items: PickerRepo[] = [];
  for (const nodeItem of Json.arr(search, 'nodes')) {
    const it = nodeItem as JsonMap;
    const owner = Json.obj(it, 'owner');
    items.push({
      id: Json.str(it, 'id'),
      name: Json.str(it, 'name'),
      ownerLogin: owner !== null ? Json.str(owner, 'login') : '',
      ownerAvatar: owner !== null ? Json.str(owner, 'avatarUrl') : ''
    });
  }
  return items;
}

/** 仓库候选按关键字过滤（owner/name 组合大小写不敏感包含匹配） */
export function filterReposByKeyword(repos: PickerRepo[], keyword: string): PickerRepo[] {
  const q = keyword.trim().toLowerCase();
  if (q === '') {
    return repos;
  }
  return repos.filter((r: PickerRepo): boolean => pickerRepoFullName(r).toLowerCase().indexOf(q) >= 0);
}

/** 表单基础数据聚合（REPO_FORM_QUERY 一次取全：新建 Issue/PR 都要用） */
export interface RepoFormPage {
  repoId: string;
  defaultBranch: string;
  templates: IssueTemplateItem[];
  branches: BranchRefItem[];
  /** 安全政策页 URL（仓库有 SECURITY.md 才非空；Choose Template 页 Security 行） */
  securityPolicyUrl: string;
}

export function mapRepoForm(data: JsonMap): RepoFormPage {
  const repo = Json.obj(data, 'repository') ?? ({} as JsonMap);
  const dbr = Json.obj(repo, 'defaultBranchRef');
  return {
    repoId: Json.str(repo, 'id'),
    defaultBranch: dbr !== null ? Json.str(dbr, 'name') : '',
    templates: mapIssueTemplates(data),
    branches: mapBranchRefs(data),
    securityPolicyUrl: Json.str(repo, 'securityPolicyUrl')
  };
}

/** 编辑回填内容（Issue/PR 同构：id/title/body + 权限门） */
export interface EditableContent {
  id: string;
  title: string;
  body: string;
  viewerCanUpdate: boolean;
}

/** createIssue 结果（id 供创建后挂 Project，number 供跳详情） */
export interface IssueCreated {
  id: string;
  number: number;
}

/** 按 field（'issue' | 'pullRequest'）取编辑回填节点 */
export function mapEditable(data: JsonMap, field: string): EditableContent {
  const repo = Json.obj(data, 'repository') ?? ({} as JsonMap);
  const node = Json.obj(repo, field) ?? ({} as JsonMap);
  return {
    id: Json.str(node, 'id'),
    title: Json.str(node, 'title'),
    body: Json.str(node, 'body'),
    viewerCanUpdate: Json.bool(node, 'viewerCanUpdate')
  };
}

/** Choose Template 页：config.yml 联系链接行（外链跳浏览器，官方带 ⧉ 图标） */
export interface TemplateContactLink {
  name: string;
  about: string;
  url: string;
}

/** Choose Template 页：issue form（.yml 表单，GraphQL issueTemplates 不返回；移动端跳网页填写） */
export interface IssueFormTemplate {
  name: string;
  description: string;
  filename: string;
}

/** .github/ISSUE_TEMPLATE 目录的 forms + contact links 聚合 */
export interface IssueTemplateExtras {
  forms: IssueFormTemplate[];
  contactLinks: TemplateContactLink[];
}

/** 去行尾回车符 */
function chomp(line: string): string {
  return line.endsWith('\r') ? line.substring(0, line.length - 1) : line;
}

/** 去 YAML 值两端成对引号 */
function unquote(value: string): string {
  const v = value.trim();
  if (v.length >= 2 && ((v.startsWith('"') && v.endsWith('"')) || (v.startsWith("'") && v.endsWith("'")))) {
    return v.substring(1, v.length - 1);
  }
  return v;
}

/** 解析 config.yml 的 contact_links 段（逐行扫描：`- name:` 开新项，`about:`/`url:` 归属当前项） */
export function parseContactLinks(yaml: string): TemplateContactLink[] {
  const items: TemplateContactLink[] = [];
  const lines = yaml.split('\n');
  let inSection = false;
  let current: TemplateContactLink | null = null;
  for (const raw of lines) {
    const line = chomp(raw);
    if (line.trim() === '' || line.trim().startsWith('#')) {
      continue;
    }
    if (/^\S/.test(line)) {
      // 顶层键：contact_links 段开/关（段前可能有其他顶层键如 blank_issues_enabled，故全文件扫描）
      inSection = line.startsWith('contact_links:');
      current = null;
      continue;
    }
    if (!inSection) {
      continue;
    }
    const nameMatch = line.match(/^\s*-\s*name:\s*(.*)$/);
    if (nameMatch !== null) {
      current = { name: unquote(nameMatch[1]), about: '', url: '' };
      items.push(current);
      continue;
    }
    const aboutMatch = line.match(/^\s+about:\s*(.*)$/);
    if (aboutMatch !== null && current !== null) {
      current.about = unquote(aboutMatch[1]);
      continue;
    }
    const urlMatch = line.match(/^\s+url:\s*(.*)$/);
    if (urlMatch !== null && current !== null) {
      current.url = unquote(urlMatch[1]);
    }
  }
  return items;
}

/** 解析 issue form（.yml）顶层 name/description（只取未缩进行，忽略 body 块内字段） */
export function parseIssueFormMeta(yaml: string, filename: string): IssueFormTemplate | null {
  let name = '';
  let description = '';
  for (const raw of yaml.split('\n')) {
    const line = chomp(raw);
    if (line.trim() === '' || /^\s/.test(line) || line.trim().startsWith('#')) {
      continue;
    }
    const nameMatch = line.match(/^name:\s*(.*)$/);
    if (nameMatch !== null && name === '') {
      name = unquote(nameMatch[1]);
      continue;
    }
    const descMatch = line.match(/^description:\s*(.*)$/);
    if (descMatch !== null && description === '') {
      description = unquote(descMatch[1]);
    }
  }
  if (name === '') {
    return null;
  }
  return { name: name, description: description, filename: filename };
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
    viewerCanUpdate: Json.bool(issue, 'viewerCanUpdate'),
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
  const repoOwner = Json.obj(repo, 'owner');
  const mergedBy = Json.obj(pr, 'mergedBy');
  const mergeCommit = Json.obj(pr, 'mergeCommit');
  const files = Json.obj(pr, 'files');
  const commitsSum = Json.obj(pr, 'commits');
  const reviews = Json.obj(pr, 'reviews');
  const checks = Json.obj(pr, 'statusCheckRollup');
  // 会话时间轴（官方 Conversation）：事件 + 评论 + 审阅按时间序，单一游标分页
  const timelineWrap = Json.obj(pr, 'timelineItems') ?? ({} as JsonMap);
  const timelinePage = Json.obj(timelineWrap, 'pageInfo') ?? ({} as JsonMap);
  const labelItems: MetaLabel[] = [];
  const labelsConn = Json.obj(pr, 'labels') ?? ({} as JsonMap);
  for (const nodeItem of Json.arr(labelsConn, 'nodes')) {
    const it = nodeItem as JsonMap;
    labelItems.push({ id: Json.str(it, 'id'), name: Json.str(it, 'name'), color: Json.str(it, 'color') });
  }
  const assigneeItems: MetaUser[] = [];
  const assigneesConn = Json.obj(pr, 'assignees') ?? ({} as JsonMap);
  for (const nodeItem of Json.arr(assigneesConn, 'nodes')) {
    const it = nodeItem as JsonMap;
    assigneeItems.push({ id: Json.str(it, 'id'), login: Json.str(it, 'login'), avatarUrl: Json.str(it, 'avatarUrl') });
  }
  const milestoneObj = Json.obj(pr, 'milestone');
  const milestoneItem: MetaMilestone | null = milestoneObj !== null
    ? { id: Json.str(milestoneObj, 'id'), title: Json.str(milestoneObj, 'title') }
    : null;
  return {
    subjectId: Json.str(pr, 'id'),
    number: Json.num(pr, 'number'),
    title: Json.str(pr, 'title'),
    state: Json.str(pr, 'state'),
    merged: Json.bool(pr, 'merged'),
    isDraft: Json.bool(pr, 'isDraft'),
    viewerCanUpdate: Json.bool(pr, 'viewerCanUpdate'),
    body: Json.str(pr, 'body'),
    bodyHTML: Json.str(pr, 'bodyHTML'),
    createdAt: Json.str(pr, 'createdAt'),
    mergedAt: Json.str(pr, 'mergedAt'),
    additions: Json.num(pr, 'additions'),
    deletions: Json.num(pr, 'deletions'),
    authorLogin: author !== null ? Json.str(author, 'login') : '',
    authorAvatar: author !== null ? Json.str(author, 'avatarUrl') : '',
    authorAssociation: Json.str(pr, 'authorAssociation'),
    reactions: mapReactionGroups(Json.arr(pr, 'reactionGroups')),
    ownerAvatar: repoOwner !== null ? Json.str(repoOwner, 'avatarUrl') : '',
    headRefName: Json.str(pr, 'headRefName'),
    baseRefName: Json.str(pr, 'baseRefName'),
    mergeOid: mergeCommit !== null ? Json.str(mergeCommit, 'abbreviatedOid') : '',
    mergedByLogin: mergedBy !== null ? Json.str(mergedBy, 'login') : '',
    filesCount: files !== null ? Json.num(files, 'totalCount') : 0,
    commitsCount: commitsSum !== null ? Json.num(commitsSum, 'totalCount') : 0,
    reviewsTotal: reviews !== null ? Json.num(reviews, 'totalCount') : 0,
    checksState: checks !== null ? Json.str(checks, 'state') : '',
    checks: mapStatusChecks(checks),
    checksTotal: mapChecksTotal(checks),
    labelItems: labelItems,
    assigneeItems: assigneeItems,
    milestoneItem: milestoneItem,
    mergeable: Json.str(pr, 'mergeable'),
    mergeStateStatus: Json.str(pr, 'mergeStateStatus'),
    repoViewerPermission: Json.str(repo, 'viewerPermission'),
    defaultMergeMethod: Json.str(repo, 'viewerDefaultMergeMethod'),
    mergeHeadline: Json.str(pr, 'viewerMergeHeadlineText'),
    mergeBody: Json.str(pr, 'viewerMergeBodyText'),
    timeline: mapTimeline(timelineWrap),
    // 分页信息在 pageInfo 内（连接层没有 hasNextPage/endCursor 键）
    timelineHasNext: Json.bool(timelinePage, 'hasNextPage'),
    timelineCursor: Json.str(timelinePage, 'endCursor'),
    threads: mapReviewThreads(Json.obj(pr, 'reviewThreads'))
  };
}

/** contexts.totalCount（View all 次行计数；连接被 first:20 截断时 totalCount 仍是全量） */
function mapChecksTotal(checks: JsonMap | null): number {
  if (checks === null) {
    return 0;
  }
  const conn = Json.obj(checks, 'contexts');
  return conn !== null ? Json.num(conn, 'totalCount') : 0;
}

/**
 * statusCheckRollup.contexts → 归一化行（Spec 048 富行）。
 * CheckRun 用 conclusion（缺省回落 status），StatusContext 用 state；state 值两族共用分档/文案映射。
 */
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
    const runId = Json.num(node, 'databaseId');
    const conclusion = Json.str(node, 'conclusion');
    const state = conclusion !== '' ? conclusion : Json.str(node, 'state');
    const name = Json.str(node, 'name') !== '' ? Json.str(node, 'name') : Json.str(node, 'context');
    const suite = Json.obj(node, 'checkSuite');
    const app = suite !== null ? Json.obj(suite, 'app') : null;
    if (name !== '') {
      items.push({
        key: `${name}#${items.length}`,
        name: name,
        state: state,
        checkRunId: runId,
        // CheckRun detailsUrl / StatusContext targetUrl：均为官方页链接，键不同值同用
        detailsUrl: Json.str(node, 'detailsUrl') !== '' ? Json.str(node, 'detailsUrl') : Json.str(node, 'targetUrl'),
        title: Json.str(node, 'title'),
        startedAt: Json.str(node, 'startedAt'),
        completedAt: Json.str(node, 'completedAt'),
        appLogo: app !== null ? Json.str(app, 'logoUrl') : ''
      });
    }
  }
  return items;
}

/** reviews(first) connection → 审阅卡行（Spec 042 元素4） */
/** 单条审阅节点 → PrReview（时间轴 review 节点与审阅编辑共用） */
export function mapReview(node: JsonMap): PrReview {
  const author = Json.obj(node, 'author');
  return {
    id: Json.str(node, 'id'),
    state: Json.str(node, 'state'),
    body: Json.str(node, 'body'),
    bodyHTML: Json.str(node, 'bodyHTML'),
    submittedAt: Json.str(node, 'submittedAt'),
    authorLogin: author !== null ? Json.str(author, 'login') : '',
    authorAvatar: author !== null ? Json.str(author, 'avatarUrl') : '',
    authorIsBot: author !== null && Json.str(author, '__typename') === 'Bot',
    viewerDidAuthor: Json.bool(node, 'viewerDidAuthor')
  };
}

/** reviewThreads(first) connection → thread 行；line 为 null（文件级）归一为 0（Spec 042 元素4） */
export function mapReviewThreads(conn: JsonMap | null): ReviewThread[] {
  const items: ReviewThread[] = [];
  if (conn === null) {
    return items;
  }
  for (const nodeItem of Json.arr(conn, 'nodes')) {
    const node = nodeItem as JsonMap;
    const commentsWrap = Json.obj(node, 'comments') ?? ({} as JsonMap);
    const comments: ReviewThreadComment[] = [];
    for (const commentItem of Json.arr(commentsWrap, 'nodes')) {
      const comment = commentItem as JsonMap;
      const commentAuthor = Json.obj(comment, 'author');
      comments.push({
        id: Json.str(comment, 'id'),
        body: Json.str(comment, 'body'),
        bodyHTML: Json.str(comment, 'bodyHTML'),
        createdAt: Json.str(comment, 'createdAt'),
        authorLogin: commentAuthor !== null ? Json.str(commentAuthor, 'login') : '',
        authorAvatar: commentAuthor !== null ? Json.str(commentAuthor, 'avatarUrl') : '',
        authorIsBot: commentAuthor !== null && Json.str(commentAuthor, '__typename') === 'Bot',
        viewerDidAuthor: Json.bool(comment, 'viewerDidAuthor')
      });
    }
    items.push({
      id: Json.str(node, 'id'),
      path: Json.str(node, 'path'),
      line: Json.num(node, 'line'),
      isResolved: Json.bool(node, 'isResolved'),
      isOutdated: Json.bool(node, 'isOutdated'),
      viewerCanResolve: Json.bool(node, 'viewerCanResolve'),
      viewerCanUnresolve: Json.bool(node, 'viewerCanUnresolve'),
      comments: comments,
      commentsTotal: Json.num(commentsWrap, 'totalCount')
    });
  }
  return items;
}

/**
 * Merge 可用性门（Spec 042 元素8/9）：未合并 + 服务端可合 + 仓库写权限。
 * PR 无 viewerCanMerge 字段（运行时实测），权限改用 Repository.viewerPermission；
 * mergeStateStatus 的细粒度阻塞（BLOCKED/BEHIND…）由 mergeStateReasonKey 呈现文案，
 * 门禁只看 mergeable（CONFLICTING/UNKNOWN 一律禁用）。
 */
export function canMergePr(merged: boolean, mergeable: string, repoViewerPermission: string): boolean {
  const canWrite = repoViewerPermission === 'ADMIN'
    || repoViewerPermission === 'MAINTAIN' || repoViewerPermission === 'WRITE';
  return !merged && mergeable === 'MERGEABLE' && canWrite;
}

/**
 * Merge options 当前生效方式（Spec 042 元素8）：用户选过（current 非空）用用户的，
 * 否则取服务端默认 `Repository.viewerDefaultMergeMethod`（PR 无 mergeMethod 参数，默认值只能来自仓库），
 * 再兜底 MERGE。UI 侧不得用「固定 squash」当初值——那会让服务端默认永不生效。
 */
export function resolveMergeMethod(current: string, serverDefault: string): string {
  if (current !== '') {
    return current;
  }
  return serverDefault !== '' ? serverDefault : 'MERGE';
}

/**
 * mergeStateStatus → 不可合并原因文案键后缀（Spec 042 元素10；UI 拼 $r('app.string.pr_merge_state_*')）。
 * 未知枚举兜底 unknown（测试 8：失败显示对应原因且不崩溃）。
 */
export function mergeStateReasonKey(status: string): string {
  switch (status) {
    case 'DIRTY':
      return 'conflicting';
    case 'BLOCKED':
      return 'blocked';
    case 'BEHIND':
      return 'behind';
    case 'UNSTABLE':
      return 'unstable';
    case 'DRAFT':
      return 'draft';
    case 'HAS_HOOKS':
      return 'has_hooks';
    default:
      return 'unknown';
  }
}

/** PullRequestReviewState → 审阅卡徽章文案键后缀（pr_review_state_*；未知值按 COMMENTED 呈现） */
export function reviewStateKey(state: string): string {
  switch (state) {
    case 'APPROVED':
      return 'approved';
    case 'CHANGES_REQUESTED':
      return 'changes_requested';
    case 'DISMISSED':
      return 'dismissed';
    case 'PENDING':
      return 'pending';
    default:
      return 'commented';
  }
}
