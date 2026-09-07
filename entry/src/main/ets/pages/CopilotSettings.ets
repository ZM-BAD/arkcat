/**
 * Copilot settings 页（Spec 058）：Subscription / Usage / About 三分组（用量为 mock）。
 * 纯 UI 架子：套餐名/用量/登录名均 mock 常量，UPGRADE 与链接动作 toast 占位。
 */
import { promptAction } from '@kit.ArkUI';
import { OctIcon } from '../components/OctIcon';
import { PageShadowBar } from '../components/PageShadowBar';
import { resText } from '../utils/I18n';

@ComponentV2
export struct CopilotSettingsView {
  @Param pathStack: NavPathStack = new NavPathStack();
  /** 滚动顶部阴影 */
  @Local scrollShadow: boolean = false;
  /** mock：套餐名/用量/登录名（OAuth 接入后由 057 落库信息替换） */
  private readonly mockPlan: string = 'Copilot Free';
  private readonly mockLogin: string = 'ZM-BAD';
  private readonly mockCompletions: number = 50;
  private readonly mockChat: number = 60;

  private comingSoon(): void {
    promptAction.showToast({ message: $r('app.string.home_feature_coming') });
  }

  /** 分组间 8vp 灰粗分隔条（官方分组样式） */
  @Builder
  groupGap() {
    Row()
      .width('100%')
      .height(8)
      .backgroundColor($r('app.color.bg_page'))
  }

  /** Usage 统计行：名称 + N% used + 蓝色环形进度 */
  @Builder
  usageRow(label: ResourceStr, percent: number) {
    Row({ space: 12 }) {
      Text(label)
        .fontSize(17)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
      Text(resText(this.getUIContext(), $r('app.string.copilot_settings_used'),
        `${percent}%`))
        .fontSize(17)
        .fontColor($r('app.color.text_primary'))
      Progress({ value: percent, total: 100, type: ProgressType.Ring })
        .width(18)
        .height(18)
        .color($r('app.color.link_blue'))
        .style({ strokeWidth: 2.5 })
    }
    .width('100%')
    .padding({ top: 14, bottom: 14 })
  }

  /** About 可点行（点按 toast 占位） */
  @Builder
  aboutRow(label: ResourceStr) {
    Text(label)
      .fontSize(17)
      .fontColor($r('app.color.text_primary'))
      .width('100%')
      .padding({ top: 16, bottom: 16 })
      .onClick(() => this.comingSoon())
  }

  /** 页脚：灰底说明 + 蓝色链接文本（Span 多色） */
  @Builder
  footerNote() {
    Text() {
      Span($r('app.string.copilot_settings_footer_a'))
        .fontColor($r('app.color.text_secondary'))
      Span($r('app.string.copilot_settings_footer_link_match'))
        .fontColor($r('app.color.link_blue'))
        .decoration({ type: TextDecorationType.Underline, color: $r('app.color.link_blue') })
      Span($r('app.string.copilot_settings_footer_b'))
        .fontColor($r('app.color.text_secondary'))
      Span($r('app.string.copilot_settings_footer_link_settings'))
        .fontColor($r('app.color.link_blue'))
        .decoration({ type: TextDecorationType.Underline, color: $r('app.color.link_blue') })
      Span($r('app.string.copilot_settings_footer_c'))
        .fontColor($r('app.color.text_secondary'))
    }
    .fontSize($r('app.float.body_font_size'))
    .lineHeight(22)
    .width('100%')
    .padding(16)
    .backgroundColor($r('app.color.bg_page'))
  }

  build() {
    Column() {
      Row({ space: 4 }) {
        Stack() {
          OctIcon({ res: $r('app.media.oct_arrow_left_24'), iconSize: 20, iconColor: $r('app.color.text_primary') })
        }
        .width(44)
        .height(44)
        .accessibilityDescription($r('app.string.a11y_back'))
        .focusable(true)
        .onClick(() => {
          this.pathStack.pop();
        })

        Text($r('app.string.tab_copilot'))
          .fontSize($r('app.float.title_font_size'))
          .fontWeight(600)
          .fontColor($r('app.color.text_primary'))
      }
      .width('100%')
      .height(52)
      .padding({ left: 4, right: 4 })

      PageShadowBar({ show: this.scrollShadow })

      Scroll() {
        Column() {
          // Subscription 分组
          Text($r('app.string.copilot_settings_subscription'))
            .fontSize($r('app.float.body_font_size'))
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
            .margin({ top: 8, bottom: 4 })

          Text(this.mockPlan)
            .fontSize(28)
            .fontWeight(600)
            .fontColor($r('app.color.text_primary'))
            .width('100%')

          Text(resText(this.getUIContext(), $r('app.string.copilot_settings_active_for'), this.mockLogin))
            .fontSize($r('app.float.body_font_size'))
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
            .margin({ bottom: 16 })

          this.groupGap()

          // Usage 分组
          Text($r('app.string.copilot_settings_usage'))
            .fontSize($r('app.float.body_font_size'))
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
            .margin({ top: 8, bottom: 4 })

          this.usageRow($r('app.string.copilot_settings_code_completions'), this.mockCompletions)
          this.usageRow($r('app.string.copilot_settings_chat_messages'), this.mockChat)

          Button($r('app.string.copilot_settings_upgrade_plan'))
            .fontSize($r('app.float.body_font_size'))
            .fontWeight(600)
            .fontColor($r('app.color.link_blue'))
            .backgroundColor($r('app.color.tab_active_bg'))
            .width('100%')
            .height(44)
            .borderRadius(6)
            .margin({ top: 10 })
            .onClick(() => this.comingSoon())

          Text($r('app.string.copilot_settings_upgrade_desc'))
            .fontSize($r('app.float.body_font_size'))
            .fontColor($r('app.color.text_secondary'))
            .lineHeight(22)
            .width('100%')
            .margin({ top: 10, bottom: 16 })

          this.groupGap()

          // About 分组
          Text($r('app.string.copilot_settings_about'))
            .fontSize($r('app.float.body_font_size'))
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
            .margin({ top: 8, bottom: 4 })

          this.aboutRow($r('app.string.settings_copilot_free'))
          Divider().strokeWidth(0.5).color($r('app.color.divider'))
          this.aboutRow($r('app.string.copilot_settings_copilot'))
          Divider().strokeWidth(0.5).color($r('app.color.divider'))
          this.aboutRow($r('app.string.copilot_settings_privacy_policy'))
          Divider().strokeWidth(0.5).color($r('app.color.divider'))
          this.aboutRow($r('app.string.copilot_settings_terms'))
        }
        .padding({ left: 16, right: 16, bottom: 16 })
        .width('100%')
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
      .onScroll((_x: number, y: number): void => {
        this.scrollShadow = y > 0.001;
      })

      this.footerNote()
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_page'))
  }
}
