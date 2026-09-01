/**
 * 简易语法高亮（Spec 011）：行内注释/字符串/关键字/函数调用着色。
 * 无原生代码着色，MVP 按扩展名选取关键字集；块注释跨行状态由调用方维持。
 */
import { CodeLine, CodeSpan, codeTextColorOf, commentColorOf, funcColorOf, keywordColorOf } from './CodeTheme';

/** 单行高亮结果（行片段 + 块注释延续状态） */
export interface HighlightResult {
  line: CodeLine;
  inBlockComment: boolean;
}

const JS_KEYWORDS: string[] = [
  'const', 'let', 'var', 'function', 'return', 'if', 'else', 'for', 'while', 'do', 'switch', 'case',
  'default', 'break', 'continue', 'new', 'class', 'extends', 'implements', 'interface', 'type',
  'import', 'export', 'from', 'require', 'async', 'await', 'try', 'catch', 'finally', 'throw',
  'this', 'super', 'null', 'undefined', 'true', 'false', 'typeof', 'instanceof', 'yield', 'static', 'private'
];

const PY_KEYWORDS: string[] = [
  'def', 'return', 'if', 'elif', 'else', 'for', 'while', 'import', 'from', 'as', 'class', 'try',
  'except', 'finally', 'with', 'lambda', 'yield', 'pass', 'break', 'continue', 'not', 'and', 'or',
  'in', 'is', 'None', 'True', 'False', 'assert', 'global', 'async', 'await'
];

const JAVA_KEYWORDS: string[] = [
  'public', 'private', 'protected', 'static', 'final', 'void', 'int', 'long', 'float', 'double',
  'boolean', 'char', 'String', 'new', 'class', 'interface', 'extends', 'implements', 'try', 'catch',
  'finally', 'throw', 'return', 'if', 'else', 'for', 'while', 'do', 'switch', 'case', 'break',
  'continue', 'null', 'true', 'false', 'this', 'var', 'val', 'fun', 'object', 'when', 'internal'
];

const OTHER_KEYWORDS: string[] = [
  'package', 'import', 'export', 'func', 'var', 'const', 'type', 'struct', 'interface', 'map',
  'chan', 'go', 'defer', 'select', 'fn', 'let', 'mut', 'pub', 'use', 'mod', 'enum', 'impl',
  'trait', 'match', 'loop', 'unsafe', 'return', 'if', 'else', 'for', 'while', 'do', 'switch',
  'case', 'default', 'break', 'continue', 'nil', 'null', 'true', 'false', 'self', 'class',
  'namespace', 'using', 'template', 'virtual', 'constexpr', '#include', '#define', 'def', 'end',
  'unless', 'until', 'begin', 'rescue', 'ensure', 'done', 'local', 'echo', 'exit', 'as', 'in',
  'is', 'not', 'and', 'or', 'with', 'from', 'raise', 'super'
];

/** 按扩展名返回关键字集合 */
function keywordsOf(ext: string): string[] {
  if (ext === 'js' || ext === 'ts' || ext === 'mjs' || ext === 'cjs' || ext === 'jsx' || ext === 'tsx' || ext === 'ets') {
    return JS_KEYWORDS;
  }
  if (ext === 'py') {
    return PY_KEYWORDS;
  }
  if (ext === 'java' || ext === 'cs' || ext === 'kt' || ext === 'kts') {
    return JAVA_KEYWORDS;
  }
  return OTHER_KEYWORDS;
}

/** 文件名 → 扩展名（小写、无点） */
export function extOf(path: string): string {
  const idx = path.lastIndexOf('.');
  if (idx < 0 || idx === path.length - 1) {
    return '';
  }
  let ext = path.substring(idx + 1);
  let lower = '';
  for (const ch of ext) {
    lower += ch >= 'A' && ch <= 'Z' ? ch.toLowerCase() : ch;
  }
  return lower;
}

function isIdentStart(ch: string): boolean {
  return (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z') || ch === '_' || ch === '$';
}

function isIdentChar(ch: string): boolean {
  return isIdentStart(ch) || (ch >= '0' && ch <= '9');
}

/**
 * 高亮一行。inBlockComment: 是否处于 /* 块注释内（输入态），返回下一行所需状态。
 * 规则优先级：块注释 > 行注释 > 字符串 > 关键字 > 函数调用（标识符后跟 "("）。
 */
export function highlightLine(raw: string, ext: string, dark: boolean, inBlockComment: boolean): HighlightResult {
  const textColor: string = codeTextColorOf(dark);
  const kwColor: string = keywordColorOf(dark);
  const fnColor: string = funcColorOf(dark);
  const cmColor: string = commentColorOf(dark);
  const keywords: string[] = keywordsOf(ext);
  const spans: CodeSpan[] = [];
  let inBlock: boolean = inBlockComment;
  let plain: string = '';
  const flushPlain = (): void => {
    if (plain !== '') {
      spans.push(new CodeSpan(plain, textColor));
      plain = '';
    }
  };
  let i: number = 0;
  while (i < raw.length) {
    const ch: string = raw.charAt(i);
    if (inBlock) {
      // 块注释内：找闭合
      if (ch === '*' && raw.charAt(i + 1) === '/') {
        plain += '*/';
        i += 2;
        inBlock = false;
        continue;
      }
      plain += ch;
      i++;
      continue;
    }
    if (ch === '/' && raw.charAt(i + 1) === '/') {
      flushPlain();
      spans.push(new CodeSpan(raw.substring(i), cmColor));
      i = raw.length;
      continue;
    }
    if (ch === '/' && raw.charAt(i + 1) === '*') {
      flushPlain();
      const close = raw.indexOf('*/', i + 2);
      if (close >= 0) {
        spans.push(new CodeSpan(raw.substring(i, close + 2), cmColor));
        i = close + 2;
      } else {
        spans.push(new CodeSpan(raw.substring(i), cmColor));
        inBlock = true;
        i = raw.length;
      }
      continue;
    }
    if (ch === '\'' || ch === '"' || ch === '`') {
      flushPlain();
      let j: number = i + 1;
      while (j < raw.length) {
        if ((raw.charAt(j) === '\\') && j + 1 < raw.length) {
          j += 2;
          continue;
        }
        if (raw.charAt(j) === ch) {
          j++;
          break;
        }
        j++;
      }
      spans.push(new CodeSpan(raw.substring(i, Math.min(j, raw.length)), textColor));
      i = j;
      continue;
    }
    if (isIdentStart(ch)) {
      let j: number = i;
      while (j < raw.length && isIdentChar(raw.charAt(j))) {
        j++;
      }
      const word: string = raw.substring(i, j);
      let k: number = j;
      while (k < raw.length && raw.charAt(k) === ' ') {
        k++;
      }
      if (keywords.indexOf(word) >= 0) {
        flushPlain();
        spans.push(new CodeSpan(word, kwColor));
      } else if (k < raw.length && raw.charAt(k) === '(') {
        flushPlain();
        spans.push(new CodeSpan(word, fnColor));
      } else {
        plain += word;
      }
      i = j;
      continue;
    }
    plain += ch;
    i++;
  }
  flushPlain();
  return { line: new CodeLine(spans), inBlockComment: inBlock };
}
