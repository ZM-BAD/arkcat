/**
 * Home 页数据服务：Spec 001 的 GraphQL 主查询 + 通知角标 REST 兜底。
 */
import { graphql, restGet } from './GitHttpClient';
import { HomeOverview, mapHomeOverview } from '../models/GitHubModels';

const HOME_QUERY = `
query HomePage {
  viewer {
    avatarUrl
    login
    name
    bio
    followers { totalCount }
    following { totalCount }
    status { message emoji }
    pinnedItems(first: 6, types: [REPOSITORY]) {
      nodes {
        ... on Repository {
          id
          nameWithOwner
          description
          stargazerCount
          forkCount
          primaryLanguage { name color }
        }
      }
    }
    contributionsCollection {
      contributionCalendar {
        totalContributions
        weeks { contributionDays { date contributionCount color } }
      }
    }
  }
}`;

export class HomeService {
  /** 拉取 Home 页聚合数据（用户卡片 + 贡献日历 + Pinned） */
  static async fetchHomeOverview(token: string): Promise<HomeOverview> {
    const data = await graphql(HOME_QUERY, null, token);
    return mapHomeOverview(data);
  }

  /**
   * 未读通知角标。
   * 公网 GraphQL 无 notificationThreads，按 Spec 001 用 REST /notifications?per_page=1 兜底：
   * 返回非空数组即视为有未读（角标显示 1+）。
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
