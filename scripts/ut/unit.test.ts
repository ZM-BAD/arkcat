/**
 * ArkCat 宿主单元测试（node:test + esbuild 打包 ArkTS 纯函数链）。
 * 运行：bash scripts/ut/run-local-tests.sh（CI / pre-commit 同入口）。
 * 覆盖：utils/Json、utils/Format、utils/Diff、utils/WorkConfig、
 * models/RepoSubModels（映射/过滤/图标）、models/PrDiffModels（files 映射/patch 回填）。
 *
 * 边界说明：被测代码运行在宿主机 Node（非 HOS 运行时），
 * 因此只测纯函数/纯映射；系统调用（intl 格式化等）由 UI 层负责，不在本层。
 */
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { Json, JsonMap } from '../../entry/src/main/ets/utils/Json';
import {
  timeParts, githubShortTime, compactCount, notificationTypeKey, TimeParts
} from '../../entry/src/main/ets/utils/Format';
import { parseDiffPatch, fileBaseName } from '../../entry/src/main/ets/utils/Diff';
import {
  defaultWorkSections, visibleWorkSections, workSectionsToStorage, workSectionsFromStorage,
  WorkSection
} from '../../entry/src/main/ets/utils/WorkConfig';
import {
  mapRepoCommit, mapRepoCommitsPage, mapPrCommits,
  filterPrsByAuthor, filterPrsByAssignee, repoPrIconKey, RepoPrItem, mapIssueDetail
} from '../../entry/src/main/ets/models/RepoSubModels';
import { mapPrFiles, mapFilesCursor, applyRestPatch, PrFileItem } from '../../entry/src/main/ets/models/PrDiffModels';
import {
  buildNotificationsPath, pullRefFromUrl, buildPullStatesQuery, mapPullMerged,
  filterByReasons, filterByInboxView, collectRepoFilters, NotificationItem, PrRef
} from '../../entry/src/main/ets/services/NotificationsService';
import {
  buildQualifierInsert, pushSearchHistory, buildSearchQuery, formatBigCount, isLightHexColor,
  mapSearchNode, mapSearchResults, mapSearchOverview, buildCodeQuery, mapCodeSearch
} from '../../entry/src/main/ets/services/SearchService';
import {
  buildCodeSnippet, splitLines, buildFragmentLines,
  parseCodeSearchItem, fileBadgeKey, RawMatch
} from '../../entry/src/main/ets/services/CodeSearchService';
import {
  buildTrendingPath, buildAwesomePath, buildRepoListPath, mapSearchRepos,
  contributorCount, buildRepoMetaQuery, mapRepoMeta
} from '../../entry/src/main/ets/services/ExploreService';
import { RepoSummary } from '../../entry/src/main/ets/models/GitHubModels';
import { MarkdownService } from '../../entry/src/main/ets/services/MarkdownService';
import { parseAchievementDetail, extractAchievementSlugs } from '../../entry/src/main/ets/models/AchievementModels';

const NOW = Date.parse('2026-08-31T12:00:00Z');
const MINUTE_MS = 60 * 1000;
const HOUR_MS = 60 * MINUTE_MS;
const DAY_MS = 24 * HOUR_MS;

function json(): JsonMap {
  return { 'a': 'x', 'n': 5, 'b': true, 'obj': { 'k': 'v' }, 'arr': [1, 2] };
}

function prRow(id: string, authorLogin: string, assignees: string[] = []): RepoPrItem {
  return {
    id: id, repoName: 'r', repoFullName: 'o/r', number: 1, title: 't', state: 'OPEN',
    merged: false, labels: [], authorLogin: authorLogin, assignees: assignees
  } as RepoPrItem;
}

function fileItem(path: string, patch: string = ''): PrFileItem {
  return {
    path: path, additions: 0, deletions: 0, status: 'ADDED', patch: patch,
    hunks: [], diffTooLarge: false, isBinary: false, expanded: false
  };
}

// ─────────────── Json ───────────────

test('Json.str/num/bool 缺失或类型不符回退默认', () => {
  assert.equal(Json.str(json(), 'a'), 'x');
  assert.equal(Json.str(json(), 'missing'), '');
  assert.equal(Json.str(json(), 'missing', 'd'), 'd');
  assert.equal(Json.str(json(), 'n'), '');
  assert.equal(Json.num(json(), 'n'), 5);
  assert.equal(Json.num(json(), 'a'), 0);
  assert.equal(Json.bool(json(), 'b'), true);
  assert.equal(Json.bool(json(), 'missing', true), true);
  assert.equal(Json.bool(json(), 'a'), false);
});

test('Json.obj/arr 兜底', () => {
  assert.ok(Json.obj(json(), 'obj') !== null);
  assert.equal(Json.obj(json(), 'missing'), null);
  assert.equal((Json.arr(json(), 'arr') as Object[]).length, 2);
  assert.equal((Json.arr(json(), 'missing') as Object[]).length, 0);
});

test('Json.parse 合法对象返回 JsonMap', () => {
  const parsed = Json.parse('{"k":"v","n":1}');
  assert.ok(parsed !== null);
  assert.equal(Json.str(parsed as JsonMap, 'k'), 'v');
});

test('Json.parse 非对象 JSON 返回 null（42/"x"/null）', () => {
  assert.equal(Json.parse('42'), null);
  assert.equal(Json.parse('"x"'), null);
  assert.equal(Json.parse('null'), null);
});

test('Json.parse 数组视为对象（与实现语义一致）', () => {
  assert.ok(Json.parse('[1,2]') !== null);
});

test('Json.parse 非法 JSON 返回 null', () => {
  assert.equal(Json.parse('{bad json'), null);
  assert.equal(Json.parse(''), null);
});

// ─────────────── Format ───────────────

test('timeParts 各档位', () => {
  assert.equal(timeParts('2026-08-31T11:59:50Z', NOW)?.unit, 'just_now');
  assert.equal(timeParts('2026-08-31T11:55:00Z', NOW)?.value, 5);
  assert.equal(timeParts('2026-08-31T09:00:00Z', NOW)?.unit, 'hour');
  assert.equal(timeParts('2026-08-01T12:00:00Z', NOW)?.unit, 'day' as string);
  assert.equal(timeParts('2026-05-31T12:00:00Z', NOW)?.value, 3);
  assert.equal(timeParts('2026-05-31T12:00:00Z', NOW)?.unit, 'month' as string);
  assert.equal(timeParts('2025-08-31T12:00:00Z', NOW)?.unit, 'year' as string);
  assert.equal(timeParts('bad-date', NOW), null);
});

test('timeParts 边界：整分钟/整 30 天/31 天/未来时间', () => {
  assert.equal(timeParts(new Date(NOW - MINUTE_MS).toISOString(), NOW)?.value, 1);
  assert.equal(timeParts(new Date(NOW - 30 * DAY_MS).toISOString(), NOW)?.unit, 'day' as string);
  assert.equal(timeParts(new Date(NOW - 30 * DAY_MS).toISOString(), NOW)?.value, 30);
  assert.equal(timeParts(new Date(NOW - 31 * DAY_MS).toISOString(), NOW)?.value, 1);
  assert.equal(timeParts('2099-01-01T00:00:00Z', NOW)?.unit, 'just_now');
});

test('githubShortTime 全单位', () => {
  assert.equal(githubShortTime(timeParts('2026-08-31T09:00:00Z', NOW)!), '3h');
  assert.equal(githubShortTime(timeParts('2026-08-30T12:00:00Z', NOW)!), '1d');
  assert.equal(githubShortTime(timeParts('2026-08-31T11:59:50Z', NOW)!), 'now');
  assert.equal(githubShortTime({ value: 2, unit: 'month' } as TimeParts), '2mo');
  assert.equal(githubShortTime({ value: 3, unit: 'year' } as TimeParts), '3y');
});

test('compactCount 缩略计数', () => {
  assert.equal(compactCount(999), '999');
  assert.equal(compactCount(1000), '1k');
  assert.equal(compactCount(1500), '1.5k');
  assert.equal(compactCount(1250), '1.3k');
  assert.equal(compactCount(12000), '12k');
});

test('notificationTypeKey 映射与未知原样', () => {
  assert.equal(notificationTypeKey('Issue'), 'issue');
  assert.equal(notificationTypeKey('PullRequest'), 'pr');
  assert.equal(notificationTypeKey('Release'), 'release');
  assert.equal(notificationTypeKey('CheckSuite'), 'ci');
  assert.equal(notificationTypeKey('Discussion'), 'discussion');
  assert.equal(notificationTypeKey('SecurityAlert'), 'security');
  assert.equal(notificationTypeKey('UnknownType'), 'UnknownType');
});

// ─────────────── Diff ───────────────

test('parseDiffPatch 标准 patch 解析', () => {
  const patch = '@@ -1,3 +1,4 @@\n ctx\n+added\n-del\n';
  const hunks = parseDiffPatch(patch);
  assert.equal(hunks.length, 1);
  const h = hunks[0];
  assert.equal(h.oldStart, 1);
  assert.equal(h.newStart, 1);
  assert.equal(h.lines.filter((l) => l.kind === 'add').length, 1);
  assert.equal(h.lines.filter((l) => l.kind === 'del').length, 1);
  assert.equal(h.lines.length, 3);
  assert.equal(h.lines[0].kind, 'ctx');
  assert.equal(h.lines[1].kind, 'add');
  assert.equal(h.lines[1].newLine, 2);
  assert.equal(h.lines[2].kind, 'del');
  assert.equal(h.lines[2].oldLine, 2);
});

test('parseDiffPatch 空 patch 与非法输入', () => {
  assert.equal(parseDiffPatch('').length, 0);
  assert.equal(parseDiffPatch('not a patch').length, 0);
});

test('parseDiffPatch 多 hunk 各自维护行号', () => {
  const patch = '@@ -1,2 +1,2 @@\n a\n-b\n+c\n d\n@@ -10,1 +10,2 @@\n e\n+f\n';
  const hunks = parseDiffPatch(patch);
  assert.equal(hunks.length, 2);
  assert.equal(hunks[0].oldStart, 1);
  assert.equal(hunks[1].oldStart, 10);
  assert.equal(hunks[1].newStart, 10);
  assert.equal(hunks[1].lines[1].kind, 'add');
  assert.equal(hunks[1].lines[1].newLine, 11);
});

test('parseDiffPatch CRLF 剔除行尾 \\r', () => {
  const patch = '@@ -1,1 +1,2 @@\r\n ctx\r\n+added\r\n';
  const hunks = parseDiffPatch(patch);
  assert.equal(hunks.length, 1);
  assert.equal(hunks[0].header.length, '@@ -1,1 +1,2 @@'.length);
  assert.equal(hunks[0].lines[0].text, 'ctx');
  assert.equal(hunks[0].lines[1].text, 'added');
});

test('parseDiffPatch No newline 标记不渲染', () => {
  const patch = '@@ -1,2 +1,2 @@\n ctx\n\\ No newline at end of file\n+add\n';
  const hunks = parseDiffPatch(patch);
  assert.equal(hunks.length, 1);
  assert.equal(hunks[0].lines.length, 2);
  assert.equal(hunks[0].lines[0].kind, 'ctx');
  assert.equal(hunks[0].lines[1].kind, 'add');
});

test('parseDiffPatch 新文件场景 -0,0 起始', () => {
  const patch = '@@ -0,0 +1,2 @@\n+a\n+b\n';
  const hunks = parseDiffPatch(patch);
  assert.equal(hunks.length, 1);
  assert.equal(hunks[0].oldStart, 0);
  assert.equal(hunks[0].newStart, 1);
  assert.equal(hunks[0].lines[0].oldLine, 0);
  assert.equal(hunks[0].lines[0].newLine, 1);
  assert.equal(hunks[0].lines[1].newLine, 2);
});

test('parseDiffPatch 非法 hunk 头整体跳过', () => {
  const patch = '@@ -x +y @@\nctx line\n';
  assert.equal(parseDiffPatch(patch).length, 0);
});

test('parseDiffPatch hunk 内空行按上下文处理防行号错位（H3）', () => {
  const patch = '@@ -1,2 +1,2 @@\n foo\n\n bar\n';
  const hunks = parseDiffPatch(patch);
  assert.equal(hunks.length, 1);
  assert.equal(hunks[0].lines.length, 3);
  assert.equal(hunks[0].lines[1].kind, 'ctx');
  assert.equal(hunks[0].lines[1].text, '');
  assert.equal(hunks[0].lines[1].oldLine, 2);
  assert.equal(hunks[0].lines[1].newLine, 2);
});

test('fileBaseName 提取', () => {
  assert.equal(fileBaseName('/a/b/c.ts'), 'c.ts');
  assert.equal(fileBaseName('README.md'), 'README.md');
  assert.equal(fileBaseName('src/main/ets/Index.ets'), 'Index.ets');
});

// ─────────────── WorkConfig ───────────────

test('WorkConfig 默认分区与顺序', () => {
  const defaults = defaultWorkSections();
  assert.ok(defaults.length >= 7);
  assert.equal(defaults[0].id, 'issues');
  assert.equal(defaults[1].id, 'prs');
  assert.equal(defaults[6].id, 'starred');
  assert.ok(defaults.every((s) => s.visible));
});

test('WorkConfig 序列化 roundtrip', () => {
  const defaults = defaultWorkSections();
  const storage = workSectionsToStorage(defaults);
  const restored = workSectionsFromStorage(storage);
  assert.equal(restored.length, defaults.length);
  assert.equal(restored[0].id, defaults[0].id);
});

test('visibleWorkSections 仅保留 visible 项且保持顺序', () => {
  const sections: WorkSection[] = [
    { id: 'issues', visible: true },
    { id: 'prs', visible: false },
    { id: 'starred', visible: true }
  ];
  const visible = visibleWorkSections(sections);
  assert.equal(visible.length, 2);
  assert.equal(visible[0].id, 'issues');
  assert.equal(visible[1].id, 'starred');
});

test('workSectionsFromStorage 非数组/非法 JSON 回退默认', () => {
  assert.equal(workSectionsFromStorage('{}').length, defaultWorkSections().length);
  assert.equal(workSectionsFromStorage('{{bad').length, defaultWorkSections().length);
  assert.equal(workSectionsFromStorage('').length, defaultWorkSections().length);
  assert.equal(workSectionsFromStorage('[]').length, defaultWorkSections().length);
});

test('workSectionsFromStorage 非法/重复 id 剔除、visible 缺省为 true', () => {
  const restored = workSectionsFromStorage('[{"id":"bogus"},{"id":"issues","visible":false},{"id":"issues"}]');
  assert.equal(restored.length, 1);
  assert.equal(restored[0].id, 'issues');
  assert.equal(restored[0].visible, false);
  const missingVisible = workSectionsFromStorage('[{"id":"prs"}]');
  assert.equal(missingVisible[0].id, 'prs');
  assert.equal(missingVisible[0].visible, true);
});

// ─────────────── RepoSubModels ───────────────

test('mapRepoCommit GitActor user 兜底（无关联账号用 name）', () => {
  const raw: JsonMap = {
    'oid': 'abc123',
    'messageHeadline': 'fix: something',
    'committedDate': '2026-08-31T10:00:00Z',
    'author': { 'name': '周铭', 'avatarUrl': '' },
    'statusCheckRollup': { 'state': 'SUCCESS' }
  };
  const item = mapRepoCommit(raw);
  assert.equal(item.authorLogin, '周铭');
  assert.equal(item.checksState, 'SUCCESS');
  const raw2: JsonMap = {
    'oid': 'def456',
    'messageHeadline': 'hi',
    'committedDate': '2026-08-31T10:00:00Z',
    'author': { 'name': 'Zhang', 'avatarUrl': '', 'user': { 'login': 'zm-bad' } }
  };
  assert.equal(mapRepoCommit(raw2).authorLogin, 'zm-bad');
});

test('mapRepoCommit 无 author/schema 字段缺省', () => {
  const item = mapRepoCommit({ 'oid': 'x', 'messageHeadline': 'm', 'committedDate': 'd' });
  assert.equal(item.authorLogin, '');
  assert.equal(item.authorAvatar, '');
  assert.equal(item.checksState, '');
});

test('mapRepoCommitsPage 深链解析（defaultBranchRef/target/history）', () => {
  const data: JsonMap = {
    'repository': {
      'defaultBranchRef': {
        'target': {
          'history': {
            'pageInfo': { 'hasNextPage': true, 'endCursor': 'c1' },
            'nodes': [
              { 'oid': 'aa', 'messageHeadline': 'm1', 'committedDate': '2026-08-31T10:00:00Z',
                'author': { 'name': 'N', 'user': { 'login': 'u1' } } }
            ]
          }
        }
      }
    }
  };
  const page = mapRepoCommitsPage(data);
  assert.equal(page.hasNextPage, true);
  assert.equal(page.endCursor, 'c1');
  assert.equal(page.commits.length, 1);
  assert.equal(page.commits[0].authorLogin, 'u1');
});

test('mapRepoCommitsPage 空数据兜底', () => {
  const page = mapRepoCommitsPage({});
  assert.equal(page.hasNextPage, false);
  assert.equal(page.endCursor, '');
  assert.equal(page.commits.length, 0);
});

test('mapPrCommits 节点解包（PR commits）', () => {
  const data: JsonMap = {
    'repository': {
      'pullRequest': {
        'commits': {
          'pageInfo': { 'hasNextPage': false, 'endCursor': '' },
          'nodes': [
            { 'commit': { 'oid': 'aa', 'messageHeadline': 'm1', 'committedDate': '2026-08-31T10:00:00Z',
              'author': { 'name': 'N', 'user': { 'login': 'u1' } }, 'statusCheckRollup': { 'state': 'SUCCESS' } } },
            { 'commit': { 'oid': 'bb', 'messageHeadline': 'm2', 'committedDate': '2026-08-31T10:00:00Z',
              'author': { 'name': 'N2' } } }
          ]
        }
      }
    }
  };
  const page = mapPrCommits(data);
  assert.equal(page.commits.length, 2);
  assert.equal(page.commits[0].authorLogin, 'u1');
  assert.equal(page.commits[0].checksState, 'SUCCESS');
  assert.equal(page.commits[1].checksState, '');
});

test('mapPrCommits 空数据兜底', () => {
  const page = mapPrCommits({});
  assert.equal(page.hasNextPage, false);
  assert.equal(page.commits.length, 0);
});

test('repoPrIconKey 状态映射（merged/open/closed/draft）', () => {
  assert.equal(repoPrIconKey('MERGED', true), 'merged');
  assert.equal(repoPrIconKey('OPEN', false), 'open');
  assert.equal(repoPrIconKey('CLOSED', false), 'closed');
  assert.equal(repoPrIconKey('OPEN', false, true), 'draft');
  assert.equal(repoPrIconKey('MERGED', false, false), 'merged');
});

test('filterPrsByAuthor 作者过滤', () => {
  const prs = [prRow('1', 'alice'), prRow('2', 'bob')];
  assert.equal(filterPrsByAuthor(prs, 'alice').length, 1);
  assert.equal(filterPrsByAuthor(prs, '').length, 2);
  assert.equal(filterPrsByAuthor(prs, 'nobody').length, 0);
});

test('filterPrsByAssignee 分配人过滤', () => {
  const prs = [prRow('1', 'alice', ['carol']), prRow('2', 'bob', [])];
  assert.equal(filterPrsByAssignee(prs, 'carol').length, 1);
  assert.equal(filterPrsByAssignee(prs, '').length, 2);
  assert.equal(filterPrsByAssignee(prs, 'carolx').length, 0);
});

// ─────────────── PrDiffModels ───────────────

test('mapPrFiles 统计字段与文件列表', () => {
  const data: JsonMap = {
    'repository': {
      'pullRequest': {
        'id': 'PRID',
        'additions': 12,
        'deletions': 3,
        'files': {
          'totalCount': 2,
          'nodes': [
            { 'path': 'a.ts', 'additions': 10, 'deletions': 0, 'status': 'MODIFIED' },
            { 'path': 'b.ts', 'additions': 2, 'deletions': 3, 'status': 'ADDED' }
          ]
        }
      }
    }
  };
  const page = mapPrFiles(data);
  assert.equal(page.totalCount, 2);
  assert.equal(page.additions, 12);
  assert.equal(page.deletions, 3);
  assert.equal(page.pullRequestId, 'PRID');
  assert.equal(page.files.length, 2);
  assert.equal(page.files[0].path, 'a.ts');
});

test('mapFilesCursor 游标解析与兜底', () => {
  const data: JsonMap = {
    'repository': { 'pullRequest': { 'files': { 'pageInfo': { 'endCursor': 'abc' } } } }
  };
  assert.equal(mapFilesCursor(data), 'abc');
  assert.equal(mapFilesCursor({}), '');
});

test('applyRestPatch 可解析 patch 正常回填', () => {
  const item = applyRestPatch(fileItem('a.ts'), {
    'patch': '@@ -1,1 +1,1 @@\n-a\n+b\n',
    'additions': 1, 'deletions': 1, 'status': 'MODIFIED'
  });
  assert.equal(item.diffTooLarge, false);
  assert.equal(item.hunks.length, 1);
  assert.equal(item.additions, 1);
  assert.equal(item.deletions, 1);
  assert.equal(item.status, 'MODIFIED');
});

test('applyRestPatch 大 diff 判定（H4：有 patch 但解析不出 hunk → 过大）', () => {
  const item = applyRestPatch(fileItem('a.ts'), { 'patch': 'plain text without hunks' });
  assert.equal(item.diffTooLarge, true);
});

test('applyRestPatch 空 patch 非二进制 → 过大；二进制 → 不算大 diff', () => {
  const textItem = applyRestPatch(fileItem('a.ts'), { 'patch': '' });
  assert.equal(textItem.diffTooLarge, true);
  const binaryItem = applyRestPatch(fileItem('img.png'), { 'patch': '' });
  assert.equal(binaryItem.isBinary, true);
  assert.equal(binaryItem.diffTooLarge, false);
});

test('applyRestPatch rest 缺字段回退 item 值', () => {
  const item = applyRestPatch(fileItem('a.ts'), {});
  assert.equal(item.additions, 0);
  assert.equal(item.status, 'ADDED');
  assert.equal(item.diffTooLarge, true);
});

// ─────────────── services 纯函数（自 ohosTest 迁入；设备层聚焦 UI/集成） ───────────────

function ntItem(threadId: string, reason: string, unread: boolean, fullName: string = 'o/r', avatar: string = ''): NotificationItem {
  return {
    threadId: threadId, repoFullName: fullName, title: 't', subjectType: 'Issue', reason: reason,
    unread: unread, updatedAt: '', subjectUrl: '', ownerAvatarUrl: avatar, prMerged: false
  };
}

function repoSummary(id: string, nameWithOwner: string): RepoSummary {
  return {
    id: id, name: nameWithOwner.substring(2), nameWithOwner: nameWithOwner, description: '',
    stargazerCount: 1, forkCount: 0, primaryLanguage: '', languageColor: '', isPrivate: false,
    ownerLogin: nameWithOwner.substring(0, 1), ownerAvatarUrl: '', graphqlId: 'N' + id,
    openGraphImageUrl: '', viewerHasStarred: false, contributorCount: 0
  };
}

test('buildNotificationsPath 过滤参数（Focused 参与模式）', () => {
  assert.equal(buildNotificationsPath(true, 30), '/notifications?all=true&per_page=30');
  assert.equal(buildNotificationsPath(false, 1), '/notifications?all=false&per_page=1');
  assert.equal(buildNotificationsPath(true, 30, true), '/notifications?participating=true&per_page=30');
});

test('filterByReasons reason 过滤（空选=全量，未知 reason 归类）', () => {
  const items = [
    ntItem('1', 'assign'), ntItem('2', 'mention'), ntItem('3', 'team_mention'),
    ntItem('4', 'review_requested'), ntItem('5', 'comment'), ntItem('6', 'subscribed'),
    ntItem('7', 'author'), ntItem('8', 'state_change'), ntItem('9', 'weird-reason')
  ];
  assert.equal(filterByReasons(items, []).length, 9);
  assert.equal(filterByReasons(items, ['mention']).length, 1);
  assert.equal(filterByReasons(items, ['mention'])[0].threadId, '2');
  // 未知 reason 不被任何已选 key 命中，也不被空选之外的列别吞掉
  assert.equal(filterByReasons(items, ['assign', 'mention']).length, 2);
});

test('filterByInboxView 视图语义（inbox 全部/done=已读近似/saved 无标记空）', () => {
  const items = [ntItem('1', 'comment', true), ntItem('2', 'comment', false), ntItem('3', 'comment', true)];
  assert.equal(filterByInboxView(items, 'inbox').length, 3);
  assert.equal(filterByInboxView(items, 'done')[0].threadId, '2');
  assert.equal(filterByInboxView(items, 'saved').length, 0);
});

test('collectRepoFilters 聚合（首现顺序+计数+头像取非空）', () => {
  const items = [
    ntItem('1', 'comment', true, 'o/a', 'http://a'),
    ntItem('2', 'comment', true, 'o/b', ''),
    ntItem('3', 'comment', true, 'o/a', ''),
    ntItem('4', 'comment', true, 'o/a', 'http://a2')
  ];
  const reps = collectRepoFilters(items);
  assert.equal(reps.length, 2);
  assert.equal(reps[0].fullName, 'o/a');
  assert.equal(reps[0].count, 3);
  assert.equal(reps[0].avatarUrl, 'http://a');
  assert.equal(reps[1].fullName, 'o/b');
});

test('buildCodeQuery 与 mapCodeSearch（REST code 条目映射）', () => {
  assert.equal(buildCodeQuery('claude code'), 'claude code');
  const repo1: JsonMap = { 'nameWithOwner': 'nvidia/trit' };
  const repo2: JsonMap = { 'nameWithOwner': 'jezwb/claude-skills' };
  const data: JsonMap = {
    'search': {
      'codeCount': 2,
      'nodes': [
        { 'repository': repo1, 'path': 'docs/CLAUDE.md', 'name': 'CLAUDE.md' },
        { 'repository': repo2, 'path': 'src/main.ts', 'name': 'main.ts' }
      ]
    }
  };
  const items = mapCodeSearch(data);
  assert.equal(items.length, 2);
  assert.equal(items[0].repoFullName, 'nvidia/trit');
  assert.equal(items[0].isMarkdown, true);
  assert.equal(items[1].isMarkdown, false);
});

test('buildTrendingPath 时间窗 qualifier 拼装', () => {
  const now = Date.parse('2026-09-06T12:00:00Z');
  const path = buildTrendingPath(now, 7);
  assert.ok(path.startsWith('/search/repositories?q='));
  assert.ok(path.includes('pushed%3A%3E2026-08-30'));
  assert.ok(path.includes('sort=stars&order=desc'));
  assert.ok(buildAwesomePath().includes('topic%3Aawesome-list'));
});

test('buildRepoListPath 语言/口语 qualifier 边界', () => {
  const now = Date.parse('2026-09-06T12:00:00Z');
  const trending = buildRepoListPath('trending', now, 7, 'Go', 'English');
  assert.ok(trending.includes('pushed%3A%3E2026-08-30'));
  assert.ok(trending.includes('language%3AGo'));
  assert.ok(trending.includes('spoken_language%3AEnglish'));
  assert.ok(trending.includes('sort=stars&order=desc'));
  // 未传语言不带 language qualifier（防空拼）
  assert.ok(!buildAwesomePath().includes('language%3A'));
});

test('mapSearchRepos REST 响应映射', () => {
  const body = `{"items":[{"id":"1","name":"b","full_name":"a/b","description":"d",` +
    `"stargazers_count":10,"forks_count":2,"language":"TypeScript",` +
    `"private":false,"owner":{"login":"a","avatar_url":"https://av"}}]}`;
  const repos = mapSearchRepos(body);
  assert.equal(repos.length, 1);
  assert.equal(repos[0].nameWithOwner, 'a/b');
  assert.equal(repos[0].stargazerCount, 10);
  assert.equal(repos[0].forkCount, 2);
  assert.equal(repos[0].primaryLanguage, 'TypeScript');
  assert.equal(repos[0].ownerLogin, 'a');
});

test('contributorCount Link last 页解析', () => {
  assert.equal(contributorCount('[{"login":"a"}]', ''), 1);
  assert.equal(contributorCount('[]', ''), 0);
  assert.equal(contributorCount('null', ''), 0);
  assert.equal(contributorCount('[{"login":"a"}]',
    '<https://api.github.com/repositories/1/contributors?page=2>; rel="next", ' +
    '<https://api.github.com/repositories/1/contributors?page=435>; rel="last"'), 435);
});

test('buildRepoMetaQuery 与 mapRepoMeta 别名兜底', () => {
  const repoOne = repoSummary('1', 'a/b');
  const repoTwo = repoSummary('2', 'a/c');
  const query = buildRepoMetaQuery([repoOne, repoTwo]);
  assert.ok(query.includes('r0: repository(owner: "a", name: "b")'));
  assert.ok(query.includes('r1: repository(owner: "a", name: "c")'));
  const meta0: JsonMap = { 'openGraphImageUrl': 'https://img', 'viewerHasStarred': true };
  const merged = mapRepoMeta([repoOne, repoTwo], { 'r0': meta0 });
  assert.equal(merged[0].openGraphImageUrl, 'https://img');
  assert.equal(merged[0].viewerHasStarred, true);
  // alias 缺失：保留 REST 原值
  assert.equal(merged[1].openGraphImageUrl, '');
});

test('buildQualifierInsert 空格/冒号边界', () => {
  assert.equal(buildQualifierInsert('', 'repo'), 'repo:');
  assert.equal(buildQualifierInsert('foo', 'repo'), 'foo repo:');
  assert.equal(buildQualifierInsert('foo ', 'repo'), 'foo repo:');
  assert.equal(buildQualifierInsert('repo:', 'user'), 'repo:user:');
});

test('pushSearchHistory 去重置顶与容量上限', () => {
  const next = pushSearchHistory(['a', 'b'], 'a');
  assert.equal(next.length, 2);
  assert.equal(next[0], 'a');
  const cap = pushSearchHistory(['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j'], 'k');
  assert.equal(cap.length, 10);
  assert.equal(cap[0], 'k');
  assert.equal(cap[9], 'i');
  assert.equal(pushSearchHistory(['a'], '  ').length, 1);
});

test('mapSearchNode 各类型分派（repo/issue/pr/user/未知）', () => {
  const r = mapSearchNode({
    '__typename': 'Repository', 'nameWithOwner': 'a/b', 'description': 'd',
    'stargazerCount': 9, 'forkCount': 3, 'primaryLanguage': { 'name': 'TS', 'color': '#3178c6' }
  });
  assert.equal(r?.kind, 'repository');
  assert.equal(r?.stars, 9);
  assert.equal(r?.languageColor, '#3178c6');
  const repoIss: JsonMap = { 'nameWithOwner': 'c/d' };
  assert.equal(mapSearchNode({ '__typename': 'Issue', 'title': 't', 'state': 'OPEN', 'number': 12, 'repository': repoIss })?.kind, 'issue');
  assert.equal(mapSearchNode({ '__typename': 'PullRequest', 'title': 'p', 'state': 'MERGED', 'number': 7, 'repository': repoIss })?.kind, 'pr');
  const u = mapSearchNode({
    '__typename': 'User', 'login': 'foo', 'name': 'Foo', 'avatarUrl': 'a.png', 'bio': 'b',
    'followers': { 'totalCount': 2 }, 'following': { 'totalCount': 5 }
  });
  assert.equal(u?.followers, 2);
  assert.equal(mapSearchNode({ '__typename': 'Unknown' }), null);
});

test('mapSearchNode PR 扩展字段与 org 生物', () => {
  const labelNodes: JsonMap[] = [{ 'name': 'bug-fix', 'color': '1F883D' }];
  const item = mapSearchNode({
    '__typename': 'PullRequest', 'title': '[CLI]: Crash', 'state': 'OPEN', 'number': 7,
    'createdAt': '2026-08-31T10:00:00Z', 'repository': { 'nameWithOwner': 'a/b' },
    'labels': { 'nodes': labelNodes }, 'comments': { 'totalCount': 6 },
    'reactions': { 'totalCount': 2 }, 'statusCheckRollup': { 'state': 'SUCCESS' },
    'reviewDecision': 'CHANGES_REQUESTED'
  });
  assert.equal(item?.labels.length, 1);
  assert.equal(item?.labels[0].name, 'bug-fix');
  assert.equal(item?.commentCount, 6);
  assert.equal(item?.reactionCount, 2);
  assert.equal(item?.checkState, 'SUCCESS');
  assert.equal(item?.reviewDecision, 'CHANGES_REQUESTED');
  assert.equal(item?.createdAt, '2026-08-31T10:00:00Z');
  const orgItem = mapSearchNode({
    '__typename': 'Organization', 'login': 'github', 'name': 'GitHub',
    'description': 'build together', 'avatarUrl': 'g.png'
  });
  assert.equal(orgItem?.bio, 'build together');
  const repoItem = mapSearchNode({
    '__typename': 'Repository', 'nameWithOwner': 'a/b', 'stargazerCount': 5,
    'owner': { 'avatarUrl': 'o.png' }
  });
  assert.equal(repoItem?.avatarUrl, 'o.png');
});

test('mapSearchResults/Overview 页信息与分区计数', () => {
  const res = mapSearchResults({
    'search': {
      'repositoryCount': 2, 'pageInfo': { 'hasNextPage': true, 'endCursor': 'abc' },
      'nodes': [
        { '__typename': 'Repository', 'nameWithOwner': 'a/b' },
        { '__typename': 'Issue', 'title': 't', 'number': 1, 'repository': { 'nameWithOwner': 'c/d' } }
      ]
    }
  });
  assert.equal(res.totalCount, 2);
  assert.equal(res.hasNextPage, true);
  assert.equal(res.endCursor, 'abc');
  assert.equal(res.items.length, 2);
  assert.equal(res.items[1].kind, 'issue');
  const ov = mapSearchOverview({
    'repos': { 'repositoryCount': 5, 'nodes': [{ '__typename': 'Repository', 'nameWithOwner': 'a/b' }] },
    'issues': { 'issueCount': 7, 'nodes': [] },
    'prs': { 'issueCount': 9, 'nodes': [] },
    'users': { 'userCount': 11, 'nodes': [] },
    'orgs': { 'userCount': 13, 'nodes': [{ '__typename': 'Organization', 'login': 'github', 'name': 'GitHub' }] }
  });
  assert.equal(ov.repoCount, 5);
  assert.equal(ov.orgCount, 13);
  assert.equal(ov.issueCount, 7);
  assert.equal(ov.prCount, 9);
  assert.equal(ov.userCount, 11);
});

test('buildSearchQuery 各 kind qualifier 与 trim', () => {
  assert.equal(buildSearchQuery('repositories', 'cli'), 'cli');
  assert.equal(buildSearchQuery('issues', 'cli'), 'cli is:issue');
  assert.equal(buildSearchQuery('prs', 'cli'), 'cli is:pr');
  assert.equal(buildSearchQuery('people', 'cli'), 'cli type:user');
  assert.equal(buildSearchQuery('orgs', 'cli'), 'cli type:org');
  assert.equal(buildSearchQuery('code', '  cli  '), 'cli');
});

test('formatBigCount 与 isLightHexColor', () => {
  assert.equal(formatBigCount(0), '0');
  assert.equal(formatBigCount(999), '999');
  assert.equal(formatBigCount(72000), '72k');
  assert.equal(formatBigCount(9999), '10k');
  assert.equal(formatBigCount(2200000), '2.2m');
  assert.equal(formatBigCount(2000000), '2m');
  assert.equal(isLightHexColor('F6F8FA'), true);
  assert.equal(isLightHexColor('0C4462'), false);
  assert.equal(isLightHexColor(''), false);
  assert.equal(isLightHexColor('zzzzzz'), false);
});

test('buildCodeSnippet 词边界命中', () => {
  const content = 'clients connect via latest_tomatoes_cli_gem\nfoo cli bar\n';
  const s = buildCodeSnippet(content, ['cli'], 20);
  assert.equal(s.totalMatches, 2);
  const line1 = s.window.find((l) => l.no === 1);
  // latest_tomatoes_cli_gem 中 cli 的绝对位置 36..39
  assert.equal(line1?.highlights.length, 1);
  assert.equal(line1?.highlights[0].start, 36);
  assert.equal(line1?.highlights[0].end, 39);
});

test('buildCodeSnippet 窗口与 more 分区', () => {
  const content = 'A\ncli line2\nB\nline4 cli\nC\nD\nE\nF\nG\nH\ncli on 10\n';
  const s = buildCodeSnippet(content, ['cli'], 6);
  assert.equal(s.totalMatches, 3);
  assert.equal(s.window[0].no, 1);
  assert.ok(s.more.length > 0);
  const line2 = s.window.find((l) => l.no === 2);
  assert.equal(line2?.highlights[0].start, 0);
  assert.equal(line2?.highlights[0].end, 3);
});

test('buildFragmentLines 行内高亮偏移换算', () => {
  const fragment = 'a line\nfoo CLI bar\nb line';
  const matches: RawMatch[] = [{ 'text': 'CLI', 'indices': [11, 14] }];
  assert.equal(splitLines(fragment).length, 3);
  const out = buildFragmentLines(fragment, matches);
  assert.equal(out.length, 3);
  // 命中行（第 2 行起始偏移 7）：11-7=4..14-7=7
  assert.equal(out[1].highlights.length, 1);
  assert.equal(out[1].highlights[0].start, 4);
  assert.equal(out[1].highlights[0].end, 7);
});

test('parseCodeSearchItem 与 fileBadgeKey', () => {
  const item: JsonMap = {
    'repository': { 'full_name': 'owner/repo' },
    'path': 'docs/a.md', 'name': 'a.md',
    'url': 'https://api.github.com/repositories/1/contents/docs/a.md',
    'text_matches': [{ 'fragment': 'x CLI y', 'matches': [{ 'text': 'CLI', 'indices': [2, 5] }] }]
  };
  const f = parseCodeSearchItem(item);
  assert.ok(f !== null);
  assert.equal(f?.repoFullName, 'owner/repo');
  assert.equal(f?.matches.length, 1);
  assert.equal(f?.matches[0].text, 'CLI');
  assert.equal(fileBadgeKey(f?.name ?? ''), 'markdown');
  assert.equal(fileBadgeKey('NEWS'), 'text');
});

test('pullRefFromUrl 与 buildPullStatesQuery/mapPullMerged', () => {
  const ref = pullRefFromUrl('https://api.github.com/repos/ZM-BAD/arkcat/pulls/123');
  assert.equal(ref?.owner, 'ZM-BAD');
  assert.equal(ref?.name, 'arkcat');
  assert.equal(ref?.number, 123);
  assert.equal(pullRefFromUrl('https://api.github.com/repos/a/b/issues/8'), null);
  assert.equal(pullRefFromUrl(''), null);
  const refA: PrRef = { owner: 'a', name: 'b', number: 8 };
  const refB: PrRef = { owner: 'c', name: 'd', number: 9 };
  const q = buildPullStatesQuery([refA, refB]);
  assert.ok(q.indexOf('t0:repository(owner:"a", name:"b")') >= 0);
  assert.ok(q.indexOf('t1:repository(owner:"c", name:"d")') >= 0);
  const merged = mapPullMerged({
    't0': { 'issueOrPullRequest': { 'merged': true } },
    't1': { 'issueOrPullRequest': { 'merged': false } },
    't2': {}
  }, 3);
  assert.equal(merged[0], true);
  assert.equal(merged[1], false);
  assert.equal(merged[2], false);
});

test('MarkdownService.routeOf 站内链接分派', () => {
  assert.equal(MarkdownService.routeOf('/owner/repo')?.name, 'repoDetail');
  assert.equal(MarkdownService.routeOf('https://github.com/owner/repo')?.param, 'owner/repo');
  assert.equal(MarkdownService.routeOf('https://github.com/owner/repo/issues/12')?.name, 'issueDetail');
  assert.equal(MarkdownService.routeOf('/owner/repo/issues/12#L3')?.param, 'owner/repo/12');
  assert.equal(MarkdownService.routeOf('/owner/repo/pull/7')?.name, 'prDetail');
  assert.equal(MarkdownService.routeOf('https://github.com/owner/repo/pulls/7')?.name, 'prDetail');
  assert.equal(MarkdownService.routeOf('/owner/repo/blob/main/src/index.ets')?.name, 'codeViewer');
  assert.equal(MarkdownService.routeOf('/owner/repo/blob/main/src/index.ets')?.param, 'owner|repo|main/src/index.ets');
  assert.equal(MarkdownService.routeOf('https://example.com/a/b'), null);
  assert.equal(MarkdownService.routeOf('mailto:a@b.c'), null);
  assert.equal(MarkdownService.routeOf('#anchor'), null);
  assert.equal(MarkdownService.routeOf(''), null);
  assert.equal(MarkdownService.routeOf('/owner/repo/tree/main'), null);
  assert.equal(MarkdownService.routeOf('/owner'), null);
});

test('MarkdownService.shouldCollapse 阈值边界', () => {
  assert.equal(MarkdownService.shouldCollapse(5000, 4000), true);
  assert.equal(MarkdownService.shouldCollapse(4000, 4000), false);
  assert.equal(MarkdownService.shouldCollapse(10, 4000), false);
  // 阈值 0 = 不折叠（评论等短内容）
  assert.equal(MarkdownService.shouldCollapse(5000, 0), false);
});

test('mapIssueDetail/mapPrDetail body/bodyHTML 映射（防正文恒空回归）', () => {
  const author: JsonMap = { 'login': 'zm_bad' };
  const cNode: JsonMap = {
    'id': 'C1', 'body': 'plain', 'bodyHTML': '<p>rendered</p>', 'createdAt': '2026-08-02T00:00:00Z', 'author': author
  };
  const issueData: JsonMap = {
    'repository': { 'issue': {
      'number': 1, 'title': 't', 'state': 'OPEN', 'stateReason': '', 'body': 'body text',
      'bodyHTML': '<p>body html</p>', 'createdAt': '2026-08-01T00:00:00Z', 'author': author,
      'labels': { 'nodes': [] }, 'comments': { 'totalCount': 1, 'nodes': [cNode] }
    } }
  };
  const ip = mapIssueDetail(issueData);
  assert.equal(ip.body, 'body text');
  assert.equal(ip.bodyHTML, '<p>body html</p>');
  assert.equal(ip.comments[0].body, 'plain');
  assert.equal(ip.comments[0].bodyHTML, '<p>rendered</p>');
});

test('parseAchievementDetail 完整/锚点/多 tier 事件解析', () => {
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
  assert.equal(d.name, 'YOLO');
  assert.equal(d.description, 'You want it? You merge it.');
  assert.equal(d.badgeImageUrl, 'https://x/yolo-default-be0bbff04951.png');
  assert.equal(d.unlockedAt, '2026-08-31T19:09:34Z');
  // 私有仓库不可见引用 → ref 置空、标签保留
  assert.equal(d.events.length, 1);
  assert.equal(d.events[0].ref, '');
  assert.equal(d.events[0].label, 'Merged without a review');
  // 公共仓库事件：<a> 引用原样
  const anchor = parseAchievementDetail(
    `<div><h3>YOLO</h3></div><div class="achievement-history-tier"><div class="TimelineItem-body"><a href="https://github.com/ZM-BAD/arkcat/pull/3">ZM-BAD/arkcat #3</a> · <span>Merged without a review</span></div></div>`,
    'yolo', 'fb.png');
  assert.equal(anchor.events[0].ref, 'ZM-BAD/arkcat #3');
  // 多 tier：多条事件保持顺序、inaccessible 无 ref
  const multi = parseAchievementDetail(`<div><h3>Pair Extraordinaire</h3></div>
<div class="achievement-history-tier"><div class="TimelineItem-body"><a href="https://github.com/ZM-BAD/arkcat/pull/1">ZM-BAD/arkcat #1</a> · <span>Coauthored with @claude</span></div></div>
<div class="achievement-history-tier"><div class="TimelineItem-body"><span class="color-fg-muted">inaccessible</span> · <span>Coauthored with @claude</span></div></div>`,
    'pair-extraordinaire', 'fb.png');
  assert.equal(multi.events.length, 2);
  assert.equal(multi.events[0].ref, 'ZM-BAD/arkcat #1');
  assert.equal(multi.events[1].ref, '');
});

test('parseAchievementDetail 非法结构抛错/无时间字段兜底', () => {
  let caught = false;
  try {
    parseAchievementDetail('<div>no h3 here</div>', 'yolo', 'fb.png');
  } catch (e) {
    caught = true;
  }
  assert.equal(caught, true);
  const d = parseAchievementDetail(
    `<img src="x.png" data-targets="achievement-badge-flip.tiers" /><h3>Starstruck</h3><div class="mt-1">d</div>`,
    'starstruck', 'fb.png');
  assert.equal(d.name, 'Starstruck');
  assert.equal(d.unlockedAt, '');
  assert.equal(d.badgeImageUrl, 'x.png');
});

test('extractAchievementSlugs 去重提取', () => {
  const slugs = extractAchievementSlugs(`?achievement=yolo&amp;tab=achievements then ?achievement=quickdraw&amp;tab and yolo again`);
  assert.equal(slugs.length, 2);
  assert.equal(slugs[0], 'yolo');
  assert.equal(slugs[1], 'quickdraw');
});
