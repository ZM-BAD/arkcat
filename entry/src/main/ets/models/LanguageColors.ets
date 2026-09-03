/**
 * GitHub linguist 常用语言颜色表（数据，非 UI 样式）。
 *
 * 来源：GitHub liguist 官方 colors.json（https://github.com/github-linguist/linguist 的
 * linguist/colors.json 子集）。用途：REST 兜底数据无 languageColor 字段时按语言名着色；
 * GraphQL 语言颜色齐全时不使用。
 *
 * 注意：本文件是 check-hardcoded-colors.py 的豁免白名单（数据色板），
 * 页面/组件里禁止直接引用色值，一律走 color.json / PrimerTokens。
 */
export const LANGUAGE_COLORS: Record<string, string> = {
  'Go': '#00ADD8',
  'Rust': '#DEA584',
  'TypeScript': '#3178C6',
  'JavaScript': '#F1E05A',
  'Python': '#3572A5',
  'Java': '#B07219',
  'C': '#555555',
  'C++': '#F34B7D',
  'C#': '#178600',
  'Ruby': '#701516',
  'Shell': '#89E051',
  'Kotlin': '#A97BFF',
  'Swift': '#F05138',
  'Dart': '#00B4AB'
};
