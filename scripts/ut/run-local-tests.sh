#!/usr/bin/env bash
# ArkCat 宿主单元测试（无模拟器/无 HOS 运行时依赖）：
#  esbuild（devDependency，经 scripts/ut/build-ut.mjs）打包 ArkTS 纯函数链 → node:test 执行。
#  覆盖率：宿主层不统计（bundle 单文件无意义），覆盖率走官方 Local Test（hvigorw test）侧。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

if [ ! -d "$ROOT/node_modules/esbuild" ]; then
  echo "esbuild not installed — run: npm install" >&2
  exit 1
fi

node "$ROOT/scripts/ut/build-ut.mjs"
node --test "$ROOT/.ut/bundle.test.mjs"
