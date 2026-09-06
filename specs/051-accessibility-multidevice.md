# Spec 051: 无障碍与多设备适配（横向规范）

> BFS Level: 4（横向规范）
> 关联截图: 官方 2026 每版本大量 Dynamic Type / VoiceOver / 对比度修复；iPad 支持（v1.0 起）
> 上游 Spec: 026（暗黑）、039（Primer）、全页面横切
> 状态: draft（2026-09-02 规划；持续型、伴随各域，先做「基线验收清单」）

---

## 一、页面/功能概述

参考官方 2026 年每月更新都把「无障碍（VoiceOver/Dynamic Type/对比度）」作为常驻修复项，我们把这类工作从隐式变成**显式横切规范**：① `accessibility` 标注基线（现有 64 处接入点补全：列表项/卡片/输入框/加载态/错误态/开关列 word）；② **大字体**（系统字体缩放 ≥ 1.4× 下 全部关键页不裁切/不重叠——官方 App 2026 每一版都在修这个）；③ **对比度**抽查（Primer token 硬性，自定义色一律过 WCAG AA）；④ **状态播报**（加载完成/刷新/错误/操作成功场景 announce）；⑤ 多设备：**折叠屏/平板**（Mate X7 / MatePad Pro 13 断点适配：内容最大宽 720vp、可选双栏；2in1 MateBook Pro 窗口化）；⑥ 安全区域/横竖屏。交付形态：**可运行的无障碍走查清单**（tab/长截图比对脚本固定步骤），作为每批功能合并前的 gate。

---

## 二、整体 UI 结构

```text
交付物（非单一页面）：
1. docs/a11y-checklist.md  —— 固定走查步骤（页面 × 场景）
2. utils/A11y.ets —— 公共封装（announce/角色描述/对比度工具）
3. 抽查门禁：CI 用 linter（可选）或人工走查记录

设备矩阵（现有模拟器/真机）：
Pura 90 Pro（手机 6.7" 直屏）
Mate X7（折叠外屏/内屏）
MatePad Pro 13（平板 → 双栏候选）
MateBook Pro（2in1 窗口/触控）
```

---

## 三、元素清单

| # | 位置 | 元素 | 功能 | 可行性 | 接口 | 备注 |
| --- | ------ | ------ | ------ | -------- | ------ | ------ |
| 1 | 全局 | accessibility 基线 | 组件的可访问性标注（accessibilityText/description/role/selected/focused/checkable）全量补齐（特别是列表行、按钮、tab、toast） | ✅ | ArkUI a11y API | 现状 64 处 → 覆盖所有交互元素 |
| 2 | 全局 | 大字体适配 | 系统字体缩放（设置字体倍率）下：标题/按钮/卡片行不裁切；Text 默认跟随（不强制 fixed 字号）；关键页人工走查 | ✅ | 系统字体与 layout 检查 | 验收阈值：系统字体 1.4× 下 RepoDetail/IssueDetail/Profile/Inbox/Copilot 无截断 |
| 3 | 全局 | 对比度校验 | 非 token 颜色零容忍；自定义色（labels 色、状态色）过 AA（4.5/1 文本、3/1 大字号） | ✅ | 颜色计算 util | labels 背景白/黑字自动判定（044 协作） |
| 4 | 全局 | 状态播报 | 加载完成/内容变化/错误/写操作成功 announce（Toast 同步 announce） | ✅ | announce（ArkUI） | 列表刷新、表单提交、tabs 切换 |
| 5 | 多设备 | 折叠屏适配 | 折叠状态/分屏：内容区最大宽限制（与官方 App 一致）；Mate X7 双屏不断行 | ⚠️ | 系统参数 | 双栏列表-详情（Master-Detail）仅平板；折叠内屏不做 |
| 6 | 多设备 | 平板布局 | 宽屏断点 ≥840vp：列表可双栏（master-detail，仅 Repo 详情→子树） | ⚠️ | MediaQuery | 若投入大：先占位不做双栏，仅内容最大宽对齐（P1 合并说明） |
| 7 | 多设备 | 安全区域/横竖屏 | 每页 safeArea 校验（刘海/挖孔避开）+ 横屏滚动布局不破 | ✅ | 系统安全区 | —— |
| 8 | 流程 | 走查清单 | docs/a11y-checklist.md（页面×场景表格，勾选记录） | ✅ | 无 | 每个功能批合并前跑一遍 |

> 可行性: 6/8 可行（折叠屏细节、平板双栏为 ⚠️）

---

## 四、核心接口片段

```text
# ArkUI 关键 API（现状已接入部分）
.accessibilityText('xx') / .accessibilityDescription('xx')
.announce(Status.FINISH, '刷新完成')
.focusable(true) / .accessibilityLevel(Level.ONE)
# 系统字体：默认 follow（不锁死），Text 若设固定 size 必须改为 token 档（12/14/16/20/32/40）
```

---

## 五、边界 / 不可行项

| 项 | 原因 | StarRaft 处理方式 |
| ---- | ------ | ------------------- |
| 平板双栏（Master-Detail） | 信息架构大改（Repo 详情内部拆两栏）投入超高 | 保留单栏 + 最大宽 720vp；双栏列为远期观察项 |
| 「动态字体」极端 200% | 布局受限于 5-6 档 token 字号 | 走查档位到 1.4×；超档不影响功能即可 |
| 屏幕阅读器完整标签（中文朗读） | 语言支持依赖系统 TTS 语言包 | 跟随系统（不阻止）；标注只保证结构正确 |

---

## 六、TDD 验收标准

- [ ] 测试 1：a11y-checklist.md 建立，含 8 个核心页 × 6 个场景 48 条目
- [ ] 测试 2：列表行/按钮/tab 100% 有 accessibility 标注（抽样 30 个断言无裸 Text-only 交互元素）
- [ ] 测试 3：系统字体 1.4× 下 Pura 90 Pro 走查：RepoDetail/IssueDetail/PrDetail/Profile/Inbox 无文字裁切（人工+截图存档）
- [ ] 测试 4：对比度检查 util 对 040 的自定义色（标签/状态）判定正确
- [ ] 测试 5：操作成功/失败 announce（提交、下载、刷新）
- [ ] 测试 6：Mate X7 折叠/展开不出现布局错乱（截图对比）
- [ ] 测试 7：安全区域：刘海屏顶部图标不被遮挡（截图）
- [ ] 测试 8：check-spec 通过

---

## 七、备注

- 官方数据参考：**2026 年 1.241-1.273 每版 release notes 的 Bug fixes 段绝大多数是无障碍条目**（Dynamic Type 裁切、对比度、VoiceOver 播报）——说明「普通功能大迭代后紧跟着无障碍专项」是官方常态；我们对应：每批合并前跑本清单。
- 品牌对齐：官方 iPad 支持是 v1.0 就有（官网 App Store 描述）；我们现阶段模拟器有 MatePad/Mate X7，走查成本低于真机，本规范恒定 0 成本门禁。
- 与 026 暗黑共存：对比度同步在 light/dark 两套执行。
