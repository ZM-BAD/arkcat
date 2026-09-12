/**
 * 展示格式化工具：相对时间、贡献等级、通知类型等纯函数，方便单元测试。
 *
 * i18n 约定：纯函数仅产出结构化数据（value + unit/key），
 * 文案翻译由 UI 层通过 $r()/resourceManager 完成，见 Spec 012。
 */
import { intl, i18n } from '@kit.LocalizationKit';

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

/** GitHub 通知相对时间（官方风格）：now / 5m / 22h / 1d / 8d / 3mo / 2y */
export function githubShortTime(parts: TimeParts): string {
  switch (parts.unit) {
    case 'just_now':
      return 'now';
    case 'minute':
      return `${parts.value}m`;
    case 'hour':
      return `${parts.value}h`;
    case 'day':
      return `${parts.value}d`;
    case 'month':
      return `${parts.value}mo`;
    case 'year':
      return `${parts.value}y`;
  }
  return '';
}

/**
 * ISO 解锁时间 → 本地「月 日」文本；跨年（非当前年份）带年份（February 2, 2020 / 2020年2月2日），
 * 非法 ISO 返回 ''。Spec 052 成就解锁行。
 * 用应用首选语言（Settings 语言三态覆盖后的生效语言）而非系统 locale：
 * 否则中文 App + 英文系统会出现「Unlocked 9月11日」式混排。
 */
export function unlockDateText(iso: string): string {
  const ts = Date.parse(iso);
  if (Number.isNaN(ts)) {
    return '';
  }
  try {
    const date = new Date(ts);
    const withYear = date.getFullYear() !== new Date().getFullYear();
    const locale = i18n.System.getAppPreferredLanguage();
    const options: intl.DateTimeOptions = withYear ?
      { year: 'numeric', month: 'long', day: 'numeric' } :
      { month: 'long', day: 'numeric' };
    const fmt = new intl.DateTimeFormat(locale, options);
    return fmt.format(date);
  } catch (e) {
    return '';
  }
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
