/**
 * Repo Detail 页（Spec 006）：官方布局对齐。
 * 头部（业主/描述/stars/forks）+ 操作区（STAR+fork/🔔）+ 计数入口（Issues/PR/Actions/Releases）
 * + More 折叠区（分支/Code/Commits/README·EDIT）+ README 简化富文本。
 * Packages/Settings 按边界不展示；文件列表/语言占比收进 More（查询保留）。
 */
import { promptAction } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { RepoDetail, FileEntry, LanguageSlice } from '../models/RepoDetailModels';
import { RepoService } from '../services/RepoService';
import { WorkService } from '../services/WorkService';
import { WorkUserList } from '../models/WorkModels';
import { StarredListSheet, STARRED_SUGGESTIONS } from '../components/StarredListSheet';
import { MarkdownService, MarkdownFetchResult } from '../services/MarkdownService';
import { StateView } from '../components/StateView';
import { AppBar, AppBarAction, AppBarActionCfg } from '../components/AppBar';
import { OctIcon } from '../components/OctIcon';
import { PageShadowBar } from '../components/PageShadowBar';
import { MarkdownView } from '../components/MarkdownView';
import { resText } from '../utils/I18n';
import { githubShortTime, timeParts, TimeParts } from '../utils/Format';

@ComponentV2
export struct RepoDetailView {
  @Param owner: string = '';
  @Param name: string = '';
  @Param token: string = '';
  @Param pathStack: NavPathStack = new NavPathStack();
  @Local detail: RepoDetail | null = null;
  @Local loading: boolean = true;
  @Local errorMsg: string = '';
  /** 滚动顶部阴影（滚动中显示、回顶消失） */
  @Local scrollShadow: boolean = false;
  @Local isRefreshing: boolean = false;
  @Local busy: boolean = false;
  @Local moreExpanded: boolean = false;
  /** 贡献者总数（More 区 Contributors 行）：-1=未加载/失败，行尾不显示数字（与 countRow 负数哨兵同构） */
  @Local contributorCount: number = -1;
  /** viewer 星标列表（已加星才拉）：列表钮文案与成员 sheet 数据源（官方已加星四钮布局） */
  @Local lists: WorkUserList[] = [];
  /** 列表成员 sheet 当前仓库 id（成员态判定，Starred 页同构） */
  @Local sheetRepoId: string = '';
  /** 成员切换进行中（乐观更新期间防连点） */
  @Local toggling: boolean = false;
  @Local listSheetOpen: boolean = false;
  /** README 官方 HTML（REST /readme html+json；null=未加载） */
  @Local readmeResult: MarkdownFetchResult | null = null;

  aboutToAppear(): void {
    this.refresh();
  }

  private refresh(): void {
    if (this.owner === '' || this.name === '') {
      return;
    }
    this.loading = true;
    this.errorMsg = '';
    this.readmeResult = null;
    this.loadContributorCount();
    RepoService.fetchRepoDetail(this.token, this.owner, this.name)
      .then((detail: RepoDetail) => {
        this.detail = detail;
        this.loading = false;
        this.isRefreshing = false;
        // 已加星才有列表钮（官方四钮布局）：预拉列表供钮面文案与成员 sheet 用
        if (detail.viewerHasStarred) {
          this.fetchLists();
        }
        this.loadReadme();
      })
      .catch((e: Error) => {
        this.errorMsg = e.message;
        this.loading = false;
        this.isRefreshing = false;
      });
  }

  /** 贡献者总数走 REST（GraphQL 无字段）：与详情主体并行拉取，失败保持 -1 不阻断页面 */
  private loadContributorCount(): void {
    RepoService.fetchContributorCount(this.token, this.owner, this.name)
      .then((count: number) => {
        this.contributorCount = count;
      })
      .catch(() => {
        // 404（空仓库）/网络失败：Contributors 行不显示数字
      });
  }

  /** 拉取 viewer 列表（含成员仓库 id 分页补全）：失败静默，列表钮回退 ADD TO LIST 态 */
  private fetchLists(): void {
    WorkService.fetchUserLists(this.token)
      .then((lists: WorkUserList[]) => {
        this.lists = lists;
      })
      .catch(() => {
        // 列表拉取失败不影响详情主体；sheet 内保留旧数据
      });
  }

  /** 切换仓库与某列表的成员关系：乐观更新（点击即翻转），失败重取回滚（Starred 页同构） */
  private toggleListMember(list: WorkUserList): void {
    const repoId = this.sheetRepoId;
    const targetMember = repoId !== '' && list.repoIds.includes(repoId);
    if (repoId === '' || this.toggling) {
      return;
    }
    // 本地翻转目标列表成员态与计数，UI 即时反馈
    const nextLists = this.lists.map((l: WorkUserList): WorkUserList => {
      if (l.id !== list.id) {
        return l;
      }
      const ids = l.repoIds.slice();
      const idx = ids.indexOf(repoId);
      if (targetMember) {
        if (idx >= 0) {
          ids.splice(idx, 1);
        }
      } else {
        ids.push(repoId);
      }
      return {
        id: l.id,
        name: l.name,
        description: l.description,
        itemCount: targetMember ? l.itemCount - 1 : l.itemCount + 1,
        repoIds: ids,
        repoHasNext: l.repoHasNext,
        repoCursor: l.repoCursor
      };
    });
    this.lists = nextLists;
    // mutation 全量 listIds：翻转后按新成员集发送
    const sendIds: string[] = [];
    for (const l of nextLists) {
      if (l.repoIds.includes(repoId)) {
        sendIds.push(l.id);
      }
    }
    this.toggling = true;
    WorkService.updateUserListsForItem(this.token, repoId, sendIds)
      .then(() => {
        this.toggling = false;
        this.fetchLists();
      })
      .catch((e: Error) => {
        this.toggling = false;
        promptAction.showToast({ message: e.message });
        this.fetchLists();
      });
  }

  /** 官方语义：点 Suggestions 直接创建同名列表，成功后刷新（Starred 页同构） */
  private createListFromSuggestion(index: number): void {
    const name = this.stringOf(STARRED_SUGGESTIONS[index]);
    WorkService.createList(this.token, name, '')
      .then((): void => {
        this.fetchLists();
      })
      .catch((e: Error) => {
        promptAction.showToast({ message: e.message });
      });
  }

  /** 列表成员 sheet（单个 bindSheet 引用，避免多 bindSheet 失效） */
  @Builder
  listSheet() {
    StarredListSheet({
      lists: this.lists,
      sheetRepoId: this.sheetRepoId,
      onToggleMember: (list: WorkUserList): void => this.toggleListMember(list),
      onCreateSuggestion: (index: number): void => this.createListFromSuggestion(index),
      onCreateList: (): void => {
        // 先收 sheet 再推页，避免弹窗盖在新页面上
        this.listSheetOpen = false;
        this.pathStack.pushPathByName('createList', '');
      }
    })
  }

  /** README 走官方渲染管线（Spec 040：REST html+json；GraphQL readmeText 仅作降级） */
  private loadReadme(): void {
    MarkdownService.fetchReadmeHtml(this.token, this.owner, this.name)
      .then((res: MarkdownFetchResult) => {
        this.readmeResult = res;
        this.isRefreshing = false;
      })
      .catch(() => {
        this.readmeResult = { status: 'error', html: '' };
        this.isRefreshing = false;
      });
  }

  /** 本人仓库判定（fork 置灰+提示、stargazers 入口共用） */
  private get isOwnRepo(): boolean {
    const detail = this.detail;
    return detail !== null && detail.viewerLogin !== '' && detail.ownerLogin === detail.viewerLogin;
  }

  /** stargazers 入口可见性：仅本人仓库（Spec 053；他人仓库点击无反应，对齐官方 App） */
  private get canViewStargazers(): boolean {
    return this.isOwnRepo;
  }

  /** 当前仓库是否已在任一列表（列表钮灰底/白底分流） */
  private get repoInAnyList(): boolean {
    return this.firstListName() !== '';
  }

  /** 当前仓库所在的首个列表名（官方多列表时显示首个；未入列返回空） */
  private firstListName(): string {
    const repoId = this.detail?.repoId ?? '';
    if (repoId === '') {
      return '';
    }
    for (const l of this.lists) {
      if (l.repoIds.includes(repoId)) {
        return l.name;
      }
    }
    return '';
  }

  private navigateLink(name: string, param: string): void {
    this.pathStack.pushPathByName(name, param);
  }

  /** 拉起系统浏览器（Profile/MarkdownView 同款 viewData want） */
  private openExternal(uri: string): void {
    const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    if (ctx === undefined) {
      return;
    }
    ctx.startAbility({
      action: 'ohos.want.action.viewData',
      entities: ['entity.system.browsable'],
      uri: uri
    }).catch(() => {
      // 无应用接住时静默，不打断浏览
    });
  }

  /** 主页链接补全协议（GitHub 仓库 Homepage 允许只填 example.com） */
  private homepageUri(): string {
    const raw = this.detail?.homepageUrl ?? '';
    return raw !== '' && !raw.startsWith('http://') && !raw.startsWith('https://') ? `https://${raw}` : raw;
  }

  private onStar(): void {
    const detail = this.detail;
    if (detail === null || detail.repoId === '' || this.busy) {
      return;
    }
    // 已加星：官方先弹取消确认（取消会同步把仓库移出 lists）；未加星直接加
    if (detail.viewerHasStarred) {
      this.confirmUnstar();
      return;
    }
    this.doToggleStar();
  }

  /** 取消星标确认弹窗（官方文案；CANCEL/UNSTAR 双蓝按钮） */
  private confirmUnstar(): void {
    const ui = this.getUIContext();
    ui.getPromptAction().showDialog(
      {
        title: this.fmt($r('app.string.repo_unstar_title'), this.detail?.name ?? ''),
        message: this.stringOf($r('app.string.repo_unstar_message')),
        buttons: [
          { text: this.stringOf($r('app.string.repo_unstar_cancel')), color: $r('app.color.link_blue') },
          { text: this.stringOf($r('app.string.repo_unstar_confirm')), color: $r('app.color.link_blue') }
        ]
      },
      (err, data) => {
        if (err || data.index !== 1) {
          return;
        }
        this.doToggleStar();
      });
  }

  /** Star/Unstar 实际执行（原 onStar 主体） */
  private doToggleStar(): void {
    const detail = this.detail;
    if (detail === null || detail.repoId === '' || this.busy) {
      return;
    }
    this.busy = true;
    RepoService.toggleStar(this.token, detail.repoId, detail.viewerHasStarred)
      .then((starred: boolean) => {
        const updated: RepoDetail = {
          repoId: detail.repoId,
          name: detail.name,
          nameWithOwner: detail.nameWithOwner,
          description: detail.description,
          stargazerCount: detail.stargazerCount + (starred ? 1 : -1),
          forkCount: detail.forkCount,
          watcherCount: detail.watcherCount,
          viewerHasStarred: starred,
          licenseName: detail.licenseName,
          homepageUrl: detail.homepageUrl,
          topics: detail.topics,
          readmeText: detail.readmeText,
          files: detail.files,
          languages: detail.languages,
          lastCommitMessage: detail.lastCommitMessage,
          ownerAvatarUrl: detail.ownerAvatarUrl,
          ownerLogin: detail.ownerLogin,
          viewerLogin: detail.viewerLogin,
          issueCount: detail.issueCount,
          prCount: detail.prCount,
          hasDiscussions: detail.hasDiscussions,
          discussionCount: detail.discussionCount,
          releaseCount: detail.releaseCount,
          defaultBranchRefName: detail.defaultBranchRefName
        };
        this.detail = updated;
        // 加星成功后进入四钮布局：补拉列表数据（未加星态不预拉）
        if (starred) {
          this.fetchLists();
        }
        const ui = this.getUIContext();
        promptAction.showToast({
          message: starred
            ? resText(ui, $r('app.string.repo_starred_toast'))
            : resText(ui, $r('app.string.repo_unstarred_toast'))
        });
      })
      .catch((e: Error) => {
        promptAction.showToast({ message: this.fmt($r('app.string.repo_star_failed'), e.message) });
      })
      .finally(() => {
        this.busy = false;
      });
  }

  /** 带 %1$s 格式化：资源模板 + 参数 → 当前语言文案 */
  private fmt(res: Resource, arg: string): string {
    return resText(this.getUIContext(), res, arg);
  }

  /** 资源 → 当前语言的纯文案 */
  private stringOf(res: Resource): string {
    return resText(this.getUIContext(), res);
  }

  private onFork(): void {
    // 本人仓库官方禁 fork：按钮置灰，点击仅提示
    if (this.isOwnRepo) {
      promptAction.showToast({ message: this.stringOf($r('app.string.repo_fork_own_toast')) });
      return;
    }
    const detail = this.detail;
    if (detail === null || detail.repoId === '' || this.busy) {
      return;
    }
    this.busy = true;
    RepoService.createFork(this.token, detail.repoId)
      .then(() => {
        promptAction.showToast({ message: $r('app.string.repo_fork_created_toast') });
      })
      .catch((e: Error) => {
        promptAction.showToast({ message: this.fmt($r('app.string.repo_fork_failed'), e.message) });
      })
      .finally(() => {
        this.busy = false;
      });
  }

  private openIssues(): void {
    // Spec 007 注册 issuesList 路由后接入
    this.pathStack.pushPathByName('issuesList', `${this.owner}/${this.name}`);
  }

  private openPrs(): void {
    this.pathStack.pushPathByName('repoPrs', `${this.owner}/${this.name}`);
  }

  private openDiscussions(): void {
    this.pathStack.pushPathByName('repoDiscussions', `${this.owner}/${this.name}`);
  }

  private openReleases(): void {
    this.pathStack.pushPathByName('repoReleases', `${this.owner}/${this.name}`);
  }

  private openCommits(): void {
    this.pathStack.pushPathByName('repoCommits', `${this.owner}/${this.name}`);
  }

  /** Spec 038：More → 文件 → 仓库文件树 */
  private openFiles(): void {
    this.pathStack.pushPathByName('repoFiles', `${this.owner}|${this.name}|`);
  }

  private comingSoon(): void {
    promptAction.showToast({ message: $r('app.string.home_feature_coming') });
  }

  /** 相对时间结构化数据 → 当前语言文案（%1$d 位置占位） */
  private timeText(parts: TimeParts | null): string {
    return parts !== null ? githubShortTime(parts) : '';
  }

  @Builder
  headerBox() {
    Column({ space: 8 }) {
      Row({ space: 6 }) {
        Image(this.detail?.ownerAvatarUrl ?? '')
          .width(20)
          .height(20)
          .borderRadius(12)
          .backgroundColor($r('app.color.heat_empty'))
        Text(this.detail?.ownerLogin ?? '')
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_primary'))
      }
      .width('100%')

      Text(this.detail?.name ?? '')
        .fontSize($r('app.float.title_font_size'))
        .fontWeight(600)
        .fontColor($r('app.color.text_primary'))
        .width('100%')

      if (this.detail !== null && this.detail.description !== '') {
        Text(this.detail.description)
          .fontSize($r('app.float.body_font_size'))
          .fontColor($r('app.color.text_primary'))
          .width('100%')
      }

      // 主页链接行（bio 下，官方同位）：link 图标与个人 Profile 链接行同款，文字黑色，点击拉起浏览器
      if ((this.detail?.homepageUrl ?? '') !== '') {
        Row({ space: 6 }) {
          OctIcon({ res: $r('app.media.oct_link_16'), iconSize: 14, iconColor: $r('app.color.text_secondary') })
          Text(this.detail?.homepageUrl ?? '')
            .fontSize($r('app.float.body_font_size'))
            .fontColor($r('app.color.text_primary'))
            .maxLines(1)
        }
        .width('100%')
        .margin({ top: 16 })
        .onClick(() => this.openExternal(this.homepageUri()))
      }

      Row({ space: 5 }) {
        Row({ space: 5 }) {
          OctIcon({ res: $r('app.media.oct_star_16'), iconSize: 14, iconColor: $r('app.color.text_secondary') })
          Text(`${this.detail?.stargazerCount ?? 0}`)
            .fontSize($r('app.float.caption_font_size'))
            .fontColor($r('app.color.text_primary'))
          Text($r('app.string.repo_stars_label'))
            .fontSize($r('app.float.caption_font_size'))
            .fontColor($r('app.color.text_secondary'))
        }
        .responseRegion({ x: 0, y: -12, width: '100%', height: '220%' })
        .onClick(() => {
          // stargazers 名单仅本人仓库可见（Spec 053）：他人仓库点击无任何反应
          if (!this.canViewStargazers) {
            return;
          }
          this.pathStack.pushPathByName('stargazers', `${this.owner}/${this.name}`);
        })
        Text('·')
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_tertiary'))
          .margin({ left: 2, right: 2 })
        Row({ space: 5 }) {
          OctIcon({ res: $r('app.media.oct_repo_forked_16'), iconSize: 14, iconColor: $r('app.color.text_secondary') })
          Text(`${this.detail?.forkCount ?? 0}`)
            .fontSize($r('app.float.caption_font_size'))
            .fontColor($r('app.color.text_primary'))
          Text($r('app.string.repo_forks_label'))
            .fontSize($r('app.float.caption_font_size'))
            .fontColor($r('app.color.text_secondary'))
        }
        .responseRegion({ x: 0, y: -12, width: '100%', height: '220%' })
        .onClick(() => {
          this.pathStack.pushPathByName('forks', `${this.owner}/${this.name}`);
        })
      }
      .width('100%')
    }
    .padding({ left: 16, right: 16, top: 8, bottom: 8 })
    .width('100%')
  }

  /** 操作区：未加星=STAR 大按钮+fork/🔔 圆钮；已加星=金星钮（灰底，点击弹取消确认）+列表钮（官方四钮布局） */
  @Builder
  actionBar() {
    Row({ space: 8 }) {
      if (!(this.detail?.viewerHasStarred ?? false)) {
        Row({ space: 6 }) {
          OctIcon({ res: $r('app.media.oct_star_16'), iconSize: 16, iconColor: $r('app.color.text_primary') })
          Text(this.stringOf($r('app.string.explore_star')))
            .fontSize($r('app.float.body_font_size'))
            .fontColor($r('app.color.text_primary'))
        }
        .layoutWeight(1)
        .height(44)
        .justifyContent(FlexAlign.Center)
        .borderRadius(6)
        .backgroundColor($r('app.color.card_background'))
        .border({ width: 1, color: $r('app.color.border') })
        .onClick(() => this.onStar())
      } else {
        Stack() {
          // 金色实心星（官方已加星态）：灰底仍可点，点击弹取消确认
          OctIcon({ res: $r('app.media.oct_star_fill_16'), iconSize: 18, iconColor: $r('app.color.star_gold') })
        }
        .width(44)
        .height(44)
        .borderRadius(6)
        .backgroundColor($r('app.color.chip_bg'))
        .border({ width: 1, color: $r('app.color.border') })
        .onClick(() => this.onStar())

        // 列表钮：未入列=+ ADD TO LIST（白底描边）；已入列=列表 icon+首个列表名（灰底，官方同构）
        Row({ space: 6 }) {
          if (this.repoInAnyList) {
            OctIcon({ res: $r('app.media.oct_list_unordered_16'), iconSize: 16, iconColor: $r('app.color.text_primary') })
            Text(this.firstListName())
              .fontSize($r('app.float.body_font_size'))
              .fontColor($r('app.color.text_primary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          } else {
            OctIcon({ res: $r('app.media.oct_plus_16'), iconSize: 16, iconColor: $r('app.color.text_primary') })
            Text($r('app.string.explore_add_to_list'))
              .fontSize($r('app.float.body_font_size'))
              .fontColor($r('app.color.text_primary'))
              .maxLines(1)
          }
        }
        .layoutWeight(1)
        .height(44)
        .justifyContent(FlexAlign.Center)
        .borderRadius(6)
        .backgroundColor(this.repoInAnyList ? $r('app.color.chip_bg') : $r('app.color.card_background'))
        .border({ width: 1, color: $r('app.color.border') })
        .onClick(() => {
          const detail = this.detail;
          if (detail === null) {
            return;
          }
          // 与 Starred 页卡片 ⋯ 同构：定 sheet 仓库 + 刷新列表 + 开弹层
          this.sheetRepoId = detail.repoId;
          this.fetchLists();
          this.listSheetOpen = true;
        })
      }
      Stack() {
        // 本人仓库 fork 置灰（官方禁自 fork），点击 toast 提示
        OctIcon({
          res: $r('app.media.oct_repo_forked_16'), iconSize: 18,
          iconColor: this.isOwnRepo ? $r('app.color.text_tertiary') : $r('app.color.text_primary')
        })
      }
      .width(44)
      .height(44)
      .borderRadius(6)
      .backgroundColor($r('app.color.card_background'))
      .border({ width: 1, color: $r('app.color.border') })
      .onClick(() => this.onFork())
      Stack() {
        OctIcon({ res: $r('app.media.oct_bell_16'), iconSize: 18, iconColor: $r('app.color.text_primary') })
      }
      .width(44)
      .height(44)
      .borderRadius(6)
      .backgroundColor($r('app.color.card_background'))
      .border({ width: 1, color: $r('app.color.border') })
      .onClick(() => this.comingSoon())
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 8 })
  }

  /** 计数入口：彩块图标 + 标签 + 计数 */
  @Builder
  countRow(iconRes: Resource, color: ResourceColor, labelRes: Resource, count: number, onClick: () => void) {
    Row({ space: 12 }) {
      Stack() {
        OctIcon({ res: iconRes, iconSize: 16, iconColor: Color.White })
      }
      .width(32)
      .height(32)
      .backgroundColor(color)
      .borderRadius(6)
      Text(labelRes)
        .fontSize($r('app.float.body_font_size'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
      if (count >= 0) {
        Text(`${count}`)
          .fontSize($r('app.float.body_font_size'))
          .fontColor($r('app.color.text_secondary'))
      }
    }
    .width('100%')
    .height(48)
    .padding({ left: 16, right: 16 })
    .onClick(onClick)
  }

  /** More 折叠区：分支/Code/Commits/README·EDIT */
  @Builder
  moreSection() {
    Column() {
      if (!this.moreExpanded) {
      Row({ space: 12 }) {
        Stack() {
          OctIcon({ res: $r('app.media.oct_kebab_horizontal_16'), iconSize: 14, iconColor: $r('app.color.text_primary') })
        }
        .width(32)
        .height(32)
        .backgroundColor($r('app.color.bg_page'))
        .borderRadius(6)
        Text($r('app.string.repo_more'))
          .fontSize($r('app.float.body_font_size'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
        Blank()
        OctIcon({ res: $r('app.media.oct_chevron_down_16'), iconSize: 14, iconColor: $r('app.color.text_secondary') })
      }
      .width('100%')
      .height(48)
      .padding({ left: 16, right: 16 })
      .onClick(() => {
        this.moreExpanded = true;
      })
      }

      if (this.moreExpanded) {
        Row({ space: 12 }) {
          Stack() {
            OctIcon({ res: $r('app.media.oct_people_16'), iconSize: 16, iconColor: Color.White })
          }
          .width(32)
          .height(32)
          .backgroundColor($r('app.color.badge_red'))
          .borderRadius(6)
          Text($r('app.string.repo_contributors'))
            .fontSize($r('app.float.body_font_size'))
            .fontColor($r('app.color.text_primary'))
            .layoutWeight(1)
          if (this.contributorCount >= 0) {
            Text(`${this.contributorCount}`)
              .fontSize($r('app.float.body_font_size'))
              .fontColor($r('app.color.text_secondary'))
          }
        }
        .width('100%')
        .height(48)
        .padding({ left: 16, right: 16 })
        .onClick(() => this.navigateLink('contributors', `${this.owner}/${this.name}`))

        Row({ space: 12 }) {
          Stack() {
            OctIcon({ res: $r('app.media.oct_eye_16'), iconSize: 16, iconColor: Color.White })
          }
          .width(32)
          .height(32)
          .backgroundColor($r('app.color.attention_bg'))
          .borderRadius(6)
          Text($r('app.string.repo_watchers'))
            .fontSize($r('app.float.body_font_size'))
            .fontColor($r('app.color.text_primary'))
            .layoutWeight(1)
          Text(`${this.detail?.watcherCount ?? 0}`)
            .fontSize($r('app.float.body_font_size'))
            .fontColor($r('app.color.text_secondary'))
        }
        .width('100%')
        .height(48)
        .padding({ left: 16, right: 16 })
        .onClick(() => this.navigateLink('watchers', `${this.owner}/${this.name}`))

        Row({ space: 12 }) {
          Stack() {
            OctIcon({ res: $r('app.media.oct_law_16'), iconSize: 16, iconColor: Color.White })
          }
          .width(32)
          .height(32)
          .backgroundColor($r('app.color.badge_red'))
          .borderRadius(6)
          Text($r('app.string.repo_license'))
            .fontSize($r('app.float.body_font_size'))
            .fontColor($r('app.color.text_primary'))
            .layoutWeight(1)
          if ((this.detail?.licenseName ?? '') !== '') {
            Text(this.detail?.licenseName ?? '')
              .fontSize($r('app.float.body_font_size'))
              .fontColor($r('app.color.text_secondary'))
              .maxLines(1)
          }
        }
        .width('100%')
        .height(48)
        .padding({ left: 16, right: 16 })
        .onClick(() => this.navigateLink('license', `${this.owner}/${this.name}`))
      }
    }
    .width('100%')
    .backgroundColor($r('app.color.card_background'))
    .borderRadius(12)
  }

  /** 分支区（独立于 More）：Current branch/main 垂排 + Code/Commits */
  @Builder
  branchSection() {
    Column() {
      // 结构：git-branch 图标最左，右侧为 Current branch 文字 + main ✓ 上下排布
      Row({ space: 12 }) {
        Stack() {
          OctIcon({ res: $r('app.media.oct_git_branch_16'), iconSize: 16, iconColor: $r('app.color.text_secondary') })
        }
        .width(32)
        .height(32)
        .borderRadius(6)
        Column({ space: 2 }) {
          Text($r('app.string.repo_current_branch'))
            .fontSize($r('app.float.caption_font_size'))
            .fontColor($r('app.color.text_secondary'))
          Row({ space: 6 }) {
            Text(this.detail?.defaultBranchRefName ?? 'main')
              .fontSize($r('app.float.body_font_size'))
              .fontColor($r('app.color.text_primary'))
            OctIcon({ res: $r('app.media.oct_check_16'), iconSize: 14, iconColor: $r('app.color.success_text') })
          }
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Text($r('app.string.repo_change'))
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.link_blue'))
          .onClick(() => this.comingSoon())
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 10, bottom: 10 })

      Divider().color($r('app.color.divider')).margin({ left: 16, right: 16 })

      Row({ space: 12 }) {
        Stack() {
          OctIcon({ res: $r('app.media.oct_file_code_16'), iconSize: 16, iconColor: $r('app.color.text_primary') })
        }
        .width(32)
        .height(32)
        .backgroundColor($r('app.color.heat_empty'))
        .borderRadius(6)
        Text($r('app.string.repo_code'))
          .fontSize($r('app.float.body_font_size'))
          .fontColor($r('app.color.text_primary'))
      }
      .width('100%')
      .height(48)
      .padding({ left: 16, right: 16 })
      .onClick(() => this.openFiles())

      Divider().color($r('app.color.divider')).margin({ left: 72 })

      Row({ space: 12 }) {
        Stack() {
          OctIcon({ res: $r('app.media.oct_git_commit_16'), iconSize: 16, iconColor: $r('app.color.text_primary') })
        }
        .width(32)
        .height(32)
        .backgroundColor($r('app.color.heat_empty'))
        .borderRadius(6)
        Text($r('app.string.repo_commits'))
          .fontSize($r('app.float.body_font_size'))
          .fontColor($r('app.color.text_primary'))
      }
      .width('100%')
      .height(48)
      .padding({ left: 16, right: 16 })
      .onClick(() => this.openCommits())
    }
    .width('100%')
    .backgroundColor($r('app.color.card_background'))
    .borderRadius(12)
  }

  /** README 卡片：官方 HTML 渲染（Spec 040）；404 → no README 占位；异常 → 纯文本降级 */
  @Builder
  readmeCard() {
    Column() {
      if (this.readmeResult !== null) {
        if (this.readmeResult.status === 'ok') {
          MarkdownView({
            html: this.readmeResult.html,
            fallbackText: this.detail?.readmeText ?? '',
            collapse: false,
            imgBase: `https://raw.githubusercontent.com/${this.owner}/${this.name}/${this.detail?.defaultBranchRefName ?? 'main'}/`,
            linkBase: `https://github.com/${this.owner}/${this.name}/blob/${this.detail?.defaultBranchRefName ?? 'main'}/`,
            onNavigate: (name: string, param: string) => this.navigateLink(name, param)
          })
        } else if (this.readmeResult.status === 'notFound') {
          Text(resText(this.getUIContext(), $r('app.string.md_no_readme')))
            .fontSize($r('app.float.body_font_size'))
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
        } else if ((this.detail?.readmeText ?? '') !== '') {
          MarkdownView({
            html: '',
            fallbackText: this.detail?.readmeText ?? '',
            showRetry: true,
            onRetry: () => this.loadReadme()
          })
        }
      }
    }
    .alignItems(HorizontalAlign.Start)
    .padding($r('app.float.card_padding'))
    .borderRadius($r('app.float.card_radius'))
    .backgroundColor($r('app.color.card_background'))
    .width('100%')
  }

  build() {
    Column() {
      AppBar({
        showBack: true,
        onBack: (): void => {
          this.pathStack.pop();
        },
        actions: [
          new AppBarAction($r('app.media.oct_plus_circle_24'), (): void => this.comingSoon(),
            { iconColor: $r('app.color.link_blue'), a11y: $r('app.string.a11y_new') }),
          new AppBarAction($r('app.media.oct_kebab_horizontal_16'), (): void => this.comingSoon(),
            { rotate90: true, iconColor: $r('app.color.link_blue'), a11y: $r('app.string.a11y_more') })
        ]
      })

      PageShadowBar({ show: this.scrollShadow })

      Refresh({ refreshing: $$this.isRefreshing }) {
        Scroll() {
          Column({ space: 10 }) {
            if (this.detail !== null) {
              this.headerBox()
              this.actionBar()

              Column() {
                this.countRow($r('app.media.oct_issue_opened_16'), $r('app.color.success_text'), $r('app.string.repo_issues_link'), this.detail.issueCount, () => this.openIssues())
                Divider().color($r('app.color.divider')).margin({ left: 72 })
                this.countRow($r('app.media.oct_git_pull_request_16'), $r('app.color.link_blue'), $r('app.string.repo_pr_link'), this.detail.prCount, () => this.openPrs())
                Divider().color($r('app.color.divider')).margin({ left: 72 })
                if (this.detail.hasDiscussions) {
                  // 仓库开启 Discussions 才显示（icon 与 Home 页 Discussions 同款，官方顺序在 PRs 与 Actions 之间）
                  this.countRow($r('app.media.oct_comment_discussion_16'), $r('app.color.shortcut_purple_fg'), $r('app.string.repo_discussions'), this.detail.discussionCount, () => this.openDiscussions())
                  Divider().color($r('app.color.divider')).margin({ left: 72 })
                }
                // Actions 无对应 API：行内不显示数字（countRow 负数哨兵=无计数）
                this.countRow($r('app.media.oct_play_16'), $r('app.color.star_gold'), $r('app.string.repo_actions'), -1, () => this.comingSoon())
                Divider().color($r('app.color.divider')).margin({ left: 72 })
                this.countRow($r('app.media.oct_tag_16'), $r('app.color.work_dark_bg'), $r('app.string.repo_releases'), this.detail.releaseCount, () => this.openReleases())
              }
              .width('100%')
              .backgroundColor($r('app.color.card_background'))
              .borderRadius(12)

              this.moreSection()

              this.branchSection()

              if (this.readmeResult !== null) {
                this.readmeCard()
              }
            } else {
              StateView({
                loading: this.loading,
                error: this.errorMsg,
                onRetry: () => this.refresh()
              })
            }
          }
          .padding({ left: 16, right: 16 })
          .width('100%')
        }
        .scrollBar(BarState.Off)
        .align(Alignment.Top)
        .onScroll((_x: number, y: number): void => {
          this.scrollShadow = y > 0.001;
        })
      }
      .layoutWeight(1)
      .onRefreshing((): void => {
        this.isRefreshing = true;
        this.refresh();
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_page'))
    // !! 双向绑定：拖拽/遮罩/回退关闭时框架回写 false，否则再点列表钮无法重新打开
    .bindSheet(this.listSheetOpen!!, this.listSheet(), {
      height: 300,
      detents: [300, SheetSize.LARGE],
      backgroundColor: $r('app.color.bg_page'),
      // 关闭钮/标题均自绘；外点自动关闭
      showClose: false
    })
  }
}
