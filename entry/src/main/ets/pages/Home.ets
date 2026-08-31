/**
 * Home Tab（Spec 013）：对齐 GitHub 官方布局。
 * Header（Home 标题/搜索/刷新/新建/头像）+ My Work 七行入口
 * + Favorites 空态 + Shortcuts 引导。
 * 入口列表页与 Favorites 添加流程属后续 Spec，当前点击提示。
 */
import { promptAction } from '@kit.ArkUI';
import { ViewerBasic } from '../models/GitHubModels';
import { HomeService } from '../services/HomeService';
import { StateView } from '../components/StateView';
import { OctIcon } from '../components/OctIcon';
import { WorkSection, WorkConfigStore, visibleWorkSections } from '../utils/WorkConfig';

/** My Work 条目标识：图标/色/文案/路由（与 Edit My Work 013/016 一致） */
interface WorkEntryMeta {
  iconRes: Resource;
  color: string;
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
      })
      .catch((e: Error) => {
        this.errorMsg = e.message;
        this.loading = false;
      });
  }

  private comingSoon(): void {
    promptAction.showToast({ message: $r('app.string.home_feature_coming') });
  }

  @Builder
  header() {
    Row() {
      Text($r('app.string.tab_home'))
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
      Blank()
      Stack() {
  OctIcon({
        res: $r('app.media.oct_search_24'),
        iconSize: 20,
        iconColor: $r('app.color.text_primary')
  })
}
.onClick((): void => {
          this.pathStack.pushPathByName('search', '');
        })
        .padding(6)
      Stack() {
  OctIcon({
        res: $r('app.media.oct_sync_16'),
        iconSize: 18,
        iconColor: $r('app.color.text_primary')
  })
}
.onClick((): void => this.refresh())
        .padding(6)
      Stack() {
  OctIcon({
        res: $r('app.media.oct_plus_24'),
        iconSize: 20,
        iconColor: $r('app.color.text_primary')
  })
}
.onClick((): void => {
          promptAction.showToast({ message: $r('app.string.home_new_coming') });
        })
        .padding(6)
      if (this.viewer !== null) {
        Image(this.viewer.avatarUrl)
          .width(32)
          .height(32)
          .borderRadius(16)
          .backgroundColor($r('app.color.heat_empty'))
          .margin({ left: 4 })
          .onClick(() => {
            this.pathStack.pushPathByName('userProfile', this.viewer?.login ?? '');
          })
      }
    }
    .width('100%')
    .height(56)
    .padding({ left: 16, right: 8 })
  }

  /** My Work 条目标识：id → 图标/色/文案/路由（与 Edit My Work 013/016 一致） */
  private workMeta(id: string): WorkEntryMeta {
    switch (id) {
      case 'prs':
        return { iconRes: $r('app.media.oct_git_pull_request_16'), color: '#3C78D8', label: $r('app.string.home_work_pull_requests'), route: 'workPrs' };
      case 'discussions':
        return { iconRes: $r('app.media.oct_comment_discussion_16'), color: '#8250DF', label: $r('app.string.home_work_discussions'), route: 'discussions' };
      case 'projects':
        return { iconRes: $r('app.media.oct_project_16'), color: '#57606A', label: $r('app.string.home_work_projects'), route: 'projects' };
      case 'topRepos':
        return { iconRes: $r('app.media.oct_repo_16'), color: '#24292F', label: $r('app.string.home_work_top_repos'), route: 'topRepos' };
      case 'orgs':
        return { iconRes: $r('app.media.oct_organization_16'), color: '#E87B2E', label: $r('app.string.home_work_organizations'), route: 'organizations' };
      case 'starred':
        return { iconRes: $r('app.media.oct_star_fill_16'), color: '#E3B341', label: $r('app.string.home_work_starred'), route: 'starred' };
      default:
        return { iconRes: $r('app.media.oct_issue_opened_16'), color: '#2DA44E', label: $r('app.string.home_work_issues'), route: 'workIssues' };
    }
  }

  /** My Work 单行入口：彩色圆角方块 + 单色字形 + 标签；按 WorkConfig 过滤/排序 */
  @Builder
  workEntry(meta: WorkEntryMeta) {
    Row() {
      Stack() {
          OctIcon({ res: meta.iconRes, iconSize: 18, iconColor: Color.White })
      }
      .width(34)
      .height(34)
      .backgroundColor(meta.color)
      .borderRadius(8)
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
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
      Blank()
      Stack() {
  OctIcon({
        res: $r('app.media.oct_kebab_horizontal_16'),
        iconSize: 18,
        iconColor: $r('app.color.text_secondary')
  })
}
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
      .borderRadius(8)
      .border({ width: 1, color: $r('app.color.border') })
      .onClick(() => this.comingSoon())
  }

  @Builder
  favoritesSection() {
    Text($r('app.string.home_favorites'))
      .fontSize(20)
      .fontWeight(FontWeight.Bold)
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

  /** Shortcuts 圆形图标：浅色圆底 + 深色字形（bg/fg 走语义色 token） */
  @Builder
  shortcutGlyph(iconRes: Resource, bg: ResourceColor, fg: ResourceColor) {
    Stack() {
      OctIcon({ res: iconRes, iconSize: 14, iconColor: fg })
    }
    .width(30)
    .height(30)
    .backgroundColor(bg)
    .borderRadius(15)
    .margin({ right: 6 })
  }

  @Builder
  shortcutsSection() {
    Text($r('app.string.home_shortcuts'))
      .fontSize(20)
      .fontWeight(FontWeight.Bold)
      .fontColor($r('app.color.text_primary'))
      .width('100%')
      .padding({ top: 16, bottom: 12 })

    Column({ space: 12 }) {
      Row() {
        this.shortcutGlyph($r('app.media.oct_issue_opened_16'), $r('app.color.shortcut_issue_bg'), '#2DA44E')
        this.shortcutGlyph($r('app.media.oct_git_pull_request_16'), $r('app.color.shortcut_pr_bg'), '#3C78D8')
        this.shortcutGlyph($r('app.media.oct_comment_discussion_16'), $r('app.color.shortcut_discussion_bg'), '#8250DF')
        this.shortcutGlyph($r('app.media.oct_project_16'), $r('app.color.shortcut_project_bg'), '#57606A')
        this.shortcutGlyph($r('app.media.oct_organization_16'), $r('app.color.shortcut_org_bg'), '#E87B2E')
        this.shortcutGlyph($r('app.media.oct_star_fill_16'), $r('app.color.shortcut_star_bg'), $r('app.color.star_gold'))
      }
      .padding({ left: 8 })

      Text($r('app.string.home_shortcuts_title'))
        .fontSize($r('app.float.body_font_size'))
        .fontWeight(FontWeight.Bold)
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

      Scroll() {
        Column() {
          if (this.viewer !== null || this.errorMsg === '') {
            this.myWorkSection()

            Divider()
              .color($r('app.color.divider'))
              .margin({ top: 8 })

            this.favoritesSection()

            Divider()
              .color($r('app.color.divider'))
              .margin({ top: 8 })

            this.shortcutsSection()
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
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_page'))
  }
}
