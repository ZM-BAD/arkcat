/**
 * PR Diff 数据模型与映射（Spec 010）：文件变更列表（GraphQL）+ patch hunk（REST）。
 * 模型保持纯数据；映射集中在 models/、patch 解析在 utils/Diff.ets（便于单元测试）。
 */
import { Json, JsonMap } from '../utils/Json';
import { DiffHunk, parseDiffPatch } from '../utils/Diff';

/** 变更文件行 */
export interface PrFileItem {
  path: string;
  additions: number;
  deletions: number;
  status: string;
  /** REST patch 原文（GraphQL 无 diff 字段） */
  patch: string;
  /** parseDiffPatch 产物（未拉取/空 patch 为空数组） */
  hunks: DiffHunk[];
  /** REST 未返回 patch（大 diff）时置 true */
  diffTooLarge: boolean;
  /** 页面展开态（父数组重建刷新） */
  expanded: boolean;
}

export interface PrFilesPage {
  /** 标题计数（GraphQL files.totalCount） */
  totalCount: number;
  /** PR id（评论 mutation 用） */
  pullRequestId: string;
  files: PrFileItem[];
}

function mapFileNode(node: JsonMap): PrFileItem {
  if (node === null || node === undefined) {
    return { path: '', additions: 0, deletions: 0, status: '', patch: '', hunks: [], diffTooLarge: false, expanded: false };
  }
  return {
    path: Json.str(node, 'path'),
    additions: Json.num(node, 'additions'),
    deletions: Json.num(node, 'deletions'),
    status: Json.str(node, 'status'),
    patch: '',
    hunks: [],
    diffTooLarge: false,
    expanded: false
  };
}

/** GraphQL pullRequest.files → PrFilesPage（patch 由 fetchPrFiles 的 REST 回填） */
export function mapPrFiles(data: JsonMap): PrFilesPage {
  const repo = Json.obj(data, 'repository') ?? ({} as JsonMap);
  const pr = Json.obj(repo, 'pullRequest') ?? ({} as JsonMap);
  const files = Json.obj(pr, 'files') ?? ({} as JsonMap);
  const nodes: PrFileItem[] = [];
  for (const n of Json.arr(files, 'nodes')) {
    nodes.push(mapFileNode(n as JsonMap));
  }
  return {
    totalCount: Json.num(files, 'totalCount'),
    pullRequestId: Json.str(pr, 'id'),
    files: nodes
  };
}

/** REST item（含 patch）→ PrFileItem（patch 仅当存在且非空） */
export function applyRestPatch(item: PrFileItem, rest: JsonMap): PrFileItem {
  const patch = Json.str(rest, 'patch');
  let hunks: DiffHunk[] = [];
  let tooLarge = false;
  if (patch !== '') {
    hunks = parseDiffPatch(patch);
    if (hunks.length === 0) {
      tooLarge = true;
    }
  } else {
    tooLarge = true;
  }
  return {
    path: item.path,
    additions: Json.num(rest, 'additions', item.additions),
    deletions: Json.num(rest, 'deletions', item.deletions),
    status: Json.str(rest, 'status', item.status),
    patch: patch,
    hunks: hunks,
    diffTooLarge: tooLarge,
    expanded: false
  };
}
