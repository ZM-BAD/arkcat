/**
 * Copilot 私有 API 客户端（Spec 059）。
 *
 * 端点：https://api.githubcopilot.com（与 GitHub 主 API 不同域，GitHttpClient 硬编码
 * 主域前缀，故独立封装，仿 OAuthService postForm 模式）。
 *
 * 付费红线（用户强制）：仅暴露 chat/completions 写端点，模型恒为 FREE_CHAT_MODELS
 * 白名单常量（2026-09-08 实测 gpt-4o-mini-2024-07-18 可用；premium 模型 Free 用户
 * 实测 400 model_not_supported）。UI 无模型选择入口——/models 返回列表含 premium 项，
 * 绝不能透传给用户选择。无任何 subscription / billing / upgrade 调用。
 */
import { http } from '@kit.NetworkKit';
import { Json, JsonMap } from '../utils/Json';

const COPILOT_API = 'https://api.githubcopilot.com';
const GITHUB_API = 'https://api.github.com';
const USER_AGENT = 'ArkCat/1.0.0';

/** 免费模型白名单（唯一请求模型来源；新增须先 gh api 实测 200 再入库） */
export const FREE_CHAT_MODELS: string[] = ['gpt-4o-mini-2024-07-18'];

/** 白名单校验（纯函数，宿主 UT 覆盖）：/models 列表透传安全闸门，拒绝一切 premium 模型 */
export function isFreeModelAllowed(id: string): boolean {
  return FREE_CHAT_MODELS.indexOf(id) >= 0;
}

/** Chat 请求的消息轮次（仅支持 user/assistant 两项） */
export interface CopilotTurn {
  role: string;
  content: string;
}

/** 请求体构造（纯函数）：model 恒取白名单首项，永不走参数 */
export function buildChatPayload(turns: CopilotTurn[], model?: string): string {
  const used = model !== undefined && isFreeModelAllowed(model) ? model : FREE_CHAT_MODELS[0];
  const payload: JsonMap = {
    'model': used,
    'messages': turns as Object,
    'stream': false
  };
  return JSON.stringify(payload);
}

/** 响应解析（纯函数）：choices[0].message.content；缺分支/空内容回退空串 */
export function parseChatResponse(body: string): string {
  const root = Json.parse(body);
  if (root === null) {
    return '';
  }
  const choices = Json.arr(root, 'choices');
  if (choices.length === 0) {
    return '';
  }
  const first = choices[0] as JsonMap;
  const message = Json.obj(first, 'message') ?? ({} as JsonMap);
  return Json.str(message, 'content');
}

/**
 * 发送一轮对话（非流式，一次取整）。
 * 异常语义：ApiError 风格复用 GitHttpClient 的 friendlyError 映射（401/403/429/网络），
 * 但本域错误文案走 copilotErrorText——403 在 Copilot 语境=无权限/配额用尽，与 GitHub
 * 主 API 的 rate-limited 文案不同。
 */
export async function copilotChat(token: string, turns: CopilotTurn[]): Promise<string> {
  const resp = await postJson(`${COPILOT_API}/chat/completions`, token, buildChatPayload(turns));
  const content = parseChatResponse(resp);
  if (content === '') {
    throw new Error('Copilot returned empty content');
  }
  return content;
}

/** 服务端用量快照（copilot_internal/user 的 quota_snapshots 归一化） */
export interface CopilotQuota {
  /** chat 已用百分比（0-100 四舍五入；服务端 percent_remaining 取反） */
  chatUsedPercent: number;
  /** code completions 已用百分比（0-100） */
  completionsUsedPercent: number;
  /** chat 剩余额度（诊断展示用） */
  chatRemaining: number;
  /** chat 总额度（Free 月配额实测 200） */
  chatEntitlement: number;
}

/** 单条 quota 快照 → 已用百分比（纯函数）：percent_remaining 缺失/越界回退 0 */
export function usedPercentOf(snapshot: JsonMap | null): number {
  if (snapshot === null) {
    return 0;
  }
  const remaining = Json.num(snapshot, 'percent_remaining', -1);
  if (remaining < 0 || remaining > 100) {
    return 0;
  }
  return Math.round(100 - remaining);
}

/** 用量解析（纯函数）：quota_snapshots.chat/.completions；缺整段回退 null（调用方走本地估算） */
export function parseCopilotQuota(body: string): CopilotQuota | null {
  const root = Json.parse(body);
  if (root === null) {
    return null;
  }
  const snapshots = Json.obj(root, 'quota_snapshots');
  if (snapshots === null) {
    return null;
  }
  const chatRaw = Json.obj(snapshots, 'chat');
  const completionsRaw = Json.obj(snapshots, 'completions');
  if (chatRaw === null && completionsRaw === null) {
    return null;
  }
  const chat: JsonMap = chatRaw ?? ({} as JsonMap);
  return {
    chatUsedPercent: usedPercentOf(chatRaw),
    completionsUsedPercent: usedPercentOf(completionsRaw),
    chatRemaining: Json.num(chat, 'remaining', 0),
    chatEntitlement: Json.num(chat, 'entitlement', 0)
  };
}

/**
 * 拉取服务端真实用量（undocumented 内部端点，2026-09-08 实测 200：Free 账号
 * quota_snapshots = chat/completions/premium_interactions）。失败回退 null，
 * 调用方降级为本地记账近似——该端点非公开契约，不能成为唯一数据源。
 */
export async function fetchCopilotQuota(token: string): Promise<CopilotQuota | null> {
  if (token === '') {
    return null;
  }
  try {
    const body = await getJson(`${GITHUB_API}/copilot_internal/user`, token);
    return parseCopilotQuota(body);
  } catch (e) {
    return null;
  }
}

/** GET JSON —— 返回响应体字符串；非 2xx 抛 Error */
async function getJson(url: string, token: string): Promise<string> {
  const req = http.createHttp();
  try {
    const options: http.HttpRequestOptions = {
      method: http.RequestMethod.GET,
      header: {
        'Authorization': `Bearer ${token}`,
        'Accept': 'application/json',
        'User-Agent': USER_AGENT
      },
      expectDataType: http.HttpDataType.STRING,
      connectTimeout: 15000,
      readTimeout: 20000
    };
    const resp = await req.request(url, options);
    const code = typeof resp.responseCode === 'number' ? resp.responseCode : 0;
    const text = typeof resp.result === 'string' ? resp.result : '';
    if (code < 200 || code >= 300) {
      throw new Error(`GitHub API ${url} -> HTTP ${code} ${text.substring(0, 200)}`);
    }
    return text;
  } finally {
    req.destroy();
  }
}

/** POST JSON —— 返回响应体字符串；非 2xx 抛 Error（含 HTTP code，错误文案映射处解析） */
async function postJson(url: string, token: string, body: string): Promise<string> {  const req = http.createHttp();
  try {
    const options: http.HttpRequestOptions = {
      method: http.RequestMethod.POST,
      header: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'User-Agent': USER_AGENT
      },
      expectDataType: http.HttpDataType.STRING,
      connectTimeout: 15000,
      readTimeout: 30000,
      extraData: body
    };
    const resp = await req.request(url, options);
    const code = typeof resp.responseCode === 'number' ? resp.responseCode : 0;
    const text = typeof resp.result === 'string' ? resp.result : '';
    if (code < 200 || code >= 300) {
      throw new Error(`Copilot API ${url} -> HTTP ${code} ${text.substring(0, 200)}`);
    }
    return text;
  } catch (e) {
    if (e instanceof Error) {
      throw e;
    }
    throw new Error(`Copilot API network failed: ${e}`);
  } finally {
    req.destroy();
  }
}
