/**
 * 图标计数小胶囊（issue/PR 卡信息密度行）：icon+文本，8/2 内距、radius 12。
 * 两种官方变体：实底（chip_bg 底，灰 icon/字）与描边（透明底+divider 描边，字 text_primary，Checks 状态）。
 * 此前 4 页 8 处逐字手写，现统一收口；尺寸/底色不同的场景（Release 资产胶囊 radius10）不强行归并。
 */
import { OctIcon } from './OctIcon';

@ComponentV2
export struct CountChip {
  @Require @Param icon: Resource;
  @Require @Param text: string;
  @Param iconColor: ResourceColor = $r('app.color.text_secondary');
  @Param textColor: ResourceColor = $r('app.color.text_secondary');
  /** true=描边变体（透明底+divider 描边）；false=实底 chip_bg */
  @Param outlined: boolean = false;

  build() {
    Row({ space: 4 }) {
      OctIcon({ res: this.icon, iconSize: 12, iconColor: this.iconColor })
      Text(this.text)
        .fontSize($r('app.float.caption_font_size'))
        .fontColor(this.textColor)
    }
    .padding({ left: 8, right: 8, top: 2, bottom: 2 })
    .borderRadius(12)
    .border(this.outlined ? { width: 1, color: $r('app.color.divider') } : { width: 0, color: Color.Transparent })
    .backgroundColor(this.outlined ? Color.Transparent : $r('app.color.chip_bg'))
  }
}
