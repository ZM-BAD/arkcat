/**
 * Local Test：utils/models 纯函数层（官方 ArkTS 语义；与 scripts/ut 宿主 node:test 同域子集）。
 * 运行：hvigorw test -p module=entry -p coverage=true（macOS/Windows；Linux 不支持）。
 * 覆盖面：Json/Format/Diff/WorkConfig/RepoSubModels/PrDiffModels 核心分支。
 */
import { describe, it, expect } from '@ohos/hypium';
import { Json, JsonMap } from '../main/ets/utils/Json.ets';
import { timeParts, githubShortTime, compactCount, notificationTypeKey } from '../main/ets/utils/Format.ets';
import { parseDiffPatch, fileBaseName } from '../main/ets/utils/Diff.ets';
import {
  defaultWorkSections, visibleWorkSections, workSectionsToStorage, workSectionsFromStorage, WorkSection
} from '../main/ets/utils/WorkConfig.ets';
import {
  mapRepoCommit, mapRepoCommitsPage, mapPrCommits,
  filterPrsByAuthor, filterPrsByAssignee, repoPrIconKey, RepoPrItem
} from '../main/ets/models/RepoSubModels.ets';
import { mapPrFiles, mapFilesCursor, applyRestPatch, PrFileItem } from '../main/ets/models/PrDiffModels.ets';
import {
  accountsToStorage, accountsFromStorage, legacyToAccount, nextAddResult, AccountInfo
} from '../main/ets/services/AccountStore.ets';

const NOW = Date.parse('2026-08-31T12:00:00Z');
const MINUTE_MS = 60 * 1000;
const DAY_MS = 24 * 60 * MINUTE_MS;

function jsonMap(): JsonMap {
  const obj: JsonMap = { 'k': 'v' };
  return { 'a': 'x', 'n': 5, 'b': true, 'obj': obj, 'arr': [1, 2] };
}

function prRow(id: string, authorLogin: string, assignees: string[]): RepoPrItem {
  return {
    id: id, number: 1, title: 't', state: 'OPEN', merged: false, isDraft: false, createdAt: '',
    labels: [], commentCount: 0, reviewCount: 0, checksState: '', authorLogin: authorLogin,
    authorAvatar: '', assignees: assignees
  };
}

function fileItem(path: string): PrFileItem {
  return {
    path: path, additions: 0, deletions: 0, status: 'ADDED', patch: '',
    hunks: [], diffTooLarge: false, isBinary: false, expanded: false
  };
}

export function UtPureLogicTest() {
  describe('UtPureLogic', () => {
    it('Json 兜底', 0, () => {
      const m = jsonMap();
      expect(Json.str(m, 'a')).assertEqual('x');
      expect(Json.str(m, 'missing', 'd')).assertEqual('d');
      expect(Json.num(m, 'n')).assertEqual(5);
      expect(Json.bool(m, 'b')).assertTrue();
      expect(Json.bool(m, 'a')).assertFalse();
      expect(Json.obj(m, 'missing')).assertNull();
      expect(Json.arr(m, 'missing').length).assertEqual(0);
    });

    it('Json.parse 分支', 0, () => {
      expect(Json.parse('{"k":"v"}') !== null).assertTrue();
      expect(Json.parse('42')).assertNull();
      expect(Json.parse('"x"')).assertNull();
      expect(Json.parse('null')).assertNull();
      expect(Json.parse('{bad json')).assertNull();
    });

    it('timeParts 档位与边界', 0, () => {
      expect(timeParts('2026-08-31T11:59:50Z', NOW)?.unit).assertEqual('just_now');
      expect(timeParts('2026-08-31T11:55:00Z', NOW)?.value).assertEqual(5);
      expect(timeParts('2026-08-31T09:00:00Z', NOW)?.unit).assertEqual('hour');
      expect(timeParts('2026-05-31T12:00:00Z', NOW)?.value).assertEqual(3);
      expect(timeParts('2025-08-31T12:00:00Z', NOW)?.unit).assertEqual('year');
      expect(timeParts('bad-date', NOW)).assertNull();
      expect(timeParts('2099-01-01T00:00:00Z', NOW)?.unit).assertEqual('just_now');
    });

    it('timeParts 精确边界（30 天/31 天）', 0, () => {
      expect(timeParts(new Date(NOW - 30 * DAY_MS).toISOString(), NOW)?.value).assertEqual(30);
      expect(timeParts(new Date(NOW - 30 * DAY_MS).toISOString(), NOW)?.unit).assertEqual('day');
      expect(timeParts(new Date(NOW - 31 * DAY_MS).toISOString(), NOW)?.unit).assertEqual('month');
    });

    it('githubShortTime 全单位', 0, () => {
      expect(githubShortTime({ value: 0, unit: 'just_now' })).assertEqual('now');
      expect(githubShortTime({ value: 5, unit: 'minute' })).assertEqual('5m');
      expect(githubShortTime({ value: 22, unit: 'hour' })).assertEqual('22h');
      expect(githubShortTime({ value: 1, unit: 'day' })).assertEqual('1d');
      expect(githubShortTime({ value: 2, unit: 'month' })).assertEqual('2mo');
      expect(githubShortTime({ value: 3, unit: 'year' })).assertEqual('3y');
    });

    it('compactCount 与通知类型映射', 0, () => {
      expect(compactCount(999)).assertEqual('999');
      expect(compactCount(1500)).assertEqual('1.5k');
      expect(compactCount(12000)).assertEqual('12k');
      expect(notificationTypeKey('Issue')).assertEqual('issue');
      expect(notificationTypeKey('PullRequest')).assertEqual('pr');
      expect(notificationTypeKey('SecurityAlert')).assertEqual('security');
      expect(notificationTypeKey('UnknownType')).assertEqual('UnknownType');
    });

    it('parseDiffPatch 标准与多 hunk', 0, () => {
      const hunks = parseDiffPatch('@@ -1,2 +1,2 @@\n a\n-b\n+c\n d\n@@ -10,1 +10,2 @@\n e\n+f\n');
      expect(hunks.length).assertEqual(2);
      expect(hunks[0].oldStart).assertEqual(1);
      expect(hunks[1].newStart).assertEqual(10);
      expect(hunks[1].lines[1].kind).assertEqual('add');
      expect(hunks[1].lines[1].newLine).assertEqual(11);
    });

    it('parseDiffPatch CRLF/No-newline 标记', 0, () => {
      const crlf = parseDiffPatch('@@ -1,1 +1,2 @@\r\n ctx\r\n+added\r\n');
      expect(crlf[0].lines[1].text).assertEqual('added');
      const noNewline = parseDiffPatch('@@ -1,2 +1,2 @@\n ctx\n\\ No newline at end of file\n+add\n');
      expect(noNewline[0].lines.length).assertEqual(2);
    });

    it('parseDiffPatch 新文件/非法头/H3 空行', 0, () => {
      const fresh = parseDiffPatch('@@ -0,0 +1,2 @@\n+a\n+b\n');
      expect(fresh[0].oldStart).assertEqual(0);
      expect(fresh[0].lines[1].newLine).assertEqual(2);
      expect(parseDiffPatch('@@ -x +y @@\nctx\n').length).assertEqual(0);
      const blank = parseDiffPatch('@@ -1,2 +1,2 @@\n foo\n\n bar\n');
      expect(blank[0].lines[1].kind).assertEqual('ctx');
      expect(blank[0].lines[1].oldLine).assertEqual(2);
    });

    it('fileBaseName 提取', 0, () => {
      expect(fileBaseName('/a/b/c.ts')).assertEqual('c.ts');
      expect(fileBaseName('README.md')).assertEqual('README.md');
    });

    it('WorkConfig 默认与 roundtrip', 0, () => {
      const defaults = defaultWorkSections();
      expect(defaults.length >= 7).assertTrue();
      expect(defaults[0].id).assertEqual('issues');
      expect(workSectionsFromStorage(workSectionsToStorage(defaults)).length).assertEqual(defaults.length);
    });

    it('visibleWorkSections 与坏输入回退', 0, () => {
      const sections: WorkSection[] = [
        { id: 'issues', visible: true },
        { id: 'prs', visible: false }
      ];
      expect(visibleWorkSections(sections).length).assertEqual(1);
      expect(workSectionsFromStorage('{}').length).assertEqual(defaultWorkSections().length);
      expect(workSectionsFromStorage('{{bad').length).assertEqual(defaultWorkSections().length);
      expect(workSectionsFromStorage('[]').length).assertEqual(defaultWorkSections().length);
    });

    it('workSectionsFromStorage 非法/重复 id 剔除', 0, () => {
      const restored = workSectionsFromStorage('[{"id":"bogus"},{"id":"issues","visible":false},{"id":"issues"}]');
      expect(restored.length).assertEqual(1);
      expect(restored[0].id).assertEqual('issues');
      expect(restored[0].visible).assertFalse();
    });

    it('mapRepoCommit GitActor 兜底与缺省', 0, () => {
      const author: JsonMap = { 'name': '周铭', 'avatarUrl': '' };
      const checks: JsonMap = { 'state': 'SUCCESS' };
      const raw: JsonMap = {
        'oid': 'abc', 'messageHeadline': 'm', 'committedDate': '2026-08-31T10:00:00Z',
        'author': author, 'statusCheckRollup': checks
      };
      expect(mapRepoCommit(raw).authorLogin).assertEqual('周铭');
      const user: JsonMap = { 'login': 'zm-bad' };
      const author2: JsonMap = { 'name': 'Zhang', 'user': user };
      const raw2: JsonMap = {
        'oid': 'def', 'messageHeadline': 'm', 'committedDate': '2026-08-31T10:00:00Z',
        'author': author2
      };
      expect(mapRepoCommit(raw2).authorLogin).assertEqual('zm-bad');
      expect(mapRepoCommit({ 'oid': 'x', 'messageHeadline': 'm', 'committedDate': 'd' }).authorLogin).assertEqual('');
    });

    it('mapRepoCommitsPage/mapPrCommits 深链与兜底', 0, () => {
      const user: JsonMap = { 'login': 'u1' };
      const author: JsonMap = { 'name': 'N', 'user': user };
      const node: JsonMap = {
        'oid': 'aa', 'messageHeadline': 'm1', 'committedDate': 'd', 'author': author
      };
      const pageInfo: JsonMap = { 'hasNextPage': true, 'endCursor': 'c1' };
      const nodes: JsonMap[] = [node];
      const history: JsonMap = { 'pageInfo': pageInfo, 'nodes': nodes };
      const target: JsonMap = { 'history': history };
      const defaultBranchRef: JsonMap = { 'target': target };
      const repository: JsonMap = { 'defaultBranchRef': defaultBranchRef };
      const data: JsonMap = { 'repository': repository };
      const page = mapRepoCommitsPage(data);
      expect(page.hasNextPage).assertTrue();
      expect(page.commits[0].authorLogin).assertEqual('u1');
      expect(mapRepoCommitsPage({}).commits.length).assertEqual(0);
      expect(mapPrCommits({}).commits.length).assertEqual(0);
    });

    it('repoPrIconKey 与作者/分配人过滤', 0, () => {
      expect(repoPrIconKey('MERGED', true, false)).assertEqual('merged');
      expect(repoPrIconKey('OPEN', false, true)).assertEqual('draft');
      const prs: RepoPrItem[] = [prRow('1', 'alice', ['carol']), prRow('2', 'bob', [])];
      expect(filterPrsByAuthor(prs, 'alice').length).assertEqual(1);
      expect(filterPrsByAuthor(prs, '').length).assertEqual(2);
      expect(filterPrsByAssignee(prs, 'carol').length).assertEqual(1);
      expect(filterPrsByAssignee(prs, '').length).assertEqual(2);
    });

    it('mapPrFiles/mapFilesCursor', 0, () => {
      const pageInfo: JsonMap = { 'endCursor': 'abc' };
      const fileNode: JsonMap = { 'path': 'a.ts', 'additions': 12, 'deletions': 3, 'status': 'MODIFIED' };
      const nodes: JsonMap[] = [fileNode];
      const files: JsonMap = { 'totalCount': 1, 'pageInfo': pageInfo, 'nodes': nodes };
      const pr: JsonMap = { 'id': 'PRID', 'additions': 12, 'deletions': 3, 'files': files };
      const repository: JsonMap = { 'pullRequest': pr };
      const data: JsonMap = { 'repository': repository };
      const filesPage = mapPrFiles(data);
      expect(filesPage.totalCount).assertEqual(1);
      expect(filesPage.files[0].path).assertEqual('a.ts');
      expect(filesPage.pullRequestId).assertEqual('PRID');
      expect(mapFilesCursor(data)).assertEqual('abc');
      expect(mapFilesCursor({})).assertEqual('');
    });

    it('applyRestPatch 大 diff/二进制/缺省（H4）', 0, () => {
      const ok = applyRestPatch(fileItem('a.ts'),
        { 'patch': '@@ -1,1 +1,1 @@\n-a\n+b\n', 'additions': 1, 'deletions': 1, 'status': 'MODIFIED' });
      expect(ok.diffTooLarge).assertFalse();
      expect(ok.hunks.length).assertEqual(1);
      expect(applyRestPatch(fileItem('a.ts'), { 'patch': 'no hunks' }).diffTooLarge).assertTrue();
      expect(applyRestPatch(fileItem('a.ts'), { 'patch': '' }).diffTooLarge).assertTrue();
      const bin = applyRestPatch(fileItem('img.png'), { 'patch': '' });
      expect(bin.isBinary).assertTrue();
      expect(bin.diffTooLarge).assertFalse();
    });

    it('AccountStore 序列化 roundtrip 与坏输入回退', 0, () => {
      const accounts: AccountInfo[] = [
        { login: 'zm', token: 'tok_a', alias: '主号', name: '周铭', addedAt: 100 }
      ];
      const restored = accountsFromStorage(accountsToStorage(accounts));
      expect(restored.length).assertEqual(1);
      expect(restored[0].login).assertEqual('zm');
      expect(restored[0].alias).assertEqual('主号');
      expect(restored[0].name).assertEqual('周铭');
      expect(accountsFromStorage('{{bad').length).assertEqual(0);
      expect(accountsFromStorage('{}').length).assertEqual(0);
      expect(accountsFromStorage('[]').length).assertEqual(0);
    });

    it('AccountStore 残缺条目剔除与 legacy 映射', 0, () => {
      const items = '[{"login":"a","token":"t1"},{"login":"","token":"t2"},{"login":"b","token":""}]';
      expect(accountsFromStorage(items).length).assertEqual(1);
      expect(accountsFromStorage(items)[0].login).assertEqual('a');
      const legacy = legacyToAccount('tok_v1', '', '', 42);
      expect(legacy.login).assertEqual('');
      expect(legacy.token).assertEqual('tok_v1');
      expect(legacy.addedAt).assertEqual(42);
    });

    it('nextAddResult 查重与 5 个上限', 0, () => {
      const mk = (login: string): AccountInfo =>
        ({ login: login, token: 't', alias: '', name: '', addedAt: 0 });
      expect(nextAddResult([], 'a')).assertEqual(0);
      expect(nextAddResult([mk('a'), mk('b')], 'a')).assertEqual(1);
      const five: AccountInfo[] = [mk('a'), mk('b'), mk('c'), mk('d'), mk('e')];
      expect(nextAddResult(five, 'f')).assertEqual(2);
      expect(nextAddResult(five, 'a')).assertEqual(1);
      const four: AccountInfo[] = [mk('a'), mk('b'), mk('c'), mk('d')];
      expect(nextAddResult(four, 'e')).assertEqual(0);
    });
  });
}
