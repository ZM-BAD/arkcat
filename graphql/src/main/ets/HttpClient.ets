/**
 * 通用 HTTP 传输层（@kit.NetworkKit 封装）。
 *
 * 统一超时、UA、错误提取：非 2xx 抛 ApiError（附响应 body 的 message 字段便于排查），
 * 网络层失败抛 ApiError(0)。响应头以键值对返回，配 getHeader 做大小写不敏感读取。
 */
import { http } from '@kit.NetworkKit';
import { ApiError } from './ApiError';
import { Json } from './Json';

const DEFAULT_CONNECT_TIMEOUT = 15000;
const DEFAULT_READ_TIMEOUT = 20000;
const DEFAULT_USER_AGENT = 'ArkTsGraphQL/1.0.0';

export interface HttpResponse {
  code: number;
  body: string;
  headers: Record<string, string>;
}

export interface HttpRequestOptions {
  method: http.RequestMethod;
  url: string;
  headers?: Record<string, string>;
  body?: string;
  userAgent?: string;
  connectTimeout?: number;
  readTimeout?: number;
  /** 网络层失败（ApiError code 0）自动重试次数；默认 0。只重试未达服务端的瞬态失败，幂等请求才建议 >0 */
  retries?: number;
}

/** 瞬态重试退避：500ms 起步指数退避，上限 4s（attempt 从 0 计） */
export function retryDelayMs(attempt: number): number {
  const ms = 500 * Math.pow(2, attempt);
  return ms > 4000 ? 4000 : ms;
}

function sleep(ms: number): Promise<void> {
  return new Promise<void>((resolve: () => void) => {
    setTimeout((): void => resolve(), ms);
  });
}

/** Retry-After 头 → 秒数；缺失或非法返回 undefined */
function parseRetryAfter(headers: Record<string, string>): number | undefined {
  const v = getHeader(headers, 'retry-after');
  if (v === '' || !/^[0-9]+$/.test(v)) {
    return undefined;
  }
  return Number(v);
}

/** 大小写不敏感读取响应头（服务端可能返回小写或原样大小写的头名） */
export function getHeader(headers: Record<string, string>, name: string): string {
  const lower = name.toLowerCase();
  for (const key of Object.keys(headers)) {
    if (key.toLowerCase() === lower) {
      const v = headers[key];
      return typeof v === 'string' ? v : '';
    }
  }
  return '';
}

export class HttpClient {
  /** 发起请求；非 2xx 抛 ApiError(code)，网络层失败抛 ApiError(0)（配 retries 时对 code 0 指数退避重试） */
  static async request(opts: HttpRequestOptions): Promise<HttpResponse> {
    const maxRetry = opts.retries !== undefined && opts.retries > 0 ? opts.retries : 0;
    for (let attempt = 0; ; attempt++) {
      try {
        return await HttpClient.requestOnce(opts);
      } catch (e) {
        // 只重试网络层失败（code 0，未达服务端）；HTTP 语义错误一律不重试（防非幂等重复提交）
        if (e instanceof ApiError && e.code === 0 && attempt < maxRetry) {
          await sleep(retryDelayMs(attempt));
          continue;
        }
        if (e instanceof Error) {
          throw e;
        }
        throw new Error(`${e}`);
      }
    }
  }

  private static async requestOnce(opts: HttpRequestOptions): Promise<HttpResponse> {
    const req = http.createHttp();
    try {
      const headers: Record<string, string> = {};
      if (opts.headers !== undefined) {
        const keys = Object.keys(opts.headers);
        for (const k of keys) {
          headers[k] = opts.headers[k];
        }
      }
      headers['User-Agent'] = opts.userAgent !== undefined ? opts.userAgent : DEFAULT_USER_AGENT;
      const options: http.HttpRequestOptions = {
        method: opts.method,
        header: headers,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: opts.connectTimeout !== undefined ? opts.connectTimeout : DEFAULT_CONNECT_TIMEOUT,
        readTimeout: opts.readTimeout !== undefined ? opts.readTimeout : DEFAULT_READ_TIMEOUT
      };
      if (opts.body !== undefined) {
        options.extraData = opts.body;
      }
      const resp = await req.request(opts.url, options);
      const code = typeof resp.responseCode === 'number' ? resp.responseCode : 0;
      const text = typeof resp.result === 'string' ? resp.result : '';
      const respHeaders: Record<string, string> = {};
      if (resp.header !== undefined && resp.header !== null) {
        const raw = resp.header as Record<string, Object>;
        for (const key of Object.keys(raw)) {
          const v = raw[key];
          if (typeof v === 'string') {
            respHeaders[key] = v;
          }
        }
      }
      if (code < 200 || code >= 300) {
        // 拼入响应 body 的 message，便于 422/403 等业务失败排查
        let detail = '';
        const errBody = Json.parse(text);
        if (errBody !== null) {
          const m = Json.str(errBody, 'message');
          if (m !== '') {
            detail = ` ${m}`;
          }
        }
        throw new ApiError(code, `Request failed: ${opts.url} -> HTTP ${code}${detail.substring(0, 200)}`,
          parseRetryAfter(respHeaders));
      }
      return { code: code, body: text, headers: respHeaders };
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
}
