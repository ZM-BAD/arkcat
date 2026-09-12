# Spec 064: Open Source Libraries 页

> BFS Level: 3
> 关联截图: 官方 GitHub for Android「Open Source Libraries」页（引言 + 链接清单 + 逐库许可全文）
> 上游 Spec: 014（Settings）
> 状态: implemented

---

## 一、页面/功能概述

Settings → Open Source Libraries 进入的静态开源披露页（license notice）。复刻官方 App 同名页三段式结构：引言 → 项目链接清单 → 逐库许可全文。目的：满足 MIT 等许可「随分发物保留版权与许可声明」的义务，同时作为华为上架的开源组件披露。

**范围裁定**：只列「实际打进 HAP 分发物」的开源内容——Octicons（图标 SVG）与 Primer Design Primitives（设计令牌色值/尺寸数据）。系统运行时（ArkUI/ArkTS）、纯构建期工具（Hypium/esbuild/pre-commit 系）与未打包素材不列。X logo 为品牌资产非开源软件，不进清单、不标注（用户 2026-09-12 裁定：常规品牌引用，官方 App 亦无此类标注）。

---

## 二、整体 UI 结构

1. 顶部：自绘 App Bar（返回 + 大标题；标题走 i18n——英文 "Open Source Libraries"、中文「开源库」）
2. 内容区（单列滚动，纯英文正文，法律文本不翻译）：
   - 引言行："ArkCat is built using open source software:"
   - 圆点链接清单：项目名蓝色下划线链接，点击拉起系统浏览器打开源仓库
   - 分隔线之后逐库区块：粗体库名 + 等宽字体许可全文（license 名 / 版权行 / 授权正文）

---

## 三、元素清单

| # | 位置 | 元素 | 功能 | 可行性 | GraphQL 接口 | 备注 |
| --- | ------ | ------ | ------ | -------- | ------------- | ------ |
| 1 | App Bar | 返回按钮 | pop 路由 | ✅ | 无 | 自绘，hideTitleBar(true) |
| 2 | App Bar | 标题（i18n） | 展示页名 | ✅ | 无 | base=Open Source Libraries / zh_CN=开源库 |
| 3 | 内容区 | 引言行 | 说明页用途 | ✅ | 无 | i18n（英文句式 + 中文对应翻译） |
| 4 | 内容区 | Octicons 链接条目 | 系统浏览器开 github.com/primer/octicons | ✅ | 无 | v19.33.0，MIT，启用 85 个 SVG |
| 5 | 内容区 | Primer Primitives 链接条目 | 系统浏览器开 github.com/primer/primitives | ✅ | 无 | MIT，设计令牌数据源 |
| 6 | 内容区 | 逐库 MIT 许可全文 | 合规披露 | ✅ | 无 | 与 assets/octicons/LICENSE 文本一致 |

> 可行性图例：✅ 可直接实现 ｜ ⚠️ 部分可行/降级 ｜ ❌ 不可实现

---

## 四、核心 GraphQL 片段

无——纯静态页面，零网络请求。

---

## 五、边界 / 不可行项

1. 链接点击拉起系统浏览器失败（无可处理 scheme 的应用）：静默，不阻塞页面。
2. 许可正文为法律文本，不做 i18n、不换行改写；仅随系统字号缩放。
3. 未来新增打包的第三方素材时，须同步在本页与 assets/ 归档补条目（见六）。

---

## 六、TDD 验收标准

- [x] 页面数据包含 Octicons 与 Primer Primitives 两条，name/url/license 与本 Spec 一致（OpenSourceLibraries 数据模型单测）
- [x] Octicons 许可正文与 `assets/octicons/LICENSE` 逐字一致（单测读文件比对）
- [x] Settings 的 Open Source 行点击 push `openSourceLibraries` 路由（人工走查）
- [x] 条目点击拉起系统浏览器打开对应仓库（人工走查）
- [x] 中文环境 App Bar 显示「开源库」，正文仍为英文（人工走查）

---

## 七、备注

1. 官方页对 Apache-2.0 库只放摘要段；本项目无 Apache 分发物，全部条目统一 MIT 全文，无需摘要逻辑。
2. 页面内容纯英文为用户 2026-09-12 拍板（法律文本惯例）；App Bar 与引言行走 i18n。
3. OpenHarmony 不列：HAP 未打包其任何代码，运行时由系统提供（用户 2026-09-12 裁定）。
