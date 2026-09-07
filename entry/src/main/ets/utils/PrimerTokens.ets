/**
 * GitHub Primer 设计令牌（Design Tokens）——ArkCat 本地化（Spec 039 / DESIGN.md）
 *
 * 来源：primer/primitives（MIT，v2026-09 拉取）+ primer.style 设计文档。
 * 颜色不在此处：统一走 resources base/dark 双套 color.json（支持系统级 dark 切换），
 * 此处仅保存「不随主题变化」的尺寸/字号/圆角/动效/阴影/触摸目标常量。
 * 用法：UI 元素优先使用这些常量与 color.json 的官方色，禁止硬编码随意数值。
 */

/** 间距（4px 网格，官方 base.size 2/4/6/8…） */
export const SPACING_XS = 4;
export const SPACING_SM = 8;
export const SPACING_MD = 12;
export const SPACING_LG = 16;
export const SPACING_XL = 24;
export const SPACING_2XL = 32;
export const SPACING_3XL = 48;

/** 圆角（官方 small/medium/large/full） */
export const RADIUS_SMALL = 3;
export const RADIUS_MEDIUM = 6;
export const RADIUS_LARGE = 12;
export const RADIUS_FULL = 9999;

/** 字号（12/14/16/20/32，官方 text.size xs/sm/md/lg/xl，单位 fp≈px 语义） */
export const FONT_XS = 12;
export const FONT_SM = 14;
export const FONT_MD = 16;
export const FONT_LG = 20;
export const FONT_XL = 32;
/** 正文行高 = 1.5 倍字号（官方 lineHeight 对齐 4px 网格） */
export const LINE_HEIGHT_RATIO = 1.5;

/** 字重（官方 300/400/500/600；标题 600、正文 400、强调 500） */
export const FONT_WEIGHT_LIGHT = 300;
export const FONT_WEIGHT_NORMAL = 400;
export const FONT_WEIGHT_MEDIUM = 500;
export const FONT_WEIGHT_SEMIBOLD = 600;

/** 动效时长（官方 duration scale：0/50/100/150/200/300/400/500/600/700/800ms） */
export const DURATION_FAST = 100;   // 微交互（hover/active/focus）
export const DURATION_NORMAL = 200; // 状态切换、展开/收起
export const DURATION_SLOW = 400;   // 页面级过渡

/** 阴影（官方 boxShadow：resting=静置卡片，floating=浮层） */
export const SHADOW_RESTING = '0 1px 0 rgba(31,35,40,0.04)';
export const SHADOW_FLOATING = '0 8px 24px rgba(140,149,159,0.2)';

/** 可触摸目标最小尺寸：44 × 44（官方无障碍要求） */
export const TOUCH_TARGET_MIN = 44;
