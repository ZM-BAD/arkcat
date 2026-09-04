/**
 * 滚动页顶部阴影条（官方「头部下滑吸附」样式）：
 * 置于固定头部下缘，滚动中显示（内容从阴影下穿过）、回顶部消失。
 * 调用方通过滚动容器的 onScroll 驱动 show（y > 0.001）。
 */
@ComponentV2
export struct PageShadowBar {
  @Param show: boolean = false;

  build() {
    if (this.show) {
      Row()
        .width('100%')
        .height(3)
        .linearGradient({
          direction: GradientDirection.Bottom,
          colors: [
            [$r('app.color.shadow_floating'), 0],
            [Color.Transparent, 1]
          ]
        })
    }
  }
}
