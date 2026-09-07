# Spec 048: Actions / Checks 状态检查（Check runs 详情 + 一键重跑）

> BFS Level: 3
> 关联截图: 官方 PR Status 卡「View all」→ Check runs 列表/详情（步骤/时长/失败重跑）；1.249/1.269/1.270 对应
> 上游 Spec: 031（PrDetail）、045（通知 — 失败通知联动）
> 状态: draft（2026-09-02 规划）

---

## 一、页面/功能概述

把 PR 的「状态检查」从「一个状态徽章」（031 现有 `statusCheckRollup`）升级为**可动手**：① PR Status 卡展开 → Check runs 列表（name/status/conclusion/duration/运行时）；② Check run 详情视图（步骤 step 展开、日志入口（详情页跳转官方页）、重跑入口）；③ **失败重跑**（REST `POST /repos/{o}/{r}/check-runs/{id}/rerequest`；或 job 级 rerun API，二选一），需要 repo+workflow scope（低权重账号则降级为「在浏览器重跑」）。这也是官方 2026 状态检查改版（1.249 status checks revamp + 「一键修复失败检查 1.269」）的移动端对齐。

---

## 二、整体 UI 结构

PrDetail 页面结构：
1. Status 卡（已有）→ 「View all」→ CheckRunsList（弹层/页面）：
   - 每行：名称 · 状态（spinner / 对勾 / 叉号）· 时长
   - 行点击 → CheckRunDetail：
     - 顶部：conclusion 大徽章/进度条
     - steps 列表（序号/名/状态/时长，折叠展开）
     - 动作：Rerun failed checks | 查看官方详情(Web) | 复制链接
2. 通知（045）：CI 失败通知 → 点击直达 CheckRunDetail

---

## 三、元素清单

| # | 位置 | 元素 | 功能 | 可行性 | GraphQL/REST 接口 | 备注 |
| --- | ------ | ------ | ------ | -------- | ------------------- | ------ |
| 1 | Status 卡 | 展开入口 | 「View all / N checks」→ 列表页（弹层优先） | ✅ | 无 | 现有 rollup 的 state 徽章保留 |
| 2 | 列表 | Check runs | 按传入顺序列出 name/status/conclusion/startedAt/completedAt/时长 | ✅ | checkSuite(id) { checkRuns } 或 PR 侧 checkSuites\|checkRuns(last) | 单页 50 条内 |
| 3 | 详情 | Check run 概览 | 名称/头图（conclusion 色块 → Primer 语义色）/commit sha 短链/日志步骤数 | ✅ | CheckRun 详情字段 | 步骤缺失（复合）时灰态 |
| 4 | 详情 | steps 列表 | step.name/status/conclusion/number + 时长；失败 step 高亮 | ✅ | 见四 | API 6 小时内步骤保留 |
| 5 | 详情 | 官方详情页 | 「详情」按钮 → 应用内 ArkWeb 打开 check run 的 detailsUrl（官方 Actions 页） | ✅ | 无（detailsUrl 来自查询） | 需要登录态页面（ArkWeb 带 cookie? 无 → 浏览器打开） —— 降级外开（见 6） |
| 6 | 详情 | 外部打开 | 无 cookie 场景 → 系统浏览器打开官方页面 | ✅ | 无 | 默认动作就是浏览器（移动端常见） |
| 7 | 详情 | 一键重跑 | REST rerun（优先 check_run rerequest；降级 job rerun）→ toast + 列表刷新 | ⚠️ | 见四 | 需要 token 具有 workflow scope（低权限降级：仅提示+浏览器） |
| 8 | 详情 | 重跑后状态 | 查询断言 status=QUEUED 并轮询（2s×10 次） | ⚠️ | 无 | 失败提示「可能已重跑（风控/并发）」 |
| 9 | 通知 | 失败通知联动 | 045 中 CI 相关通知 → 本模块直达（若通知类型可识别） | ⚠️ | 无 | 通知类型映射（run/check）在 045 判定 |
| 10 | 列表 | 并发路径 | 仓库 Actions 页面重跑按钮受限时（permission）隐藏 | ✅ | 无 | 前端权限判断 + 后端兜底 |

> 可行性: 7/10 可行（重跑、轮询状态、通知联动 3 项 ⚠️；其余 ✅）

---

## 四、核心 GraphQL/REST 片段

```graphql
query Drawer($owner: String!, $name: String!, $number: Int!) {
  repository(owner: $owner, name: $name) {
    pullRequest(number: $number) {
      id url
      checkSuites(last: 6) {
        nodes {
          id status conclusion
          checkRuns(last: 60) {
            nodes {
              id databaseId name status conclusion startedAt completedAt detailsUrl
              steps(first: 100) { nodes { id name number status conclusion } }
            }
          }
        }
      }
    }
  }
}
```

```rest
# 重跑 check run（HTTP/1.1；带 token）
POST /repos/{owner}/{repo}/check-runs/{check_run_id}/rerequest
# 或 job 级：POST /repos/{owner}/{repo}/actions/jobs/{job_id}/rerun（需 workflow scope）
# 不设置 body；返回 202/204
```

---

## 五、边界 / 不可行项

| 项 | 原因 | ArkCat 处理方式 |
| ---- | ------ | ------------------- |
| 重跑权限（workflow scope） | PAT 默认无 workflow | 检测 403 → 提示「请为 token 开通 workflow 权限，或在浏览器重跑」，按钮保留但二次确认 |
| 官方在 web 上的「复现失败/打包」 | Actions API 不开放给移动端 | 不做 |
| check run 日志全文 | GraphQL 无日志字段；官方 web 才有 | 跳浏览器看日志 |
| 免费 token 配额 | 轮询请求多 → 限流 | 轮询上限 10 次、间隔 2s；失败静默（状态已知） |

---

## 六、TDD 验收标准

- [ ] 测试 1：「View all」展开 Check runs 列表，行含 名称/状态图标/时长；conclusion 色板为 Primer 语义色
- [ ] 测试 2：点击行进入详情；steps 折叠/展开；失败 step 高亮（+ 步骤序号）
- [ ] 测试 3：详情按钮 → 外部浏览器打开 detailsUrl
- [ ] 测试 4：重跑点击 → POST rerequest 成功（断言路径带 check_run_id）；成功后列表刷新且状态变 queued/in_progress
- [ ] 测试 5：403 时按钮降级文案出现（不崩溃），i18n 双份
- [ ] 测试 6：轮询：10 次后停止，无重复请求（计数断言）
- [ ] 测试 7：空 checks → 列表空态（无检查文本）+ 页面可返回
- [ ] 测试 8：check-spec 通过

---

## 七、备注

- 官方 2026 相关：1.249「状态检查体验重做（更清晰状态指示 + View all）」；1.269/1.270「在 Check run 屏一键修复失败的 Actions 检查」——本 Spec 即对齐这两条。
- 状态色：与 031/027 的 `statusCheckRollup.state` 语义一致（SUCCESS 绿/FAILURE 红/NEUTRAL 灰…），统一 `utils/Tokens`，不新增色值。
- 优先级：官方 2026 主线（CI 在移动端「可操作」），标注 P1（次于写路径 040-044）。
