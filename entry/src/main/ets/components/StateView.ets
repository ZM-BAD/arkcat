/**
 * 通用加载/错误/空态视图。各页复用，保证一致的反馈。
 */
@ComponentV2
export struct StateView {
  @Param loading: boolean = false;
  @Param error: string = '';
  @Param empty: boolean = false;
  @Param emptyText: string = '';
  @Event onRetry: () => void = () => {};

  build() {
    Column({ space: 12 }) {
      if (this.loading) {
        LoadingProgress()
          .width(40)
          .height(40)
          .color($r('app.color.primary'))
        Text($r('app.string.state_loading'))
          .fontSize($r('app.float.body_font_size'))
          .fontColor($r('app.color.text_secondary'))
      } else if (this.error !== '') {
        Text('⚠️')
          .fontSize(32)
        Text(this.error)
          .fontSize($r('app.float.body_font_size'))
          .fontColor($r('app.color.text_secondary'))
          .textAlign(TextAlign.Center)
        Button($r('app.string.state_retry'))
          .buttonStyle(ButtonStyleMode.NORMAL)
          .onClick(() => this.onRetry())
      } else if (this.empty) {
        Text('🗂')
          .fontSize(32)
        Text(this.emptyText !== '' ? this.emptyText : $r('app.string.state_empty'))
          .fontSize($r('app.float.body_font_size'))
          .fontColor($r('app.color.text_secondary'))
      }
    }
    .width('100%')
    .padding(32)
    .alignItems(HorizontalAlign.Center)
  }
}
