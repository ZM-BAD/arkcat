# 贡献指南

## Git Hooks 安装

```bash
bash scripts/install-hooks.sh
```

安装后每次 `git commit` 自动运行（优先 pre-commit 框架，未安装时回退 `.githooks/`）：
- **pre-commit**: Spec 合规检查（check-spec.sh）+ markdownlint + gitleaks + trailing whitespace / end-of-file + 硬编码颜色检查（check-hardcoded-colors.py）+ 硬编码字号检查（check-hardcoded-fontsize.py）+ 宿主单元测试（scripts/ut/run-local-tests.sh，需先 `npm install`）
- **commit-msg**: commitlint 校验 Conventional Commits 格式

## Commit Message 规范

遵循 [Conventional Commits](https://www.conventionalcommits.org/)：

```text
<type>[optional scope]: <description>
```

**Type 列表**：

| Type | 用途 |
| ------ | ------ |
| `feat` | 新功能 |
| `fix` | Bug 修复 |
| `docs` | 文档变更 |
| `style` | 代码格式（不影响逻辑） |
| `refactor` | 重构 |
| `perf` | 性能优化 |
| `test` | 测试相关 |
| `build` | 构建系统/依赖 |
| `ci` | CI 配置 |
| `chore` | 其他杂项 |
| `revert` | 回滚 |

**约定**：type 用英文，**描述用中文**；描述勿以大写拉丁词开头（commitlint subject-case 会拒，如 `Primer`/`More` 开头）。

**示例**：

```bash
feat(home): 首页通知角标
fix(repo): 修正星标计数显示
docs(spec): 更新 PR diff 规格
test(home): 用户卡片宿主单测
```

## Spec 编写规范

1. 所有功能/页面必须先在 `specs/` 编写 Spec
2. Spec 文件命名：`NNN-name.md`（三位数字递增）
3. 使用 `specs/_TEMPLATE.md` 作为模板
4. 包含 GraphQL 可行性标注
5. 包含 TDD 验收标准 checklist

## 分支策略

- `main` — 稳定分支，仅发版时由 develop fast-forward 并打 tag，其余零操作
- `develop` — 开发分支
- `feature/xxx` — 功能分支（自 develop 切出）
- `fix/xxx` — 修复分支（自 develop 切出）

**合并约定**：分支按原样推送多提交，经 GitHub **Squash and merge** 进 develop（禁止推送前本地 squash 重写历史）；合并时不删除分支（清理时机由维护者掌握）。

## 质量门禁

| 检查项 | 工具 | 阻断？ |
| -------- | ------ | -------- |
| Spec 合规 | `scripts/check-spec.sh`（pre-commit + CI `spec-lint`） | ✅ 是 |
| Commit 格式 | pre-commit commitlint / `.githooks/commit-msg` | ✅ 是 |
| 文件结构 / Spec 编号连续 | CI `structure-check` | ✅ 是 |
| Secret 泄漏 | gitleaks（pre-commit + CI） | ✅ 是 |
| UI 硬编码颜色 | `scripts/check-hardcoded-colors.py`（pre-commit + CI） | ✅ 是 |
| UI 硬编码字号/字重 | `scripts/check-hardcoded-fontsize.py`（pre-commit + CI） | ✅ 是 |
| 宿主单元测试 | `scripts/ut/run-local-tests.sh`（pre-commit + CI `unit-tests`） | ✅ 是 |
| HarmonyOS 构建 | 本地 `devecocli build`；CI `harmony-build` / `official-local-test`（双平台）暂 `if: false`，仓库转 public 后恢复 | 本地阻断 |

> 技术栈、GraphQL 调用规范、样式红线、i18n 等开发约定全貌见 [AGENTS.md](AGENTS.md)。
