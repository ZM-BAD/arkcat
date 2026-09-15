/**
 * 限流可观测：解析 x-ratelimit-* 系列响应头。
 * 配合 ApiError.retryAfter（429/503 的 Retry-After 头）可做提示与退避决策。
 */
import { getHeader } from './HttpClient';

export interface RateLimitInfo {
  /** 窗口内配额上限 */
  limit: number;
  /** 剩余配额 */
  remaining: number;
  /** 配额重置时间（epoch 秒） */
  reset: number;
  /** 配额资源类别（REST 的 core/search/graphql 等；缺省 ''） */
  resource: string;
}

function parseNum(v: string): number {
  if (!/^[0-9]+$/.test(v)) {
    return -1;
  }
  return Number(v);
}

/** 从响应头解析限流信息；无 x-ratelimit-limit/remaining 头时返回 null */
export function readRateLimit(headers: Record<string, string>): RateLimitInfo | null {
  const limit = parseNum(getHeader(headers, 'x-ratelimit-limit'));
  const remaining = parseNum(getHeader(headers, 'x-ratelimit-remaining'));
  if (limit < 0 || remaining < 0) {
    return null;
  }
  const reset = getHeader(headers, 'x-ratelimit-reset');
  return {
    limit: limit,
    remaining: remaining,
    reset: reset !== '' ? parseNum(reset) : 0,
    resource: getHeader(headers, 'x-ratelimit-resource')
  };
}
