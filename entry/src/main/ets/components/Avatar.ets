/**
 * 头像组件：统一「Image + 尺寸/圆角 + 占位底色 + 空值兜底」。
 *
 * 此前 30+ 处手写同构 Image 块，占位色漂移三套（heat_empty/text_tertiary/chip_bg）、
 * 空值兜底只有个别页面有——现统一：占位色 heat_empty（明暗双套最接近官方头像占位），
 * 空值可用 fallbackIcon 显示 person 兜底图标（RepoPeopleView 先例）。
 */
import { OctIcon } from './OctIcon';

@ComponentV2
export struct Avatar {
  @Param url: string = '';
  /** 边长（vp）；圆角=边长一半（circle）或 6（square，组织方形头像） */
  @Param diameter: number = 40;
  /** true=方形（radius 6，org 头像）；false=圆形 */
  @Param square: boolean = false;
  /** url 为空时居中显示 person 兜底图标 */
  @Param fallbackIcon: boolean = false;

  build() {
    Stack() {
      Image(this.url)
        .width(this.diameter)
        .height(this.diameter)
        .borderRadius(this.square ? 6 : this.diameter / 2)
        .backgroundColor($r('app.color.heat_empty'))
      if (this.url === '' && this.fallbackIcon) {
        OctIcon({ res: $r('app.media.oct_person_16'), iconSize: this.diameter / 2,
          iconColor: $r('app.color.text_secondary') })
      }
    }
    .width(this.diameter)
    .height(this.diameter)
  }
}
