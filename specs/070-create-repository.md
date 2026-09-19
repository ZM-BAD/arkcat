# Spec 070: New repository（创建新仓库）

> BFS Level: 1
> 关联截图: 官方 App 2026-09-20 截图 5 张（General 两步流程 + Choose a template×2 + Choose a license）
> 上游 Spec: 013（Home，「+」菜单入口）
> 状态: reviewing（2026-09-20 实现完成并部署模拟器待验收；走查通过后回写 implemented）

---

## 一、页面/功能概述

Home「+」弹出菜单的 **New repository** 项（现为占位 toast）接通真实创建仓库流程。官方为「自底部弹出的近全屏两步弹层」：第一步 General（Owner / 仓库名 / 描述），第二步 Configuration（可见性开关 / 仓库模板 / README / .gitignore / License），底部两圆点指示步进；第二步内三个选项各拉起自底部的子弹层（模板仓库 / .gitignore 模板 / License），均带搜索与右上 SAVE。无模板时走 REST `POST /user/repos`（GraphQL 无建仓 mutation），选模板时走 GraphQL `createRepositoryFromTemplate`；创建成功关弹层并跳转新仓库详情页。

---

## 二、整体 UI 结构

> 两步在同一弹层内横向切换（官方分页圆点），主弹层与子弹层均自底部弹出（带顶部抓取条）。

1. **General 步**（主弹层第 1 步）
   - 顶部：✕（关闭整个流程）+ 两行标题（New repository 灰字 / General 粗体）+ NEXT 蓝字钮
   - Owner 行：左「Owner」，右 头像 + login（静态展示，整行下细分隔线）
   - Repository name 区：灰色标签 + 无边框输入框（占位 Enter a repository name）+ 提示文案（Great repository names are short and memorable）+ 「0 / 100 characters」计数
   - Description 区：灰色标签（Description (optional)）+ 多行输入框 + 「0 / 350 characters」计数
   - 底部：两圆点分页指示（第 1 点激活）
2. **Configuration 步**（主弹层第 2 步）
   - 顶部：←（回 General）+ 两行标题（New repository / Configuration）+ CREATE 蓝字钮
   - Visibility 区：标题行（Visibility: Private/Public 随开关切换，值为粗体）+ 说明文案
   - Private repository 行：标签 + Switch（默认开，link_blue）
   - 分隔线
   - Start with a template 行：标签 + 右侧 SELECT（选中后回显模板名）
   - 分隔线；未选模板时追加三个初始内容行：
     - Add README 行 + 说明（Can be used for longer descriptions.）+ Switch（默认关）
     - Add .gitignore 行 + 说明（Tells git which files not to track.）+ 右侧 SELECT（选中回显模板名）
     - Add license 行 + 说明（Explains how others can use your code.）+ 右侧 SELECT（选中回显 spdx）
   - 底部：两圆点分页指示（第 2 点激活）
3. **子弹层×3**（自底部弹出，盖在主弹层上）
   - 顶部：✕ + 标题（Choose a template / Choose a license）+ 可选副标题（Repository template / Add .gitignore）+ 右上 SAVE
   - 搜索行：🔍 + 无边框输入框（各层占位不同），下细分隔线
   - 列表：56 高行；License 行=名称 + spdx 灰字，其余=单值行；选中行右缘蓝勾
   - 空态（模板仓库为空）：灰底画布居中粗体「Nothing to see here」

---

## 三、元素清单

可行性：20/20 全部可行

| # | 位置 | 元素 | 功能 | 可行性 | 接口 | 备注 |
| --- | ------ | ------ | ------ | -------- | ------ | ------ |
| 1 | Home「+」菜单 | New repository 菜单项 | 打开主弹层（自底部弹出） | ✅ | — | 替换现占位 toast（Home.ets comingSoon）；官方口径不变 |
| 2 | General 顶栏 | ✕ + 两行标题 + NEXT | ✕ 关整个流程；NEXT 校验后进 Configuration | ✅ | — | 两行头部形态复用 IssueForm（Spec 043）先例 |
| 3 | General·Owner 行 | 「Owner」+ 头像 + login（静态） | 展示当前账号 | ✅ | viewer 基础查询（HomeService.fetchViewerBasic 复用） | 官方无组织时为静态行；组织建仓不在本期（§五） |
| 4 | General·Repository name 区 | 标签 + 输入框 + 提示 + N/100 计数 | 输入仓库名称 | ✅ | — | maxLength 100；无交互白名单校验（服务端 422 兜底） |
| 5 | General·Description 区 | 标签 + 多行输入 + N/350 计数 | 输入描述 | ✅ | — | TextArea 自增高封顶（坑 18） |
| 6 | General 底部 | 两圆点分页指示（第 1 点激活） | 步骤指示 | ✅ | — | 纯 UI |
| 7 | Configuration 顶栏 | ← + 两行标题 + CREATE | ← 回 General（内容保留）；CREATE 创建 | ✅ | — | 步进状态机在弹层组件内 |
| 8 | Configuration·Visibility 区 | 标题（Visibility: Private/Public 动态）+ 说明 | 展示可见性 | ✅ | — | 值随开关实时切换 |
| 9 | Configuration·Private repository 行 | 标签 + Switch（默认开） | 切私有/公开 | ✅ | — | 行点击与 Switch 兄弟拆分（坑 10 防冒泡） |
| 10 | Configuration·Start with a template 行 | 标签 + SELECT（选中回显模板名） | 打开模板仓库子弹层 | ✅ | viewer 仓库 isTemplate 查询 | 选中模板后 README/.gitignore/license 三行隐藏（§五） |
| 11 | Configuration·Add README 行 | 标签 + 说明 + Switch（默认关） | 初始提交带 README | ✅ | REST `auto_init` | |
| 12 | Configuration·Add .gitignore 行 | 标签 + 说明 + SELECT（选中回显模板名） | 打开 .gitignore 子弹层 | ✅ | REST GET /gitignore/templates | |
| 13 | Configuration·Add license 行 | 标签 + 说明 + SELECT（选中回显 spdx） | 打开 License 子弹层 | ✅ | REST GET /licenses | |
| 14 | 子弹层骨架 | ✕ + 标题/副标题 + SAVE + 搜索行 + 行列表 + 空态 | 三个子弹层共用一套骨架 | ✅ | — | SAVE 提交选中、✕ 丢弃（待定选择不落库）；选中行右缘蓝勾（坑 29 key 带选中态） |
| 15 | 模板仓库子弹层 | viewer 的 isTemplate 仓库列表 | 选仓库模板 | ✅ | GraphQL viewer 模板仓库查询 | 空态=灰底居中「Nothing to see here」（官方截图口径，复用 work_filter_nothing） |
| 16 | .gitignore 子弹层 | 模板名列表 + 搜索 | 选 .gitignore 模板 | ✅ | REST GET /gitignore/templates | API 返回序即展示序（官方 AL/Actionscript/Ada… 同源） |
| 17 | License 子弹层 | 精选许可证列表（name + spdx 灰字） + 搜索 | 选许可证 | ✅ | REST GET /licenses | 官方 13 集来自 choosealicense 精选（§七），从全量客户端过滤 |
| 18 | CREATE 动作 | 组装表单创建仓库 | 成功：关弹层 + 跳新仓库详情；失败：toast 且弹层保留 | ✅ | REST POST /user/repos；GraphQL createRepositoryFromTemplate | 422 → 专属文案；其余 friendlyError |
| 19 | 步进动画 | General↔Configuration 横向推入/退出 | 步进反馈 | ✅ | — | translate transition（两步同屏仅渲染其一） |
| 20 | Configuration 底部 | 两圆点（第 2 点激活） | 步骤指示 | ✅ | — | 纯 UI |

---

## 四、核心接口

> 建仓双通道：GraphQL 无 createRepository mutation（§五），无模板走 REST；选模板走 GraphQL（模板建仓 GraphQL 原生支持，且 repoPicker 数据源已是 GraphQL）。

```graphql
# 模板建仓（选了模板仓库时；visibility = PRIVATE | PUBLIC，includeAllBranches 固定 false=仅默认分支）
mutation CreateRepoFromTemplate($input: CreateRepositoryFromTemplateInput!) {
  createRepositoryFromTemplate(input: $input) {
    repository { name owner { login } url }
  }
}

# 模板仓库候选 + 建仓所需 ownerId（isTemplate 由客户端过滤：RepositoryConnection 无 isTemplate 筛选参数）
query ViewerTemplateRepos($first: Int!) {
  viewer {
    id
    repositories(first: $first, ownerAffiliations: OWNER, orderBy: {field: NAME, direction: ASC}) {
      nodes { id name isTemplate owner { login } }
    }
  }
}
```

REST（经 GitHttpClient.restPost/restGet，页面禁裸 http）：

| 端点 | 用途 | 关键字段 |
| ---- | ---- | -------- |
| `POST /user/repos`（201） | 无模板建仓 | `name` 必填；`description`；`private`；`auto_init`；`gitignore_template`；`license_template`；空可选字段整体省略 |
| `GET /gitignore/templates` | .gitignore 模板名数组 | `["AL","Actionscript",…]`，API 序即展示序 |
| `GET /licenses` | 全量许可证 | 按 `spdx_id` 客户端过滤 13 精选集，保留 API 序 |

---

## 五、边界 / 不可行项

| 项 | 原因 | ArkCat 处理方式 |
| ---- | ---- | ------------------- |
| 组织账号建仓 | 官方 Owner 行仅在有组织时可选；组织建仓走 `POST /orgs/{org}/repos` 需组织权限，个人账号无组织为常态 | Owner 行静态展示当前账号；组织建仓后续单独立 spec |
| 模板与初始内容互斥 | 模板建仓端点（REST generate / GraphQL createRepositoryFromTemplate）不接收 README/.gitignore/license 参数 | 选模板后三行隐藏；模板行可重新点开改选 |
| license/.gitignore 与 auto_init 的依赖 | REST 文档未言明依赖关系；社区经验模板文件随初始提交落地，无初始提交则被忽略 | 任一初始内容（README/.gitignore/license）选中即 `auto_init=true`；GitHub 此时必然带出最小 README（REST 语义，§七 记录） |
| 重名 / 非法名 | 服务端校验（422） | toast 专属文案（名称已存在或无效），弹层与已填内容保留；不做客户端字符白名单 |
| 模板仓库超 100 | `first: 100` 单页 | 模板仓库为个人少量资产，不分页；超出部分不展示 |
| 子弹层拉取失败 | 网络/权限 | StateView 错误态 + 重试；空态与错误态分开渲染 |
| OAuth scope | 建仓需 `repo`（私有）/`public_repo or repo`（公开） | 已核实 OAuthService SCOPES 含 `repo`（OAuthService.ets:14-15），无需改动 |

---

## 六、TDD 验收标准

- [x] bash scripts/check-spec.sh 通过
- [x] 宿主单测不回归（bash scripts/ut/run-local-tests.sh）
- [ ] buildCreateRepoBody：可选字段为空时省略、private/auto_init 正确；shouldAutoInit 四分支（仅 README / 仅 gitignore / 仅 license / 全空）
- [ ] mapRestLicenses：13 集过滤、API 序保持、NOASSERTION 排除、name/spdx 映射
- [ ] mapGitignoreTemplates：字符串数组映射、非字符串剔除
- [ ] mapTemplateRepos：isTemplate 过滤、id/name/owner 提取
- [ ] filterPickerItems：大小写不敏感、trim、空串返回全量
- [ ] 模拟器：Home「+」→ New repository，主弹层自底部弹出；两步切换（NEXT/←）与底部圆点激活态正确
- [ ] 模拟器：三个子弹层自底部弹出且盖在主弹层上（模板空态「Nothing to see here」/ gitignore 列表 / license 列表），搜索过滤与 SAVE 选中回显、✕ 丢弃均正确
- [ ] 模拟器：真实创建仓库成功 → 弹层关闭并跳转新仓库详情页；重名 422 → 专属 toast 且已填内容保留
- [ ] base/zh_CN 新增 key 对齐；硬编码颜色/字号门禁通过

---

## 七、备注

- **呈现形态**：官方为自底部弹出的近全屏弹层（截图带抓取条）→ 主弹层=Home 根节点 `bindSheet(SheetSize.LARGE + dragBar + showClose:false)`；三个子弹层=弹层内容组件内的**嵌套 bindSheet**，单 bindSheet + sheetKind 分派（坑 2：同组件多 bindSheet 只有最后一个生效）。弹层内容关闭即销毁重建 → 重开自动回 General 步、表单清空。
- **步进切换**：两步在同一弹层内 if/else 切换 + translate transition（General 退 -30%、Config 进 100%，回退反向），官方为横向推入分页，圆点随之切激活态。
- **NEXT 空名交互**：官方截图中 NEXT 恒为蓝色可点态（空名亦然），点击后行为未被截图捕获 → 推断为行内 danger 文案「Repository name can't be empty」（不置灰、不跳转）。
- **选中值回显**：官方选中后 Configuration 行尾样式未被截图捕获 → 推断 SELECT 位置回显选中值（gitignore=模板名、license=spdx、模板=仓库名，超长省略）；子弹层内选中行右缘蓝勾、SAVE 前为待定态（✕ 丢弃）。
- **License 13 精选集**：官方列表首项 AGPL-3.0 且序=choosealicense.com 精选（AGPL/Apache/BSD2/BSD3/BSL/CC0/EPL/GPL2/GPL3/LGPL/MIT/MPL/Unlicense），与全量 /licenses（0BSD 打头）不符 → 客户端按 spdx 过滤这 13 项，保留 API 返回序（恰好与官方一致）。
- **auto_init 语义**：仅选 license/.gitignore 不勾 README 时，`auto_init=true` 仍会带出最小 README——GitHub REST 语义如此（web 端 license-only 无 README 走另一条内部路径，第三方不可达），官方 App 亦无法绕开。
- **创建成功**：push `repoDetail`（参数 `owner/name`，StarredRepositories.ets:470 同款）；Home 仓库列表不主动刷新（下拉刷新可见），与官方一致（官方亦只跳详情页）。
- **组件拆分**：NewRepositorySheet（壳：状态/步进/子弹层分派/CREATE）+ NewRepositoryGeneral + NewRepositoryConfig + NewRepositoryPicker（三弹层共用骨架）四文件，各 <300 行；纯逻辑（payload 组装/映射/过滤/校验）下沉 models/RepoCreateModels.ets 进宿主单测。
- i18n 前缀 `repo_create_`，base/zh_CN 双份；「Add .gitignore」值兼任子弹层副标题（官方即复用同一文案）。
