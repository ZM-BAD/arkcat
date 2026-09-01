/**
 * 仪器测试：格式化工具与模型映射（纯函数）。
 * 运行于模拟器（aa test），与主代码同一编译单元，可直接 import main ets。
 */
import { describe, it, expect } from '@ohos/hypium';
import { timeParts, compactCount, notificationTypeKey, githubShortTime } from '../../../main/ets/utils/Format';
import { Json } from '../../../main/ets/utils/Json';
import { WorkSection, defaultWorkSections, visibleWorkSections, workSectionsToStorage, workSectionsFromStorage } from '../../../main/ets/utils/WorkConfig';
import {
  mapRepoPr, mapRepoPrsPage, mapRepoCommitsPage, mapRepoReleasesPage, mapIssueDetail, mapPrDetail,
  filterPrsByAuthor, filterPrsByAssignee, repoPrIconKey, monthDayText
} from '../../../main/ets/models/RepoSubModels';
import { repoIssueStates } from '../../../main/ets/services/IssuesService';
import { RepoPrItem } from '../../../main/ets/models/RepoSubModels';
import {
  buildWorkIssuesQuery, buildWorkPrsQuery, buildWorkDiscussionsQuery, buildTopReposPrivacy,
  mapWorkIssue, workIssueIconKey, mapWorkPr, workPrIconKey,
  mapWorkStarredPage, filterWorkProjects, WorkProjectItem,
  mapWorkProjectsPage, mapWorkTopReposPage, mapWorkOrgsPage
} from '../../../main/ets/models/WorkModels';
import { mapUser, mapRepo, mapViewerBasic, mapNotifications, issueNumberFromUrl } from '../../../main/ets/models/GitHubModels';
import { buildNotificationsPath, pullRefFromUrl, buildPullStatesQuery, mapPullMerged, PrRef } from '../../../main/ets/services/NotificationsService';
import { buildCodeQuery, mapCodeSearch } from '../../../main/ets/services/SearchService';
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
    it('githubShortTime_formats', 0, () => {
      // GitHub 通知卡片风格：22h / 1d / 8d（无本地化后缀）
      expect(githubShortTime({ value: 0, unit: 'just_now' })).assertEqual('now');
      expect(githubShortTime({ value: 5, unit: 'minute' })).assertEqual('5m');
      expect(githubShortTime({ value: 22, unit: 'hour' })).assertEqual('22h');
      expect(githubShortTime({ value: 1, unit: 'day' })).assertEqual('1d');
      expect(githubShortTime({ value: 8, unit: 'day' })).assertEqual('8d');
      expect(githubShortTime({ value: 3, unit: 'month' })).assertEqual('3mo');
      expect(githubShortTime({ value: 2, unit: 'year' })).assertEqual('2y');
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

    it('mapRepo_ownerFields', 0, () => {
      const owner: JsonMap = { 'login': 'zm_bad', 'avatarUrl': 'https://avatars.example/zm' };
      const raw: JsonMap = {
        'id': 'R_2',
        'name': 'starraft',
        'nameWithOwner': 'zm_bad/starraft',
        'owner': owner
      };
      const repo = mapRepo(raw);
      expect(repo.name).assertEqual('starraft');
      expect(repo.ownerLogin).assertEqual('zm_bad');
      expect(repo.ownerAvatarUrl).assertEqual('https://avatars.example/zm');
      // 查询未带 owner 节点 → 兜底空串
      const bare = mapRepo({ 'id': 'R_3' });
      expect(bare.ownerLogin).assertEqual('');
      expect(bare.ownerAvatarUrl).assertEqual('');
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
      // Spec 002 Focused：participating 模式
      expect(buildNotificationsPath(true, 30, true)).assertEqual('/notifications?participating=true&per_page=30');
    });

    it('issueNumberFromUrl_extract', 0, () => {
      expect(issueNumberFromUrl('/repos/a/b/issues/82')).assertEqual('82');
      expect(issueNumberFromUrl('/repos/a/b/pull/456')).assertEqual('456');
      // GitHub 通知 subject.url 为完整 URL
      expect(issueNumberFromUrl('https://api.github.com/repos/a/b/issues/82')).assertEqual('82');
      expect(issueNumberFromUrl('/repos/a/b/commits/deadbeef')).assertEqual('');
      expect(issueNumberFromUrl('')).assertEqual('');
    });

    it('buildCodeQuery_and_map', 0, () => {
      expect(buildCodeQuery('claude code')).assertEqual('"claude code"');
      const repo1: JsonMap = { 'nameWithOwner': 'nvidia/trit' };
      const repo2: JsonMap = { 'nameWithOwner': 'jezwb/claude-skills' };
      const fileNode1: JsonMap = {
        'repository': repo1,
        'path': 'docs/CLAUDE.md',
        'name': 'CLAUDE.md'
      };
      const fileNode2: JsonMap = {
        'repository': repo2,
        'path': 'src/main.ts',
        'name': 'main.ts'
      };
      const nodes: JsonMap[] = [fileNode1, fileNode2];
      const search: JsonMap = {
        'codeCount': 2,
        'nodes': nodes
      };
      const items = mapCodeSearch({ 'search': search });
      expect(items.length).assertEqual(2);
      expect(items[0].repoFullName).assertEqual('nvidia/trit');
      expect(items[0].name).assertEqual('CLAUDE.md');
      expect(items[0].isMarkdown).assertTrue();
      expect(items[1].isMarkdown).assertFalse();
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
      const owner: JsonMap = { 'login': 'zm_bad', 'avatarUrl': 'https://avatars.example/zm' };
      const repoNode: JsonMap = { 'id': 'R5', 'name': 'b', 'nameWithOwner': 'a/b', 'stargazerCount': 1, 'owner': owner };
      const pinnedWrap: JsonMap = { 'nodes': [repoNode] };
      const countWrap: JsonMap = { 'totalCount': 9 };
      const userNode: JsonMap = {
        'id': 'U1',
        'login': 'zm_bad',
        'name': '周铭',
        'company': '@example',
        'location': 'SH',
        'websiteUrl': 'https://zmbad.me',
        'email': 'zm@example.com',
        'viewerIsFollowing': true,
        'status': status,
        'followers': followers,
        'following': following,
        'pinnedItems': pinnedWrap,
        'repositories': countWrap,
        'starredRepositories': countWrap,
        'organizations': countWrap
      };
      const viewer: JsonMap = { 'login': 'other' };
      const data: JsonMap = { 'viewer': viewer, 'user': userNode };
      const profile = mapUserProfile(data);
      expect(profile.user.login).assertEqual('zm_bad');
      expect(profile.viewerLogin).assertEqual('other');
      expect(profile.userId).assertEqual('U1');
      expect(profile.company).assertEqual('@example');
      expect(profile.email).assertEqual('zm@example.com');
      expect(profile.statusEmoji).assertEqual('🚀');
      expect(profile.viewerIsFollowing).assertTrue();
      expect(profile.pinned.length).assertEqual(1);
      expect(profile.pinned[0].ownerLogin).assertEqual('zm_bad');
      expect(profile.repositoriesCount).assertEqual(9);
      expect(profile.organizationsCount).assertEqual(9);
      expect(profile.starredCount).assertEqual(9);
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
      const issuesWrap: JsonMap = { 'totalCount': 5 };
      const prsWrap: JsonMap = { 'totalCount': 3 };
      const releaseNode: JsonMap = { 'tagName': 'v1.0.0', 'publishedAt': '2026-08-01T00:00:00Z', 'isLatest': true };
      const releasesWrap: JsonMap = { 'totalCount': 2, 'nodes': [releaseNode] };
      const ownerNode: JsonMap = { 'avatarUrl': 'u', 'login': 'zm_bad' };
      const repo: JsonMap = {
        'id': 'R1',
        'name': 'starraft',
        'nameWithOwner': 'zm_bad/starraft',
        'description': 'gh client',
        'stargazerCount': 2,
        'forkCount': 1,
        'viewerHasStarred': true,
        'watchers': watchers,
        'issues': issuesWrap,
        'pullRequests': prsWrap,
        'releases': releasesWrap,
        'owner': ownerNode,
        'licenseInfo': license,
        'repositoryTopics': topicsWrap,
        'readme': readmeBlob,
        'fileTree': tree,
        'languages': langs,
        'defaultBranchRef': branch
      };
      const detail = mapRepoDetail({ 'repository': repo });
      expect(detail.repoId).assertEqual('R1');
      expect(detail.name).assertEqual('starraft');
      expect(detail.licenseName).assertEqual('MIT License');
      expect(detail.topics[0]).assertEqual('arkts');
      expect(detail.readmeText).assertEqual('# StarRaft');
      expect(detail.files.length).assertEqual(2);
      expect(detail.files[0].type).assertEqual('tree');
      // 语言占比：750/1000 → 75%
      expect(detail.languages[0].percent).assertEqual(75);
      expect(detail.languages[1].percent).assertEqual(25);
      expect(detail.lastCommitMessage).assertEqual('feat: init');
      // Spec 006 计数/业主/分支
      expect(detail.issueCount).assertEqual(5);
      expect(detail.prCount).assertEqual(3);
      expect(detail.releaseCount).assertEqual(2);
      expect(detail.latestRelease?.tagName).assertEqual('v1.0.0');
      expect(detail.ownerLogin).assertEqual('zm_bad');
      expect(detail.defaultBranchRefName).assertEqual('main');
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

    it('pullRefFromUrl_and_queries', 0, () => {
      const ref = pullRefFromUrl('https://api.github.com/repos/ZM-BAD/starraft/pulls/123');
      expect(ref?.owner).assertEqual('ZM-BAD');
      expect(ref?.name).assertEqual('starraft');
      expect(ref?.number).assertEqual(123);
      // Issue URL / 非法路径 → null（不探测合并态）
      expect(pullRefFromUrl('https://api.github.com/repos/a/b/issues/8')).assertNull();
      expect(pullRefFromUrl('')).assertNull();
      // 单查询多 alias
      const refA: PrRef = { owner: 'a', name: 'b', number: 8 };
      const refB: PrRef = { owner: 'c', name: 'd', number: 9 };
      const q = buildPullStatesQuery([refA, refB]);
      expect(q.indexOf('t0:repository(owner:"a", name:"b")') >= 0).assertTrue();
      expect(q.indexOf('t1:repository(owner:"c", name:"d")') >= 0).assertTrue();
      expect(q.indexOf('issueOrPullRequest(number:8)') >= 0).assertTrue();
      // 别名解析：缺失节点兜底 false
      const node1: JsonMap = { 'merged': true };
      const node2: JsonMap = { 'merged': false };
      const repo1: JsonMap = { 'issueOrPullRequest': node1 };
      const repo2: JsonMap = { 'issueOrPullRequest': node2 };
      const alias0: JsonMap = { 'repository': repo1 };
      const alias1: JsonMap = { 'repository': repo2 };
      const alias2: JsonMap = {};
      const data: JsonMap = { 't0': alias0, 't1': alias1, 't2': alias2 };
      const merged = mapPullMerged(data, 3);
      expect(merged[0]).assertTrue();
      expect(merged[1]).assertFalse();
      expect(merged[2]).assertFalse();
    });

    it('mapNotifications_parseAndInvalid', 0, () => {
      expect(mapNotifications('[]').length).assertEqual(0);
      expect(mapNotifications('not json').length).assertEqual(0);
      const owner: JsonMap = { 'login': 'zm_bad', 'avatar_url': 'https://avatars.example/zm' };
      const repo: JsonMap = { 'full_name': 'a/b', 'owner': owner };
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
      expect(list[0].ownerAvatarUrl).assertEqual('https://avatars.example/zm');
    });

    it('timeParts_years_and_compactCount', 0, () => {
      // 2024-06 → 2026-08：26 个月 ≥ 12 → 2 年
      const years = timeParts('2024-06-01T12:00:00Z', NOW);
      expect(years?.unit).assertEqual('year');
      expect(years?.value).assertEqual(2);
      // 13 个月整仍属 month 粒度边界内
      const months = timeParts('2026-06-01T12:00:00Z', NOW);
      expect(months?.unit).assertEqual('month');
      expect(compactCount(999)).assertEqual('999');
      expect(compactCount(1000)).assertEqual('1k');
      expect(compactCount(50500)).assertEqual('50.5k');
      expect(compactCount(118900)).assertEqual('118.9k');
    });

    it('workConfig_visibleAndStorage', 0, () => {
      const all = defaultWorkSections();
      expect(all.length).assertEqual(7);
      expect(visibleWorkSections(all).length).assertEqual(7);
      const partial: WorkSection[] = [
        { id: 'starred', visible: true },
        { id: 'issues', visible: false }
      ];
      const shown = visibleWorkSections(partial);
      expect(shown.length).assertEqual(1);
      expect(shown[0].id).assertEqual('starred');
      // 序列化往返
      const round = workSectionsFromStorage(workSectionsToStorage(partial));
      expect(round.length).assertEqual(2);
      expect(round[0].id).assertEqual('starred');
      expect(round[1].visible).assertFalse();
      // 坏数据回退默认；重复 id 去重
      expect(workSectionsFromStorage('not json').length).assertEqual(7);
      expect(workSectionsFromStorage('[]').length).assertEqual(7);
    });

    it('workQueries_builders', 0, () => {
      expect(buildWorkIssuesQuery('all', 'created', 'all')).assertEqual('is:issue author:@me sort:updated-desc');
      expect(buildWorkIssuesQuery('open', 'assigned', 'public')).assertEqual('is:issue is:open assignee:@me is:public sort:updated-desc');
      expect(buildWorkPrsQuery('merged', 'created', 'private')).assertEqual('is:pr is:merged author:@me is:private sort:updated-desc');
      expect(buildWorkDiscussionsQuery('open', 'mentioned', true)).assertEqual('is:discussion is:open mentions:@me is:unanswered');
      expect(buildWorkDiscussionsQuery('all', 'created', false)).assertEqual('is:discussion author:@me');
      expect(buildTopReposPrivacy('all')).assertEqual('');
      expect(buildTopReposPrivacy('public')).assertEqual('PUBLIC');
      expect(buildTopReposPrivacy('private')).assertEqual('PRIVATE');
    });

    it('mapWorkIssue_and_workPr', 0, () => {
      const repo: JsonMap = { 'nameWithOwner': 'a/b' };
      const label: JsonMap = { 'name': 'bug', 'color': '#D73A4A' };
      const labelsWrap: JsonMap = { 'nodes': [label] };
      const comments: JsonMap = { 'totalCount': 3 };
      const issueNode: JsonMap = {
        'id': 'I1', 'number': 5, 'title': 'fix', 'state': 'CLOSED', 'stateReason': 'NOT_PLANNED',
        'createdAt': '2026-08-01T00:00:00Z', 'repository': repo,
        'labels': labelsWrap, 'comments': comments
      };
      const issue = mapWorkIssue(issueNode);
      expect(issue.iconKey).assertEqual('not_planned');
      expect(issue.repoFullName).assertEqual('a/b');
      expect(issue.labels[0].color).assertEqual('#D73A4A');
      expect(issue.commentCount).assertEqual(3);
      expect(workIssueIconKey('OPEN', '')).assertEqual('open');
      expect(workIssueIconKey('CLOSED', 'COMPLETED')).assertEqual('completed');
      // PR：merged 且无 statusCheckRollup → checksState 空
      const prComments: JsonMap = { 'totalCount': 2 };
      const reviewsWrap: JsonMap = { 'totalCount': 1 };
      const prNode: JsonMap = {
        'id': 'P1', 'number': 8, 'title': 'feat', 'state': 'MERGED', 'merged': true,
        'createdAt': '2026-08-01T00:00:00Z', 'repository': repo,
        'comments': prComments, 'reviewRequests': reviewsWrap
      };
      const pr = mapWorkPr(prNode);
      expect(pr.iconKey).assertEqual('merged');
      expect(pr.checksState).assertEqual('');
      expect(pr.reviewCount).assertEqual(1);
      expect(workPrIconKey('OPEN', false)).assertEqual('open');
      expect(workPrIconKey('CLOSED', false)).assertEqual('closed');
    });

    it('mapWorkStarred_page', 0, () => {
      const owner: JsonMap = { 'login': 'zm_bad', 'avatarUrl': 'u' };
      const lang: JsonMap = { 'name': 'Dart', 'color': '#00B4AB' };
      const repoNode: JsonMap = {
        'id': 'R1', 'name': 'ficl', 'description': 'proxy', 'stargazerCount': 50500,
        'owner': owner, 'primaryLanguage': lang
      };
      const repoNode2: JsonMap = {
        'id': 'R2', 'name': 'nolang', 'description': '', 'stargazerCount': 3, 'owner': owner
      };
      const pageInfo: JsonMap = { 'hasNextPage': false, 'endCursor': '' };
      const starredWrap: JsonMap = { 'nodes': [repoNode, repoNode2], 'pageInfo': pageInfo };
      const viewer: JsonMap = {
        'login': 'zm_bad', 'starredRepositories': starredWrap
      };
      const data: JsonMap = { 'viewer': viewer };
      const page = mapWorkStarredPage(data);
      expect(page.viewerLogin).assertEqual('zm_bad');
      expect(page.repos.length).assertEqual(2);
      expect(page.repos[0].language).assertEqual('Dart');
      expect(page.repos[1].language).assertEqual('');
      expect(page.repos[0].stargazerCount).assertEqual(50500);
    });

    it('filterWorkProjects_scoping', 0, () => {
      const p1: WorkProjectItem = { 'id': 'A', 'number': 1, 'title': 'a', 'closed': false, 'updatedAt': '2026-08-01T00:00:00Z', 'ownerLogin': 'me' };
      const p2: WorkProjectItem = { 'id': 'B', 'number': 2, 'title': 'b', 'closed': true, 'updatedAt': '2026-08-02T00:00:00Z', 'ownerLogin': 'me' };
      const p3: WorkProjectItem = { 'id': 'C', 'number': 3, 'title': 'c', 'closed': false, 'updatedAt': '2026-08-03T00:00:00Z', 'ownerLogin': 'other' };
      const all = filterWorkProjects([p1, p2, p3], false, 'me', false);
      expect(all.length).assertEqual(2);
      expect(all[0].id).assertEqual('C');
      const mine = filterWorkProjects([p1, p2, p3], true, 'me', false);
      expect(mine.length).assertEqual(1);
      expect(mine[0].id).assertEqual('A');
      const closed = filterWorkProjects([p1, p2], false, 'me', true);
      expect(closed.length).assertEqual(1);
      expect(closed[0].id).assertEqual('B');
    });

    it('mapWorkViewerConnections(projects/tops/orgs)', 0, () => {
      const projOwner: JsonMap = { 'login': 'me' };
      const projNode: JsonMap = {
        'title': 'roadmap', 'number': 1, 'closed': false,
        'updatedAt': '2026-08-01T00:00:00Z', 'owner': projOwner
      };
      const projPageInfo: JsonMap = { 'hasNextPage': false, 'endCursor': 'cur' };
      const repoOwner: JsonMap = { 'login': 'me', 'avatarUrl': 'u' };
      const repoNode: JsonMap = { 'name': 'repo', 'owner': repoOwner };
      const orgNode: JsonMap = { 'login': 'org1', 'name': 'Org One', 'avatarUrl': 'u' };
      const projWrap: JsonMap = { 'nodes': [projNode], 'pageInfo': projPageInfo };
      const reposWrap: JsonMap = { 'nodes': [repoNode] };
      const orgsWrap: JsonMap = { 'nodes': [orgNode] };
      const viewer: JsonMap = {
        'login': 'me',
        'projectsV2': projWrap,
        'repositories': reposWrap,
        'organizations': orgsWrap
      };
      const projPage = mapWorkProjectsPage({ 'viewer': viewer });
      expect(projPage.viewerLogin).assertEqual('me');
      expect(projPage.projects.length).assertEqual(1);
      expect(projPage.projects[0].ownerLogin).assertEqual('me');
      const topPage = mapWorkTopReposPage({ 'viewer': viewer });
      expect(topPage.repos.length).assertEqual(1);
      expect(topPage.repos[0].name).assertEqual('repo');
      const orgPage = mapWorkOrgsPage({ 'viewer': viewer });
      expect(orgPage.orgs.length).assertEqual(1);
      expect(orgPage.orgs[0].login).assertEqual('org1');
      expect(orgPage.orgs[0].name).assertEqual('Org One');
    });

    it('repoSub_pages_mappers', 0, () => {
      expect(repoIssueStates('all').length).assertEqual(2);
      expect(repoIssueStates('open')[0]).assertEqual('OPEN');
      expect(repoIssueStates('closed')[0]).assertEqual('CLOSED');
      expect(monthDayText('2026-06-30T00:00:00Z')).assertEqual('June 30');
      expect(monthDayText('bad')).assertEqual('');
      expect(repoPrIconKey('MERGED', true)).assertEqual('merged');
      expect(repoPrIconKey('OPEN', false)).assertEqual('open');
      expect(repoPrIconKey('CLOSED', false)).assertEqual('closed');

      const author: JsonMap = { 'login': 'zm_bad' };
      const labelNode: JsonMap = { 'name': 'deps', 'color': '#B5B5B5' };
      const labelsWrap: JsonMap = { 'nodes': [labelNode] };
      const commentsWrap: JsonMap = { 'totalCount': 2 };
      const reviewsWrap: JsonMap = { 'totalCount': 1 };
      const assigneeNode: JsonMap = { 'login': 'renovate' };
      const assigneesWrap: JsonMap = { 'nodes': [assigneeNode] };
      const pr: JsonMap = {
        'id': 'P1', 'number': 8, 'title': 'feat', 'state': 'MERGED', 'merged': true,
        'createdAt': '2026-08-01T00:00:00Z',
        'labels': labelsWrap, 'comments': commentsWrap, 'reviewRequests': reviewsWrap,
        'author': author, 'assignees': assigneesWrap
      };
      const prItem = mapRepoPr(pr);
      const prList: RepoPrItem[] = [prItem];
      expect(filterPrsByAuthor(prList, '').length).assertEqual(1);
      expect(filterPrsByAuthor(prList, 'other').length).assertEqual(0);
      expect(filterPrsByAssignee(prList, 'renovate').length).assertEqual(1);

      const lNode: JsonMap = { 'name': 'deps' };
      const prsWrap: JsonMap = { 'nodes': [pr] };
      const labelsList: JsonMap = { 'nodes': [lNode] };
      const repo: JsonMap = { 'pullRequests': prsWrap, 'labels': labelsList };
      const data1: JsonMap = { 'repository': repo };
      const page = mapRepoPrsPage(data1);
      expect(page.prs.length).assertEqual(1);
      expect(page.labelOptions[0]).assertEqual('deps');
      expect(page.authorOptions[0]).assertEqual('zm_bad');
      expect(page.assigneeOptions[0]).assertEqual('renovate');

      const checks: JsonMap = { 'state': 'SUCCESS' };
      const commitNode: JsonMap = {
        'oid': 'abc', 'messageHeadline': 'fix', 'committedDate': '2026-08-01T00:00:00Z',
        'author': author, 'statusCheckRollup': checks
      };
      const history: JsonMap = { 'nodes': [commitNode] };
      const target: JsonMap = { 'history': history };
      const branchRef: JsonMap = { 'target': target };
      const repo2: JsonMap = { 'defaultBranchRef': branchRef };
      const data2: JsonMap = { 'repository': repo2 };
      const cp = mapRepoCommitsPage(data2);
      expect(cp.commits.length).assertEqual(1);
      expect(cp.commits[0].checksState).assertEqual('SUCCESS');

      const relNode: JsonMap = {
        'id': 'R1', 'tagName': '1.3.2', 'isLatest': true,
        'createdAt': '2026-06-30T00:00:00Z', 'description': 'LLM', 'body': 'body', 'author': author
      };
      const releasesWrap2: JsonMap = { 'nodes': [relNode] };
      const repo3: JsonMap = { 'releases': releasesWrap2 };
      const data3: JsonMap = { 'repository': repo3 };
      const rp = mapRepoReleasesPage(data3);
      expect(rp.releases.length).assertEqual(1);
      expect(rp.releases[0].isLatest).assertTrue();

      const issueLabelsWrap: JsonMap = { 'nodes': [lNode] };
      const cNode: JsonMap = { 'id': 'C1', 'body': 'c', 'createdAt': '2026-08-02T00:00:00Z', 'author': author };
      const issueComments: JsonMap = { 'totalCount': 1, 'nodes': [cNode] };
      const issueNode: JsonMap = {
        'number': 1, 'title': 't', 'state': 'OPEN', 'stateReason': '', 'body': 'body text',
        'createdAt': '2026-08-01T00:00:00Z', 'author': author,
        'labels': issueLabelsWrap, 'comments': issueComments
      };
      const repo4: JsonMap = { 'issue': issueNode };
      const data4: JsonMap = { 'repository': repo4 };
      const ip = mapIssueDetail(data4);
      expect(ip.number).assertEqual(1);
      expect(ip.comments.length).assertEqual(1);
      expect(ip.labels[0]).assertEqual('deps');

      const mergeCommit: JsonMap = { 'abbreviatedOid': 'eb43eaa' };
      const prComments: JsonMap = { 'totalCount': 1, 'nodes': [] };
      const prNode: JsonMap = {
        'number': 82, 'title': 'fix', 'state': 'MERGED', 'merged': true, 'isDraft': false,
        'body': 'body', 'createdAt': '2026-08-01T00:00:00Z', 'mergedAt': '2026-08-02T00:00:00Z',
        'additions': 249, 'deletions': 49, 'author': author, 'headRefName': 'fix/1', 'baseRefName': 'main',
        'mergeCommit': mergeCommit, 'statusCheckRollup': checks,
        'comments': prComments
      };
      // files/commits/reviews 内联字面量需显式类型（上一批测试的既有惯例）
      const filesWrap: JsonMap = { 'totalCount': 3 };
      const commitsWrap2: JsonMap = { 'totalCount': 1 };
      const reviewsWrap2: JsonMap = { 'totalCount': 0 };
      prNode['files'] = filesWrap;
      prNode['commits'] = commitsWrap2;
      prNode['reviews'] = reviewsWrap2;
      const repo5: JsonMap = { 'pullRequest': prNode };
      const data5: JsonMap = { 'repository': repo5 };
      const pp = mapPrDetail(data5);
      expect(pp.filesCount).assertEqual(3);
      expect(pp.additions).assertEqual(249);
      expect(pp.mergeOid).assertEqual('eb43eaa');
      expect(pp.checksState).assertEqual('SUCCESS');
    });
  });
}
