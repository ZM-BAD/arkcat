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
  filterPrsByAuthor, filterPrsByAssignee, repoPrIconKey, RepoPrItem
} from '../../entry/src/main/ets/models/RepoSubModels';
import { mapPrFiles, mapFilesCursor, applyRestPatch, PrFileItem } from '../../entry/src/main/ets/models/PrDiffModels';

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
