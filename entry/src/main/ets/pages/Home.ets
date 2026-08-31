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

@ComponentV2
export struct HomeView {
  @Param token: string = '';
  @Param pathStack: NavPathStack = new NavPathStack();
  @Local viewer: ViewerBasic | null = null;
  @Local loading: boolean = true;
  @Local errorMsg: string = '';

  aboutToAppear(): void {
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
      Text('🔍')
        .fontSize(18)
        .padding(6)
        .onClick(() => {
          this.pathStack.pushPathByName('search', '');
        })
      Text('🔄')
        .fontSize(18)
        .padding(6)
        .onClick(() => this.refresh())
      Text('＋')
        .fontSize(20)
        .padding(6)
        .onClick(() => {
          promptAction.showToast({ message: $r('app.string.home_new_coming') });
        })
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

  /** My Work 单行入口：彩色圆角方块 + 单色字形 + 标签 */
  @Builder
  workEntry(icon: string, color: string, labelRes: Resource) {
    Row() {
      Text(icon)
        .fontSize(15)
        .fontColor(Color.White)
        .width(34)
        .height(34)
        .textAlign(TextAlign.Center)
        .backgroundColor(color)
        .borderRadius(8)
      Text(labelRes)
        .fontSize($r('app.float.body_font_size'))
        .fontColor($r('app.color.text_primary'))
        .margin({ left: 12 })
    }
    .width('100%')
    .height(52)
    .alignItems(VerticalAlign.Center)
    .onClick(() => this.comingSoon())
  }

  @Builder
  myWorkSection() {
    Row() {
      Text($r('app.string.home_my_work'))
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
      Blank()
      Text('⋯')
        .fontSize(18)
        .fontColor($r('app.color.text_secondary'))
        .padding(4)
        .onClick(() => this.comingSoon())
    }
    .width('100%')
    .padding({ top: 16, bottom: 4 })

    this.workEntry('◷', '#2DA44E', $r('app.string.home_work_issues'))
    this.workEntry('⇄', '#3C78D8', $r('app.string.home_work_pull_requests'))
    this.workEntry('❞', '#8250DF', $r('app.string.home_work_discussions'))
    this.workEntry('▦', '#57606A', $r('app.string.home_work_projects'))
    this.workEntry('▤', '#24292F', $r('app.string.home_work_top_repos'))
    this.workEntry('⌂', '#E87B2E', $r('app.string.home_work_organizations'))
    this.workEntry('★', '#E3B341', $r('app.string.home_work_starred'))
  }

  @Builder
  outlineButton(labelRes: Resource) {
    Button(labelRes)
      .width('100%')
      .height(44)
      .fontSize($r('app.float.caption_font_size'))
      .fontColor('#0969DA')
      .backgroundColor(Color.Transparent)
      .borderRadius(8)
      .border({ width: 1, color: '#D0D7DE' })
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

  /** Shortcuts 圆形图标：浅色圆底 + 深色字形 */
  @Builder
  shortcutGlyph(icon: string, bg: string, fg: string) {
    Text(icon)
      .fontSize(13)
      .fontColor(fg)
      .width(30)
      .height(30)
      .textAlign(TextAlign.Center)
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
        this.shortcutGlyph('◷', '#E7F0FF', '#2DA44E')
        this.shortcutGlyph('⇄', '#E6F4EA', '#3C78D8')
        this.shortcutGlyph('❞', '#F3E6FF', '#8250DF')
        this.shortcutGlyph('▦', '#FFF4D6', '#57606A')
        this.shortcutGlyph('⌂', '#FFF0E6', '#E87B2E')
        this.shortcutGlyph('★', '#FFE6E6', '#B88700')
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
              .color('#E5E7EB')
              .margin({ top: 8 })

            this.favoritesSection()

            Divider()
              .color('#E5E7EB')
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
