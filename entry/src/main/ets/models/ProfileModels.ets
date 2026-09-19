/**
 * 用户主页数据模型与映射（Spec 005）+ 用户/组织列表与组织主页模型（Spec 034-037）。
 */
import { Json, JsonMap } from '../utils/Json';
import { RepoSummary, UserSummary, mapRepo, mapUser } from './GitHubModels';

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
  statusEmoji: string;
  statusMessage: string;
  viewerIsFollowing: boolean;
  /** GitHub Developer Program 成员（true 时 Profile 显示 cpu 徽章行） */
  isDeveloperProgramMember: boolean;
  pinned: RepoSummary[];
  /** Popular 兜底（Spec 072）：star 降序前 6 个自有可见仓库，pinned 为空时 UI 消费 */
  popular: RepoSummary[];
  repositoriesCount: number;
  organizationsCount: number;
  starredCount: number;
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
  return {
    user: mapUser(userNode),
    userId: Json.str(userNode, 'id'),
    viewerLogin: Json.str(viewer, 'login'),
    company: Json.str(userNode, 'company'),
    location: Json.str(userNode, 'location'),
    websiteUrl: Json.str(userNode, 'websiteUrl'),
    twitterUsername: Json.str(userNode, 'twitterUsername'),
    email: Json.str(userNode, 'email'),
    statusEmoji: status ? Json.str(status, 'emoji') : '',
    statusMessage: status ? Json.str(status, 'message') : '',
    viewerIsFollowing: Json.bool(userNode, 'viewerIsFollowing'),
    isDeveloperProgramMember: Json.bool(userNode, 'isDeveloperProgramMember'),
    pinned: pinned,
    popular: popular,
    repositoriesCount: repositoriesRaw ? Json.num(repositoriesRaw, 'totalCount') : 0,
    organizationsCount: organizationsRaw ? Json.num(organizationsRaw, 'totalCount') : 0,
    starredCount: starsRaw ? Json.num(starsRaw, 'totalCount') : 0
  };
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
