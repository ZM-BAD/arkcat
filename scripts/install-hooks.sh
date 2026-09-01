#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────
# 安装 Git hooks
# 优先使用 pre-commit 框架（.pre-commit-config.yaml，含 commitlint/
# markdownlint/gitleaks/spec 检查）；未安装 pre-commit 时回退到 .githooks/
# ──────────────────────────────────────────────────────────────

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
HOOKS_DIR="$PROJECT_ROOT/.githooks"

# 移除 core.hooksPath 配置：它会屏蔽 .git/hooks 目录，
# 与 pre-commit 框架互斥（pre-commit 会拒绝安装）
git -C "$PROJECT_ROOT" config --unset core.hooksPath 2>/dev/null || true

if command -v pre-commit >/dev/null 2>&1; then
    echo "🔧 使用 pre-commit 框架安装 hooks..."
    cd "$PROJECT_ROOT"
    pre-commit install --hook-type pre-commit --hook-type commit-msg
    echo "✅ pre-commit hooks 安装完成"
    echo ""
    echo "已启用 hooks（见 .pre-commit-config.yaml）："
    pre-commit validate-config
    echo ""
    echo "首次提交会拉取 hook 环境（需能访问 GitHub），"
    echo "可先执行 pre-commit run --all-files 预跑一遍"
else
    echo "⚠️  未检测到 pre-commit，回退安装 .githooks/ 到 .git/hooks"
    chmod +x "$HOOKS_DIR"/* 2>/dev/null || true
    for hook in "$HOOKS_DIR"/*; do
        [ -f "$hook" ] && cp "$hook" "$PROJECT_ROOT/.git/hooks/$(basename "$hook")" \
            && chmod +x "$PROJECT_ROOT/.git/hooks/$(basename "$hook")"
    done
    echo "✅ .githooks 安装完成"
    ls -1 "$HOOKS_DIR" | while read hook; do
        echo "  - $hook"
    done
fi

# 防误操作 pre-push（独立于 pre-commit 框架；GitHub 分支保护私有仓库需 Pro）
if [ -f "$HOOKS_DIR/pre-push" ]; then
    cp "$HOOKS_DIR/pre-push" "$PROJECT_ROOT/.git/hooks/pre-push"
    chmod +x "$PROJECT_ROOT/.git/hooks/pre-push"
    echo "✅ pre-push 保护（main/develop 禁 force push / 删除）已安装"
fi
