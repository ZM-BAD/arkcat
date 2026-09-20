/**
 * Check run 富行（Spec 048）：状态色图标 · App 图标 · 名称 · 副标题 · 行尾 chevron。
 * Status 卡展开态与 Checks 全量页共用同一行形态（官方两处一致）。
 * 副标题：check run title（如 Renovate 描述）优先，否则结论文案（带时长）。
 * checkRunId=0（StatusContext）不可点、无 chevron。
 */
import { OctIcon } from './OctIcon';
import { StatusCheckItem } from '../models/RepoSubModels';
import { conclusionKey, durationText } from '../models/ChecksModels';
import { resText } from '../utils/I18n';

@ComponentV2
export struct CheckRunRow {
  @Require @Param item: StatusCheckItem;
  /** 行点击（仅 CheckRun；页面据此进 Check run 详情页） */
  @Event onOpen: (item: StatusCheckItem) => void = (_item: StatusCheckItem): void => { };

  private stateIcon(): Resource {
    if (this.item.state === 'SUCCESS') {
      return $r('app.media.oct_check_16');
    }
    if (this.item.state === 'FAILURE' || this.item.state === 'TIMED_OUT' || this.item.state === 'STARTUP_FAILURE') {
      return $r('app.media.oct_x_16');
    }
    return $r('app.media.oct_dot_fill_16');
  }

  private stateColor(): ResourceColor {
    if (this.item.state === 'SUCCESS') {
      return $r('app.color.success_text');
    }
    if (this.item.state === 'FAILURE' || this.item.state === 'TIMED_OUT' || this.item.state === 'STARTUP_FAILURE') {
      return $r('app.color.danger_text');
    }
    return $r('app.color.warning_text');
  }

  /** 副标题：title 优先；结论词模板带时长的两档（成功/失败）在缺时长时回落纯词 */
  private subtitle(): string {
    if (this.item.title !== '') {
      return this.item.title;
    }
    const key = conclusionKey(this.item.state);
    const dur = durationText(this.item.startedAt, this.item.completedAt);
    if (key === 'success') {
      return dur !== ''
        ? resText(this.getUIContext(), $r('app.string.checks_sub_success', dur))
        : resText(this.getUIContext(), $r('app.string.checks_word_success'));
    }
    if (key === 'failed') {
      return dur !== ''
        ? resText(this.getUIContext(), $r('app.string.checks_sub_failed', dur))
        : resText(this.getUIContext(), $r('app.string.checks_word_failed'));
    }
    if (key === 'cancelled') {
      return resText(this.getUIContext(), $r('app.string.checks_word_cancelled'));
    }
    if (key === 'waiting') {
      return resText(this.getUIContext(), $r('app.string.checks_word_waiting'));
    }
    if (key === 'action') {
      return resText(this.getUIContext(), $r('app.string.checks_word_action'));
    }
    return resText(this.getUIContext(), $r('app.string.checks_word_progress'));
  }

  build() {
    Row({ space: 8 }) {
      OctIcon({ res: this.stateIcon(), iconSize: 12, iconColor: this.stateColor() })
      if (this.item.appLogo !== '') {
        Image(this.item.appLogo)
          .width(24)
          .height(24)
          .borderRadius(4)
          .backgroundColor($r('app.color.heat_empty'))
      } else {
        // StatusContext 无 App 图标：占位同宽，保持名称列对齐
        Row().width(24).height(24)
      }
      Column({ space: 1 }) {
        Text(this.item.name)
          .fontSize($r('app.float.body_font_size'))
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Text(this.subtitle())
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_secondary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (this.item.checkRunId > 0) {
        OctIcon({ res: $r('app.media.oct_chevron_right_16'), iconSize: 14, iconColor: $r('app.color.text_secondary') })
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding({ top: 10, bottom: 10 })
    .onClick((): void => {
      if (this.item.checkRunId > 0) {
        this.onOpen(this.item);
      }
    })
  }
}
