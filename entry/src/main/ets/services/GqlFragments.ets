/**
 * 跨服务共享的 GraphQL 查询片段常量（TS 级插值去重，非服务端 named fragment——
 * 每条请求是独立 document，片段以 `${常量}` 内插进各查询模板）。
 * 只收单行精确形态；多行/带字段的变体不强行归并。
 */

/** Relay 连接分页信息（27 处查询共用；判停用 hasNextPage，末页 endCursor 仍非空） */
export const FRAG_PAGE_INFO = 'pageInfo { hasNextPage endCursor }';

/** 当前登录者 login（viewer 身份探测） */
export const FRAG_VIEWER_LOGIN = 'viewer { login }';
