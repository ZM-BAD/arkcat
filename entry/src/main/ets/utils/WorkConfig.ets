/**
 * Home My Work 条目配置（Spec 016）：全局可观察单例 + Preferences 持久化。
 * 数组顺序即 Home 显示顺序；visible=false 的条目在 Home 隐藏。
 * 用 @ObservedV2 + @Trace：Edit My Work 保存后 Home 立即反映，无需手动刷新。
 */
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { Json, JsonMap } from './Json';

/** My Work 条目定义（id 与 Home 路由映射固定） */
export interface WorkSection {
  id: string;
  visible: boolean;
}

/** 七个条目的默认顺序（与 Spec 013 一致） */
export const WORK_SECTION_IDS: string[] = [
  'issues', 'prs', 'discussions', 'projects', 'topRepos', 'orgs', 'starred'
];

const PREFS_NAME = 'work_prefs';
const PREFS_KEY = 'work_sections_v1';

/** 默认配置：全勾选、013 顺序 */
export function defaultWorkSections(): WorkSection[] {
  const result: WorkSection[] = [];
  for (const id of WORK_SECTION_IDS) {
    result.push({ id: id, visible: true });
  }
  return result;
}

/** 过滤 + 顺序（纯函数）：仅返回 visible 条目，保持数组顺序 */
export function visibleWorkSections(sections: WorkSection[]): WorkSection[] {
  const result: WorkSection[] = [];
  for (const section of sections) {
    if (section.visible) {
      result.push(section);
    }
  }
  return result;
}

/** 序列化 + 反序列化（纯函数）：坏输入回退默认配置，非法/重复条目剔除 */
export function workSectionsToStorage(sections: WorkSection[]): string {
  return JSON.stringify(sections);
}

export function workSectionsFromStorage(text: string): WorkSection[] {
  try {
    const parsed: Object | null = JSON.parse(text);
    if (!Array.isArray(parsed)) {
      return defaultWorkSections();
    }
    const result: WorkSection[] = [];
    const seen: Set<string> = new Set();
    for (const raw of parsed as Object[]) {
      const map = raw as JsonMap;
      const id = Json.str(map, 'id');
      if (id !== '' && !seen.has(id) && WORK_SECTION_IDS.indexOf(id) >= 0) {
        seen.add(id);
        result.push({ id: id, visible: Json.bool(map, 'visible', true) });
      }
    }
    return result.length > 0 ? result : defaultWorkSections();
  } catch (e) {
    return defaultWorkSections();
  }
}

@ObservedV2
export class WorkConfigStore {
  @Trace sections: WorkSection[] = defaultWorkSections();

  static instance: WorkConfigStore = new WorkConfigStore();

  /** 启动/进入编辑页时加载持久化配置（失败保持默认） */
  static async load(context: common.Context | undefined): Promise<void> {
    if (context === undefined) {
      return;
    }
    try {
      const prefs = await preferences.getPreferences(context, PREFS_NAME);
      const value: preferences.ValueType = await prefs.get(PREFS_KEY, '');
      if (typeof value === 'string') {
        WorkConfigStore.instance.sections = workSectionsFromStorage(value);
      }
    } catch (e) {
      // 首启无配置属正常路径，保持默认
    }
  }

  /** SAVE：持久化当前配置（失败静默，不阻断返回） */
  static async save(context: common.Context | undefined): Promise<void> {
    if (context === undefined) {
      return;
    }
    try {
      const prefs = await preferences.getPreferences(context, PREFS_NAME);
      await prefs.put(PREFS_KEY, workSectionsToStorage(WorkConfigStore.instance.sections));
      await prefs.flush();
    } catch (e) {
      // 持久化失败不阻断交互（下次进入可重试）
    }
  }
}
