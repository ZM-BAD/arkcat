#!/usr/bin/env bash
# GraphQL 契约检查：scripts/graphql-contract.mjs 清单 → gh api graphql 实测。
# 目的：GraphQL 字段与 schema 漂移（历史事故：Release body 字段不存在、
#       GitActor 无 login、PR_FILES 缺 pageInfo 全是死代码）——改查询/升级 schema 后一整页挂。
# 运行：bash scripts/check-graphql.sh（本机 gh 已登录；CI 无 token 自动跳过不红）
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if ! gh auth status >/dev/null 2>&1; then
  echo "⚠️  gh 未登录（gh auth login）——契约检查跳过（本机开发建议先登录再跑）"
  exit 0
fi

node --input-type=module - "$ROOT/scripts/graphql-contract.mjs" <<'NODE'
import { execFileSync } from 'node:child_process';

const contract = (await import('file://' + process.argv[2])).default;
const token = execFileSync('gh', ['auth', 'token'], { encoding: 'utf-8' }).trim();
const fails = [];
for (const item of contract) {
  let data;
  try {
    const res = await fetch('https://api.github.com/graphql', {
      method: 'POST',
      headers: {
        authorization: `Bearer ${token}`,
        'content-type': 'application/json'
      },
      body: JSON.stringify({ query: item.query, variables: item.variables ?? {} })
    });
    data = await res.json();
  } catch (e) {
    fails.push({ name: item.name, err: String(e.message ?? e).slice(0, 300) });
    continue;
  }
  const errors = data.errors ?? [];
  if (errors.length > 0) {
    fails.push({ name: item.name, err: JSON.stringify(errors).slice(0, 400) });
  } else {
    console.log(`✅ ${item.name}`);
  }
}
if (fails.length > 0) {
  console.error('❌ GraphQL 契约检查失败:');
  for (const f of fails) {
    console.error(`  - ${f.name}\n    ${f.err}`);
  }
  process.exit(1);
}
console.log(`✅ contract check passed (${contract.length} queries)`);
NODE
