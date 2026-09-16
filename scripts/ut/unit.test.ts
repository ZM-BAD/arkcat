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
import { NONE_FILTER_KEY } from '../../entry/src/main/ets/utils/FilterLoading';
import { parseDiffPatch, fileBaseName } from '../../entry/src/main/ets/utils/Diff';
import {
  defaultWorkSections, visibleWorkSections, workSectionsToStorage, workSectionsFromStorage,
  moveWorkSection, WorkSection
} from '../../entry/src/main/ets/utils/WorkConfig';
import {
  mapRepoCommit, mapRepoCommitsPage, mapPrCommits,
  filterPrsByAuthor, filterPrsByAssignee, filterPrsByMilestone, repoPrIconKey, RepoPrItem, mapIssueDetail,
  mapPrDetail, mapRepoReleasesPage, formatBytes,
  mapReviewThreads, canMergePr, mergeStateReasonKey, reviewStateKey
} from '../../entry/src/main/ets/models/RepoSubModels';
import { mapPrFiles, mapFilesCursor, applyRestPatch, PrFileItem } from '../../entry/src/main/ets/models/PrDiffModels';
import {
  buildNotificationsPath, pullRefFromUrl, buildPullStatesQuery, mapPullMerged,
  filterByReasons, filterByInboxView, collectRepoFilters, NotificationItem, PrRef
} from '../../entry/src/main/ets/services/NotificationsService';
import {
  buildQualifierInsert, pushSearchHistory, buildSearchQuery, formatBigCount,
  mapSearchNode, mapSearchResults, mapSearchOverview, buildCodeQuery
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
import {
  accountsToStorage, accountsFromStorage, legacyToAccount, nextAddResult,
  AccountInfo
} from '../../entry/src/main/ets/services/AccountStore';
import {
  userPageUrl, repoPageUrl, repoTreeUrl, blobPageUrl, pullPageUrl, issuePageUrl, commitPageUrl
} from '../../entry/src/main/ets/utils/Share';

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
  // 26 个月跨年后仍在 month 粒度之下的边界（2026-06-01 → 约 3 个月）
  assert.equal(timeParts('2024-06-01T12:00:00Z', NOW)?.unit, 'year' as string);
  assert.equal(timeParts('2024-06-01T12:00:00Z', NOW)?.value, 2);
  assert.equal(timeParts('2026-06-01T12:00:00Z', NOW)?.unit, 'month' as string);
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
  assert.equal(compactCount(50500), '50.5k');
  assert.equal(compactCount(118900), '118.9k');
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

test('parseDiffPatch 无 count 的 hunk 头（@@ -1 +1 @@ 兼容）', () => {
  const patch = '@@ -1 +1 @@\n-x\n\\ No newline at end of file\n+y\n\\ No newline at end of file\n';
  const hunks = parseDiffPatch(patch);
  assert.equal(hunks.length, 1);
  assert.equal(hunks[0].oldStart, 1);
  assert.equal(hunks[0].newStart, 1);
  assert.equal(hunks[0].lines.length, 2);
  assert.equal(hunks[0].lines[0].kind, 'del');
  assert.equal(hunks[0].lines[1].kind, 'add');
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

test('moveWorkSection 上移/下移与边界（Spec 016 重排模式）', () => {
  const sections: WorkSection[] = [
    { id: 'issues', visible: true },
    { id: 'prs', visible: false },
    { id: 'starred', visible: true }
  ];
  const ids = (list: WorkSection[]): string => list.map((s) => s.id).join(',');

  // 下移：prs 与 starred 交换（visible=false 的条目同样参与排序）
  assert.equal(ids(moveWorkSection(sections, 1, 2)), 'issues,starred,prs');
  // 上移：starred 移到首位
  assert.equal(ids(moveWorkSection(sections, 2, 0)), 'starred,issues,prs');
  // 首行上移 / 末行下移 / 原位 / 越界：原样返回
  assert.equal(ids(moveWorkSection(sections, 0, -1)), 'issues,prs,starred');
  assert.equal(ids(moveWorkSection(sections, 2, 3)), 'issues,prs,starred');
  assert.equal(ids(moveWorkSection(sections, 1, 1)), 'issues,prs,starred');
  assert.equal(ids(moveWorkSection(sections, -1, 0)), 'issues,prs,starred');
  assert.equal(ids(moveWorkSection(sections, 9, 0)), 'issues,prs,starred');
  // 入参不被改写
  assert.equal(ids(sections), 'issues,prs,starred');
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
  // 「Assigned to nobody」哨兵：只留无 assignees 行（2026-09-14 官方口径）
  assert.equal(filterPrsByAssignee(prs, NONE_FILTER_KEY).length, 1);
});

test('filterPrsByMilestone 里程碑过滤（含 No milestone 哨兵）', () => {
  const mk = (id: string, milestoneTitle: string): RepoPrItem => {
    const pr = prRow(id, 'alice');
    pr.milestoneTitle = milestoneTitle;
    return pr;
  };
  const prs = [mk('1', 'v1.0'), mk('2', ''), mk('3', 'v1.0'), mk('4', '')];
  // 空值=不筛
  assert.equal(filterPrsByMilestone(prs, '').length, 4);
  // 按标题
  assert.equal(filterPrsByMilestone(prs, 'v1.0').length, 2);
  // 「No milestone」哨兵：只留无里程碑行
  assert.equal(filterPrsByMilestone(prs, NONE_FILTER_KEY).length, 2);
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
    openGraphImageUrl: '', viewerHasStarred: false, contributorCount: 0,
    isArchived: false, isFork: false, isMirror: false, isTemplate: false
  };
}

test('filterReposByType 官方 8 项语义（Spec 021/037）', async () => {
  const m = await import('../../entry/src/main/ets/models/GitHubModels');
  const plain = repoSummary('1', 'a/plain');
  const archived = { ...repoSummary('2', 'a/archived'), isArchived: true };
  const fork = { ...repoSummary('3', 'a/fork'), isFork: true };
  const mirror = { ...repoSummary('4', 'a/mirror'), isMirror: true };
  const template = { ...repoSummary('5', 'a/template'), isTemplate: true };
  const priv = { ...repoSummary('6', 'a/priv'), isPrivate: true };
  const all = [plain, archived, fork, mirror, template, priv];
  // all 不过滤
  assert.equal(m.filterReposByType(all, 'all').length, 6);
  assert.equal(m.filterReposByType(all, 'archived')[0].id, '2');
  assert.equal(m.filterReposByType(all, 'fork')[0].id, '3');
  assert.equal(m.filterReposByType(all, 'mirror')[0].id, '4');
  assert.equal(m.filterReposByType(all, 'template')[0].id, '5');
  assert.equal(m.filterReposByType(all, 'private')[0].id, '6');
  // public = 非私有（GraphQL 无 INTERNAL 区分）
  assert.equal(m.filterReposByType(all, 'public').length, 5);
  // source = 非 fork/镜像/归档（普通私有仓库仍算 source）
  const source = m.filterReposByType(all, 'source');
  assert.equal(source.length, 3);
  assert.deepEqual(source.map((r: RepoSummary): string => r.id), ['1', '5', '6']);
  // 未知 key 不过滤（防御性：脏值不得清空列表）
  assert.equal(m.filterReposByType(all, 'weird').length, 6);
});

test('FilterLoading：客户端筛选页的空态自动补拉判定', async () => {
  const m = await import('../../entry/src/main/ets/utils/FilterLoading');
  assert.equal(m.AUTO_LOAD_MAX_EXTRA_PAGES, 5);
  // 有结果 / 没有下一页 → 不补拉
  assert.equal(m.shouldAutoLoadMore(3, true, 0), false);
  assert.equal(m.shouldAutoLoadMore(0, false, 0), false);
  // 空且有下一页 → 补拉，直到上限
  assert.equal(m.shouldAutoLoadMore(0, true, 0), true);
  assert.equal(m.shouldAutoLoadMore(0, true, 4), true);
  assert.equal(m.shouldAutoLoadMore(0, true, 5), false);
  // 「已加载范围内无结果」：补拉结束仍空但服务端还有数据；拉到底则属真实空
  assert.equal(m.isLimitedRangeEmpty(0, true), true);
  assert.equal(m.isLimitedRangeEmpty(0, false), false);
  assert.equal(m.isLimitedRangeEmpty(2, true), false);
});

test('buildNotificationsPath 分页参数（Spec 002 自动补拉）', () => {
  // page=1 不拼参数（保持既有首屏路径与单测不变）
  assert.equal(buildNotificationsPath(true, 50), '/notifications?all=true&per_page=50');
  assert.equal(buildNotificationsPath(true, 50, false, 1), '/notifications?all=true&per_page=50');
  // page>1 拼 page
  assert.equal(buildNotificationsPath(false, 50, false, 3), '/notifications?all=false&per_page=50&page=3');
  // Focused 模式：participating 取代 all（既有口径）
  assert.equal(buildNotificationsPath(true, 50, true, 2), '/notifications?participating=true&per_page=50&page=2');
});

test('repoOrderFromKey 官方 Sort by 8 项 → orderBy 字段/方向（Spec 037）', async () => {
  const m = await import('../../entry/src/main/ets/services/ProfileListService');
  assert.deepEqual(m.repoOrderFromKey('pushed_desc'), { field: 'PUSHED_AT', direction: 'DESC' });
  assert.deepEqual(m.repoOrderFromKey('pushed_asc'), { field: 'PUSHED_AT', direction: 'ASC' });
  assert.deepEqual(m.repoOrderFromKey('created_desc'), { field: 'CREATED_AT', direction: 'DESC' });
  assert.deepEqual(m.repoOrderFromKey('created_asc'), { field: 'CREATED_AT', direction: 'ASC' });
  assert.deepEqual(m.repoOrderFromKey('name_asc'), { field: 'NAME', direction: 'ASC' });
  assert.deepEqual(m.repoOrderFromKey('name_desc'), { field: 'NAME', direction: 'DESC' });
  assert.deepEqual(m.repoOrderFromKey('stars_desc'), { field: 'STARGAZERS', direction: 'DESC' });
  assert.deepEqual(m.repoOrderFromKey('stars_asc'), { field: 'STARGAZERS', direction: 'ASC' });
  // 未知键回退默认 Recently pushed（脏值不得乱序）
  assert.deepEqual(m.repoOrderFromKey('weird'), { field: 'PUSHED_AT', direction: 'DESC' });
});

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

test('buildCodeQuery（REST code 查询串原样透传）', () => {
  assert.equal(buildCodeQuery('claude code'), 'claude code');
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

test('formatBigCount', () => {
  assert.equal(formatBigCount(0), '0');
  assert.equal(formatBigCount(999), '999');
  assert.equal(formatBigCount(72000), '72k');
  assert.equal(formatBigCount(9999), '10k');
  assert.equal(formatBigCount(2200000), '2.2m');
  assert.equal(formatBigCount(2000000), '2m');
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
  assert.ok(q.indexOf('t0: repository(owner: "a", name: "b")') >= 0);
  assert.ok(q.indexOf('t1: repository(owner: "c", name: "d")') >= 0);
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
  const prData: JsonMap = {
    'repository': { 'pullRequest': {
      'number': 82, 'title': 'fix', 'state': 'MERGED', 'merged': true, 'isDraft': false,
      'body': 'pb', 'bodyHTML': '<p>pr html</p>', 'createdAt': '2026-08-01T00:00:00Z',
      'mergedAt': '2026-08-02T00:00:00Z', 'additions': 1, 'deletions': 1, 'author': author,
      'headRefName': 'fix/1', 'baseRefName': 'main', 'comments': { 'totalCount': 0, 'nodes': [] }
    } }
  };
  assert.equal(mapPrDetail(prData).bodyHTML, '<p>pr html</p>');
});

test('Spec 042 mapPrDetail 合并门 + reviews/reviewThreads 映射', () => {
  const author: JsonMap = { 'login': 'zm_bad' };
  const reviewNode: JsonMap = {
    'id': 'RV1', 'state': 'APPROVED', 'body': 'lgtm', 'bodyHTML': '<p>lgtm</p>',
    'submittedAt': '2026-09-01T00:00:00Z', 'author': author, 'viewerDidAuthor': true
  };
  const threadNode: JsonMap = {
    'id': 'TH1', 'path': 'src/a.ets', 'line': null, 'isResolved': true, 'isOutdated': false,
    'viewerCanResolve': false, 'viewerCanUnresolve': true,
    'comments': {
      'totalCount': 1,
      'nodes': [{
        'id': 'TC1', 'body': 'inline', 'bodyHTML': '<p>inline</p>',
        'createdAt': '2026-09-01T00:00:00Z', 'author': author, 'viewerDidAuthor': true
      }]
    }
  };
  const prData: JsonMap = {
    'repository': { 'viewerPermission': 'ADMIN', 'pullRequest': {
      'number': 9, 'title': 't', 'state': 'OPEN', 'merged': false, 'isDraft': false,
      'body': '', 'bodyHTML': '', 'createdAt': '2026-09-01T00:00:00Z', 'additions': 0,
      'deletions': 0, 'author': author, 'headRefName': 'h', 'baseRefName': 'm',
      'mergeable': 'MERGEABLE', 'mergeStateStatus': 'CLEAN',
      'reviews': { 'totalCount': 1, 'nodes': [reviewNode] },
      'reviewThreads': { 'totalCount': 1, 'nodes': [threadNode] },
      'comments': { 'totalCount': 0, 'nodes': [] }
    } }
  };
  const page = mapPrDetail(prData);
  assert.equal(page.mergeable, 'MERGEABLE');
  assert.equal(page.mergeStateStatus, 'CLEAN');
  assert.equal(page.repoViewerPermission, 'ADMIN');
  assert.equal(page.reviews.length, 1);
  assert.equal(page.reviews[0].state, 'APPROVED');
  assert.equal(page.reviews[0].viewerDidAuthor, true);
  // line=null（文件级 thread）归一为 0
  assert.equal(page.threads[0].line, 0);
  assert.equal(page.threads[0].isResolved, true);
  assert.equal(page.threads[0].viewerCanUnresolve, true);
  assert.equal(page.threads[0].comments[0].authorLogin, 'zm_bad');
  assert.equal(page.threads[0].commentsTotal, 1);
  // 缺字段容错：无 reviewThreads/reviews 键 → 空数组、viewerCanMerge 回 false
  const bare = mapPrDetail({ 'repository': { 'pullRequest': {
    'number': 1, 'title': '', 'state': 'OPEN', 'merged': false, 'isDraft': false, 'body': '',
    'bodyHTML': '', 'createdAt': '', 'additions': 0, 'deletions': 0,
    'author': author, 'headRefName': '', 'baseRefName': '', 'comments': { 'totalCount': 0, 'nodes': [] }
  } } });
  assert.equal(bare.threads.length, 0);
  assert.equal(bare.reviews.length, 0);
  assert.equal(bare.repoViewerPermission, '');
});

test('Spec 042 mapReviewThreads 多 thread 顺序与字段', () => {
  const conn: JsonMap = { 'nodes': [
    { 'id': 'T1', 'path': 'a.ets', 'line': 12, 'isResolved': false, 'isOutdated': true,
      'viewerCanResolve': true, 'viewerCanUnresolve': false, 'comments': { 'totalCount': 0, 'nodes': [] } },
    { 'id': 'T2', 'path': 'b.ets', 'line': 3, 'isResolved': true, 'isOutdated': false,
      'viewerCanResolve': false, 'viewerCanUnresolve': true, 'comments': { 'totalCount': 2, 'nodes': [] } }
  ] };
  const threads = mapReviewThreads(conn);
  assert.equal(threads.length, 2);
  assert.equal(threads[0].line, 12);
  assert.equal(threads[0].isOutdated, true);
  assert.equal(threads[1].commentsTotal, 2);
  // null connection 容错
  assert.equal(mapReviewThreads(null).length, 0);
});

test('Spec 042 canMergePr 合并门 + 文案键映射（未知枚举兜底）', () => {
  assert.equal(canMergePr(false, 'MERGEABLE', 'WRITE'), true);
  assert.equal(canMergePr(false, 'MERGEABLE', 'ADMIN'), true);
  assert.equal(canMergePr(false, 'MERGEABLE', 'MAINTAIN'), true);
  assert.equal(canMergePr(true, 'MERGEABLE', 'WRITE'), false);
  assert.equal(canMergePr(false, 'CONFLICTING', 'WRITE'), false);
  assert.equal(canMergePr(false, 'MERGEABLE', 'READ'), false);
  assert.equal(canMergePr(false, 'MERGEABLE', ''), false);
  assert.equal(mergeStateReasonKey('DIRTY'), 'conflicting');
  assert.equal(mergeStateReasonKey('BLOCKED'), 'blocked');
  assert.equal(mergeStateReasonKey('BEHIND'), 'behind');
  assert.equal(mergeStateReasonKey('UNSTABLE'), 'unstable');
  assert.equal(mergeStateReasonKey('DRAFT'), 'draft');
  assert.equal(mergeStateReasonKey('HAS_HOOKS'), 'has_hooks');
  assert.equal(mergeStateReasonKey('UNKNOWN'), 'unknown');
  assert.equal(mergeStateReasonKey('SOMETHING_NEW'), 'unknown');
  assert.equal(reviewStateKey('APPROVED'), 'approved');
  assert.equal(reviewStateKey('CHANGES_REQUESTED'), 'changes_requested');
  assert.equal(reviewStateKey('DISMISSED'), 'dismissed');
  assert.equal(reviewStateKey('PENDING'), 'pending');
  assert.equal(reviewStateKey('COMMENTED'), 'commented');
  assert.equal(reviewStateKey('WEIRD'), 'commented');
});

test('mapRepoReleasesPage body=description 兜底 + formatBytes 单位', () => {
  const author: JsonMap = { 'login': 'zm_bad' };
  const relNode: JsonMap = {
    'id': 'R1', 'tagName': '1.0', 'isLatest': true, 'createdAt': '2026-06-30T00:00:00Z',
    'description': 'long body', 'author': author
  };
  const rp = mapRepoReleasesPage({ 'repository': { 'releases': { 'nodes': [relNode] } } });
  // Release schema 无 body 字段（2026-09-04 实测）：description 即正文
  assert.equal(rp.releases[0].body, 'long body');
  assert.equal(rp.releases[0].bodyHTML, '');
  assert.equal(formatBytes(0), '0 B');
  assert.equal(formatBytes(512), '512 B');
  assert.equal(formatBytes(1536), '1.5 KB');
  assert.equal(formatBytes(5 * 1024 * 1024), '5.0 MB');
  assert.equal(formatBytes(2048 * 1024 * 1024), '2.0 GB');
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
  // 详情头图 background-image → 主题横幅 URL（Spec 052 每徽章背景色）
  assert.equal(d.detailBgUrl, 'https://x/yolo-detail-9511d3a21745.png');
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
  // 无 background-image 片段 → 主题横幅为空串
  assert.equal(multi.detailBgUrl, '');
  // 真实嵌套标记（Pair Extraordinaire 线上片段）：label span 内含 @claude 的 user-mention 链接，
  // 旧正则 [^<]+ 会整条丢事件
  const nested = parseAchievementDetail(
    `<div><h3>Pair Extraordinaire</h3></div><div class="achievement-history-tier"><div class="TimelineItem-body"><a class="Link" href="/ZM-BAD/spooner/pull/1">ZM-BAD/spooner#1</a> · <span>Coauthored with <a href="/claude" class="user-mention" hovercard-type="user">@claude</a></span></div></div>`,
    'pair-extraordinaire', 'fb.png');
  assert.equal(nested.events.length, 1);
  assert.equal(nested.events[0].ref, 'ZM-BAD/spooner#1');
  assert.equal(nested.events[0].label, 'Coauthored with @claude');
  // Arctic Code Vault 形态②：仅仓库引用，无标签
  const refOnly = parseAchievementDetail(
    `<div><h3>Arctic Code Vault Contributor</h3></div><div class="achievement-history-tier"><div class="TimelineItem-body"><a class="Link" href="/atom/atom">atom/atom</a></div></div>`,
    'arctic-code-vault-contributor', 'fb.png');
  assert.equal(refOnly.events.length, 1);
  assert.equal(refOnly.events[0].ref, 'atom/atom');
  assert.equal(refOnly.events[0].label, '');
  // Arctic Code Vault 形态③：纯文本标签尾注，无引用
  const labelOnly = parseAchievementDetail(
    `<div><h3>Arctic Code Vault Contributor</h3></div><div class="achievement-history-tier"><div class="TimelineItem-body"><span>these repositories, and more, were archived</span></div></div>`,
    'arctic-code-vault-contributor', 'fb.png');
  assert.equal(labelOnly.events.length, 1);
  assert.equal(labelOnly.events[0].ref, '');
  assert.equal(labelOnly.events[0].label, 'these repositories, and more, were archived');
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

// ─────────────── AccountStore（Spec 049a 纯函数） ───────────────

test('accounts 序列化 roundtrip（含 name/addedAt）', () => {
  const accounts = [
    { login: 'zm', token: 'tok_a', name: '周铭', addedAt: 100 },
    { login: 'bob', token: 'tok_b', name: 'Bob', addedAt: 200 }
  ];
  const restored = accountsFromStorage(accountsToStorage(accounts));
  assert.equal(restored.length, 2);
  assert.equal(restored[0].login, 'zm');
  assert.equal(restored[0].name, '周铭');
  assert.equal(restored[0].addedAt, 100);
  assert.equal(restored[1].login, 'bob');
});

test('accountsFromStorage 坏 JSON/非数组/空串回退空表', () => {
  assert.equal(accountsFromStorage('').length, 0);
  assert.equal(accountsFromStorage('{{bad').length, 0);
  assert.equal(accountsFromStorage('{}').length, 0);
  assert.equal(accountsFromStorage('null').length, 0);
  assert.equal(accountsFromStorage('[]').length, 0);
});

test('accountsFromStorage 残缺条目（缺 login/token）剔除', () => {
  const items = JSON.stringify([
    { login: 'a', token: 't1' },
    { login: '', token: 't2' },
    { login: 'b', token: '' },
    { token: 't3' },
    { login: 'c', token: 't4', name: 'N', addedAt: 1 }
  ]);
  const restored = accountsFromStorage(items);
  assert.equal(restored.length, 2);
  assert.equal(restored[0].login, 'a');
  assert.equal(restored[1].login, 'c');
});

test('legacyToAccount v1 → v2 映射（login/name 失败为空串）', () => {
  const a = legacyToAccount('tok_v1', '', '', 42);
  assert.equal(a.login, '');
  assert.equal(a.name, '');
  assert.equal(a.token, 'tok_v1');
  assert.equal(a.addedAt, 42);
});

test('nextAddResult 查重与 5 个上限', () => {
  const mk = (login: string) => ({ login, token: 't', name: '', addedAt: 0 });
  assert.equal(nextAddResult([], 'a'), 0); // OK
  assert.equal(nextAddResult([mk('a'), mk('b')], 'a'), 1); // DUPLICATE
  const five = [mk('a'), mk('b'), mk('c'), mk('d'), mk('e')];
  assert.equal(nextAddResult(five, 'f'), 2); // LIMIT
  assert.equal(nextAddResult(five, 'a'), 1); // 满员时重复仍走 DUPLICATE（重新授权语义）
  const four = [mk('a'), mk('b'), mk('c'), mk('d')];
  assert.equal(nextAddResult(four, 'e'), 0);
});

test('Share：各页面分享地址构造（Spec 061）', () => {
  assert.equal(userPageUrl('ZM-BAD'), 'https://github.com/ZM-BAD');
  assert.equal(repoPageUrl('ZM-BAD', 'arkcat'), 'https://github.com/ZM-BAD/arkcat');
  assert.equal(blobPageUrl('ZM-BAD', 'arkcat', 'entry/src/Index.ets'),
    'https://github.com/ZM-BAD/arkcat/blob/HEAD/entry/src/Index.ets');
  assert.equal(pullPageUrl('ZM-BAD', 'arkcat', 42), 'https://github.com/ZM-BAD/arkcat/pull/42');
  assert.equal(issuePageUrl('deno', 'deno', 1), 'https://github.com/deno/deno/issues/1');
  assert.equal(commitPageUrl('ZM-BAD', 'arkcat', 'a1b2c3'),
    'https://github.com/ZM-BAD/arkcat/commit/a1b2c3');
});

test('Share：repoTreeUrl 根目录回落仓库主页、子目录带 tree/HEAD', () => {
  assert.equal(repoTreeUrl('ZM-BAD', 'arkcat', ''), 'https://github.com/ZM-BAD/arkcat');
  assert.equal(repoTreeUrl('ZM-BAD', 'arkcat', 'entry/src'),
    'https://github.com/ZM-BAD/arkcat/tree/HEAD/entry/src');
});

test('OpenSource：披露条目与许可文本（Spec 064）', async () => {
  const { OPEN_SOURCE_ENTRIES } = await import('../../entry/src/main/ets/models/OpenSourceModels');
  assert.equal(OPEN_SOURCE_ENTRIES.length, 2);
  assert.equal(OPEN_SOURCE_ENTRIES[0].name, 'Octicons');
  assert.equal(OPEN_SOURCE_ENTRIES[0].url, 'https://github.com/primer/octicons');
  assert.equal(OPEN_SOURCE_ENTRIES[1].name, 'Primer Design Primitives');
  assert.equal(OPEN_SOURCE_ENTRIES[1].url, 'https://github.com/primer/primitives');
  // Octicons 许可正文须与仓库归档 LICENSE 逐字一致（防双处漂移）
  const { readFileSync } = await import('node:fs');
  const { join } = await import('node:path');
  const file = readFileSync(join(process.cwd(), 'assets/octicons/LICENSE'), 'utf-8');
  assert.equal(OPEN_SOURCE_ENTRIES[0].licenseText.trim(), file.replace(/\r\n/g, '\n').trim());
  // 每条许可文本都包含其版权行与 license 名（渲染区块数据完整）
  for (const entry of OPEN_SOURCE_ENTRIES) {
    assert.ok(entry.licenseText.includes(entry.copyrightLine));
    assert.ok(entry.licenseText.startsWith('MIT License'));
  }
});

test('WorkDiscussions：单仓库模式（Share Feedback，Spec 065）', async () => {
  const { buildWorkDiscussionsQuery } = await import('../../entry/src/main/ets/models/WorkModels');
  // repo 模式：repo: 限定 + 无个人归属 qualifier
  const q = buildWorkDiscussionsQuery('open', 'created', false, 'new', 'ZM-BAD/arkcat');
  assert.equal(q, 'is:discussion is:open repo:ZM-BAD/arkcat sort:created-desc');
  // 全局模式不受影响：仍走 author:@me
  assert.equal(buildWorkDiscussionsQuery('open', 'created', false, 'new'),
    'is:discussion is:open author:@me sort:created-desc');
});

test('WorkDiscussions：Author/Label qualifier 与映射（Spec 065）', async () => {
  const m = await import('../../entry/src/main/ets/models/WorkModels');
  // author + label 组合
  assert.equal(m.buildWorkDiscussionsQuery('open', 'created', false, 'new', 'ZM-BAD/arkcat', 'zccz14', ''),
    'is:discussion is:open repo:ZM-BAD/arkcat author:zccz14 sort:created-desc');
  // 带空格标签名加引号；none → no:label
  assert.equal(m.buildWorkDiscussionsQuery('all', 'created', false, 'new', 'ZM-BAD/arkcat', '', 'A Welcome'),
    'is:discussion repo:ZM-BAD/arkcat label:"A Welcome" sort:created-desc');
  assert.equal(m.buildWorkDiscussionsQuery('all', 'created', false, 'new', 'ZM-BAD/arkcat', '', 'none'),
    'is:discussion repo:ZM-BAD/arkcat no:label sort:created-desc');
  // Category qualifier：单词直接跟，带空格/标点引号包裹（2026-09-14 实测 deno：category:Q&A=458、category:"show and tell"=13）
  assert.equal(m.buildWorkDiscussionsQuery('all', 'created', false, 'new', 'denoland/deno', '', '', 'Q&A'),
    'is:discussion repo:denoland/deno category:Q&A sort:created-desc');
  assert.equal(m.buildWorkDiscussionsQuery('all', 'created', false, 'new', 'denoland/deno', '', '', 'Show and tell'),
    'is:discussion repo:denoland/deno category:"Show and tell" sort:created-desc');
  // emoji shortcode 转换（官方默认六分类）
  assert.equal(m.emojiFromShortcode(':mega:'), '\u{1F4E3}');
  assert.equal(m.emojiFromShortcode(':raised_hands:'), '\u{1F64C}');
  assert.equal(m.emojiFromShortcode(':unknown_emoji:'), '');
  // 映射：作者 + 标签节点
  const item = m.mapDiscussion({
    id: 'd1', number: 3, title: 'T', state: 'OPEN', createdAt: '',
    repository: { nameWithOwner: 'ZM-BAD/arkcat' }, category: { name: 'Ideas' },
    comments: { totalCount: 1 },
    author: { login: 'zccz14', name: 'CZ', avatarUrl: 'https://a/b.png' },
    labels: { nodes: [{ name: 'Bug', color: 'D73A4A' }] }
  });
  assert.equal(item.authorLogin, 'zccz14');
  assert.equal(item.authorName, 'CZ');
  assert.equal(item.labels.length, 1);
  assert.equal(item.labels[0].color, 'D73A4A');
  // 作者去重
  const dup = m.mapDiscussion(JSON.parse(JSON.stringify({
    id: 'd2', number: 4, title: 'T2', state: 'OPEN', createdAt: '',
    author: { login: 'zccz14', name: 'CZ', avatarUrl: '' }
  })));
  assert.equal(m.collectDiscussionAuthors([item, dup]).length, 1);
  // labels 映射
  assert.equal(m.mapRepoLabels({ repository: { labels: { nodes: [{ name: 'Bug', color: 'D73A4A' }] } } }).length, 1);
});

test('AppLock：偏好归一化（Spec 066）', async () => {
  const m = await import('../../entry/src/main/ets/utils/AppLock');
  // 仅 '1' 视为开启
  assert.equal(m.normalizeAppLockPref('1'), true);
  // 缺省/脏值一律 OFF（未设置过/偏好损坏不得误锁）
  assert.equal(m.normalizeAppLockPref(''), false);
  assert.equal(m.normalizeAppLockPref('0'), false);
  assert.equal(m.normalizeAppLockPref('true'), false);
  assert.equal(m.normalizeAppLockPref(undefined), false);
  assert.equal(m.normalizeAppLockPref(null), false);
  // 键名与 AppStorage 键约定
  assert.equal(m.KEY_APP_LOCK, 'app_lock_enabled');
  assert.equal(m.APP_LOCK_ENABLED_KEY, 'appLockEnabled');
  assert.equal(m.APP_LOCK_LOCKED_KEY, 'appLockLocked');
});

test('DataColors：感知光感官方公式（无 gamma 解码，DESIGN.md §1.2）', async () => {
  const m = await import('../../entry/src/main/ets/utils/DataColors');
  const bug = m.parseHexColor('d73a4a');
  assert.notEqual(bug, null);
  // (215*0.2126 + 58*0.7152 + 74*0.0722)/255 = 0.362876…
  assert.ok(Math.abs(m.perceivedLightness(bug!) - 0.362876) < 0.0001);
  // 非法输入
  assert.equal(m.parseHexColor('xyz'), null);
  assert.equal(m.parseHexColor(''), null);
  // HSL 往返
  assert.equal(m.hslToHex(m.rgbToHsl(bug!)), '#D73A4A');
});

test('DataColors：文字黑白 0.6 阈值（官方移动端口径，10 标签验证集）', async () => {
  const m = await import('../../entry/src/main/ets/utils/DataColors');
  // 白字组（PL < 0.6）
  assert.equal(m.labelTextColor('d73a4a', 'light'), '#FFFFFF'); // bug 0.3629
  assert.equal(m.labelTextColor('d876e3', 'light'), '#FFFFFF'); // question 0.5753 —— web 端 0.453 会误判黑字的关键样本
  assert.equal(m.labelTextColor('7057ff', 'light'), '#FFFFFF'); // good first issue 0.4096
  // 黑字组（PL ≥ 0.6）
  assert.equal(m.labelTextColor('ededed', 'light'), '#000000'); // dependencies 0.9294
  assert.equal(m.labelTextColor('a2eeef', 'light'), '#000000'); // enhancement 0.8703
  assert.equal(m.labelTextColor('ffffff', 'light'), '#000000'); // wontfix 1.0
});

test('DataColors：亮色实底 / 暗色 18% 透明底', async () => {
  const m = await import('../../entry/src/main/ets/utils/DataColors');
  assert.equal(m.labelBackground('d73a4a', 'light'), '#D73A4A');
  assert.equal(m.labelBackground('d73a4a', 'dark'), 'rgba(215,58,74,0.18)');
  assert.equal(m.labelBackground('bad', 'light'), 'transparent');
});

test('DataColors：近白发丝描边（PL>0.96）与暗色 30% 描边', async () => {
  const m = await import('../../entry/src/main/ets/utils/DataColors');
  // wontfix #ffffff：PL=1.0 > 0.96 → 同色相 L−25 = #BFBFBF，alpha=0.04 → #0A…
  assert.equal(m.labelBorder('ffffff', 'light'), '#0ABFBFBF');
  // dependencies #ededed：PL 0.9294 ≤ 0.96 → 无描边
  assert.equal(m.labelBorder('ededed', 'light'), '');
  assert.equal(m.labelBorder('d73a4a', 'light'), '');
  // 暗色：提亮文字色 30% 透明
  assert.ok(m.labelBorder('d73a4a', 'dark').startsWith('#4D'));
});

test('DataColors：暗色提亮公式 lightenBy=(0.6−PL)×100', async () => {
  const m = await import('../../entry/src/main/ets/utils/DataColors');
  // d73a4a：PL=0.3629，HSL(353.9°,66.5%,52.7%) → L+23.71=76.45% → #EB9FA6
  assert.equal(m.labelTextColor('d73a4a', 'dark'), '#EB9FA6');
  // 近白标签暗色不提亮（switch=0）：保持原色
  assert.equal(m.labelTextColor('ffffff', 'dark'), '#FFFFFF');
});

// ===== graphql 库（HAR 模块）纯函数测试：宿主直跑真库源码（build-ut.mjs 裸包名映射） =====
import {
  escapeGraphQLString, aliasField, aliasQueryDocument,
  readConnectionPage, fetchAllPages,
  RequestSequencer, withFallback, runBounded,
  readRateLimit, retryDelayMs
} from '../../graphql/src/main/ets/Index';
import { mapGitHubErrorType } from '../../entry/src/main/ets/services/GitHttpClient';

test('escapeGraphQLString：反斜杠/双引号/换行/回车', () => {
  assert.equal(escapeGraphQLString('a\\b'), 'a\\\\b');
  assert.equal(escapeGraphQLString('say "hi"'), 'say \\"hi\\"');
  assert.equal(escapeGraphQLString('line1\nline2'), 'line1 line2');
  assert.equal(escapeGraphQLString('a\rb'), 'a b');
  assert.equal(escapeGraphQLString('plain'), 'plain');
});

test('aliasField：字符串转义加引号 / 数值直插', () => {
  assert.equal(aliasField('r0', 'repository', [
    { 'name': 'owner', 'value': 'a' }, { 'name': 'name', 'value': 'b' }
  ], 'openGraphImageUrl'),
    'r0: repository(owner: "a", name: "b") { openGraphImageUrl }');
  assert.equal(
    aliasField('r0', 'repository', [
      { 'name': 'owner', 'value': 'o' }, { 'name': 'name', 'value': 'n' }
    ], 'pullRequest(number: 8) { id }'),
    'r0: repository(owner: "o", name: "n") { pullRequest(number: 8) { id } }');
  assert.equal(aliasField('u0', 'user', [{ 'name': 'login', 'value': 42 }], 'login'),
    'u0: user(login: 42) { login }');
  // 含引号的恶意串被转义，不会破坏 document 结构
  assert.ok(aliasField('r1', 'repository', [
    { 'name': 'owner', 'value': 'a" } invalid' }, { 'name': 'name', 'value': 'b' }
  ], 'id').includes('\\" } invalid'));
});

test('aliasQueryDocument：具名/匿名 query', () => {
  assert.equal(aliasQueryDocument('Op', ['a', 'b']), 'query Op {\n  a\n  b\n}');
  assert.equal(aliasQueryDocument('', ['x']), 'query {\n  x\n}');
});

test('readConnectionPage：nodes/edges/缺失节点三态', () => {
  const nodesConn: JsonMap = {
    'pageInfo': { 'hasNextPage': true, 'endCursor': 'cur1' },
    'nodes': [{ 'id': '1' }, { 'id': '2' }]
  };
  const p1 = readConnectionPage(nodesConn, (n) => Json.str(n, 'id'));
  assert.deepEqual(p1.items, ['1', '2']);
  assert.equal(p1.hasNextPage, true);
  assert.equal(p1.endCursor, 'cur1');
  const edgesConn: JsonMap = {
    'pageInfo': { 'hasNextPage': false, 'endCursor': '' },
    'edges': [{ 'node': { 'id': '9' } }]
  };
  const p2 = readConnectionPage(edgesConn, (n) => Json.str(n, 'id'), true);
  assert.deepEqual(p2.items, ['9']);
  assert.equal(p2.hasNextPage, false);
  const p3 = readConnectionPage(null, (n) => Json.str(n, 'id'));
  assert.deepEqual(p3.items, []);
  assert.equal(p3.hasNextPage, false);
  // 缺 pageInfo：不抛错，按无下一页处理
  const p4 = readConnectionPage({ 'nodes': [] } as JsonMap, (n) => Json.str(n, 'id'));
  assert.equal(p4.hasNextPage, false);
});

test('fetchAllPages：游标链式续拉 / hasNextPage 判停 / maxPages 上限', async () => {
  // 三页数据，hasNextPage 判停（末页 endCursor 非空也不再多打）
  const pages: Record<string, string[]> = { 'null': ['a'], 'cur1': ['b'], 'cur2': ['c'] };
  const next: Record<string, string> = { 'null': 'cur1', 'cur1': 'cur2', 'cur2': '' };
  const more: Record<string, boolean> = { 'null': true, 'cur1': true, 'cur2': false };
  const seen: string[] = [];
  const got = await fetchAllPages<string>(async (cursor) => {
    const key = cursor === null ? 'null' : cursor;
    seen.push(key);
    return { items: pages[key], hasNextPage: more[key], endCursor: next[key] };
  });
  assert.deepEqual(got, ['a', 'b', 'c']);
  assert.deepEqual(seen, ['null', 'cur1', 'cur2']);
  // maxPages=2：第三页不再拉
  const seen2: string[] = [];
  await fetchAllPages<string>(async (cursor) => {
    const key = cursor === null ? 'null' : cursor;
    seen2.push(key);
    return { items: pages[key], hasNextPage: true, endCursor: next[key] };
  }, 2);
  assert.equal(seen2.length, 2);
  // fetchPage 内降级（catch 返回终止页）：已取页保留、不再续拉
  const got3 = await fetchAllPages<string>(async (cursor) => {
    if (cursor !== null) {
      return { items: [], hasNextPage: false, endCursor: '' };
    }
    return { items: ['only'], hasNextPage: true, endCursor: 'x' };
  });
  assert.deepEqual(got3, ['only']);
});

test('mapGitHubErrorType：GitHub 错误词汇表（适配层注入库 mapper）', () => {
  assert.equal(mapGitHubErrorType('RATE_LIMITED'), 429);
  assert.equal(mapGitHubErrorType('FORBIDDEN'), 403);
  assert.equal(mapGitHubErrorType('INSUFFICIENT_SCOPE'), 403);
  assert.equal(mapGitHubErrorType('ACCESS_DENIED'), 403);
  assert.equal(mapGitHubErrorType('NOT_FOUND'), 404);
  assert.equal(mapGitHubErrorType('UNPROCESSABLE'), 422);
  assert.equal(mapGitHubErrorType('VALIDATION'), 422);
  assert.equal(mapGitHubErrorType('UNAUTHORIZED'), 401);
  assert.equal(mapGitHubErrorType('UNKNOWN_TYPE'), 200);
});

test('RequestSequencer：旧请求按序号丢弃', () => {
  const seq = new RequestSequencer();
  const first = seq.begin();
  assert.ok(seq.isCurrent(first));
  const second = seq.begin();
  assert.ok(seq.isCurrent(second));
  assert.ok(!seq.isCurrent(first));
});

test('withFallback：失败返回兜底值', async () => {
  assert.equal(await withFallback(Promise.resolve(7), 0), 7);
  assert.equal(await withFallback(Promise.reject(new Error('x')), 0), 0);
});

test('runBounded：分批并行且保序', async () => {
  const order: number[] = [];
  const got = await runBounded<number, string>([1, 2, 3, 4, 5], 2, async (n) => {
    order.push(n);
    return `v${n}`;
  });
  assert.deepEqual(got, ['v1', 'v2', 'v3', 'v4', 'v5']);
  assert.equal(order.length, 5);
});

test('readRateLimit：标准头/缺失头/非法值三态', () => {
  const info = readRateLimit({
    'x-ratelimit-limit': '5000',
    'x-ratelimit-remaining': '4999',
    'x-ratelimit-reset': '1757900000',
    'x-ratelimit-resource': 'graphql'
  });
  assert.equal(info?.limit, 5000);
  assert.equal(info?.remaining, 4999);
  assert.equal(info?.reset, 1757900000);
  assert.equal(info?.resource, 'graphql');
  // 缺头 → null（非 GitHub 响应）
  assert.equal(readRateLimit({ 'content-type': 'application/json' }), null);
  // 非法值 → null
  assert.equal(readRateLimit({ 'x-ratelimit-limit': 'abc', 'x-ratelimit-remaining': '1' }), null);
});

test('retryDelayMs：500ms 起步指数退避、4s 封顶', () => {
  assert.equal(retryDelayMs(0), 500);
  assert.equal(retryDelayMs(1), 1000);
  assert.equal(retryDelayMs(2), 2000);
  assert.equal(retryDelayMs(3), 4000);
  assert.equal(retryDelayMs(4), 4000);
  assert.equal(retryDelayMs(10), 4000);
});
