# Spec 023: Starred Repositories（工作区星标仓库页）

> BFS Level: 3
> 关联截图: GitHub 官方 App「Starred Repositories」页（Home My Work 入口，用户提供，2026-08-31）
> 上游 Spec: 013（入口）
> 状态: ✅ implemented（2026-08-31，构建通过 / 仪器测试 29/29 / 模拟器验收通过）

---

## 一、页面/功能概述

Home My Work「Starred」入口进入的星标仓库列表页。顶部 App Bar 展示副标题（viewer login）+ 主标题「Starred Repositories」；下方「My lists」区（+ NEW 进创建页；已建列表行进列表详情）与「Create your first list」空态卡（CREATE A LIST 进创建页）；再下方「Starred」分组的星标仓库列表（owner 头像 + 加粗仓库名 + 断行描述 + ★ 星数（紧凑格式 50.5k/118.9k）+ 主语言点）。数据源 `viewer.starredRepositories`。

---

## 二、整体 UI 结构

1. 顶部 App Bar：← 返回 + 副标题灰色小字（ZM-BAD）+ 主标题「Starred Repositories」+ 操作（搜索 🔍 + 更多菜单 ⋯）
2. 列表入口：☰ My lists + 「+ NEW」（进创建页）
3. 空态卡（无 lists 时）：标题「Create your first list」+ 副文案「Lists make it easier ...」+ 「CREATE A LIST」按钮
4. 分组头：☆ Starred
5. 仓库行一：◯ 头像 + 仓库名（chen08209）+ 描述（FIClash / A multi-platform proxy client…）+ 星数（★ 50.5k）+ 主语言（● Dart）+ 行尾 ⋯（打开列表成员 sheet）
6. 仓库行二：◯ 头像 + 仓库名（harry0703）+ 描述（MoneyPrinterTurbo / 利用 AI 大模型…（中文描述原样展示））+ 星数（★ 118.9k）+ 主语言（● Python）+ 行尾 ⋯（打开列表成员 sheet）
7. 列表底部分页：Load more

---

## 三、元素清单

| # | 位置 | 元素 | 功能 | 可行性 | GraphQL 接口 | 备注 |
| --- | ------ | ------ | ------ | -------- | ------------- | ------ |
| 1 | App Bar 左 | ← 返回 | 回退 | ✅ | —（纯 UI） | — |
| 2 | App Bar | 副标题（viewer login）+ 主标题「Starred Repositories」 | 标题展示 | ✅ | `viewer.login` | 双行字号 |
| 3 | App Bar 右 | 🔍 就地搜索 | 页内 TextInput 客户端过滤 | ✅ | —（纯 UI） | 按仓库名过滤已加载列表 |
| 4 | App Bar 右 | ⋯ 更多 | 刷新列表 | ✅ | —（纯 UI） | 菜单含刷新 |
| 5 | My lists 行 | ☰ My lists + + NEW | 列表入口（进创建页） | ✅ | `createUserList / updateUserList / deleteUserList / updateUserListsForItem` | My lists 完整实现：+NEW/CREATE A LIST 进创建页（创建/编辑/删除/重命名）、列表行进 ListDetail、行内 ⋯ 打开成员切换 sheet（乐观更新 updateUserListsForItem）、Suggestions 快捷创建 |
| 6 | My lists 区 | Create your first list 空态卡（标题+副文案+按钮） | 空态展示 | ✅ | —（纯 UI） | CREATE A LIST 进创建页 |
| 7 | Starred 区 | ☆ Starred 分组头 | 分组标题 | ✅ | —（纯 UI） | — |
| 8 | 仓库行 | owner 头像 + login | 展示 | ✅ | `owner { login avatarUrl }` | — |
| 9 | 仓库行 | 仓库名（加粗）+ 描述（断行） | 展示 | ✅ | `name / description` | 描述原样展示（含多语言） |
| 10 | 仓库行 | ★ 星数（紧凑格式）+ 主语言点/名称 | 展示 | ✅ | `stargazerCount / primaryLanguage { name color }` | 星数 ≥1000 显示 xx.xk |
| 11 | 仓库行 | 行点击 | 进入仓库详情 | ✅ | —（纯 UI） | 路由复用 repoDetail；行尾 ⋯ 打开列表成员 sheet（乐观更新 updateUserListsForItem） |
| 12 | 列表底部 | Load more 分页 | 翻页 | ✅ | `starredRepositories.pageInfo` | — |

> 可行性比例声明：12/12 可行。

---

## 四、核心 GraphQL 片段

```graphql
query WorkStarred($first: Int = 30, $after: String) {
  viewer {
    login
    starredRepositories(first: $first, after: $after) {
      totalCount
      pageInfo { hasNextPage endCursor }
      nodes {
        id name nameWithOwner description stargazerCount
        owner { login avatarUrl }
        primaryLanguage { name color }
      }
    }
  }
}
```

---

## 五、边界 / 不可行项

| 项 | 原因 | ArkCat 处理方式 |
| ---- | ------ | ------------------- |
| My lists 数据与创建流程 | GitHub Lists 功能（API 可用性待验证，截图为空态） | 已实现：+NEW / CREATE A LIST 进创建页（createUserList / updateUserList / deleteUserList 覆盖创建/编辑/删除/重命名）；列表行进 ListDetail；行内 ⋯ 打开成员切换 sheet |
| 星数超 100 万的显示 | 截图仅展示 k 级别 | `compactCount`：≥1000 显示 xx.xk（一位小数，整数值去小数位），≥1000000 显示 x.x m 暂不实现（亿级无需，备注） |
| 行内 ⋯ | 截图可见 ⋯ 按钮 | ⋯ 打开列表成员 sheet（添加/移除列表，乐观更新 updateUserListsForItem） |

---

## 六、TDD 验收标准

- [x] 测试 1：`compactCount` 纯函数：50500→"50.5k"、118900→"118.9k"、1000→"1k"、999→"999"
- [x] 测试 2：`mapStarredRepo` / `mapWorkStarredPage` 纯函数：语言缺失回退空串；分页字段正确
- [x] 测试 3：模拟器实测 — Starred 分组行结构（头像/名/描述/星数/语言）与截图一致
- [x] 测试 4：模拟器实测 — My lists 空态卡展示；+ NEW 与 CREATE A LIST 进创建页（创建/编辑/删除/重命名）
- [x] 测试 5：grep 检查 StarredRepositories.ets 无中文字符串字面量残留
- [x] 测试 6：`bash scripts/check-spec.sh` 通过
- [x] 测试 7：`devecocli build` 全量构建通过

---

## 七、备注

- 仓库行用 `name` 而非 nameWithOwner（owner 已在左侧单独展示，与截图一致）。
- 主语言缺失（无语言仓库）时隐藏语言点与名称，与官方一致。
- 入口复用 013 的 Starred 彩色图标（黄 `#E3B341`）。
- 描述文本原样展示（用户截图中有中文描述，不翻译）。
- 他人视角（035 重构后 Profile Starred 入口带 login，官方实测两形态）：本人页保持 My lists 区（+ NEW/列表行/空态卡）+ 行内 ⋯ 不变；他人页显示「Lists」区（只读：无 + NEW/空态卡，数据 `user(login).lists`，服务端仅返回公开列表；行进只读列表详情，详情页隐藏 Edit/Delete、归属人取 `node.user`）；对方无 lists 时 Lists 区与 Starred 分组头均不显示，直接进仓库列表。

- 模拟器实测：Starred 真实数据渲染（tokio-rs/tokio ★33k Rust 等）+ My lists 空态卡展示通过。
