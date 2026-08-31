/**
 * 用户主页服务（Spec 005）：GraphQL 主查询 + Follow/Unfollow mutation。
 * Packages Tab 无公开 API 不展示；Projects 按边界跳过。
 */
import { graphql } from './GitHttpClient';
import { UserProfile, mapUserProfile } from '../models/ProfileModels';

const PROFILE_QUERY = `
query UserProfile($login: String!) {
  viewer { login }
  user(login: $login) {
    id
    avatarUrl
    name
    login
    bio
    company
    location
    websiteUrl
    twitterUsername
    viewerIsFollowing
    status { message emoji }
    followers { totalCount }
    following { totalCount }
    pinnedItems(first: 6, types: [REPOSITORY]) {
      nodes { ... on Repository {
        id nameWithOwner description stargazerCount forkCount
        primaryLanguage { name color }
      } }
    }
    contributionsCollection {
      contributionCalendar {
        totalContributions
        weeks { contributionDays { date contributionCount color } }
      }
    }
    repositories(first: 30, orderBy: { field: UPDATED_AT, direction: DESC }) {
      totalCount
      nodes { ... on Repository {
        id nameWithOwner description stargazerCount forkCount
        primaryLanguage { name color }
      } }
    }
    starredRepositories(first: 30) {
      totalCount
      nodes { ... on Repository {
        id nameWithOwner description stargazerCount forkCount
        primaryLanguage { name color }
      } }
    }
    organizations(first: 30) { totalCount }
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

  /** Follow/Unfollow；返回操作后的目标关注态 */
  static async setFollowing(token: string, userId: string, follow: boolean): Promise<boolean> {
    const variables: Record<string, Object> = { 'userId': userId };
    await graphql(follow ? FOLLOW_MUTATION : UNFOLLOW_MUTATION, variables, token);
    return follow;
  }
}
