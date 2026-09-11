# AGENTS.md — ArkCat AI 辅助开发指南

> 本文件供 AI 编码助手（Claude Code / GitHub Copilot / Cursor / ZCode 等）读取，
> 用于快速理解项目上下文、开发规范与约定。

---

## 一、项目概览

**ArkCat** 是基于 HarmonyOS NEXT（纯血鸿蒙）开发的 GitHub 第三方客户端应用。

| 关键信息 | 值 |
| --------- | ----- |
| 包名 / 平台 | `me.zmbad.arkcat`；目标 HarmonyOS 7.0（API 26），最低兼容 5.0（API 12） |
| 语言 / 构建 | ArkTS / ArkUI；hvigor（DevEco Studio 内置，CLI 经 `devecocli` 调用） |
| 测试框架 | Hypium（仪器 / ohosTest）+ node:test（宿主纯函数单测） |
| 架构 | 纯端侧直连 GitHub GraphQL API v4（REST v3 兜底），无 BFF/后端 |
| 认证 | GitHub OAuth Device Flow（主路径）+ Personal Access Token（兼容路径），均本地加密存储 |

---

## 二、技术栈与约定

### 2.1 核心技术
- **UI**：ArkUI 原生组件（不用三方 UI 库）；**网络**：`@kit.NetworkKit` 自封装 GraphQL Client
- **状态管理**：V2（`@ComponentV2` / `@Local`，API 18+；简单页面可用 V1）
- **路由**：Navigation（`NavPathStack` + `navDestination` 模式，见 `pages/Index.ets`）
- **设计规范**：GitHub Primer（[DESIGN.md](DESIGN.md) 为唯一依据；色值/尺寸/字号/圆角/阴影必须用官方令牌——颜色走 resources base/dark 双套 color.json，其余走 `utils/PrimerTokens.ets` 常量，禁止硬编码随意数值）

### 2.2 代码风格
- **命名**：文件 `kebab-case`（`user-profile.ets`）；组件 `PascalCase`（`UserProfile`）；变量/函数 `camelCase`
- **注释**：关键逻辑必须写注释，保持与周围代码相同的注释密度
- **组件拆分**：单文件推荐不超过 300 行（非强制、不设门禁，超出即拆不可取）；复杂组件拆分子组件；高内聚文件可豁免——模型/类型聚合（models/*）、路由注册中心（Index.ets）、多实体查询服务（services/*）、单一职责的密集体块（如 Markdown 渲染），拆分只会扩散 import 与查找成本

### 2.3 ArkTS 注意事项
- ArkTS 是 TypeScript 严格子集，**不支持**：`any`/`unknown`、`var`、动态对象属性添加、`eval`/`with`、函数重载（用可选参数替代）
- 装饰器：`@Entry`、`@Component`、`@State`、`@Prop`、`@Link` 等是 ArkUI 核心
- 资源引用：`$r('app.string.xxx')`、`$r('app.media.xxx')`；i18n 走 base/zh_CN 双份 string.json

---

## 三、Specs 规范

> **核心原则**：每个功能/页面必须先写 Spec，再写代码。Spec 是开发的蓝图。

- **位置/命名**：`specs/NNN-name.md`（三位数字递增）；模板见 `specs/_TEMPLATE.md`（一~七章节：概述/UI 结构/元素清单/核心 GraphQL/边界/TDD 验收/备注）
- **状态流转**：`draft → reviewing → approved → implemented → deprecated`
- **合规检查**：提交前/CI 自动跑 `bash scripts/check-spec.sh`（文件名、章节顺序、❌ 处理、可行性比例与 ✅ 数一致）；**该脚本不查编号连续**——编号由 CI 的 `structure-check` 校验（本地绿 ≠ CI 绿）

---

## 四、Git 工作流

### 5.1 分支策略
- `main` — 稳定分支，可发布（仅在发布时 FF）；`develop` — 开发分支
- 开发流程：develop 切 `feature/<name>`（或 `fix/<name>`）→ 自测于 feature → squash 并 develop → 集成回归在 develop

### 5.2 Commit 规范
遵循 [Conventional Commits](https://www.conventionalcommits.org/)，type：`feat fix docs style refactor perf test build ci chore revert`。

### 5.3 Git Hooks
安装：`bash scripts/install-hooks.sh`。优先 pre-commit 框架（`.pre-commit-config.yaml`：check-spec.sh / markdownlint / 硬编码颜色 / gitleaks / trailing whitespace / 宿主单测）；commit-msg 走 commitlint（`.commitlintrc.json`）；`.githooks/` 为无 pre-commit 环境回退。

---

## 五、质量门禁

| 检查项 | 触发位置 | 阻断？ |
| -------- | --------- | -------- |
| Spec 合规 | pre-commit + CI | ✅ 是 |
| Commit 格式 | commit-msg hook + CI | ✅ 是 |
| 文件结构 / Spec 编号 | CI | ✅ 是 |
| Secret 泄漏（gitleaks） | pre-commit + CI | ✅ 是（CI 2026-09-01 起） |
| UI 硬编码颜色（#RRGGBB） | pre-commit + CI | ✅ 是 |
| 宿主单元测试（node:test） | pre-commit + CI | ✅ 是 |
| Primer 样式 Review（[docs/primer-review-rules.md](docs/primer-review-rules.md)） | Code Review（人工走查，机械条目逐步下沉 scripts/） | ✅ 是（评审退回） |
| HarmonyOS 构建 | 本地 | 本地阻断 |

CI（GitHub Actions）：**spec-lint** / **commit-lint** / **structure-check**（含 Spec 编号连续）/ **hardcoded-colors** / **gitleaks** / **unit-tests**；**harmony-build** 与 **official-local-test** 当前 `if: false` 禁用（私仓 macOS runner 计费 ×10，仓库转 public 后恢复，构建暂由本地兜底）。

---

## 六、设计理念

> **「体验级复刻」**——复刻官方 App 的信息架构、页面层级、导航模式、交互反馈逻辑；不复刻平台特有控件样式。底层全部原生 ArkUI。
> **样式红线**：页面骨架必须复用现有模式（自绘 AppBar/RepoCard/列表卡等），禁自创布局风格；图标必须走 OctIcon 组件；颜色一律官方 token（resources color.json / PrimerTokens），`entry/src/main/ets` 禁止直接写 `#RRGGBB`（`scripts/check-hardcoded-colors.py` 门禁，数据色板文件豁免）。
> **Review 规则**：Primer 样式逐条核对清单见 [docs/primer-review-rules.md](docs/primer-review-rules.md)——〔机械〕条目下沉 `scripts/` 门禁，〔人工〕条目 code review 走查。

---

## 七、开发注意事项

1. **不要写后端代码** — 纯端侧项目，所有数据来自 GitHub GraphQL API
2. **API Token 存储** — 使用 `@StorageLink` 或安全存储，不要硬编码
3. **GraphQL 优先** — 能 GraphQL 获取的数据，不走 REST
4. **网络请求** — 统一封装在 `services/`，不要在页面里直接写 http 调用
5. **资源管理** — 字符串、颜色、尺寸等放入 `resources/base/element/`
6. **鸿蒙适配** — 注意鸿蒙与 iOS/Android 的差异（导航栏、手势、安全区域等）
7. **Spec 先行** — 改代码前先确认对应 Spec 是否已 approve
8. **不要膨胀 README** — 详细文档放 `specs/`，README 保持精简

---

## 八、常用命令（Commands）

```bash
bash scripts/install-hooks.sh   # 安装 Git hooks
bash scripts/check-spec.sh      # 手动检查 spec 合规

# 本地构建（DevEco Studio GUI：Build → Build Project / Run → Run 'entry'）
devecocli build                # debug HAP（默认 --product default --build-mode debug）
devecocli build clean          # 清理构建产物
devecocli check lint           # DevEco Code Linter 静态检查

devecocli device list          # 已连接设备
devecocli emulator list        # 本地模拟器
devecocli emulator start "Pura 90 Pro"   # 启动模拟器（名称带空格加引号）
devecocli run --help           # 构建并部署到设备
```

> **沙箱提示**：`devecocli build` 等构建类命令标记为 `[Outside sandbox]`，沙箱下首次执行需放行授权，属正常现象。

---

*本文件是 AI 助手理解项目的主要入口。修改项目结构、规范或约定时，请同步更新本文。*
