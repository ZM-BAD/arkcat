/**
 * Copilot Tab（Spec 004）：全部 Chat 功能依赖 Copilot 私有 API，无公开接口，
 * 按 Spec 边界展示 Empty State。问候区为纯展示。
 */
@ComponentV2
export struct CopilotView {
  build() {
    Column({ space: 12 }) {
      Text('☀️')
        .fontSize(40)
        .margin({ top: 24 })
      Text($r('app.string.copilot_title'))
        .fontSize($r('app.float.title_font_size'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))

      Column({ space: 8 }) {
        Text('🤖')
          .fontSize(48)
        Text($r('app.string.copilot_unsupported'))
          .fontSize($r('app.float.body_font_size'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
        Text($r('app.string.copilot_hint'))
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_secondary'))
      }
      .padding(32)
      .borderRadius($r('app.float.card_radius'))
      .backgroundColor($r('app.color.card_background'))
      .margin({ top: 48, left: 24, right: 24 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_page'))
  }
}
