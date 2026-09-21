/**
 * Home Shortcuts 快捷方式（Spec 074）：纯函数 + 全局可观察单例 + Preferences 持久化。
 * 快捷方式 = 已保存的 Issue/PR 搜索（名称 + kind + 查询串 + 图标/颜色键）。
 * 公开 GitHub API 无 shortcuts 读/写能力（官方为服务端同步）→ 端侧存储；
 * 数据按当前账号 login 分区（切账号互不可见），数组顺序即展示顺序。
 * 注意：本模块被宿主单测（node:test）直接导入，顶层禁用 $r 等运行时资源调用。
 */
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { Json, JsonMap } from './Json';
import { workScopeQualifier, workVisibilityQualifier, workIssuesSortQualifier } from '../models/WorkModels';

/** 快捷方式项（kind+query 唯一；iconKey/colorKey 为创建页色板/图标网格的键） */
export interface ShortcutItem {
  id: string;
  name: string;
  /** 行首次行文案：Saved 行第二行 = name，第一行 = head（建议收藏时原样保留建议行首行；
   *  手动创建时为类型标签；旧数据空串时渲染端按 kind 兜底） */
  head: string;
  /** 'issues' | 'prs'：类型限定词（is:issue/is:pr）由打开通道按 kind 追加，查询串内不落 */
  kind: string;
  query: string;
  iconKey: string;
  colorKey: string;
  createdAt: number;
}

const PREFS_NAME = 'shortcuts_prefs';

/** 存储键：按账号分区（同 050 favorites_prefs 思路） */
export function shortcutsKey(login: string): string {
  return `shortcuts_v1_${login}`;
}

/** 归一键：kind+query（小写化、折叠连续空白）——去重与「建议已保存则隐藏」共用同一判定 */
export function sameShortcutQuery(kind: string, query: string): string {
  return `${kind}|${query.trim().replace(/\s+/g, ' ')}`.toLowerCase();
}

/** 查询串拼装（纯函数）：复用 Work 词汇表纯函数；state 兼容 PR 的 merged/queued；不含 is:issue/is:pr。
 *  discussions 不落状态限定词（is:open 非 discussion 合法状态） */
export function buildShortcutQuery(kind: string, state: string, scope: string, visibility: string,
  sortKey: string, orgs: string[], repos: string[]): string {
  let query = '';
  if (kind !== 'discussions') {
    if (state === 'open') {
      query += ' is:open';
    } else if (state === 'closed') {
      query += ' is:closed';
    } else if (state === 'merged') {
      query += ' is:merged';
    } else if (state === 'queued') {
      query += ' is:queued';
    }
  }
  query += ` ${workScopeQualifier(scope)}`;
  const vis = workVisibilityQualifier(visibility);
  if (vis !== '') {
    query += ` ${vis}`;
  }
  orgs.forEach((o: string) => {
    query += ` org:${o}`;
  });
  repos.forEach((r: string) => {
    query += ` repo:${r}`;
  });
  query += ` ${workIssuesSortQualifier(sortKey)}`;
  return query.trim();
}

/** 序列化（纯函数） */
export function shortcutsToStorage(list: ShortcutItem[]): string {
  return JSON.stringify(list);
}

/** 反序列化（纯函数）：坏输入回退空数组，非法/重复（kind+query）条目剔除，保持数组顺序 */
export function shortcutsFromStorage(text: string): ShortcutItem[] {
  try {
    const parsed: Object | null = JSON.parse(text);
    if (!Array.isArray(parsed)) {
      return [];
    }
    const result: ShortcutItem[] = [];
    const seen: Set<string> = new Set();
    for (const raw of parsed as Object[]) {
      const map = raw as JsonMap;
      const name = Json.str(map, 'name');
      const kind = Json.str(map, 'kind');
      const query = Json.str(map, 'query');
      const dedupeKey = sameShortcutQuery(kind, query);
      if (name === '' || kind === '' || query === '' || seen.has(dedupeKey)) {
        continue;
      }
      seen.add(dedupeKey);
      result.push({
        id: Json.str(map, 'id'),
        name: name,
        head: Json.str(map, 'head'),
        kind: kind,
        query: query,
        iconKey: Json.str(map, 'iconKey'),
        colorKey: Json.str(map, 'colorKey'),
        createdAt: Json.num(map, 'createdAt', 0)
      });
    }
    return result;
  } catch (e) {
    return [];
  }
}

/** 添加（纯函数）：kind+query 已存在原序返回副本，新项追加末尾 */
export function addShortcut(list: ShortcutItem[], item: ShortcutItem): ShortcutItem[] {
  const key = sameShortcutQuery(item.kind, item.query);
  for (const s of list) {
    if (sameShortcutQuery(s.kind, s.query) === key) {
      return list.slice();
    }
  }
  const next = list.slice();
  next.push(item);
  return next;
}

/** 移除（纯函数）：按 id 定位，不存在原序返回副本 */
export function removeShortcut(list: ShortcutItem[], id: string): ShortcutItem[] {
  return list.filter((s: ShortcutItem): boolean => s.id !== id);
}

/** 排序（纯函数）：把 from 处条目移到 to 处；越界或原位返回原序副本（同 moveFavorite 语义） */
export function moveShortcut(list: ShortcutItem[], from: number, to: number): ShortcutItem[] {
  const next: ShortcutItem[] = list.slice();
  if (from < 0 || from >= next.length || to < 0 || to >= next.length || from === to) {
    return next;
  }
  const moved = next[from];
  next.splice(from, 1);
  next.splice(to, 0, moved);
  return next;
}

/** 快捷方式 store：Home/管理页镜像读取，SAVE 落盘（050 FavoritesStore 同构） */
@ObservedV2
export class ShortcutStore {
  @Trace list: ShortcutItem[] = [];
  /** 当前分区账号（空 = 未登录兜底，仍可读写默认分区） */
  currentLogin: string = '';

  static instance: ShortcutStore = new ShortcutStore();

  /** 进入 Home/管理页时加载当前账号分区（无账号为空列表） */
  static async load(context: common.Context | undefined, login: string): Promise<void> {
    ShortcutStore.instance.currentLogin = login;
    if (context === undefined) {
      return;
    }
    try {
      const prefs = await preferences.getPreferences(context, PREFS_NAME);
      const value: preferences.ValueType = await prefs.get(shortcutsKey(login), '');
      ShortcutStore.instance.list = typeof value === 'string' ? shortcutsFromStorage(value) : [];
    } catch (e) {
      // 首启无配置属正常路径，保持空列表
    }
  }

  /** SAVE：持久化当前列表到当前账号分区（失败静默，不阻断返回） */
  static async save(context: common.Context | undefined): Promise<void> {
    if (context === undefined) {
      return;
    }
    try {
      const prefs = await preferences.getPreferences(context, PREFS_NAME);
      await prefs.put(shortcutsKey(ShortcutStore.instance.currentLogin),
        shortcutsToStorage(ShortcutStore.instance.list));
      await prefs.flush();
    } catch (e) {
      // 持久化失败不阻断交互（下次保存可重试）
    }
  }
}
