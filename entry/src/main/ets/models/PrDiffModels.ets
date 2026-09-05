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
  /** 二进制文件（REST 不返回 patch 但非大 diff，review H4） */
  isBinary: boolean;
  /** 页面展开态（父数组重建刷新） */
  expanded: boolean;
}

/** 官方「Binary file not shown」判定：常见二进制扩展名（REST 无 is_binary 字段，按扩展名近似） */
const BINARY_EXTS: string[] = ['png', 'jpg', 'jpeg', 'gif', 'webp', 'ico', 'bmp', 'tiff', 'pdf', 'zip', 'gz',
  'tar', 'rar', '7z', 'dmg', 'exe', 'dll', 'so', 'dylib', 'bin', 'jar', 'class', 'woff', 'woff2', 'ttf', 'eot',
  'otf', 'mp3', 'mp4', 'mov', 'avi', 'mkv', 'wav', 'flac', 'psd', 'ai', 'sketch', 'db', 'sqlite'];

export function isBinaryPath(path: string): boolean {
  const name = path.toLowerCase();
  const dot = name.lastIndexOf('.');
  if (dot < 0) {
    return false;
  }
  return BINARY_EXTS.includes(name.substring(dot + 1));
}

export interface PrFilesPage {
  /** 标题计数（GraphQL files.totalCount） */
  totalCount: number;
  /** PR id（评论 mutation 用） */
  pullRequestId: string;
  /** 变动统计（标题栏副标题 +N -N） */
  additions: number;
  deletions: number;
  files: PrFileItem[];
}

/** GraphQL 单个文件节点 → PrFileItem（fetchPrFiles 翻页复用） */
export function mapFileNode(node: JsonMap): PrFileItem {
  if (node === null || node === undefined) {
    return { path: '', additions: 0, deletions: 0, status: '', patch: '', hunks: [], diffTooLarge: false, isBinary: false, expanded: false };
  }  return {
    path: Json.str(node, 'path'),
    additions: Json.num(node, 'additions'),
    deletions: Json.num(node, 'deletions'),
    status: Json.str(node, 'status'),
    patch: '',
    hunks: [],
    diffTooLarge: false,
    isBinary: isBinaryPath(Json.str(node, 'path')),
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
    additions: Json.num(pr, 'additions'),
    deletions: Json.num(pr, 'deletions'),
    files: nodes
  };
}

/** files 连接页游标（fetchPrFiles >100 文件翻页用，review G4） */
export function mapFilesCursor(data: JsonMap): string {
  const repo = Json.obj(data, 'repository') ?? ({} as JsonMap);
  const pr = Json.obj(repo, 'pullRequest') ?? ({} as JsonMap);
  const files = Json.obj(pr, 'files') ?? ({} as JsonMap);
  return Json.str(Json.obj(files, 'pageInfo') ?? ({} as JsonMap), 'endCursor');
}

/** REST item（含 patch）→ PrFileItem（patch 仅当存在且非空） */
export function applyRestPatch(item: PrFileItem, rest: JsonMap): PrFileItem {  const patch = Json.str(rest, 'patch');
  const binary = isBinaryPath(item.path);
  let hunks: DiffHunk[] = [];
  let tooLarge = false;
  if (patch !== '') {
    hunks = parseDiffPatch(patch);
    if (hunks.length === 0) {
      tooLarge = true;
    }
  } else if (!binary) {
    // 二进制文件本就无 patch，不算大 diff（review H4）
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
    isBinary: binary,
    expanded: false
  };
}

// ─────────────── Commit 详情（参考官方 Commit 页：CHANGES/DETAILS 双 tab） ───────────────

/** Commit 变更文件（REST /commits/{sha} 的 files + patch 解析） */
export interface CommitFileItem {
  path: string;
  status: string;
  additions: number;
  deletions: number;
  hunks: DiffHunk[];
}

/** Associated Pull Requests 行 */
export interface CommitPullItem {
  number: number;
  title: string;
}

export interface CommitDetailPage {
  oid: string;
  headline: string;
  messageBodyHTML: string;
  /** 完整 message 文本（REST commit.message；标题区显示全文） */
  message: string;
  committedDate: string;
  checksState: string;
  authorLogin: string;
  authorAvatar: string;
  parents: string[];
  files: CommitFileItem[];
  pullRequests: CommitPullItem[];
}

/** GraphQL object(expression: oid) → CommitDetailPage（files/parents/pulls 由 fetchCommitDetail 走 REST 回填） */
export function mapCommitDetail(data: JsonMap): CommitDetailPage {
  const repo = Json.obj(data, 'repository') ?? ({} as JsonMap);
  const obj = Json.obj(repo, 'object') ?? ({} as JsonMap);
  const author = Json.obj(obj, 'author');
  const authorUser = author !== null ? Json.obj(author, 'user') : null;
  const authorLogin = authorUser !== null && Json.str(authorUser, 'login') !== ''
    ? Json.str(authorUser, 'login')
    : (author !== null ? Json.str(author, 'name') : '');
  const checks = Json.obj(obj, 'statusCheckRollup');
  return {
    oid: Json.str(obj, 'oid'),
    headline: Json.str(obj, 'messageHeadline'),
    messageBodyHTML: Json.str(obj, 'messageBodyHTML'),
    message: '',
    committedDate: Json.str(obj, 'committedDate'),
    checksState: checks !== null ? Json.str(checks, 'state') : '',
    authorLogin: authorLogin,
    authorAvatar: author !== null ? Json.str(author, 'avatarUrl') : '',
    parents: [],
    files: [],
    pullRequests: []
  };
}
