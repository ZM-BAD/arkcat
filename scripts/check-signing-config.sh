#!/usr/bin/env bash
# 门禁：build-profile.json5 不得携带本机信息入库。
#
# 签名配置是本机专属的——里面是 ~/.ohos/config 下的绝对路径（含用户名）与加密口令。
# 入库有两重害处：
#   1) 把本机路径与用户名推到远端仓库（仓库开源后人人可见）；
#   2) 其他贡献者拿到这份配置也签不了名（官方 FAQ faqs-signature-service-19 记载的
#      「signingConfigs 冲突」正是此因）。
#
# 提交形态应为 `signingConfigs: []`（官方 FAQ 认可的写法：文件提交、签名内容不提交）。
# 本地真实签名配置请留在工作区不入库——本脚本会拦住误提交。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROFILE="$ROOT/build-profile.json5"

if [ ! -f "$PROFILE" ]; then
  echo "check-signing-config: 未找到 build-profile.json5，跳过"
  exit 0
fi

FAIL=0

# ① 绝对路径（macOS / Linux / Windows 三平台形态）
if grep -nE "/Users/|/home/|/Volumes/|[A-Za-z]:\\\\" "$PROFILE" >/dev/null 2>&1; then
  echo "❌ build-profile.json5 含本机绝对路径："
  grep -nE "/Users/|/home/|/Volumes/|[A-Za-z]:\\\\" "$PROFILE" | sed 's/^/     /'
  FAIL=1
fi

# ② 非空 signingConfigs（签名段一旦有内容，路径与口令就在里面）
if python3 - "$PROFILE" <<'PYEOF'
import re, sys
s = open(sys.argv[1], encoding='utf-8').read()
m = re.search(r'signingConfigs\s*:\s*\[(.*?)\]', s, re.S)
sys.exit(1 if (m and m.group(1).strip()) else 0)
PYEOF
then
  :
else
  echo "❌ build-profile.json5 的 signingConfigs 非空——本机签名配置不应入库，请改为 signingConfigs: []"
  FAIL=1
fi

if [ "$FAIL" -eq 1 ]; then
  echo ""
  echo "本机签名配置改用工作区保留（不 git add 该文件），或参照 README/CONTRIBUTING 自行配置本地签名。"
  exit 1
fi

echo "✅ build-profile.json5 无本机信息（signingConfigs 为空）"
