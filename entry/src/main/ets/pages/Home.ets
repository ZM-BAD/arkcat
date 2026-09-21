/**
 * Home Tab（Spec 013）：对齐 GitHub 官方布局。
 * Header（Home 标题/搜索/刷新/新建）+ My Work 七行入口
 * + Favorites 空态 + Shortcuts 引导。
 * 入口列表页与 Favorites 添加流程属后续 Spec，当前点击提示。
 */
import { promptAction } from '@kit.ArkUI';
import { ViewerBasic } from '../models/GitHubModels';
import { HomeService } from '../services/HomeService';
import { friendlyError } from '../services/GitHttpClient';
import { AccountStore, AccountInfo } from '../services/AccountStore';
import { StateView } from '../components/StateView';
import { OctIcon } from '../components/OctIcon';
import { Avatar } from '../components/Avatar';
import { AppBar, AppBarAction, AppBarMenuItem } from '../components/AppBar';
import { NewRepositorySheet } from '../components/NewRepositorySheet';
import { WorkSection, WorkConfigStore, visibleWorkSections } from '../utils/WorkConfig';
import { FavoriteRepo, FavoritesStore } from '../utils/Favorites';
import { ShortcutItem, ShortcutStore } from '../utils/Shortcuts';
import { shortcutColor, shortcutIconRes } from '../models/ShortcutPalette';

/** 标题栏底部渐变阴影（滚动时显示、回顶部消失） */
const SHADOW_GRADIENT: Array<[ResourceColor, number]> = [
  [$r('app.color.shadow_floating'), 0],
  [Color.Transparent, 1]
];

/** My Work 条目标识：图标/色/文案/路由（与 Edit My Work 013/016 一致） */
interface WorkEntryMeta {
  iconRes: Resource;
  color: ResourceColor;
  label: Resource;
  route: string;
}

@ComponentV2
export struct HomeView {
  @Param token: string = '';
  @Param pathStack: NavPathStack = new NavPathStack();
  @Local viewer: ViewerBasic | null = null;
  @Local loading: boolean = true;
  @Local errorMsg: string = '';
  /** Spec 070：New repository 两步弹层 */
  @Local newRepoOpen: boolean = false;
  @Local workStore: WorkConfigStore = WorkConfigStore.instance;
  @Param workVersion: number = 0;
  /** Spec 050：收藏列表镜像——@Local 引用 @ObservedV2 单例时 @Trace 跨组件观察不可靠（08-31 坑），
   *  与 016 同走「Index 版本泵 + @Monitor 刷镜像」，分支条件读镜像才会在 SAVE 后重评估 */
  @Local favorites: FavoriteRepo[] = [];
  @Param favoritesVersion: number = 0;
  /** Spec 074：快捷方式镜像（同 Favorites 的 @Local 镜像 + 版本泵策略） */
  @Local shortcuts: ShortcutItem[] = [];
  @Param shortcutsVersion: number = 0;
  /** Spec 060：viewer 探针结果上报（底栏 tab4 头像复用同一次请求，不再单独发 viewer 查询） */
  @Event onViewer: (avatarUrl: string) => void = (avatarUrl: string) => {};
  @Local sectionsVersion: number = 0;

  aboutToAppear(): void {
    WorkConfigStore.load(this.getUIContext().getHostContext())
      .then(() => {
        // load 完成后再触发一次重渲染（编辑页 SAVE 走 workVersion 参数泵）
        this.sectionsVersion++;
      });
    this.reloadFavorites();
    this.reloadShortcuts();
    this.refresh();
  }

  /** Spec 049a：切换账号后 token 更新（@Param 单向同步）→ 用新 token 重拉 */
  @Monitor('token')
  onTokenChanged(): void {
    this.reloadFavorites();
    this.reloadShortcuts();
    this.refresh();
  }

  /** Spec 050：加载当前账号的 Favorites 分区（端侧存储，切账号互不可见） */
  private reloadFavorites(): void {
    const ctx = this.getUIContext().getHostContext();
    AccountStore.getCurrentAccount(ctx)
      .then((acc: AccountInfo | null) => FavoritesStore.load(ctx, acc !== null ? acc.login : ''))
      .then((): void => {
        this.favorites = FavoritesStore.instance.list.slice();
      })
      .catch((): void => {
        // 读取失败保持现有列表（空列表 = 空态引导）
      });
  }

  /** 编辑页 SAVE 泵回（homeFavoritesVersion 递增）：store 单例已是新列表，刷镜像触发重渲染 */
  @Monitor('favoritesVersion')
  onFavoritesVersionChanged(): void {
    this.favorites = FavoritesStore.instance.list.slice();
  }

  /** Spec 074：加载当前账号的 Shortcuts 分区（端侧存储，切账号互不可见） */
  private reloadShortcuts(): void {
    const ctx = this.getUIContext().getHostContext();
    AccountStore.getCurrentAccount(ctx)
      .then((acc: AccountInfo | null) => ShortcutStore.load(ctx, acc !== null ? acc.login : ''))
      .then((): void => {
        this.shortcuts = ShortcutStore.instance.list.slice();
      })
      .catch((): void => {
        // 读取失败保持现有列表（空列表 = 空态引导）
      });
  }

  /** 管理页/创建页 SAVE 泵回（homeShortcutsVersion 递增）：store 单例已是新列表，刷镜像 */
  @Monitor('shortcutsVersion')
  onShortcutsVersionChanged(): void {
    this.shortcuts = ShortcutStore.instance.list.slice();
  }

  private refresh(): void {
    this.loading = true;
    this.errorMsg = '';
    // 请求代际：切号后旧账号的响应直接丢弃（否则底栏 tab4 头像会被上一个账号回填）
    const reqToken: string = this.token;
    HomeService.fetchViewerBasic(this.token)
      .then((viewer: ViewerBasic) => {
        if (reqToken !== this.token) {
          return;
        }
        this.viewer = viewer;
        this.loading = false;
        this.isRefreshing = false;
        this.onViewer(viewer.avatarUrl);
      })
      .catch((e: Error) => {
        if (reqToken !== this.token) {
          return;
        }
        this.errorMsg = friendlyError(this.getUIContext(), e);
        this.loading = false;
        this.isRefreshing = false;
        this.onViewer('');
      });
  }

  private comingSoon(): void {
    promptAction.showToast({ message: $r('app.string.home_feature_coming') });
  }

  /** 标题栏阴影：滚动中显示、回顶部消失 */
  @Local headerShadow: boolean = false;
  @Local isRefreshing: boolean = false;

  /**
   * 「+」弹出菜单（用户 2026-09-19 定案：顶栏弹出菜单而非底部弹层；
   * 官方口径两项：Create Issue / New Repository——建仓流程见 Spec 070，底部弹出两步弹层）。
   */
  private createMenuItems(): AppBarMenuItem[] {
    return [
      {
        icon: $r('app.media.oct_issue_opened_16'),
        label: $r('app.string.create_new_issue'),
        onAction: (): void => {
          // 官方动线：先整页 Choose a repository（Spec 043，2026-09-19 截图驱动重写）
          this.pathStack.pushPathByName('repoPicker', '');
        }
      },
      {
        icon: $r('app.media.oct_repo_16'),
        label: $r('app.string.create_new_repo'),
        onAction: (): void => {
          this.newRepoOpen = true;
        }
      }
    ];
  }

  @Builder
  header() {
    Column() {
      AppBar({
        title: $r('app.string.tab_home'),
        actions: [
          new AppBarAction($r('app.media.oct_search_24'), (): void => {
            this.pathStack.pushPathByName('search', '');
          }, { a11y: $r('app.string.a11y_search') }),
          new AppBarAction($r('app.media.oct_sync_16'), (): void => {
            // 与下拉刷新同效果：置位刷新动画，refresh() 完成后复位（review 用户反馈）
            this.isRefreshing = true;
            this.refresh();
          }, { a11y: $r('app.string.a11y_refresh') }),
          new AppBarAction($r('app.media.oct_plus_circle_24'), (): void => {
          }, { a11y: $r('app.string.a11y_new'), menuItems: this.createMenuItems() })
        ]
      })
      // 底部渐变阴影条：滚动中显示、回顶部消失（if 条件渲染，不依赖 shadow 属性刷新）
      if (this.headerShadow) {
        Row()
          .width('100%')
          .height(3)
          .linearGradient({
            direction: GradientDirection.Bottom,
            colors: SHADOW_GRADIENT
          })
      }
    }
    .width('100%')
  }

  /** My Work 条目标识：id → 图标/色/文案/路由（与 Edit My Work 013/016 一致） */
  private workMeta(id: string): WorkEntryMeta {
    switch (id) {
      case 'prs':
        return { iconRes: $r('app.media.oct_git_pull_request_16'), color: $r('app.color.link_blue'), label: $r('app.string.home_work_pull_requests'), route: 'workPrs' };
      case 'discussions':
        return { iconRes: $r('app.media.oct_comment_discussion_16'), color: $r('app.color.shortcut_purple_fg'), label: $r('app.string.home_work_discussions'), route: 'discussions' };
      case 'projects':
        return { iconRes: $r('app.media.oct_table_16'), color: $r('app.color.text_secondary'), label: $r('app.string.home_work_projects'), route: 'projects' };
      case 'topRepos':
        return { iconRes: $r('app.media.oct_repo_16'), color: $r('app.color.work_dark_bg'), label: $r('app.string.home_work_top_repos'), route: 'topRepos' };
      case 'orgs':
        return { iconRes: $r('app.media.oct_organization_16'), color: $r('app.color.shortcut_orange_fg'), label: $r('app.string.home_work_organizations'), route: 'organizations' };
      case 'starred':
        return { iconRes: $r('app.media.oct_star_fill_16'), color: $r('app.color.star_gold'), label: $r('app.string.home_work_starred'), route: 'starred' };
      default:
        return { iconRes: $r('app.media.oct_issue_opened_16'), color: $r('app.color.success_text'), label: $r('app.string.home_work_issues'), route: 'workIssues' };
    }
  }

  /** My Work 单行入口：彩色圆角方块 + 单色字形 + 标签；按 WorkConfig 过滤/排序 */
  @Builder
  workEntry(meta: WorkEntryMeta) {
    Row() {
      Stack() {
          OctIcon({ res: meta.iconRes, iconSize: 18, iconColor: Color.White })
      }
      .width(44)
      .height(44)
      .backgroundColor(meta.color)
      .borderRadius(6)
      Text(meta.label)
        .fontSize($r('app.float.body_font_size'))
        .fontColor($r('app.color.text_primary'))
        .margin({ left: 12 })
    }
    .width('100%')
    .height(52)
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      this.pathStack.pushPathByName(meta.route, '');
    })
  }

  @Builder
  myWorkSection() {
    Row() {
      Text($r('app.string.home_my_work'))
        .fontSize($r('app.float.section_title_font_size'))
        .fontWeight(600)
        .fontColor($r('app.color.text_primary'))
      Blank()
      Stack() {
  OctIcon({
        res: $r('app.media.oct_kebab_horizontal_16'),
        iconSize: 18,
        iconColor: $r('app.color.text_secondary')
  })
}
.width(44)
.height(44)
        .accessibilityDescription($r('app.string.a11y_more'))
        .focusable(true)
.onClick((): void => {
          this.pathStack.pushPathByName('editMyWork', '');
        })
        .padding(4)
    }
    .width('100%')
    .padding({ top: 16, bottom: 4 })

    ForEach(visibleWorkSections(this.workStore.sections), (section: WorkSection) => {
      this.workEntry(this.workMeta(section.id))
      // key 引用 workVersion/sectionsVersion：确保保存/加载后触发重渲染
    }, (section: WorkSection) => `${section.id}_${this.workVersion}_${this.sectionsVersion}`)
  }

  @Builder
  outlineButton(labelRes: Resource, onTap?: () => void) {
    Button(labelRes)
      // Capsule 类型会忽略 borderRadius（曾渲染成胶囊）；Normal 才走 Primer 6vp 圆角
      .type(ButtonType.Normal)
      .width('100%')
      .height(44)
      .fontSize($r('app.float.caption_font_size'))
      .fontColor($r('app.color.link_blue'))
      .backgroundColor(Color.Transparent)
      .borderRadius($r('app.float.button_radius'))
      .border({ width: 1, color: $r('app.color.border') })
      .onClick(() => {
        if (onTap !== undefined) {
          onTap();
        } else {
          this.comingSoon();
        }
      })
  }

  /** Spec 050：收藏仓库行（官方：头像 + owner 灰字 + 仓库名），点击进仓库详情 */
  @Builder
  favRow(fav: FavoriteRepo) {
    Row({ space: 14 }) {
      Avatar({ url: fav.ownerAvatar, diameter: 40, fallbackIcon: true })
      Column({ space: 2 }) {
        Text(fav.ownerLogin)
          .fontSize($r('app.float.body_font_size'))
          .fontColor($r('app.color.text_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(fav.name)
          .fontSize($r('app.float.body_font_size'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .height(64)
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      this.pathStack.pushPathByName('repoDetail', `${fav.ownerLogin}/${fav.name}`);
    })
  }

  /** Favorites 区块（Spec 050 双态）：空态=引导文案 + ADD FAVORITES；有值=⋯ 入口 + 收藏行列表 */
  @Builder
  favoritesSection() {
    if (this.favorites.length === 0) {
      Text($r('app.string.home_favorites'))
        .fontSize($r('app.float.section_title_font_size'))
        .fontWeight(600)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
        .padding({ top: 16, bottom: 8 })

      Column({ space: 12 }) {
        Text($r('app.string.home_favorites_empty'))
          .fontSize($r('app.float.body_font_size'))
          .fontColor($r('app.color.text_secondary'))
          .textAlign(TextAlign.Center)
          .width('100%')
        this.outlineButton($r('app.string.home_favorites_add'), (): void => {
          this.pathStack.pushPathByName('favoritesEdit', '');
        })
      }
      .padding(24)
      .width('100%')
    } else {
      Row() {
        Text($r('app.string.home_favorites'))
          .fontSize($r('app.float.section_title_font_size'))
          .fontWeight(600)
          .fontColor($r('app.color.text_primary'))
        Blank()
        Stack() {
          OctIcon({
            res: $r('app.media.oct_kebab_horizontal_16'),
            iconSize: 18,
            iconColor: $r('app.color.text_secondary')
          })
        }
        .width(44)
        .height(44)
        .accessibilityDescription($r('app.string.a11y_more'))
        .focusable(true)
        .onClick((): void => {
          this.pathStack.pushPathByName('favoritesEdit', '');
        })
        .padding(4)
      }
      .width('100%')
      .padding({ top: 16, bottom: 4 })

      ForEach(this.favorites, (fav: FavoriteRepo) => {
        this.favRow(fav)
      // key 带 favoritesVersion：编辑页 SAVE 泵回后强制重渲染（同 016 workVersion）
      }, (fav: FavoriteRepo) => `${fav.ownerLogin}/${fav.name}_${this.favoritesVersion}`)
    }
  }

  /** Shortcuts 圆形图标：浅色圆底 + 深色字形（bg/fg 走语义色 token）；8 枚紧贴居中排布 */
  @Builder
  shortcutGlyph(iconRes: Resource, bg: ResourceColor, fg: ResourceColor) {
    Stack() {
      OctIcon({ res: iconRes, iconSize: 12, iconColor: fg })
    }
    .width(32)
    .height(32)
    .backgroundColor(bg)
    .borderRadius(16)
  }

  /** kind → 类型标签资源（head 空串兜底，与创建页/管理页共用文案源） */
  private kindLabelRes(kind: string): Resource {
    if (kind === 'prs') {
      return $r('app.string.home_work_pull_requests');
    }
    if (kind === 'discussions') {
      return $r('app.string.home_work_discussions');
    }
    return $r('app.string.home_work_issues');
  }

  /** Spec 074：快捷方式行（彩色 tile + 两行文案），与管理页 Saved 行同款（用户 2026-09-21 定案） */
  @Builder
  shortcutRow(item: ShortcutItem) {
    Row({ space: 14 }) {
      Stack() {
        OctIcon({ res: shortcutIconRes(item.iconKey), iconSize: 20, iconColor: shortcutColor(item.colorKey).fg })
      }
      .width(40)
      .height(40)
      .borderRadius(8)
      .backgroundColor(shortcutColor(item.colorKey).bg)
      Column({ space: 2 }) {
        Text(item.head !== '' ? item.head : this.kindLabelRes(item.kind))
          .fontSize($r('app.float.body_font_size'))
          .fontColor($r('app.color.text_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(item.name)
          .fontSize($r('app.float.body_font_size'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .height(72)
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      if (item.kind === 'discussions') {
        // 公开 API 无 discussions 搜索（spec 074 §五）：明确提示而非给出错误结果
        promptAction.showToast({ message: $r('app.string.shortcut_discussions_unsupported') });
        return;
      }
      // 046 searchResults 通道（kind|query）；is:issue/is:pr 类型限定词由通道按 kind 追加
      this.pathStack.pushPathByName('searchResults', `${item.kind}|${item.query}`);
    })
  }

  /** Shortcuts 区块（Spec 074 双态）：空态=013 引导（入口接通管理页）；有值=⋯ 入口 + 快捷方式行列表 */
  @Builder
  shortcutsSection() {
    if (this.shortcuts.length === 0) {
      Text($r('app.string.home_shortcuts'))
        .fontSize($r('app.float.section_title_font_size'))
        .fontWeight(600)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
        .padding({ top: 16, bottom: 12 })

      Column({ space: 12 }) {
        Row() {
          // 当前顺序：zap / issue / pr / discussion / organization / people / briefcase / file-diff
          this.shortcutGlyph($r('app.media.oct_zap_16'), $r('app.color.shortcut_zap_bg'), $r('app.color.shortcut_gray_fg'))
          this.shortcutGlyph($r('app.media.oct_issue_opened_16'), $r('app.color.shortcut_green_bg'), $r('app.color.shortcut_green_fg'))
          this.shortcutGlyph($r('app.media.oct_git_pull_request_16'), $r('app.color.shortcut_blue_bg'), $r('app.color.shortcut_blue_fg'))
          this.shortcutGlyph($r('app.media.oct_comment_discussion_16'), $r('app.color.shortcut_purple_bg'), $r('app.color.shortcut_purple_fg'))
          this.shortcutGlyph($r('app.media.oct_organization_16'), $r('app.color.shortcut_orange_bg'), $r('app.color.shortcut_orange_fg'))
          this.shortcutGlyph($r('app.media.oct_people_16'), $r('app.color.shortcut_pink_bg'), $r('app.color.shortcut_pink_fg'))
          this.shortcutGlyph($r('app.media.oct_briefcase_16'), $r('app.color.shortcut_indigo_bg'), $r('app.color.shortcut_indigo_fg'))
          this.shortcutGlyph($r('app.media.oct_file_diff_16'), $r('app.color.shortcut_file_bg'), $r('app.color.shortcut_gray_fg'))
        }
        .justifyContent(FlexAlign.Center)

        Text($r('app.string.home_shortcuts_title'))
          .fontSize($r('app.float.body_font_size'))
          .fontWeight(600)
          .fontColor($r('app.color.text_primary'))
          .textAlign(TextAlign.Center)
          .width('100%')

        Text($r('app.string.home_shortcuts_desc'))
          .fontSize($r('app.float.body_font_size'))
          .fontColor($r('app.color.text_secondary'))
          .textAlign(TextAlign.Center)
          .width('100%')

        this.outlineButton($r('app.string.home_shortcuts_get_started'), (): void => {
          this.pathStack.pushPathByName('shortcuts', '');
        })
      }
      .padding(24)
      .width('100%')
    } else {
      Row() {
        Text($r('app.string.home_shortcuts'))
          .fontSize($r('app.float.section_title_font_size'))
          .fontWeight(600)
          .fontColor($r('app.color.text_primary'))
        Blank()
        Stack() {
          OctIcon({
            res: $r('app.media.oct_kebab_horizontal_16'),
            iconSize: 18,
            iconColor: $r('app.color.text_secondary')
          })
        }
        .width(44)
        .height(44)
        .accessibilityDescription($r('app.string.a11y_more'))
        .focusable(true)
        .onClick((): void => {
          this.pathStack.pushPathByName('shortcuts', '');
        })
        .padding(4)
      }
      .width('100%')
      .padding({ top: 16, bottom: 4 })

      ForEach(this.shortcuts, (item: ShortcutItem) => {
        this.shortcutRow(item)
      // key 带 shortcutsVersion：管理页 SAVE 泵回后强制重渲染（同 favoritesVersion）
      }, (item: ShortcutItem) => `${item.id}_${this.shortcutsVersion}`)
    }
  }

  build() {
    Column() {
      this.header()

      Refresh({ refreshing: $$this.isRefreshing }) {
        Scroll() {
          Column() {
            // viewer 拉取失败仅降级此提示：My Work/Favorites/Shortcuts 为本地或容错区块照常可用（review A15）
            if (this.viewer === null && this.errorMsg !== '') {
              StateView({
                loading: this.loading,
                error: this.errorMsg,
                onRetry: () => this.refresh()
              })
            }

            this.myWorkSection()

            Divider()
              .color($r('app.color.divider'))
              .margin({ top: 8 })

            this.favoritesSection()

            Divider()
              .color($r('app.color.divider'))
              .margin({ top: 8 })

            this.shortcutsSection()
          }
          .padding({ left: 16, right: 16 })
          .width('100%')
        }
        .scrollBar(BarState.Off)
        .align(Alignment.Top)
        .onScroll((_x: number, y: number): void => {
          this.headerShadow = y > 0.001;
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
    // Spec 070：New repository 两步弹层（官方为自底部弹出近全屏，dragBar 对应官方抓取条）
    .bindSheet(this.newRepoOpen!!, this.newRepoSheet(), {
      height: SheetSize.LARGE,
      showClose: false,
      // LARGE 档框架不渲染 dragBar，抓取条在弹层内容里自绘（官方口径）
      dragBar: false,
      backgroundColor: $r('app.color.card_background'),
      onDisappear: (): void => {
        this.newRepoOpen = false;
      }
    })
  }

  /** 弹层内容：创建成功关弹层并跳新仓库详情（官方动线）；General ✕ 关整个流程 */
  @Builder
  newRepoSheet() {
    NewRepositorySheet({
      token: this.token,
      ownerLoginHint: this.viewer !== null ? this.viewer.login : '',
      ownerAvatarHint: this.viewer !== null ? this.viewer.avatarUrl : '',
      onDismiss: (): void => {
        this.newRepoOpen = false;
      },
      onCreated: (owner: string, name: string): void => {
        this.newRepoOpen = false;
        this.pathStack.pushPathByName('repoDetail', `${owner}/${name}`);
      }
    })
  }
}
