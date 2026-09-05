/**
 * Explore Activity 卡片（Spec 056）：贡献者行（头像+org 小像+文案+相对时间）
 * + PR 概要卡（仓库行/标题/Merged 徽章+分支芯片/Summary 折叠/反应笑脸）。
 * 点击分区进 prDetail/repoDetail/userProfile（同级兄弟拆分，防父子 onClick 双触发）。
 */
import { ExploreActivityEvent, SUMMARY_COLLAPSED_LINES, SummaryLine, SummarySegment, summarizeBody } from '../models/ExploreModels';
import { resText } from '../utils/I18n';
import { githubShortTime, timeParts } from '../utils/Format';
import { OctIcon } from './OctIcon';
import { ReactionBar } from './ReactionBar';

@ComponentV2
export struct ExploreActivityCard {
  @Param token: string = '';
  @Param event: ExploreActivityEvent | null = null;
  @Event onOpenPr: () => void = (): void => { };
  @Event onOpenRepo: () => void = (): void => { };
  @Event onOpenUser: () => void = (): void => { };
  /** Summary 展开（Read more → 全高无内滚，Spec 010 定案） */
  @Local expanded: boolean = false;

  private stringOf(res: Resource): string {
    return resText(this.getUIContext(), res);
  }

  private timeText(): string {
    if (this.event === null) {
      return '';
    }
    const parts = timeParts(this.event.createdAt, Date.now());
    return parts !== null ? githubShortTime(parts) : '';
  }

  private summaryLines(): SummaryLine[] {
    return this.event !== null ? summarizeBody(this.event.body) : [];
  }

  private hasSummary(): boolean {
    return this.event !== null && this.event.body.trim() !== '';
  }

  /** 折叠态只取前 N 行（超出部分渐隐） */
  private visibleLines(): SummaryLine[] {
    const lines = this.summaryLines();
    if (!this.expanded && lines.length > SUMMARY_COLLAPSED_LINES) {
      return lines.slice(0, SUMMARY_COLLAPSED_LINES);
    }
    return lines;
  }

  private hasMoreLines(): boolean {
    return !this.expanded && this.summaryLines().length > SUMMARY_COLLAPSED_LINES;
  }

  @Builder
  contributorHeader() {
    if (this.event !== null) {
      Row({ space: 8 }) {
        Stack({ alignContent: Alignment.BottomEnd }) {
          if (this.event.authorAvatar !== '') {
            Image(this.event.authorAvatar)
              .width(26)
              .height(26)
              .borderRadius(13)
              .backgroundColor($r('app.color.heat_empty'))
          } else {
            Circle().width(26).height(26).fill($r('app.color.heat_empty'))
          }
          // 组织小头像叠右下（官方卡片样式；描边色同所在灰带）
          if (this.event.orgAvatar !== '') {
            Image(this.event.orgAvatar)
              .width(13)
              .height(13)
              .borderRadius(7)
              .border({ width: 1.5, color: $r('app.color.bg_page') })
          }
        }
        .width(28)
        .height(28)
        .onClick(() => this.onOpenUser())

        Column({ space: 1 }) {
          Row({ space: 3 }) {
            Text(this.event.authorLogin)
              .fontSize(14)
              .fontWeight(600)
              .fontColor($r('app.color.text_primary'))
            Text(this.stringOf($r('app.string.explore_contributed_to')))
              .fontSize(14)
              .fontColor($r('app.color.text_secondary'))
          }
          .onClick(() => this.onOpenUser())

          Text(this.event.repoFullName)
            .fontSize(14)
            .fontWeight(600)
            .fontColor($r('app.color.text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .onClick(() => this.onOpenRepo())
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Text(this.timeText())
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_secondary'))
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
    }
  }

  @Builder
  summaryCard() {
    if (this.event !== null) {
      Column({ space: 10 }) {
        // 仓库行（进仓库；与 PR 点击同级拆分）
        Row({ space: 6 }) {
          OctIcon({ res: $r('app.media.oct_repo_16'), iconSize: 16, iconColor: $r('app.color.text_primary') })
          Text(this.event.repoFullName)
            .fontSize(14)
            .fontWeight(600)
            .fontColor($r('app.color.text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width('100%')
        .onClick(() => this.onOpenRepo())

        // 标题 + 徽章行（进 PR 详情）
        Column({ space: 8 }) {
          Text(this.event.title)
            .fontSize(16)
            .fontWeight(600)
            .fontColor($r('app.color.text_primary'))
            .width('100%')

          Row({ space: 8 }) {
            Scroll() {
              Row({ space: 8 }) {
                if (this.event.merged) {
                  Row({ space: 4 }) {
                    OctIcon({ res: $r('app.media.oct_git_merge_16'), iconSize: 12, iconColor: Color.White })
                    Text($r('app.string.pr_merged_badge'))
                      .fontSize(12)
                      .fontColor(Color.White)
                  }
                  .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                  .borderRadius(12)
                  .backgroundColor($r('app.color.merged_badge_bg'))
                }
                if (this.event.headRef !== '') {
                  Text(this.event.headRef)
                    .fontSize(12)
                    .fontColor($r('app.color.shortcut_blue_fg'))
                    .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                    .borderRadius(2)
                    .backgroundColor($r('app.color.shortcut_blue_bg'))
                }
              }
            }
            .scrollable(ScrollDirection.Horizontal)
            .scrollBar(BarState.Off)
            .layoutWeight(1)

            OctIcon({ res: $r('app.media.oct_arrow_right_16'), iconSize: 16, iconColor: $r('app.color.text_primary') })
          }
          .width('100%')
        }
        .width('100%')
        .onClick(() => this.onOpenPr())

        if (this.hasSummary()) {
          Divider().color($r('app.color.divider'))
          this.summarySection()
        }

        // 反应笑脸（ReactionBar 精简态，041 mutation 复用）
        ReactionBar({
          token: this.token,
          subjectId: this.event.subjectId,
          reactions: this.event.reactions,
          smileyOnly: true
        })
      }
      .padding($r('app.float.card_padding'))
      .borderRadius($r('app.float.card_radius'))
      .backgroundColor($r('app.color.card_background'))
      .width('100%')
    }
  }

  @Builder
  summarySection() {
    Column({ space: 6 }) {
      Text($r('app.string.explore_summary'))
        .fontSize(18)
        .fontWeight(600)
        .fontColor($r('app.color.text_primary'))
        .width('100%')

      Stack({ alignContent: Alignment.Bottom }) {
        this.summaryLinesView()

        if (this.hasMoreLines()) {
          // 底部渐隐 + Read more 浮层（渐变到卡底色，展开后整块消失）
          Column()
            .width('100%')
            .height(44)
            .linearGradient({
              direction: GradientDirection.Bottom,
              colors: [[Color.Transparent, 0.0], [$r('app.color.card_background'), 1.0]]
            })
          Row({ space: 2 }) {
            Text($r('app.string.explore_read_more'))
              .fontSize(13)
              .fontColor($r('app.color.text_primary'))
            OctIcon({ res: $r('app.media.oct_chevron_right_16'), iconSize: 12, iconColor: $r('app.color.text_secondary') })
          }
          .padding({ left: 12, right: 10, top: 6, bottom: 6 })
          .borderRadius(16)
          .backgroundColor($r('app.color.card_background'))
          .border({ width: 1, color: $r('app.color.divider') })
          .margin({ bottom: 2 })
          .onClick(() => {
            this.expanded = true;
          })
        }
      }
      .width('100%')
    }
    .width('100%')
  }

  @Builder
  summaryLinesView() {
    Column({ space: 4 }) {
      ForEach(this.visibleLines(), (line: SummaryLine, idx: number) => {
        Row({ space: 6 }) {
          if (line.bullet) {
            Circle()
              .width(5)
              .height(5)
              .fill($r('app.color.text_secondary'))
              .margin({ top: 8 })
          }
          Text() {
            ForEach(line.segments, (seg: SummarySegment) => {
              Span(seg.text)
                .fontSize(seg.isCode ? 13 : 14)
                .fontColor($r('app.color.text_primary'))
                .fontFamily(seg.isCode ? 'monospace' : 'HarmonyOS Sans')
                .backgroundColor(seg.isCode ? $r('app.color.chip_bg') : Color.Transparent)
            }, (seg: SummarySegment, sIdx: number) => `${idx}_${sIdx}`)
          }
          .fontSize(14)
          .lineHeight(20)
          .layoutWeight(1)
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)
      }, (line: SummaryLine, idx: number) => `${idx}_${line.segments.length}`)
    }
    .width('100%')
  }

  build() {
    Column({ space: 8 }) {
      this.contributorHeader()
      this.summaryCard()
    }
    .width('100%')
  }
}
