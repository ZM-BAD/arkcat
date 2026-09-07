/**
 * Home Tab（Spec 013）：对齐 GitHub 官方布局。
 * Header（Home 标题/搜索/刷新/新建/头像）+ My Work 七行入口
 * + Favorites 空态 + Shortcuts 引导。
 * 入口列表页与 Favorites 添加流程属后续 Spec，当前点击提示。
 */
import { promptAction } from '@kit.ArkUI';
import { ViewerBasic } from '../models/GitHubModels';
import { HomeService } from '../services/HomeService';
import { friendlyError } from '../services/GitHttpClient';
import { StateView } from '../components/StateView';
import { OctIcon } from '../components/OctIcon';
import { WorkSection, WorkConfigStore, visibleWorkSections } from '../utils/WorkConfig';

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
  @Local workStore: WorkConfigStore = WorkConfigStore.instance;
  @Param workVersion: number = 0;
  @Local sectionsVersion: number = 0;

  aboutToAppear(): void {
    WorkConfigStore.load(this.getUIContext().getHostContext())
      .then(() => {
        // load 完成后再触发一次重渲染（编辑页 SAVE 走 workVersion 参数泵）
        this.sectionsVersion++;
      });
    this.refresh();
  }

  private refresh(): void {
    this.loading = true;
    this.errorMsg = '';
    HomeService.fetchViewerBasic(this.token)
      .then((viewer: ViewerBasic) => {
        this.viewer = viewer;
        this.loading = false;
        this.isRefreshing = false;
      })
      .catch((e: Error) => {
        this.errorMsg = friendlyError(this.getUIContext(), e);
        this.loading = false;
        this.isRefreshing = false;
      });
  }

  private comingSoon(): void {
    promptAction.showToast({ message: $r('app.string.home_feature_coming') });
  }

  /** 标题栏阴影：滚动中显示、回顶部消失 */
  @Local headerShadow: boolean = false;
  @Local isRefreshing: boolean = false;

  @Builder
  header() {
    Column() {
      Row() {
        Text($r('app.string.tab_home'))
          .fontSize(20)
          .fontWeight(600)
          .fontColor($r('app.color.text_primary'))
        Blank()
        Stack() {
          OctIcon({
            res: $r('app.media.oct_search_24'),
            iconSize: 20,
            iconColor: $r('app.color.link_blue')
          })
        }
.width(44)
.height(44)
        .accessibilityDescription($r('app.string.a11y_search'))
        .focusable(true)
        .onClick((): void => {
          this.pathStack.pushPathByName('search', '');
        })
        .padding(6)
        Stack() {
          OctIcon({
            res: $r('app.media.oct_sync_16'),
            iconSize: 18,
            iconColor: $r('app.color.link_blue')
          })
        }
.width(44)
.height(44)
        .accessibilityDescription($r('app.string.a11y_refresh'))
        .focusable(true)
        .onClick((): void => {
          // 与下拉刷新同效果：置位刷新动画，refresh() 完成后复位（review 用户反馈）
          this.isRefreshing = true;
          this.refresh();
        })
        .padding(6)
        Stack() {
          OctIcon({
            res: $r('app.media.oct_plus_circle_24'),
            iconSize: 20,
            iconColor: $r('app.color.link_blue')
          })
        }
.width(44)
.height(44)
        .accessibilityDescription($r('app.string.a11y_new'))
        .focusable(true)
        .onClick((): void => {
          promptAction.showToast({ message: $r('app.string.home_new_coming') });
        })
        .padding(6)
        if (this.viewer !== null) {
          Image(this.viewer.avatarUrl)
            .width(20)
            .height(20)
            .borderRadius(12)
            .backgroundColor($r('app.color.heat_empty'))
            .margin({ left: 4 })
            .onClick(() => {
              this.pathStack.pushPathByName('userProfile', this.viewer?.login ?? '');
            })
        }
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
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
        .fontSize(18)
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
  outlineButton(labelRes: Resource) {
    Button(labelRes)
      .width('100%')
      .height(44)
      .fontSize($r('app.float.caption_font_size'))
      .fontColor($r('app.color.link_blue'))
      .backgroundColor(Color.Transparent)
      .borderRadius(6)
      .border({ width: 1, color: $r('app.color.border') })
      .onClick(() => this.comingSoon())
  }

  @Builder
  favoritesSection() {
    Text($r('app.string.home_favorites'))
      .fontSize(18)
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
      this.outlineButton($r('app.string.home_favorites_add'))
    }
    .padding(24)
    .width('100%')
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

  @Builder
  shortcutsSection() {
    Text($r('app.string.home_shortcuts'))
      .fontSize(18)
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

      this.outlineButton($r('app.string.home_shortcuts_get_started'))
    }
    .padding(24)
    .width('100%')
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
  }
}
