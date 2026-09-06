# Spec 033: 代码查看选项页（Settings → Code Options）

> BFS Level: 4
> 关联截图: GitHub 官方 App Code Options 设置页（Android 截图，用户提供 2026-09-01）
> 上游 Spec: 014（Settings）
> 状态: implemented（2026-09-01，构建通过 / 模拟器冒烟 + 持久化验证通过）

---

## 一、页面/功能概述

Settings 页「Code Options」行点击进入的代码查看选项二级页。含 5 组开关 + 1 个条件显示的字号滑杆 + 固定示例 Preview 区块。所有选项 preferences 持久化，为后续代码查看器（Spec 010/011）提供行为配置。**Always use dark theme 仅控制代码查看器自身明暗，与 App 三态暗黑模式（Spec 026）解耦。**

---

## 二、整体 UI 结构

```text
┌─────────────────────────────────────┐
│ ←  Code Options                     │
├─────────────────────────────────────┤
│ Scrollable File Path            [●] │
│ Show line numbers               [●] │
│ Always use dark theme           [ ] │
│ Override system font size       [●] │
│ A ─────◉─────── A                    │
│ Wrap lines                      [●] │
├─ Preview ───────────────────────────┤
│ ▾ n/code-scanning/new/README.md ▢ ⋯ │
│ 1 def fibonacci(n)                   │
│ 2   // A long comment demonstrating │
│       the effects of the line       │
│   ·  wrapping option.               │
│ 3   return n if (0..1).include? n   │
│ 4   (fibonacci(n-1) + fibonacci(n-2))│
│ 5 end                               │
└─────────────────────────────────────┘
```

---

## 三、元素清单

| # | 位置 | 元素 | 功能 | 可行性 | GraphQL 接口 | 备注 |
| --- | ------ | ------ | ------ | -------- | ------------- | ------ |
| 1 | App Bar | ← 返回 + Code Options 标题 | 导航 | ✅ | —（纯 UI） | 自绘头部，hideTitleBar |
| 2 | 开关区 | Scrollable File Path（默认开） | 本地持久化 | ✅ | — | preferences |
| 3 | 开关区 | Show line numbers（默认开） | 本地持久化 | ✅ | — | — |
| 4 | 开关区 | Always use dark theme（默认关） | 本地持久化 | ✅ | — | 仅代码查看器主题 |
| 5 | 开关区 | Override system font size（默认开） | 本地持久化 | ✅ | — | 控制 6 的显示 |
| 6 | 开关区 | 字号滑杆 A↔A（12–20 fp，默认 16） | 本地持久化 | ✅ | — | 仅 5 开启时显示 |
| 7 | 开关区 | Wrap lines（默认开） | 本地持久化 | ✅ | — | — |
| 8 | Preview | 区块标题 | 展示 | ✅ | —（纯 UI） | — |
| 9 | Preview | 路径行（▾ + 路径 + ▢ + ⋯） | 展示 | ✅ | —（纯 UI） | 固定示例路径 |
| 10 | Preview | 代码预览（行号 + 语法着色 + 换行效果） | 展示 | ✅ | —（纯 UI） | 明暗主题跟随 4 |

> 可行性比例声明：10/10 可行。

---

## 四、核心接口

无 GraphQL 接口——纯本地偏好设置 + 固定示例渲染，数据经 `preferences`（`starraft_settings`）持久化，键前缀 `code_`：

```text
code_scrollable_path / code_line_numbers / code_dark_theme /
code_override_font / code_wrap_lines（boolean，默认除 dark_theme 外均 true）
code_font_size（number，fp，默认 16，范围 12–20）
```

语法着色不引三方库：预览为固定 5 行示例，按内置配色表渲染 `TextSpan`（关键字红、函数蓝、注释灰、数字蓝、标识符正文色）。

---

## 五、边界 / 不可行项

| 项 | 原因 | StarRaft 处理方式 |
| ---- | ------ | ------------------- |
| 真实文件预览 | Spec 010/011 代码查看器未实现 | 固定示例（README.md + fibonacci 片段） |
| 路径行 ▢ / ⋯ 按钮 | 语义属代码查看器（重跑/更多） | 点击提示后续 |
| 真实语法高亮引擎 | 不引三方库 | 内置固定示例配色表 |
| 滑杆随 Override 关闭隐藏 | — | 条件渲染（图片 2 仅开启时显示） |

---

## 六、TDD 验收标准

- [ ] 测试 1：默认值正确——Scrollable Path / Line numbers / Override font / Wrap 开，Dark theme 关；字号 16
- [ ] 测试 2：字号滑杆仅 Override system font size 开启时可见；拖动后代码预览字号跟随并持久化
- [ ] 测试 3：Wrap lines 关 → 注释行单行省略；开 → 按截图两行换行展示；行号随实际行数
- [ ] 测试 4：Always use dark theme 切换 → 代码预览深浅两套配色切换；App 主题（Spec 026）不影响代码区
- [ ] 测试 5：重启重进页面状态保持；grep 页面无中文字符串字面量；check-spec.sh 通过

---

## 七、备注

- 预览代码为 GitHub 截图同款 Ruby 风格片段（`def fibonacci(n)` … `end`），路径 `n/code-scanning/new/README.md` 为固定文案（示例数据，非 UI 文案）。
- 两套代码配色参考 GitHub 官方：浅色（关键字 `#CF222E`/函数 `#0550AE`/注释 `#6E7781`）、深色（`#FF7B72`/`#D2A8FF`/`#8B949E`），代码区背景 `#F6F8FA` / `#0D1117`。
- 二级页头部沿用已验证方案：`NavDestination.hideTitleBar(true)` + 不设 `.title()` + 页内自绘返回/标题，避免双标题双返回。
- i18n：新增约 10 key，base（英）与 zh_CN（简中）成对补齐。
