/**
 * 通知服务：Spec 002。公网 GraphQL 无通知接口，全部走 REST Notifications API。
 * PullRequest 通知的 merged 状态 REST 不返回：从 subject.url 解析仓库+编号后，
 * 用单次 GraphQL 别名查询批量探测（merged 显示紫色 merge 图标，见 Inbox 卡片）。
 */
import { restGet, restPatch, graphql } from './GitHttpClient';
import { mapNotifications, withPrMerged, NotificationItem } from '../models/GitHubModels';
import { Json, JsonMap } from '../utils/Json';

/** 构造通知列表请求路径（纯函数，便于单测；Spec 002 四筛选） */
export function buildNotificationsPath(all: boolean, perPage: number, participating: boolean = false): string {
  const mode = participating ? `participating=${participating ? 'true' : 'false'}` : `all=${all ? 'true' : 'false'}`;
  return `/notifications?${mode}&per_page=${perPage}`;
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

/** 单请求多 alias：每个 PR 一个 t{i}: repository(...){issueOrPullRequest(...)} */
export function buildPullStatesQuery(refs: PrRef[]): string {
  let fields = '';
  for (let i = 0; i < refs.length; i++) {
    const ref = refs[i];
    fields += `t${i}:repository(owner:"${ref.owner}", name:"${ref.name}")` +
      `{ issueOrPullRequest(number:${ref.number}){ ... on PullRequest{ merged } ... on Issue{ state } } }\n`;
  }
  return `query {\n${fields}}`;
}

/** 别名查询结果 → merged 布尔数组（与 refs 同序；节点缺失默认 false） */
export function mapPullMerged(data: JsonMap, count: number): boolean[] {
  const merged: boolean[] = [];
  for (let i = 0; i < count; i++) {
    const alias = Json.obj(data, `t${i}`);
    const repo = alias !== null ? Json.obj(alias, 'repository') : null;
    const node = repo !== null ? Json.obj(repo, 'issueOrPullRequest') : null;
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
  static async fetchNotifications(token: string, all: boolean, perPage: number = 30,
    participating: boolean = false): Promise<NotificationItem[]> {
    const resp = await restGet(buildNotificationsPath(all, perPage, participating), token);
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
    let merged: boolean[] = [];
    try {
      const data = await graphql(buildPullStatesQuery(prRefs), {} as Record<string, Object>, token);
      merged = mapPullMerged(data, prRefs.length);
    } catch (e) {
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

  /** 标记单个线程已读（PATCH，幂等） */
  static async markThreadRead(token: string, threadId: string): Promise<void> {
    await restPatch(`/notifications/threads/${threadId}`, token);
  }
}
