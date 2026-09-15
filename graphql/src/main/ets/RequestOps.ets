/**
 * 请求编排原语：竞态守卫、软失败降级、有界并发池。
 * 均为纯逻辑（无 UI/系统能力依赖），可宿主单测。
 */

/** 页面级请求竞态守卫：旧请求的回调按序号丢弃 */
export class RequestSequencer {
  private seq: number = 0;

  /** 开启一次新请求，返回本次序号（闭包捕获） */
  begin(): number {
    this.seq += 1;
    return this.seq;
  }

  /** 回调返回时判断是否仍是最新一次请求 */
  isCurrent(seq: number): boolean {
    return seq === this.seq;
  }
}

/** 装饰性请求软失败：task 失败时返回 fallback，不击穿主流程 */
export async function withFallback<T>(task: Promise<T>, fallback: T): Promise<T> {
  try {
    return await task;
  } catch (e) {
    return fallback;
  }
}

/**
 * 有界并发池：按 batch 分批串行、批内 Promise.all 并行，
 * 避免全量 Promise.all 一次性打满网络栈（批量补全头像/计数等场景）。
 */
export async function runBounded<T, R>(items: T[], batchSize: number,
  task: (item: T) => Promise<R>): Promise<R[]> {
  const results: R[] = [];
  for (let start = 0; start < items.length; start += batchSize) {
    const slice = items.slice(start, start + batchSize);
    const part = await Promise.all(slice.map((item: T) => task(item)));
    for (const r of part) {
      results.push(r);
    }
  }
  return results;
}
