/**
 * Copilot 会话本地存储（Spec 059）。
 *
 * Copilot 无会话历史公开 API（/threads 等 404 实测，见 059 五章），会话保存在本机
 * preferences：@ObservedV2 单例 + @Trace 保证主页/详情页共享同一数据源、修改即刷新
 * （仿 WorkConfigStore 模式）。序列化/反序列化为纯函数，供宿主 UT 覆盖。
 *
 * 持久化策略：load 首次落内存后记录 context，之后每次变更自动 fire-and-forget 落盘
 * （内存单例先更新，异步 flush 兜底）——杜绝「详情页已更新、退回主页被磁盘旧数据覆盖」。
 */
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { ChatMessage, ChatSession, firstMessageTitle } from '../models/CopilotModels';
import { Json, JsonMap } from './Json';

const TAG = '[CopilotStore]';

const PREFS_NAME = 'copilot_prefs';
const PREFS_KEY = 'copilot_sessions_v1';

/** 新建消息 id（时间戳 + 序号防同毫秒碰撞） */
let msgSeq = 0;

function newId(prefix: string): string {
  msgSeq += 1;
  return `${prefix}-${Date.now()}-${msgSeq}`;
}

/** 序列化（纯函数）：消息/会话全量落盘 */
export function copilotSessionsToStorage(sessions: ChatSession[]): string {
  return JSON.stringify(sessions);
}

/** 反序列化（纯函数）：坏输入/缺字段回退空数组（空数组=主页空态卡） */
export function copilotSessionsFromStorage(text: string): ChatSession[] {
  try {
    const parsed: Object | null = JSON.parse(text);
    if (!Array.isArray(parsed)) {
      return [];
    }
    const result: ChatSession[] = [];
    for (const raw of parsed as Object[]) {
      const map = raw as JsonMap;
      const id = Json.str(map, 'id');
      if (id === '') {
        continue;
      }
      const messages: ChatMessage[] = [];
      const rawMessages = Json.arr(map, 'messages');
      for (const rawMsg of rawMessages) {
        const msg = rawMsg as JsonMap;
        const body = Json.str(msg, 'body');
        const msgId = Json.str(msg, 'id');
        if (body !== '' && msgId !== '') {
          messages.push({
            id: msgId,
            isUser: Json.bool(msg, 'isUser', false),
            body: body
          });
        }
      }
      result.push({
        id: id,
        title: Json.str(map, 'title'),
        updatedAt: Json.str(map, 'updatedAt'),
        messages: messages
      });
    }
    return result;
  } catch (e) {
    return [];
  }
}

@ObservedV2
export class CopilotStore {
  @Trace sessions: ChatSession[] = [];

  static instance: CopilotStore = new CopilotStore();

  /** 加载后的宿主 context（变更自动落盘用；未加载为 undefined，静默跳过） */
  private static ctx: common.Context | undefined = undefined;

  /** load 执行完至少一次（避免每切回 Tab 重读磁盘覆盖最新内存态） */
  private static loaded: boolean = false;

  /** 内存变更版本戳：load 结果晚到时若版本已前进则丢弃（防磁盘旧数据覆盖新会话） */
  private static version: number = 0;

  /** 启动/首次进入时加载持久化会话；失败保持空数组（主页显示空态） */
  static async load(context: common.Context | undefined): Promise<void> {
    if (context === undefined) {
      return;
    }
    CopilotStore.ctx = context;
    if (CopilotStore.loaded) {
      return;
    }
    CopilotStore.loaded = true;
    const v0 = CopilotStore.version;
    try {
      const prefs = await preferences.getPreferences(context, PREFS_NAME);
      const value: preferences.ValueType = await prefs.get(PREFS_KEY, '');
      if (typeof value === 'string' && CopilotStore.version === v0) {
        CopilotStore.instance.sessions = copilotSessionsFromStorage(value);
        hilog.info(0xFF00, TAG, 'load ok: %{public}d sessions', CopilotStore.instance.sessions.length);
      }
    } catch (e) {
      // 首启/损坏数据属正常路径，保持空数组
      hilog.error(0xFF00, TAG, 'load failed: %{public}s', `${e}`);
    }
  }

  /** 变更自动落盘（fire-and-forget；失败静默，下次变更重试） */
  private static persist(): void {
    CopilotStore.version += 1;
    const ctx = CopilotStore.ctx;
    if (ctx === undefined) {
      return;
    }
    preferences.getPreferences(ctx, PREFS_NAME).then((prefs: preferences.Preferences) => {
      prefs.put(PREFS_KEY, copilotSessionsToStorage(CopilotStore.instance.sessions))
        .then((): Promise<void> => prefs.flush())
        .catch(() => {
        });
    }).catch(() => {
    });
  }

  /** 新建空会话（标题占位 New conversation，首条用户消息后由 firstMessageTitle 接管） */
  static createSession(): ChatSession {
    const session: ChatSession = {
      id: newId('chat'),
      title: '',
      updatedAt: new Date().toISOString(),
      messages: []
    };
    CopilotStore.instance.sessions = [session, ...CopilotStore.instance.sessions];
    CopilotStore.persist();
    return session;
  }

  static find(id: string): ChatSession | null {
    for (const s of CopilotStore.instance.sessions) {
      if (s.id === id) {
        return s;
      }
    }
    return null;
  }

  /** 删除会话（主页/详情共享单例，删除后立即反映） */
  static delete(id: string): void {
    const next: ChatSession[] = [];
    for (const s of CopilotStore.instance.sessions) {
      if (s.id !== id) {
        next.push(s);
      }
    }
    CopilotStore.instance.sessions = next;
    CopilotStore.persist();
  }

  /** 追加消息（不变的数组引用重赋值触发 @Trace） */
  static appendMessage(sessionId: string, isUser: boolean, body: string): void {
    const session = CopilotStore.find(sessionId);
    if (session === null) {
      return;
    }
    const message: ChatMessage = { id: newId('msg'), isUser: isUser, body: body };
    const messages: ChatMessage[] = session.messages.concat([message]);
    const title = isUser && session.title === '' ? firstMessageTitle(body) : session.title;
    CopilotStore.update(sessionId, title, messages);
  }

  /** 全量替换会话（标题/消息变化统一入口，updatedAt 刷新排序） */
  static update(sessionId: string, title: string, messages: ChatMessage[]): void {
    const sessions: ChatSession[] = [];
    for (const s of CopilotStore.instance.sessions) {
      if (s.id === sessionId) {
        sessions.push({
          id: s.id,
          title: title,
          updatedAt: new Date().toISOString(),
          messages: messages
        });
      } else {
        sessions.push(s);
      }
    }
    CopilotStore.instance.sessions = sessions;
    CopilotStore.persist();
  }
}
