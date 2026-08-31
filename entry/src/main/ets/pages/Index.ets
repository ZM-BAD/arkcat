@Entry
@Component
struct Index {
  @State message: string = 'Hello StarRaft';

  build() {
    Column() {
      Text(this.message)
        .fontSize($r('app.float.page_text_font_size'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .margin({ top: $r('app.float.hero_margin_top') })

      Text('纯血鸿蒙 GitHub 客户端')
        .fontSize($r('app.float.sub_text_font_size'))
        .fontColor($r('app.color.text_secondary'))
        .margin({ top: $r('app.float.sub_margin_top') })

      Blank()

      Button('开始 TDD 之旅')
        .width('80%')
        .height($r('app.float.button_height'))
        .backgroundColor($r('app.color.primary'))
        .fontColor(Color.White)
        .margin({ bottom: $r('app.float.button_bottom_margin') })
        .onClick(() => {
          // TODO: 导航到主页
        })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
    .alignItems(HorizontalAlign.Center)
  }
}
