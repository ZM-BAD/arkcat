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
  @Param iconColor: ResourceColor = '#24292F';

  build() {
    Image(this.res)
      .width(this.iconSize)
      .height(this.iconSize)
      .fillColor(this.iconColor)
  }
}
