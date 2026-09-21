/**
 * 通知服务：Spec 002。公网 GraphQL 无通知接口，全部走 REST Notifications API。
 * PullRequest 通知的 merged 状态 REST 不返回：从 subject.url 解析仓库+编号后，
 * 用单次 GraphQL 别名查询批量探测（merged 显示紫色 merge 图标，见 Inbox 卡片）。
 */
import { restGet, restPatch, restPut, restDelete, graphql } from './GitHttpClient';
import { aliasField, aliasQueryDocument, withFallback } from 'graphql';
import { mapNotifications, withPrMerged, NotificationItem } from '../models/GitHubModels';
import { Json, JsonMap } from '../utils/Json';

/**
 * 构造通知列表请求路径（纯函数，便于单测；Spec 002 四筛选）。
 * page 仅在 >1 时拼入，避免影响既有单测与首屏路径。
 */
export function buildNotificationsPath(all: boolean, perPage: number, participating: boolean = false,
  page: number = 1): string {
  const mode = participating ? `participating=${participating ? 'true' : 'false'}` : `all=${all ? 'true' : 'false'}`;
  const pagePart = page > 1 ? `&page=${page}` : '';
  return `/notifications?${mode}&per_page=${perPage}${pagePart}`;
}

/** PR 引用：属主/仓库名/编号（从 subject.url 解析） */
export interface PrRef {
  owner: string;
  name: string;
  number: number;
}

/** https://api.github.com/repos/{owner}/{name}/pulls/{n} → PrRef；非法返回 null */
export function pullRefFromUrl(url: string): PrRef | null {
  const m = /repos\/([^\/]+)\/([^\/]+)\/pulls\/([0-9]+)$/.exec(url);
  if (m === null || m[1] === undefined || m[2] === undefined || m[3] === undefined) {
    return null;
  }
  return { owner: m[1], name: m[2], number: parseInt(m[3], 10) };
}

/** 单请求多 alias：每个 PR 一个 t{i}: repository(...){issueOrPullRequest(...)}（owner/name 经库内转义） */
export function buildPullStatesQuery(refs: PrRef[]): string {
  const parts: string[] = [];
  for (let i = 0; i < refs.length; i++) {
    const ref = refs[i];
    parts.push(aliasField(`t${i}`, 'repository', [
      { 'name': 'owner', 'value': ref.owner },
      { 'name': 'name', 'value': ref.name }
    ], `issueOrPullRequest(number: ${ref.number}) { ... on PullRequest{ merged } ... on Issue{ state } }`));
  }
  return aliasQueryDocument('', parts);
}

/** 别名查询结果 → merged 布尔数组（与 refs 同序；节点缺失默认 false） */
export function mapPullMerged(data: JsonMap, count: number): boolean[] {
  const merged: boolean[] = [];
  for (let i = 0; i < count; i++) {
    // alias 即 repository 节点（查询形如 t{i}: repository(...){...}），直接取内层 issueOrPullRequest
    const alias = Json.obj(data, `t${i}`);
    const node = alias !== null ? Json.obj(alias, 'issueOrPullRequest') : null;
    merged.push(node !== null ? Json.bool(node, 'merged') : false);
  }
  return merged;
}

export class NotificationsService {
  /**
   * 拉取通知列表（Spec 002 四筛选）：
   * - all=true 含已读（Inbox▾）
   * - all=false 仅未读（Unread）
   * - participating=true 参与类高价值（Focused）
   */
  static async fetchNotifications(token: string, all: boolean, perPage: number = 50,
    participating: boolean = false, page: number = 1): Promise<NotificationItem[]> {
    const resp = await restGet(buildNotificationsPath(all, perPage, participating, page), token);
    const items = mapNotifications(resp.body);
    return NotificationsService.enrichPrMerged(token, items);
  }

  /** PR 合并态批量回填（单次 GraphQL）；失败静默保留默认 false（绿色 PR 图标） */
  static async enrichPrMerged(token: string, items: NotificationItem[]): Promise<NotificationItem[]> {
    const refs: (PrRef | null)[] = [];
    for (const item of items) {
      refs.push(item.subjectType === 'PullRequest' ? pullRefFromUrl(item.subjectUrl) : null);
    }
    const prRefs: PrRef[] = [];
    for (const ref of refs) {
      if (ref !== null) {
        prRefs.push(ref);
      }
    }
    if (prRefs.length === 0) {
      return items;
    }
    // merged 探测属展示增强：软失败为 null（=探测失败，条目原样返回）
    const merged: boolean[] | null = await withFallback(
      graphql(buildPullStatesQuery(prRefs), {} as Record<string, Object>, token)
        .then((data: JsonMap): boolean[] => mapPullMerged(data, prRefs.length)),
      null);
    if (merged === null) {
      return items;
    }
    // 按原顺序回填：仅 PR 条目被替换，非 PR 原样
    const result: NotificationItem[] = [];
    let k = 0;
    for (let i = 0; i < items.length; i++) {
      if (refs[i] !== null) {
        result.push(withPrMerged(items[i], merged[k]));
        k++;
      } else {
        result.push(items[i]);
      }
    }
    return result;
  }

  /**
   * 标记单个线程已读/未读（PATCH，幂等；Spec 045 多选 ● 钮）。
   * unread=false 标已读（官方默认语义，兼容 002 单条已读）；unread=true 标回未读。
   */
  static async markThreadRead(token: string, threadId: string, unread: boolean = false): Promise<void> {
    await restPatch(`/notifications/threads/${threadId}`, token, `{"unread": ${unread}}`);
  }

  /** 标记单个线程 Done（DELETE；Done 通知不再出现在默认 Inbox，Spec 045 ✓/左滑） */
  static async markThreadDone(token: string, threadId: string): Promise<void> {
    await restDelete(`/notifications/threads/${threadId}`, token);
  }

  /** 退订单个线程（DELETE subscription；仅停止后续通知，不影响已有列表，Spec 045 右滑） */
  static async unsubscribeThread(token: string, threadId: string): Promise<void> {
    await restDelete(`/notifications/threads/${threadId}/subscription`, token);
  }

  /** 全部通知标已读（PUT；多选全选 + ● 的单发优化路径，Spec 045） */
  static async markAllRead(token: string): Promise<void> {
    await restPut('/notifications', token);
  }

  /** release 数字 id → tagName（Spec 045 tap 跳 ReleaseDetail；release 不存在/网络失败返回空串） */
  static async fetchReleaseTag(token: string, owner: string, name: string, releaseId: number): Promise<string> {
    try {
      const resp = await restGet(`/repos/${owner}/${name}/releases/${releaseId}`, token);
      const item = JSON.parse(resp.body) as JsonMap;
      return Json.str(item, 'tag_name');
    } catch (e) {
      return '';
    }
  }
}

// ────────────────────────── Inbox 筛选面板（本地过滤） ──────────────────────────
// REST /notifications 不提供 reason 查询参数：面板第二组类型在客户端按
// 通知对象 reason 字段匹配；参数字面值以官方「reason:」查询语法为准。

/** 通知类型键（Inbox 筛选面板第二组；participating 为参与类并集） */
export type InboxReasonKey = 'assign' | 'participating' | 'mention' | 'team_mention' | 'review_requested';

/** 类型键 → REST reason 字段匹配；Participating=comment/subscribed/author/mention/team_mention 并集 */
export function reasonKeyMatches(key: InboxReasonKey, reason: string): boolean {
  switch (key) {
    case 'assign':
      return reason === 'assign';
    case 'mention':
      return reason === 'mention';
    case 'team_mention':
      return reason === 'team_mention';
    case 'review_requested':
      return reason === 'review_requested';
    case 'participating':
      return reason === 'comment' || reason === 'subscribed' || reason === 'author' ||
        reason === 'mention' || reason === 'team_mention';
    default:
      return false;
  }
}

/** 类型多选过滤：任一选中键命中即保留（并集）；空选=全量 */
export function filterByReasons(items: NotificationItem[], keys: InboxReasonKey[]): NotificationItem[] {
  if (keys.length === 0) {
    return items;
  }
  return items.filter((it: NotificationItem) => keys.some((k: InboxReasonKey) => reasonKeyMatches(k, it.reason)));
}

/**
 * 视图过滤（第一组）：Inbox=全部；Done=已读（旧版已读≈已完成）；
 * Saved=本地保存标记，REST 无该状态且暂无保存入口 → 空视图。
 */
export function filterByInboxView(items: NotificationItem[], view: string): NotificationItem[] {
  if (view === 'done') {
    return items.filter((it: NotificationItem) => !it.unread);
  }
  if (view === 'saved') {
    return [];
  }
  return items;
}

/** 仓库筛选候选：名称 + 该仓库最新通知的属主头像 + 全量计数（rawItems 聚合，稳定不随视图变化） */
export interface InboxRepoFilterItem {
  fullName: string;
  avatarUrl: string;
  count: number;
}

/** 从通知列表聚合仓库筛选候选（保持首次出现顺序，纯函数便于单测） */
export function collectRepoFilters(items: NotificationItem[]): InboxRepoFilterItem[] {
  const out: InboxRepoFilterItem[] = [];
  for (const it of items) {
    const found = out.find((r: InboxRepoFilterItem) => r.fullName === it.repoFullName);
    if (found === undefined) {
      out.push({ fullName: it.repoFullName, avatarUrl: it.ownerAvatarUrl, count: 1 });
    } else {
      found.count++;
      if (found.avatarUrl === '' && it.ownerAvatarUrl !== '') {
        found.avatarUrl = it.ownerAvatarUrl;
      }
    }
  }
  return out;
}
