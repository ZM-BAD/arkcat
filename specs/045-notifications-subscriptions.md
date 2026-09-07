# Spec 045: 通知与订阅增强（Inbox 高级 + 仓库 Watch）

> BFS Level: 3
> 关联截图: 官方 Inbox 顶部分栏（All/Issues/PRs/Running…）+ 行滑动操作；RepoDetail Bell 状态切换
> 上游 Spec: 002（Inbox）、006（RepoDetail）、032（通知设置）
> 状态: draft（2026-09-02 规划；依赖 002 现状（已实现），纯增强）

---

## 一、页面/功能概述

Inbox（已实现：四类 filter + 单条已读 + 卡片美化）继续补三点：① **通知类型分栏**（issue/PR/讨论/release/mention…）与「全部已读」批量操作；② **点击通知 → 跳转对应对象页**（现仅标已读）；③ 仓库维度的 **Watch/Unwatch 订阅状态**（RepoDetail Bell 从占位变真：`viewerSubscription` 显示 + `updateSubscription` 切换），并让订阅状态与 Inbox「Repository」过滤器联动提示。

---

## 二、整体 UI 结构

Inbox：
1. 顶部：当前过滤器 tabs（已有）+ 新增「类型 chips：Issues/PRs/Releases/讨论」→ 本地过滤
2. 工具栏：「全部已读」(REST PUT /notifications) ｜ 清空已读
3. 列表卡片（已有）→ tap 行为：标记已读 + 路由跳转（issue/PR/discussion/release 对应页面）
4. 行滑动：手滑动过（已有 032 仅本地设置 → 落地为实组件）

RepoDetail：
1. Bell（已有占位）：
   - 未订阅：空心 Bell → tap → 弹「Watch/忽略」（SUBSCRIBED/IGNORED）
   - 已订阅：实心 Bell（viewerSubscription=SUBSCRIBED）

---

## 三、元素清单

| # | 位置 | 元素 | 功能 | 可行性 | GraphQL/REST 接口 | 备注 |
| --- | ------ | ------ | ------ | -------- | ------------------- | ------ |
| 1 | Inbox | 类型分栏 | 通知按 subject.type 本地过滤（Issue/PR/Release/Discussion/Mention/CI） | ✅ | 现有 REST `GET /notifications?participating=true` 返回类型字段 | 客户端过滤不增加请求 |
| 2 | Inbox | 全部已读 | 批量标记（首页 badge 同步刷新） | ✅ | REST `PUT /notifications` | 确认弹窗后执行 |
| 3 | Inbox | 清空已读 | 已读线程不再展示（本地隐藏 + 服务端可选 REST `DELETE`） | ✅ | REST `DELETE /notifications` | 与官方「清空」行为一致（默认只隐藏） |
| 4 | Inbox | tap → 路由 | 通知卡片点击 → IssueDetail/PrDetail/Discussion/Releases 对应页 | ✅ | 无（subject.url 解析） | 路由映射复用 051? 无 051 了 → 本 spec 内建 LinkRouter（见备注） |
| 5 | Inbox | 行滑动操作 | 左滑「已读/未读」「归档」（依托 032 设置的动作选择） | ✅ | REST PATCH /notifications/threads/{id} | 用 ArkUI SwipeAction 组件 |
| 6 | RepoDetail | Watch 状态 | `viewerSubscription`（NONE/SUBSCRIBED/PROTECTED/IGNORED）显示 Bell 态 | ✅ | GraphQL repository.viewerSubscription | PROTECTED 显示「系统订阅」灰态 |
| 7 | RepoDetail | 订阅切换 | 弹层三选：订阅/忽略/取消 → `updateSubscription` | ✅ | 见四 | 切换后 Bell 态 + toast |
| 8 | 设置 | 云端通知偏好 | web 端通知偏好（watch 选项/邮箱开关）不可从移动端改 | ❌ | 无 | 不实现，仅在 032 标注说明 |
| 9 | Inbox | 分页/刷新增强 | 现有列表分页 + 下拉刷新；通知 badge 跨账号刷新 | ⚠️ | 无 | 409 冲突/限流提示；跨账号场景在 049 后启用 |
| 10 | 通知 | 通知位置（happenedAt/lastReadAt）相对时间 | 与 GitHub 官方一致（22h-1d 等，Inbox 已做 09-02） | ✅ | 无 | 保持现状即可 |

> 可行性: 8/10 可行（点击分页增强 ⚠️；云端偏好 ❌；相对时间 ✅ 已实现）

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
# 全部已读
PUT /notifications                        # body 无；Header Last-Event-Date 可选
# 单线程状态
PATCH /notifications/threads/{thread_id}  # {"unread": false|true}
# 清空已读（可选）
DELETE /notifications
```

---

## 五、边界 / 不可行项

| 项 | 原因 | ArkCat 处理方式 |
| ---- | ------ | ------------------- |
| 通知偏好云端设置 | 只有网页端 UI（watch 选项等） | 界面只读说明「请到 github.com 设置」，不模拟 |
| PROTECTED 订阅（机构强制） | API 禁止解除 | Bell 显示锁图标灰态 + toast 说明 |
| 通知实时推送（服务端 → 设备） | 纯端侧项目无法介入推送管线 | 不做；保持 007/002 的「打开刷新」模型；全局轮询仅在前台，不做后台 |
| 跨账号 unread badge | 049 之前单账号 | 049 完成后统一 |
| 无 Notification APIs 的更细粒度过滤（repo 级订阅偏好） | —— | 「Repository 过滤器」已有；仓库过滤标签本地 |

---

## 六、TDD 验收标准

- [ ] 测试 1：类型 chips 过滤后列表计数与预期一致（如 PR 类通知只显示 subject.type==PullRequest）
- [ ] 测试 2：「全部已读」触发 PUT /notifications，Inbox 未读数归零、Home badge 同步
- [ ] 测试 3：点击通知卡片 → 对应详情页（issue/pr/discussion/release）路由正确且该条标记已读
- [ ] 测试 4：左滑动作按 032 用户选定的动作执行（mark read / archive）
- [ ] 测试 5：RepoDetail Bell 三种态渲染（未订阅空心 / SUBSCRIBED 实心 / PROTECTED 锁形）
- [ ] 测试 6：订阅弹层选择后 viewerSubscription 本地更新 + 服务器状态复核
- [ ] 测试 7：分页异常（409/超时）显示重试不崩溃
- [ ] 测试 8：无权限仓库（204 空）Bell 与订阅走降级提示
- [ ] 测试 9：i18n 双份 + check-spec 通过

---

## 七、备注

- 本 Spec 内含一个共享的 **LinkRouter**（URL → 页面路由解析器）：gitHub.com 链接（/o/r、/o/r/issues|pulls/{n}、/o/r/releases、/o/r/discussions）→ NavPath 映射；后续 046/047/051 都可复用，单独小部件但归本 Spec 交付（避免零散）。
- 官方 2026: Inbox 分栏演进为「Focused/Unread 等」+ 1.249 状态检查改版并入通知；与 048 协作（检查失败通知 → Check 详情）在 048 中处理，跨档不重复。
