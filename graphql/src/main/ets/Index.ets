/**
 * ArkTsGraphQL — HarmonyOS NEXT 原生 GraphQL 客户端库。
 *
 * 基于 @kit.NetworkKit 的 GraphQL over HTTP 封装：
 * - GraphQLClient：请求/data 提取/errors 语义映射（GraphQL 错误恒为 HTTP 200）
 * - HttpClient：通用 HTTP 传输（超时/UA/错误提取/响应头）
 * - Pagination：Relay cursor 分页原语（Page/readConnectionPage/fetchAllPages）
 * - AliasQuery：alias 批量查询构造（转义内插）
 * - RequestOps：竞态守卫/软失败/有界并发池
 * - Json/JsonMap：ArkTS 无 any 环境下的 JSON 安全访问
 */
export { Json, JsonMap } from './Json';
export { ApiError } from './ApiError';
export { HttpClient, HttpResponse, HttpRequestOptions, getHeader, retryDelayMs } from './HttpClient';
export { GraphQLClient, GraphQLClientConfig, GraphQLRequestOptions } from './GraphQLClient';
export { Page, readConnectionPage, fetchAllPages, DEFAULT_MAX_PAGES } from './Pagination';
export { escapeGraphQLString, aliasField, aliasQueryDocument, AliasArg } from './AliasQuery';
export { RequestSequencer, withFallback, runBounded } from './RequestOps';
export { RateLimitInfo, readRateLimit } from './RateLimit';
