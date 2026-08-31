/**
 * 仪器测试：格式化工具与模型映射（纯函数）。
 * 运行于模拟器（aa test），与主代码同一编译单元，可直接 import main ets。
 */
import { describe, it, expect } from '@ohos/hypium';
import { timeParts, contributionLevelColor, notificationTypeKey } from '../../../main/ets/utils/Format';
import { Json } from '../../../main/ets/utils/Json';
import { mapUser, mapRepo, mapCalendar, mapViewerBasic, mapNotifications } from '../../../main/ets/models/GitHubModels';
import { buildNotificationsPath } from '../../../main/ets/services/NotificationsService';
import { buildTopicQuery } from '../../../main/ets/services/ExploreService';
import { mapSearchResult } from '../../../main/ets/models/ExploreModels';
import { mapUserProfile, isSelfProfile } from '../../../main/ets/models/ProfileModels';
import { mapRepoDetail, nextStarAction } from '../../../main/ets/models/RepoDetailModels';
import { mapIssue, mapIssuesPage, issueOrderField } from '../../../main/ets/models/IssuesModels';

type JsonMap = Record<string, Object>;

const NOW = Date.parse('2026-08-31T12:00:00Z');

export default function logicTest(testsuiteName: string) {
  describe(testsuiteName, () => {
    it('timeParts_justNow', 0, () => {
      const parts = timeParts('2026-08-31T11:59:50Z', NOW);
      expect(parts !== null).assertTrue();
      expect(parts?.value).assertEqual(0);
      expect(parts?.unit).assertEqual('just_now');
    });
    it('timeParts_minutes', 0, () => {
      const parts = timeParts('2026-08-31T11:55:00Z', NOW);
      expect(parts?.value).assertEqual(5);
      expect(parts?.unit).assertEqual('minute');
    });
    it('timeParts_hours', 0, () => {
      const parts = timeParts('2026-08-31T09:00:00Z', NOW);
      expect(parts?.value).assertEqual(3);
      expect(parts?.unit).assertEqual('hour');
    });
    it('timeParts_days', 0, () => {
      const parts = timeParts('2026-08-29T12:00:00Z', NOW);
      expect(parts?.value).assertEqual(2);
      expect(parts?.unit).assertEqual('day');
    });
    it('timeParts_months', 0, () => {
      // 6/1 → 8/31 共 91 天，floor(91/30) = 3 个月
      const parts = timeParts('2026-06-01T12:00:00Z', NOW);
      expect(parts?.value).assertEqual(3);
      expect(parts?.unit).assertEqual('month');
    });
    it('timeParts_invalid', 0, () => {
      expect(timeParts('not-a-date', NOW)).assertNull();
    });

    it('contributionLevelColor_levels', 0, () => {
      expect(contributionLevelColor(0)).assertEqual('#EBEDF0');
      expect(contributionLevelColor(2)).assertEqual('#9BE9A8');
      expect(contributionLevelColor(5)).assertEqual('#40C463');
      expect(contributionLevelColor(9)).assertEqual('#30A14E');
      expect(contributionLevelColor(20)).assertEqual('#216E39');
    });

    it('notificationTypeKey_mapping', 0, () => {
      expect(notificationTypeKey('PullRequest')).assertEqual('pr');
      expect(notificationTypeKey('Issue')).assertEqual('issue');
      expect(notificationTypeKey('SecurityAlert')).assertEqual('security');
      expect(notificationTypeKey('CheckSuite')).assertEqual('ci');
      expect(notificationTypeKey('Discussion')).assertEqual('discussion');
      // 未知类型原样返回，UI 层直接展示
      expect(notificationTypeKey('Whatever')).assertEqual('Whatever');
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

    it('mapViewerBasic_basic', 0, () => {
      const raw: JsonMap = {
        'login': 'zm_bad',
        'name': '周铭',
        'avatarUrl': 'https://avatars.example/u'
      };
      const viewer = mapViewerBasic(raw);
      expect(viewer.login).assertEqual('zm_bad');
      expect(viewer.name).assertEqual('周铭');
      expect(viewer.avatarUrl).assertEqual('https://avatars.example/u');
    });

    it('mapViewerBasic_missingFields', 0, () => {
      const viewer = mapViewerBasic({});
      expect(viewer.login).assertEqual('');
      expect(viewer.name).assertEqual('');
      expect(viewer.avatarUrl).assertEqual('');
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

    it('mapRepoDetail_starToggle', 0, () => {
      const license: JsonMap = { 'name': 'MIT License', 'spdxId': 'MIT' };
      const topicName: JsonMap = { 'name': 'arkts' };
      const topicNode: JsonMap = { 'topic': topicName };
      const topicsWrap: JsonMap = { 'nodes': [topicNode] };
      const readmeBlob: JsonMap = { 'text': '# StarRaft' };
      const entry1: JsonMap = { 'name': 'entry', 'type': 'tree' };
      const entry2: JsonMap = { 'name': 'README.md', 'type': 'blob' };
      const entries: JsonMap[] = [entry1, entry2];
      const tree: JsonMap = { 'entries': entries };
      const langNode1: JsonMap = { 'name': 'ArkTS', 'color': '#0EA5E9' };
      const edge1: JsonMap = { 'size': 750, 'node': langNode1 };
      const langNode2: JsonMap = { 'name': 'Python', 'color': '#3572A5' };
      const edge2: JsonMap = { 'size': 250, 'node': langNode2 };
      const edges: JsonMap[] = [edge1, edge2];
      const langs: JsonMap = { 'totalSize': 1000, 'edges': edges };
      const commitNode: JsonMap = { 'messageHeadline': 'feat: init' };
      const history: JsonMap = { 'nodes': [commitNode] };
      const target: JsonMap = { 'history': history };
      const branch: JsonMap = { 'name': 'main', 'target': target };
      const watchers: JsonMap = { 'totalCount': 9 };
      const repo: JsonMap = {
        'id': 'R1',
        'nameWithOwner': 'zm_bad/starraft',
        'description': 'gh client',
        'stargazerCount': 2,
        'forkCount': 1,
        'viewerHasStarred': true,
        'watchers': watchers,
        'licenseInfo': license,
        'repositoryTopics': topicsWrap,
        'readme': readmeBlob,
        'fileTree': tree,
        'languages': langs,
        'defaultBranchRef': branch
      };
      const detail = mapRepoDetail({ 'repository': repo });
      expect(detail.repoId).assertEqual('R1');
      expect(detail.licenseName).assertEqual('MIT License');
      expect(detail.topics[0]).assertEqual('arkts');
      expect(detail.readmeText).assertEqual('# StarRaft');
      expect(detail.files.length).assertEqual(2);
      expect(detail.files[0].type).assertEqual('tree');
      // 语言占比：750/1000 → 75%
      expect(detail.languages[0].percent).assertEqual(75);
      expect(detail.languages[1].percent).assertEqual(25);
      expect(detail.lastCommitMessage).assertEqual('feat: init');
      // Star 切换方向
      expect(nextStarAction(true)).assertFalse();
      expect(nextStarAction(false)).assertTrue();
    });

    it('mapIssuesPage_and_orderField', 0, () => {
      expect(issueOrderField('created')).assertEqual('CREATED_AT');
      expect(issueOrderField('updated')).assertEqual('UPDATED_AT');
      expect(issueOrderField('comments')).assertEqual('COMMENTS');
      expect(issueOrderField('other')).assertEqual('CREATED_AT');
      const author: JsonMap = { 'login': 'zm_bad' };
      const labelName: JsonMap = { 'name': 'bug' };
      const labelsNodes: JsonMap[] = [labelName];
      const labels: JsonMap = { 'nodes': labelsNodes };
      const comments: JsonMap = { 'totalCount': 3 };
      const prSource: JsonMap = { 'number': 12 };
      const timelineNode: JsonMap = { 'source': prSource };
      const timelineNodes: JsonMap[] = [timelineNode];
      const timeline: JsonMap = { 'nodes': timelineNodes };
      const issueNode: JsonMap = {
        'id': 'I1',
        'number': 4,
        'title': 'fix bug',
        'state': 'OPEN',
        'createdAt': '2026-08-30T00:00:00Z',
        'author': author,
        'labels': labels,
        'comments': comments,
        'timelineItems': timeline
      };
      const issue = mapIssue(issueNode);
      expect(issue.number).assertEqual(4);
      expect(issue.authorLogin).assertEqual('zm_bad');
      expect(issue.labels[0]).assertEqual('bug');
      expect(issue.commentCount).assertEqual(3);
      expect(issue.linkedPrCount).assertEqual(1);
      const pageInfo: JsonMap = { 'hasNextPage': true, 'endCursor': 'cur1' };
      const issuesWrap: JsonMap = { 'totalCount': 9, 'pageInfo': pageInfo, 'nodes': [issueNode] };
      const labelListNode: JsonMap = { 'name': 'docs' };
      const labelListNodes: JsonMap[] = [labelListNode];
      const labelsList: JsonMap = { 'nodes': labelListNodes };
      const repo: JsonMap = { 'issues': issuesWrap, 'labels': labelsList };
      const page = mapIssuesPage({ 'repository': repo });
      expect(page.totalCount).assertEqual(9);
      expect(page.hasNextPage).assertTrue();
      expect(page.endCursor).assertEqual('cur1');
      expect(page.issues.length).assertEqual(1);
      expect(page.repoLabels[0]).assertEqual('docs');
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
