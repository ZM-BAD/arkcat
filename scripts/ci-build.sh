#!/usr/bin/env bash
# CI debug 构建（macOS）：签名材料在本机 ~/.ohos/config、不在 CI——
# 剥除 signingConfigs（含 products.signingConfig 引用）→ 产出 unsigned HAP（可装模拟器）。
# 前置：setup-ohos 后的 PATH（hvigorw/ohpm）+ $HOS_SDK_HOME + ohpm install --all。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROFILE="$ROOT/build-profile.json5"

python3 - "$PROFILE" <<'PYEOF'
import sys
import re
p = sys.argv[1]
s = open(p).read()
s2 = re.sub(r'\n\s*signingConfigs:\s*\[[^\]]*\],\n', '\n', s, count=1)
s2 = re.sub(r"\n\s*signingConfig: '[^']*',\n", '\n', s2, count=1)
if s2 == s:
    print('build-profile.json5 未找到签名配置段，跳过剥离')
else:
    open(p, 'w').write(s2)
    print('signingConfigs stripped for CI (unsigned HAP)')
PYEOF

export DEVECO_SDK_HOME=$HOS_SDK_HOME
hvigorw assembleHap --mode module -p product=default -p buildMode=debug --no-daemon
