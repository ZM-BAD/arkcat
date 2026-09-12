# Spec 011: Code Viewer（代码文件查看页）

> BFS Level: 3
> 关联截图: GitHub 官方 App 代码文件查看页（用户提供 2026-09-01，…ate-tool-text.mjs，行号+高亮）
> 上游 Spec: 006（入口：Repo Detail → More → 文件行）/ 038（Files → 点击文件）
> 状态: implemented（2026-09-01，构建通过 / 模拟器冒烟 + 真实数据验证：内容+行号+高亮/Copy/设置联动）

---

## 一、页面/功能概述

代码文件查看页：展示文件内容（行号 + 文本 + 简单语法着色），头部为全自绘 App Bar：← 返回 + 文件名（截断）+ 分享/齿轮/更多三图标。齿轮进入 Code Options（Spec 033）——该页的开关/字号/主题即本页行为配置；多行文本大纲（行数上千时）支持滚动。Markdown 文件原则上渲染原始文本（渲染预览见边界）。

---

## 二、整体 UI 结构

1. 顶部 App Bar（自绘头，60 高，文件名截断）：← 返回 + 文件名（README.md）+ ⭮ 分享 + ⚙ 齿轮 + ⋮ 更多
2. 代码正文：行号列（灰右对齐，可关）+ 等宽字体代码 + 关键色着色（← 行号列（灰右对齐，可关）/ 等宽字体 + 关键色着色）
   - 示例行：41 const readCorpus = (name) => ...、42 JSON.parse(readFileSync(...))、43、44、45 const KIMI_VOCAB = "/tmp/..."、...
3. 加载中/错误重试走 StateView；二进制不支持为独立自绘占位

---

## 三、元素清单

| # | 位置 | 元素 | 功能 | 可行性 | GraphQL 接口 | 备注 |
| --- | ------ | ------ | ------ | -------- | ------------- | ------ |
| 1 | App Bar 左 | ← 返回 | 回退 | ✅ 纯 UI | — | 回 Files 列表 |
| 2 | App Bar 中 | 文件名 | 展示（basename，超长省略） | ✅ 纯 UI | — | — |
| 3 | App Bar 右 | ⭮ 分享 | 分享文件链接 | ✅ 纯 UI | — | 拉起系统分享面板分享 `blob/HEAD/{path}`（Spec 061）；复制全文在 ⋮ Copy contents |
| 4 | App Bar 右 | ⚙ 齿轮 | 打开 Code Options | ✅ 纯 UI | — | push `codeOptions`（Spec 033 设置页） |
| 5 | App Bar 右 | ⋮ 更多 | Copy contents / Copy link | ✅ 纯 UI | — | bindMenu；编辑/审查等不实现 |
| 6 | 正文 | 行号列 | 显示行号 | ✅ 纯 UI | — | 受 Code Options `code_line_numbers` 控制 |
| 7 | 正文 | 代码文本 | 展示 | ✅ | `repository.object(expression: "HEAD:path") { ... on Blob { text } }` | 等宽字体 |
| 8 | 正文 | 语法着色 | 简单关键字/字符串/注释/函数着色 | ⚠️ 客户端部分 | — | 无原生高亮：本地 tokenizer（见备注） |
| 9 | 行为 | Code Options 联动 | 暗色主题/字号/换行/重叠设置生效 | ✅ 纯 UI | — | preferences `arkcat_settings`：`code_dark_theme`/`code_font_size`/`code_wrap_lines`/`code_line_numbers` |
| 10 | 行为 | Markdown 预览 | 渲染预览 | ⚠️ | — | MVP 显示原始文本（渲染需三方库，见边界） |

可行性：8/10 可行（8 ✅ + 2 ⚠️）。

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
    }
  }
}

# expression 示例: "HEAD:README.md" / "HEAD:src/main.ets"
# 注意: GraphQL blob.text 对二进制返回 null / isBinary=true
```

---

## 五、边界 / 不可行项

| 项 | 原因 | ArkCat 处理方式 |
| ---- | ------ | ------------------- |
| 语法高亮 | ArkUI 无原生代码着色 | MVP 本地 tokenizer：注释 > 字符串 > 关键字 > 函数调用样式；按扩展名选用关键字集（js/ts/et/py/java/cs/go/rs/…） |
| Markdown 渲染 | ArkUI 无原生 MD 渲染组件 | 显示原始文本；点击复制/代码查看不受影响（后续评估三方组件或自研简化渲染） |
| 二进制/大文件 | `isBinary=true` / `isTruncated=true` | 二进制显示「Binary file not supported」占位；截断提示「File is too large」 |
| 行内评论/行选择 | 需 GraphQL reviewThreads 上下文 | 不实现（官方 App 亦需 PR 上下文） |
| 编辑 | 需 REST + SHA 乐观锁 | 不实现 |
| Blame / History | 需 REST Blame API | 不实现 |
| 长行水平滚动 | 嵌套滚动复杂度 | MVP 行不换行 + 溢出省略（wrapLines 关闭时）；横滑后续优化 |
| Markdown 渲染时行为 | — | md 文件同文本查看（彩色头部不特殊渲染） |

---

## 六、TDD 验收标准

- [x] 测试 1：038 Files → 点击文件进入本页；头部对齐截图（← 文件名 + ⭮⚙⋮）；文件名截断显示
- [x] 测试 2：内容显示 + 行号正确；Code Options 关闭行号开关后回本页行号隐藏
- [ ] 测试 3：字符串独立着色（提前规划中：当前为注释/关键字/函数三类，字符串仍用正文色；元素 8 已标 ⚠️）
- [x] 测试 4：⋮ 菜单 Copy contents 复制全文成功（剪贴板校验）；⚙ 齿轮进入 Code Options
- [x] 测试 5：构建 + 模拟器实测通过；grep 无中文字符串字面量；check-spec.sh 通过

---

## 七、备注

- 主题：Code Options 固定示例已有的明/暗两套配色（`LIGHT_BG #F6F8FA` / `DARK_BG #0D1117`、关键字红/紫、函数蓝/紫、注释灰）作为本页取色表，抽到共用 `utils/CodeTheme.ets`（Code Options 与本页同源，避免双处漂移）。
- 字号：`code_font_size`（12-20sp），用户设置即时生效。
- 下载/复制：剪贴板经 `pasteboard`（@kit.BasicServicesKit）写入 `MIMETYPE_TEXT_PLAIN`。
- 图标：分享 `oct_share_android_16`（`link_blue`）、齿轮 `oct_gear_16`（v19.33.0 新增归档）、更多 `oct_kebab_horizontal_16`（rotate 90 竖三点，`link_blue`）——顶栏图标口径见 Spec 062。
- 本项目为第三方客户端：GitHub 官方 SDK 未使用，纯 GraphQL/REST 公开数据；文件名以路由参数传递（owner\|name\|path）。
