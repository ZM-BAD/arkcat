/**
 * 仪器测试：格式化工具与模型映射（纯函数）。
 * 运行于模拟器（aa test），与主代码同一编译单元，可直接 import main ets。
 */
import { describe, it, expect } from '@ohos/hypium';
import { unlockDateText } from '../../../main/ets/utils/Format';
import { mapRepoPr, mapRepoPrsPage, mapRepoCommitsPage, mapRepoReleasesPage, mapIssueDetail, mapPrDetail, filterPrsByAuthor, filterPrsByAssignee, repoPrIconKey, monthDayText } from '../../../main/ets/models/RepoSubModels';
import { repoIssueStates } from '../../../main/ets/services/IssuesService';
import { RepoPrItem } from '../../../main/ets/models/RepoSubModels';
import { buildWorkIssuesQuery, buildWorkPrsQuery, buildWorkDiscussionsQuery, buildTopReposPrivacy, mapWorkIssue, workIssueIconKey, mapWorkPr, workPrIconKey, mapWorkStarredPage, filterWorkProjects, sortWorkProjects, filterTopRepos, WorkTopRepoItem, WorkProjectItem, mapWorkProjectsPage, mapWorkTopReposPage, mapWorkOrgsPage } from '../../../main/ets/models/WorkModels';
import { mapUser, mapRepo, mapViewerBasic, mapNotifications, issueNumberFromUrl } from '../../../main/ets/models/GitHubModels';
import { buildPrDetailsQuery } from '../../../main/ets/services/ExploreService';
import { mapActivityEvents, mapActivityEventsWithDetails, summarizeBody, ActivityPrRef } from '../../../main/ets/models/ExploreModels';
import { mapUserProfile, isSelfProfile } from '../../../main/ets/models/ProfileModels';
import { mapRepoDetail, nextStarAction } from '../../../main/ets/models/RepoDetailModels';
import { mapFork, mapStargazerPage, mapWatcherPage, mapContributorPage } from '../../../main/ets/models/RepoSocialModels';
import { mapLicenseInfo, stripLicenseTitle } from '../../../main/ets/models/RepoLicenseModels';
import { mapReleaseDetail, mapReactionUsersPage } from '../../../main/ets/models/RepoSubModels';
import { mapIssue, mapIssuesPage, issueOrderField } from '../../../main/ets/models/IssuesModels';
import { ReactionGroup, REACTION_META, reactionEmoji, findReactionGroup, flipReactionGroups } from '../../../main/ets/models/RepoSubModels';
import { MarkdownEdit } from '../../../main/ets/utils/MarkdownEdit';
import { parsePollResponse, OAuthPollState } from '../../../main/ets/services/OAuthService';

type JsonMap = Record<string, Object>;

const NOW = Date.parse('2026-08-31T12:00:00Z');

export default function logicTest(testsuiteName: string) {
  describe(testsuiteName, () => {


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
        'name': 'arkcat',
        'nameWithOwner': 'zm_bad/arkcat',
        'owner': owner
      };
      const repo = mapRepo(raw);
      expect(repo.name).assertEqual('arkcat');
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


    it('issueNumberFromUrl_extract', 0, () => {
      expect(issueNumberFromUrl('/repos/a/b/issues/82')).assertEqual('82');
      expect(issueNumberFromUrl('/repos/a/b/pull/456')).assertEqual('456');
      // GitHub 通知 subject.url 为完整 URL
      expect(issueNumberFromUrl('https://api.github.com/repos/a/b/issues/82')).assertEqual('82');
      expect(issueNumberFromUrl('/repos/a/b/commits/deadbeef')).assertEqual('');
      expect(issueNumberFromUrl('')).assertEqual('');
    });


    it('mapActivityEvents_mergedOnly_dedupe', 0, () => {
      // 嵌套结构经 JSON.parse 构造（ohosTest 禁无类型嵌套字面量）
      const prEvent = (repoName: string, number: number, action: string): JsonMap => {
        const raw = `{"type":"PullRequestEvent","id":"e_${repoName}_${number}",` +
          `"created_at":"2026-09-05T18:51:20Z",` +
          `"actor":{"login":"alice","avatar_url":"https://a/1"},` +
          `"org":{"avatar_url":"https://o/1"},"repo":{"name":"${repoName}"},` +
          `"payload":{"action":"${action}","number":${number},` +
          `"pull_request":{"number":${number},"head":{"ref":"feature/x"}}}}`;
        return JSON.parse(raw) as JsonMap;
      };
      const push = JSON.parse('{"type":"PushEvent"}') as JsonMap;
      const events: Object[] = [
        prEvent('a/b', 1, 'merged'),
        push,
        prEvent('a/b', 2, 'opened'),
        prEvent('a/b', 1, 'merged'),
        prEvent('c/d', 3, 'closed'),
        prEvent('c/d', 4, 'merged')
      ];
      const refs = mapActivityEvents(events);
      expect(refs.length).assertEqual(2);
      expect(refs[0].repoFullName).assertEqual('a/b');
      expect(refs[0].number).assertEqual(1);
      expect(refs[0].actorLogin).assertEqual('alice');
      expect(refs[0].orgAvatar).assertEqual('https://o/1');
      expect(refs[0].headRef).assertEqual('feature/x');
      expect(refs[1].number).assertEqual(4);
    });

    it('mapActivityEvents_cap10', 0, () => {
      const events: Object[] = [];
      for (let i = 1; i <= 15; i++) {
        const raw = `{"type":"PullRequestEvent","id":"e${i}","repo":{"name":"a/b"},` +
          `"payload":{"action":"merged","number":${i},"pull_request":{"number":${i}}}}`;
        events.push(JSON.parse(raw) as JsonMap);
      }
      expect(mapActivityEvents(events).length).assertEqual(10);
    });

    it('buildPrDetailsQuery_alias_escape', 0, () => {
      const normal: ActivityPrRef = {
        eventId: 'e1', repoFullName: 'a/b', number: 7, headRef: 'f',
        actorLogin: '', actorAvatar: '', orgAvatar: '', createdAt: ''
      };
      const weird: ActivityPrRef = {
        eventId: 'e2', repoFullName: 'o/ha"ck', number: 8, headRef: '',
        actorLogin: '', actorAvatar: '', orgAvatar: '', createdAt: ''
      };
      const q = buildPrDetailsQuery([normal, weird]);
      expect(q.startsWith('query ExploreActivity {')).assertTrue();
      expect(q.includes('r0: repository(owner: "a", name: "b")')).assertTrue();
      expect(q.includes('pullRequest(number: 7)')).assertTrue();
      expect(q.includes('pullRequest(number: 8)')).assertTrue();
      expect(q.includes('name: "ha\\"ck"')).assertTrue();
      expect(q.includes('headRefName')).assertTrue();
      expect(q.includes('baseRefName')).assertTrue();
    });

    it('mapActivityEventsWithDetails_merge_fallback', 0, () => {
      const refs: ActivityPrRef[] = [{
        eventId: 'e1', repoFullName: 'a/b', number: 7, headRef: 'feature/x',
        actorLogin: 'alice', actorAvatar: 'https://a/1', orgAvatar: '', createdAt: '2026-09-05T18:51:20Z'
      }];
      const data = JSON.parse(`{"r0":{"pullRequest":{"id":"PR_1","title":"T","body":"- x","merged":true,` +
        `"headRefName":"feature/x","baseRefName":"main",` +
        `"author":{"login":"bob","avatarUrl":"https://b/2"},` +
        `"reactionGroups":[{"content":"THUMBS_UP","viewerHasReacted":false,` +
        `"reactors":{"totalCount":3}}]}}}`) as JsonMap;
      const out = mapActivityEventsWithDetails(refs, data);
      expect(out.length).assertEqual(1);
      expect(out[0].key).assertEqual('a/b/7');
      expect(out[0].title).assertEqual('T');
      expect(out[0].authorLogin).assertEqual('bob');
      expect(out[0].subjectId).assertEqual('PR_1');
      expect(out[0].reactions.length).assertEqual(1);
      expect(out[0].reactions[0].count).assertEqual(3);
      expect(out[0].headRef).assertEqual('feature/x');
      expect(out[0].baseRef).assertEqual('main');
      // alias 缺失（PR 已删）→ 剔除
      expect(mapActivityEventsWithDetails(refs, { } as JsonMap).length).assertEqual(0);
      // author 空 → 回退事件 actor
      const noAuthor = JSON.parse(`{"r0":{"pullRequest":{"id":"PR_1","title":"T","body":"",` +
        `"merged":true,"author":null,"reactionGroups":[]}}}`) as JsonMap;
      const out2 = mapActivityEventsWithDetails(refs, noAuthor);
      expect(out2.length).assertEqual(1);
      expect(out2[0].authorLogin).assertEqual('alice');
      expect(out2[0].authorAvatar).assertEqual('https://a/1');
    });

    it('summarizeBody_parse', 0, () => {
      const body = [
        '## Summary',
        '',
        '- replace `linkit@0.1.19` as owner',
        '- see [docs](https://example.com) for more',
        '![img](https://x/y.png)',
        '```rust',
        'let x = 1;',
        '```',
        '> quote',
        'plain line'
      ].join('\n');
      const lines = summarizeBody(body);
      // 标题/空行/图片行/围栏标记/引用行剥除，剩 bullet×2 + 围栏内容 + 普通行
      expect(lines.length).assertEqual(4);
      expect(lines[0].bullet).assertTrue();
      expect(lines[0].segments.length).assertEqual(3);
      expect(lines[0].segments[0].text).assertEqual('replace ');
      expect(lines[0].segments[1].isCode).assertTrue();
      expect(lines[0].segments[1].text).assertEqual('linkit@0.1.19');
      expect(lines[0].segments[2].text).assertEqual(' as owner');
      expect(lines[1].segments[0].text).assertEqual('see docs for more');
      expect(lines[2].segments[0].isCode).assertTrue();
      expect(lines[2].segments[0].text).assertEqual('let x = 1;');
      expect(lines[3].bullet).assertFalse();
      expect(lines[3].segments[0].text).assertEqual('plain line');
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
      const readmeBlob: JsonMap = { 'text': '# ArkCat' };
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
        'name': 'arkcat',
        'nameWithOwner': 'zm_bad/arkcat',
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
      expect(detail.name).assertEqual('arkcat');
      expect(detail.licenseName).assertEqual('MIT License');
      expect(detail.topics[0]).assertEqual('arkts');
      expect(detail.readmeText).assertEqual('# ArkCat');
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


    it('workQueries_builders', 0, () => {
      expect(buildWorkIssuesQuery('all', 'created', 'all', 'newest', [], []))
        .assertEqual('is:issue author:@me sort:created-desc');
      expect(buildWorkIssuesQuery('open', 'assigned', 'public', 'most_commented', ['ZM-BAD'], ['ZM-BAD/arkcat']))
        .assertEqual('is:issue is:open assignee:@me is:public org:ZM-BAD repo:ZM-BAD/arkcat sort:comments-desc');
      expect(buildWorkIssuesQuery('closed', 'involved', 'private', 'reactions:+1', [], []))
        .assertEqual('is:issue is:closed involves:@me is:private sort:reactions-+1-desc');
      expect(buildWorkIssuesQuery('open', 'created', 'all', 'least_recently_updated', [], []))
        .assertEqual('is:issue is:open author:@me sort:updated-asc');
      expect(buildWorkPrsQuery('merged', 'created', 'private', 'newest', [], []))
        .assertEqual('is:pr is:merged author:@me is:private sort:created-desc');
      expect(buildWorkPrsQuery('queued', 'review_requested', 'all', 'most_commented', ['ZM-BAD'], ['ZM-BAD/arkcat']))
        .assertEqual('is:pr is:queued review-requested:@me org:ZM-BAD repo:ZM-BAD/arkcat sort:comments-desc');
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
      expect(workPrIconKey('OPEN', false, false)).assertEqual('open');
      expect(workPrIconKey('OPEN', false, true)).assertEqual('draft');
      expect(workPrIconKey('CLOSED', false, false)).assertEqual('closed');
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
      expect(repoPrIconKey('MERGED', true, false)).assertEqual('merged');
      expect(repoPrIconKey('OPEN', false, false)).assertEqual('open');
      expect(repoPrIconKey('OPEN', false, true)).assertEqual('draft');
      expect(repoPrIconKey('CLOSED', false, false)).assertEqual('closed');

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

    it('mapWatcherPage_conn', 0, () => {
      const watcherNode: JsonMap = { 'login': 'w', 'name': 'W', 'bio': 'b', 'avatarUrl': 'u' };
      const pageInfo: JsonMap = { 'hasNextPage': false, 'endCursor': '' };
      const watchers: JsonMap = { 'pageInfo': pageInfo, 'nodes': [watcherNode] };
      const repoNode: JsonMap = { 'watchers': watchers };
      const data: JsonMap = { 'repository': repoNode };
      const page = mapWatcherPage(data);
      expect(page.users.length).assertEqual(1);
      expect(page.users[0].login).assertEqual('w');
      expect(page.users[0].name).assertEqual('W');
      expect(page.hasNextPage).assertFalse();
    });

    it('mapContributorPage_merge', 0, () => {
      // REST 原序 + GraphQL 补全（key=login）：name/bio 覆盖，顺序保持
      const restA: JsonMap = { 'login': 'a', 'avatar_url': 'av-a' };
      const restB: JsonMap = { 'login': 'b', 'avatar_url': 'av-b' };
      const gqlA: JsonMap = { 'login': 'a', 'name': 'User A', 'bio': 'bio about A', 'avatarUrl': 'av-a' };
      const meta = new Map<string, JsonMap>();
      meta.set('a', gqlA);
      const restArr: JsonMap[] = [restA, restB];
      const page = mapContributorPage(restArr, meta, 1);
      expect(page.users.length).assertEqual(2);
      expect(page.users[0].login).assertEqual('a');
      expect(page.users[0].name).assertEqual('User A');
      expect(page.users[0].bio).assertEqual('bio about A');
      expect(page.users[1].login).assertEqual('b');
      expect(page.users[1].name).assertEqual('');
      expect(page.users[1].avatarUrl).assertEqual('av-b');
      expect(page.hasNextPage).assertFalse();
      expect(page.endCursor).assertEqual('2');
    });

    it('mapContributorPage_fullPage', 0, () => {
      // 长度=per_page(50) → 认为可能还有下一页（REST 无 Link 头透出的近似判断）
      const restNodes: JsonMap[] = [];
      for (let i = 0; i < 50; i++) {
        const n: JsonMap = { 'login': `u${i}`, 'avatar_url': '' };
        restNodes.push(n);
      }
      const page = mapContributorPage(restNodes, new Map<string, JsonMap>(), 2);
      expect(page.users.length).assertEqual(50);
      expect(page.hasNextPage).assertTrue();
      expect(page.endCursor).assertEqual('3');
    });

    it('mapLicenseInfo_full', 0, () => {
      const info: JsonMap = { 'name': 'MIT License', 'spdxId': 'MIT', 'body': 'MIT License\n\nCopyright (c) 2026 A\n' };
      const repoNode: JsonMap = { 'licenseInfo': info };
      const data: JsonMap = { 'repository': repoNode };
      const license = mapLicenseInfo(data);
      expect(license !== null).assertTrue();
      if (license !== null) {
        expect(license.name).assertEqual('MIT License');
        expect(license.spdxId).assertEqual('MIT');
        expect(license.body.length > 0).assertTrue();
      }
    });

    it('mapLicenseInfo_null', 0, () => {
      const repoNode: JsonMap = {};
      const data: JsonMap = { 'repository': repoNode };
      const license = mapLicenseInfo(data);
      expect(license === null).assertTrue();
    });

    it('stripLicenseTitle_mit', 0, () => {
      const body = 'MIT License\n\nCopyright (c) 2026 A\n\nPermission is hereby granted';
      const stripped = stripLicenseTitle('MIT License', body);
      expect(stripped.startsWith('Copyright')).assertTrue();
      expect(stripped.indexOf('MIT License')).assertEqual(-1);
      // name 为空 → 原样返回
      expect(stripLicenseTitle('', body)).assertEqual(body);
    });


    // ─────── Spec 047：Release 详情映射 / 字节格式化 ───────

    it('mapReleaseDetail_full', 0, () => {
      const asset: JsonMap = {
        'id': 'a1', 'name': 'app.zip', 'size': 1048576, 'downloadCount': 9,
        'contentType': 'application/zip', 'url': 'https://api.github.com/.../a1',
        'browserDownloadUrl': 'https://github.com/.../app.zip'
      };
      const assetsWrap: JsonMap = { 'nodes': [asset] };
      const author: JsonMap = { 'login': 'alice', 'avatarUrl': 'av-a' };
      const releaseNode: JsonMap = {
        'id': 'r1', 'tagName': 'v1.2.0', 'name': 'v1.2.0', 'isDraft': false,
        'isPrerelease': true, 'publishedAt': '2026-09-01T10:00:00Z', 'createdAt': '2026-09-01T09:00:00Z',
        'url': 'https://github.com/o/r/releases/tag/v1.2.0',
        'author': author, 'body': 'b', 'bodyHTML': '<p>b</p>', 'releaseAssets': assetsWrap
      };
      const repoWrap: JsonMap = { 'release': releaseNode };
      const data: JsonMap = { 'repository': repoWrap };
      const page = mapReleaseDetail(data);
      expect(page !== null).assertTrue();
      if (page !== null) {
        expect(page.tagName).assertEqual('v1.2.0');
        expect(page.isPrerelease).assertTrue();
        expect(page.releaseUrl).assertEqual('https://github.com/o/r/releases/tag/v1.2.0');
        expect(page.assets.length).assertEqual(1);
        expect(page.assets[0].name).assertEqual('app.zip');
        expect(page.assets[0].size).assertEqual(1048576);
      }
    });
    it('mapReleaseDetail_null', 0, () => {
      const repoWrap: JsonMap = {};
      const data: JsonMap = { 'repository': repoWrap };
      const page = mapReleaseDetail(data);
      expect(page === null).assertTrue();
    });
    it('mapReactionUsersPage_picksContent', 0, () => {
      const reactor: JsonMap = { 'login': 'alice', 'name': 'Alice', 'avatarUrl': 'av-a' };
      const pageInfo: JsonMap = { 'hasNextPage': true, 'endCursor': 'c1' };
      const reactors: JsonMap = { 'totalCount': 2, 'pageInfo': pageInfo, 'nodes': [reactor] };
      const group: JsonMap = { 'content': 'THUMBS_UP', 'reactors': reactors };
      const node: JsonMap = { 'reactionGroups': [group] };
      const data: JsonMap = { 'node': node };
      const page = mapReactionUsersPage(data, 'THUMBS_UP');
      expect(page.totalCount).assertEqual(2);
      expect(page.users.length).assertEqual(1);
      expect(page.users[0].name).assertEqual('Alice');
      expect(page.hasNextPage).assertTrue();
      expect(page.endCursor).assertEqual('c1');
      const miss = mapReactionUsersPage(data, 'HEART');
      expect(miss.users.length).assertEqual(0);
    });

    // ─────── Spec 041：Markdown 工具栏插入 / 反应 / 评论映射 ───────

    it('markdownEdit_wrap_selected', 0, () => {
      const ins = MarkdownEdit.apply('abc', 0, 3, 'bold');
      expect(ins.text).assertEqual('**abc**');
      expect(ins.selStart).assertEqual(0);
      expect(ins.selEnd).assertEqual(7);
    });
    it('markdownEdit_wrap_empty', 0, () => {
      // 未选中：插入对，光标居中
      const ins = MarkdownEdit.apply('', 0, 0, 'code');
      expect(ins.text).assertEqual('``');
      expect(ins.selStart).assertEqual(1);
      expect(ins.selEnd).assertEqual(1);
    });
    it('markdownEdit_quote_lines', 0, () => {
      const ins = MarkdownEdit.apply('a\nb', 0, 3, 'quote');
      expect(ins.text).assertEqual('> a\n> b');
      expect(ins.selStart).assertEqual(0);
      expect(ins.selEnd).assertEqual(7);
    });
    it('markdownEdit_task_empty', 0, () => {
      const ins = MarkdownEdit.apply('', 0, 0, 'task');
      expect(ins.text).assertEqual('- [ ] ');
      expect(ins.selStart).assertEqual(6);
      expect(ins.selEnd).assertEqual(6);
    });
    it('markdownEdit_link_selected', 0, () => {
      const ins = MarkdownEdit.apply('hello', 0, 5, 'link');
      expect(ins.text).assertEqual('[hello]()');
      expect(ins.selStart).assertEqual(8);
      expect(ins.selEnd).assertEqual(8);
    });
    it('markdownEdit_link_empty', 0, () => {
      const ins = MarkdownEdit.apply('', 0, 0, 'link');
      expect(ins.text).assertEqual('[]()');
      expect(ins.selStart).assertEqual(3);
      expect(ins.selEnd).assertEqual(3);
    });
    it('markdownEdit_swap_selection', 0, () => {
      // 反向选区（start>end）应归一化
      const ins = MarkdownEdit.apply('abc', 3, 0, 'bold');
      expect(ins.text).assertEqual('**abc**');
      expect(ins.selEnd).assertEqual(7);
    });

    it('reactionMeta_8', 0, () => {
      expect(REACTION_META.length).assertEqual(8);
      expect(reactionEmoji('THUMBS_UP')).assertEqual('👍');
      expect(reactionEmoji('EYES')).assertEqual('👀');
      expect(reactionEmoji('NOPE')).assertEqual('');
    });
    it('flipReactionGroups_toggle', 0, () => {
      const groups: ReactionGroup[] = [{ content: 'THUMBS_UP', count: 3, viewerHasReacted: false, users: [] }];
      const added = flipReactionGroups(groups, 'THUMBS_UP', true);
      expect(added[0].count).assertEqual(4);
      expect(added[0].viewerHasReacted).assertTrue();
      const removed = flipReactionGroups(added, 'THUMBS_UP', false);
      expect(removed[0].count).assertEqual(3);
      expect(removed[0].viewerHasReacted).assertFalse();
    });
    it('flipReactionGroups_addNew', 0, () => {
      const groups: ReactionGroup[] = [];
      const added = flipReactionGroups(groups, 'EYES', true);
      expect(added.length).assertEqual(1);
      expect(added[0].content).assertEqual('EYES');
      expect(added[0].count).assertEqual(1);
      expect(added[0].viewerHasReacted).assertTrue();
      expect(findReactionGroup(added, 'HOORAY') === null).assertTrue();
    });

    it('mapIssueDetail_reactions', 0, () => {
      const authorI: JsonMap = { 'login': 'alice', 'avatarUrl': 'av-a' };
      const commentAuthor: JsonMap = { 'login': 'bob', 'avatarUrl': 'av-b' };
      const reactUser: JsonMap = { 'login': 'bob', 'avatarUrl': 'av-b' };
      const reactUsers: JsonMap = { 'totalCount': 2, 'nodes': [reactUser] };
      const reactGroup: JsonMap = {
        'content': 'THUMBS_UP', 'viewerHasReacted': true, 'reactors': reactUsers
      };
      const commentNode: JsonMap = {
        'id': 'c1', 'body': 'hi', 'bodyHTML': '<p>hi</p>', 'createdAt': '2026-09-01T11:00:00Z',
        'author': commentAuthor, 'viewerDidAuthor': true, 'reactionGroups': [reactGroup]
      };
      const labelsWrap: JsonMap = { 'nodes': [] };
      const pageInfoWrap: JsonMap = { 'hasNextPage': false, 'endCursor': 'x' };
      const commentsWrap: JsonMap = { 'totalCount': 1, 'pageInfo': pageInfoWrap, 'nodes': [commentNode] };
      const issueNode: JsonMap = {
        'id': 'i1', 'number': 3, 'title': 'issue', 'state': 'OPEN', 'stateReason': '',
        'body': '', 'bodyHTML': '', 'createdAt': '2026-09-01T10:00:00Z',
        'author': authorI, 'labels': labelsWrap, 'comments': commentsWrap
      };
      const repoWrap: JsonMap = { 'issue': issueNode };
      const data: JsonMap = { 'repository': repoWrap };
      const page = mapIssueDetail(data);
      expect(page.subjectId).assertEqual('i1');
      expect(page.comments.length).assertEqual(1);
      expect(page.comments[0].viewerDidAuthor).assertTrue();
      expect(page.comments[0].reactions.length).assertEqual(1);
      expect(page.comments[0].reactions[0].count).assertEqual(2);
      expect(page.comments[0].reactions[0].viewerHasReacted).assertTrue();
      expect(page.comments[0].reactions[0].users[0].login).assertEqual('bob');
    });
    it('mapPrDetail_subjectId', 0, () => {
      const prAuthor: JsonMap = { 'login': 'a', 'avatarUrl': '' };
      const commentsWrap: JsonMap = { 'totalCount': 0, 'nodes': [] };
      const filesWrap: JsonMap = { 'totalCount': 0 };
      const commitsWrap: JsonMap = { 'totalCount': 0 };
      const reviewsWrap: JsonMap = { 'totalCount': 0 };
      const node: JsonMap = {
        'id': 'p1', 'number': 7, 'title': 'pr', 'state': 'OPEN', 'merged': false, 'isDraft': false,
        'body': '', 'bodyHTML': '', 'createdAt': '2026-09-01T10:00:00Z', 'mergedAt': '',
        'additions': 0, 'deletions': 0, 'author': prAuthor,
        'headRefName': '', 'baseRefName': '',
        'files': filesWrap, 'commits': commitsWrap,
        'reviews': reviewsWrap,
        'comments': commentsWrap
      };
      const repoWrap: JsonMap = { 'pullRequest': node };
      const data: JsonMap = { 'repository': repoWrap };
      const page = mapPrDetail(data);
      expect(page.subjectId).assertEqual('p1');
      expect(page.comments.length).assertEqual(0);
    });
    it('oauthPoll_pending', 0, () => {
      const r = parsePollResponse({ 'error': 'authorization_pending' } as JsonMap, 5);
      expect(r.state).assertEqual(OAuthPollState.PENDING);
      expect(r.token).assertEqual('');
      expect(r.nextInterval).assertEqual(5);
    });
    it('oauthPoll_slowDown', 0, () => {
      const r = parsePollResponse({ 'error': 'slow_down' } as JsonMap, 5);
      expect(r.state).assertEqual(OAuthPollState.SLOW_DOWN);
      expect(r.nextInterval).assertEqual(10);
      expect(r.token).assertEqual('');
    });
    it('oauthPoll_expired', 0, () => {
      const r = parsePollResponse({ 'error': 'expired_token' } as JsonMap, 5);
      expect(r.state).assertEqual(OAuthPollState.EXPIRED);
    });
    it('oauthPoll_denied', 0, () => {
      const r = parsePollResponse({ 'error': 'access_denied' } as JsonMap, 5);
      expect(r.state).assertEqual(OAuthPollState.DENIED);
    });
    it('oauthPoll_success', 0, () => {
      const r = parsePollResponse({ 'access_token': 'gho_test' } as JsonMap, 5);
      expect(r.state).assertEqual(OAuthPollState.SUCCESS);
      expect(r.token).assertEqual('gho_test');
    });
    it('oauthPoll_unknownError', 0, () => {
      const r = parsePollResponse({ 'error': 'unsupported_grant_type' } as JsonMap, 5);
      expect(r.state).assertEqual(OAuthPollState.ERROR);
    });
  });
}
