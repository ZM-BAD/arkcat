/**
 * PR Diff patch 解析（Spec 010）：REST /pulls/{n}/files 的 patch 字段 → hunk 结构。
 * 纯函数便于单元测试；hunk 行号从 @@ -old,count +new,count @@ 计算（0 表示无效行号）。
 */
export type DiffLineKind = 'add' | 'del' | 'ctx';

export interface DiffLine {
  kind: DiffLineKind;
  /** 行内容（不含差分前缀 + / - / 空格） */
  text: string;
  /** 旧文件行号（add 行为 0） */
  oldLine: number;
  /** 新文件行号（del 行为 0） */
  newLine: number;
}

export interface DiffHunk {
  /** 保留原始 header（如 "@@ -0,0 +1,2 @@"）用于标题行渲染 */
  header: string;
  oldStart: number;
  newStart: number;
  lines: DiffLine[];
}

const HUNK_RE = /^@@ -([0-9]+)(?:,([0-9]+))? \+([0-9]+)(?:,([0-9]+))? @@/;

/** 解析一个 hunk header，返回起始行号（解析失败回退 0/0，渲染时按普通行处理） */
function parseHunkHeader(header: string): DiffHunk {
  const m = HUNK_RE.exec(header);
  if (m === null) {
    return { header: header, oldStart: 0, newStart: 0, lines: [] };
  }
  return {
    header: header,
    oldStart: Number(m[1] ?? '0'),
    newStart: Number(m[3] ?? '0'),
    lines: []
  };
}

/**
 * 解析 patch 文本为 hunk 列表。
 * 规则：@@ 之前的文件头（--- a/…、+++ b/…）跳过；hunk 内 + 为新增、- 为删除、
 * 空格为上下文、\ 开头为 "No newline at end of file" 标记（跳过）；CRLF 行尾 \r 剔除。
 */
export function parseDiffPatch(patch: string): DiffHunk[] {
  if (patch === '') {
    return [];
  }
  const rawLines: string[] = patch.split('\n');
  const hunks: DiffHunk[] = [];
  let current: DiffHunk | null = null;
  let oldLine = 0;
  let newLine = 0;
  for (let i = 0; i < rawLines.length; i++) {
    const raw = rawLines[i];
    const line = raw.endsWith('\r') ? raw.substring(0, raw.length - 1) : raw;
    if (line.startsWith('@@')) {
      current = parseHunkHeader(line);
      if (current.oldStart > 0 || current.newStart > 0) {
        hunks.push(current);
        oldLine = current.oldStart - 1;
        newLine = current.newStart - 1;
        continue;
      }
      if (current.lines.length === 0) {
        // header 解析失败（非标准行）视为纯文本，跳过
        current = null;
        continue;
      }
    }
    if (current === null) {
      continue;
    }
    if (line === '') {
      // 仅 split 产生的末尾空元素跳过；hunk 内空上下文行按上下文处理防行号错位（review H3）
      if (i === rawLines.length - 1) {
        continue;
      }
      oldLine += 1;
      newLine += 1;
      current.lines.push({ kind: 'ctx', text: '', oldLine: oldLine, newLine: newLine });
      continue;
    }
    if (line.startsWith('\\')) {
      // "No newline at end of file" 标记：不渲染
      continue;
    }
    if (line.startsWith('+')) {
      newLine += 1;
      current.lines.push({ kind: 'add', text: line.substring(1), oldLine: 0, newLine: newLine });
    } else if (line.startsWith('-')) {
      oldLine += 1;
      current.lines.push({ kind: 'del', text: line.substring(1), oldLine: oldLine, newLine: 0 });
    } else {
      oldLine += 1;
      newLine += 1;
      current.lines.push({ kind: 'ctx', text: line.substring(1), oldLine: oldLine, newLine: newLine });
    }
  }
  return hunks;
}

/** 文件路径的末段（文件头展示截断用） */
export function fileBaseName(path: string): string {
  const idx = path.lastIndexOf('/');
  return idx >= 0 ? path.substring(idx + 1) : path;
}
