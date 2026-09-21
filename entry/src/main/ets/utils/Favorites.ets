/**
 * Home Favorites 收藏（Spec 050）：纯函数 + 全局可观察单例 + Preferences 持久化。
 * 公开 GitHub API 无 favorites 读/写能力（官方为私有接口）→ 端侧存储；
 * 数据按当前账号 login 分区（切账号互不可见），数组顺序即 Home 展示顺序。
 */
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { Json, JsonMap } from './Json';
import { PickerRepo } from '../models/RepoSubModels';

/** 收藏项（owner/name 唯一；ownerAvatar 添加时缓存，离线可渲染） */
export interface FavoriteRepo {
  ownerLogin: string;
  name: string;
  ownerAvatar: string;
  addedAt: number;
}

const PREFS_NAME = 'favorites_prefs';

/** 存储键：按账号分区（049 缓存键同思路） */
export function favoritesKey(login: string): string {
  return `favorites_v1_${login}`;
}

/** 唯一标识：owner/name（小写归一，GitHub 仓库路径大小写不敏感） */
export function favoriteId(ownerLogin: string, name: string): string {
  return `${ownerLogin}/${name}`.toLowerCase();
}

/** 序列化（纯函数） */
export function favoritesToStorage(favorites: FavoriteRepo[]): string {
  return JSON.stringify(favorites);
}

/** 反序列化（纯函数）：坏输入回退空数组，非法/重复条目剔除，保持数组顺序 */
export function favoritesFromStorage(text: string): FavoriteRepo[] {
  try {
    const parsed: Object | null = JSON.parse(text);
    if (!Array.isArray(parsed)) {
      return [];
    }
    const result: FavoriteRepo[] = [];
    const seen: Set<string> = new Set();
    for (const raw of parsed as Object[]) {
      const map = raw as JsonMap;
      const ownerLogin = Json.str(map, 'ownerLogin');
      const name = Json.str(map, 'name');
      const id = favoriteId(ownerLogin, name);
      if (ownerLogin === '' || name === '' || seen.has(id)) {
        continue;
      }
      seen.add(id);
      result.push({
        ownerLogin: ownerLogin,
        name: name,
        ownerAvatar: Json.str(map, 'ownerAvatar'),
        addedAt: Json.num(map, 'addedAt', 0)
      });
    }
    return result;
  } catch (e) {
    return [];
  }
}

/** 添加（纯函数）：已存在原序返回副本，新项追加末尾 */
export function addFavorite(favorites: FavoriteRepo[], item: FavoriteRepo): FavoriteRepo[] {
  const id = favoriteId(item.ownerLogin, item.name);
  for (const f of favorites) {
    if (favoriteId(f.ownerLogin, f.name) === id) {
      return favorites.slice();
    }
  }
  const next = favorites.slice();
  next.push(item);
  return next;
}

/** 移除（纯函数）：按 owner/name 定位，不存在原序返回副本 */
export function removeFavorite(favorites: FavoriteRepo[], ownerLogin: string, name: string): FavoriteRepo[] {
  const id = favoriteId(ownerLogin, name);
  return favorites.filter((f: FavoriteRepo): boolean => favoriteId(f.ownerLogin, f.name) !== id);
}

/** 排序（纯函数）：把 from 处条目移到 to 处；越界或原位返回原序副本（同 moveWorkSection 语义） */
export function moveFavorite(favorites: FavoriteRepo[], from: number, to: number): FavoriteRepo[] {
  const next: FavoriteRepo[] = favorites.slice();
  if (from < 0 || from >= next.length || to < 0 || to >= next.length || from === to) {
    return next;
  }
  const moved = next[from];
  next.splice(from, 1);
  next.splice(to, 0, moved);
  return next;
}

/** 候选过滤（纯函数）：从 Top Repositories 与搜索结果中剔除已收藏仓库（两区联动去重） */
export function filterCandidates(candidates: PickerRepo[], favorites: FavoriteRepo[]): PickerRepo[] {
  const picked: Set<string> = new Set();
  for (const f of favorites) {
    picked.add(favoriteId(f.ownerLogin, f.name));
  }
  return candidates.filter((c: PickerRepo): boolean => !picked.has(favoriteId(c.ownerLogin, c.name)));
}

/** 搜索词可用性（纯函数）：trim 后非空才触发服务端搜索 */
export function isSearchable(keyword: string): boolean {
  return keyword.trim() !== '';
}

@ObservedV2
export class FavoritesStore {
  @Trace list: FavoriteRepo[] = [];
  /** 当前分区账号（空 = 未登录兜底，仍可读写默认分区） */
  currentLogin: string = '';

  static instance: FavoritesStore = new FavoritesStore();

  /** 进入 Home/编辑页时加载当前账号分区（无账号为空列表） */
  static async load(context: common.Context | undefined, login: string): Promise<void> {
    FavoritesStore.instance.currentLogin = login;
    if (context === undefined) {
      return;
    }
    try {
      const prefs = await preferences.getPreferences(context, PREFS_NAME);
      const value: preferences.ValueType = await prefs.get(favoritesKey(login), '');
      FavoritesStore.instance.list = typeof value === 'string' ? favoritesFromStorage(value) : [];
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
      await prefs.put(favoritesKey(FavoritesStore.instance.currentLogin),
        favoritesToStorage(FavoritesStore.instance.list));
      await prefs.flush();
    } catch (e) {
      // 持久化失败不阻断交互（下次保存可重试）
    }
  }
}
