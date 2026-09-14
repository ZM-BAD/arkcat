/**
 * 数据色工具（DESIGN.md §1.1/§1.2）：GitHub API 返回的运行时颜色（仓库标签 hex 等）的官方渲染规则。
 * 公式唯一来源 primer/react IssueLabelToken（链接见 DESIGN.md §1.2）：
 * - 感知光感 PL = (0.2126R + 0.7152G + 0.0722B) / 255（官方原样公式，不做 sRGB gamma 解码）
 * - 文字黑白阈值 0.6（官方移动端亮暗两态实测一致口径；web 亮色为 0.453）
 * - 亮色：原色实底；近白（PL > 0.96）加同色系发丝描边
 * - 暗色：原色 18% 透明底；文字 = 同色相提亮 lightenBy = (0.6 − PL) × 100（仅 PL < 0.6 时）
 * 全部纯函数、可宿主单测；返回 ArkUI 可直接用的颜色字符串（'#RRGGBB' / '#AARRGGBB' / 'rgba(...)'）。
 */

/** 主题模式（LabelPill 经 MediaQuery 实测后传入，避免各调用方自判） */
export type DataColorMode = 'light' | 'dark';

export interface RGB {
  r: number;
  g: number;
  b: number;
}

/** h∈[0,360)，s/l∈[0,100] */
export interface HSL {
  h: number;
  s: number;
  l: number;
}

const PL_THRESHOLD = 0.6;
const LIGHT_BORDER_THRESHOLD = 0.96;
const DARK_BG_ALPHA = 0.18;
const DARK_BORDER_ALPHA = 0.3;

function clamp01(v: number): number {
  return Math.max(0, Math.min(1, v));
}

function clamp100(v: number): number {
  return Math.max(0, Math.min(100, v));
}

/** 解析 'RRGGBB' 或 '#RRGGBB'；非法输入返回 null（调用方回退语义令牌） */
export function parseHexColor(hex: string): RGB | null {
  const raw = hex.startsWith('#') ? hex.substring(1) : hex;
  if (raw.length !== 6) {
    return null;
  }
  const r = parseInt(raw.substring(0, 2), 16);
  const g = parseInt(raw.substring(2, 4), 16);
  const b = parseInt(raw.substring(4, 6), 16);
  if (Number.isNaN(r) || Number.isNaN(g) || Number.isNaN(b)) {
    return null;
  }
  return { r: r, g: g, b: b };
}

/** 统一输出 '#RRGGBB'（大写、去 #），供拼 alpha 与比对 */
export function normalizeHex(hex: string): string {
  return (hex.startsWith('#') ? hex.substring(1) : hex).toUpperCase();
}

/** 感知光感（官方原样公式，无 gamma 解码） */
export function perceivedLightness(c: RGB): number {
  return ((c.r * 0.2126) + (c.g * 0.7152) + (c.b * 0.0722)) / 255;
}

/** RGB → HSL（h∈[0,360)，s/l∈[0,100]） */
export function rgbToHsl(c: RGB): HSL {
  const rn = c.r / 255;
  const gn = c.g / 255;
  const bn = c.b / 255;
  const max = Math.max(rn, gn, bn);
  const min = Math.min(rn, gn, bn);
  const l = (max + min) / 2;
  let h = 0;
  let s = 0;
  if (max !== min) {
    const d = max - min;
    s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
    if (max === rn) {
      h = ((gn - bn) / d + (gn < bn ? 6 : 0)) * 60;
    } else if (max === gn) {
      h = ((bn - rn) / d + 2) * 60;
    } else {
      h = ((rn - gn) / d + 4) * 60;
    }
  }
  return { h: h, s: s * 100, l: l * 100 };
}

function toHex2(v: number): string {
  const clamped = Math.max(0, Math.min(255, Math.round(v)));
  const s = clamped.toString(16).toUpperCase();
  return s.length === 1 ? `0${s}` : s;
}

/** HSL → '#RRGGBB' */
export function hslToHex(c: HSL): string {
  const hn = ((c.h % 360) + 360) % 360 / 360;
  const sn = clamp100(c.s) / 100;
  const ln = clamp100(c.l) / 100;
  const q = ln < 0.5 ? ln * (1 + sn) : ln + sn - ln * sn;
  const p = 2 * ln - q;
  const channel = (t: number): number => {
    let tt = t;
    if (tt < 0) {
      tt += 1;
    }
    if (tt > 1) {
      tt -= 1;
    }
    if (tt < 1 / 6) {
      return p + (q - p) * 6 * tt;
    }
    if (tt < 1 / 2) {
      return q;
    }
    if (tt < 2 / 3) {
      return p + (q - p) * (2 / 3 - tt) * 6;
    }
    return p;
  };
  const r = Math.round(channel(hn + 1 / 3) * 255);
  const g = Math.round(channel(hn) * 255);
  const b = Math.round(channel(hn - 1 / 3) * 255);
  return `#${toHex2(r)}${toHex2(g)}${toHex2(b)}`;
}

/** '#RRGGBB' + alpha → '#AARRGGBB'（HarmonyOS 颜色 alpha 在前） */
function hexWithAlpha(hex: string, alpha: number): string {
  const a = Math.round(clamp01(alpha) * 255);
  const prefix = a.toString(16).toUpperCase();
  return `#${prefix.length === 1 ? `0${prefix}` : prefix}${normalizeHex(hex)}`;
}

/** 暗色模式的提亮文字色：同色相，亮度按官方 lightenBy 公式抬到阈值（仅 PL < 0.6 时提亮） */
function darkTextColor(c: RGB): string {
  const pl = perceivedLightness(c);
  const hsl = rgbToHsl(c);
  if (pl < PL_THRESHOLD) {
    hsl.l = clamp100(hsl.l + (PL_THRESHOLD - pl) * 100);
  }
  return hslToHex(hsl);
}

/**
 * 标签文字色：亮=黑白（0.6 阈值）；暗=同色相提亮色。
 * 非法输入回退纯黑/纯白（调用方正常不会命中——GitHub 标签色恒为 6 位 hex）。
 */
export function labelTextColor(hex: string, mode: DataColorMode): string {
  const c = parseHexColor(hex);
  if (c === null) {
    return mode === 'dark' ? '#FFFFFF' : '#000000';
  }
  if (mode === 'dark') {
    return darkTextColor(c);
  }
  return perceivedLightness(c) < PL_THRESHOLD ? '#FFFFFF' : '#000000';
}

/** 标签背景色：亮=原色实底；暗=原色 18% 透明；非法输入返回 transparent */
export function labelBackground(hex: string, mode: DataColorMode): string {
  const c = parseHexColor(hex);
  if (c === null) {
    return 'transparent';
  }
  if (mode === 'dark') {
    return `rgba(${c.r},${c.g},${c.b},${DARK_BG_ALPHA})`;
  }
  return `#${normalizeHex(hex)}`;
}

/**
 * 标签描边色（官方仅两种情形出现描边，其余返回 '' 由组件转透明，保持 1px 透明描边占位不跳版）：
 * 亮=仅近白标签（PL > 0.96）：同色相、亮度 −25、alpha = PL − 0.96；
 * 暗=提亮文字色 30% 透明（描边比底色更显，官方 darkThemeIssueLabel 口径）。
 */
export function labelBorder(hex: string, mode: DataColorMode): string {
  const c = parseHexColor(hex);
  if (c === null) {
    return '';
  }
  const pl = perceivedLightness(c);
  if (mode === 'light') {
    if (pl <= LIGHT_BORDER_THRESHOLD) {
      return '';
    }
    const hsl = rgbToHsl(c);
    hsl.l = Math.max(0, hsl.l - 25);
    return hexWithAlpha(hslToHex(hsl), clamp01(pl - LIGHT_BORDER_THRESHOLD));
  }
  return hexWithAlpha(darkTextColor(c), DARK_BORDER_ALPHA);
}
