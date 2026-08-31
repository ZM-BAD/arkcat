# Specs 目录

> StarRaft 项目所有页面/功能的 Spec 文档

## 文件命名规范

- 格式：`NNN-name.md`（三位数字递增，短横线分隔）
- 模板：[`_TEMPLATE.md`](_TEMPLATE.md)

## Spec 索引

| 编号 | 文件 | 描述 | BFS Level | 状态 |
|------|------|------|-----------|------|
| 001 | [home-tab.md](001-home-tab.md) | 首页 Tab（已被 013 替换） | Level 1 | deprecated |
| 002 | [inbox-tab.md](002-inbox-tab.md) | 通知收件箱 Tab | Level 1 | ✅ |
| 003 | [explore-tab.md](003-explore-tab.md) | 发现探索 Tab | Level 1 | ✅ |
| 004 | [copilot-tab.md](004-copilot-tab.md) | AI 助手 Tab | Level 1 | ✅ |
| 005 | [user-profile.md](005-user-profile.md) | 用户个人主页 | Level 3 | ✅ |
| 006 | [repo-detail.md](006-repo-detail.md) | 仓库详情页 | Level 3 | ✅ |
| 007 | [issues-list.md](007-issues-list.md) | Issue 列表页 | Level 3 | ✅ |
| 008 | [pr-list.md](008-pr-list.md) | PR 列表页 | Level 3 | ✅ |
| 009 | [pr-detail.md](009-pr-detail.md) | PR 详情页 | Level 3 | ✅ |
| 010 | [pr-diff.md](010-pr-diff.md) | PR Diff / Files Changed | Level 3 | ✅ |
| 011 | [code-viewer.md](011-code-viewer.md) | 代码文件查看页 | Level 3 | ✅ |
| 012 | [i18n.md](012-i18n.md) | 国际化（英/简中，默认英语） | Level 4 | ✅ |
| 013 | [home-official.md](013-home-official.md) | Home Tab 官方布局（My Work/Favorites/Shortcuts） | Level 1 | ✅ |
| 014 | [settings.md](014-settings.md) | Settings 设置页 | Level 3 | ✅ implemented |

## 覆盖率

| 指标 | 数值 |
|------|------|
| 已分析 Spec 数 | 11 |
| 已分析元素总数 | 123+ |
| 核心场景覆盖率 | ~95%（按使用频率加权） |
| GraphQL 可覆盖 | ~85% |
| 需 REST 兜底 | ~15% |

## 不可实现功能汇总

| Tab/页面 | 功能 | 原因 | StarRaft 处理 |
|---------|------|------|--------------|
| Explore | Collections 精选集合 | 无公开 API | MVP 隐藏 |
| Copilot | 全部 Chat 功能 | Copilot API 不公开 | 展示 Empty State |
| User Profile | Packages Tab | 无公开用户级 API | 不展示 |
| Repo Detail | Packages/Settings Tab | 无公开 API / 无意义 | 不展示 |
