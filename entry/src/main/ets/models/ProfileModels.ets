/**
 * 用户主页数据模型与映射（Spec 005）。
 */
import { Json, JsonMap } from '../utils/Json';
import { RepoSummary, UserSummary, mapRepo, mapUser } from './GitHubModels';
import { ContributionCalendar, mapCalendar } from './GitHubModels';

/** 用户主页聚合数据 */
export interface UserProfile {
  user: UserSummary;
  userId: string;
  viewerLogin: string;
  company: string;
  location: string;
  websiteUrl: string;
  twitterUsername: string;
  statusEmoji: string;
  statusMessage: string;
  viewerIsFollowing: boolean;
  calendar: ContributionCalendar;
  pinned: RepoSummary[];
  repos: RepoSummary[];
  stars: RepoSummary[];
  repositoriesCount: number;
  organizationsCount: number;
  starredCount: number;
}

/** GraphQL UserProfile 响应 → UserProfile */
export function mapUserProfile(data: JsonMap): UserProfile {
  const viewer = Json.obj(data, 'viewer') ?? ({} as JsonMap);
  const userNode = Json.obj(data, 'user') ?? ({} as JsonMap);
  const status = Json.obj(userNode, 'status');
  const collection = Json.obj(Json.obj(userNode, 'contributionsCollection') ?? ({} as JsonMap), 'contributionCalendar');
  const pinnedRaw = Json.obj(userNode, 'pinnedItems');
  const pinned: RepoSummary[] = [];
  if (pinnedRaw !== null) {
    for (const node of Json.arr(pinnedRaw, 'nodes')) {
      pinned.push(mapRepo(node as JsonMap));
    }
  }
  const reposRaw = Json.obj(userNode, 'repositories');
  const repos: RepoSummary[] = [];
  if (reposRaw !== null) {
    for (const node of Json.arr(reposRaw, 'nodes')) {
      repos.push(mapRepo(node as JsonMap));
    }
  }
  const starsRaw = Json.obj(userNode, 'starredRepositories');
  const stars: RepoSummary[] = [];
  if (starsRaw !== null) {
    for (const node of Json.arr(starsRaw, 'nodes')) {
      stars.push(mapRepo(node as JsonMap));
    }
  }
  const repositoriesRaw = Json.obj(userNode, 'repositories');
  const organizationsRaw = Json.obj(userNode, 'organizations');
  return {
    user: mapUser(userNode),
    userId: Json.str(userNode, 'id'),
    viewerLogin: Json.str(viewer, 'login'),
    company: Json.str(userNode, 'company'),
    location: Json.str(userNode, 'location'),
    websiteUrl: Json.str(userNode, 'websiteUrl'),
    twitterUsername: Json.str(userNode, 'twitterUsername'),
    statusEmoji: status ? Json.str(status, 'emoji') : '',
    statusMessage: status ? Json.str(status, 'message') : '',
    viewerIsFollowing: Json.bool(userNode, 'viewerIsFollowing'),
    calendar: mapCalendar(collection ?? ({} as JsonMap)),
    pinned: pinned,
    repos: repos,
    stars: stars,
    repositoriesCount: repositoriesRaw ? Json.num(repositoriesRaw, 'totalCount') : 0,
    organizationsCount: organizationsRaw ? Json.num(organizationsRaw, 'totalCount') : 0,
    starredCount: starsRaw ? Json.num(starsRaw, 'totalCount') : 0
  };
}

/** 自关注判断：viewer 与目标为同一账号时不展示 Follow 菜单（纯函数，便于单测） */
export function isSelfProfile(viewerLogin: string, targetLogin: string): boolean {
  return viewerLogin !== '' && viewerLogin === targetLogin;
}
