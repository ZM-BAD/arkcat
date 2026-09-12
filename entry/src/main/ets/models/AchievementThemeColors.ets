/**
 * GitHub 成就徽章全量本地主题色板（Spec 052）。
 *
 * 来源：官方 detail 横幅资产逐像素采样（非截图）。官方横幅镜像自
 * Schweinepriester/github-profile-achievements 仓库 images/backgrounds/（即
 * github.githubassets.com/assets/<slug>-detail-<hash>.png 的原样镜像），2026-09-13 解码。
 * 每枚取拉伸铺满后的顶部/底部中心色（Starstruck/Open Sourcerer 为多向渐变，此处按垂直两色近似）。
 *
 * 用途：详情页官方横幅图不可用（URL 解析失败/降级条目）时的背景兜底渐变；
 * 正常路径仍以官方横幅原图铺满为准，色表仅保证任意徽章（含收集大户的稀有徽章）有正确的主题色。
 */

/** 单枚徽章的本地主题色（官方横幅顶/底中心采样值） */
export interface AchievementTheme {
  top: string;
  bottom: string;
}

const SLUGS: string[] = [
  'pull-shark',
  'yolo',
  'quickdraw',
  'pair-extraordinaire',
  'galaxy-brain',
  'starstruck',
  'public-sponsor',
  'arctic-code-vault-contributor',
  'heart-on-your-sleeve',
  'mars-2020-contributor',
  'open-sourcerer',
  'proxima-pioneer',
  'proxima-staffshipper',
  'proxima-staffuser'
];

const TOPS: string[] = [
  '#0A6ADD',
  '#FEBC9C',
  '#FCF3C8',
  '#ADEEBA',
  '#6539B9',
  '#FDBE7F',
  '#AFCDED',
  '#020245',
  '#E95DAE',
  '#230C52',
  '#DABAFF',
  '#5D749A',
  '#024F4E',
  '#D48A86'
];

const BOTTOMS: string[] = [
  '#2B34A6',
  '#FEBC9C',
  '#FC9046',
  '#CDED79',
  '#2F1462',
  '#BABBF3',
  '#DEAAA5',
  '#0074B4',
  '#FFD5CC',
  '#BB2E18',
  '#FF83CA',
  '#081D51',
  '#0F092A',
  '#323066'
];

/** slug → 本地主题色；未收录返回 null（调用方走通用兜底渐变） */
export function achievementTheme(slug: string): AchievementTheme | null {
  const i = SLUGS.indexOf(slug);
  if (i === -1) {
    return null;
  }
  const top = TOPS[i];
  const bottom = BOTTOMS[i];
  const theme: AchievementTheme = { top: top, bottom: bottom };
  return theme;
}
