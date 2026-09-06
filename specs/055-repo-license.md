# Spec 055: 仓库 License 正文页

> BFS Level: 2
> 关联截图: 三图批次第 3 张（ponytail License）
> 上游 Spec: 006（仓库详情页 More 折叠区 License 入口）
> 状态: draft

---

## 一、页面/功能概述

点击仓库详情页 More 折叠区中「License」入口行进入许可证正文页：
自绘 AppBar 为「仓库名（灰小字）+ License（黑粗体大字）」——注意与 Contributors/Watchers 页的
文字层级相反（对照截图：灰小字在上、黑大字在下），正文为 licenseInfo.body 全文（段落自然留白）。

---

## 二、整体 UI 结构

1. App Bar：返回按钮 + 仓库名 ponytail（灰小字，上）+ License（黑粗体大字，下）
2. 正文区：许可证全文（正文段落占位，不复制全文）

正文整页 Scroll，无卡片无分割线；StateView（loading/错误重试）；无许可证 → 空态文案。

---

## 三、元素清单

| # | 位置 | 元素 | 功能 | 可行性 | 接口 | 备注 |
| --- | ------ | ------ | ------ | -------- | ------ | ------ |
| 1 | AppBar | ← + 仓库名（灰 16fp，上）+ License（黑粗体 20fp，下） | 返回 / 标题 | ✅ | — | 层级与 Stargazers 页相反（对照截图）；标题复用 repo_license；参数 owner/name |
| 2 | 正文 | licenseInfo.body 全文（body 字号、行高自然段落留白） | 展示 | ✅ | repository.licenseInfo { name spdxId body } | body 首行等于 name（如 "MIT License"）时 strip，正文从 Copyright 起（对照截图） |
| 3 | 状态 | licenseInfo = null → 空态 | 展示 | ✅ | — | repo_license_none（该仓库无许可证） |
| 4 | 列表 | StateView（loading / 错误重试） | 展示 | ✅ | — | 沿用现有 StateView 组件 |

---

## 四、核心 GraphQL 片段

```graphql
query RepoLicense($owner: String!, $name: String!) {
  repository(owner: $owner, name: $name) {
    licenseInfo { name spdxId body }
  }
}
```

---

## 五、边界 / 不可行项

| 项 | 原因 | StarRaft 处理方式 |
| ---- | ------ | ------------------- |
| licenseInfo 为 null | 仓库未声明许可证 | 正文区显示 repo_license_none 空态，头部照常 |
| body 首行为许可证名（如 "MIT License"） | GitHub body 以许可证全名开头，官方截图无此行 | 首行等于 name 时 strip（name 为空不 strip） |
| 许可证 SPDX 未识别 | licenseInfo 名称可能为 "Other" | 标题固定显示 License（非 licenseInfo.name），不做额外处理 |
| 正文超长 | 大型许可证全文较长 | 整页 Scroll，无钳高（纯文本页） |

---

## 六、TDD 验收标准

- [x] 测试 1：mapLicenseInfo：完整 licenseInfo（name/body）→ 字段映射正确
- [x] 测试 2：stripLicenseTitle：body 首行 = name（"MIT License"）→ 去掉首行，正文以 Copyright 开头
- [x] 测试 3：mapLicenseInfo：licenseInfo = null → null（页面显示空态）

---

## 七、备注

- 正文衬线/非衬线照系统默认（截图为正黑体，ArkUI 默认即可）；字号/recommend spacing 按 body_font_size + 段落空行。
- 官方 License 页底部 tab 常驻遮挡正文尾部（延续现状，不处理）。
- 数据仅一个查询，与 Spec 006 详情的 licenseInfo{name spdxId} 字段共源，无需额外 REST。
