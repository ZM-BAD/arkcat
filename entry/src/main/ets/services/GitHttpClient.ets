/**
 * GitHub HTTP 客户端：GraphQL v4 主通道 + REST v3 兜底。
 *
 * 传输、鉴权头、错误语义映射已下沉到 graphql 库（HAR 模块，通用 GraphQL over HTTP 封装），
 * 本文件只保留 GitHub 端点常量、REST 便捷封装与本地化错误文案。
 * 页面禁止直接调用 http。
 */
import { http } from '@kit.NetworkKit';
import { ApiError, GraphQLClient, HttpClient, HttpResponse, getHeader, JsonMap } from 'graphql';
import { resText } from '../utils/I18n';

// ApiError 由库定义：re-export 保持既有 `from '../services/GitHttpClient'` 引用路径不变
export { ApiError } from 'graphql';

const GITHUB_API = 'https://api.github.com';
const GITHUB_GRAPHQL = 'https://api.github.com/graphql';
const USER_AGENT = 'ArkCat/1.0.0';
const API_VERSION = 'application/vnd.github+json';

/** GitHub GraphQL 端点单例（错误词汇表属适配层：注入语义映射，库保持协议中立） */
const graphqlClient = new GraphQLClient(GITHUB_GRAPHQL, {
  'userAgent': USER_AGENT,
  'errorTypeToCode': mapGitHubErrorType
});

/**
 * GitHub GraphQL 错误语义映射（errors[].type → HTTP 语义码）。
 * GitHub 错误恒为 HTTP 200：不映射则页面 401/403/429 分支永不命中。
 */
export function mapGitHubErrorType(type: string): number {
  if (type === 'RATE_LIMITED') {
    return 429;
  }
  if (type === 'FORBIDDEN' || type === 'INSUFFICIENT_SCOPE' || type === 'ACCESS_DENIED') {
    return 403;
  }
  if (type === 'NOT_FOUND') {
    return 404;
  }
  if (type === 'UNPROCESSABLE' || type === 'VALIDATION') {
    return 422;
  }
  if (type === 'UNAUTHORIZED') {
    return 401;
  }
  return 200;
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

function toRawResponse(resp: HttpResponse): RawResponse {
  const link = getHeader(resp.headers, 'link');
  return { code: resp.code, body: resp.body, link: link !== '' ? link : undefined };
}

/** GraphQL 请求：返回 data 节点；errors 非空时抛 ApiError（语义码映射在库内） */
export async function graphql(query: string, variables: Record<string, Object> | null,
  token: string): Promise<JsonMap> {
  return graphqlClient.query(query, variables, { 'token': token });
}

/** REST GET */
export async function restGet(path: string, token: string, accept?: string): Promise<RawResponse> {
  const headers = baseHeaders(token);
  if (accept !== undefined) {
    headers['Accept'] = accept;
  }
  const resp = await HttpClient.request({
    'method': http.RequestMethod.GET,
    'url': `${GITHUB_API}${path}`,
    'headers': headers
  });
  return toRawResponse(resp);
}

/** REST POST（/markdown 渲染等带 JSON body 请求） */
export async function restPost(path: string, token: string, body: string, accept?: string): Promise<RawResponse> {
  const headers = baseHeaders(token);
  if (accept !== undefined) {
    headers['Accept'] = accept;
  }
  const resp = await HttpClient.request({
    'method': http.RequestMethod.POST,
    'url': `${GITHUB_API}${path}`,
    'headers': headers,
    'body': body
  });
  return toRawResponse(resp);
}

/** REST PATCH（标记通知已读等） */
export async function restPatch(path: string, token: string): Promise<RawResponse> {
  const resp = await HttpClient.request({
    'method': http.RequestMethod.PATCH,
    'url': `${GITHUB_API}${path}`,
    'headers': baseHeaders(token)
  });
  return toRawResponse(resp);
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
