# AGENTS.md — StarRaft AI 辅助开发指南

> 本文件供 AI 编码助手（Claude Code / GitHub Copilot / Cursor 等）读取，
> 用于快速理解项目上下文、开发规范与约定。

---

## 一、项目概览

**StarRaft** 是一个基于 HarmonyOS NEXT（纯血鸿蒙）开发的 GitHub 第三方客户端应用。

| 关键信息 | 值 |
|---------|-----|
| 应用名称 | StarRaft |
| 包名 | `me.zmbad.starraft` |
| 目标平台 | HarmonyOS 7.0（API 26.0.0） |
| 最低兼容 | HarmonyOS 5.0（API 12） |
| 开发语言 | ArkTS / ArkUI |
| 构建工具 | hvigor（DevEco Studio 内置，CLI 经 `devecocli` 调用） |
| 测试框架 | Hypium |
| 架构 | 纯端侧直连 GitHub GraphQL API，无 BFF/后端 |
| 认证方式 | GitHub Personal Access Token（用户自行生成，本地存储） |

---

## 二、技术栈与约定

### 2.1 核心技术
- **UI 框架**：ArkUI（原生组件，不使用三方 UI 库）
- **网络**：`@kit.NetworkKit`（自封装 GraphQL Client）
- **API**：GitHub GraphQL API v4 为主，REST v3 兜底
- **状态管理**：V2（`@ComponentV2` / `@Local` 等，API 18+；简单页面可用 V1）
- **路由**：待选型（候选：Navigation / Router）

### 2.2 代码风格
- **语言**：ArkTS（TypeScript 的超集，遵循严格类型）
- **命名**：
  - 文件名：`kebab-case`（如 `user-profile.ets`）
  - 组件名：`PascalCase`（如 `UserProfile`）
  - 变量/函数：`camelCase`
- **注释**：关键逻辑必须写注释，保持与周围代码相同的注释密度
- **组件拆分**：单文件不超过 300 行，复杂组件拆分子组件

### 2.3 ArkTS 注意事项
- ArkTS 是 TypeScript 的严格子集，**不支持**的部分：
  - `any` / `unknown` 类型
  - `var` 声明（必须 `let` / `const`）
  - 动态对象属性添加
  - `eval` / `with` 语句
  - 函数重载（使用可选参数替代）
- 装饰器：`@Entry`、`@Component`、`@State`、`@Prop`、`@Link` 等是 ArkUI 核心
- 资源引用：`$r('app.string.xxx')`、`$r('app.media.xxx')`

---

## 三、目录结构

```text
starraft/
├── AppScope/                 # 应用级配置
│   └── app.json5             # 应用入口配置
├── entry/                    # 主模块
│   └── src/main/
│       ├── ets/              # ArkTS 源码
│       │   ├── entryability/ # 主入口 Ability
│       │   ├── pages/        # 页面
│       │   ├── components/   # 可复用组件
│       │   ├── services/     # 网络请求 / API 封装
│       │   ├── models/       # 数据模型（interface/type）
│       │   └── utils/        # 工具类
│       ├── resources/        # 资源文件（string/media/profile）
│       └── module.json5      # 模块配置
├── specs/                    # Spec 文档目录
│   ├── _TEMPLATE.md          # Spec 模板
│   ├── README.md             # Spec 索引
│   └── NNN-name.md           # 各页面 Spec
├── skills/                   # 项目本地 AI Skills（不入库，见 .gitignore）
│   ├── harmony-next/         # API 参考库（3,708 文件，60MB）
│   ├── harmonyos-design/     # 设计规则库
│   ├── harmonyos-motion-vocabulary/  # 动效词汇
│   ├── review-harmonyos-design/      # 设计评审基线
│   ├── arkts-development/    # ArkTS 开发指南
│   └── harmonyos-build-deploy/       # 构建部署指南
├── scripts/                  # 脚本
│   ├── check-spec.sh         # Spec 合规检查
│   └── install-hooks.sh      # 安装 Git hooks
├── .githooks/                # Git hooks
├── .github/workflows/        # CI 配置
│   └── ci.yml                # 主 CI 流程
├── hvigorfile.ts             # 构建配置
├── build-profile.json5       # 构建 profile
├── oh-package.json5          # 根依赖
├── CONTRIBUTING.md           # 贡献指南
├── AGENTS.md                 # 本文件：AI 辅助开发指南
├── CLAUDE.md → AGENTS.md     # Claude Code 兼容软链
├── README.md                 # 项目自述（English，默认）
└── README_zh.md              # 项目自述（中文）
```

---

## 四、Specs 规范

> **核心原则**：每个功能/页面必须先写 Spec，再写代码。Spec 是开发的蓝图。

### 4.1 Spec 位置
所有 Spec 文件位于 `specs/` 目录，命名为 `NNN-name.md`（三位数字递增）。

### 4.2 Spec 模板
使用 `specs/_TEMPLATE.md` 作为模板，包含以下章节：

1. **页面/功能概述** — 是什么、在哪、干什么
2. **整体 UI 结构** — ASCII art 布局图
3. **元素清单** — 表格（位置/元素/功能/可行性/GraphQL 接口/备注）
4. **核心 GraphQL 片段** — queries / mutations
5. **边界 / 不可行项** — 降级策略
6. **TDD 验收标准** — 实现后逐条勾选的 checklist
7. **备注** — 差异、适配、第三方库等

### 4.3 Spec 状态流转

```text
draft → reviewing → approved → implemented → deprecated
```

### 4.4 Spec 合规检查
提交前自动运行 `bash scripts/check-spec.sh`，确保：
- 文件名格式正确（`NNN-name.md`）
- 必需章节齐全（一~七，按模板顺序）
- ❌ 项有明确处理方式
- 可行性比例声明（N/M 可行）与元素清单 ✅ 数一致
- 编号连续无空缺

---

## 五、Git 工作流

### 5.1 分支策略
- `main` — 稳定分支，可发布
- `develop` — 开发分支
- `feature/<name>` — 功能分支
- `fix/<name>` — 修复分支

### 5.2 Commit 规范
遵循 [Conventional Commits](https://www.conventionalcommits.org/)：

```text
<type>[optional scope]: <description>
```

| Type | 用途 |
|------|------|
| `feat` | 新功能 |
| `fix` | Bug 修复 |
| `docs` | 文档变更 |
| `style` | 代码格式 |
| `refactor` | 重构 |
| `perf` | 性能优化 |
| `test` | 测试相关 |
| `build` | 构建/依赖 |
| `ci` | CI 配置 |
| `chore` | 其他杂项 |
| `revert` | 回滚 |

### 5.3 Git Hooks
安装方式：`bash scripts/install-hooks.sh`。优先使用 pre-commit 框架（`.pre-commit-config.yaml`），未安装时回退 `.githooks/`：
- `pre-commit`：Spec 合规检查（check-spec.sh）、markdownlint、gitleaks、trailing whitespace 等
- `commit-msg`：commitlint 校验 Conventional Commits 格式
- `.githooks/`（spec 检查 + commit 格式校验）为无 pre-commit 环境时的回退方案

---

## 六、质量门禁

| 检查项 | 触发位置 | 阻断？ |
|--------|---------|--------|
| Spec 合规 | pre-commit + CI | ✅ 是 |
| Commit 格式 | commit-msg hook + CI | ✅ 是 |
| 文件结构完整性 | CI | ✅ 是 |
| Spec 编号连续性 | CI | ✅ 是 |
| HarmonyOS 构建 | 本地 | 本地阻断 |

### CI 流程（GitHub Actions）
- **spec-lint**：运行 `check-spec.sh`
- **commit-lint**：检查 commit message 格式
- **structure-check**：验证必需文件存在 + 编号连续
- **harmony-build**：保留（DevEco Studio 许可证限制，本地构建）

---

## 七、设计理念

> **「体验级复刻」** — 成为最接近 GitHub 官方 APP 体验的第三方客户端。

- **复刻的**：信息架构、页面层级、导航模式、功能分区、交互反馈逻辑
- **不复刻的**：平台特有控件样式（不用 iOS 毛玻璃 / Material 涟漪）
- **原则**：用户打开 StarRaft 立即感受到「这就是换皮」，但底层全部使用原生 ArkUI 组件

---

## 八、开发注意事项

1. **不要写后端代码** — 纯端侧项目，所有数据来自 GitHub GraphQL API
2. **API Token 存储** — 使用 `@StorageLink` 或安全存储，不要硬编码
3. **GraphQL 优先** — 能 GraphQL 获取的数据，不走 REST
4. **网络请求** — 统一封装在 `services/`，不要在页面里直接写 http 调用
5. **资源管理** — 字符串、颜色、尺寸等放入 `resources/base/element/`
6. **鸿蒙适配** — 注意鸿蒙与 iOS/Android 的差异（导航栏、手势、安全区域等）
7. **Spec 先行** — 改代码前先确认对应 Spec 是否已 approve
8. **不要膨胀 README** — 详细文档放 `specs/`，README 保持精简

---

## 九、常用命令

```bash
# 安装 Git hooks
bash scripts/install-hooks.sh

# 手动检查 spec 合规
bash scripts/check-spec.sh

# 本地构建（DevEco Studio GUI）
# Build → Build Project (Ctrl/Cmd + F9)
# Run → Run 'entry' (Ctrl/Cmd + R)

# CLI 构建 / 检查（devecocli 1.3+，包装 DevEco Studio 的 hvigor/ohpm/hdc）
devecocli build              # debug HAP（默认 --product default --build-mode debug）
devecocli build clean        # 清理构建产物
devecocli check lint         # DevEco Code Linter 静态检查

# 设备 / 模拟器 / 日志
devecocli device list                       # 已连接设备
devecocli emulator list                     # 本地模拟器
devecocli emulator start "Pura 90 Pro"      # 启动模拟器（名称带空格加引号）
devecocli run --help                        # 构建并部署到设备
```

> **沙箱提示**：`devecocli build` 等构建类命令在技能文档中标记为 `[Outside sandbox]`，
> 在 ZCode 沙箱模式下首次执行需放行授权，属正常现象。

---

*本文件是 AI 助手理解项目的主要入口。修改项目结构、规范或约定时，请同步更新本文。*
