/**
 * 官方风格空态视图（Spec 017-023 共用）：
 * 插图占位 + 大标题 + 可选副文案 + 可选重置按钮。
 * 加载/错误态仍用 StateView，仅空态走本组件。
 */
@ComponentV2
export struct WorkEmptyView {
  @Param iconText: string = '🐱';
  @Param title: Resource = $r('app.string.state_empty');
  @Param subtitle: Resource | null = null;
  @Param button: Resource | null = null;
  @Event onButton: () => void = () => {};

  build() {
    Column({ space: 12 }) {
      if (this.iconText !== '') {
        Text(this.iconText)
          .fontSize(56)
          .margin({ top: 24 })
      }
      Text(this.title)
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .textAlign(TextAlign.Center)
        .width('100%')
      if (this.subtitle !== null) {
        Text(this.subtitle)
          .fontSize($r('app.float.body_font_size'))
          .fontColor($r('app.color.text_secondary'))
          .textAlign(TextAlign.Center)
          .width('100%')
      }
      if (this.button !== null) {
        Button(this.button)
          .width('70%')
          .height(44)
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.link_blue'))
          .backgroundColor(Color.Transparent)
          .borderRadius(8)
          .border({ width: 1, color: $r('app.color.border') })
          .margin({ top: 12 })
          .onClick(() => this.onButton())
      }
    }
    .width('100%')
    .padding({ top: 48, bottom: 32 })
    .alignItems(HorizontalAlign.Center)
  }
}
