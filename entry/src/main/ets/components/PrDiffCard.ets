/**
 * PR Diff 单文件卡（Spec 010）：文件头（路径/±统计/折叠箭头/查看）+ 展开后的 hunk diff 行。
 * 展开态由父页面持有（@Local 数组重建触发刷新），本组件按 @Param 只读渲染；
 * diff 行三色（add/del/ctx）走 color.json token，行内容 monospace，长行钳 4 行防白屏。
 */
import { OctIcon } from './OctIcon';
import { PrFileItem } from '../models/PrDiffModels';
import { DiffHunk, DiffLine, fileBaseName } from '../utils/Diff';
import { resText } from '../utils/I18n';

@ComponentV2
export struct PrDiffCard {
  @Param item: PrFileItem | null = null;
  @Event onToggle: () => void = (): void => { };
  @Event onOpenFile: () => void = (): void => { };

  private stringOf(res: Resource): string {
    return resText(this.getUIContext(), res);
  }

  /** 单条 diff 行：±/空格前缀 + 等宽内容；add/del 行底色与文字色按官方配色 */
  @Builder
  diffLine(line: DiffLine) {
    Row() {
      Text(line.kind === 'add' ? '+' : (line.kind === 'del' ? '-' : ' '))
        .width(20)
        .fontFamily('monospace')
        .fontSize(12)
        .textAlign(TextAlign.Center)
        .fontColor(line.kind === 'add' ? $r('app.color.diff_add_fg')
          : (line.kind === 'del' ? $r('app.color.diff_del_fg') : $r('app.color.text_secondary')))
      Text(line.text)
        .fontFamily('monospace')
        .fontSize(12)
        .fontColor(line.kind === 'add' ? $r('app.color.diff_add_fg')
          : (line.kind === 'del' ? $r('app.color.diff_del_fg') : $r('app.color.text_primary')))
        .maxLines(4)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
    }
    .width('100%')
    .padding({ left: 8, right: 8, top: 2, bottom: 2 })
    .alignItems(VerticalAlign.Top)
    .backgroundColor(line.kind === 'add' ? $r('app.color.diff_add_bg')
      : (line.kind === 'del' ? $r('app.color.diff_del_bg') : Color.Transparent))
  }

  /** hunk 块：@@ 标题行 + 行列表 */
  @Builder
  hunkBlock(hunk: DiffHunk) {
    Column() {
      Text(hunk.header)
        .fontFamily('monospace')
        .fontSize(12)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
        .padding({ left: 8, right: 8, top: 3, bottom: 3 })
        .backgroundColor($r('app.color.diff_hunk_bg'))
      ForEach(hunk.lines, (line: DiffLine, idx: number) => {
        this.diffLine(line)
      }, (line: DiffLine, idx: number) => idx + '_' + line.kind + '_' + line.text)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Column() {
      if (this.item !== null) {
        Row({ space: 6 }) {
          OctIcon({ res: $r('app.media.oct_file_16'), iconSize: 14, iconColor: $r('app.color.text_secondary') })
          Text(this.item.path)
            .fontFamily('monospace')
            .fontSize(12)
            .fontColor($r('app.color.text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          Text(`+${this.item.additions}`)
            .fontSize(12)
            .fontColor($r('app.color.diff_add_fg'))
          Text(`-${this.item.deletions}`)
            .fontSize(12)
            .fontColor($r('app.color.diff_del_fg'))
          Stack() {
            OctIcon({ res: $r('app.media.oct_chevron_down_16'), iconSize: 16,
              iconColor: $r('app.color.text_secondary') })
              .rotate({ angle: this.item.expanded ? 180 : 0 })
          }
          .width(36)
          .height(36)
          .padding(10)
          .accessibilityDescription(this.item.expanded ? $r('app.string.a11y_collapse') : $r('app.string.a11y_expand'))
          .focusable(true)
          .onClick(() => {
            this.onToggle();
          })
          Stack() {
            OctIcon({ res: $r('app.media.oct_eye_16'), iconSize: 16, iconColor: $r('app.color.text_secondary') })
          }
          .width(36)
          .height(36)
          .padding(10)
          .accessibilityDescription($r('app.string.a11y_view_file'))
          .focusable(true)
          .onClick(() => {
            this.onOpenFile();
          })
        }
        .width('100%')
        .height(44)
        .padding({ left: 10, right: 2 })
        .onClick(() => {
          this.onToggle();
        })

        if (this.item.expanded) {
          if (this.item.hunks.length === 0) {
            Text(this.item.diffTooLarge ? this.stringOf($r('app.string.pr_diff_too_large'))
              : this.stringOf($r('app.string.pr_files_empty')))
              .fontSize($r('app.float.caption_font_size'))
              .fontColor($r('app.color.text_secondary'))
              .width('100%')
              .padding({ left: 10, right: 10, top: 6, bottom: 8 })
          } else {
            ForEach(this.item.hunks, (hunk: DiffHunk, idx: number) => {
              this.hunkBlock(hunk)
            }, (hunk: DiffHunk, idx: number) => idx + '_' + hunk.header)
          }
        }
      }
    }
    .width('100%')
    .margin({ bottom: 10 })
    .borderRadius($r('app.float.card_radius'))
    .backgroundColor($r('app.color.card_background'))
    .clip(true)
  }
}
