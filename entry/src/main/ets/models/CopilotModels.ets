/**
 * Copilot 页模型（Spec 058 UI 架子）。
 * 全部为 mock 数据——Copilot 私有 API 无公开契约，功能批接入后替换（见 058 备注）。
 */

export interface ChatMessage {
  id: string;
  isUser: boolean;
  body: string;
}

export interface ChatSession {
  id: string;
  title: string;
  /** ISO 时间戳 → githubShortTime 渲染相对时间（mock 取当前时刻 → just now） */
  updatedAt: string;
}

/** 主页 Chats mock 会话（对齐参考图：《网站性能优化方法》为当前会话） */
export function mockChatSessions(): ChatSession[] {
  const now = new Date().toISOString();
  return [
    { id: 'mock-2', title: '网站性能优化方法', updatedAt: now },
    { id: 'mock-1', title: '参与 React 代码库的指导', updatedAt: now }
  ];
}

/** 详情页 mock 消息：用户多要点 + 助手回复 + 追问（对齐参考图 3 内容） */
export function mockChatMessages(): ChatMessage[] {
  return [
    {
      id: 'm1',
      isUser: true,
      body: '如果您有：\n· 需要优化性能的网站\n· 想要搜索某个开源项目中的性能优化代码示例\n· 想配置 GitHub Actions 来进行性能测试'
    },
    {
      id: 'm2',
      isUser: false,
      body: '我很乐意帮助！您能告诉我具体是哪方面的 GitHub 相关问题吗?'
    },
    {
      id: 'm3',
      isUser: true,
      body: '网站性能优化方法'
    }
  ];
}
