/**
 * Explore 页数据模型与映射（Spec 056：Activity 动态流 + Summary 轻量解析）。
 * 003 的 Topic 搜索模型已随官方化版式移除。
 */
import { Json, JsonMap } from '../utils/Json';
import { ReactionGroup, mapReactionGroups } from './RepoSubModels';

/** 信息流卡片上限（一次 alias 批量查询的条数） */
export const MAX_ACTIVITY_ITEMS = 10;

/** Summary 折叠时展示的行数（超出渐隐 + Read more） */
export const SUMMARY_COLLAPSED_LINES = 4;

/** received_events 中筛出的 merged PR 事件（GraphQL 补详情前） */
export interface ActivityPrRef {
  eventId: string;
  repoFullName: string;
  number: number;
  headRef: string;
  actorLogin: string;
  actorAvatar: string;
  /** 仓库所属组织小头像（无组织为空） */
  orgAvatar: string;
  createdAt: string;
}

/** 活动卡片（事件 + GraphQL 详情合并后） */
export interface ExploreActivityEvent {
  /** ForEach key：repo/number 唯一 */
  key: string;
  repoFullName: string;
  number: number;
  title: string;
  body: string;
  merged: boolean;
  /** 反应 mutation 的节点 id */
  subjectId: string;
  /** PR 作者（展示为贡献者；空时映射层已回退事件 actor） */
  authorLogin: string;
  authorAvatar: string;
  orgAvatar: string;
  headRef: string;
  /** target/合并目标分支（GraphQL baseRefName；空=未知） */
  baseRef: string;
  createdAt: string;
  reactions: ReactionGroup[];
}

/** Summary 内联分段（isCode 灰底等宽渲染） */
export interface SummarySegment {
  text: string;
  isCode: boolean;
}

/** Summary 行（bullet 圆点 + 分段） */
export interface SummaryLine {
  bullet: boolean;
  segments: SummarySegment[];
}

/**
 * REST received_events → merged PR 事件引用。
 * 仅保留 type=PullRequestEvent 且 payload.action=merged；repo+number 去重、上限 MAX_ACTIVITY_ITEMS。
 */
export function mapActivityEvents(events: Object[]): ActivityPrRef[] {
  const refs: ActivityPrRef[] = [];
  const seen = new Set<string>();
  for (const eventItem of events) {
    const event = eventItem as JsonMap;
    if (Json.str(event, 'type') !== 'PullRequestEvent') {
      continue;
    }
    const payload = Json.obj(event, 'payload');
    if (payload === null || Json.str(payload, 'action') !== 'merged') {
      continue;
    }
    const repo = Json.obj(event, 'repo');
    const pull = Json.obj(payload, 'pull_request');
    if (repo === null || pull === null) {
      continue;
    }
    const repoFullName = Json.str(repo, 'name');
    const number = Json.num(pull, 'number');
    const key = `${repoFullName}#${number}`;
    if (seen.has(key)) {
      continue;
    }
    seen.add(key);
    const actor = Json.obj(event, 'actor');
    const org = Json.obj(event, 'org');
    const head = Json.obj(pull, 'head');
    refs.push({
      eventId: Json.str(event, 'id'),
      repoFullName: repoFullName,
      number: number,
      headRef: head !== null ? Json.str(head, 'ref') : '',
      actorLogin: actor !== null ? Json.str(actor, 'login') : '',
      actorAvatar: actor !== null ? Json.str(actor, 'avatar_url') : '',
      orgAvatar: org !== null ? Json.str(org, 'avatar_url') : '',
      createdAt: Json.str(event, 'created_at')
    });
    if (refs.length >= MAX_ACTIVITY_ITEMS) {
      break;
    }
  }
  return refs;
}

/**
 * 事件与 GraphQL alias 详情 zip 合并。
 * alias 节点为 null（PR 已删）时剔除该条；author 为空回退事件 actor。
 */
export function mapActivityEventsWithDetails(refs: ActivityPrRef[], data: JsonMap): ExploreActivityEvent[] {
  const out: ExploreActivityEvent[] = [];
  for (let i = 0; i < refs.length; i++) {
    const node = Json.obj(data, `r${i}`);
    if (node === null) {
      continue;
    }
    const pull = Json.obj(node, 'pullRequest');
    if (pull === null) {
      continue;
    }
    const author = Json.obj(pull, 'author');
    const authorLogin = author !== null ? Json.str(author, 'login') : '';
    const ref = refs[i];
    out.push({
      key: `${ref.repoFullName}/${ref.number}`,
      repoFullName: ref.repoFullName,
      number: ref.number,
      title: Json.str(pull, 'title'),
      body: Json.str(pull, 'body'),
      merged: Json.bool(pull, 'merged'),
      subjectId: Json.str(pull, 'id'),
      authorLogin: authorLogin !== '' ? authorLogin : ref.actorLogin,
      authorAvatar: author !== null ? Json.str(author, 'avatarUrl') : ref.actorAvatar,
      orgAvatar: ref.orgAvatar,
      // GraphQL 别名取 head/base；head 回退 REST 事件源（老数据无 headRefName）
      headRef: Json.str(pull, 'headRefName') !== '' ? Json.str(pull, 'headRefName') : ref.headRef,
      baseRef: Json.str(pull, 'baseRefName'),
      createdAt: ref.createdAt,
      reactions: mapReactionGroups(Json.arr(pull, 'reactionGroups'))
    });
  }
  return out;
}

/**
 * PR 正文 → Summary 行（轻量解析）：
 * 剥离图片/链接地址/粗体标记，`code` 转 isCode 分段，标题行/围栏标记/引用/注释行跳过。
 * 完整渲染在 prDetail（MarkdownView），卡片只保官方信息流观感。
 */
export function summarizeBody(body: string): SummaryLine[] {
  const lines: SummaryLine[] = [];
  let inFence = false;
  for (const rawLine of body.split('\n')) {
    const line = rawLine.trim();
    if (line === '') {
      continue;
    }
    if (line.startsWith('```')) {
      inFence = !inFence;
      continue;
    }
    if (inFence) {
      lines.push({ bullet: false, segments: [{ text: line, isCode: true }] });
      continue;
    }
    if (line.startsWith('#') || line.startsWith('>') || line.startsWith('<!--')) {
      continue;
    }
    let content = line;
    let bullet = false;
    // 无序（- * +）与有序（1.）列表都算 bullet
    const bulletMatch = /^([-*+]|\d+\.)\s+(.*)$/.exec(content);
    if (bulletMatch !== null && bulletMatch.length >= 3) {
      bullet = true;
      content = bulletMatch[2];
    }
    const segments = parseSummaryInline(content);
    // 整行只剩图片等被剥空的内容时跳过，防空行
    if (segments.length === 0) {
      continue;
    }
    lines.push({ bullet: bullet, segments: segments });
  }
  return lines;
}

/** 行内解析：剥图片/链接/粗体，`code` 转 isCode 分段（反引号奇数个时末端按普通文本兜底） */
function parseSummaryInline(text: string): SummarySegment[] {
  let rest = text.replace(/!\[[^\]]*\]\([^)]*\)/g, '');
  rest = rest.replace(/\[([^\]]*)\]\([^)]*\)/g, '$1');
  rest = rest.replace(/\*\*([^*]+)\*\*/g, '$1');
  const segments: SummarySegment[] = [];
  const parts = rest.split('`');
  for (let i = 0; i < parts.length; i++) {
    if (parts[i] === '') {
      continue;
    }
    segments.push({ text: parts[i], isCode: i % 2 === 1 });
  }
  return segments;
}
