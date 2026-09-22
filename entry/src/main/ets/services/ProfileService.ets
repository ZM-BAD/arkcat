/**
 * 用户主页服务（Spec 005）：GraphQL 主查询 + Follow/Unfollow mutation
 * + 用户状态写入（Spec 076：changeUserStatus 兼作清空）。
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
    status { message emoji emojiHTML indicatesLimitedAvailability expiresAt organization { id } }
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
    sponsorshipsAsSponsor { totalCount }
    projectsV2 { totalCount }
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

// 状态写入（Spec 076）：GraphQL 无独立清空 mutation——空 message 即清空，且**省略的字段一并清空**
// （设置类 mutation 的替换语义），故「永不过期」直接省略 expiresAt，不做 null 传参。
// limitedAvailability 走文档内字面量（布尔无转义面，且取自形参——仍是受控值，非裸内插）；
// 原写法声明 $limited、调用侧却传 variables 键 limitedAvailability，键名不符令 $limited 恒为
// null，Busy 从未落库（2026-09-22 实测）。字符串仍走 variables。
const SET_STATUS_MUTATION = (limited: boolean): string => `
mutation SetUserStatus($message: String!, $emoji: String, $expiresAt: DateTime) {
  changeUserStatus(input: {
    message: $message
    emoji: $emoji
    limitedAvailability: ${limited}
    expiresAt: $expiresAt
  }) {
    status { message emoji emojiHTML indicatesLimitedAvailability expiresAt }
  }
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

  /**
   * 写入状态（Spec 076）。空 message 即清空；emoji / expiresAt / organizationId 为空串时省略变量
   * （省略 = 清空该属性，见 SET_STATUS_MUTATION 注释）。
   * organizationId 必须由调用方回传既有值：省略即被 GitHub 视为公开，会把组织限定状态改成全网可见。
   */
  static async setStatus(token: string, message: string, emoji: string, busy: boolean,
    expiresAt: string, organizationId: string): Promise<void> {
    const variables: Record<string, Object> = {
      'message': message
    };
    if (emoji !== '') {
      variables['emoji'] = emoji;
    }
    if (expiresAt !== '') {
      variables['expiresAt'] = expiresAt;
    }
    if (organizationId !== '') {
      variables['organizationId'] = organizationId;
    }
    await graphql(SET_STATUS_MUTATION(busy), variables, token);
  }

  /** 清空状态：同 mutation 传空文案（organizationId 同样回传，避免误伤组织限定的清空目标） */
  static async clearStatus(token: string, organizationId: string): Promise<void> {
    await ProfileService.setStatus(token, '', '', false, '', organizationId);
  }
}
