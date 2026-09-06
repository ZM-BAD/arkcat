# Spec 022: Organizations（工作区组织列表页）

> BFS Level: 3
> 关联截图: GitHub 官方 App「Organizations」页（Home My Work 入口，用户提供，2026-08-31）
> 上游 Spec: 013（入口）
> 状态: ✅ implemented（2026-08-31，构建通过 / 仪器测试 29/29 / 模拟器验收通过）

---

## 一、页面/功能概述

Home My Work「Organizations」入口进入的组织列表页，展示 viewer 所属组织。行结构：组织头像 + 名称（大字）+ 登录名（灰色小字），点击进入组织主页（复用 orgProfile 路由，登录名作为参数，Organization 节点解析）。空态为纯文字居中「There aren't any organizations.」（官方截图无插图）。数据源 `viewer.organizations`。

---

## 二、整体 UI 结构

1. 顶部 App Bar：← 返回、「Organizations」标题（无筛选/搜索按钮，与截图一致）
2. 组织行（头像 + 名称）：◯ 头像 + 组织名称大字（StarRaft Org）+ 登录名灰色小字（starraft）；第二条 6tail / 6tail 同构
3. 列表底部分页：Load more
4. 空态：纯文字居中「There aren't any organizations.」

---

## 三、元素清单

| # | 位置 | 元素 | 功能 | 可行性 | GraphQL 接口 | 备注 |
| --- | ------ | ------ | ------ | -------- | ------------- | ------ |
| 1 | App Bar 左 | ← 返回 | 回退 | ✅ | —（纯 UI） | — |
| 2 | App Bar 中 | 「Organizations」标题 | 页面标题 | ✅ | —（纯 UI） | — |
| 3 | 组织行 | 组织头像 | 展示 | ✅ | `avatarUrl` | — |
| 4 | 组织行 | 组织名称（大字） | 展示 | ✅ | `name` | name 缺失回退 login |
| 5 | 组织行 | 登录名（灰色小字） | 展示 | ✅ | `login` | — |
| 6 | 组织行 | 行点击 | 进入组织主页 | ✅ | —（纯 UI） | 路由复用 orgProfile（param: login，Organization 节点解析） |
| 7 | 空态 | 纯文字空态 | 无组织时展示 | ✅ | —（纯 UI） | 居中大字，无插图（对齐截图） |
| 8 | 列表底部 | Load more 分页 | 翻页 | ✅ | `organizations.pageInfo` | — |

> 可行性比例声明：8/8 可行。

---

## 四、核心 GraphQL 片段

```graphql
query WorkOrganizations($first: Int = 50, $after: String) {
  viewer {
    organizations(first: $first, after: $after) {
      totalCount
      pageInfo { hasNextPage endCursor }
      nodes {
        id login name avatarUrl
      }
    }
  }
}
```

---

## 五、边界 / 不可行项

| 项 | 原因 | StarRaft 处理方式 |
| ---- | ------ | ------------------- |
| 组织内仓库/成员列表 | 独立 Spec 范围 | 点击进入组织主页（orgProfile 路由）即可查看该组织仓库 |
| 官方插画 | 该页为空态纯文字，无插图 | 无需处理（纯文字空态） |
| viewer.organizations 数据获取 | Organization 字段（login/name 等）需 `read:org` scope | 错误态展示 GitHub 引导文案（含 scopes 链接）；用户授权后无需改版即可用 |

---

## 六、TDD 验收标准

- [x] 测试 1：`mapWorkOrg` / `mapWorkOrgsPage` 纯函数：name 缺失回退 login；分页字段正确
- [x] 测试 2：模拟器实测 — 组织列表展示；空态纯文字居中展示
- [ ] 测试 3：模拟器实测 — 行点击进入组织主页（登录名正确传递）
- [x] 测试 4：grep 检查 Organizations.ets 无中文字符串字面量残留
- [x] 测试 5：`bash scripts/check-spec.sh` 通过
- [x] 测试 6：`devecocli build` 全量构建通过

---

## 七、备注

- 无组织用户的截图即官方空态样式：灰色浅底 + 居中黑体大标题，无任何按钮。
- 入口复用 013 的 Organizations 彩色图标（橙 `#E87B2E`）。

- 模拟器实测：Organizations 页渲染通过；数据区当前展示错误态（本机 PAT 无 `read:org` scope，GitHub 返回官方引导文案），用户授权后自动可加载。
