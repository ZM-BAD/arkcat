/**
 * 仪器测试：格式化工具与模型映射（纯函数）。
 * 运行于模拟器（aa test），与主代码同一编译单元，可直接 import main ets。
 */
import { describe, it, expect } from '@ohos/hypium';
import { relativeTime, contributionLevelColor, notificationTypeLabel } from '../../../main/ets/utils/Format';
import { Json } from '../../../main/ets/utils/Json';
import { mapUser, mapRepo, mapCalendar, mapHomeOverview, mapNotifications } from '../../../main/ets/models/GitHubModels';
import { buildNotificationsPath } from '../../../main/ets/services/NotificationsService';
import { buildTopicQuery } from '../../../main/ets/services/ExploreService';
import { mapSearchResult } from '../../../main/ets/models/ExploreModels';
import { mapUserProfile, isSelfProfile } from '../../../main/ets/models/ProfileModels';

type JsonMap = Record<string, Object>;

const NOW = Date.parse('2026-08-31T12:00:00Z');

export default function logicTest(testsuiteName: string) {
  describe(testsuiteName, () => {
    it('relativeTime_justNow', 0, () => {
      expect(relativeTime('2026-08-31T11:59:50Z', NOW)).assertEqual('刚刚');
    });
    it('relativeTime_minutes', 0, () => {
      expect(relativeTime('2026-08-31T11:55:00Z', NOW)).assertEqual('5 分钟前');
    });
    it('relativeTime_hours', 0, () => {
      expect(relativeTime('2026-08-31T09:00:00Z', NOW)).assertEqual('3 小时前');
    });
    it('relativeTime_days', 0, () => {
      expect(relativeTime('2026-08-29T12:00:00Z', NOW)).assertEqual('2 天前');
    });
    it('relativeTime_months', 0, () => {
      // 6/1 → 8/31 共 91 天，floor(91/30) = 3 个月
      expect(relativeTime('2026-06-01T12:00:00Z', NOW)).assertEqual('3 个月前');
    });
    it('relativeTime_invalid', 0, () => {
      expect(relativeTime('not-a-date', NOW)).assertEqual('');
    });

    it('contributionLevelColor_levels', 0, () => {
      expect(contributionLevelColor(0)).assertEqual('#EBEDF0');
      expect(contributionLevelColor(2)).assertEqual('#9BE9A8');
      expect(contributionLevelColor(5)).assertEqual('#40C463');
      expect(contributionLevelColor(9)).assertEqual('#30A14E');
      expect(contributionLevelColor(20)).assertEqual('#216E39');
    });

    it('notificationTypeLabel_mapping', 0, () => {
      expect(notificationTypeLabel('PullRequest')).assertEqual('PR');
      expect(notificationTypeLabel('Issue')).assertEqual('Issue');
      expect(notificationTypeLabel('SecurityAlert')).assertEqual('安全');
      expect(notificationTypeLabel('Whatever')).assertEqual('Whatever');
    });

    it('json_helpers_missingFields', 0, () => {
      const raw: JsonMap = { 'a': 'x', 'n': 3 };
      expect(Json.str(raw, 'a')).assertEqual('x');
      expect(Json.str(raw, 'missing', 'fb')).assertEqual('fb');
      expect(Json.num(raw, 'n')).assertEqual(3);
      expect(Json.num(raw, 'missing', 7)).assertEqual(7);
      expect(Json.obj(raw, 'missing')).assertNull();
      expect(Json.arr(raw, 'missing').length).assertEqual(0);
      expect(Json.parse('not json')).assertNull();
    });

    it('mapUser_basic', 0, () => {
      const followers: JsonMap = { 'totalCount': 12 };
      const following: JsonMap = { 'totalCount': 7 };
      const raw: JsonMap = {
        'login': 'zm_bad',
        'name': '周铭',
        'avatarUrl': 'https://avatars.example/u',
        'bio': 'hello',
        'followers': followers,
        'following': following
      };
      const user = mapUser(raw);
      expect(user.login).assertEqual('zm_bad');
      expect(user.name).assertEqual('周铭');
      expect(user.followers).assertEqual(12);
      expect(user.following).assertEqual(7);
    });

    it('mapRepo_languageFallback', 0, () => {
      const lang: JsonMap = { 'name': 'TypeScript', 'color': '#3178C6' };
      const raw: JsonMap = {
        'id': 'R_1',
        'nameWithOwner': 'a/b',
        'stargazerCount': 3,
        'forkCount': 1,
        'primaryLanguage': lang
      };
      const repo = mapRepo(raw);
      expect(repo.primaryLanguage).assertEqual('TypeScript');
      expect(repo.languageColor).assertEqual('#3178C6');
      expect(repo.stargazerCount).assertEqual(3);
    });

    it('mapCalendar_colorFallbackAndTotal', 0, () => {
      const day1: JsonMap = { 'date': '2026-08-30', 'contributionCount': 6, 'color': '' };
      const day2: JsonMap = { 'date': '2026-08-31', 'contributionCount': 1, 'color': '#40C463' };
      const week: JsonMap = { 'contributionDays': [day1, day2] };
      const raw: JsonMap = { 'totalContributions': 0, 'weeks': [week] };
      const calendar = mapCalendar(raw);
      // API color 缺失时按贡献数兜底：count=6 → 等级 4 色
      expect(calendar.weeks[0][0].color).assertEqual('#30A14E');
      expect(calendar.weeks[0][1].color).assertEqual('#40C463');
      // total 缺失时由 days 累加
      expect(calendar.totalContributions).assertEqual(7);
    });

    it('mapHomeOverview_endToEnd', 0, () => {
      const followers: JsonMap = { 'totalCount': 1 };
      const following: JsonMap = { 'totalCount': 2 };
      const repoNode: JsonMap = {
        'id': 'R_9',
        'nameWithOwner': 'zm_bad/starraft',
        'description': 'gh client',
        'stargazerCount': 2,
        'forkCount': 0
      };
      const pinned: JsonMap = { 'nodes': [repoNode] };
      const day: JsonMap = { 'date': '2026-08-31', 'contributionCount': 4, 'color': '#30A14E' };
      const week: JsonMap = { 'contributionDays': [day] };
      const calendar: JsonMap = { 'totalContributions': 4, 'weeks': [week] };
      const collection: JsonMap = { 'contributionCalendar': calendar };
      const viewer: JsonMap = {
        'login': 'zm_bad',
        'avatarUrl': 'u',
        'followers': followers,
        'following': following,
        'pinnedItems': pinned,
        'contributionsCollection': collection
      };
      const overview = mapHomeOverview({ 'viewer': viewer });
      expect(overview.user.login).assertEqual('zm_bad');
      expect(overview.pinned.length).assertEqual(1);
      expect(overview.pinned[0].nameWithOwner).assertEqual('zm_bad/starraft');
      expect(overview.calendar.totalContributions).assertEqual(4);
    });

    it('buildNotificationsPath_filter', 0, () => {
      expect(buildNotificationsPath(true, 30)).assertEqual('/notifications?all=true&per_page=30');
      expect(buildNotificationsPath(false, 1)).assertEqual('/notifications?all=false&per_page=1');
    });

    it('buildTopicQuery_and_mapSearchResult', 0, () => {
      expect(buildTopicQuery('harmonyos')).assertEqual('topic:harmonyos');
      const node1: JsonMap = { 'id': 'R1', 'nameWithOwner': 'a/b', 'stargazerCount': 5 };
      const node2: JsonMap = { 'id': 'R2', 'nameWithOwner': 'c/d', 'stargazerCount': 1 };
      const nodes: JsonMap[] = [node1, node2];
      const searchNode: JsonMap = { 'repositoryCount': 2, 'nodes': nodes };
      const result = mapSearchResult({ 'search': searchNode }, 'harmonyos');
      expect(result.topic).assertEqual('harmonyos');
      expect(result.repositoryCount).assertEqual(2);
      expect(result.repos.length).assertEqual(2);
      expect(result.repos[1].nameWithOwner).assertEqual('c/d');
    });

    it('mapUserProfile_and_selfCheck', 0, () => {
      const followers: JsonMap = { 'totalCount': 3 };
      const following: JsonMap = { 'totalCount': 4 };
      const status: JsonMap = { 'message': 'building', 'emoji': '🚀' };
      const repoNode: JsonMap = { 'id': 'R5', 'nameWithOwner': 'a/b', 'stargazerCount': 1 };
      const reposWrap: JsonMap = { 'nodes': [repoNode] };
      const userNode: JsonMap = {
        'id': 'U1',
        'login': 'zm_bad',
        'name': '周铭',
        'company': '@example',
        'location': 'SH',
        'websiteUrl': 'https://zmbad.me',
        'viewerIsFollowing': true,
        'status': status,
        'followers': followers,
        'following': following,
        'repositories': reposWrap,
        'starredRepositories': reposWrap
      };
      const viewer: JsonMap = { 'login': 'other' };
      const data: JsonMap = { 'viewer': viewer, 'user': userNode };
      const profile = mapUserProfile(data);
      expect(profile.user.login).assertEqual('zm_bad');
      expect(profile.viewerLogin).assertEqual('other');
      expect(profile.userId).assertEqual('U1');
      expect(profile.company).assertEqual('@example');
      expect(profile.statusEmoji).assertEqual('🚀');
      expect(profile.viewerIsFollowing).assertTrue();
      expect(profile.repos.length).assertEqual(1);
      expect(profile.stars.length).assertEqual(1);
      // 自关注判断
      expect(isSelfProfile('zm_bad', 'zm_bad')).assertTrue();
      expect(isSelfProfile('other', 'zm_bad')).assertFalse();
      expect(isSelfProfile('', 'zm_bad')).assertFalse();
    });

    it('mapNotifications_parseAndInvalid', 0, () => {
      expect(mapNotifications('[]').length).assertEqual(0);
      expect(mapNotifications('not json').length).assertEqual(0);
      const repo: JsonMap = { 'full_name': 'a/b' };
      const subject: JsonMap = { 'title': 'fix bug', 'type': 'Issue' };
      const item: JsonMap = {
        'id': 'T1',
        'repository': repo,
        'subject': subject,
        'reason': 'assign',
        'unread': true,
        'updated_at': '2026-08-30T00:00:00Z'
      };
      const list = mapNotifications(JSON.stringify([item]));
      expect(list.length).assertEqual(1);
      expect(list[0].repoFullName).assertEqual('a/b');
      expect(list[0].subjectType).assertEqual('Issue');
      expect(list[0].unread).assertTrue();
    });
  });
}
