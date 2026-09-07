#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────
# Spec 合规性检查脚本
# 检查 specs/ 目录下的 spec 文件是否符合模板约定
# ──────────────────────────────────────────────────────────────

set -euo pipefail

SPEC_DIR="specs"
ERRORS=0
WARNINGS=0

# 模板要求的必需章节（按顺序；四、允许「核心 GraphQL 片段 / 核心接口」两种标题）
SECTIONS=(
  '## 一、页面/功能概述'
  '## 二、整体 UI 结构'
  '## 三、元素清单'
  '## 四、核心'
  '## 五、边界 / 不可行项'
  '## 六、TDD 验收标准'
  '## 七、备注'
)

# 1. 检查所有 .md 文件（排除 _TEMPLATE.md 和 README.md 索引）
SPEC_FILES=$(find "$SPEC_DIR" -maxdepth 1 -name "*.md" ! -name "_TEMPLATE.md" ! -name "README.md" 2>/dev/null | sort)

if [ -z "$SPEC_FILES" ]; then
    echo "⚠️  未发现 spec 文件"
    exit 0
fi

echo "🔍 检查 spec 文件合规性..."
echo ""

for file in $SPEC_FILES; do
    filename=$(basename "$file")

    # 2. 检查文件名格式：NNN-name.md
    if ! [[ "$filename" =~ ^[0-9]{3}-[a-z0-9-]+\.md$ ]]; then
        echo "  ❌ $filename — 文件名格式错误，应为 NNN-name.md（如 001-home-tab.md）"
        ERRORS=$((ERRORS + 1))
    fi

    # 3. 检查标题
    if ! grep -q "^# Spec " "$file"; then
        echo "  ❌ $filename — 缺少 '# Spec NNN: Title' 标题"
        ERRORS=$((ERRORS + 1))
    fi

    # 4. 检查必需章节（存在 + 顺序）
    prev_line=0
    for sec in "${SECTIONS[@]}"; do
        line=$(grep -n -F -m1 "$sec" "$file" 2>/dev/null | head -1 | cut -d: -f1 || true)
        if [ -z "$line" ]; then
            echo "  ❌ $filename — 缺少章节 '$sec'"
            ERRORS=$((ERRORS + 1))
        elif [ "$line" -lt "$prev_line" ]; then
            echo "  ❌ $filename — 章节顺序错误：'$sec'（第 $line 行）应位于前一章节之后"
            ERRORS=$((ERRORS + 1))
        else
            prev_line=$line
        fi
    done

    # 5. 检查未完成的 ❌ 项是否有处理说明
    if grep -q "❌" "$file"; then
        if ! grep -q "ArkCat 处理" "$file"; then
            echo "  ⚠️  $filename — 包含 ❌ 项但缺少处理方式说明"
            WARNINGS=$((WARNINGS + 1))
        fi
    fi

    # 6. 可行性比例声明一致性："- N/M 可行" 的 N 必须等于元素清单中 ✅ 行数
    claim=$(grep -oE "[0-9]+/[0-9]+ 可行" "$file" | head -1 || true)
    if [ -n "$claim" ]; then
        claimed=$(echo "$claim" | cut -d/ -f1)
        actual=$(awk -F'|' '/^\| [0-9]+ \|/ { c += gsub(/✅/, "", $0) } END { print c+0 }' "$file")
        if [ "$claimed" -ne "$actual" ]; then
            echo "  ❌ $filename — 可行性比例声明为 ${claim}，但元素清单实际 ✅=$actual 行"
            ERRORS=$((ERRORS + 1))
        fi
    fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "检查完成: $ERRORS 个错误, $WARNINGS 个警告"

if [ $ERRORS -gt 0 ]; then
    echo "❌ Spec 合规检查失败"
    exit 1
else
    echo "✅ Spec 检查通过"
    exit 0
fi
