/**
 * 展示格式化工具：相对时间、贡献等级、通知类型等纯函数，方便单元测试。
 *
 * i18n 约定：纯函数仅产出结构化数据（value + unit/key），
 * 文案翻译由 UI 层通过 $r()/resourceManager 完成，见 Spec 012。
 */

const MINUTE_MS = 60 * 1000;
const HOUR_MS = 60 * MINUTE_MS;
const DAY_MS = 24 * HOUR_MS;

/** 相对时间的单位；just_now 表示 1 分钟内 */
export type TimeUnit = 'just_now' | 'minute' | 'hour' | 'day' | 'month' | 'year';

/** 相对时间的结构化结果：value + unit，UI 层负责翻译 */
export interface TimeParts {
  value: number;
  unit: TimeUnit;
}

/**
 * ISO 时间转相对时间结构化数据。
 * - 1 分钟内 → { value: 0, unit: 'just_now' }
 * - 1 小时内 → { value: N, unit: 'minute' }
 * - 24 小时内 → { value: N, unit: 'hour' }
 * - 30 天内 → { value: N, unit: 'day' }
 * - 其余 → { value: N, unit: 'month' }（粗粒度，MVP 足够）
 */
export function timeParts(iso: string, nowMs: number): TimeParts | null {
  const ts = Date.parse(iso);
  if (Number.isNaN(ts)) {
    return null;
  }
  const diff = Math.max(0, nowMs - ts);
  if (diff < MINUTE_MS) {
    return { value: 0, unit: 'just_now' };
  }
  if (diff < HOUR_MS) {
    return { value: Math.floor(diff / MINUTE_MS), unit: 'minute' };
  }
  if (diff < DAY_MS) {
    return { value: Math.floor(diff / HOUR_MS), unit: 'hour' };
  }
  const days = Math.floor(diff / DAY_MS);
  if (days <= 30) {
    return { value: days, unit: 'day' };
  }
  const months = Math.floor(days / 30);
  if (months >= 12) {
    return { value: Math.floor(months / 12), unit: 'year' };
  }
  return { value: months, unit: 'month' };
}

/** 星标数的紧凑格式（Spec 023）：≥1000 显示 xx.xk（整数去 .0），否则原样 */
export function compactCount(n: number): string {
  if (n < 1000) {
    return `${n}`;
  }
  const k = Math.round(n / 100) / 10;
  return `${k}k`;
}

/** 贡献等级（0-4）对应的 GitHub 热力图颜色，API 未返回颜色时兜底 */
export function contributionLevelColor(count: number): string {
  if (count <= 0) {
    return '#EBEDF0';
  }
  if (count <= 2) {
    return '#9BE9A8';
  }
  if (count <= 5) {
    return '#40C463';
  }
  if (count <= 9) {
    return '#30A14E';
  }
  return '#216E39';
}

/**
 * GitHub Notifications subject.type → 本地化 key。
 * 未知类型原样返回，UI 层未命中 key 时直接显示原文。
 */
export function notificationTypeKey(subjectType: string): string {
  switch (subjectType) {
    case 'Issue':
      return 'issue';
    case 'PullRequest':
      return 'pr';
    case 'Release':
      return 'release';
    case 'CheckSuite':
      return 'ci';
    case 'Discussion':
      return 'discussion';
    case 'SecurityAlert':
      return 'security';
    default:
      return subjectType;
  }
}
