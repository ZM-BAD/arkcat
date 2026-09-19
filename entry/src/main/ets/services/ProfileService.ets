/**
 * 用户主页服务（Spec 005）：GraphQL 主查询 + Follow/Unfollow mutation。
 * Packages Tab 无公开 API 不展示；Projects 按边界跳过。
 */
import { graphql } from './GitHttpClient';
import { withFallback } from 'graphql';
import { Json, JsonMap } from '../utils/Json';
import { UserProfile, mapUserProfile } from '../models/ProfileModels';
import { FRAG_VIEWER_LOGIN } from './GqlFragments';

const PROFILE_QUERY = `
query UserProfile($login: String!) {
  ${FRAG_VIEWER_LOGIN}
  user(login: $login) {
    id
    avatarUrl
    name
    login
    bio
    company
    location
    websiteUrl
    email
    twitterUsername
    viewerIsFollowing
    isDeveloperProgramMember
    status { message emoji }
    followers { totalCount }
    following { totalCount }
    pinnedItems(first: 6, types: [REPOSITORY]) {
      nodes { ... on Repository {
        id name nameWithOwner description stargazerCount forkCount
        owner { login avatarUrl }
        primaryLanguage { name color }
      } }
    }
    popular: repositories(first: 6, ownerAffiliations: OWNER, orderBy: {field: STARGAZERS, direction: DESC}) {
      nodes { ... on Repository {
        id name nameWithOwner description stargazerCount forkCount
        owner { login avatarUrl }
        primaryLanguage { name color }
      } }
    }
    repositories { totalCount }
    starredRepositories { totalCount }
  }
}`;

// 组织计数独立查询（review G8）：organizations 受 read:org 门控，
// 混入主查询会让任一用户主页整页报错；失败静默置 0 与 Spec 022 策略一致
const ORG_COUNT_QUERY = `
query OrgCount($login: String!) {
  user(login: $login) {
    organizations { totalCount }
  }
}`;

const FOLLOW_MUTATION = `
mutation FollowUser($userId: ID!) {
  followUser(input: { userId: $userId }) { clientMutationId }
}`;

const UNFOLLOW_MUTATION = `
mutation UnfollowUser($userId: ID!) {
  unfollowUser(input: { userId: $userId }) { clientMutationId }
}`;

export class ProfileService {
  /** 拉取用户主页聚合数据 */
  static async fetchProfile(token: string, login: string): Promise<UserProfile> {
    const variables: Record<string, Object> = { 'login': login };
    const data = await graphql(PROFILE_QUERY, variables, token);
    return mapUserProfile(data);
  }

  /** 组织计数独立查询（review G8）：失败/缺 scope 置 0，不阻塞主页 */
  static async fetchOrgCount(token: string, login: string): Promise<number> {
    // 装饰性计数：软失败为 0（badge 不显示），不阻断 Profile 主查询
    return withFallback(ProfileService.fetchOrgCountRaw(token, login), 0);
  }

  private static async fetchOrgCountRaw(token: string, login: string): Promise<number> {
    const variables: Record<string, Object> = { 'login': login };
    const data = await graphql(ORG_COUNT_QUERY, variables, token);
    const user = Json.obj(data, 'user') ?? ({} as JsonMap);
    const orgs = Json.obj(user, 'organizations') ?? ({} as JsonMap);
    return Json.num(orgs, 'totalCount');
  }

  /** Follow/Unfollow；返回操作后的目标关注态 */
  static async setFollowing(token: string, userId: string, follow: boolean): Promise<boolean> {
    const variables: Record<string, Object> = { 'userId': userId };
    await graphql(follow ? FOLLOW_MUTATION : UNFOLLOW_MUTATION, variables, token);
    return follow;
  }
}
