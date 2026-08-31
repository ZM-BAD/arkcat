# Spec 011: Code Viewer（代码文件查看页）

> BFS Level: 3
> 关联截图: Repo Detail → 点击文件
> 上游 Spec: 006
> 状态: ✅ approved

---

## 一、页面/功能概述

代码文件查看页，展示文件内容（行号 + 文本）、支持复制/搜索/编辑/分享操作。Markdown 文件支持渲染预览。

---

## 二、整体 UI 结构

```text
┌─────────────────────────────────────┐
│  ←   README.md                ···    │
├─────────────────────────────────────┤
│  [ Jump to ]                        │  ← 快速跳转
├─────────────────────────────────────┤
│  1 │ # starraft                      │
│  2 │                                │
│  3 │ 鸿蒙 Next 原生 GitHub 客户端     │
│  4 │                                │
│  5 │ 基于 ArkUI 构建                │
│  6 │                                │
│  7 │ ## 特性                         │
│  8 │ - 纯血鸿蒙原生体验              │
│  ...                                │
├─────────────────────────────────────┤
│  📋 Copy  🔍 Search  📝 Edit  🔗 Share  ⋮ │
└─────────────────────────────────────┘
```

---

## 三、元素清单

| # | 位置 | 元素 | 功能 | 可行性 | GraphQL 接口 | 备注 |
|---|------|------|------|--------|-------------|------|
| 1 | App Bar 左 | ← 返回 | 回退 | ✅ 纯 UI | — | — |
| 2 | App Bar 中 | 文件名 | 展示 | ✅ | — | — |
| 3 | App Bar 右 | ··· 更多菜单 | 更多操作 | ⚠️ 客户端部分 | — | — |
| 4 | 跳转条 | Jump to | 跳转符号/章节 | ✅ 客户端纯 UI | — | — |
| 5 | 行号区 | 左侧行号 | 展示 | ✅ 客户端计数 | — | — |
| 6 | 代码区 | 文本内容 | 展示 | ✅ | `repository.object(expression: "HEAD:path") { ... on Blob { text } }` | — |
| 7 | 代码区 | 语法高亮 | 着色 | ⚠️ | — | ArkUI 无原生支持 |
| 8 | 底部栏 | 📋 Copy | 复制内容 | ✅ 纯 UI | — | — |
| 9 | 底部栏 | 🔍 Search | 搜索内容 | ✅ 客户端纯 UI | — | — |
| 10 | 底部栏 | 📝 Edit | 在线编辑 | ⚠️ | REST `PUT /repos/.../contents/{path}` | — |
| 11 | 底部栏 | 🔗 Share | 分享链接 | ✅ 纯 UI | — | — |
| 12 | 底部栏 | ⋮ 更多 | raw/blame/history | ⚠️ | REST 兜底 | — |

---

## 四、核心 GraphQL 片段

```graphql
query FileContent($owner: String!, $name: String!, $expression: String!) {
  repository(owner: $owner, name: $name) {
    object(expression: $expression) {
      ... on Blob {
        text
        isBinary
        isTruncated
        byteSize
      }
      ... on Tree {
        entries { name type extension }
      }
    }
  }
}

# 示例 expression:
# "HEAD:README.md"
# "HEAD:src/main.ets"
# "HEAD:src/"  （目录）
```

---

## 五、边界 / 不可行项

| 项 | 原因 | StarRaft 处理方式 |
|----|------|-------------------|
| Markdown 渲染 | ArkUI 无原生 MD 渲染 | 需引入第三方 MD 组件 |
| 语法高亮 | ArkUI 无原生代码着色 | MVP 用等宽字体 + 简单关键字匹配 |
| 二进制/图片 | `isBinary=true` | REST `raw_url` 下载展示 |
| 大文件 | `isTruncated=true` | REST `raw_url` 流式展示 |
| 文件编辑 | 需 REST + SHA 乐观锁 | 暂不实现 |
| Blame 视图 | 需 REST Blame API | 暂不实现 |
| History | 需 REST | 暂不实现 |

---

## 六、TDD 验收标准

- [ ] 文本文件内容能展示
- [ ] 行号正确显示
- [ ] 复制功能正常
- [ ] 搜索功能正常

---

## 七、备注

- 8/12 可行
- 核心功能（文本查看 + 行号 + 复制）100% 可实现
