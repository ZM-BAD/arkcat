/**
 * 通用加载/错误/空态视图。各页复用，保证一致的反馈。
 * emptyText 为 Resource，调用方直接传 $r()（Spec 012）。
 */
import { OctIcon } from './OctIcon';
@ComponentV2

export struct StateView {
  @Param loading: boolean = false;
  @Param error: string = '';
  @Param empty: boolean = false;
  @Param emptyText: Resource = $r('app.string.state_empty');
  @Event onRetry: () => void = () => {};

  build() {
    Column({ space: 12 }) {
      if (this.loading) {
        LoadingProgress()
          .width(40)
          .height(40)
          .color($r('app.color.link_blue'))
        Text($r('app.string.state_loading'))
          .fontSize($r('app.float.body_font_size'))
          .fontColor($r('app.color.text_secondary'))
      } else if (this.error !== '') {
        OctIcon({ res: $r('app.media.oct_alert_16'), iconSize: 32, iconColor: $r('app.color.text_secondary') })
        Text(this.error)
          .fontSize($r('app.float.body_font_size'))
          .fontColor($r('app.color.text_secondary'))
          .textAlign(TextAlign.Center)
        Button($r('app.string.state_retry'))
          .buttonStyle(ButtonStyleMode.NORMAL)
          .onClick(() => this.onRetry())
      } else if (this.empty) {
        OctIcon({ res: $r('app.media.oct_file_directory_16'), iconSize: 32, iconColor: $r('app.color.text_secondary') })
        Text(this.emptyText)
          .fontSize($r('app.float.body_font_size'))
          .fontColor($r('app.color.text_secondary'))
      }
    }
    .width('100%')
    .padding(32)
    .alignItems(HorizontalAlign.Center)
  }
}
