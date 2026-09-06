# Spec 050: Home 个性化（Favorites 收藏 + Shortcuts 快捷入口）

> BFS Level: 3
> 关联截图: 官方 Home：Favorites 卡片列（用户自定义）、Shortcuts 格、My Work（现有 013 已实现）
> 上游 Spec: 013（Home 官方布局）、016（Edit My Work）
> 状态: draft（2026-09-02 规划；与 049 有缓存键协作，可后置）

---

## 一、页面/功能概述

Home 现有：My Work（可编辑，016）+ Favorites 空态 + Shortcuts 静态引导。本 Spec：**Favorites 从空态到真功能**（收藏任意 repo/user/org → Home 卡片列：星标/头像/名字/描述 + 进入详情；长按/编辑模式删除、排序、改别名）+ **Shortcuts 个性化**（官方 Shortcuts：Issues/PRs/Discussions… 可编辑展示/顺序/显示隐藏；两行 2×4 格）。数据本地持久化（账号隔离 per 049）。

---

## 二、整体 UI 结构

```text
Home
┌─────────────────────────────────────┐
│ My Work（已有 013/016，不变）          │
├─────────────────────────────────────┤
│ Favorites（N 项）                    │
│  ├─ 卡片横滑：★ 仓库名 | 描述 | 星数    │
│  │  点击 → 详情                       │
│  │  长按/右键菜单：删除/置顶/改备注      │
│  └─ 「+ Add」→ 搜索收藏对象页          │
│      （按类型 tab：仓库/用户/组织）      │
├─────────────────────────────────────┤
│ Shortcuts（2×4 格）                  │
│  ├─ 现有静态格换成可配置格（icon/标题）  │
│  └─ 编辑模式（拖拽排序/隐藏/恢复）       │
└─────────────────────────────────────┘
```

---

## 三、元素清单

| # | 位置 | 元素 | 功能 | 可行性 | 接口 | 备注 |
| --- | ------ | ------ | ------ | -------- | ------ | ------ |
| 1 | Home | Favorites 卡片列表 | 本地模型渲染卡片（仓库：名称/描述/star；用户：头像/登录；组织同） | ✅ | 无（本地 + 打开时刷新数据接口） | 卡片复用 RepoCard（isPinned 变体已有） |
| 2 | Home | Add Favorite 入口 | 「+」→ 搜索页（收藏目标）→ 选中加入列表 + 去重提示 | ✅ | search（046 共用） | 若 046 未完成则用现有 repo search 兜底 |
| 3 | Home | 收藏管理 | 编辑模式（长按进入）：删除/上移/置顶；别名备注 | ✅ | 无 | 本地 @StorageLink 持久化 |
| 4 | Home | Shortcuts 数据 | 预置动作集（Starred/Issues/PRs/Discussions/Projects/Profile/搜索/代码浏览）+ 用户配置（顺序/隐藏） | ✅ | 无 | 动作→路由映射表 |
| 5 | Home | Shortcuts 编辑 | 编辑模式：隐藏/显示/排序（拖拽）/恢复默认 | ✅ | 无 | 沿用 016 的拖拽交互样式 |
| 6 | Home | 空态 | 无收藏/无快捷时显示引导文案（现空态按钮接通） | ✅ | 无 | —— |
| 7 | 数据 | 账号隔离 | favorites/shortcuts 存储按 login 分区（049 的 login 缓存键） | ✅ | 无 | —— |
| 8 | 数据 | 云端同步 | 官方 Favorites 行为（云端/账号）未证实有 API | ❌ | 无 | 本地 only；备注官方移动端为「本机配置」表现调研待补 |

> 可行性: 7/8 可行（云端同步 ❌ 不做）

---

## 四、核心接口片段

```text
# 本地模型（Preferences/StorageLink 持久化）
Favorites = [{ type: 'repo'|'user'|'org', key: 'owner/name'|'login',
               alias?: string, addedAt: number, pinned?: boolean }]
Shortcuts  = [{ id: 'starred'|'issues'|'prs'|'discussions'|'projects'|'profile'|'search'|'files',
                visible: boolean, order: number }]
# 读取数据时用现有 Service 按 key 拉最新（star 数/头像）
```

---

## 五、边界 / 不可行项

| 项 | 原因 | StarRaft 处理方式 |
| ---- | ------ | ------------------- |
| Favorites 官方云端同步 | 无公开 API 佐证（移动端观感偏本机） | 本地持久化；跨设备不保证，备注说明 |
| 收藏对象加载失败（被删/私有） | —— | 卡片显示「不可用」+ 可删除 |
| 官方 Shortcuts 语义（产品内固定） | 官方 shortcut 为内置固定动作 | 允许隐藏/排序/恢复，不开放自定义外部动作 |
| 收藏数量上限 | 队列溢页 | 20 个上限 + 提示「移除后加入」 |

---

## 六、TDD 验收标准

- [ ] 测试 1：Add 收藏（仓库）后 Home 出现卡片；再次添加同 key 提示重复且不入列
- [ ] 测试 2：收藏卡片点击 → RepoDetail（user/org 同理跳转）
- [ ] 测试 3：长按进入编辑模式：删除/置顶生效，顺序持久化
- [ ] 测试 4：收藏对象不存在（mock 404）卡片显示不可用且可删除
- [ ] 测试 5：Shortcuts 隐藏项在编辑模式显示灰态；恢复默认还原 8 项初始顺序
- [ ] 测试 6：切账号（049）后 favorites 列表分区（A 收藏不出现于 B）
- [ ] 测试 7：Home 空态文案两处双份 i18n；check-spec 通过

---

## 七、备注

- 复用 016 的拖拽交互（EditMyWork 已有 Drag/Order 模式，直接把编辑模式组件抽公共）。
- 官方 2026-06 前后 Home 卡片布局调整（pinned 卡片）方向不同——按 013 现有布局保持，本 Spec 仅在“功能接通”层面。
- 卡片刷新：进入 Home 时拉一次（缓存 5min 内不重拉），避免收藏数量大时慢。
