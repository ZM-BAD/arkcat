/**
 * Copilot 页模型与纯函数（Spec 059 功能批）。
 * 会话/消息为本地持久化数据（Copilot 无会话历史公开 API，见 059 五章）；
 * mock 常量已于本批删除（058 UI 架子数据源被 CopilotStore 替代）。
 */

export interface ChatMessage {
  id: string;
  isUser: boolean;
  body: string;
}

export interface ChatSession {
  id: string;
  title: string;
  /** ISO 时间戳 → githubShortTime 渲染相对时间（消息变更时刷新） */
  updatedAt: string;
  messages: ChatMessage[];
}

/** 会话标题：首条用户消息前 40 字符（官方行为近似），失败回退空串（显示 New conversation） */
export function firstMessageTitle(body: string): string {
  const trimmed = body.trim();
  if (trimmed === '') {
    return '';
  }
  return trimmed.length > 40 ? trimmed.substring(0, 40) : trimmed;
}
