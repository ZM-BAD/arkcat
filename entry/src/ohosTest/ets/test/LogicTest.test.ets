/**
 * 仪器测试：格式化工具与模型映射（纯函数）。
 * 运行于模拟器（aa test），与主代码同一编译单元，可直接 import main ets。
 */
import { describe, it, expect } from '@ohos/hypium';
import { timeParts, compactCount, notificationTypeKey, githubShortTime, unlockDateText } from '../../../main/ets/utils/Format';
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
  mapWorkStarredPage, filterWorkProjects, sortWorkProjects, filterTopRepos, WorkTopRepoItem, WorkProjectItem,
  mapWorkProjectsPage, mapWorkTopReposPage, mapWorkOrgsPage
} from '../../../main/ets/models/WorkModels';
import { mapUser, mapRepo, mapViewerBasic, mapNotifications, issueNumberFromUrl, NotificationItem } from '../../../main/ets/models/GitHubModels';
import { buildNotificationsPath, pullRefFromUrl, buildPullStatesQuery, mapPullMerged, PrRef,
  filterByReasons, filterByInboxView, collectRepoFilters, InboxReasonKey, InboxRepoFilterItem
} from '../../../main/ets/services/NotificationsService';
import { buildCodeQuery, mapCodeSearch, mapSearchNode, mapSearchResults, mapOrgSearchResults, buildQualifierInsert, pushSearchHistory, buildSearchQuery, mapSearchOverview, formatBigCount, isLightHexColor } from '../../../main/ets/services/SearchService';
import { buildCodeSnippet, splitLines, buildFragmentLines, parseCodeSearchItem, fileBadgeKey } from '../../../main/ets/services/CodeSearchService';
import { RawMatch } from '../../../main/ets/services/CodeSearchService';
import { buildTopicQuery } from '../../../main/ets/services/ExploreService';
import { mapSearchResult } from '../../../main/ets/models/ExploreModels';
import { mapUserProfile, isSelfProfile } from '../../../main/ets/models/ProfileModels';
import { mapRepoDetail, nextStarAction } from '../../../main/ets/models/RepoDetailModels';
import { parseAchievementDetail, extractAchievementSlugs } from '../../../main/ets/models/AchievementModels';
import { mapFork, mapStargazerPage } from '../../../main/ets/models/RepoSocialModels';
import { mapIssue, mapIssuesPage, issueOrderField } from '../../../main/ets/models/IssuesModels';
import { MarkdownService } from '../../../main/ets/services/MarkdownService';

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

    it('filterByReasons_reasonKeys', 0, () => {
      const mk = (threadId: string, reason: string): NotificationItem => {
        return {
          threadId: threadId, repoFullName: 'o/r', title: 't', subjectType: 'Issue', reason: reason,
          unread: true, updatedAt: '', subjectUrl: '', ownerAvatarUrl: '', prMerged: false
        };
      };
      const items = [
        mk('1', 'assign'), mk('2', 'mention'), mk('3', 'team_mention'),
        mk('4', 'review_requested'), mk('5', 'comment'), mk('6', 'subscribed'), mk('7', 'author'),
        mk('8', 'state_change')
      ];
      // 空选 = 全量
      expect(filterByReasons(items, []).length).assertEqual(8);
      // 单选
      expect(filterByReasons(items, ['mention']).length).assertEqual(1);
      expect(filterByReasons(items, ['assign'])[0].threadId).assertEqual('1');
      // 多选并集
      const two: InboxReasonKey[] = ['assign', 'mention'];
      expect(filterByReasons(items, two).length).assertEqual(2);
      // Participating = comment/subscribed/author/mention/team_mention 并集
      const part: InboxReasonKey[] = ['participating'];
      expect(filterByReasons(items, part).length).assertEqual(5);
    });

    it('filterByInboxView_views', 0, () => {
      const mk = (threadId: string, unread: boolean): NotificationItem => {
        return {
          threadId: threadId, repoFullName: 'o/r', title: 't', subjectType: 'Issue', reason: 'comment',
          unread: unread, updatedAt: '', subjectUrl: '', ownerAvatarUrl: '', prMerged: false
        };
      };
      const items = [mk('1', true), mk('2', false), mk('3', true)];
      expect(filterByInboxView(items, 'inbox').length).assertEqual(3);
      // Done=已读近似；Saved 无本地保存标记 → 空视图
      expect(filterByInboxView(items, 'done')[0].threadId).assertEqual('2');
      expect(filterByInboxView(items, 'saved').length).assertEqual(0);
    });

    it('collectRepoFilters_aggregate', 0, () => {
      const mk = (threadId: string, fullName: string, avatar: string): NotificationItem => {
        return {
          threadId: threadId, repoFullName: fullName, title: 't', subjectType: 'Issue', reason: 'comment',
          unread: true, updatedAt: '', subjectUrl: '', ownerAvatarUrl: avatar, prMerged: false
        };
      };
      const items = [
        mk('1', 'o/a', 'http://a'), mk('2', 'o/b', ''), mk('3', 'o/a', ''), mk('4', 'o/a', 'http://a2')
      ];
      const reps: InboxRepoFilterItem[] = collectRepoFilters(items);
      // 保持首次出现顺序 + 计数 + 头像取最新非空
      expect(reps.length).assertEqual(2);
      expect(reps[0].fullName).assertEqual('o/a');
      expect(reps[0].count).assertEqual(3);
      expect(reps[0].avatarUrl).assertEqual('http://a');
      expect(reps[1].fullName).assertEqual('o/b');
      expect(reps[1].count).assertEqual(1);
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
      // qualifier 可解析：原词不带引号（gitHub search 语法）
      expect(buildCodeQuery('claude code')).assertEqual('claude code');
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

    it('buildQualifierInsert', 0, () => {
      expect(buildQualifierInsert('', 'repo')).assertEqual('repo:');
      expect(buildQualifierInsert('foo', 'repo')).assertEqual('foo repo:');
      expect(buildQualifierInsert('foo ', 'repo')).assertEqual('foo repo:');
      expect(buildQualifierInsert('repo:', 'user')).assertEqual('repo:user:');
    });

    it('pushSearchHistory_dedupAndCap', 0, () => {
      const next = pushSearchHistory(['a', 'b'], 'a');
      expect(next.length).assertEqual(2);
      expect(next[0]).assertEqual('a');
      expect(next[1]).assertEqual('b');
      const cap = pushSearchHistory(['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j'], 'k');
      expect(cap.length).assertEqual(10);
      expect(cap[0]).assertEqual('k');
      expect(cap[9]).assertEqual('i');
    });

    it('mapSearchNode_kinds', 0, () => {
      const lang: JsonMap = { 'name': 'TS', 'color': '#3178c6' };
      const repoNode: JsonMap = {
        '__typename': 'Repository', 'nameWithOwner': 'a/b', 'description': 'd',
        'stargazerCount': 9, 'forkCount': 3,
        'primaryLanguage': lang
      };
      const r = mapSearchNode(repoNode);
      expect(r?.kind).assertEqual('repository');
      expect(r?.title).assertEqual('a/b');
      expect(r?.stars).assertEqual(9);
      expect(r?.languageColor).assertEqual('#3178c6');
      const repoIss: JsonMap = { 'nameWithOwner': 'c/d' };
      const issueNode: JsonMap = {
        '__typename': 'Issue', 'title': 't', 'state': 'OPEN', 'number': 12,
        'repository': repoIss
      };
      const i = mapSearchNode(issueNode);
      expect(i?.kind).assertEqual('issue');
      expect(i?.repoFullName).assertEqual('c/d');
      expect(i?.number).assertEqual(12);
      const prNode: JsonMap = {
        '__typename': 'PullRequest', 'title': 'p', 'state': 'MERGED', 'number': 7,
        'repository': repoIss
      };
      const p = mapSearchNode(prNode);
      expect(p?.kind).assertEqual('pr');
      const followers: JsonMap = { 'totalCount': 2 };
      const following: JsonMap = { 'totalCount': 5 };
      const userNode: JsonMap = {
        '__typename': 'User', 'login': 'foo', 'name': 'Foo', 'avatarUrl': 'a.png', 'bio': 'b',
        'followers': followers, 'following': following
      };
      const u = mapSearchNode(userNode);
      expect(u?.kind).assertEqual('user');
      expect(u?.followers).assertEqual(2);
      expect(mapSearchNode({ '__typename': 'Unknown' }) === null).assertTrue();
    });

    it('mapSearchResults_pageInfo', 0, () => {
      const repoNode1: JsonMap = { '__typename': 'Repository', 'nameWithOwner': 'a/b' };
      const repoNode2: JsonMap = { 'nameWithOwner': 'c/d' };
      const issueNode: JsonMap = { '__typename': 'Issue', 'title': 't', 'number': 1, 'repository': repoNode2 };
      const pageInfo: JsonMap = { 'hasNextPage': true, 'endCursor': 'abc' };
      const nodes: JsonMap[] = [repoNode1, issueNode];
      const searchNode: JsonMap = {
        'repositoryCount': 2,
        'pageInfo': pageInfo,
        'nodes': nodes
      };
      const res = mapSearchResults({ 'search': searchNode });
      expect(res.totalCount).assertEqual(2);
      expect(res.hasNextPage).assertTrue();
      expect(res.endCursor).assertEqual('abc');
      expect(res.items.length).assertEqual(2);
      expect(res.items[1].kind).assertEqual('issue');
    });

    it('mapOrgSearchResults', 0, () => {
      const item1: JsonMap = { 'login': 'org1', 'name': 'Org One', 'avatar_url': 'o.png' };
      const data: JsonMap = { 'items': [item1] };
      const items = mapOrgSearchResults(data);
      expect(items.length).assertEqual(1);
      expect(items[0].kind).assertEqual('organization');
      expect(items[0].title).assertEqual('org1');
    });

    it('searchQuery_qualifiers', 0, () => {
      expect(buildSearchQuery('repositories', 'cli')).assertEqual('cli');
      expect(buildSearchQuery('issues', 'cli')).assertEqual('cli is:issue');
      expect(buildSearchQuery('prs', 'cli')).assertEqual('cli is:pr');
      expect(buildSearchQuery('people', 'cli')).assertEqual('cli type:user');
      expect(buildSearchQuery('orgs', 'cli')).assertEqual('cli type:org');
      expect(buildSearchQuery('code', '  cli  ')).assertEqual('cli');
    });

    it('formatBigCount_display', 0, () => {
      expect(formatBigCount(0)).assertEqual('0');
      expect(formatBigCount(999)).assertEqual('999');
      expect(formatBigCount(72000)).assertEqual('72k');
      expect(formatBigCount(9999)).assertEqual('10k');
      expect(formatBigCount(2200000)).assertEqual('2.2m');
      expect(formatBigCount(24200000)).assertEqual('24.2m');
      expect(formatBigCount(2000000)).assertEqual('2m');
    });

    it('isLightHexColor_luminance', 0, () => {
      expect(isLightHexColor('F6F8FA')).assertTrue();
      expect(isLightHexColor('0C4462')).assertFalse();
      expect(isLightHexColor('')).assertFalse();
      expect(isLightHexColor('zzzzzz')).assertFalse();
    });

    it('mapSearchNode_extendedFields', 0, () => {
      const labelNodes: JsonMap[] = [ { 'name': 'bug-fix', 'color': '1F883D' } ];
      const labels: JsonMap = { 'nodes': labelNodes };
      const comments: JsonMap = { 'totalCount': 6 };
      const reactions: JsonMap = { 'totalCount': 2 };
      const check: JsonMap = { 'state': 'SUCCESS' };
      const prRepo: JsonMap = { 'nameWithOwner': 'a/b' };
      const prNode: JsonMap = {
        '__typename': 'PullRequest', 'title': '[CLI]: Crash', 'state': 'OPEN', 'number': 7,
        'createdAt': '2026-08-31T10:00:00Z', 'repository': prRepo,
        'labels': labels, 'comments': comments, 'reactions': reactions,
        'statusCheckRollup': check, 'reviewDecision': 'CHANGES_REQUESTED'
      };
      const item = mapSearchNode(prNode);
      expect(item !== null).assertTrue();
      if (item !== null) {
        expect(item.labels.length).assertEqual(1);
        expect(item.labels[0].name).assertEqual('bug-fix');
        expect(item.commentCount).assertEqual(6);
        expect(item.reactionCount).assertEqual(2);
        expect(item.checkState).assertEqual('SUCCESS');
        expect(item.reviewDecision).assertEqual('CHANGES_REQUESTED');
        expect(item.createdAt).assertEqual('2026-08-31T10:00:00Z');
      }
      const ownerNode: JsonMap = { 'avatarUrl': 'o.png' };
      const repoNode: JsonMap = {
        '__typename': 'Repository', 'nameWithOwner': 'a/b', 'stargazerCount': 5,
        'owner': ownerNode
      };
      const repoItem = mapSearchNode(repoNode);
      expect(repoItem !== null && repoItem.avatarUrl === 'o.png').assertTrue();
      const orgNode: JsonMap = {
        '__typename': 'Organization', 'login': 'github', 'name': 'GitHub', 'description': 'build together',
        'avatarUrl': 'g.png'
      };
      const orgItem = mapSearchNode(orgNode);
      expect(orgItem !== null && orgItem.bio === 'build together').assertTrue();
    });

    it('mapSearchOverview_sections', 0, () => {
      const repoNode: JsonMap = { '__typename': 'Repository', 'nameWithOwner': 'a/b' };
      const orgNode: JsonMap = { '__typename': 'Organization', 'login': 'github', 'name': 'GitHub' };
      const reposSec: JsonMap = { 'repositoryCount': 5, 'nodes': [repoNode] };
      const issuesSec: JsonMap = { 'issueCount': 7, 'nodes': [] };
      const prsSec: JsonMap = { 'issueCount': 9, 'nodes': [] };
      const usersSec: JsonMap = { 'userCount': 11, 'nodes': [] };
      const orgsSec: JsonMap = { 'userCount': 13, 'nodes': [orgNode] };
      const data: JsonMap = {
        'repos': reposSec,
        'issues': issuesSec,
        'prs': prsSec,
        'users': usersSec,
        'orgs': orgsSec
      };
      const ov = mapSearchOverview(data);
      expect(ov.repoCount).assertEqual(5);
      expect(ov.repoItems.length).assertEqual(1);
      expect(ov.orgCount).assertEqual(13);
      expect(ov.orgItems.length).assertEqual(1);
      expect(ov.issueCount).assertEqual(7);
      expect(ov.prCount).assertEqual(9);
      expect(ov.userCount).assertEqual(11);
    });

    it('codeSnippet_tokenBoundary', 0, () => {
      // "clients" 不应误命中 "cli"；"_cli_" 词内应命中
      const content = 'clients connect via latest_tomatoes_cli_gem\nfoo cli bar\n';
      const s = buildCodeSnippet(content, ['cli'], 20);
      expect(s.totalMatches).assertEqual(2);
      const line1 = s.window.find((l => l.no === 1));
      expect(line1 !== undefined && line1.highlights.length === 1).assertTrue();
      if (line1 !== undefined && line1.highlights.length === 1) {
        // latest_tomatoes_cli_gem 中 cli 的绝对位置 36..39
        expect(line1.highlights[0].start).assertEqual(36);
        expect(line1.highlights[0].end).assertEqual(39);
      }
    });

    it('codeSnippet_windowAndMore', 0, () => {
      // 内容：第 2 行 1 处命中、第 4 行 1 处、第 10 行 1 处 → 窗口覆盖 2/4 附近行，10 行进 more
      const content = 'A\ncli line2\nB\nline4 cli\nC\nD\nE\nF\nG\nH\ncli on 10\n';
      const s = buildCodeSnippet(content, ['cli'], 6);
      expect(s.totalMatches).assertEqual(3);
      expect(s.window.length > 0).assertTrue();
      expect(s.window[0].no).assertEqual(1); // 窗口从 1 起（含上下文）
      expect(s.more.length > 0).assertTrue();
      // 高亮区间定位：line2 的 cli 为 0..3
      const line2 = s.window.find((l => l.no === 2));
      expect(line2 !== undefined && line2.highlights[0].start === 0 && line2.highlights[0].end === 3).assertTrue();
    });

    it('codeSnippet_fragmentFallback', 0, () => {
      const fragment = 'a line\nfoo CLI bar\nb line';
      const match1: RawMatch = { 'text': 'CLI', 'indices': [11, 14] };
      const matches: RawMatch[] = [match1];
      expect(splitLines(fragment).length).assertEqual(3);
      const out = buildFragmentLines(fragment, matches);
      expect(out.length).assertEqual(3);
      // 命中行（第 2 行起始偏移 7）：11-7=4..14-7=7
      expect(out[1].highlights.length).assertEqual(1);
      expect(out[1].highlights[0].start).assertEqual(4);
      expect(out[1].highlights[0].end).assertEqual(7);
    });

    it('codeFile_parseAndBadge', 0, () => {
      const m1: RawMatch = { 'text': 'CLI', 'indices': [2, 5] };
      const matchesA: RawMatch[] = [m1];
      const tm: JsonMap = {
        'fragment': 'x CLI y',
        'matches': matchesA
      };
      const repoInfo: JsonMap = { 'full_name': 'owner/repo' };
      const item: JsonMap = {
        'repository': repoInfo,
        'path': 'docs/a.md',
        'name': 'a.md',
        'url': 'https://api.github.com/repositories/1/contents/docs/a.md',
        'text_matches': [tm]
      };
      const f = parseCodeSearchItem(item);
      expect(f !== null).assertTrue();
      if (f !== null) {
        expect(f.repoFullName).assertEqual('owner/repo');
        expect(f.matches.length).assertEqual(1);
        expect(f.matches[0].text).assertEqual('CLI');
        expect(fileBadgeKey(f.name)).assertEqual('markdown');
        expect(fileBadgeKey('NEWS')).assertEqual('text');
      }
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
      expect(buildWorkIssuesQuery('all', 'created', 'all', 'newest', [], []))
        .assertEqual('is:issue author:@me sort:created-desc');
      expect(buildWorkIssuesQuery('open', 'assigned', 'public', 'most_commented', ['ZM-BAD'], ['ZM-BAD/starraft']))
        .assertEqual('is:issue is:open assignee:@me is:public org:ZM-BAD repo:ZM-BAD/starraft sort:comments-desc');
      expect(buildWorkIssuesQuery('closed', 'involved', 'private', 'reactions:+1', [], []))
        .assertEqual('is:issue is:closed involves:@me is:private sort:reactions-+1-desc');
      expect(buildWorkIssuesQuery('open', 'created', 'all', 'least_recently_updated', [], []))
        .assertEqual('is:issue is:open author:@me sort:updated-asc');
      expect(buildWorkPrsQuery('merged', 'created', 'private', 'newest', [], []))
        .assertEqual('is:pr is:merged author:@me is:private sort:created-desc');
      expect(buildWorkPrsQuery('queued', 'review_requested', 'all', 'most_commented', ['ZM-BAD'], ['ZM-BAD/starraft']))
        .assertEqual('is:pr is:queued review-requested:@me org:ZM-BAD repo:ZM-BAD/starraft sort:comments-desc');
      expect(buildWorkDiscussionsQuery('all', 'created', false, 'new'))
        .assertEqual('is:discussion author:@me sort:created-desc');
      expect(buildWorkDiscussionsQuery('open', 'commented', true, 'top_all'))
        .assertEqual('is:discussion is:open commenter:@me is:unanswered sort:interactions-desc');
      expect(buildTopReposPrivacy('all')).assertEqual('');
      expect(buildTopReposPrivacy('public')).assertEqual('PUBLIC');
      expect(buildTopReposPrivacy('private')).assertEqual('PRIVATE');
      const r1: WorkTopRepoItem = { 'id': '1', 'name': 'a', 'ownerLogin': 'me', 'ownerAvatar': '', 'isArchived': false, 'isFork': true, 'isMirror': false, 'isTemplate': false, 'visibility': 'PUBLIC' };
      const r2: WorkTopRepoItem = { 'id': '2', 'name': 'b', 'ownerLogin': 'me', 'ownerAvatar': '', 'isArchived': true, 'isFork': false, 'isMirror': false, 'isTemplate': false, 'visibility': 'PRIVATE' };
      const r3: WorkTopRepoItem = { 'id': '3', 'name': 'c', 'ownerLogin': 'me', 'ownerAvatar': '', 'isArchived': false, 'isFork': false, 'isMirror': false, 'isTemplate': true, 'visibility': 'PUBLIC' };
      expect(filterTopRepos([r1, r2, r3], 'all').length).assertEqual(3);
      expect(filterTopRepos([r1, r2, r3], 'fork').length).assertEqual(1);
      expect(filterTopRepos([r1, r2, r3], 'archived').length).assertEqual(1);
      expect(filterTopRepos([r1, r2, r3], 'private').length).assertEqual(1);
      expect(filterTopRepos([r1, r2, r3], 'source').length).assertEqual(1);
      expect(filterTopRepos([r1, r2, r3], 'template').length).assertEqual(1);
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
      const p1: WorkProjectItem = { 'id': 'A', 'number': 1, 'title': 'a', 'closed': false, 'template': false, 'createdAt': '2026-07-01T00:00:00Z', 'updatedAt': '2026-08-01T00:00:00Z', 'ownerLogin': 'me' };
      const p2: WorkProjectItem = { 'id': 'B', 'number': 2, 'title': 'b', 'closed': true, 'template': false, 'createdAt': '2026-07-02T00:00:00Z', 'updatedAt': '2026-08-02T00:00:00Z', 'ownerLogin': 'me' };
      const p3: WorkProjectItem = { 'id': 'C', 'number': 3, 'title': 'c', 'closed': false, 'template': false, 'createdAt': '2026-07-03T00:00:00Z', 'updatedAt': '2026-08-03T00:00:00Z', 'ownerLogin': 'other' };
      const p4: WorkProjectItem = { 'id': 'D', 'number': 4, 'title': 'd', 'closed': false, 'template': true, 'createdAt': '2026-07-04T00:00:00Z', 'updatedAt': '2026-08-04T00:00:00Z', 'ownerLogin': 'me' };
      const all = filterWorkProjects([p1, p2, p3, p4], false, 'me', 'open');
      expect(all.length).assertEqual(2);
      const mine = filterWorkProjects([p1, p2, p3, p4], true, 'me', 'open');
      expect(mine.length).assertEqual(1);
      expect(mine[0].id).assertEqual('A');
      const closed = filterWorkProjects([p1, p2, p3, p4], false, 'me', 'closed');
      expect(closed.length).assertEqual(1);
      expect(closed[0].id).assertEqual('B');
      const template = filterWorkProjects([p1, p2, p3, p4], false, 'me', 'template');
      expect(template.length).assertEqual(1);
      expect(template[0].id).assertEqual('D');
      const sortViewed = sortWorkProjects([p1, p2], 'most_viewed', { 'B': 100 });
      expect(sortViewed[0].id).assertEqual('B');
      const sortTitle = sortWorkProjects([p2, p1], 'title_az', {});
      expect(sortTitle[0].id).assertEqual('A');
      const sortCreatedOldest = sortWorkProjects([p1, p2], 'created_oldest', {});
      expect(sortCreatedOldest[0].id).assertEqual('A');
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

    it('markdown_routeOf', 0, () => {
      // 站内仓库 → repoDetail（相对与绝对链接等价）
      expect(MarkdownService.routeOf('/owner/repo')?.name).assertEqual('repoDetail');
      expect(MarkdownService.routeOf('https://github.com/owner/repo')?.param).assertEqual('owner/repo');
      expect(MarkdownService.routeOf('https://github.com/owner/repo/issues/12')?.name).assertEqual('issueDetail');
      expect(MarkdownService.routeOf('/owner/repo/issues/12#L3')?.param).assertEqual('owner/repo/12');
      expect(MarkdownService.routeOf('/owner/repo/pull/7')?.name).assertEqual('prDetail');
      expect(MarkdownService.routeOf('https://github.com/owner/repo/pulls/7')?.name).assertEqual('prDetail');
      expect(MarkdownService.routeOf('/owner/repo/blob/main/src/index.ets')?.name).assertEqual('codeViewer');
      expect(MarkdownService.routeOf('/owner/repo/blob/main/src/index.ets')?.param).assertEqual('owner|repo|main/src/index.ets');
      // 外站/非链接不路由
      expect(MarkdownService.routeOf('https://example.com/a/b')).assertNull();
      expect(MarkdownService.routeOf('mailto:a@b.c')).assertNull();
      expect(MarkdownService.routeOf('#anchor')).assertNull();
      expect(MarkdownService.routeOf('')).assertNull();
      expect(MarkdownService.routeOf('/owner/repo/tree/main')).assertNull();
      expect(MarkdownService.routeOf('/owner')).assertNull();
    });

    it('markdown_shouldCollapse', 0, () => {
      expect(MarkdownService.shouldCollapse(5000, 4000)).assertTrue();
      expect(MarkdownService.shouldCollapse(4000, 4000)).assertFalse();
      expect(MarkdownService.shouldCollapse(10, 4000)).assertFalse();
      // 阈值 0 = 不折叠（评论等短内容）
      expect(MarkdownService.shouldCollapse(5000, 0)).assertFalse();
    });

    it('markdown_bodyHTML_mapping', 0, () => {
      const author: JsonMap = { 'login': 'zm_bad' };
      // 评论：body/bodyHTML 字段映射（顺带防回归：曾误读 description 导致正文恒空）
      const cNode: JsonMap = { 'id': 'C1', 'body': 'plain', 'bodyHTML': '<p>rendered</p>', 'createdAt': '2026-08-02T00:00:00Z', 'author': author };
      const issueComments: JsonMap = { 'totalCount': 1, 'nodes': [cNode] };
      const emptyLabels: JsonMap = { 'nodes': [] };
      const issueNode: JsonMap = {
        'number': 1, 'title': 't', 'state': 'OPEN', 'stateReason': '', 'body': 'body text',
        'bodyHTML': '<p>body html</p>', 'createdAt': '2026-08-01T00:00:00Z', 'author': author,
        'labels': emptyLabels, 'comments': issueComments
      };
      const issueRepo: JsonMap = { 'issue': issueNode };
      const issueData: JsonMap = { 'repository': issueRepo };
      const ip = mapIssueDetail(issueData);
      expect(ip.body).assertEqual('body text');
      expect(ip.bodyHTML).assertEqual('<p>body html</p>');
      expect(ip.comments[0].body).assertEqual('plain');
      expect(ip.comments[0].bodyHTML).assertEqual('<p>rendered</p>');

      const emptyPrComments: JsonMap = { 'totalCount': 0, 'nodes': [] };
      const prNode: JsonMap = {
        'number': 82, 'title': 'fix', 'state': 'MERGED', 'merged': true, 'isDraft': false,
        'body': 'pb', 'bodyHTML': '<p>pr html</p>', 'createdAt': '2026-08-01T00:00:00Z', 'mergedAt': '2026-08-02T00:00:00Z',
        'additions': 1, 'deletions': 1, 'author': author, 'headRefName': 'fix/1', 'baseRefName': 'main',
        'comments': emptyPrComments
      };
      const prRepo: JsonMap = { 'pullRequest': prNode };
      const prData: JsonMap = { 'repository': prRepo };
      const pp = mapPrDetail(prData);
      expect(pp.bodyHTML).assertEqual('<p>pr html</p>');

      const relNode: JsonMap = {
        'id': 'R1', 'tagName': '1.0', 'isLatest': true, 'createdAt': '2026-06-30T00:00:00Z',
        'description': 'short', 'body': 'long body', 'bodyHTML': '<p>release html</p>', 'author': author
      };
      const relNodes: JsonMap = { 'nodes': [relNode] };
      const relRepo: JsonMap = { 'releases': relNodes };
      const relData: JsonMap = { 'repository': relRepo };
      const rp = mapRepoReleasesPage(relData);
      expect(rp.releases[0].body).assertEqual('long body');
      expect(rp.releases[0].bodyHTML).assertEqual('<p>release html</p>');
    });

    it('achievement_parse_full', 0, () => {
      // 官方详情片段（含 tier-badge 图/relative-time/私有仓库 inaccessible 引用）
      const html = `<div class="d-flex flex-column">
<div class="d-flex flex-items-center flex-justify-center tmp-p-3" style="background-image: url('https://x/yolo-detail-9511d3a21745.png')">
<achievement-badge-flip tier-count="1"><img src="https://x/yolo-default-be0bbff04951.png" data-targets="achievement-badge-flip.tiers" width="140" alt="Achievement: YOLO" /></achievement-badge-flip>
</div>
<div class="tmp-p-3"><div class="d-flex flex-items-center"><h3>YOLO</h3></div><div class="mt-1">You want it? You merge it.</div></div>
<div class="achievement-history"><h4>History</h4>
<div class="TimelineItem TimelineItem--condensed achievement-history-unlocked-at">
<div class="TimelineItem-badge"><svg class="octicon octicon-trophy"><path d="x"></path></svg></div>
<div class="TimelineItem-body"><span class="color-fg-success text-bold">100% unlocked</span> · Unlocked
<relative-time datetime="2026-08-31T19:09:34Z" month="short" day="numeric" threshold="PT0S">2026-08-31 19:09:34 UTC</relative-time>
</div></div>
<div class="TimelineItem TimelineItem--condensed achievement-history-tier">
<div class="TimelineItem-badge"><svg class="octicon octicon-dot-fill"><path d="y"></path></svg></div>
<div class="TimelineItem-body"><span class="color-fg-muted">inaccessible</span> · <span>Merged without a review</span></div>
</div></div></div>`;
      const d = parseAchievementDetail(html, 'yolo', 'fallback.png');
      expect(d.name).assertEqual('YOLO');
      expect(d.description).assertEqual('You want it? You merge it.');
      expect(d.badgeImageUrl).assertEqual('https://x/yolo-default-be0bbff04951.png');
      expect(d.unlockedAt).assertEqual('2026-08-31T19:09:34Z');
      // 私有仓库不可见引用 → 隐藏，事件标签保留
      expect(d.events.length).assertEqual(1);
      expect(d.events[0].ref).assertEqual('');
      expect(d.events[0].label).assertEqual('Merged without a review');
    });

    it('achievement_parse_anchor_ref', 0, () => {
      // 公共仓库事件：<a> 引用 + 事件标签
      const html = `<div><h3>YOLO</h3></div><div class="achievement-history-tier"><div class="TimelineItem-body"><a href="https://github.com/ZM-BAD/starraft/pull/3">ZM-BAD/starraft #3</a> · <span>Merged without a review</span></div></div>`;
      const d = parseAchievementDetail(html, 'yolo', 'fb.png');
      expect(d.events[0].ref).assertEqual('ZM-BAD/starraft #3');
      expect(d.events[0].label).assertEqual('Merged without a review');
    });

    it('achievement_parse_multi_tier', 0, () => {
      // 多次达成/多 tier：解析出多条事件（保持顺序）
      const html = `<div><h3>Pair Extraordinaire</h3></div>
<div class="achievement-history-tier"><div class="TimelineItem-body"><a href="https://github.com/ZM-BAD/starraft/pull/1">ZM-BAD/starraft #1</a> · <span>Coauthored with @claude</span></div></div>
<div class="achievement-history-tier"><div class="TimelineItem-body"><span class="color-fg-muted">inaccessible</span> · <span>Coauthored with @claude</span></div></div>`;
      const d = parseAchievementDetail(html, 'pair-extraordinaire', 'fb.png');
      expect(d.events.length).assertEqual(2);
      expect(d.events[0].ref).assertEqual('ZM-BAD/starraft #1');
      expect(d.events[0].label).assertEqual('Coauthored with @claude');
      expect(d.events[1].ref).assertEqual('');
      expect(d.events[1].label).assertEqual('Coauthored with @claude');
    });

    it('achievement_parse_invalid', 0, () => {
      // 无 h3（非预期结构）→ 抛错由服务层/页面兜底
      let caught = false;
      try {
        parseAchievementDetail('<div>no h3 here</div>', 'yolo', 'fb.png');
      } catch (e) {
        caught = true;
      }
      expect(caught).assertTrue();
    });

    it('achievement_parse_no_time', 0, () => {
      // 无 relative-time/无事件行时字段置空，不崩溃
      const html = `<img src="x.png" data-targets="achievement-badge-flip.tiers" /><h3>Starstruck</h3><div class="mt-1">d</div>`;
      const d = parseAchievementDetail(html, 'starstruck', 'fb.png');
      expect(d.name).assertEqual('Starstruck');
      expect(d.unlockedAt).assertEqual('');
      expect(d.badgeImageUrl).assertEqual('x.png');
    });

    it('achievement_slugs_dedup', 0, () => {
      const html = `?achievement=yolo&amp;tab=achievements then ?achievement=quickdraw&amp;tab and yolo again`;
      const slugs = extractAchievementSlugs(html);
      expect(slugs.length).assertEqual(2);
      expect(slugs[0]).assertEqual('yolo');
      expect(slugs[1]).assertEqual('quickdraw');
    });

    it('unlockDateText_valid', 0, () => {
      // 设备语言相关，仅断言非空（本地「月 日」）
      expect(unlockDateText('2026-08-31T19:09:34Z') !== '').assertTrue();
      expect(unlockDateText('not-a-date')).assertEqual('');
    });

    it('mapFork_full', 0, () => {
      const langNode: JsonMap = { 'name': 'TypeScript', 'color': '#3178C6' };
      const pOwner: JsonMap = { 'login': 'ZM-BAD' };
      const parentNode: JsonMap = { 'name': 'DAG-chat', 'owner': pOwner };
      const forkOwner: JsonMap = { 'login': 'yjnzen', 'avatarUrl': 'https://x/av.png' };
      const node: JsonMap = {
        'name': 'DAG-chat',
        'description': 'Chat applications that use DAG',
        'stargazerCount': 0,
        'primaryLanguage': langNode,
        'parent': parentNode,
        'owner': forkOwner
      };
      const f = mapFork(node);
      expect(f.name).assertEqual('DAG-chat');
      expect(f.nameWithOwner).assertEqual('yjnzen/DAG-chat');
      expect(f.ownerLogin).assertEqual('yjnzen');
      expect(f.primaryLanguage).assertEqual('TypeScript');
      expect(f.languageColor).assertEqual('#3178C6');
      expect(f.parentNameWithOwner).assertEqual('ZM-BAD/DAG-chat');
    });

    it('mapFork_nullParent', 0, () => {
      // 上游不可见/无语言 → 置空（UI 隐藏 Forked from / 语言段）
      const forkOwner: JsonMap = { 'login': 'o', 'avatarUrl': '' };
      const node: JsonMap = {
        'name': 'R', 'description': '', 'stargazerCount': 1,
        'owner': forkOwner
      };
      const f = mapFork(node);
      expect(f.parentNameWithOwner).assertEqual('');
      expect(f.primaryLanguage).assertEqual('');
    });

    it('mapStargazerPage_conn', 0, () => {
      const stargazerNode: JsonMap = { 'login': 'a', 'name': 'A', 'bio': 'b', 'avatarUrl': 'u' };
      const pageInfo: JsonMap = { 'hasNextPage': true, 'endCursor': 'CURSOR' };
      const stargazers: JsonMap = { 'pageInfo': pageInfo, 'nodes': [stargazerNode] };
      const repoNode: JsonMap = { 'stargazers': stargazers };
      const data: JsonMap = { 'repository': repoNode };
      const page = mapStargazerPage(data);
      expect(page.users.length).assertEqual(1);
      expect(page.users[0].login).assertEqual('a');
      expect(page.users[0].bio).assertEqual('b');
      expect(page.hasNextPage).assertTrue();
      expect(page.endCursor).assertEqual('CURSOR');
    });
  });
}
