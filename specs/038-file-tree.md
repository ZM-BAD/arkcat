# Spec 038: Repo File Tree（仓库文件列表页）

> BFS Level: 3
> 关联截图: GitHub 官方 App「Files」页（用户提供 2026-09-01，仓库根目录全为文件夹）
> 上游 Spec: 006（入口：Repo Detail → 分支区卡「Code」行）
> 状态: implemented（2026-09-01，构建通过 / 模拟器冒烟 + 真实数据验证：列表/下钻/过滤/复制链路）

---

## 一、页面/功能概述

仓库文件树浏览页：列出当前目录的条目（文件夹/文件），点击文件夹下钻一级、点击文件进入 Spec 011 代码查看器。入口为 Repo Detail 分支区卡「Code」行。头部为全自绘 App Bar：← 返回 + 标题（根目录为「Files」，子目录为当前目录名）+ 搜索/分享/更多三个操作图标，完全对齐官方截图。

---

## 二、整体 UI 结构

1. 自绘 App Bar（60 高）：← 返回 + 标题 Files + 搜索（🔍）/ 分享（⭮）/ 更多（⋮）
2. 搜索过滤行：点 🔍 展开，本地过滤 TextInput
3. 文件/目录列表：
   - 目录行（蓝实心文件夹 + 名称）：.claude、.github、adapters、brand
   - 文件行（灰文件图标 + 名称）：README.md
   - ……
   - 加载中 / 错误重试 / 空目录（StateView 三态）

---

## 三、元素清单

| # | 位置 | 元素 | 功能 | 可行性 | GraphQL 接口 | 备注 |
| --- | ------ | ------ | ------ | -------- | ------------- | ------ |
| 1 | App Bar 左 | ← 返回 | 回上一级/上一目录 | ✅ 纯 UI | — | 下钻为 push 新路由实例（参数含 path），返回天然回上一目录 |
| 2 | App Bar 中 | 标题（Files/当前目录名） | 展示 | ✅ 纯 UI | — | 根目录固定「Files」，下钻后显示目录名 |
| 3 | App Bar 右 | 🔍 搜索 | 本地过滤条目 | ✅ 纯 UI | — | 展开过滤行，输入时按文件名匹配 |
| 4 | App Bar 右 | ⭮ 分享 | 复制仓库链接 | ⚠️ 客户端部分 | — | MVP 用剪贴板 + toast；系统分享面板后续 |
| 5 | App Bar 右 | ⋮ 更多 | 菜单（Copy link + Copy path） | ✅ 纯 UI | — | bindMenu 弹出 |
| 6 | 列表 | 目录行 | 下钻 | ✅ | `repository.object(expression: "HEAD:path") { ... on Tree { entries } }` | 蓝实心文件夹图标（file-directory-fill） |
| 7 | 列表 | 文件行 | 进入代码查看器 | ✅ | 同上（blob 分支见 Spec 011） | file 图标，点击 push codeViewer |
| 8 | 列表 | 加载/错误/空态 | 反馈 | ✅ 复用组件 | — | StateView 三态 |

可行性：7/8 可行（7 ✅ + 1 ⚠️）。

---

## 四、核心 GraphQL 片段

```graphql
query DirEntries($owner: String!, $name: String!, $expression: String!) {
  repository(owner: $owner, name: $name) {
    object(expression: $expression) {
      ... on Tree {
        entries { name type }
      }
    }
  }
}

# expression:
#   根目录  "HEAD:"
#   子目录  "HEAD:src/components"
```

> 说明：GraphQL `Tree.entries` 无分页参数（一次性返回全部）；GitHub 对单次树展开有
> 总量限制，超出时对象可能是 `Tree` 无 entries 或异常——降级见边界。

---

## 五、边界 / 不可行项

| 项 | 原因 | StarRaft 处理方式 |
| ---- | ------ | ------------------- |
| 超大目录（>500 条目） | GraphQL/REST 单次均有限制 | 展示已返回条目 + toast「Directory has N entries」（列表不截断）；不做懒加载（后续按 REST `/contents` 分页） |
| 符号链接目录 | GraphQL type 为 blob/tree 之外 | 按名称展示、点击给出提示 |
| 系统分享面板 | ShareKit 面板样式不可控 | 剪贴板复制链接 + toast（后续评估 ShareKit） |
| Open in browser | 浏览器跳转需 openLink 能力 | 本批不实现；菜单为 Copy link + Copy path |
| 空目录 | — | 显示 StateView 空态（Empty directory） |

---

## 六、TDD 验收标准

- [x] 测试 1：Repo Detail 分支区卡「Code」行点击进入本页；头部对齐截图（← Files + 🔍⭮⋮ 三图标）
- [x] 测试 2：目录行点击下钻、标题变为目录名；返回事件回上一目录；文件行点击进入 Spec 011 代码查看器
- [x] 测试 3：点 🔍 展开过滤行、输入文件名实时过滤（文件夹+文件）；再点关闭
- [x] 测试 4：复制仓库链接成功（剪贴板内容校验 + toast）
- [x] 测试 5：构建 + 模拟器实测通过；grep 无中文字符串字面量；check-spec.sh 通过

---

## 七、备注

- 目录行图标：官方 App 为蓝实心文件夹 → Octicons `file-directory-fill-16.svg`（v19.33.0 已归档 + media 副本），着色由 OctIcon.fillColor 统一（oct_ 媒体资源）。
- 下钻实现：push 新路由实例（`repoFiles` 参数 owner\|name\|path），返回按钮与系统手势均回上一级目录，与官方 App 导航一致。
- 符号链接目录（type 非 tree/blob）：按名称展示、点击给出提示。
- 文件类型图标 MVP 统一灰色 file 图标（官方 App 按文件类型着彩色图标，属视觉差异，后续 Spec 024 体系扩展时再逐类型映射）。
