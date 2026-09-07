/**
 * 分页列表底部加载指示（触底加载更多时的动态效果）。
 * show=true 显示蓝色转圈；固定内距保证出现/消失时列表底部高度不跳动。
 */
@ComponentV2
export struct ListLoadingFooter {
  @Param show: boolean = false;

  build() {
    Column() {
      if (this.show) {
        LoadingProgress()
          .width(24)
          .height(24)
          .color($r('app.color.link_blue'))
      }
    }
    .width('100%')
    .padding({ top: 14, bottom: 18 })
    .alignItems(HorizontalAlign.Center)
  }
}
