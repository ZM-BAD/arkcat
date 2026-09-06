# Spec 029: 仓库 Releases 页（Repo Detail → Releases）

> BFS Level: 3
> 关联截图: GitHub 官方 App「Releases」页（DAG-chat，深色，用户提供 2026-08-31）
> 上游 Spec: 006（入口）
> 状态: ✅ implemented（2026-08-31，构建通过 / 仪器测试 30/30 / 模拟器双主题验收通过）

---

## 一、页面/功能概述

仓库 Releases 列表：顶部为最新 Release 头卡（tag 名 + Latest release 徽章 + 发布者/日期 + What's Changed 正文预览 + View release details 链接），下方 All Releases 版本清单（tag + 相对时间 + Latest 徽章）。数据源 `repository.releases`。

---

## 二、整体 UI 结构

1. 顶部 App Bar：← 返回 + 副标题（DAG-chat）+ 主标题「Releases」
2. 最新 Release 头卡：版本号（1.3.2）+「Latest release」徽章
3. 头卡发布信息：🀫 头像 + 发布者（ZM-BAD）+ 「released this June 30」
4. 头卡正文：「What's Changed」标题 + 内容条目（LLM / • DeepSeek V4…，截断 4 行）+「View release details」链接
5. 版本清单分组头：「All Releases」
6. 版本行：1.3.2 · 相对时间 2mo · 「Latest release」徽章；1.3.1 · 4mo
7. 列表底部分页：Load more

## 三、元素清单

| # | 位置 | 元素 | 功能 | 可行性 | GraphQL 接口 | 备注 |
| --- | ------ | ------ | ------ | -------- | ------------- | ------ |
| 1 | App Bar | ← 返回 + 副标题 owner + Releases | 导航 | ✅ | —（纯 UI） | — |
| 2 | 头卡 | tag + Latest release 徽章 | 展示 | ✅ | `isLatest/tagName` | 仅最近一条 |
| 3 | 头卡 | 发布者 + 日期「released this M/D」 | 展示 | ✅ | `author/createdAt` | 月名+日格式 |
| 4 | 头卡 | What's Changed 正文（截断） | 展示 | ✅ | `body/description` | 4 行省略 |
| 5 | 头卡 | View release details | 跳转 | ✅ | —（纯 UI） | 站内跳转详情页（047） |
| 6 | 列表 | All Releases（tag + 时间 + Latest 徽章） | 展示 | ✅ | `releases{ nodes }` | — |
| 7 | 列表 | Load more 分页 | 翻页 | ✅ | `releases.pageInfo` | — |

> 可行性比例声明：7/7 可行。

---

## 四、核心 GraphQL 片段

```graphql
query RepoReleases($owner: String!, $name: String!, $first: Int = 30, $after: String) {
  repository(owner: $owner, name: $name) {
    releases(first: $first, after: $after, orderBy: { field: CREATED_AT, direction: DESC }) {
      totalCount
      pageInfo { hasNextPage endCursor }
      nodes { id tagName name isLatest createdAt description body author { login avatarUrl } }
    }
  }
}
```

---

## 五、边界 / 不可行项

| 项 | 原因 | StarRaft 处理方式 |
| ---- | ------ | ------------------- |
| 资产下载/查看跨渠道 | 外部链接 | View release details / tag 点击提示后续 |
| What's Changed 富文本 | Markdown 渲染后续 | 纯文本截断 |

---

## 六、TDD 验收标准

- [x] 测试 1：`formatReleasedThis(iso)` 纯函数：英文「released this June 30」/中文日期格式正确（i18n key 拼接）
- [x] 测试 2：`mapRepoReleasesPage` 纯函数：最近一条 isLatest 标记/分页正确
- [x] 测试 3：构建 + 模拟器实测：深色头卡/清单与截图对齐
- [x] 测试 4：grep 页面无中文字符串字面量；check-spec.sh 通过

---

## 七、备注

- i18n 新增：`releases_latest`、`releases_all`、`releases_released_this`（%1$s 位）、`releases_view_details`；zh：最新版本/全部版本/于 %1$s 发布/查看发布详情。
