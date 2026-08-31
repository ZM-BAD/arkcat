/**
 * 展示格式化工具：相对时间、贡献等级、通知类型等纯函数，方便单元测试。
 */

const MINUTE_MS = 60 * 1000;
const HOUR_MS = 60 * MINUTE_MS;
const DAY_MS = 24 * HOUR_MS;

/**
 * ISO 时间转中文相对时间。
 * - 1 分钟内 → 「刚刚」
 * - 1 小时内 → 「N 分钟前」
 * - 24 小时内 → 「N 小时前」
 * - 30 天内 → 「N 天前」
 * - 其余 → 「N 个月前」（粗粒度，MVP 足够）
 */
export function relativeTime(iso: string, nowMs: number): string {
  const ts = Date.parse(iso);
  if (Number.isNaN(ts)) {
    return '';
  }
  const diff = Math.max(0, nowMs - ts);
  if (diff < MINUTE_MS) {
    return '刚刚';
  }
  if (diff < HOUR_MS) {
    return `${Math.floor(diff / MINUTE_MS)} 分钟前`;
  }
  if (diff < DAY_MS) {
    return `${Math.floor(diff / HOUR_MS)} 小时前`;
  }
  const days = Math.floor(diff / DAY_MS);
  if (days <= 30) {
    return `${days} 天前`;
  }
  return `${Math.floor(days / 30)} 个月前`;
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

/** GitHub Notifications subject.type → 中文类型名 */
export function notificationTypeLabel(subjectType: string): string {
  switch (subjectType) {
    case 'Issue':
      return 'Issue';
    case 'PullRequest':
      return 'PR';
    case 'Release':
      return 'Release';
    case 'CheckSuite':
      return 'CI';
    case 'Discussion':
      return 'Discussion';
    case 'SecurityAlert':
      return '安全';
    default:
      return subjectType;
  }
}
