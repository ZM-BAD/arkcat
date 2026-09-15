/**
 * Relay cursor 分页原语。
 *
 * Page<T> 为统一翻页抽象；readConnectionPage 从标准 connection 节点
 * （pageInfo{hasNextPage endCursor} + nodes[] 或 edges[]{node}）提取一页；
 * fetchAllPages 驱动续拉循环（hasNextPage 判停——实测末页 endCursor 仍非空，
 * 用游标判停会多打一次空页——并以上限防极端长列表拖死加载）。
 */
import { Json, JsonMap } from './Json';

/** 默认续拉上限（防极端长列表拖死加载） */
export const DEFAULT_MAX_PAGES = 10;

export interface Page<T> {
  items: T[];
  hasNextPage: boolean;
  endCursor: string;
}

function emptyPage<T>(): Page<T> {
  return { items: [], hasNextPage: false, endCursor: '' };
}

/**
 * 从标准 connection 节点提取一页。
 * viaEdges=false 读 nodes[]；true 读 edges[]{node}。
 * conn 为 null（节点缺失）时返回空页不抛错。
 */
export function readConnectionPage<T>(conn: JsonMap | null, mapItem: (node: JsonMap) => T,
  viaEdges: boolean = false): Page<T> {
  if (conn === null) {
    return emptyPage<T>();
  }
  const items: T[] = [];
  const raw = viaEdges ? Json.arr(conn, 'edges') : Json.arr(conn, 'nodes');
  for (const entry of raw) {
    if (typeof entry !== 'object' || entry === null) {
      continue;
    }
    const node = viaEdges ? Json.obj(entry as JsonMap, 'node') : entry as JsonMap;
    if (node !== null) {
      items.push(mapItem(node));
    }
  }
  const pageInfo = Json.obj(conn, 'pageInfo');
  return {
    items: items,
    hasNextPage: pageInfo !== null ? Json.bool(pageInfo, 'hasNextPage') : false,
    endCursor: pageInfo !== null ? Json.str(pageInfo, 'endCursor') : ''
  };
}

/**
 * 续拉循环：fetchPage(cursor) 首次以 null 调用（调用方可自行落到首页游标/首页请求），
 * 之后按 endCursor 链式续拉，hasNextPage 为 false 或拉满 maxPages 停止。
 * 单页失败想降级截断的，在 fetchPage 内 catch 后返回 hasNextPage=false 的空页即可。
 */
export async function fetchAllPages<T>(fetchPage: (cursor: string | null) => Promise<Page<T>>,
  maxPages: number = DEFAULT_MAX_PAGES): Promise<T[]> {
  const all: T[] = [];
  let cursor: string | null = null;
  for (let guard = 0; guard < maxPages; guard++) {
    const page: Page<T> = await fetchPage(cursor);
    const items: T[] = page.items;
    for (const item of items) {
      all.push(item);
    }
    if (!page.hasNextPage) {
      break;
    }
    cursor = page.endCursor;
  }
  return all;
}
