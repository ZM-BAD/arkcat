/**
 * 代码搜索结果（Spec 046 / 官方结果页批）：
 * - REST /search/code（text-match 媒体类型）取文件 + 匹配片段（fragment 无行号）
 * - 行号/高亮由文件内容级计算：拉取 contents API → 全文扫描匹配词
 *   （官方 App 同款效果：匹配行 + 上下文窗口 + 剩余匹配计数）
 * - 纯函数（splitLines/buildCodeSnippet/buildFragmentLines/buildCodeSnippet 便于单测）
 */
import { util } from '@kit.ArkTS';
import { restGet } from './GitHttpClient';
import { Json, JsonMap } from '../utils/Json';

/** 匹配高亮区间（相对行文本的列偏移） */
export interface CodeHighlight {
  start: number;
  end: number;
}

/** 代码展示行：no<=0 表示未知行号（内容获取失败兜底时不显示行号栏） */
export interface CodeLine {
  no: number;
  text: string;
  highlights: CodeHighlight[];
}

/** 卡片窗口切片：初始显示 + 展开追加 + 剩余匹配数 */
export interface CodeSnippet {
  window: CodeLine[];
  more: CodeLine[];
  totalMatches: number;
  windowMatches: number;
}

/** 代码搜索结果卡（页面渲染单元，一组 repo 内多个文件各自一张卡） */
export interface CodeFileResult {
  repoFullName: string;
  repoAvatarUrl: string;
  path: string;
  name: string;
  isMarkdown: boolean;
  snippet: CodeSnippet;
  /** 内容获取失败：仅 fragment 预览（无行号） */
  rawFallback: boolean;
}

/** 代码搜索分页结果（hasMore = page*perPage < total_count） */
export interface CodeSearchPage {
  files: CodeFileResult[];
  hasMore: boolean;
}

/** REST /search/code text_match.matches 子项 */
export interface RawMatch {
  text: string;
  indices: number[];
}

/** REST /search/code 原始文件项 */
export interface RawCodeFile {
  repoFullName: string;
  path: string;
  name: string;
  contentUrl: string;
  fragment: string;
  matches: RawMatch[];
}

const CODE_SEARCH_PATH = '/search/code?q=';
const TEXT_MATCH_ACCEPT = 'application/vnd.github.text-match+json';

/** 文件类型徽章文案：.md → Markdown，其余 → Text（官方两大分类） */
export function fileBadgeKey(fileName: string): string {
  return fileName.toLowerCase().endsWith('.md') ? 'markdown' : 'text';
}

/** 词字符判定：仅为字母/数字（GitHub code search 的 token 边界；_ 与 - 视为分隔符） */
function isWordChar(ch: string): boolean {
  const code = ch.charCodeAt(0);
  return (code >= 48 && code <= 57) || (code >= 65 && code <= 90) || (code >= 97 && code <= 122);
}

/** 拆行（兼容 \r\n） */
export function splitLines(text: string): string[] {
  const parts = text.split('\n');
  const out: string[] = [];
  for (const part of parts) {
    out.push(part.endsWith('\r') ? part.substring(0, part.length - 1) : part);
  }
  return out;
}

/**
 * 全文扫描匹配词 → 行号化高亮行（纯函数）。
 * - terms 去重（大小写不敏感），逐行 indexOf 定位所有命中区间（跨词命中允许，与官方一致）
 * - 窗口 = 每命中行 ±2 上下文合并，超长截断（maxShownLines），剩余行进 more
 * @param maxShownLines 初始窗口最大行数
 */
export function buildCodeSnippet(content: string, terms: string[], maxShownLines: number): CodeSnippet {
  const clean: string[] = [];
  for (const t of terms) {
    const tt = t.trim();
    if (tt !== '' && clean.findIndex((k: string) => k.toLowerCase() === tt.toLowerCase()) < 0) {
      clean.push(tt);
    }
  }
  const lines = splitLines(content);
  const ranges: CodeHighlight[][] = [];
  const matchNos: number[] = [];
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    const lower = line.toLowerCase();
    const lineRanges: CodeHighlight[] = [];
    for (const term of clean) {
      const lt = term.toLowerCase();
      // token 级匹配：非词字符分隔的完整 token == 关键词（官方 <em> 规则，避免 clients 误命中 cli）
      let start = -1;
      for (let c = 0; c <= lower.length; c++) {
        const isWord = c < lower.length && isWordChar(lower.charAt(c));
        if (isWord && start < 0) {
          start = c;
        } else if (!isWord && start >= 0) {
          if (lower.substring(start, c) === lt &&
              !lineRanges.some((r: CodeHighlight) => start < r.end && c > r.start)) {
            lineRanges.push({ start: start, end: c });
          }
          start = -1;
        }
      }
    }
    ranges.push(lineRanges);
    if (lineRanges.length > 0) {
      matchNos.push(i + 1);
    }
  }
  const totalMatches = ranges.reduce((acc: number, r: CodeHighlight[]) => acc + r.length, 0);
  if (totalMatches === 0) {
    return { window: [], more: [], totalMatches: 0, windowMatches: 0 };
  }
  // 窗口行号：按命中顺序展开 [m-2, m+1]；上下文装不下的命中行进 more
  const windowNos: number[] = [];
  const moreNos: number[] = [];
  const inWindow = (l: number): boolean => windowNos.indexOf(l) >= 0;
  for (const m of matchNos) {
    if (windowNos.length + 3 > maxShownLines) {
      moreNos.push(m);
      continue;
    }
    for (let l = Math.max(1, m - 2); l <= m + 1; l++) {
      if (!inWindow(l)) {
        windowNos.push(l);
      }
    }
  }
  const toLine = (no: number): CodeLine => ({
    no: no,
    text: lines[no - 1],
    highlights: ranges[no - 1]
  });
  const window: CodeLine[] = [];
  let windowMatches = 0;
  for (const l of windowNos) {
    window.push(toLine(l));
    windowMatches += ranges[l - 1].length;
  }
  const more: CodeLine[] = [];
  for (const m of moreNos) {
    for (let l = Math.max(1, m - 1); l <= m + 1; l++) {
      if (!inWindow(l) && more.findIndex((x: CodeLine) => x.no === l) < 0) {
        more.push(toLine(l));
      }
    }
  }
  return { window: window, more: more, totalMatches: totalMatches, windowMatches: windowMatches };
}

/**
 * fragment 兜底预览（内容拉取失败）：按 matches 索引（相对 fragment 偏移）切行高亮。
 * 无行号（no=0），页面渲染时隐藏行号栏。
 */
export function buildFragmentLines(fragment: string, matches: RawMatch[]): CodeLine[] {
  const lines = splitLines(fragment);
  const lineStart: number[] = [];
  let off = 0;
  for (const line of lines) {
    lineStart.push(off);
    off += line.length + 1;
  }
  const out: CodeLine[] = [];
  for (let i = 0; i < lines.length; i++) {
    const start = lineStart[i];
    const ranges: CodeHighlight[] = [];
    for (const m of matches) {
      if (m.indices.length >= 2) {
        const s = m.indices[0];
        const e = m.indices[1];
        if (s >= start && e <= start + lines[i].length) {
          ranges.push({ start: s - start, end: e - start });
        }
      }
    }
    out.push({ no: 0, text: lines[i], highlights: ranges });
  }
  return out;
}

/** REST /search/code 单项 → 原始文件（纯函数） */
export function parseCodeSearchItem(item: JsonMap): RawCodeFile | null {
  const repo = Json.obj(item, 'repository');
  const repoFullName = repo ? Json.str(repo, 'full_name') : '';
  const path = Json.str(item, 'path');
  let name = Json.str(item, 'name');
  if (name === '') {
    const parts = path.split('/');
    name = parts.length > 0 ? parts[parts.length - 1] : '';
  }
  if (repoFullName === '' || name === '') {
    return null;
  }
  let fragment = '';
  const matches: RawMatch[] = [];
  const url = Json.str(item, 'url');
  // text_matches 数组（首个一般就是主窗口；全部保留供计数）
  const tms = Json.arr(item, 'text_matches');
  for (const tmItem of tms) {
    const tm = tmItem as JsonMap;
    if (fragment === '') {
      fragment = Json.str(tm, 'fragment');
    }
    for (const mItem of Json.arr(tm, 'matches')) {
      const m = mItem as JsonMap;
      const text = Json.str(m, 'text');
      const arr = Json.arr(m, 'indices');
      if (arr.length >= 2 && typeof arr[0] === 'number' && typeof arr[1] === 'number') {
        matches.push({ text: text, indices: [arr[0] as number, arr[1] as number] });
      } else {
        matches.push({ text: text, indices: [] });
      }
    }
  }
  return {
    repoFullName: repoFullName,
    path: path,
    name: name,
    contentUrl: url,
    fragment: fragment,
    matches: matches
  };
}

/** REST /search/code 响应 → 原始文件列表（纯函数，按序取 perPage 条） */
export function parseCodeSearch(data: JsonMap): RawCodeFile[] {
  const out: RawCodeFile[] = [];
  for (const item of Json.arr(data, 'items')) {
    const f = parseCodeSearchItem(item as JsonMap);
    if (f !== null) {
      out.push(f);
    }
  }
  return out;
}

/** 内容 API 响应 base64 → 文本 */
async function fetchContentText(contentUrl: string, token: string): Promise<string> {
  const PREFIX = 'https://api.github.com';
  const path = contentUrl.startsWith(PREFIX) ? contentUrl.substring(PREFIX.length) : contentUrl;
  const resp = await restGet(path, token);
  const data = Json.parse(resp.body);
  const content = data !== null ? Json.str(data, 'content') : '';
  if (content === '') {
    return '';
  }
  const helper = new util.Base64Helper();
  const bytes: Uint8Array = helper.decodeSync(content);
  return util.TextDecoder.create('utf-8').decodeToString(bytes);
}

/**
 * 原始文件 → 结果卡：拉内容计算行号窗口；失败降级 fragment 预览。
 * @param avatarMap repoFullName → owner 头像（GraphQL CODE 节点提供；缺失空串）
 */
export async function buildCodeResult(raw: RawCodeFile, avatarUrl: string, token: string): Promise<CodeFileResult> {
  let content = '';
  try {
    if (raw.contentUrl !== '') {
      content = await fetchContentText(raw.contentUrl, token);
    }
  } catch (e) {
    content = '';
  }
  const terms: string[] = [];
  for (const m of raw.matches) {
    if (m.text !== '' && terms.indexOf(m.text) < 0) {
      terms.push(m.text);
    }
  }
  let snippet: CodeSnippet;
  let fallback = false;
  if (content !== '' && terms.length > 0) {
    snippet = buildCodeSnippet(content, terms, 40);
  } else {
    snippet = {
      window: buildFragmentLines(raw.fragment, raw.matches),
      more: [],
      totalMatches: raw.matches.length,
      windowMatches: raw.matches.length
    };
    fallback = true;
  }
  return {
    repoFullName: raw.repoFullName,
    repoAvatarUrl: avatarUrl,
    path: raw.path,
    name: raw.name,
    isMarkdown: raw.name.toLowerCase().endsWith('.md'),
    snippet: snippet,
    rawFallback: fallback
  };
}

/** REST 代码搜索原始页（raws + GitHub total_count） */
export interface RawCodeSearchPage {
  raws: RawCodeFile[];
  totalCount: number;
}

export class CodeSearchService {
  /** 代码搜索 REST（text-match）→ 原始文件列表（不含内容窗口） */
  static async fetchCodeRaw(token: string, keyword: string, page: number = 1, perPage: number = 10): Promise<RawCodeSearchPage> {
    const url = `${CODE_SEARCH_PATH}${encodeURIComponent(keyword)}&per_page=${perPage}&page=${page}`;
    const resp = await restGet(url, token, TEXT_MATCH_ACCEPT);
    const data = Json.parse(resp.body);
    const raws = data !== null ? parseCodeSearch(data) : [];
    return { raws: raws, totalCount: data !== null ? Json.num(data, 'total_count') : 0 };
  }

  /** 原始文件 → 结果卡（内容窗口/高亮；头像由调用方 avatarMap 提供） */
  static async buildCodeResults(raws: RawCodeFile[], avatarMap: Record<string, string>,
    token: string): Promise<CodeFileResult[]> {
    // 分批并行拉取（review G14：此前逐个 await 串行，10 个文件拖慢整页数秒）
    const out: CodeFileResult[] = [];
    const BATCH = 5;
    for (let i = 0; i < raws.length; i += BATCH) {
      const chunk = raws.slice(i, i + BATCH);
      const results = await Promise.all(chunk.map((raw: RawCodeFile): Promise<CodeFileResult> => {
        const avatar = avatarMap[raw.repoFullName] ?? '';
        return buildCodeResult(raw, avatar, token);
      }));
      for (const r of results) {
        out.push(r);
      }
    }
    return out;
  }

  /** 代码搜索（REST text-match；page/perPage 分页；avatarMap 由调用方提供） */
  static async fetchCodeResults(token: string, keyword: string, page: number = 1, perPage: number = 10,
    avatarMap: Record<string, string>): Promise<CodeSearchPage> {
    const rawPage = await CodeSearchService.fetchCodeRaw(token, keyword, page, perPage);
    const out = await CodeSearchService.buildCodeResults(rawPage.raws, avatarMap, token);
    return { files: out, hasMore: page * perPage < rawPage.totalCount };
  }
}
