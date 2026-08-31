/**
 * GitHub 数据模型（首页相关）与 GraphQL/REST 响应映射。
 *
 * 模型保持纯数据接口；映射函数集中在此，便于单元测试。
 */
import { Json, JsonMap } from '../utils/Json';
import { contributionLevelColor } from '../utils/Format';

/** 用户摘要（Home 卡片 / 列表作者行通用） */
export interface UserSummary {
  login: string;
  name: string;
  avatarUrl: string;
  bio: string;
  followers: number;
  following: number;
}

/** 查看者基础信息（Spec 013：Home Header 头像/名字） */
export interface ViewerBasic {
  login: string;
  name: string;
  avatarUrl: string;
}

/** GraphQL viewer 基础节点 → ViewerBasic */
export function mapViewerBasic(raw: JsonMap): ViewerBasic {
  return {
    login: Json.str(raw, 'login'),
    name: Json.str(raw, 'name'),
    avatarUrl: Json.str(raw, 'avatarUrl')
  };
}

/** 仓库摘要卡片 */
export interface RepoSummary {
  id: string;
  nameWithOwner: string;
  description: string;
  stargazerCount: number;
  forkCount: number;
  primaryLanguage: string;
  languageColor: string;
}

/** 单个贡献日的展示模型（count + 颜色） */
export interface ContributionDay {
  date: string;
  count: number;
  color: string;
}

/** 贡献日历：周为列，一周内 7 天 */
export interface ContributionCalendar {
  totalContributions: number;
  weeks: ContributionDay[][];
}

/** 通知条目（REST /notifications） */
export interface NotificationItem {
  threadId: string;
  repoFullName: string;
  title: string;
  subjectType: string;
  reason: string;
  unread: boolean;
  updatedAt: string;
  subjectUrl: string;
}

/**
 * 从 subject.url 提取 Issue/PR 编号（纯函数，Spec 002 卡片编号行）。
 * 支持完整 URL（https://api.github.com/repos/a/b/issues/82）与相对路径（/repos/a/b/pull/456）。
 * 匹配 /issues/<n>、/pull/<n>、/discussions/<n>、/releases/<n>；无匹配返回''。
 */
export function issueNumberFromUrl(url: string): string {
  const m = /\/(?:issues|pull|commit|discussions|releases)\/([0-9]+)(?:\/|$)/.exec(url);
  if (m !== null && m[1] !== undefined) {
    return m[1];
  }
  return '';
}

/** GraphQL viewer 响应 → UserSummary */
export function mapUser(raw: JsonMap): UserSummary {
  const followersObj = Json.obj(raw, 'followers');
  const followingObj = Json.obj(raw, 'following');
  return {
    login: Json.str(raw, 'login'),
    name: Json.str(raw, 'name'),
    avatarUrl: Json.str(raw, 'avatarUrl'),
    bio: Json.str(raw, 'bio'),
    followers: followersObj ? Json.num(followersObj, 'totalCount') : 0,
    following: followingObj ? Json.num(followingObj, 'totalCount') : 0
  };
}

/** GraphQL Repository 节点 → RepoSummary */
export function mapRepo(raw: JsonMap): RepoSummary {
  let language = '';
  let languageColor = '';
  const langObj = Json.obj(raw, 'primaryLanguage');
  if (langObj !== null) {
    language = Json.str(langObj, 'name');
    languageColor = Json.str(langObj, 'color');
  }
  return {
    id: Json.str(raw, 'id'),
    nameWithOwner: Json.str(raw, 'nameWithOwner'),
    description: Json.str(raw, 'description'),
    stargazerCount: Json.num(raw, 'stargazerCount'),
    forkCount: Json.num(raw, 'forkCount'),
    primaryLanguage: language,
    languageColor: languageColor
  };
}

/** GraphQL contributionCalendar → ContributionCalendar（含颜色兜底） */
export function mapCalendar(raw: JsonMap): ContributionCalendar {
  const weeks: ContributionDay[][] = [];
  const weekArr = Json.arr(raw, 'weeks');
  let total = Json.num(raw, 'totalContributions');
  for (const weekItem of weekArr) {
    const days: ContributionDay[] = [];
    const week = weekItem as JsonMap;
    for (const dayItem of Json.arr(week, 'contributionDays')) {
      const day = dayItem as JsonMap;
      const count = Json.num(day, 'contributionCount');
      // API 返回 color 为空时按贡献数兜底着色
      let color = Json.str(day, 'color');
      if (color === '') {
        color = contributionLevelColor(count);
      }
      days.push({ date: Json.str(day, 'date'), count: count, color: color });
    }
    weeks.push(days);
  }
  if (total === 0) {
    for (const week of weeks) {
      for (const day of week) {
        total += day.count;
      }
    }
  }
  return { totalContributions: total, weeks: weeks };
}

/** REST /notifications 数组元素 → NotificationItem */
export function mapNotification(raw: JsonMap): NotificationItem {
  const repo = Json.obj(raw, 'repository');
  const subject = Json.obj(raw, 'subject');
  return {
    threadId: Json.str(raw, 'id'),
    repoFullName: repo ? Json.str(repo, 'full_name') : '',
    title: subject ? Json.str(subject, 'title') : '',
    subjectType: subject ? Json.str(subject, 'type') : '',
    reason: Json.str(raw, 'reason'),
    unread: Json.bool(raw, 'unread'),
    updatedAt: Json.str(raw, 'updated_at'),
    subjectUrl: subject ? Json.str(subject, 'url') : ''
  };
}

/** REST /notifications 响应文本 → NotificationItem[] */
export function mapNotifications(text: string): NotificationItem[] {
  try {
    const parsed: Object | null = JSON.parse(text);
    if (!Array.isArray(parsed)) {
      return [];
    }
    const items: NotificationItem[] = [];
    for (const raw of parsed as Object[]) {
      items.push(mapNotification(raw as JsonMap));
    }
    return items;
  } catch (e) {
    return [];
  }
}
