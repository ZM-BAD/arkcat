# Spec 061: 全应用分享按钮统一走系统分享面板

> BFS Level: 1
> 关联截图: 无官方参考图——官方 App 各页顶栏 share 图标与底部 Share 按钮一律拉起系统分享面板（复刻目标行为）
> 上游 Spec: 005（用户主页）、011（代码查看器）、031（PR 详情）、038（文件树）、047（Release 详情）、052（成就详情）
> 状态: approved
> 用户 2026-09-11 定调：**所有分享按钮都走系统分享面板**——此前同图标在不同页面给出四种反应
> （系统面板／复制内容／复制链接／占位 toast），用户无法预期，本批收口为单一行为。

---

## 一、页面/功能概述

把全 App 10 个分享入口（8 个顶栏 share 图标 + 成就页底部 Share 按钮 + Release 资产行 Share 按钮）
统一为「点击 → 拉起 HarmonyOS 系统分享面板（ShareKit）」，分享目标为**当前页面的 github.com 地址**
（文件类入口分享该文件地址，Release 资产行走既有文件分享）。此前同一图标在不同页面分别执行
占位 toast、复制内容、复制链接、系统面板四种动作，交互不可预期；本批只改分享动作本身，不改版面、
不改图标资源、不改各页 ⋮ 菜单（复制链接/复制内容语义保留）。
> Issue 详情顶栏原本没有 share 图标（用户 2026-09-11 追加要求补上，与 PR 详情同形），故本批入口由 9 变 10。

---

## 二、整体 UI 结构

1. 顶栏 share 图标（用户主页/组织主页/文件树/代码查看页/Commit 详情/PR 详情/Release 详情/Issue 详情）：
   位置、尺寸、无障碍标签不动，仅 onClick 从「toast / 复制」改为拉起系统分享面板；
   图标资源与着色随后由 Spec 062 统一为 `oct_share_android_16` + `link_blue`
2. 成就详情页底部 Share 按钮：版面不动，实现改走统一工具（行为不变，仍为系统面板）
3. Release 详情资产行（下载完成态）：Share 按钮版面不动，实现改走统一工具（仍分享缓存文件）
4. 系统面板本身由 HarmonyOS 提供（预览卡 + 目标应用列表），App 不自绘、不控制其样式

---

## 三、元素清单

| # | 位置 | 元素 | 功能 | 可行性 | GraphQL 接口 | 备注 |
| --- | ------ | ------ | ------ | -------- | ------------- | ------ |
| 1 | 用户主页顶栏 | share 图标 | 分享 `https://github.com/{login}` | ✅ | — | 本人/他人主页同一行为（登录名即参数 `login`） |
| 2 | 组织主页顶栏 | share 图标 | 分享 `https://github.com/{login}` | ✅ | — | 组织与用户主页同形 URL |
| 3 | 文件树顶栏 | share 图标 | 分享当前目录地址（根=仓库主页，子目录=`tree/HEAD/{path}`） | ✅ | — | 顺带修 `findUrl()` 忽略 `dirPath`（子目录曾分享成仓库首页） |
| 4 | 代码查看页顶栏 | share 图标 | 分享文件地址 `blob/HEAD/{path}` | ✅ | — | 原为「复制文件全文」；复制内容仍在 ⋮ Copy contents |
| 5 | 文件树/代码页 ⋮ | Copy link 菜单项 | 复制同一地址到剪贴板 | ✅ | — | 菜单语义不变（剪贴板复制保留，不改为分享） |
| 6 | Commit 详情顶栏 | share 图标 | 分享 `commit/{oid}` | ✅ | — | 预览标题 = commit headline（详情未载入时回落 URL） |
| 7 | PR 详情顶栏 | share 图标 | 分享 `pull/{number}` | ✅ | — | 预览标题 = `owner/name #number` |
| 8 | Issue 详情顶栏 | share 图标（本批新增） | 分享 `issues/{number}` | ✅ | — | 预览标题 = issue 标题（详情未载入时回落 URL）；顶栏图标口径见 062 |
| 9 | Release 详情顶栏 | share 图标 | 分享 `Release.url` | ✅ | `repository.release { url }` | 原为复制 release 链接 |
| 10 | Release 资产行 | Share 按钮 | 分享已下载的缓存文件（`general.file` + 沙箱 URI） | ✅ | — | 面板拉起失败降级复制文件 URI（047 既有约定保留） |
| 11 | 成就详情页底部 | Share 按钮 | 分享 `?achievement={slug}&tab=achievements` 页面 | ✅ | — | 052 已落地，本次收口到统一工具 |
| 12 | 全 App | 分享实现单一出口 | `utils/Share.ets`：`shareLink` / `shareFile` + 7 个页面地址构造函数 | ✅ | — | 面板失败统一 toast「无法拉起分享面板」（`share_failed`） |
| 13 | Settings | Share Feedback 行 | 不改为系统分享 | ⚠️ | — | 官方语义是提交反馈表单、非分享内容；维持占位（见第五章） |
| 14 | 共享工具 | 宿主单测 | 7 个地址构造函数断言（含根目录回落） | ✅ | — | `npm run test:ut`，本轮 78/78 |

> 可行性图例：✅ 可直接实现 ｜ ⚠️ 部分可行/降级 ｜ ❌ 不可实现
>
> **13/14 可行**（唯一 ⚠️ 为 Settings 的 Share Feedback：语义不是分享内容，本批不并入）。

---

## 四、核心 GraphQL 片段

无新增查询：新增分享动作所需的页面地址全部由本地参数拼装（owner/name/oid/number/login/path）。
唯一来自接口的地址是 Release 详情的 HTML 直链，复用 Spec 047 已选字段：

```graphql
query ReleaseDetail($owner: String!, $name: String!, $tag: String!) {
  repository(owner: $owner, name: $name) {
    release(tagName: $tag) {
      url          # Release 的 github.com HTML 直链（分享用）
    }
  }
}
```

---

## 五、边界 / 不可行项

| 项 | 原因 | ArkCat 处理方式 |
| ---------------------- | -------------------------------------------------- | ------------------------------------------------------------ |
| Settings 的 Share Feedback | 官方该行语义为提交反馈表单，不是分享内容 | 维持 coming-soon 占位，待反馈表单 Spec；不并入系统分享 |
| 文件树/代码页的 ref | 页面未持有当前 ref（默认分支即 HEAD） | 地址统一用 `HEAD`；与既有 Copy link 行为一致，不新增 ref 参数 |
| 代码查看页原分享内容 | 顶栏 share 原为复制文件全文 | 分享改为文件地址（与其它页一致）；复制全文保留在 ⋮ Copy contents，能力不丢失 |
| 系统面板不可自绘 | ShareKit 面板由系统提供，样式与目标应用列表不可控 | 只投递数据（`SharedData`）；预览模式/单选目标用系统默认值 |
| 面板拉起失败 | 用户侧失败或系统异常（无可用目标、异常） | 统一 toast「无法拉起分享面板」；文件分享额外降级复制文件 URI（047 约定） |
| 分享入口的 URL 为空 | 参数缺失（如 login 空串）或详情未载入 | `shareLink` 对空 URL 静默返回，不弹面板也不提示 |

---

## 六、TDD 验收标准

- [x] 测试 1：`npm run test:ut` 全绿（78/78，本轮新增 2 条用例：7 个地址构造函数 + 根目录回落断言）
- [x] 测试 2：`bash scripts/check-spec.sh` 通过；`python3 scripts/check-hardcoded-colors.py` 0 处命中
- [x] 测试 3：`devecocli build` 全量构建通过
- [x] 测试 4：全仓 grep `shareLink|shareFile` 后，8 个顶栏 share 图标已无 `home_feature_coming` 占位（剩余占位只在各页 ⋮ 菜单）
- [x] 测试 5：目录子路径分享地址带 `tree/HEAD/{path}`（宿主单测断言），修掉 `findUrl()` 忽略 `dirPath` 的旧缺陷
- [ ] 测试 6：模拟器实测——用户主页/组织主页/文件树/代码页/Commit/PR/Release/Issue 八个顶栏 share 点击均拉起系统面板，预览卡显示对应链接
- [ ] 测试 7：模拟器实测——成就页 Share 与 Release 资产行 Share 仍拉起系统面板（文件分享面板显示文件名）
- [ ] 测试 8：模拟器实测——Release 资产行分享取消/失败时降级为复制文件 URI 并 toast「链接已复制」
- [ ] 测试 7：模拟器实测——成就页 Share 与 Release 资产行 Share 仍拉起系统面板（文件分享面板显示文件名）
- [ ] 测试 8：模拟器实测——Release 资产行分享取消/失败时降级为复制文件 URI 并 toast「链接已复制」

---

## 七、备注

- **行为统一口径**：分享数据 = 当前页面的 github.com 地址（`HYPERLINK`），文件 = 沙箱 URI（`general.file`）；
  两类都由 `utils/Share.ets` 投递，页面不再各自拼 ShareKit 调用。取不到 UIAbilityContext（如 preview 场景）
  或 URL 为空时静默返回，避免预览/异常路径误弹面板。
- **单一出口的好处**：面板选项（预览卡 + 单选目标）、失败提示、空值守卫只有一份实现；页面地址构造函数是
  纯函数，由宿主单测覆盖（`scripts/ut/unit.test.ts`），页面层只传参。
- **刻意不动的东西**：各页 ⋮ 菜单的 Copy link / Copy contents 仍是剪贴板语义（用户要的是「复制」而不是「分享」）；
  面板样式与无障碍标签未改；顶栏图标资源与配色在本批之后由 Spec 062 统一（share-android + 蓝竖三点）。
  Release 顶栏从「复制链接」变为「分享」后，其 ⋮/菜单中的复制入口保持可用，功能不丢。
- **与官方的一致性**：官方 App 的分享一律是系统分享面板（iOS 为 UIActivityViewController，Android 为
  Intent chooser），本批把「占位/复制」补齐成官方行为，属于提升还原度，不是增强。
- **无需清单声明**：ShareKit 系统面板不申请任何权限（`module.json5` 仅保留 `ohos.permission.INTERNET`），
  与 047/052 既有可用事实一致。
- **资源变更**：新增 `share_failed`（base/zh_CN 双份）；移除仅被 052 旧实现使用的 `achievement_share_failed`
  （成就页失败提示并入统一文案）。
- **待走查**：第六章测试 6-8 为模拟器实测项，走查通过后本 Spec 置 `implemented`。
  **2026-09-11 自测留痕**：File Tree 分享 → 系统面板预览卡标题 `freeCodeCamp/freeCodeCamp`；
  Issue 详情分享 → 预览卡标题为 issue 标题「issue with step 23 of workshop-greeting-card」；两处均正常拉起面板。
