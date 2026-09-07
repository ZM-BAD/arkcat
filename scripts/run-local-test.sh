#!/usr/bin/env bash
# 官方 Local Test（Hypium + 真实 ArkTS 语义 + 覆盖率报告）本机单命令封装。
# CI 等价物：macos job 中的 hvigorw test（Linux 不支持，见 ci.yml official-local-test）。
# 前提：DevEco Studio 26 (Mac)；SDK/hvigor 位置上述自动探测。
# 输出：entry/.test/default/outputs/test/reports/{index.html, coverageReport.json}
#   test_result.txt 见 entry/.test/default/intermediates/test/coverage_data/
# 注：coverage-filter.json5 仅作用于黑盒覆盖率（ide-ui-test），
#     hvigorw test 的单元覆盖率不解析该文件（2026-09-08 实测，含工程根/模块级两处）。
set -euo pipefail

APP_ROOT="/Applications/DevEco-Studio.app"
if [ ! -d "$APP_ROOT" ]; then
  echo "DevEco Studio 未找到（期望 $APP_ROOT）" >&2
  exit 1
fi
export NODE_HOME="$APP_ROOT/Contents/tools/node"
export DEVECO_SDK_HOME="$APP_ROOT/Contents/sdk"
export PATH="$NODE_HOME/bin:$APP_ROOT/Contents/tools/hvigor/bin:$PATH"

SCOPE="${1:-}"
if [ -n "$SCOPE" ]; then
  hvigorw test -p module=entry -p coverage=true -p scope="$SCOPE" --no-daemon
else
  hvigorw test -p module=entry -p coverage=true --no-daemon
fi

REPORT="entry/.test/default/outputs/test/reports/coverageReport.json"
if [ -f "$REPORT" ]; then
  python3 - "$REPORT" <<'PYEOF'
import json, sys
d = json.load(open(sys.argv[1]))
s = d['summary']
print(f"coverage: lines {s['lines']['pct']}% ({s['lines']['covered']}/{s['lines']['total']}), "
      f"funcs {s['functions']['pct']}%, branches {s['branches']['pct']}%")
PYEOF
fi
