/**
 * 新建入口底部弹层（Spec 043 元素1）：Home「+」/ 仓库页「+」的两行选择
 * （New issue / New pull request，官方创建弹层同构：图标 + 文案行）。
 */
import { OctIcon } from './OctIcon';

@ComponentV2
export struct CreateEntrySheet {
  @Event onIssue: () => void = (): void => { };
  @Event onPr: () => void = (): void => { };

  build() {
    Column() {
      Row({ space: 14 }) {
        OctIcon({ res: $r('app.media.oct_issue_opened_16'), iconSize: 20, iconColor: $r('app.color.text_primary') })
        Text($r('app.string.create_new_issue'))
          .fontSize($r('app.float.body_font_size'))
          .fontColor($r('app.color.text_primary'))
      }
      .width('100%')
      .height(56)
      .padding({ left: 20, right: 16 })
      .onClick((): void => this.onIssue())

      Row({ space: 14 }) {
        OctIcon({ res: $r('app.media.oct_git_pull_request_16'), iconSize: 20, iconColor: $r('app.color.text_primary') })
        Text($r('app.string.create_new_pr'))
          .fontSize($r('app.float.body_font_size'))
          .fontColor($r('app.color.text_primary'))
      }
      .width('100%')
      .height(56)
      .padding({ left: 20, right: 16 })
      .onClick((): void => this.onPr())
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
  }
}
