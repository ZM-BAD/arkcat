/**
 * Commit 详情 CHANGES 文件块（官方 Commit 页）：文件名（白底）+ 展开全量 diff。
 * 与 PrDiffCard 差异：无折叠/勾选框/菜单；hunk 头蓝底蓝字无 fold 图标（对照官方截图）。
 */
import { OctIcon } from './OctIcon';
import { CommitFileItem } from '../models/PrDiffModels';
import { DiffHunk, DiffLine } from '../utils/Diff';

@ComponentV2
export struct CommitDiffBlock {
  @Param file: CommitFileItem | null = null;
  /** Code Options「展示行号」开关（父页面读取后传入） */
  @Param showLineNumbers: boolean = true;

  /** 单列行号文案：del 行旧号，其余新号；0 显示空 */
  private lineNoText(line: DiffLine): string {
    const no = line.kind === 'del' ? line.oldLine : line.newLine;
    return no > 0 ? `${no}` : '';
  }

  private diffFg(line: DiffLine): ResourceColor {
    return line.kind === 'add' ? $r('app.color.diff_add_fg')
      : (line.kind === 'del' ? $r('app.color.diff_del_fg') : $r('app.color.text_primary'));
  }

  private diffBg(line: DiffLine): ResourceColor {
    return line.kind === 'add' ? $r('app.color.diff_add_bg')
      : (line.kind === 'del' ? $r('app.color.diff_del_bg') : Color.Transparent);
  }

  /** 单条 diff 行：行号列（可选）+ ±/空格前缀 + 等宽内容 */
  @Builder
  diffLine(line: DiffLine) {
    Row() {
      if (this.showLineNumbers) {
        Text(this.lineNoText(line))
          .width(44)
          .fontFamily('monospace')
          .fontSize(12)
          .textAlign(TextAlign.End)
          .fontColor($r('app.color.text_tertiary'))
          .padding({ right: 8 })
      }
      Text(line.kind === 'add' ? '+' : (line.kind === 'del' ? '-' : ' '))
        .width(20)
        .fontFamily('monospace')
        .fontSize(12)
        .textAlign(TextAlign.Center)
        .fontColor(this.diffFg(line))
      Text(line.text)
        .fontFamily('monospace')
        .fontSize(12)
        .fontColor(this.diffFg(line))
        .maxLines(4)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
    }
    .width('100%')
    .padding({ left: 8, right: 8, top: 2, bottom: 2 })
    .alignItems(VerticalAlign.Top)
    .backgroundColor(this.diffBg(line))
  }

  /** hunk 块：@@ 标题行（蓝字蓝底；让出号列与 ± 列，停留在代码区内） + 行列表 */
  @Builder
  hunkBlock(hunk: DiffHunk) {
    Column() {
      Row() {
        // 行号列占位（与 diffLine 网格对齐）+ ± 列占位
        if (this.showLineNumbers) {
          Row().width(44)
        }
        Row().width(20)
        Text(hunk.header)
          .fontFamily('monospace')
          .fontSize(12)
          .fontColor($r('app.color.diff_hunk_head_fg'))
          .textAlign(TextAlign.Start)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 8, right: 8, top: 3, bottom: 3 })
      .backgroundColor($r('app.color.diff_hunk_head_bg'))
      ForEach(hunk.lines, (line: DiffLine, idx: number) => {
        this.diffLine(line)
      }, (line: DiffLine, idx: number) => idx + '_' + line.kind + '_' + line.text)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Column() {
      if (this.file !== null) {
        // 文件名行
        Row({ space: 8 }) {
          OctIcon({ res: $r('app.media.oct_file_16'), iconSize: 14, iconColor: $r('app.color.text_secondary') })
          Text(this.file.path)
            .fontFamily('monospace')
            .fontSize($r('app.float.caption_font_size'))
            .fontColor($r('app.color.text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
        }
        .width('100%')
        .padding({ left: 10, right: 10, top: 10, bottom: 8 })
        // 文件 diff：无 patch（大 diff/二进制）时只显示文件名
        ForEach(this.file.hunks, (hunk: DiffHunk, idx: number) => {
          this.hunkBlock(hunk)
        }, (hunk: DiffHunk, idx: number) => idx + '_' + hunk.header)
      }
    }
    .width('100%')
    .backgroundColor(Color.Transparent)
  }
}
