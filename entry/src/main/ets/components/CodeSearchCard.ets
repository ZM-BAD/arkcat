/**
 * 代码搜索结果卡（Spec 046 结果页批 / 官方版式）：
 * - 顶部胶囊徽章（● Text / ● Markdown）+ 分隔线
 * - 行号 gutter（灰底右对齐）+ 内容区（白底、命中词黄底高亮，行内最多 2 处）
 * - 剩余匹配行尾「Show N more matches」展开（unfold 图标）
 * 无行号（no<=0）时隐藏 gutter（内容获取失败的降级预览）。
 */
import { OctIcon } from './OctIcon';
import { CodeFileResult, CodeLine } from '../services/CodeSearchService';
import { resText } from '../utils/I18n';

@ComponentV2
export struct CodeSearchCard {
  @Param file: CodeFileResult | null = null;
  /** 点击卡面 → CodeViewer（父级注入 pushPathByName('codeViewer', owner|name|path)） */
  @Event onOpen: () => void = (): void => {};
  @Local expanded: boolean = false;

  private badgeText(): string {
    const f = this.file;
    if (f === null) {
      return '';
    }
    const ui = this.getUIContext();
    return f.isMarkdown ? resText(ui, $r('app.string.markdown_badge')) : resText(ui, $r('app.string.search_file_type_text'));
  }

  /** 命中行：prefix/hits/suffix 分段（静态 3/5 span，行内最多 2 处高亮） */
  @Builder
  lineContent(line: CodeLine) {
    if (line.highlights.length === 0) {
      Text(line.text)
        .fontSize($r('app.float.caption_font_size'))
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
        .lineHeight(19)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    } else if (line.highlights.length === 1) {
      Text() {
        Span(line.text.substring(0, line.highlights[0].start))
        Span(line.text.substring(line.highlights[0].start, line.highlights[0].end))
          .fontColor($r('app.color.text_primary'))
          .textBackgroundStyle({ color: $r('app.color.checks_pending_bg'), radius: 3 })
        Span(line.text.substring(line.highlights[0].end))
      }
      .fontSize($r('app.float.caption_font_size'))
      .fontColor($r('app.color.text_primary'))
      .layoutWeight(1)
      .lineHeight(19)
      .maxLines(2)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
    } else {
      Text() {
        Span(line.text.substring(0, line.highlights[0].start))
        Span(line.text.substring(line.highlights[0].start, line.highlights[0].end))
          .fontColor($r('app.color.text_primary'))
          .textBackgroundStyle({ color: $r('app.color.checks_pending_bg'), radius: 3 })
        Span(line.text.substring(line.highlights[0].end, line.highlights[1].start))
        Span(line.text.substring(line.highlights[1].start, line.highlights[1].end))
          .fontColor($r('app.color.text_primary'))
          .textBackgroundStyle({ color: $r('app.color.checks_pending_bg'), radius: 3 })
        Span(line.text.substring(line.highlights[1].end))
      }
      .fontSize($r('app.float.caption_font_size'))
      .fontColor($r('app.color.text_primary'))
      .layoutWeight(1)
      .lineHeight(19)
      .maxLines(2)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
  }

  @Builder
  codeLine(line: CodeLine) {
    Row() {
      if (line.no > 0) {
        Text(`${line.no}`)
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_tertiary'))
          .textAlign(TextAlign.End)
          .width(44)
          .padding({ right: 10 })
      }
      this.lineContent(line)
    }
    .width('100%')
  }

  build() {
    Column() {
      // 头部 + 代码体为可点区（→ CodeViewer）；与「Show more matches」拆成同层兄弟，
      // 规避 ClickEvent 无 stopPropagation 的冒泡误触（沿 010 批定案拆分模式）
      Column() {
        Row() {
          Row({ space: 7 }) {
            Circle()
              .width(10)
              .height(10)
              .fill($r('app.color.link_blue'))
            Text(this.badgeText())
              .fontSize($r('app.float.body_font_size'))
              .fontColor($r('app.color.text_primary'))
          }
          .padding({ left: 12, right: 14, top: 6, bottom: 6 })
          .borderRadius(16)
          .border({ width: 1, color: $r('app.color.divider') })
        }
        .width('100%')
        .padding({ left: 12, right: 12, top: 11, bottom: 11 })

        Divider().color($r('app.color.divider')).strokeWidth(1)

        Row() {
          Column() {
            if (this.file !== null) {
              ForEach(this.file.snippet.window, (line: CodeLine, idx: number) => {
                this.codeLine(line)
              }, (line: CodeLine, idx: number) => `${idx}-${line.no}-${line.text}`)
              if (this.expanded) {
                ForEach(this.file.snippet.more, (line: CodeLine, idx: number) => {
                  this.codeLine(line)
                }, (line: CodeLine, idx: number) => `${idx}-${line.no}-${line.text}`)
              }
            }
          }
          .width('100%')
        }
        .width('100%')
        .padding({ top: 10, bottom: 10 })
        .backgroundColor($r('app.color.card_background'))
      }
      .width('100%')
      .onClick(() => this.onOpen())

      if (this.file !== null && this.file.snippet.more.length > 0) {
        Divider().color($r('app.color.divider')).strokeWidth(1)
        Row({ space: 10 }) {
          OctIcon({
            res: this.expanded ? $r('app.media.oct_fold_up_16') : $r('app.media.oct_unfold_16'),
            iconSize: 16,
            iconColor: $r('app.color.text_secondary')
          })
          Text(this.expanded
            ? resText(this.getUIContext(), $r('app.string.search_show_less_matches'))
            : resText(this.getUIContext(), $r('app.string.search_show_more_matches'), this.file.snippet.more.length))
            .fontSize($r('app.float.body_font_size'))
            .fontColor($r('app.color.text_secondary'))
        }
        .width('100%')
        .height(44)
        .padding({ left: 14, right: 14 })
        .onClick(() => {
          this.expanded = !this.expanded;
        })
      }
    }
    .borderRadius(6)
    .border({ width: 1, color: $r('app.color.divider') })
    .backgroundColor($r('app.color.card_background'))
    .width('100%')
  }
}
