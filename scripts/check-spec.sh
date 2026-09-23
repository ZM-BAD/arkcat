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

    # 6. 可行性比例声明一致性："N/M 可行" 的 N 必须等于元素清单中 ✅ 行数
    #    正则允许比例与「可行」之间有其他措辞（如「14/14 全部可行」），且校验文件内每一条声明
    actual=$(awk -F'|' '/^\| [0-9]+ \|/ { c += gsub(/✅/, "", $0) } END { print c+0 }' "$file")
    claims=$(grep -oE "[0-9]+/[0-9]+[^|]*可行" "$file" || true)
    if [ -n "$claims" ]; then
        while IFS= read -r claim; do
            [ -z "$claim" ] && continue
            claimed=${claim%%/*}
            if [ "$claimed" -ne "$actual" ]; then
                echo "  ❌ $filename — 可行性比例声明「${claim}」与元素清单 ✅=$actual 行不符"
                ERRORS=$((ERRORS + 1))
            fi
        done <<< "$claims"
    fi
done

# ──────────────────────────────────────────────
# 以下为 2026-09-24 新增的三项检查。三者共同针对同一类盲区：
# 上文第 1~6 项校验的都是 spec 的「形状」（文件名/标题/章节/计数），
# 不校验任何**声明是否为真**——状态取值、索引同步、验收勾选都无人看守，
# 于是 045 功能已上线却仍标 draft、046 状态行与自身正文矛盾、
# specs/README.md 漏 076 等漂移可以在门禁全绿的情况下长期存在。
# ──────────────────────────────────────────────

# 提取 spec 自身的状态值与 BFS Level（容错：允许「✅ implemented」「implemented（备注）」等写法）
spec_status() {
    sed -n 's/^> 状态:[[:space:]]*//p' "$1" | head -1 \
        | sed -E 's/^✅[[:space:]]*//' | grep -oE '^[a-zA-Z]+' | head -1 || true
}
spec_bfs() {
    sed -n 's/^> BFS Level:[[:space:]]*//p' "$1" | head -1 | grep -oE '[0-9]+' | head -1 || true
}
# 取第六章（TDD 验收标准）正文，供勾选统计使用
spec_section6() {
    awk '/^## 六、/{f=1;next} /^## 七、/{f=0} f' "$1"
}

# ──────────────────────────────────────────────
# 7. 状态行合法性：取值必须落在模板定义的枚举内
# ──────────────────────────────────────────────
STATUS_ENUM_RE='^(draft|reviewing|approved|implemented|deprecated)$'

echo ""
echo "🔍 检查状态行合法性..."
for file in $SPEC_FILES; do
    filename=$(basename "$file")
    status_line=$(grep -m1 '^> 状态:' "$file" || true)
    if [ -z "$status_line" ]; then
        echo "  ❌ $filename — 缺少 '> 状态:' 字段"
        ERRORS=$((ERRORS + 1))
        continue
    fi
    status_val=$(spec_status "$file")
    if ! echo "$status_val" | grep -qE "$STATUS_ENUM_RE"; then
        echo "  ❌ $filename — 状态值非法：'${status_val}'"
        echo "     （应为 draft | reviewing | approved | implemented | deprecated）"
        ERRORS=$((ERRORS + 1))
    fi
done

# ──────────────────────────────────────────────
# 8. README 索引比对：文件必须在索引中有行，且状态一致
#    （BFS Level 不一致只告警——specs/README.md 自述该列为 2026-08
#      初始分析的历史参考，后续 spec 未重新统计，故不作阻断）
# ──────────────────────────────────────────────
README_INDEX="$SPEC_DIR/README.md"

echo ""
echo "🔍 检查 README 索引同步..."
if [ ! -f "$README_INDEX" ]; then
    echo "  ❌ 缺少 $README_INDEX"
    ERRORS=$((ERRORS + 1))
else
    # 反向：索引里有行但文件不存在
    while IFS= read -r linked; do
        [ -z "$linked" ] && continue
        if [ ! -f "$SPEC_DIR/$linked" ]; then
            echo "  ❌ README 索引指向不存在的文件：$linked"
            ERRORS=$((ERRORS + 1))
        fi
    done <<< "$(grep -oE '\]\([0-9]{3}-[a-z0-9-]+\.md\)' "$README_INDEX" | tr -d ']()' | sort -u)"

    for file in $SPEC_FILES; do
        filename=$(basename "$file")
        row=$(grep -F "]($filename)" "$README_INDEX" | head -1 || true)
        if [ -z "$row" ]; then
            echo "  ❌ $filename — README 索引中缺少该 spec 的行"
            ERRORS=$((ERRORS + 1))
            continue
        fi
        idx_status=$(echo "$row" | awk -F'|' '{gsub(/[ \t]/,"",$6); print $6}')
        idx_bfs=$(echo "$row" | awk -F'|' '{print $5}' | grep -oE '[0-9]+' | head -1 || true)
        f_status=$(spec_status "$file")
        f_bfs=$(spec_bfs "$file")

        if [ -n "$f_status" ] && [ "$idx_status" != "$f_status" ]; then
            echo "  ❌ $filename — 状态不一致：文件 '${f_status}' vs 索引 '${idx_status}'"
            ERRORS=$((ERRORS + 1))
        fi
        if [ -n "$f_bfs" ] && [ -n "$idx_bfs" ] && [ "$idx_bfs" != "$f_bfs" ]; then
            echo "  ⚠️  $filename — BFS Level 不一致：文件 '${f_bfs}' vs 索引 '${idx_bfs}'"
            WARNINGS=$((WARNINGS + 1))
        fi
    done
fi

# ──────────────────────────────────────────────
# 9. 验收勾选可见性：implemented 的 spec 若第六章验收一条未勾，
#    说明「完成」无法被验收标准自证（只告警——勾选与状态一样靠人工维护）
# ──────────────────────────────────────────────
echo ""
echo "🔍 检查验收勾选（第六章 TDD 验收标准）..."
for file in $SPEC_FILES; do
    filename=$(basename "$file")
    [ "$(spec_status "$file")" = "implemented" ] || continue
    total=$(spec_section6 "$file" | grep -cE '^[[:space:]]*- \[[ xX]\]' || true)
    total=${total:-0}
    [ "$total" -gt 0 ] || continue
    checked=$(spec_section6 "$file" | grep -cE '^[[:space:]]*- \[[xX]\]' || true)
    checked=${checked:-0}
    if [ "$checked" -eq 0 ]; then
        echo "  ⚠️  $filename — 状态 implemented，但第六章验收 $total 条全部未勾选"
        WARNINGS=$((WARNINGS + 1))
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
