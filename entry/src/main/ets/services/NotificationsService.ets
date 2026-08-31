/**
 * 通知服务：Spec 002。公网 GraphQL 无通知接口，全部走 REST Notifications API。
 */
import { restGet, restPatch } from './GitHttpClient';
import { mapNotifications, NotificationItem } from '../models/GitHubModels';

/** 构造通知列表请求路径（纯函数，便于单测；Spec 002 四筛选） */
export function buildNotificationsPath(all: boolean, perPage: number, participating: boolean = false): string {
  const mode = participating ? `participating=${participating ? 'true' : 'false'}` : `all=${all ? 'true' : 'false'}`;
  return `/notifications?${mode}&per_page=${perPage}`;
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
    return mapNotifications(resp.body);
  }

  /** 标记单个线程已读（PATCH，幂等） */
  static async markThreadRead(token: string, threadId: string): Promise<void> {
    await restPatch(`/notifications/threads/${threadId}`, token);
  }
}
