/**
 * 通知服务：Spec 002。公网 GraphQL 无通知接口，全部走 REST Notifications API。
 */
import { restGet, restPatch } from './GitHttpClient';
import { mapNotifications, NotificationItem } from '../models/GitHubModels';

/** 构造通知列表请求路径（纯函数，便于单测） */
export function buildNotificationsPath(all: boolean, perPage: number): string {
  return `/notifications?all=${all ? 'true' : 'false'}&per_page=${perPage}`;
}

export class NotificationsService {
  /** 拉取通知列表；all=true 含已读，false 仅未读 */
  static async fetchNotifications(token: string, all: boolean, perPage: number = 30): Promise<NotificationItem[]> {
    const resp = await restGet(buildNotificationsPath(all, perPage), token);
    return mapNotifications(resp.body);
  }

  /** 标记单个线程已读（PATCH，幂等） */
  static async markThreadRead(token: string, threadId: string): Promise<void> {
    await restPatch(`/notifications/threads/${threadId}`, token);
  }
}
