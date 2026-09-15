/**
 * 分组区块行两件套（Starred 页三处分组头 + 两处列表行收敛；Home/ListDetail 后续可复用）：
 * - SectionHeaderRow：左图标 + 标题（+ 右侧可选蓝色动作文案，如 + NEW）
 * - UserListRow：名称 + 右侧数量文本（星标列表行）
 */
import { OctIcon } from './OctIcon';

@ComponentV2
export struct SectionHeaderRow {
  @Require @Param icon: Resource;
  @Require @Param title: ResourceStr;
  @Param iconSize: number = 16;
  @Param rowHeight: number = 44;
  /** Starred 分组头为 16fp/Medium，列表头为 body 字号常规（历史口径，参数保留） */
  @Param titleFontSize: Length = $r('app.float.body_font_size');
  @Param titleBold: boolean = false;
  /** 右侧动作文案（如 + NEW）；空串不渲染 */
  @Param actionText: ResourceStr = '';
  @Event onAction: () => void = (): void => { };

  build() {
    Row() {
      OctIcon({ res: this.icon, iconSize: this.iconSize, iconColor: $r('app.color.text_secondary') })
      Text(this.title)
        .fontSize(this.titleFontSize)
        .fontWeight(this.titleBold ? FontWeight.Medium : FontWeight.Normal)
        .fontColor($r('app.color.text_primary'))
        .margin({ left: 10 })
      Blank()
      if (this.actionText !== '') {
        Text(this.actionText)
          .fontSize($r('app.float.body_font_size'))
          .fontColor($r('app.color.link_blue'))
          .responseRegion({ x: -6, y: -7, width: '130%', height: '147%' })
          .onClick((): void => this.onAction())
      }
    }
    .width('100%')
    .height(this.rowHeight)
  }
}

@ComponentV2
export struct UserListRow {
  @Require @Param name: string;
  /** 已格式化的数量文本（调用方 compactCount） */
  @Require @Param count: string;
  @Event onOpen: () => void = (): void => { };

  build() {
    Row() {
      Text(this.name)
        .fontSize($r('app.float.body_font_size'))
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(this.count)
        .fontSize($r('app.float.caption_font_size'))
        .fontColor($r('app.color.text_secondary'))
    }
    .width('100%')
    .height(48)
    .onClick((): void => this.onOpen())
  }
}
