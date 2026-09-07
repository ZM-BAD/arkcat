/**
 * GitHub HTTP 客户端：GraphQL v4 主通道 + REST v3 兜底。
 *
 * 统一封装鉴权、超时与错误映射，页面禁止直接调用 http。
 */
import { http } from '@kit.NetworkKit';
import { Json, JsonMap } from '../utils/Json';
import { resText } from '../utils/I18n';

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

export interface RawResponse {
  code: number;
  body: string;
  /** Link 分页头（GitHub 分页接口返回；如 contributors 的 rel="last" 页数=贡献者计数） */
  link?: string;
}

function baseHeaders(token: string): Record<string, string> {
  const headers: Record<string, string> = {
    'User-Agent': USER_AGENT,
    'Accept': API_VERSION,
    'Authorization': `Bearer ${token}`
  };
  return headers;
}

async function request(method: http.RequestMethod, url: string, token: string, body?: string,
  accept?: string): Promise<RawResponse> {
  const req = http.createHttp();
  try {
    const headers: Record<string, string> = baseHeaders(token);
    if (accept !== undefined) {
      headers['Accept'] = accept;
    }
    const options: http.HttpRequestOptions = {
      method: method,
      header: headers,
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
    // GitHub 返回小写 "link"；部分代理/网关可能保留 "Link" 原样，双写兼容
    let link = '';
    if (resp.header !== undefined && resp.header !== null) {
      const header = resp.header as Record<string, Object>;
      const v = header['link'] ?? header['Link'];
      if (typeof v === 'string') {
        link = v;
      }
    }
    if (code < 200 || code >= 300) {
      // 拼入响应 body 的 message，便于 422/403 等业务失败排查（review G11）
      let detail = '';
      const errBody = Json.parse(text);
      if (errBody !== null) {
        const m = Json.str(errBody, 'message');
        if (m !== '') {
          detail = ` ${m}`;
        }
      }
      throw new ApiError(code, `GitHub API ${url} -> HTTP ${code}${detail.substring(0, 200)}`);
    }
    return { code: code, body: text, link: link };
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
    throw new ApiError(0, `Network request failed: ${msg}`);
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
    throw new ApiError(resp.code, 'Failed to parse GraphQL response');
  }
  const errors = Json.arr(root, 'errors');
  if (errors.length > 0) {
    const first = errors[0] as JsonMap;
    // GraphQL 错误恒为 HTTP 200：按 errors[].type 映射语义状态码，
    // 否则页面 401/403/429 分支永不命中（review G2，实测 200+errors 并存）
    const type = Json.str(first, 'type');
    let semantic = resp.code;
    if (type === 'RATE_LIMITED') {
      semantic = 429;
    } else if (type === 'FORBIDDEN' || type === 'INSUFFICIENT_SCOPE' || type === 'ACCESS_DENIED') {
      semantic = 403;
    } else if (type === 'NOT_FOUND') {
      semantic = 404;
    } else if (type === 'UNPROCESSABLE' || type === 'VALIDATION') {
      semantic = 422;
    } else if (type === 'UNAUTHORIZED') {
      semantic = 401;
    }
    throw new ApiError(semantic, `GraphQL error: ${Json.str(first, 'message')}`);
  }
  const data = Json.obj(root, 'data');
  if (data === null) {
    throw new ApiError(resp.code, 'GraphQL response missing data');
  }
  return data;
}

/** REST GET */
export async function restGet(path: string, token: string, accept?: string): Promise<RawResponse> {
  return request(http.RequestMethod.GET, `${GITHUB_API}${path}`, token, undefined, accept);
}

/** REST POST（/markdown 渲染等带 JSON body 请求） */
export async function restPost(path: string, token: string, body: string, accept?: string): Promise<RawResponse> {
  return request(http.RequestMethod.POST, `${GITHUB_API}${path}`, token, body, accept);
}

/** REST PATCH（标记通知已读等） */
export async function restPatch(path: string, token: string): Promise<RawResponse> {
  return request(http.RequestMethod.PATCH, `${GITHUB_API}${path}`, token);
}


/** 异常 → 本地化友好文案（review A14/E16：裸异常串不直出给用户） */
export function friendlyError(uiContext: UIContext, e: Error): string {
  let code = 0;
  if (e instanceof ApiError) {
    code = e.code;
  } else {
    const found = /HTTP (\d{3})/.exec(e.message);
    code = found !== null && found[1] !== undefined ? Number(found[1]) : 0;
  }
  if (code === 401) {
    return resText(uiContext, $r('app.string.error_auth'));
  }
  if (code === 403 || code === 429) {
    return resText(uiContext, $r('app.string.error_rate_limited'));
  }
  if (code === 0) {
    return resText(uiContext, $r('app.string.error_network'));
  }
  return resText(uiContext, $r('app.string.error_generic'));
}
