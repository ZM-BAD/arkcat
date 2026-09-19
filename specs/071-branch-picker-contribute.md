# Spec 071: BranchPicker CONTRIBUTE → Compare changes（分支页接建 PR 动线）

> BFS Level: 2
> 关联截图: 官方 App 2026-09-20 截图 2 张（RepoDetail 分支行 → Choose Branch 右上 CONTRIBUTE → Compare changes 空态）
> 上游 Spec: 006（RepoDetail 分支行）、043（branchPicker / prCompare）
> 状态: implemented（2026-09-20 状态回写：随 PR #55 squash 合并 develop=baa9029，CI 绿；走查确认后合并）

---

## 一、页面/功能概述

仓库详情页分支区「Current branch」行的 **CHANGE** 现为占位 toast，本期接通：点击打开**选择分支页**（复用 Spec 043 的 branchPicker，扩展 `repo` 角色——标题 Choose Branch、右上 **CONTRIBUTE** 蓝字钮、当前分支蓝勾复用既有机制）。CONTRIBUTE 点击后进入 **Compare changes 页**（与顶栏菜单「New pull request」完全同页同参复用，零改动：base=默认分支、compare 空 → 空态「Choose a branch to compare changes」），延续官方「从当前分支出发发起贡献」的动线。

---

## 二、整体 UI 结构

1. **RepoDetail 分支行**（既有）：git-branch 图标 + Current branch/默认分支名 ✓ + 右缘 CHANGE 蓝字（由占位 toast 改为打开选择分支页）
2. **Choose Branch 页**（branchPicker，`repo` 角色形态）：
   - 头部：✕（关回仓库详情）+ 粗体标题 Choose Branch + 右上 **CONTRIBUTE** 蓝字钮（仅 repo 角色显示）
   - 常驻搜索行（既有）
   - 分支行（既有渲染复用）：浅蓝 mono 分支芯片 + Default 描边徽标 + 当前分支蓝底白勾（pCurrent=默认分支）
3. **Compare changes 页**（prCompare 既有页面，零改动复用）：✕ + 两行标题 + base/compare 选择 + 空态卡「Choose a branch to compare changes」（compare 未选时）

---

## 三、元素清单

可行性：7/7 全部可行

| # | 位置 | 元素 | 功能 | 可行性 | 接口 | 备注 |
| --- | ------ | ------ | ------ | -------- | ------ | ------ |
| 1 | RepoDetail 分支行 | CHANGE 蓝字 | 打开 Choose Branch（branchPicker，role=repo，pCurrent=默认分支） | ✅ | — | 替换现占位 toast；路由参数 `repo\|owner\|name\|default`，parsePickerParam 自由段零改动 |
| 2 | Choose Branch 头部 | ✕ | 关回仓库详情 | ✅ | — | 既有行为 |
| 3 | Choose Branch 右上 | CONTRIBUTE 蓝字钮 | 进入 Compare changes 页 | ✅ | — | push `prCompare`（`owner\|name`，与 RepoDetail 顶栏「New pull request」同格式）；**仅 repo 角色显示**（base/head 角色来自 prCompare 内部选择，官方该场景无此钮） |
| 4 | Choose Branch 头部 | 标题 Choose Branch | 角色化标题 | ✅ | — | 新增 `picker_repo_title`（与 base 角色现值同字面、独立 key） |
| 5 | Choose Branch 列表 | 分支行（芯片/Default 徽标/蓝勾） | 分支浏览 | ✅ | `fetchBranches`（既有） | 渲染机制全复用；pCurrent=默认分支 → 默认分支行徽标+蓝勾并存（对齐官方截图） |
| 6 | Choose Branch 列表 | 分支行点击 | repo 角色不落选择 | ✅ 纯 UI | — | 官方为切换查看分支；ArkCat RepoDetail 尚无按分支查看能力（§五），行点击不响应、不关页 |
| 7 | Compare changes 页 | 整页复用 | base=默认分支、compare 空 → 空态卡 | ✅ | — | 与新建 PR 动线零差异；✕ 返回 Choose Branch（路由栈语义） |

---

## 四、核心接口

> 无新增接口：分支列表复用 `RepoSubService.fetchBranches`（GraphQL）；prCompare 整页复用（Spec 043 既有查询）。

---

## 五、边界 / 不可行项

| 项 | 原因 | ArkCat 处理方式 |
| ---- | ---- | ------------------- |
| repo 角色分支行点击切换查看 | 官方点击=切换仓库详情/代码的查看分支；ArkCat RepoDetail 当前无按分支查看能力（Current branch 行仅展示默认分支） | 本期该页承载「分支浏览 + CONTRIBUTE 入口」，行点击不响应、不关页；分支切换查看后续单独立 spec |
| base/head 角色显示 CONTRIBUTE | 该两角色来自 prCompare 内部 base/compare 选择，官方该场景无 CONTRIBUTE | CONTRIBUTE 仅 `role=repo` 渲染 |
| CONTRIBUTE 后 ✕ 的返回层 | NavDestination 路由栈 push 语义 | ✕ 返回 Choose Branch（非直接回仓库详情），与「复用即可」口径一致 |

---

## 六、TDD 验收标准

- [x] bash scripts/check-spec.sh 通过
- [x] 宿主单测不回归（bash scripts/ut/run-local-tests.sh）
- [x] 模拟器：RepoDetail 分支行 CHANGE → Choose Branch（标题/CONTRIBUTE 钮/默认分支徽标+蓝勾/搜索过滤）
- [x] 模拟器：CONTRIBUTE → Compare changes 空态「Choose a branch to compare changes」，base=默认分支、compare=SELECT BRANCH
- [x] 模拟器：Choose Branch 分支行点击不关页、无副作用；✕ 返回仓库详情；Compare changes ✕ 返回 Choose Branch
- [x] 回归：prCompare 内 base/head 分支选择回传（BranchPickResult 槽）不回归
- [x] base/zh_CN 新增 key 对齐；硬编码颜色/字号门禁通过

---

## 七、备注

- **路由参数**：branchPicker 参数 `role|owner|name|current` 的 role 为自由段，新增 `repo` 值 Index.ets 零改动；prCompare 复用 `owner|name` 两段格式（RepoDetail 顶栏菜单同款）。
- **CONTRIBUTE 样式**：蓝字 body 14 + 600 + uppercase（FilterActivity SAVE 同款）；标题 Choose Branch 新 key `picker_repo_title`（base 角色现值恰好同字面，独立 key 防语义耦合）。
- **官方对照**：截图 2=Choose Branch（main 行 Default 徽标+蓝勾并存、CONTRIBUTE 右上）；截图 1=Compare changes 空态（base: main / compare: SELECT BRANCH / 绿色 PR 图标空态卡）——第 5/7 元素即此两态。
- 纯路由接线无新增纯函数，宿主单测仅回归不新增。
