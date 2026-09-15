/**
 * GraphQL over HTTP 客户端（协议中立：不含任何后端的错误词汇/端点/业务知识）。
 *
 * POST endpoint，返回 data 节点；errors 非空时抛 ApiError。
 * GraphQL 错误恒为 HTTP 200：语义码由宿主注入的 errorTypeToCode 决定——
 * 库先按 errors[].type 询问、未命中（返回原状态 200）再按 extensions.code 询问一次
 * （两者是常见的错误码位置）；未注入 mapper 时保持原始状态，错误原文保留在 message。
 */
import { http } from '@kit.NetworkKit';
import { ApiError } from './ApiError';
import { HttpClient } from './HttpClient';
import { Json, JsonMap } from './Json';

/** 中性默认映射：不识别任何错误词汇，一律返回原始 HTTP 状态 */
function neutralErrorTypeToCode(type: string): number {
  return 200;
}

export interface GraphQLRequestOptions {
  /** Bearer 令牌（可选：匿名 introspection 等场景不传；与 config.tokenProvider 二选一） */
  token?: string;
  /** 额外请求头（覆盖默认值） */
  headers?: Record<string, string>;
  /** 网络层失败重试次数（默认 0；查询类幂等请求才建议开启） */
  retries?: number;
}

export interface GraphQLClientConfig {
  /** 默认 User-Agent（单次请求可经 options.headers 覆盖） */
  userAgent?: string;
  connectTimeout?: number;
  readTimeout?: number;
  /** 语义码映射（宿主注入后端错误词汇；缺省中性不映射，ApiError.code=原始状态） */
  errorTypeToCode?: (type: string) => number;
  /** 默认令牌提供者：options.token 未传时调用（多账号切换场景由宿主注入） */
  tokenProvider?: () => string;
}

export class GraphQLClient {
  private readonly endpoint: string;
  private readonly userAgent: string;
  private readonly connectTimeout: number;
  private readonly readTimeout: number;
  private readonly errorTypeToCode: (type: string) => number;
  private readonly tokenProvider?: () => string;

  constructor(endpoint: string, config?: GraphQLClientConfig) {
    this.endpoint = endpoint;
    this.userAgent = config?.userAgent !== undefined ? config.userAgent : 'ArkTsGraphQL/1.0.0';
    this.connectTimeout = config?.connectTimeout !== undefined ? config.connectTimeout : 15000;
    this.readTimeout = config?.readTimeout !== undefined ? config.readTimeout : 20000;
    this.errorTypeToCode = config?.errorTypeToCode !== undefined ? config.errorTypeToCode : neutralErrorTypeToCode;
    this.tokenProvider = config?.tokenProvider;
  }

  /** 发起 GraphQL 请求：返回 data 节点；errors 非空按映射抛 ApiError(语义码) */
  async query(query: string, variables: Record<string, Object> | null,
    options?: GraphQLRequestOptions): Promise<JsonMap> {
    const payload: Record<string, Object> = { 'query': query };
    if (variables !== null) {
      payload['variables'] = variables as Object;
    }
    const headers: Record<string, string> = {
      'Accept': 'application/json',
      'Content-Type': 'application/json'
    };
    const token = options !== undefined && options.token !== undefined
      ? options.token
      : (this.tokenProvider !== undefined ? this.tokenProvider() : '');
    if (token !== '') {
      headers['Authorization'] = `Bearer ${token}`;
    }
    if (options !== undefined && options.headers !== undefined) {
      const keys = Object.keys(options.headers);
      for (const k of keys) {
        headers[k] = options.headers[k];
      }
    }
    const resp = await HttpClient.request({
      method: http.RequestMethod.POST,
      url: this.endpoint,
      headers: headers,
      body: JSON.stringify(payload),
      userAgent: this.userAgent,
      connectTimeout: this.connectTimeout,
      readTimeout: this.readTimeout,
      retries: options !== undefined && options.retries !== undefined ? options.retries : 0
    });
    const root = Json.parse(resp.body);
    if (root === null) {
      throw new ApiError(resp.code, 'Failed to parse GraphQL response');
    }
    const errors = Json.arr(root, 'errors');
    if (errors.length > 0) {
      const first = errors[0] as JsonMap;
      // 先按顶层 type 询问 mapper，未命中再按 extensions.code 询问
      const type = Json.str(first, 'type');
      let semantic = this.errorTypeToCode(type);
      if (semantic === 200) {
        const ext = Json.obj(first, 'extensions');
        if (ext !== null) {
          semantic = this.errorTypeToCode(Json.str(ext, 'code'));
        }
      }
      throw new ApiError(semantic, `GraphQL error: ${Json.str(first, 'message')}`);
    }
    const data = Json.obj(root, 'data');
    if (data === null) {
      throw new ApiError(resp.code, 'GraphQL response missing data');
    }
    return data;
  }
}
