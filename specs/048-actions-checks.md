# Spec 048: Actions / Checks 状态检查（Check runs 列表 / 详情 / 重跑）

> BFS Level: 3
> 关联截图: 官方 PR 详情 Status 卡展开态、Checks 全量页（Overview）、Check run 详情（步骤列表 + RE-RUN）、RE-RUN 弹层；对应官方 1.249 状态检查改版 / 1.269-1.270 一键重跑
> 上游 Spec: 031（PrDetail Status 卡）
> 状态: approved（2026-09-20 对照官方截图定稿，用户放行开发）

---

## 一、页面/功能概述

把 PR 的状态检查从「徽章 + 简单展开」（031 现状）升级为官方 1.249+ 的可动手动线：**Status 卡展开态**（check run 富行：状态图标 / App 图标 / 名称 / 结论时长副标题 + View all）→ **Checks 全量页**（Overview 分组列表）→ **Check run 详情页**（job 步骤列表 + RE-RUN 入口）→ **RE-RUN 弹层**（单 job 重跑 / 全部重跑 + Debug logging 开关）。重跑走 Actions REST；无对应 job 的外部 check run 降级为应用内浏览器查看官方页。

---

## 二、整体 UI 结构

1. PrDetail Status 卡（改造现有 PrStatusCard 的展开态）：
   - Reviews 行：已有，不动
   - Checks 汇总行：已有（状态色圆圈 + 结论文案 + chevron），点击展开
   - 展开态 check run 富行 × 前 5 条：左状态色图标 · App 图标（Image）· 名称 · 副标题（结论 + 时长，或 check run 自带 title）· 行尾 chevron。名称=全称（2026-09-20 走查定案）：Actions 行「workflow 名 / job 名 (event)」如 `Backend / pylint (push)`，外部 App（无 workflowRun）/经典 status=原 name/context
   - 「View all」收口行：主文案 View all + 次行计数（全成功「N successful checks」；混合失败=按实际成败计数「X failing and Y successful checks」，2026-09-20 走查定案，总数配失败词会虚报）→ Checks 全量页
2. Checks 全量页（新路由 `prChecks`，参数 owner/name/number）：
   - App Bar：返回 + 标题 Checks（官方无刷新图标；页面刷新走下拉 / onShown tick / 空态重试）
   - Overview / Details 切换卡（等宽两格，激活格蓝条压 1vp 灰底线）
   - Overview：灰底分组区块头「N successful checks」等（失败 / 进行中 / 成功三档，失败优先；单组时仅一组）+ Check run 富行（与 Status 卡展开行同款组件同名称口径，副标题单行），行点击 → Check run 详情页
   - Details：按 workflow run 分组的白底细线列表（官方截图 2026-09-20）：经典 status=无组头裸行；每个 check suite 一组——组头=App 图标 · workflow 名（外部 App=App 名，如 Codecov）· 右侧蓝字 SUMMARY（仅 Actions 组有，workflowRun 存在才显示）；组内行=裸 job 名（无 workflow 前缀）+ 结论时长副标题，行点击 → Check run 详情页
3. Check run 详情页（新路由 `checkRunDetail`，参数 owner|name|checkRunId|perm）：
   - App Bar 两行：job 展示全称（「workflow 名 / job 名 (event)」，同列表行名称口径；REST 裸 job 名不作顶栏标题）主标题 + 结论时长副标题（2026-09-20 走查定案：REST status/conclusion 小写值须归一大写再判定，否则成功 job 错显 In progress）；右 share（复制/分享 job 链接）+ ⋮（Refresh 纯文字项，原生 bindMenu 弹层、宽度自适应，静默重拉；官方无 Open in GitHub）
   - 步骤列表：左侧状态圆图标 · 步骤名（等宽字体）· 下方灰色时长小字；行间分隔线（含 Post 阶段与 Complete job）
   - 底部吸底区：右下黑浮钮「RE-RUN ▾」（sync 图标 + 下拉箭头；viewer 有仓库写权限才显示）→ 打开重跑弹层
4. Workflow run 汇总页（新路由 `runSummary`，参数 owner/name/runId|perm；Details 页签 SUMMARY 落点，官方截图 2026-09-20）：
   - App Bar：返回 + share（run 链接）+ ⋮（Refresh 纯文字项，静默重拉）
   - 面包屑行：owner login 用户头像（REST /users/{owner}，非 App 图标；20 与行高等高）· `owner / repo / workflow 名`（次要色，单行省略）
   - 提交标题大字（display_title，600）+ `workflow 名 #run_number`（次要色）
   - 触发卡（描边圆角卡）：「Triggered via {event} by {actor} {相对时间}」（actor 加粗）+ 次行 commit 图标 · 短 sha（等宽）· 分支胶囊（git-branch 图标 + head_branch）
   - 四格统计卡（描边圆角卡，竖线分格）：Status（结论词）/ Duration（run_started_at→updated_at）/ Billable time（恒 –，计费数据移动端不可得）/ Artifacts（计数，无则 –）
   - Jobs 区：灰带过渡 + 「Jobs」标题 + 计数副标题（`N passed` 等，按 conclusion 计数拼句）+ job 行（状态圆图标 · job 名 · 结论时长），行点击 → Check run 详情页（全称=「workflow 名 / job 名 (event)」现拼）
   - 底部吸底区：RE-RUN ▾ 黑浮钮（同详情页权限门）→ 重跑弹层（run 级：Enable Debug logging + RE-RUN ALL JOBS）
5. RE-RUN 弹层（详情页内单 bindSheet，固定高度；官方截图 2026-09-20：灰底上叠分组白块，白块间 8vp 灰带，抓取条自绘 36×5 Spec 070 口径）：
   - 白块1 头部：workflow run 头像（40 圆角 8）+ 两行（`workflow 名 #run_number` 灰 / job 名黑粗）
   - 白块2：「Enable Debug logging」行 + 右侧开关（默认关）+ 全宽浅蓝底蓝字按钮「RE-RUN THIS JOB」（左右 16 内距）
   - 白块3：「View workflow summary」行：黑主标题 + 灰副标题「Re-run all jobs, and view workflow details」；run 汇总页弹层同形态（无头部，按钮为 RE-RUN ALL JOBS）

---

## 三、元素清单

| # | 位置 | 元素 | 功能 | 可行性 | GraphQL/REST 接口 | 备注 |
| --- | ------ | ------ | ------ | -------- | ------------------- | ------ |
| 1 | Status 卡展开 | check run 富行 × 前 5 条 | 名称/结论/时长/App 图标副标题；行点击 → 详情 | ✅ | rollup contexts 扩展取 CheckRun databaseId/startedAt/completedAt/title + checkSuite.app | StatusContext 行副标题=状态词，不可点 |
| 2 | Status 卡展开 | View all 收口行 | 次行计数（contexts.totalCount + 汇总态选词）→ Checks 页 | ✅ | statusCheckRollup.state + contexts.totalCount | 主查询一次带出，无额外请求 |
| 3 | Checks 页 | Overview / Details 切换卡 | Overview=分组列表；Details=按 workflow run 分组（组头 SUMMARY → run 汇总页） | ✅ | commits(last:1) 取头提交 oid/headline + checkSuites(30)→workflowRun{databaseId}/checkRuns(50) + status.contexts（普通列表） | 进页一次查询；Details 组内行=裸 job 名（官方截图 2026-09-20） |
| 4 | Check run 详情 | 步骤列表 | step 序/名/结论/时长，等宽字体 | ✅ | REST GET /repos/{o}/{r}/actions/jobs/{check_run_id}（Actions 产出的 check run id = job id） | steps 按 number 排序 |
| 5 | Check run 详情 | RE-RUN 黑浮钮 | 打开重跑弹层；权限门（ADMIN/MAINTAIN/WRITE 才显示） | ✅ | 权限经路由参数传入（来源 031 主查询 viewerPermission） | 403 兜底见五 |
| 6 | RE-RUN 弹层 | 头部 workflow/run 信息 | `workflow 名 #run_number` + job 名 | ✅ | REST GET /repos/{o}/{r}/actions/runs/{run_id}（弹层打开时懒取） | 失败降级只显示 job 名 |
| 7 | RE-RUN 弹层 | RE-RUN THIS JOB 按钮 | 单 job 重跑，成功 toast + 返回刷新 | ✅ | REST POST /repos/{o}/{r}/actions/jobs/{job_id}/rerun | 2xx 即成功 |
| 8 | RE-RUN 弹层 | View workflow summary 行 | 全部 jobs 重跑（带 Debug logging 开关值）+ 打开 workflow 页 | ⚠️ | REST POST /repos/{o}/{r}/actions/runs/{run_id}/rerun body {"enable_debug_logging": bool} | 点击行为按官方副标题字面（见七） |
| 9 | RE-RUN 弹层 | Enable Debug logging 开关 | debug 日志开关（默认关） | ⚠️ | 同上，run 级参数 | job 级 rerun 无此参数（见五） |
| 10 | Check run 详情 | ⋮ Refresh | 原生 bindMenu 纯文字项，静默重拉 job 状态 | ✅ | 同 #4 接口 | 官方无 Open in GitHub（2026-09-20 走查删除） |
| 11 | Check run 详情 | 非 Actions check run | REST job 404（外部 CI App） | ⚠️ | 无 | 「无步骤数据」空态 + 隐藏 RE-RUN；share 浏览器兜底 |
| 12 | 重跑后 | 状态刷新 | 重跑成功 → pop 回列表自动重拉（queued/in_progress 可见） | ✅ | 无（onShown tick 链：详情→Checks 页→PrDetail） | 沿用仓库 onShown 刷新模式 |
| 13 | run 汇总页 | 页面数据 | run 概要 + jobs + 产物计数 | ✅ | REST GET /actions/runs/{run_id}（display_title/head_branch/head_sha/triggering_actor）+ /jobs?per_page=100（mapRestJob 复用）+ /artifacts（total_count） | 触发时间=created_at 相对时长；actor=triggering_actor 回落 actor |
| 14 | run 汇总页 | RE-RUN ▾ → run 级重跑弹层 | Enable Debug logging + RE-RUN ALL JOBS | ✅ | REST POST /actions/runs/{run_id}/rerun body {"enable_debug_logging"} | 权限门同 #5；成功 toast + 静默重拉留在本页 |
| 15 | run 汇总页 | Jobs 行 → Check run 详情 | 全称现拼「workflow 名 / job 名 (event)」 | ✅ | job id 即 check run id（#4 同源） | appLogo 缺省空（REST job 无 App 信息） |

> 可行性: 12/15 可行（⚠️ 3 项的处理见五）

---

## 四、核心 GraphQL/REST 片段

主查询扩展（031 fetchPrDetail 的 statusCheckRollup，Status 卡展开态数据源）：

```graphql
statusCheckRollup {
  state
  contexts(first: 20) {
    totalCount
    nodes {
      ... on CheckRun {
        databaseId name status conclusion startedAt completedAt detailsUrl title
        checkSuite { app { name logoUrl } }
      }
      ... on StatusContext { context state targetUrl createdAt }
    }
  }
}
```

Checks 全量页查询（新）：

```graphql
query PrChecks($owner: String!, $name: String!, $number: Int!) {
  repository(owner: $owner, name: $name) {
    pullRequest(number: $number) {
      commits(last: 1) {
        nodes {
          commit {
            # status.contexts 是普通列表（非 connection：无 first/totalCount/nodes 包裹）
            status { contexts { context state targetUrl } }
            checkSuites(first: 30) {
              totalCount
              nodes {
                status conclusion
                app { name logoUrl }
                # Details 组头 SUMMARY 落点（databaseId=REST run id）与行名全称素材
                workflowRun { databaseId event workflow { name } }
                checkRuns(first: 50) {
                  totalCount
                  nodes { databaseId name status conclusion startedAt completedAt detailsUrl title }
                }
              }
            }
          }
        }
      }
    }
  }
}
```

REST（重跑与步骤；GitHub Actions 特有知识，收敛在 ChecksService 适配层）：

```rest
# 步骤列表（Actions check run 的 check run id 与 job id 同值）
GET  /repos/{owner}/{repo}/actions/jobs/{job_id}
     # → { name, status, conclusion, started_at, completed_at, run_id, html_url,
     #     steps: [{ number, name, status, conclusion, started_at, completed_at }] }
# workflow run 名与号（弹层头部，懒取）
GET  /repos/{owner}/{repo}/actions/runs/{run_id}
     # → { name, run_number }
# run 汇总页（display_title/head_branch/head_sha/triggering_actor/created_at/run_started_at/updated_at/html_url）
GET  /repos/{owner}/{repo}/actions/runs/{run_id}
# run 的全部 jobs（JobDetail 同款形状，复用 mapRestJob）
GET  /repos/{owner}/{repo}/actions/runs/{run_id}/jobs?per_page=100
# run 产物计数（无产物 total_count=0 → 展示 –）
GET  /repos/{owner}/{repo}/actions/runs/{run_id}/artifacts     # → { total_count }
# 单 job 重跑（无 body；2xx 即成功；无权限 403）
POST /repos/{owner}/{repo}/actions/jobs/{job_id}/rerun
# 全部 jobs 重跑（Enable Debug logging 开关值走 body 参数）
POST /repos/{owner}/{repo}/actions/runs/{run_id}/rerun    body: {"enable_debug_logging": true|false}
```

---

## 五、边界 / 不可行项

| 项 | 原因 | ArkCat 处理方式 |
| ---- | ------ | ------------------- |
| run 汇总页 Billable time | 计费数据仅仓库管理员在 web 可得，移动端 API 不下发 | 恒展示 –（官方公开仓截图同为 –） |
| run 汇总页 Artifacts | 计数可得（artifacts.total_count） | 0 → –；>0 → 计数 |
| run 汇总页触发文案 | event 词与官方词表未全量对照 | push→commit、pull_request→pull request，其余显示原始 event 词，走查校正 |
| Enable Debug logging 对单 job 重跑 | REST job 级 rerun 无该参数 | 开关值仅在 run 级「View workflow summary」重跑时传入 enable_debug_logging；RE-RUN THIS JOB 忽略开关（UI 保留对齐官方） |
| 非 Actions 产出的 check run / StatusContext | 无对应 job 数据（REST 404） | 详情页步骤区「无步骤数据」空态 + 隐藏 RE-RUN 钮；share 应用内/系统分享官方链接；StatusContext 行不可点 |
| 重跑权限不足 | READ/NONE 账号 rerun 必 403 | viewerPermission ∈ ADMIN/MAINTAIN/WRITE 才渲染 RE-RUN 钮；有权限仍 403 → friendlyError toast（按钮保留） |
| check run 日志全文 | API 不向移动端开放日志流 | 不做；详情页 share 分享官方 job 链接 |
| 弹层 workflow run 号 | GraphQL 无 workflow run 概念 | 弹层打开时懒取 REST run；失败隐藏 `#run_number` 行只显示 job 名 |

---

## 六、TDD 验收标准

- [ ] 测试 1：时长纯函数——startedAt/completedAt → `11s` / `2m 30s` / `1h 05m`；无 completedAt → 空串（进行中）
- [ ] 测试 2：结论分组纯函数——SUCCESS/FAILURE/TIMED_OUT/CANCELLED/QUEUED/IN_PROGRESS 等归入 成功/失败/进行中 三档；组序=失败→进行中→成功；空列表返回空组
- [ ] 测试 3：mapRestJob——REST job JSON → 步骤模型（steps 按 number 升序、run_id/html_url 提取、steps 缺失容错）
- [ ] 测试 4：rollup contexts 归一化——CheckRun（databaseId/时长/App 图标）与 StatusContext（状态词/不可点）双分支，ForEach key 稳定
- [ ] 测试 5：走查——Status 卡展开 5 条富行 + View all 次行计数；行点击直达详情
- [ ] 测试 6：走查——Checks 页分组区块头计数正确，行形态与 Status 卡一致；返回可用
- [ ] 测试 7：走查——详情页步骤等宽字体 + 时长；RE-RUN 弹层三区齐备；RE-RUN THIS JOB 成功 toast 并返回刷新
- [ ] 测试 8：走查——READ 权限账号不渲染 RE-RUN；非 Actions check run 空态不崩溃
- [ ] 测试 9：check-spec 通过
- [ ] 测试 10：走查——Details 页签按 workflow run 分组（组头 App 图标/workflow 名/SUMMARY，组内裸 job 名）；SUMMARY → run 汇总页
- [ ] 测试 11：走查——run 汇总页面包屑/提交标题/#run_number/触发卡/四格统计/Jobs 计数齐备；Jobs 行直达 Check run 详情；RE-RUN ALL JOBS 成功 toast 并重拉

---

## 七、备注

- 官方对应：1.249「状态检查体验重做（View all + 富行）」、1.269/1.270「Check run 屏一键重跑」。
- 分组区块头词式按截图（`19 successful checks`）；全失败/混合态官方素材未覆盖，按同构词式推导（`N failed checks` / `N in progress`），走查时可校正。
- 「View workflow summary」点击行为按官方副标题字面实现：重跑全部 jobs（带开关）+ 打开 workflow run 页；若走查发现官方只是跳页不重跑，再校正（二选一改动集中在弹层回调）。
- 步骤名等宽字体走 `fontFamily('monospace')`（PrDiffCard/CommitDiffBlock 同款）；RE-RUN 黑浮钮用 `floating_btn_bg`（COMMENT 黑浮钮同 token）。
- 045（失败通知 → 直达 Check run 详情）联动不在本 Spec 范围，待 045 重建时挂接。
- 两个新路由均不隐藏底部 Tab 栏（同 PrDetail 二级页口径）。
