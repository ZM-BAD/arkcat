/**
 * Explore Activity 类型筛选：键定义 + Preferences 持久化（Spec 056 收口，Filter Activity 参考图 2026-09-07）。
 * 官方六类（Announcements/Releases/Stars/Repositories/Follows/Recommendations）；
 * 当前 Activity 数据源为接收事件（merged PR 动态，近似 “Follows”，其余五类无公开 API，Spec 056 边界）。
 */
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

export const ACTIVITY_KIND_KEYS: string[] = [
  'announcements', 'releases', 'stars', 'repositories', 'follows', 'recommendations'
];

const PREFS_NAME = 'arkcat_settings';
const KEY_ACTIVITY_KINDS = 'explore_activity_kinds';

/** 读取已保存的勾选类型（未保存 / 解析失败 → 全选） */
export function readActivityKinds(ctx: common.Context | undefined): string[] {
  if (ctx === undefined) {
    return ACTIVITY_KIND_KEYS.slice();
  }
  try {
    const pref = preferences.getPreferencesSync(ctx, { name: PREFS_NAME });
    const raw = pref.getSync(KEY_ACTIVITY_KINDS, '') as string;
    if (raw === '') {
      return ACTIVITY_KIND_KEYS.slice();
    }
    const parsed: Object | null = JSON.parse(raw);
    if (parsed === null || !Array.isArray(parsed)) {
      return ACTIVITY_KIND_KEYS.slice();
    }
    const kinds: string[] = [];
    for (const k of parsed as Object[]) {
      if (typeof k === 'string') {
        kinds.push(k);
      }
    }
    return kinds.length > 0 ? kinds : ACTIVITY_KIND_KEYS.slice();
  } catch (e) {
    return ACTIVITY_KIND_KEYS.slice();
  }
}

/** 保存勾选类型（SAVE 按钮触发；写失败返回 false 由页面提示） */
export function saveActivityKinds(ctx: common.Context | undefined, kinds: string[]): boolean {
  if (ctx === undefined) {
    return false;
  }
  try {
    const pref = preferences.getPreferencesSync(ctx, { name: PREFS_NAME });
    pref.putSync(KEY_ACTIVITY_KINDS, JSON.stringify(kinds));
    pref.flush();
    return true;
  } catch (e) {
    return false;
  }
}
