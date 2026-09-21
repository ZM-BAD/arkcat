# Spec 075: New fork（Fork 仓库弹层）

> BFS Level: 2
> 关联截图: 官方 App 2026-09-22 截图 1 张（hypit-ai/hypit 的 New fork 页）
> 上游 Spec: 006（仓库详情页 fork 圆钮）
> 状态: implemented（2026-09-22 状态回写：用户真机走查验收通过——弹层交互 / Learn more 拉起系统浏览器 / fork 成功落库）

---

## 一、页面/功能概述

仓库详情页「操作区 fork 圆钮」不再直接提交 fork，改为先弹出官方同构的 **New fork 弹层**（自底部弹出、近全屏、抓取条自绘）：顶栏 ✕ + 两行标题（`owner/name` · New fork）+ CREATE；内容区三段——Repository name（可改，默认=上游名，N/100 计数）、Repository description（上游描述只读展示）、Additional settings（`Copy the <默认分支> branch only` 开关，默认开）。点 CREATE 走 REST `POST /repos/{owner}/{repo}/forks` 真正创建，成功关弹层并 toast。

GraphQL Mutation 类型无 fork 字段（见 006 §五），故本页写入通道为 REST v3；分支名取仓库真实默认分支，不写死 main/master。

---

## 二、整体 UI 结构

1. 顶栏：✕（关弹层）+ 两行标题（上行 `owner/name` 灰字、下行 New fork 粗体）+ 右侧 CREATE 蓝字
2. 副标题行：You are creating a fork in your personal account
3. 分隔线
4. Repository name 区：灰色标签（Repository name (required)）+ 无边框输入框（默认=上游仓库名）+ 说明文案 + 「N / 100 characters」计数 + 空名行内错误（有错时）
5. 分隔线
6. Repository description 区：灰色标签 + 上游描述（次级色多行只读；上游无描述则整区隐藏）
7. 分隔线
8. Additional settings 区：灰色标签 + 行「Copy the `默认分支` branch only」+ Switch（默认开，行主体与 Switch 兄弟拆分防冒泡）
9. 开关说明：Contribute back to `{owner}/{repo}` by adding your own branch. + Learn more（蓝字，**拉起系统浏览器**打开 GitHub 分支管理文档，不在应用内打开）
10. 提交失败：名称区下方行内 danger 文案（`Fork 失败：<友好原因>`），弹层保持打开

---

## 三、元素清单

可行性：9/10 可行（1 项降级见 §五）

| # | 位置 | 元素 | 功能 | 可行性 | 接口 | 备注 |
| --- | ------ | ------ | ------ | -------- | ------ | ------ |
| 1 | 详情页操作区 | fork 圆钮 | 打开 New fork 弹层（不再直接 fork） | ✅ | — | 本人仓库仍置灰 toast（006 元素 6 口径不变） |
| 2 | 弹层顶栏 | ✕ + 两行标题 + CREATE | ✕ 关弹层；CREATE 提交 | ✅ | — | 两行头部形态复用建仓弹层（070） |
| 3 | 弹层副标题 | 归属说明行 | 说明 fork 落到个人账号 | ✅ | — | 组织 fork 见 §五 |
| 4 | 名称区 | 标签 + 输入框 + 说明 + N/100 计数 | 自定义 fork 名（默认=上游名） | ✅ | — | `maxLength`=REPO_NAME_MAX(100) |
| 5 | 名称区 | 空名行内错误 | 拦截空名提交 | ✅ | — | 同 070：CREATE 恒可点，空名走行内 danger 不提交 |
| 6 | 描述区 | 标签 + 上游描述（只读） | 展示将继承的描述 | ⚠️ | REST fork 无 description 参数 | 值继承上游，不可编辑 |
| 7 | 设置区 | `Copy the <默认分支> branch only` + Switch | 仅复制默认分支 | ✅ | `default_branch_only` | 分支名=详情查询 `defaultBranchRef.name` |
| 8 | 设置区 | 贡献说明 + Learn more | 打开 GitHub 分支管理文档 | ✅ | — | 目标页 2026-09-22 用户指定；**拉起系统浏览器**（viewData want），不走应用内浏览器 |
| 9 | 顶栏 CREATE | 提交 fork | 创建复刻 | ✅ | REST `POST /repos/{owner}/{repo}/forks` | 成功关弹层 + toast；失败行内文案 |
| 10 | 弹层 | 提交防重入 | 连点不重复提交 | ✅ | — | creating 门闩（弹层关闭即销毁重置） |

---

## 四、核心 GraphQL 片段

本页不新增 GraphQL 查询：标题、默认名、描述、默认分支全部取自仓库详情查询（006 §四）的 `name` / `description` / `defaultBranchRef { name }`，由详情页随弹层参数传入，零额外请求。

写入为 REST v3（GraphQL Mutation 类型无 fork 字段，见 006 §五）：

```http
POST /repos/{owner}/{repo}/forks
body: { "name": "<fork 名>", "default_branch_only": true | false }

→ 202 Accepted 即成功；非 2xx 经 ApiError 上抛，页面 friendlyError 出文案
```

---

## 五、边界 / 不可行项

| 项 | 原因 | ArkCat 处理方式 |
| ---- | ------ | ------------------- |
| 组织 fork | fork API 的 organization 参数需先有可选组织列表 | 副标题固定「in your personal account」，本期不做组织选择 |
| 描述不可编辑 | REST fork 无 description 参数（建库后需另发 PATCH） | 只读展示上游描述（官方截图该字段为次级色且无计数，同只读形态） |
| 名称非法字符 | 与官方 422 口径未逐字对齐 | 沿用 070：仅拦空名/超长，其余服务端 422 经 friendlyError 出文案 |
| 创建后动线 | 官方是否跳转新 fork 未核实 | 关弹层 + toast「Fork 已创建」（沿用 006 既有口径） |

---

## 六、TDD 验收标准

- [x] 详情页点 fork 圆钮弹出 New fork 弹层（本人仓库仍置灰 toast）
- [x] 名称默认=上游仓库名，计数随输入变化，空名提交出行内错误且不提交
- [x] 默认分支标签显示仓库真实默认分支（main / master / 其他随仓库）
- [x] CREATE 成功：关弹层 + toast「Fork 已创建」，账号下出现该 fork
- [x] CREATE 失败：行内 danger 文案（friendlyError 原因），弹层不关闭（走查未构造 4xx 场景，路径为全库 friendlyError 口径）
- [x] `devecocli build` 通过；真机走查验收通过（2026-09-22，用户）

---

## 七、备注

- 2026-09-22：本页是 fork 写入通道修复（006 §七）之后的官方流程对齐——原实现点 fork 直接提交，官方为「先出 New fork 页，再点 CREATE」。
- 默认分支名随仓库检测（有 main 用 main，无 main 用 master 或其他默认分支），禁止写死。
- 2026-09-22：Learn more 打开方式与目标页按用户指定定案——**拉起系统浏览器**（`viewData` want，与个人页主页链接行 / MarkdownView 外链同口径，非应用内浏览器），目标页=GitHub 分支管理文档 `docs.github.com/en/pull-requests/how-tos/commit-changes/managing-branches-within-your-repository`。
- 弹层骨架复用建仓弹层（070）与仓库详情单 bindSheet + sheetKind 分派（045/006）；弹层内容关闭即销毁，重开回到默认值。
