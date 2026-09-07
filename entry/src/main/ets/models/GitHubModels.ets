/**
 * GitHub 数据模型（首页相关）与 GraphQL/REST 响应映射。
 *
 * 模型保持纯数据接口；映射函数集中在此，便于单元测试。
 */
import { Json, JsonMap } from '../utils/Json';

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
  name: string;
  nameWithOwner: string;
  description: string;
  stargazerCount: number;
  forkCount: number;
  primaryLanguage: string;
  languageColor: string;
  isPrivate: boolean;
  /** 仓库属主（Pinned 卡片头像/用户名；查询未带 owner 时为 ''） */
  ownerLogin: string;
  ownerAvatarUrl: string;
  /** GraphQL 节点 id（Star mutation 与星标列表成员判断；REST 兜底取 node_id） */
  graphqlId: string;
  /** 仓库社交横幅图（StarRaft Trending 卡顶部大图；无自定义预览为 ''） */
  openGraphImageUrl: string;
  /** viewer 是否已 Star（Trending 卡三态按钮） */
  viewerHasStarred: boolean;
  /** 贡献者总数（REST /contributors Link last 页近似；未加载为 0） */
  contributorCount: number;
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
  /** 仓库属主头像（REST repository.owner.avatar_url；缺失为 ''） */
  ownerAvatarUrl: string;
  /** PullRequest 是否已合并（GraphQL 批量探测；默认为 false 保持绿色 PR） */
  prMerged: boolean;
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
  const owner = Json.obj(raw, 'owner');
  return {
    id: Json.str(raw, 'id'),
    name: Json.str(raw, 'name'),
    nameWithOwner: Json.str(raw, 'nameWithOwner'),
    description: Json.str(raw, 'description'),
    stargazerCount: Json.num(raw, 'stargazerCount'),
    forkCount: Json.num(raw, 'forkCount'),
    primaryLanguage: language,
    languageColor: languageColor,
    isPrivate: Json.bool(raw, 'isPrivate'),
    ownerLogin: owner !== null ? Json.str(owner, 'login') : '',
    ownerAvatarUrl: owner !== null ? Json.str(owner, 'avatarUrl') : '',
    // GraphQL 语义：id 即节点 id；meta 字段随查询可选缺失（缺省空/false）
    graphqlId: Json.str(raw, 'id'),
    openGraphImageUrl: Json.str(raw, 'openGraphImageUrl'),
    viewerHasStarred: Json.bool(raw, 'viewerHasStarred'),
    contributorCount: 0
  };
}

/** REST /notifications 数组元素 → NotificationItem */
export function mapNotification(raw: JsonMap): NotificationItem {
  const repo = Json.obj(raw, 'repository');
  const subject = Json.obj(raw, 'subject');
  const owner = repo !== null ? Json.obj(repo, 'owner') : null;
  return {
    threadId: Json.str(raw, 'id'),
    repoFullName: repo ? Json.str(repo, 'full_name') : '',
    title: subject ? Json.str(subject, 'title') : '',
    subjectType: subject ? Json.str(subject, 'type') : '',
    reason: Json.str(raw, 'reason'),
    unread: Json.bool(raw, 'unread'),
    updatedAt: Json.str(raw, 'updated_at'),
    subjectUrl: subject ? Json.str(subject, 'url') : '',
    ownerAvatarUrl: owner !== null ? Json.str(owner, 'avatar_url') : '',
    prMerged: false
  };
}

/** 拷贝通知并替换合并态（GraphQL 批量探测回填用，避免动态属性） */
export function withPrMerged(item: NotificationItem, merged: boolean): NotificationItem {
  return {
    threadId: item.threadId,
    repoFullName: item.repoFullName,
    title: item.title,
    subjectType: item.subjectType,
    reason: item.reason,
    unread: item.unread,
    updatedAt: item.updatedAt,
    subjectUrl: item.subjectUrl,
    ownerAvatarUrl: item.ownerAvatarUrl,
    prMerged: merged
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
