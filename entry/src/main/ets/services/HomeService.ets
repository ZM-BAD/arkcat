/**
 * Home 页数据服务：Spec 013 的 viewer 基础查询 + 通知角标 REST 兜底。
 */
import { graphql, restGet } from './GitHttpClient';
import { Json, JsonMap } from '../utils/Json';
import { ViewerBasic, mapViewerBasic } from '../models/GitHubModels';

const VIEWER_BASIC_QUERY = `
query ViewerBasic {
  viewer {
    login
    name
    avatarUrl
  }
}`;

export class HomeService {
  /** 拉取查看者基础信息（Home Header 头像/名字） */
  static async fetchViewerBasic(token: string): Promise<ViewerBasic> {
    const data = await graphql(VIEWER_BASIC_QUERY, null, token);
    const viewer = Json.obj(data, 'viewer') ?? ({} as JsonMap);
    return mapViewerBasic(viewer);
  }

  /**
   * 未读通知角标。
   * 公网 GraphQL 无 notificationThreads，按 Spec 013 用 REST /notifications?per_page=1 兜底：
   * 返回非空数组即视为有未读（Inbox Tab 显示蓝点）。
   */
  static async hasUnreadNotifications(token: string): Promise<boolean> {
    const resp = await restGet('/notifications?all=false&per_page=1', token);
    try {
      const parsed: Object | null = JSON.parse(resp.body);
      return Array.isArray(parsed) && (parsed as Object[]).length > 0;
    } catch (e) {
      return false;
    }
  }
}
