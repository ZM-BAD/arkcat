/**
 * Issue 列表卡（用户 2026-09-19 定案：工作区 Issues 与仓库内 Issues 列表复用同一张卡）。
 * 行1=状态图标 + `owner/name #N` 灰字 + 右侧时间；行2=标题（≤2 行）；
 * 行3=标签胶囊 + 评论数芯片（数量不定，包横向 Scroll 防溢出）。
 */
import { OctIcon } from './OctIcon';
import { LabelPill } from './LabelPill';
import { CountChip } from './CountChip';
import { WorkLabel } from '../models/WorkModels';

@ComponentV2
export struct IssueCard {
  /** 状态图标键：open / closed / not_planned（与工作区 issue.iconKey 同词汇） */
  @Param iconKey: string = 'open';
  /** 卡头仓库全名（仓库内列表同样按工作区口径展示 `owner/name #N`） */
  @Param repoFullName: string = '';
  @Param number: number = 0;
  @Param title: string = '';
  @Param labels: WorkLabel[] = [];
  @Param commentCount: number = 0;
  /** 相对时间文案（调用方经 timeParts/githubShortTime 现算，组件保持纯展示） */
  @Param timeText: string = '';
  @Event onTap: () => void = (): void => { };

  /** 状态图标（Spec 017/024：OPEN 绿 / COMPLETED 紫 / NOT_PLANNED 灰） */
  private icon(): Resource {
    if (this.iconKey === 'open') {
      return $r('app.media.oct_issue_opened_16');
    }
    // 官方字形（DESIGN.md §10.1）：not planned=skip、closed=issue-closed
    return this.iconKey === 'not_planned'
      ? $r('app.media.oct_skip_16')
      : $r('app.media.oct_issue_closed_16');
  }

  private iconColor(): ResourceColor {
    if (this.iconKey === 'open') {
      return $r('app.color.success_text');
    }
    return this.iconKey === 'not_planned' ? $r('app.color.text_secondary') : $r('app.color.shortcut_purple_fg');
  }

  build() {
    Column({ space: 6 }) {
      Row() {
        OctIcon({ res: this.icon(), iconSize: 18, iconColor: this.iconColor() })
        Text(`${this.repoFullName} #${this.number}`)
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_secondary'))
          .margin({ left: 12 })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        Text(this.timeText)
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_secondary'))
      }
      .width('100%')

      Text(this.title)
        .fontSize($r('app.float.body_font_size'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')

      if (this.labels.length > 0 || this.commentCount > 0) {
        // 标签数量不定：包横向 Scroll 防溢出卡片，内层行 minWidth 撑满、超宽可滑
        Scroll() {
          Row() {
            ForEach(this.labels, (label: WorkLabel) => {
              LabelPill({ labelName: label.name, colorHex: label.color })
            }, (label: WorkLabel) => label.name)
            if (this.commentCount > 0) {
              CountChip({ icon: $r('app.media.oct_comment_16'), text: `${this.commentCount}` })
            }
          }
          .constraintSize({ minWidth: '100%' })
        }
        .scrollBar(BarState.Off)
        .width('100%')
      }
    }
    .padding($r('app.float.card_padding'))
    .borderRadius($r('app.float.card_radius'))
    .backgroundColor($r('app.color.card_background'))
    .width('100%')
    .margin({ bottom: 8 })
    .onClick(() => this.onTap())
  }
}
