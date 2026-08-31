# 贡献指南

## Git Hooks 安装

```bash
bash scripts/install-hooks.sh
```

安装后每次 `git commit` 自动运行（优先 pre-commit 框架，未安装时回退 `.githooks/`）：
- **pre-commit**: Spec 合规检查（check-spec.sh）+ markdownlint + gitleaks + trailing whitespace
- **commit-msg**: commitlint 校验 Conventional Commits 格式

## Commit Message 规范

遵循 [Conventional Commits](https://www.conventionalcommits.org/)：

```text
<type>[optional scope]: <description>
```

**Type 列表**：

| Type | 用途 |
|------|------|
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

**示例**：

```bash
feat(home): add notification badge
fix(repo): correct star count display
docs(spec): update PR diff spec
test(home): add unit tests for user card
```

## Spec 编写规范

1. 所有功能/页面必须先在 `specs/` 编写 Spec
2. Spec 文件命名：`NNN-name.md`（三位数字递增）
3. 使用 `specs/_TEMPLATE.md` 作为模板
4. 包含 GraphQL 可行性标注
5. 包含 TDD 验收标准 checklist

## 分支策略

- `main` — 稳定分支，可发布
- `develop` — 开发分支
- `feature/xxx` — 功能分支
- `fix/xxx` — 修复分支

## 质量门禁

| 检查项 | 工具 | 阻断？ |
|--------|------|--------|
| Spec 合规 | `scripts/check-spec.sh` | ✅ 是 |
| Commit 格式 | pre-commit commitlint / `.githooks/commit-msg` | ✅ 是 |
| 文件结构 | CI `structure-check` | ✅ 是 |
| Spec 编号连续 | CI `structure-check` | ✅ 是 |
| HarmonyOS 构建 | 本地 `hvigor assembleHap` | 本地阻断 |
