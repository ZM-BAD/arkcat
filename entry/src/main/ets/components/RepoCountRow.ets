/**
 * 仓库详情计数行（Spec 006 元素 8）：彩块图标 + 标签 + 行尾计数。
 *
 * 计数走 @Param 而非共用 @Builder 的值参数：V2 里 @Builder 按值传的参数不参与依赖收集，
 * 值被复制成局部量后没有重算路径 → 数字冻结在首帧（详情页 > 个人页两处同批修复，2026-09-22）。
 */
import { OctIcon } from './OctIcon';

@ComponentV2
export struct RepoCountRow {
  @Require @Param iconRes: Resource;
  @Param tintColor: ResourceColor = '';
  @Require @Param labelRes: Resource;
  /** 负数=无计数（行内不显示数字，仅作入口，如 Actions 行） */
  @Param count: number = -1;
  @Event onTap: () => void = (): void => { };

  build() {
    Row({ space: 12 }) {
      Stack() {
        OctIcon({ res: this.iconRes, iconSize: 16, iconColor: Color.White })
      }
      .width(32)
      .height(32)
      .backgroundColor(this.tintColor)
      .borderRadius(6)
      Text(this.labelRes)
        .fontSize($r('app.float.body_font_size'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
      if (this.count >= 0) {
        Text(`${this.count}`)
          .fontSize($r('app.float.body_font_size'))
          .fontColor($r('app.color.text_secondary'))
      }
    }
    .width('100%')
    .height(48)
    .padding({ left: 16, right: 16 })
    .onClick((): void => this.onTap())
  }
}
