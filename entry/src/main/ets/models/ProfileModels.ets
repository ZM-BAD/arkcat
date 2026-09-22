/**
 * 用户主页数据模型与映射（Spec 005）+ 用户/组织列表与组织主页模型（Spec 034-037）
 * + 用户状态读写模型（Spec 076）。
 */
import { Json, JsonMap } from '../utils/Json';
import { RepoSummary, UserSummary, mapRepo, mapUser } from './GitHubModels';

/** 状态 emoji 可渲染形态（Spec 076）：文本字形优先，GitHub 自定义 emoji 走图片 */
export interface StatusEmoji {
  /** 可文本渲染的 Unicode 字形（'' = 不适用） */
  text: string;
  /** 图片地址（自定义 emoji；'' = 不适用） */
  image: string;
}

/** 用户状态（Spec 076；无状态时 UserProfile.status 为 null） */
export interface UserStatus {
  emoji: StatusEmoji;
  /** 接口原样取值（原生字形或 `:shortcode:`）：提交时原样回传，避免改动用户既有 emoji */
  emojiRaw: string;
  message: string;
  /** Busy（GraphQL `indicatesLimitedAvailability`） */
  busy: boolean;
  /** 到期时间 ISO8601（'' = 永不过期） */
  expiresAt: string;
  /** 组织限定状态所属组织 id（'' = 公开可见）。changeUserStatus 是替换语义：写入时若不回传，
   *  GitHub 会把省略的 organizationId 视作「公开」，把组织内可见的状态改成全网可见 */
  organizationId: string;
}

/** 用户主页聚合数据 */
export interface UserProfile {
  user: UserSummary;
  userId: string;
  viewerLogin: string;
  company: string;
  location: string;
  websiteUrl: string;
  twitterUsername: string;
  /** 公开邮箱（用户未公开时 GraphQL 返回 null → ''） */
  email: string;
  /** 当前状态（Spec 076；未设置 / 接口未返回时为 null） */
  status: UserStatus | null;
  viewerIsFollowing: boolean;
  /** GitHub Developer Program 成员（true 时 Profile 显示 cpu 徽章行） */
  isDeveloperProgramMember: boolean;
  pinned: RepoSummary[];
  /** Popular 兜底（Spec 072）：star 降序前 6 个自有可见仓库，pinned 为空时 UI 消费 */
  popular: RepoSummary[];
  repositoriesCount: number;
  organizationsCount: number;
  starredCount: number;
  /** Sponsoring 行计数（Spec 073）：TA 作为 sponsor 的在效赞助数 */
  sponsoringCount: number;
  /** Projects 行计数（Spec 073）：Projects V2 数量 */
  projectsCount: number;
}

/** GraphQL UserProfile 响应 → UserProfile */
export function mapUserProfile(data: JsonMap): UserProfile {
  const viewer = Json.obj(data, 'viewer') ?? ({} as JsonMap);
  const userNode = Json.obj(data, 'user') ?? ({} as JsonMap);
  const status = Json.obj(userNode, 'status');
  const pinnedRaw = Json.obj(userNode, 'pinnedItems');
  const pinned: RepoSummary[] = [];
  if (pinnedRaw !== null) {
    for (const node of Json.arr(pinnedRaw, 'nodes')) {
      pinned.push(mapRepo(node as JsonMap));
    }
  }
  const popularRaw = Json.obj(userNode, 'popular');
  const popular: RepoSummary[] = [];
  if (popularRaw !== null) {
    for (const node of Json.arr(popularRaw, 'nodes')) {
      popular.push(mapRepo(node as JsonMap));
    }
  }
  const repositoriesRaw = Json.obj(userNode, 'repositories');
  const organizationsRaw = Json.obj(userNode, 'organizations');
  const starsRaw = Json.obj(userNode, 'starredRepositories');
  const sponsoringRaw = Json.obj(userNode, 'sponsorshipsAsSponsor');
  const projectsRaw = Json.obj(userNode, 'projectsV2');
  return {
    user: mapUser(userNode),
    userId: Json.str(userNode, 'id'),
    viewerLogin: Json.str(viewer, 'login'),
    company: Json.str(userNode, 'company'),
    location: Json.str(userNode, 'location'),
    websiteUrl: Json.str(userNode, 'websiteUrl'),
    twitterUsername: Json.str(userNode, 'twitterUsername'),
    email: Json.str(userNode, 'email'),
    status: status !== null ? mapUserStatus(status) : null,
    viewerIsFollowing: Json.bool(userNode, 'viewerIsFollowing'),
    isDeveloperProgramMember: Json.bool(userNode, 'isDeveloperProgramMember'),
    pinned: pinned,
    popular: popular,
    repositoriesCount: repositoriesRaw ? Json.num(repositoriesRaw, 'totalCount') : 0,
    organizationsCount: organizationsRaw ? Json.num(organizationsRaw, 'totalCount') : 0,
    starredCount: starsRaw ? Json.num(starsRaw, 'totalCount') : 0,
    sponsoringCount: sponsoringRaw ? Json.num(sponsoringRaw, 'totalCount') : 0,
    projectsCount: projectsRaw ? Json.num(projectsRaw, 'totalCount') : 0
  };
}

// ─── Spec 076：用户状态（读映射 + 到期档换算）───────────────────────

/** GitHub emoji CDN 基址（自定义 emoji 与短代码兜底共用） */
const EMOJI_CDN_BASE = 'https://github.githubassets.com/images/icons/emoji/';

/** 状态文案上限（GitHub 官方 80 字符） */
export const STATUS_MESSAGE_MAX = 80;

/** 到期档位 key，顺序即 Select Expiration 列表顺序（Spec 076 §二-C） */
export const STATUS_EXPIRY_KEYS: string[] = ['never', 'in30m', 'in1h', 'in4h', 'today', 'thisweek'];

/** 剥离 HTML 标签并反转义常见实体（emojiHTML 只有字形与图片两种形态） */
function htmlToText(html: string): string {
  return html.replace(/<[^>]*>/g, '')
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .trim();
}

/**
 * 状态 emoji → 可渲染形态（Spec 076 §七）：
 * 接口 `emoji` 返回短代码（`:dart:`），字形要从 `emojiHTML` 取——实测为 `<div>🎯</div>`，
 * 自定义 emoji 则是 `<img src="…githubassets…">`；两者皆空时按短代码拼 CDN 图兜底。
 */
export function parseStatusEmoji(emoji: string, emojiHtml: string): StatusEmoji {
  const src = /src="([^"]+)"/.exec(emojiHtml);
  if (src !== null) {
    return { text: '', image: src[1] };
  }
  const glyph = htmlToText(emojiHtml);
  if (glyph !== '' && !glyph.startsWith(':')) {
    return { text: glyph, image: '' };
  }
  const raw = emoji.trim();
  if (raw !== '' && !raw.startsWith(':')) {
    return { text: raw, image: '' };
  }
  const name = raw.replace(/:/g, '');
  return name !== '' ? { text: '', image: `${EMOJI_CDN_BASE}${name}.png?v8` } : { text: '', image: '' };
}

/** GraphQL UserStatus → UserStatus */
export function mapUserStatus(status: JsonMap): UserStatus {
  const emoji = Json.str(status, 'emoji');
  const organization = Json.obj(status, 'organization');
  return {
    emoji: parseStatusEmoji(emoji, Json.str(status, 'emojiHTML')),
    emojiRaw: emoji,
    message: Json.str(status, 'message'),
    busy: Json.bool(status, 'indicatesLimitedAvailability'),
    expiresAt: Json.str(status, 'expiresAt'),
    organizationId: organization !== null ? Json.str(organization, 'id') : ''
  };
}

/** 状态是否可见：文案或 emoji 任一存在即展示（emoji-only 状态同样成立） */
export function statusVisible(status: UserStatus | null): boolean {
  if (status === null) {
    return false;
  }
  return status.message !== '' || status.emoji.text !== '' || status.emoji.image !== '';
}

/** 剩余可输入字符数（输入框 maxLength 与计数同源） */
export function statusRemainingCount(message: string): number {
  const remaining = STATUS_MESSAGE_MAX - message.length;
  return remaining > 0 ? remaining : 0;
}

/** 本地当日 23:59:59.999 的毫秒数（dayOffset 天偏移，跨月由 Date 归一） */
function endOfLocalDayMs(nowMs: number, dayOffset: number = 0): number {
  const now = new Date(nowMs);
  return new Date(now.getFullYear(), now.getMonth(), now.getDate() + dayOffset, 23, 59, 59, 999).getTime();
}

/** 本周六 23:59:59.999；今天即周六时顺延一周，避免与 today 同刻。
 *  写入（expiryIsoOf）与读回（expiryKeyOf）共用，防止两侧算法漂移 */
function endOfLocalWeekMs(nowMs: number): number {
  let daysToSaturday = (6 - new Date(nowMs).getDay()) % 7;
  if (daysToSaturday === 0) {
    daysToSaturday = 7;
  }
  return endOfLocalDayMs(nowMs, daysToSaturday);
}

/** 档位 key → 到期 ISO8601（'' = 永不过期，提交时省略字段）；nowMs 注入便于单测 */
export function expiryIsoOf(key: string, nowMs: number): string {
  if (key === 'never') {
    return '';
  }
  if (key === 'in30m') {
    return new Date(nowMs + 30 * 60000).toISOString();
  }
  if (key === 'in1h') {
    return new Date(nowMs + 60 * 60000).toISOString();
  }
  if (key === 'in4h') {
    return new Date(nowMs + 240 * 60000).toISOString();
  }
  if (key === 'today') {
    return new Date(endOfLocalDayMs(nowMs)).toISOString();
  }
  // thisweek：本周六 23:59:59.999；今天即周六时顺延一周，避免与 today 同刻
  return new Date(endOfLocalWeekMs(nowMs)).toISOString();
}

/** 既有 expiresAt → 档位 key（回显归档；阈值 Spec 076 §七） */
export function expiryKeyOf(expiresAt: string, nowMs: number): string {
  if (expiresAt === '') {
    return 'never';
  }
  const at = Date.parse(expiresAt);
  if (Number.isNaN(at)) {
    return 'never';
  }
  const remaining = at - nowMs;
  if (remaining <= 0) {
    return 'never';
  }
  // 先认「日末 / 周末末」两个绝对时刻——expiryIsoOf 写的正是它们，属精确匹配。
  // 若先按时长分档，19:30 后今天日末只剩 <4.5 小时会被 in4h 抢走：「今天」整天误显为
  // IN 4 HOURS，且随后的 SAVE 会把真实到期时刻改写成 now+4h（2026-09-22 review 修复）
  if (at === endOfLocalDayMs(nowMs)) {
    return 'today';
  }
  if (at === endOfLocalWeekMs(nowMs)) {
    return 'thisweek';
  }
  // 外部设定的非日末时刻：按剩余时长归档
  if (remaining <= 45 * 60000) {
    return 'in30m';
  }
  if (remaining <= 150 * 60000) {
    return 'in1h';
  }
  if (remaining <= 270 * 60000) {
    return 'in4h';
  }
  return endOfLocalDayMs(nowMs) >= at ? 'today' : 'thisweek';
}

/** 自关注判断：viewer 与目标为同一账号时不展示 Follow 菜单（纯函数，便于单测） */
export function isSelfProfile(viewerLogin: string, targetLogin: string): boolean {
  return viewerLogin !== '' && viewerLogin === targetLogin;
}

// ─── Spec 034-037：用户/组织列表与组织主页 ───────────────────────────

/** 用户列表一页（followers/following） */
export interface UserListPage {
  users: UserSummary[];
  hasNextPage: boolean;
  endCursor: string;
}

/** 组织摘要（列表行） */
export interface OrgSummary {
  login: string;
  name: string;
  description: string;
  avatarUrl: string;
}

/** 组织列表一页 */
export interface OrgListPage {
  orgs: OrgSummary[];
  hasNextPage: boolean;
  endCursor: string;
}

/** 组织主页聚合数据 */
export interface OrgProfile {
  login: string;
  name: string;
  avatarUrl: string;
  description: string;
  websiteUrl: string;
  twitterUsername: string;
  email: string;
  pinned: RepoSummary[];
  repositoriesCount: number;
  readmeText: string;
  viewerIsFollowing: boolean;
}

/** 仓库列表一页（通用） */
export interface RepoListPage {
  repos: RepoSummary[];
  hasNextPage: boolean;
  endCursor: string;
}

/** GraphQL user.followers/following → UserListPage */
export function mapUserListPage(data: JsonMap, key: string): UserListPage {
  const userNode = Json.obj(data, 'user') ?? ({} as JsonMap);
  const conn = Json.obj(userNode, key) ?? ({} as JsonMap);
  const pageInfo = Json.obj(conn, 'pageInfo') ?? ({} as JsonMap);
  const users: UserSummary[] = [];
  for (const node of Json.arr(conn, 'nodes')) {
    users.push(mapUser(node as JsonMap));
  }
  return {
    users: users,
    hasNextPage: Json.bool(pageInfo, 'hasNextPage'),
    endCursor: Json.str(pageInfo, 'endCursor')
  };
}
