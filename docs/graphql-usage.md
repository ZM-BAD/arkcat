# GraphQL 使用规范

> 本文是 ArkCat GraphQL 层的唯一使用规范。分层：`graphql/` HAR 库（通用 GraphQL over HTTP 能力，
> 可独立复用）→ `services/GitHttpClient.ets`（GitHub 端点适配层）→ `services/*`（业务查询）→ 页面。
> 库源码：`graphql/src/main/ets/`（导出桶 `Index.ets`）。

## 1. 分层与职责边界

| 层 | 位置 | 职责 | 禁止 |
| --- | --- | --- | --- |
| 库层 | `graphql/` | 传输、超时、鉴权头、data 提取、errors 语义码询问机制（词汇由适配层注入）、分页原语、alias 构造、请求编排原语、JSON 安全访问 | UI/资源/i18n/任何后端错误词汇与业务知识 |
| 适配层 | `services/GitHttpClient.ets` | GitHub 端点常量、`graphql()`/`restGet`/`restPost`/`restPatch`、`friendlyError` 本地化 | 业务查询 |
| 服务层 | `services/*.ets` | 业务查询 document 定义与解析映射（纯函数下沉 models/） | 越层拼 HTTP |
| 页面层 | `pages/`、`components/` | 只调 service | 直接调用 http/库 |

`ApiError` 由库定义、适配层 re-export：业务侧统一 `import { ApiError } from '../services/GitHttpClient'`。

## 2. 请求通道

- **GraphQL 主通道**：服务层内 `graphql(query, variables, token)`；token 显式传参（多账号场景不持有会话态）。
- **REST 兜底**：`restGet/restPost/restPatch`，返回 `RawResponse{code, body, link?}`（Link 分页头已解出，大小写不敏感）。
- 页面/组件**禁止** `http.createHttp()`。白名单例外仅三个：`OAuthService`（token 端点）、
  `DownloadService`（下载流）、`AchievementsService`（外部 CDN）。
- 新增 Accept 媒体类型（raw/html/text-match 等）写在调用点常量，经 `restGet(path, token, accept)` 传入。

## 3. 错误语义（必读）

- **GraphQL 错误恒为 HTTP 200**：库协议中立、不内嵌后端错误词汇——语义码由适配层注入
  `mapGitHubErrorType`（表：`RATE_LIMITED→429`、`FORBIDDEN/INSUFFICIENT_SCOPE/ACCESS_DENIED→403`、
  `NOT_FOUND→404`、`UNPROCESSABLE/VALIDATION→422`、`UNAUTHORIZED→401`）；
  库按 `errors[].type` → `extensions.code` 顺序询问 mapper，未注入时 `ApiError.code`=原始状态。
- `ApiError.code`：HTTP 状态码；**0 = 网络层失败**。
- 用户可见文案一律 `friendlyError(uiContext, e)`（本地化），禁止裸 `e.message` 直出；
  页面按 code 分支（401 引导重登、403/429 限流、0 网络错误）。

## 4. 查询书写约定

- 查询 document **只定义在 service 层**，静态模板字符串常量优先；models/pages 层零定义。
- 动态值一律走 `variables`（含 cursor、login、owner/name）。
- 确需拼接 document 的场景（单请求多 alias 批量查询）**必须**用库原语：
  - `aliasField(alias, field, AliasArg[], inner)`——string 实参自动转义加引号、number 直插；
  - `aliasQueryDocument(opName, parts)` 包裹成完整 document（opName 传 `''` 为匿名 query）；
  - 裸内插、手写转义均禁止（含「输入可信」场景——转义是零成本兜底）。
- 字符串转义口径：`escapeGraphQLString`（`\`、`"`、换行/回车替换为空格）。

## 5. 分页（Relay cursor）

- 请求端：cursor 走 `variables['after']`（仅非空时设置）；**禁止**把 cursor 拼进 document。
- 响应端：`readConnectionPage(conn, mapItem, viaEdges?)` 提取 `{items, hasNextPage, endCursor}`
  （nodes/edges 两种连接形态；conn 为 null 返回空页不抛错）。
- 续拉：`fetchAllPages(fetchPage, maxPages=10)`——
  - **hasNextPage 判停**（末页 endCursor 仍非空，用游标判停会多打一次空页）；
  - 默认 10 页上限防极端长列表；首次以 `null` 游标调用（调用方自行落到首页游标/首页请求）；
  - 单页失败想降级截断：在 `fetchPage` 内 catch 并返回 `hasNextPage=false` 的空页。

## 6. 请求编排原语

| 原语 | 用途 | 替代的手写模式 |
| --- | --- | --- |
| `RequestSequencer` | 页面级竞态守卫（`begin()`/`isCurrent(seq)`） | `const mySeq = ++this.seq` 五连复制 |
| `withFallback(task, fallback)` | 装饰性请求软失败 | try/catch 返回默认值 |
| `runBounded(items, batch, task)` | 有界并发池（批间串行、批内并行） | 全量 `Promise.all` |

新代码一律用库原语；存量手写模式随批收敛。

## 7. 库边界与测试要求

- 库内**禁止**引入 UI、资源（`$r`）、i18n——`friendlyError` 留在适配层即是范例；保持库可独立开源
  （仅依赖 `@kit.NetworkKit`）。
- 库/服务层纯函数（构造器、映射、过滤）必须配宿主单测（`scripts/ut/unit.test.ts`，
  跑 `bash scripts/ut/run-local-tests.sh`）；`build-ut.mjs` 把裸包名 `graphql` 直接映射到库源码，
  宿主 UT 跑的是真库逻辑。
- HAR 构建会在模块根生成 `graphql/BuildProfile.ets`（已 gitignore），勿手工修改/入库。

## 8. 常见坑

- ArkTS 泛型 await 需显式标型：`const page: Page<T> = await fetchPage(cursor)`。
- ArkTS 无 any：响应解析走 `Json.str/num/bool/obj/arr/parse`（缺字段回退默认值），禁裸属性访问。
- `Button`/`TextInput` 等组件属性与自定义组件 @Param 命名避开基类保留名（`size`/`height` 等）。
