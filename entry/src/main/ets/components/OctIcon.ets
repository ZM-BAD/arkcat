/**
 * Octicons 统一图标组件（Spec 024）。
 *
 * 约定：页面禁止直接 Image($r('app.media.oct_*'))，一律经本组件渲染，
 * 便于统一尺寸/着色，后续自研图标可直接替换组件内部实现。
 * 资源命名：media/oct_<name>_<size>.svg（与 assets/octicons/icons/ 原始文件一致）。
 */
@ComponentV2
export struct OctIcon {
  @Param res: Resource = $r('app.media.oct_arrow_left_24');
  @Param iconSize: number = 16;
  @Param iconColor: ResourceColor = $r('app.color.text_primary');

  build() {
    Image(this.res)
      .width(this.iconSize)
      .height(this.iconSize)
      .fillColor(this.iconColor)
      // Image 的 draggable 默认 true（官方「拖拽事件」文档）——不关掉的话，在可拖拽列表里
      // 长按图标会被当成「拖出这张图」，List 的行拖拽永远起不来（EditMyWork 拖拽柄曾因此失效）。
      // 图标在本项目只作视觉/按钮，全库无人依赖拖出能力。
      .draggable(false)
  }
}
