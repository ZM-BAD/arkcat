/**
 * API 调用失败异常。
 *
 * code 语义：HTTP 状态码；0 表示网络层失败（未拿到响应）。
 * GraphQL 错误恒为 HTTP 200，client 层会按 errors[].type 映射出语义码再抛出本异常。
 */
export class ApiError extends Error {
  readonly code: number;
  /** 服务端 Retry-After 头（秒）；未返回时 undefined */
  readonly retryAfter?: number;

  constructor(code: number, message: string, retryAfter?: number) {
    super(message);
    this.code = code;
    this.retryAfter = retryAfter;
  }
}
