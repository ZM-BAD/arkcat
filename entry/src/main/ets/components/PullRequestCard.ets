/**
 * PR 列表卡片（WorkPrs / RepoPrs 共用，2026-09-16 抽取）：
 * 行1 = `标题 #N`（编号灰小字紧跟标题，超长随题截断）+ 右上角时间；
 * 行2 = 仓库行（跨仓库列表传 repoFullName，单仓库列表省略）；
 * 行3 = 胶囊组（Labels/Checks/评论/Reviews）Flex 换行：放不下自动折到下一行（不横向截断、头像不裁），
 * 头像跟在胶囊末尾；全部胶囊统一描边变体（与 Checks 同底），仅 Checks 图标着色。
 * Checks 胶囊（映射自 WorkPrs 原实现）：SUCCESS 绿✓ Checks / FAILURE·ERROR 红✗ Checks failed /
 * PENDING 黄✗ Checks pending；文字一律主色，仅图标着色。
 */
import { OctIcon } from './OctIcon';
import { LabelPill } from './LabelPill';
import { CountChip } from './CountChip';
import { WorkLabel } from '../models/WorkModels';
import { resText } from '../utils/I18n';

@ComponentV2
export struct PullRequestCard {
  @Param iconRes: Resource = $r('app.media.oct_git_pull_request_16');
  @Param iconColor: ResourceColor = $r('app.color.success_text');
  @Param title: string = '';
  @Param number: number = 0;
  /** 仓库行文案（跨仓库列表传 repoFullName；单仓库列表传 '' 省略） */
  @Param repoLine: string = '';
  @Param timeText: string = '';
  @Param labels: WorkLabel[] = [];
  @Param commentCount: number = 0;
  @Param reviewCount: number = 0;
  /** GitHub statusCheckRollup state（StatusState 五态全集）：SUCCESS/FAILURE/ERROR/PENDING/EXPECTED；''=无 Checks 不显示胶囊 */
  @Param checksState: string = '';
  @Param authorAvatar: string = '';
  @Event onOpen: () => void = (): void => { };

  private stringOf(res: Resource): string {
    return resText(this.getUIContext(), res);
  }

  /** Checks 胶囊文案（StatusState 五态全集；未知静默不显示胶囊） */
  private checksLabel(state: string): string {
    if (state === 'SUCCESS') {
      return this.stringOf($r('app.string.work_pr_checks'));
    }
    if (state === 'FAILURE' || state === 'ERROR') {
      return this.stringOf($r('app.string.work_pr_checks_failed'));
    }
    if (state === 'PENDING') {
      return this.stringOf($r('app.string.work_pr_checks_pending'));
    }
    if (state === 'EXPECTED') {
      return this.stringOf($r('app.string.work_pr_checks_expected'));
    }
    return '';
  }

  private checksIcon(state: string): Resource {
    if (state === 'SUCCESS') {
      return $r('app.media.oct_check_16');
    }
    if (state === 'EXPECTED') {
      return $r('app.media.oct_circle_16');
    }
    return $r('app.media.oct_x_16');
  }

  private checksColor(state: string): ResourceColor {
    if (state === 'SUCCESS') {
      return $r('app.color.success_text');
    }
    if (state === 'FAILURE' || state === 'ERROR') {
      return $r('app.color.danger_text');
    }
    if (state === 'EXPECTED') {
      return $r('app.color.text_secondary');
    }
    return $r('app.color.warning_text');
  }

  build() {
    Row({ space: 12 }) {
      OctIcon({ res: this.iconRes, iconSize: 18, iconColor: this.iconColor })
      Column({ space: 6 }) {
        Row({ space: 8 }) {
          Text() {
            Span(this.title)
            Span(` #${this.number}`)
              .fontSize($r('app.float.caption_font_size'))
              .fontColor($r('app.color.text_secondary'))
          }
          .fontSize($r('app.float.body_font_size'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
          Text(this.timeText)
            .fontSize($r('app.float.caption_font_size'))
            .fontColor($r('app.color.text_secondary'))
        }
        .width('100%')

        if (this.repoLine !== '') {
          Text(this.repoLine)
            .fontSize($r('app.float.caption_font_size'))
            .fontColor($r('app.color.text_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }

        // 胶囊组：Flex 换行（放不下自动折行，头像永远完整可见，不做横向截断）；头像跟在胶囊末尾
        Flex({ wrap: FlexWrap.Wrap, alignItems: ItemAlign.Center }) {
          ForEach(this.labels, (label: WorkLabel) => {
            LabelPill({ labelName: label.name, colorHex: label.color })
              .margin({ right: 8, bottom: 8 })
          }, (label: WorkLabel) => label.name)
          if (this.checksLabel(this.checksState) !== '') {
            CountChip({
              icon: this.checksIcon(this.checksState),
              iconColor: this.checksColor(this.checksState),
              text: this.checksLabel(this.checksState),
              textColor: $r('app.color.text_primary'),
              outlined: true
            })
              .margin({ right: 8, bottom: 8 })
          }
          if (this.commentCount > 0) {
            CountChip({ icon: $r('app.media.oct_comment_16'), text: `${this.commentCount}`, outlined: true })
              .margin({ right: 8, bottom: 8 })
          }
          if (this.reviewCount > 0) {
            CountChip({ icon: $r('app.media.oct_eye_16'), text: `${this.reviewCount}`, outlined: true })
              .margin({ right: 8, bottom: 8 })
          }
          if (this.authorAvatar !== '') {
            Image(this.authorAvatar)
              .width(20)
              .height(20)
              .borderRadius(12)
              .backgroundColor($r('app.color.heat_empty'))
              .margin({ right: 8, bottom: 8 })
          }
        }
        .width('100%')
      }
      .layoutWeight(1)
    }
    .alignItems(VerticalAlign.Top)
    .padding($r('app.float.card_padding'))
    .borderRadius($r('app.float.card_radius'))
    .backgroundColor($r('app.color.card_background'))
    .width('100%')
    .margin({ bottom: 8 })
    .onClick(() => this.onOpen())
  }
}
