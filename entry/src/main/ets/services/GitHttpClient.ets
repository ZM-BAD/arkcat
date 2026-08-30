/**
 * GitHub HTTP 客户端：GraphQL v4 主通道 + REST v3 兜底。
 *
 * 统一封装鉴权、超时与错误映射，页面禁止直接调用 http。
 */
import { http } from '@kit.NetworkKit';
import { Json, JsonMap } from '../utils/Json';

const GITHUB_API = 'https://api.github.com';
const GITHUB_GRAPHQL = 'https://api.github.com/graphql';
const USER_AGENT = 'StarRaft';
const API_VERSION = 'application/vnd.github+json';

/** API 调用失败异常：code 为 HTTP 状态码（0 表示网络层失败） */
export class ApiError extends Error {
  readonly code: number;

  constructor(code: number, message: string) {
    super(message);
    this.code = code;
  }
}

interface RawResponse {
  code: number;
  body: string;
}

function baseHeaders(token: string): Record<string, string> {
  const headers: Record<string, string> = {
    'User-Agent': USER_AGENT,
    'Accept': API_VERSION,
    'Authorization': `Bearer ${token}`
  };
  return headers;
}

async function request(method: http.RequestMethod, url: string, token: string, body?: string): Promise<RawResponse> {
  const req = http.createHttp();
  try {
    const options: http.HttpRequestOptions = {
      method: method,
      header: baseHeaders(token),
      expectDataType: http.HttpDataType.STRING,
      connectTimeout: 15000,
      readTimeout: 20000
    };
    if (body !== undefined) {
      options.extraData = body;
    }
    const resp = await req.request(url, options);
    const code = typeof resp.responseCode === 'number' ? resp.responseCode : 0;
    const text = typeof resp.result === 'string' ? resp.result : '';
    if (code < 200 || code >= 300) {
      throw new ApiError(code, `GitHub API ${url} -> HTTP ${code}`);
    }
    return { code: code, body: text };
  } catch (e) {
    if (e instanceof ApiError) {
      throw e;
    }
    // BusinessError 等非 Error 异常：提取 code/message，避免 "[object Object]"
    let msg = `${e}`;
    if (e !== null && typeof e === 'object') {
      const record = e as Record<string, Object>;
      const m = record['message'];
      const c = record['code'];
      if (typeof m === 'string' && m !== '') {
        msg = typeof c === 'number' ? `${m} (code ${c})` : m;
      }
    }
    throw new ApiError(0, `网络请求失败: ${msg}`);
  } finally {
    req.destroy();
  }
}

/** GraphQL 请求：返回 data 节点；errors 非空时抛 ApiError(401/422 语义) */
export async function graphql(query: string, variables: Record<string, Object> | null,
  token: string): Promise<JsonMap> {
  const payload: Record<string, Object> = { 'query': query };
  if (variables !== null) {
    payload['variables'] = variables as Object;
  }
  const resp = await request(http.RequestMethod.POST, GITHUB_GRAPHQL, token, JSON.stringify(payload));
  const root = Json.parse(resp.body);
  if (root === null) {
    throw new ApiError(resp.code, 'GraphQL 响应解析失败');
  }
  const errors = Json.arr(root, 'errors');
  if (errors.length > 0) {
    const first = errors[0] as JsonMap;
    throw new ApiError(resp.code, `GraphQL 错误: ${Json.str(first, 'message')}`);
  }
  const data = Json.obj(root, 'data');
  if (data === null) {
    throw new ApiError(resp.code, 'GraphQL 响应缺少 data');
  }
  return data;
}

/** REST GET */
export async function restGet(path: string, token: string): Promise<RawResponse> {
  return request(http.RequestMethod.GET, `${GITHUB_API}${path}`, token);
}

/** REST PATCH（标记通知已读等） */
export async function restPatch(path: string, token: string): Promise<RawResponse> {
  return request(http.RequestMethod.PATCH, `${GITHUB_API}${path}`, token);
}
