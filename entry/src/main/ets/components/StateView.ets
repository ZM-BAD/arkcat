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
  /** 空态副文案（如「已加载范围内无匹配」）；null 不渲染 */
  @Param emptySub: Resource | null = null;
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
        OctIcon({ res: $r('app.media.oct_alert_16'), iconSize: 24, iconColor: $r('app.color.text_secondary') })
        Text(this.error)
          .fontSize($r('app.float.body_font_size'))
          .fontColor($r('app.color.text_secondary'))
          .textAlign(TextAlign.Center)
        Button($r('app.string.state_retry'))
          .buttonStyle(ButtonStyleMode.NORMAL)
          .responseRegion({ x: 0, y: -2, width: '100%', height: '110%' })
          .onClick(() => this.onRetry())
      } else if (this.empty) {
        OctIcon({ res: $r('app.media.oct_file_directory_16'), iconSize: 24, iconColor: $r('app.color.text_secondary') })
        Text(this.emptyText)
          .fontSize($r('app.float.body_font_size'))
          .fontColor($r('app.color.text_secondary'))
        if (this.emptySub !== null) {
          Text(this.emptySub)
            .fontSize($r('app.float.caption_font_size'))
            .fontColor($r('app.color.text_secondary'))
            .textAlign(TextAlign.Center)
        }
      }
    }
    .width('100%')
    .padding(32)
    .alignItems(HorizontalAlign.Center)
  }
}
