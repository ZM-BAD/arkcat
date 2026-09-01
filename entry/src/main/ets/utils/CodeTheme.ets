/**
 * 代码查看主题（Spec 011 / 033 共用）：GitHub 官方明/暗两套配色 + 行片段模型。
 * Code Options 固定示例与代码查看器同源取色，避免双处漂移。
 */
export const CODE_LIGHT_BG = '#F6F8FA';
export const CODE_LIGHT_TEXT = '#1F2328';
export const CODE_LIGHT_KEYWORD = '#CF222E';
export const CODE_LIGHT_FUNC = '#0550AE';
export const CODE_LIGHT_COMMENT = '#6E7781';
export const CODE_DARK_BG = '#0D1117';
export const CODE_DARK_TEXT = '#E6EDF3';
export const CODE_DARK_KEYWORD = '#FF7B72';
export const CODE_DARK_FUNC = '#D2A8FF';
export const CODE_DARK_COMMENT = '#8B949E';

/** 代码行片段（语法着色单元） */
export class CodeSpan {
  text: string;
  color: string;

  constructor(text: string, color: string) {
    this.text = text;
    this.color = color;
  }
}

/** 代码行（着色后的一组片段） */
export class CodeLine {
  spans: CodeSpan[];

  constructor(spans: CodeSpan[]) {
    this.spans = spans;
  }
}

/** 语法着色工具：Code Options 示例与代码查看器共用 */
export function keywordColorOf(dark: boolean): string {
  return dark ? CODE_DARK_KEYWORD : CODE_LIGHT_KEYWORD;
}

export function funcColorOf(dark: boolean): string {
  return dark ? CODE_DARK_FUNC : CODE_LIGHT_FUNC;
}

export function commentColorOf(dark: boolean): string {
  return dark ? CODE_DARK_COMMENT : CODE_LIGHT_COMMENT;
}

export function codeTextColorOf(dark: boolean): string {
  return dark ? CODE_DARK_TEXT : CODE_LIGHT_TEXT;
}
