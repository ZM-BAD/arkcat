# Spec 045: 通知与订阅增强（Inbox 批量管理 + 仓库 Watch）

> BFS Level: 3
> 关联截图: 官方 Android 实机五图（2026-09-22）——Inbox 列表常态（过滤条 Inbox∨/Focused/Unread/Repository∨）、长按行进入多选态（顶栏 ×+1 selected+●+✓+⋮、行首勾选圈、选中行浅蓝底）、多选态 ⋮ 弹出 Select all/Deselect all、常态顶栏 ⋮ 弹出 Refresh、行滑动两态（左滑绿底白勾 Done / 右滑灰底斜线铃铛 Unsubscribe）；RepoDetail Bell 状态切换沿用官方仓库页样式
> 上游 Spec: 002（Inbox）、006（RepoDetail）、032（通知设置）
> 状态: draft（2026-09-02 规划；2026-09-22 按官方 Android 实机截图定稿交互——多选批量、顶栏 Refresh、左右滑动）

---

## 一、页面/功能概述

Inbox（002 已实现：四类 filter + 类型/仓库过滤面板 + 单条已读 + 卡片样式）补四块：① **长按多选模式**——官方批量管理的唯一入口（顶栏变形 + 行首勾选圈 + 批量已读/批量 Done + Select all/Deselect all）；② **点击通知 → 跳转对应对象页**（现仅标已读并 toast，本次接通路由）；③ **行滑动**——左滑 Done、右滑 Unsubscribe；④ 常态顶栏 ⋮ 接通 Refresh。仓库维度另做 **Watch/Unwatch 订阅状态**（RepoDetail Bell 从空占位变真：`viewerSubscription` 显示 + `updateSubscription` 切换）。

官方 Inbox 无独立「全部已读」工具栏、无通知类型分栏 chips——类型过滤已由 002 的 Inbox ∨ 面板承载，本 spec 不再新增官方样式之外的操作入口。

---

## 二、整体 UI 结构

Inbox（常态结构沿用 002，本 spec 只改交互层）：

1. 顶部：常态顶栏 = 「Inbox」大标题 + 右上蓝竖三点 ⋮ → bindMenu 弹「Refresh」单项（重拉通知列表 + 角标刷新；Spec 048 同款配方，现状空占位接通）
2. 过滤条：Inbox ∨ / Focused / Unread / Repository ∨ 四胶囊（002 已交付，不动）
3. 列表：通知行卡（002 已交付）；本 spec 接入四种手势——
   - **tap**：标记该条已读 + 经 LinkRouter 跳转对应详情页（Issue / PR / Discussion / Release）
   - **长按**：进入多选模式
   - **左滑**：整行左移露出绿底白勾全高色块 → 松手标记 Done，行移除
   - **右滑**：整行右移露出灰底白斜线铃铛全高色块 → 松手退订该线程（Unsubscribe），行保留
4. **多选模式**（覆盖常态顶栏与过滤条）：
   - 顶栏变形：左侧 ×（退出多选）+ 「N selected」；右侧 ●（批量已读/未读切换）+ ✓（批量 Done）+ ⋮（Select all / Deselect all）
   - 过滤条隐藏，列表整体进入选择态
   - 行首出现圆形勾选圈（原类型图标右移让位）：未选 = 灰描边空心圈；选中 = accent 蓝底白勾，整行浅蓝选中底色
   - 点行切换选中态；× 或 Deselect all（清空后）退出回常态

RepoDetail（顶栏 Bell，现状 `RepoDetail.ets` 空占位）：

1. Bell 按订阅态渲染：未订阅 = 空心 Bell；SUBSCRIBED = 实心 Bell；PROTECTED = 锁形灰态；IGNORED = 斜线 Bell 灰态
2. tap Bell → 订阅弹层（订阅 / 忽略 / 取消订阅）→ `updateSubscription` → Bell 态更新 + toast

---

## 三、元素清单

| # | 位置 | 元素 | 功能 | 可行性 | GraphQL/REST 接口 | 备注 |
| --- | ------ | ------ | ------ | -------- | ------------------- | ------ |
| 1 | Inbox 顶栏（常态） | ⋮ 菜单 | 弹「Refresh」单项，重拉通知列表 + 角标刷新 | ✅ | 现有 `GET /notifications` | 002 已交付（bindMenu 纯文字单顶），045 保持现状 |
| 2 | Inbox 列表 | 长按行进入多选模式 | 顶栏变形「× + N selected + ● + ✓ + ⋮」，过滤条隐藏 | ✅ | 无（纯端侧交互态） | 长按为官方批量管理唯一入口 |
| 3 | 多选·列表行 | 行首勾选圈 | 未选灰空心圈 / 选中蓝底白勾 + 整行浅蓝底；点行切换选中 | ✅ | 无 | 选中底色走 accent 相关 token，禁硬编码 |
| 4 | 多选顶栏 | ⋮ 菜单 | Select all / Deselect all 两项纯文字菜单 | ✅ | 无 | 原生 bindMenu（Spec 048 同款配方） |
| 5 | 多选顶栏 | ● 批量已读/未读 | 按选中集主导态取反，批量标记 | ✅ | REST `PATCH /notifications/threads/{id}` | 全选场景可优化为单发 `PUT /notifications`；完成后角标联动（`inboxUnreadTick`） |
| 6 | 多选顶栏 | ✓ 批量 Done | 选中项标记完成，行从列表移除 | ✅ | REST `DELETE /notifications/threads/{id}` | 无批量端点，逐线程 `runBounded` 有界并发；注意 429 降级 |
| 7 | Inbox 列表 | tap → 已读 + 路由 | 通知卡点击 → 标已读并跳对应页：issue/pr 走原生详情路由；release 由 REST 数字 id 换 tagName 后跳 ReleaseDetail（失败降级 Releases 列表页）；discussion 经内嵌浏览器打开网页版（App 无讨论详情页） | ✅ | REST `GET /repos/{o}/{n}/releases/{id}`（release 换 tag） | LinkRouter（本 spec 交付，见七章）按 subject.type 分派 |
| 8 | Inbox 列表 | 左滑 Done | 露绿底白勾全高色块，松手标记 Done，行移除 | ✅ | REST `DELETE /notifications/threads/{id}` | ArkUI SwipeAction；与多选 ✓ 同一落库路径 |
| 9 | Inbox 列表 | 右滑 Unsubscribe | 露灰底白斜线铃铛全高色块，松手退订线程，行保留 | ✅ | REST `DELETE /notifications/threads/{id}/subscription` | 图标 `oct_bell_slash_16` 已在 assets；色块灰走 token |
| 10 | RepoDetail | Bell Watch 状态 | `viewerSubscription`（NONE/SUBSCRIBED/PROTECTED/IGNORED）驱动 Bell 四态 | ✅ | GraphQL `repository.viewerSubscription` | PROTECTED 显示锁形灰态（机构强制，API 禁改） |
| 11 | RepoDetail | 订阅切换弹层 | 三选：订阅/忽略/取消 → `updateSubscription` | ✅ | 见四 | 切换后 Bell 态本地更新 + toast |
| 12 | 设置 | 云端通知偏好 | web 端通知偏好（watch 选项/邮箱开关）移动端不可改 | ❌ | 无 | 不实现，仅在 032 页面加只读说明「请到 github.com 设置」 |
| 13 | Inbox | 分页/刷新增强 | 现有分页 + 下拉刷新；批量操作后角标跨页同步 | ⚠️ | 无 | 409 冲突/限流显示重试不崩溃；跨账号 badge 在 049 后统一 |
| 14 | Inbox | 相对时间（lastReadAt 基准） | 与官方一致（14h/2d/7d 等） | ✅ | 无 | 已实现（09-02），保持现状 |

> 可行性: 12/14 可行（分页增强 ⚠️；云端偏好 ❌；相对时间已实现）

---

## 四、核心接口片段

```graphql
query RepoSub($owner: String!, $name: String!) {
  repository(owner: $owner, name: $name) {
    id
    viewerSubscription
    isSubscribed
  }
}
mutation SetWatch($repoId: ID!, $state: SubscriptionState!) {
  updateSubscription(input: { subscribableId: $repoId, state: $state }) {
    subscribable { id ... on Repository { viewerSubscription isSubscribed } }
  }
}
```

```rest
# 全部已读（多选全选 + ● 的单发优化路径）
PUT /notifications
# 单线程已读/未读切换（● 逐线程路径）
PATCH /notifications/threads/{thread_id}   # {"unread": false|true}
# 单线程标记 Done（✓ 与左滑，无批量端点，逐线程调用）
DELETE /notifications/threads/{thread_id}
# 单线程退订（右滑 Unsubscribe，停止该线程后续通知）
DELETE /notifications/threads/{thread_id}/subscription
```

---

## 五、边界 / 不可行项

| 项 | 原因 | ArkCat 处理方式 |
| ---- | ------ | ------------------- |
| 通知偏好云端设置 | 只有网页端 UI（watch 选项等） | 界面只读说明「请到 github.com 设置」，不模拟 |
| PROTECTED 订阅（机构强制） | API 禁止解除 | Bell 显示锁图标灰态 + toast 说明 |
| 通知实时推送（服务端 → 设备） | 纯端侧项目无法介入推送管线 | 不做；保持「打开刷新」模型；全局轮询仅前台，不做后台 |
| 跨账号 unread badge | 049 之前单账号 | 049 完成后统一 |
| 批量 Done 无批量端点 | REST 仅提供单线程 DELETE | 多选 N 条时 `runBounded` 有界并发逐线程调用；429/409 按失败项提示，成功项保留结果不整批回滚 |
| Done 后行为 | Done 通知不再出现在默认 Inbox | 本地同步移除该行；下拉刷新以服务端为准 |
| Unsubscribe 语义 | DELETE subscription 仅停止该线程后续通知，不影响已存在的通知 | 行保留、样式不变；下次刷新以服务端为准 |

---

## 六、TDD 验收标准

- [ ] 测试 1：常态顶栏 ⋮ → 弹出 Refresh 单项，点击重拉列表且未读角标刷新
- [ ] 测试 2：长按通知行进入多选模式——顶栏显示「N selected」、行首出现勾选圈、过滤条隐藏；点 × 退出还原
- [ ] 测试 3：⋮ 菜单 Select all 后选中计数 = 当前列表行数；Deselect all 清空全部选中
- [ ] 测试 4：● 批量已读——选中行逐线程 PATCH 置 unread=false，行样式更新，Inbox 角标经 `inboxUnreadTick` 归零联动 Home
- [ ] 测试 5：✓ 批量 Done——选中行逐线程 DELETE 后从列表移除；部分失败（429）时成功项保留、失败项提示
- [ ] 测试 6：tap 通知卡 → LinkRouter 按 subject.type 路由正确（issue/pr/discussion/release 四类各一）且该条标记已读
- [ ] 测试 7：左滑行 → 露绿底白勾色块，松手标记 Done、行移除（与多选 ✓ 等效）
- [ ] 测试 8：右滑行 → 露灰底斜线铃铛色块，松手 DELETE subscription 成功、行保留
- [ ] 测试 9：RepoDetail Bell 四态渲染（NONE 空心 / SUBSCRIBED 实心 / PROTECTED 锁形 / IGNORED 灰态）
- [ ] 测试 10：订阅弹层选择后 `viewerSubscription` 本地更新 + 服务器状态复核一致
- [ ] 测试 11：分页异常（409/超时）显示重试不崩溃
- [ ] 测试 12：i18n 双份（base/zh_CN）+ `bash scripts/check-spec.sh` 通过

---

## 七、备注

- 本 Spec 内含一个共享的 **LinkRouter**（URL → 页面路由解析器）：`github.com` 链接（`/o/r`、`/o/r/issues|pulls/{n}`、`/o/r/releases`、`/o/r/discussions`）→ NavPath 映射；后续 046/047 均可复用，作为独立小部件归本 Spec 交付。
- 常态顶栏 ⋮ 与多选顶栏 ⋮ 均为原生 bindMenu 纯文字菜单（Spec 048 配方）；左滑/右滑色块为全高、无文字、仅居中白色图标，底色分别走 success 绿 / 中性灰 token，样式定值以 DESIGN.md 令牌为准。
- 订阅状态与 Inbox「Repository」过滤器的联动提示：watch 状态变化不主动改过滤条件，仅 toast 提示可在 Inbox ∨ 面板按仓库过滤。
- 官方 2026 演进：Inbox 分栏持续演进（Focused/Unread 已对齐）；1.249 状态检查改版并入通知——检查失败通知 → Check 详情的协作在 048 处理，跨档不重复。
