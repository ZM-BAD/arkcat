/**
 * MarkdownView 的 HTML 文档组装（Spec 040）：markdown-body 子集样式 + 复制/主题/测量 JS。
 * 颜色全部经 MarkdownPalette 注入 CSS 变量（body.md-light / body.md-dark 切 class 即换肤）。
 * 纯函数模块：组件瘦身（单文件 ≤300 行）并可单测。
 */
import { MarkdownColors, MD_DARK, MD_LIGHT } from './MarkdownPalette';

const FONT_STACK = '-apple-system, BlinkMacSystemFont, "Segoe UI", "Noto Sans", Helvetica, Arial, sans-serif';
const MONO_STACK = 'ui-monospace, SFMono-Regular, "SF Mono", Menlo, Consolas, monospace';

/** 明/暗两套 CSS 变量 + markdown-body 子集样式 */
function buildStyle(light: MarkdownColors, dark: MarkdownColors): string {
  return `:root, body.md-light {
  --md-bg: ${light.bg}; --md-fg: ${light.fg}; --md-muted: ${light.muted};
  --md-border: ${light.border}; --md-accent: ${light.accent}; --md-success: ${light.success};
  --md-danger: ${light.danger}; --md-code-bg: ${light.codeBg}; --md-pre-bg: ${light.preBg};
  --md-hl-bg: ${light.hlBg};
}
body.md-dark {
  --md-bg: ${dark.bg}; --md-fg: ${dark.fg}; --md-muted: ${dark.muted};
  --md-border: ${dark.border}; --md-accent: ${dark.accent}; --md-success: ${dark.success};
  --md-danger: ${dark.danger}; --md-code-bg: ${dark.codeBg}; --md-pre-bg: ${dark.preBg};
  --md-hl-bg: ${dark.hlBg};
}
html, body { height: auto; }
body { margin: 0; padding: 0; background: var(--md-bg); color: var(--md-fg);
  font-size: 16px; line-height: 1.5; font-family: ${FONT_STACK}; word-wrap: break-word;
  -webkit-tap-highlight-color: transparent; }
.markdown-body { max-width: 100%; }
.markdown-body > *:first-child { margin-top: 0 !important; }
.markdown-body > *:last-child { margin-bottom: 0 !important; }
.markdown-body p { margin: 0 0 16px; }
.markdown-body h1, .markdown-body h2, .markdown-body h3, .markdown-body h4, .markdown-body h5, .markdown-body h6 {
  font-weight: 600; margin: 24px 0 16px; line-height: 1.25; }
.markdown-body h1 { font-size: 2em; margin-top: 8px; padding-bottom: 4px; border-bottom: 1px solid var(--md-border); }
.markdown-body h2 { font-size: 1.5em; padding-bottom: 4px; border-bottom: 1px solid var(--md-border); }
.markdown-body h3 { font-size: 1.25em; }
.markdown-body h4 { font-size: 1em; }
.markdown-body h5 { font-size: 0.875em; }
.markdown-body h6 { font-size: 0.85em; color: var(--md-muted); }
.markdown-body a { color: var(--md-accent); text-decoration: none; }
.markdown-body strong { font-weight: 600; }
.markdown-body ul, .markdown-body ol { padding-left: 24px; margin: 0 0 16px; }
.markdown-body li + li { margin-top: 4px; }
.markdown-body li.task-list-item { list-style: none; margin-left: -16px; }
.markdown-body input[type="checkbox"] { margin-right: 4px; }
.markdown-body blockquote { margin: 0 0 16px; padding: 0 16px; border-left: 3px solid var(--md-border);
  color: var(--md-muted); }
.markdown-body pre { background: var(--md-pre-bg); border-radius: 6px; padding: 12px 16px; overflow-x: auto;
  position: relative; line-height: 1.45; margin: 0 0 16px; }
.markdown-body code { font-family: ${MONO_STACK}; font-size: 85%; }
.markdown-body p code, .markdown-body li code, .markdown-body td code, .markdown-body blockquote code {
  background: var(--md-code-bg); padding: 0.2em 0.4em; border-radius: 6px; }
.markdown-body pre code { background: transparent; padding: 0; }
.markdown-body table { border-collapse: collapse; margin: 0 0 16px; display: block; overflow-x: auto;
  max-width: 100%; }
.markdown-body th, .markdown-body td { border: 1px solid var(--md-border); padding: 6px 13px; }
.markdown-body img { max-width: 100%; }
.markdown-body hr { margin: 24px 0; border: 0; border-top: 1px solid var(--md-border); }
.markdown-body mark { background: var(--md-hl-bg); color: var(--md-fg); border-radius: 4px; padding: 0 2px; }
.markdown-body svg { max-width: 100%; }
.md-copy { position: absolute; top: 8px; right: 8px; font-size: 12px; line-height: 1; padding: 6px 10px;
  background: var(--md-bg); border: 1px solid var(--md-border); border-radius: 6px; color: var(--md-fg);
  font-family: ${FONT_STACK}; appearance: none; }
`;
}

/** 完整文档：body class 控制主题（后续主题切换走 runJavaScript 换 class，不重载） */
export function buildMarkdownDoc(html: string, dark: boolean): string {
  return '<!DOCTYPE html><html><head><meta charset="utf-8">'
    + '<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">'
    + '<style>' + buildStyle(MD_LIGHT, MD_DARK) + '</style></head>'
    + '<body class="' + (dark ? 'md-dark' : 'md-light') + '">'
    + '<div class="markdown-body">' + html + '</div>'
    + '</body></html>';
}

/** 代码块复制按钮注入（onPageEnd 执行一次；__mdReady 防重复注入） */
export function buildCopyJs(label: string): string {
  return '(function(){ if (window.__mdReady) return; window.__mdReady = true;'
    + ' var label = "' + label + '";'
    + ' document.querySelectorAll("pre").forEach(function(pre){'
    + '   if (pre.querySelector(".md-copy")) return;'
    + '   var btn = document.createElement("button"); btn.className = "md-copy"; btn.textContent = label;'
    + '   var target = pre.querySelector("code");'
    + '   btn.onclick = function(){'
    + '     if (window.starraftBridge && window.starraftBridge.copyCode) {'
    + '       window.starraftBridge.copyCode(target ? target.innerText : pre.innerText);'
    + '     }'
    + '   };'
    + '   pre.appendChild(btn);'
    + ' });'
    + '})();';
}

/** 主题切换（不重载页面，直接换 body class 即可命中 CSS 变量） */
export function buildSetThemeJs(dark: boolean): string {
  return 'document.body.className = "' + (dark ? 'md-dark' : 'md-light') + '";';
}

/** 折叠态禁 Web 内部滚动（防嵌套滚动把「展开全部」卷走）；展开后恢复 */
export function buildSetOverflowJs(collapsed: boolean): string {
  return 'document.body.style.overflow = "' + (collapsed ? 'hidden' : 'visible') + '";';
}

/** 测量正文高度（px；回传给 ArkTS 后折算 vp 设置组件高） */
export function buildMeasureJs(): string {
  return 'document.body.scrollHeight';
}

/**
 * 官方 HTML 的相对路径未重写：img src → raw 前缀、a[href] → blob 前缀（GitHub 网页同款行为）。
 * 绝对链接/锚点/邮件/协议相对不动；__mdFix 防重复注入。
 */
export function buildFixRelativeJs(imgBase: string, linkBase: string): string {
  return '(function(){ if (window.__mdFix) return; window.__mdFix = true;'
    + ' var ib = "' + imgBase + '", lb = "' + linkBase + '";'
    + ' var abs = /^(https?:|data:|mailto:|#|\\/\\/)/;'
    + ' document.querySelectorAll("img").forEach(function(img){'
    + '   var s = img.getAttribute("src") || "";'
    + '   if (s !== "" && !abs.test(s)) img.setAttribute("src", ib + s);'
    + ' });'
    + ' document.querySelectorAll("a[href]").forEach(function(a){'
    + '   var h = a.getAttribute("href") || "";'
    + '   if (h !== "" && !abs.test(h)) a.setAttribute("href", lb + h);'
    + ' });'
    + '})();';
}
