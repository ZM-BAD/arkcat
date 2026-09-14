/**
 * 客户端筛选页的「空态自动补拉」判定（全库共用，2026-09-13 定案）。
 *
 * 背景：Repositories 的 Type/Language、Inbox 的 reason、仓库内 PRs 的 author/assignee、
 * Projects 的 Status 等仍是**客户端过滤**（GitHub 无对应服务端参数，详见各 Spec 边界表）。
 * 这类页第一页可能全被过滤掉，出现「假空」——服务端其实还有数据。
 * 处理：过滤后结果为空且还有下一页时自动继续补拉，最多补 AUTO_LOAD_MAX_EXTRA_PAGES 页；
 * 到上限仍空才显示空态（附「已加载范围内无结果」提示）。
 */

/** 自动补拉上限（页数）：最多额外拉 5 页（每页 25/30/100 条由调用方决定） */
export const AUTO_LOAD_MAX_EXTRA_PAGES = 5;

/**
 * 「空值」筛选哨兵（No milestone / Assigned to nobody，2026-09-14 官方口径）。
 * 值用双下划线：GitHub 登录名不允许下划线，不会与真实候选值冲突。
 */
export const NONE_FILTER_KEY = '__none__';

/**
 * 是否应继续自动补拉。
 * @param visibleCount 当前过滤后可见条数
 * @param hasNextPage 服务端是否还有下一页
 * @param extraPagesLoaded 已额外补拉的页数（不含首拉）
 */
export function shouldAutoLoadMore(visibleCount: number, hasNextPage: boolean,
  extraPagesLoaded: number): boolean {
  if (visibleCount > 0 || !hasNextPage) {
    return false;
  }
  return extraPagesLoaded < AUTO_LOAD_MAX_EXTRA_PAGES;
}

/**
 * 空态是否属于「已加载范围内无结果」（补拉结束仍空但服务端还有数据 → 文案要说明是范围受限，而非真的没有）。
 * @param visibleCount 过滤后可见条数
 * @param hasNextPage 服务端是否还有下一页（补拉结束时仍为 true = 到上限停下，覆盖不全）
 */
export function isLimitedRangeEmpty(visibleCount: number, hasNextPage: boolean): boolean {
  return visibleCount === 0 && hasNextPage;
}
