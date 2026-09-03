/**
 * GitHub Markdown 官方明/暗配色数据色板（Spec 040）。
 * 仅此处集中定义色值（门禁豁免白名单，同 CodeTheme/LanguageColors 先例）；
 * 其余 UI 文件一律引用本文件常量，禁止直接写色值。
 * 色值来源：github-markdown-css + Primer primitives（与 DESIGN.md 同源）。
 */
export interface MarkdownColors {
  bg: string;
  fg: string;
  muted: string;
  border: string;
  accent: string;
  success: string;
  danger: string;
  codeBg: string;
  preBg: string;
  hlBg: string;
}

/** 浅色（github-markdown.css 默认主题） */
export const MD_LIGHT: MarkdownColors = {
  bg: '#ffffff',
  fg: '#1f2328',
  muted: '#59636e',
  border: '#d1d9e0',
  accent: '#0969da',
  success: '#1a7f37',
  danger: '#cf222e',
  codeBg: '#eff1f3',
  preBg: '#f6f8fa',
  hlBg: '#fff8c5'
};

/** 深色（github-dark.css） */
export const MD_DARK: MarkdownColors = {
  bg: '#0d1117',
  fg: '#f0f6fc',
  muted: '#9198a1',
  border: '#3d444d',
  accent: '#4493f8',
  success: '#3fb950',
  danger: '#f85149',
  codeBg: '#2d333b',
  preBg: '#161b22',
  hlBg: '#2b2a21'
};
