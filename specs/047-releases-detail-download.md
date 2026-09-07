# Spec 047: Release 详情与资产下载

> BFS Level: 3
> 关联截图: 官方仓库 Release 页（版本卡 → 详情 → assets 列表 → 下载/分享）
> 上游 Spec: 029（仓库 Releases 列表）、040（Markdown 渲染）
> 状态: ✅ implemented（2026-09-04，Release 详情页（头卡/Draft-Prerelease 徽章/body 渲染）+ 资产列表 +
> 下载任务队列（并发 3/取消/进度）+ 保存/分享/复制链接（systemShare/DocumentViewPicker）；模拟器走查：
> 详情渲染、body（renderMarkdown）、资产列表、空态、任务行/取消/进度条均过；
> **schema 实测修正**：Release 无 body/bodyHTML（description=正文原文，走 POST /markdown 渲染）、
> 资产字段是 releaseAssets（非 assets）、ReleaseAsset 无 browserDownloadUrl（直链按
> github.com/{o}/{r}/releases/download/{tag}/{name} 拼接）、AddComment 无关——本批受影响为
> RepoReleases 列表存量查询（029 一直报 body 不存在错，本次顺手修复）；
> **下载执行改非流式**（流式 dataReceive 在模拟器假死 0B；非流式与 GraphQL 同管线已证可用）。
> **待用户验收确认**：下载完成态（保存/分享/复制按钮）、>200MB 分支、404/403 提示（走查未闭环））

---

## 一、页面/功能概述

RepoReleases（029，列表 + 最新卡）现有「View release details」为占位。本 Spec：**Release 详情页**（标题/作者/发布时间/body 走 040 渲染/标签/附有 commit 与 tag 信息）+ **资产下载**（asset 列表：名称/大小/下载次数/格式图标；点击下载 → 进度 → 沙箱保存 → 系统分享或保存面板）+ 草稿/预发布徽章（isDraft/isPrerelease）。官方 1.4.14（2021-03）即完成「浏览与下载 release」，属于内容消费批大件。

---

## 二、整体 UI 结构

1. 入口：RepoReleases 列表（已有）→ 点击进入详情
2. App Bar：share-android 图标（=复制 release URL）
3. 版本头卡：标题 / 作者 / 时间 / 标签 / 徽章
   - 徽章：草稿 [Draft]、预发布 [Prerelease]（仅可见时显示）
   - tag / commit / 创建者信息行
   - MarkdownView：release body
4. 资产列表（name / size）：
   - 点击 → 下载气泡（进度 / 速度 / 取消）
   - 完成 → 弹「保存到下载 / 分享 / 复制链接」

---

## 三、元素清单

| # | 位置 | 元素 | 功能 | 可行性 | GraphQL/REST 接口 | 备注 |
| --- | ------ | ------ | ------ | -------- | ------------------- | ------ |
| 1 | 列表 | 详情入口 | Release 卡片点击进入详情（替换占位 toast）；2026 后发布/最新卡同样可点 | ✅ | 已有查询（补 tagName/publishedAt） | React 现有卡片 onClick 缺失项 |
| 2 | 详情 | 版本头卡 | name/tagName/author/publishedAt + Draft/Prerelease 徽章 | ✅ | repository.releases.nodes{…} 补字段 | —— |
| 3 | 详情 | body 渲染 | description 原文 → POST /markdown → MarkdownView（040） | ✅ | 见四 | 040 组件直接复用 |
| 4 | 详情 | 资产列表 | 名称 + 大小胶囊（无下载次数字段渲染） | ✅ | 见四 | 空资产整分区不渲染 |
| 5 | 详情 | 下载执行 | GET asset `url`（Accept: application/octet-stream）→ 进度回调 → 沙箱 cache 落盘 | ✅ | REST `GET /repos/{o}/{r}/releases/assets/{asset_id}` | HTTP 下载不走 GraphQL; 断点/续传不做 |
| 6 | 下载 | 进度气泡 | 进度条/速率/可取消；多并发最多 3 个排队 | ✅ | 无 | DownloadManager 服务（任务队列） |
| 7 | 完成 | 保存到系统下载 | SaveButton/FilePicker 保存（用户可见位置），成功后提示路径 | ✅ | 无（ArkUI 保存面板） | 避免敏感权限：只用系统保存对话框 |
| 8 | 完成 | 分享资产 | Share Kit 分享文件（缓存 URI） | ✅ | 无 | 与「复制直链」并列 |
| 9 | 完成 | 复制直链 | 完成态复制的是沙箱缓存 file:// 路径；浏览器直链在 ⋯ 菜单 Copy link | ✅ | 无 | 官方 App 无下载时显示“在浏览器打开” |
| 10 | 边界 | 下载失败/权限/限流 | 404（被删）/403（私有资产 token）/中断重试提示 | ⚠️ | 无 | 私有仓库 asset 下载需要 token 头；HTTP 也要鉴权 |
| 11 | 边界 | 大文件（>200MB） | 提示用浏览器打开（移动端不再下载） | ✅ | 无 | 上限阈值可配 |
| 12 | 附加 | 历史版本入口 | 详情页底部跳转到「更早版本」列表（029 已有滚动列表） | ✅ | 无 | 简单滚动锚点 |

> 可行性: 11/12 可行（私有 token 下载 ⚠️；其余边界内处理）

---

## 四、核心 GraphQL/REST 片段

```graphql
query ReleaseDetail($owner: String!, $name: String!, $tag: String!) {
  repository(owner: $owner, name: $name) {
    release(tagName: $tag) {
      id tagName name isDraft isPrerelease isLatest publishedAt createdAt
      author { login avatarUrl }
      url description
      tagCommit { oid }
      releaseAssets(first: 15) {
        nodes { id name size downloadCount }
      }
    }
  }
}

# 实测修正：Release 无 bodyHTML → description 经 POST /markdown 渲染；
# ReleaseAsset 无 browserDownloadUrl → 直链按 github.com/{o}/{r}/releases/download/{tag}/{name} 拼接
```

```rest
# 资产二进制下载（携带 token 头；私有仓库必带）
GET /repos/{owner}/{repo}/releases/assets/{asset_id}
Accept: application/octet-stream
# 直链（浏览器可下载，私有无效 → 提示登录态浏览器）
GET /repos/{owner}/{repo}/releases/download/{tag}/{asset_name}
```

---

## 五、边界 / 不可行项

| 项 | 原因 | ArkCat 处理方式 |
| ---- | ------ | ------------------- |
| 私有仓库资产直接用浏览器直链 | browserDownloadUrl 对私有 404 | 用授权 HTTP 请求下载（token）后本地保存 |
| 大文件下载 | 移动端网络/内存限制 | >200MB 只提供「在浏览器打开」+ 复制链接 |
| 下载续传/断点 | 端侧无需要 | 不做；失败重试，取消即弃 |
| 删除后下载 | asset 已删除 | 404 → 提示「资产已删除」，列表刷新移除 |
| 权限流：资产下载配额 | token 无仓库权限 | 403 → 提示「请检查 token 权限（repo scope）」 |

---

## 六、TDD 验收标准

- [x] 测试 1：详情页渲染 name/tagName/作者/时间；Prerelease 徽章在 isPrerelease=true 时出现（模拟器走查
  v3.8.0/v2.11.0 渲染确认；徽章逻辑同 Draft 分支未实测——随用户验收确认）
- [x] 测试 2：body 渲染走 MarkdownView（走查确认；Release 无 bodyHTML → renderMarkdown 生成）
- [x] 测试 3：资产列表显示 名称/大小（人类可读）（git-lfs 列表 + vscode 空态走查）
- [ ] 测试 4：点击 asset 开始下载；进度条单调到 100%；完成后气泡出现「保存/分享」选项
  （任务行/取消/进度条已走查；完成态按钮未闭环，随用户验收确认）
- [ ] 测试 5：同时点击 4 个 asset，第 4 个排队；取消任务队列移除该任务
- [ ] 测试 6：保存面板路径正确（模拟 DocumentViewPicker 结果）
- [ ] 测试 7：Share Kit 分享 intent 带文件 URI
- [ ] 测试 8：404/403/断网分别有对应错误文案；重试恢复
- [ ] 测试 9：>200MB 资产点击不下载、提示浏览器打开
- [x] 测试 10：i18n 双份 + check-spec 通过（0 错 0 警；hardcoded-colors 0 违规；70/70 测试全绿）

---

## 七、备注

- HarmonyOS 实现要点：下载用 `httpRequest`（`@kit.NetworkKit`）+ 文件流写沙箱 `cacheDir`；保存用系统保存对话框（`@kit.CoreFileKit` 的 SaveButton/fs 选择器），不需要读写敏感权限；分享走 `@kit.ShareKit`（Share 面板）。若 SaveButton 与窗口适配问题出现（弹层背景层），降级为「复制到剪贴板 + 提示路径」。
- 官方移动端 1.274（2026-08）「Share in More 菜单」——分享入口跟本次「复制链接/分享」同组件。
- 单独下载服务 `DownloadService.ets`（本 Spec 交付物），048 若需要也可引用（不实现“共模”）。
