/**
 * PR 详情 Status 卡片（Spec 031 + 041 定案）：Reviews 计数行 + Checks 摘要行（点击展开全部 checks，
 * 状态色图标/黑体文案）+ merged 分支行（紫 merge icon + 动作人行多 Span）。
 * Spec 042 增补：Merge 区块（可用=绿色按钮+三方法菜单；阻塞=原因文案+禁用态）。
 * checks 展开态为本组件内部状态；detail 变化（重拉）时随 @Param 更新。
 */
import { promptAction } from '@kit.ArkUI';
import { OctIcon } from './OctIcon';
import { CheckRunRow } from './CheckRunRow';
import { PrDetailPage, StatusCheckItem, canMergePr, mergeStateReasonKey } from '../models/RepoSubModels';
import { conclusionKey } from '../models/ChecksModels';
import { githubShortTime, timeParts, TimeParts } from '../utils/Format';
import { resText } from '../utils/I18n';

@ComponentV2
export struct PrStatusCard {
  @Require @Param detail: PrDetailPage;
  /** 合并进行中（页面 mergeSending 传入；主段 MERGE 按钮在此期间禁用，防重复提交） */
  @Param merging: boolean = false;
  /** Status 卡片 checks 列表展开态（仅本卡消费，自持有） */
  @Local checksOpen: boolean = false;
  /** Reviews 行展开态（REQUEST REVIEWS 按钮；编辑管道随 Spec 044 接入，先占位） */
  @Local reviewsOpen: boolean = false;
  /** 右段 ▾ → 页面打开 Merge options 底部页（只管选方式/改提交信息，页内无确认钮） */
  @Event onMergeOpen: () => void = (): void => { };
  /** 主段 MERGE → 按当前方式直接合并（页面先弹官方确认对话框） */
  @Event onMergeConfirm: () => void = (): void => { };
  /** Spec 048：check run 富行点击 → 页面进 Check run 详情（StatusContext 不可点，组件内已门） */
  @Event onOpenCheck: (item: StatusCheckItem) => void = (_item: StatusCheckItem): void => { };
  /** Spec 048：View all → 页面进 Checks 全量页 */
  @Event onViewAllChecks: () => void = (): void => { };

  private stringOf(res: Resource): string {
    return resText(this.getUIContext(), res);
  }

  private timeText(parts: TimeParts | null): string {
    return parts !== null ? githubShortTime(parts) : '';
  }

  private checkColor(state: string): ResourceColor {
    if (state === 'SUCCESS') {
      return $r('app.color.success_text');
    }
    if (state === 'FAILURE') {
      return $r('app.color.danger_text');
    }
    return $r('app.color.warning_text');
  }

  /** 成功占比%（红绿占比环用；按已取回的 checks 统计，contexts 上限 20 内近似） */
  private successPercent(): number {
    let success = 0;
    for (const c of this.detail.checks) {
      if (conclusionKey(c.state) === 'success') {
        success += 1;
      }
    }
    const total = this.detail.checks.length;
    return total > 0 ? Math.round((success / total) * 100) : 0;
  }

  /** Checks 摘要行文案：官方混合失败词式「Some checks were not successful」 */
  private rollupText(): string {
    if (this.detail.checksState === 'SUCCESS') {
      return this.stringOf($r('app.string.pr_all_checks_passed'));
    }
    if (this.detail.checksState === 'FAILURE') {
      return this.stringOf($r('app.string.checks_rollup_failed'));
    }
    return this.stringOf($r('app.string.work_pr_checks_pending'));
  }

  /** 冲突类原因（CONFLICTING/DIRTY）用红色提示，其余次级灰（Spec 042 元素9） */
  private mergeReasonColor(): ResourceColor {
    const conflicting = this.detail.mergeable === 'CONFLICTING'
      || mergeStateReasonKey(this.detail.mergeStateStatus) === 'conflicting';
    return conflicting ? $r('app.color.danger_text') : $r('app.color.text_secondary');
  }

  /** View all 次行计数文案：全成功「N successful checks」；混合失败按实际成败计数
   *  （官方 web 同款「X failing and Y successful checks」，2026-09-20 走查定案——总数配失败词会虚报） */
  private checksTotalText(): string {
    if (this.detail.checksState === 'SUCCESS') {
      return resText(this.getUIContext(), $r('app.string.checks_count_success'), `${this.detail.checksTotal}`);
    }
    if (this.detail.checksState === 'FAILURE') {
      let failed = 0;
      let success = 0;
      for (const c of this.detail.checks) {
        if (conclusionKey(c.state) === 'success') {
          success += 1;
        } else if (conclusionKey(c.state) === 'failed') {
          failed += 1;
        }
      }
      return resText(this.getUIContext(), $r('app.string.checks_total_mixed'), `${failed}`, `${success}`);
    }
    return resText(this.getUIContext(), $r('app.string.checks_count_progress'), `${this.detail.checksTotal}`);
  }

  /** 不可合并原因文案（Spec 042 元素9/10：CONFLICTING 优先，其次 mergeStateStatus 映射，未知兜底） */
  private mergeReasonText(): string {
    if (this.detail.mergeable === 'CONFLICTING') {
      return this.stringOf($r('app.string.pr_merge_state_conflicting'));
    }
    switch (mergeStateReasonKey(this.detail.mergeStateStatus)) {
      case 'conflicting':
        return this.stringOf($r('app.string.pr_merge_state_conflicting'));
      case 'blocked':
        return this.stringOf($r('app.string.pr_merge_state_blocked'));
      case 'behind':
        return this.stringOf($r('app.string.pr_merge_state_behind'));
      case 'unstable':
        return this.stringOf($r('app.string.pr_merge_state_unstable'));
      case 'draft':
        return this.stringOf($r('app.string.pr_merge_state_draft'));
      case 'has_hooks':
        return this.stringOf($r('app.string.pr_merge_state_has_hooks'));
      default:
        return this.stringOf($r('app.string.pr_merge_state_unknown'));
    }
  }

  @Builder
  sectionTitle(text: string) {
    Text(text)
      .fontSize($r('app.float.sub_text_font_size'))
      .fontWeight(600)
      .fontColor($r('app.color.text_primary'))
      .width('100%')
  }

  build() {
    Column({ space: 8 }) {
      this.sectionTitle(this.stringOf($r('app.string.pr_status_title')))
      // Reviews（黑）· None requested（灰）· 行尾 chevron（点开 REQUEST REVIEWS）
      Row({ space: 8 }) {
        OctIcon({ res: $r('app.media.oct_person_16'), iconSize: 14, iconColor: $r('app.color.text_secondary') })
        Text(this.stringOf($r('app.string.pr_reviews')))
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_primary'))
        Text('·')
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_tertiary'))
        Text(this.detail.reviewsTotal > 0 ? `${this.detail.reviewsTotal}` : this.stringOf($r('app.string.pr_reviews_none')))
          .fontSize($r('app.float.caption_font_size'))
          .fontColor(this.detail.reviewsTotal > 0 ? $r('app.color.text_primary') : $r('app.color.text_secondary'))
        Blank()
        OctIcon({
          res: $r('app.media.oct_chevron_down_16'),
          iconSize: 14,
          iconColor: $r('app.color.text_secondary')
        })
        .rotate(this.reviewsOpen ? { angle: 180 } : { angle: 0 })
      }
      .width('100%')
      .onClick(() => {
        this.reviewsOpen = !this.reviewsOpen;
      })
      // REQUEST REVIEWS（官方展开态）：按钮左缘对齐上一行 Reviews 文案开头（icon 14 + space 8 = 22）
      if (this.reviewsOpen) {
        Row() {
          // REQUEST REVIEWS：自绘行而非 Button（Button 不支持 textCase，且 Capsule 型忽略 borderRadius）
          // 圆角 6 矩形端，与下方 MERGE 按钮同口径；配色/长度不变
          Row() {
            Text($r('app.string.pr_request_reviews'))
              .fontSize($r('app.float.caption_font_size'))
              .fontColor($r('app.color.text_primary'))
              .textCase(TextCase.UpperCase)
          }
          .width('100%')
          .height(36)
          .justifyContent(FlexAlign.Center)
          .borderRadius(6)
          .backgroundColor($r('app.color.card_background'))
          .border({ width: 1, color: $r('app.color.border') })
          .onClick((): void => {
            // 请求审阅人员选择器（Spec 044 元数据编排）接入前的占位
            promptAction.showToast({ message: $r('app.string.home_feature_coming') });
          })
        }
        .width('100%')
        .padding({ left: 22 })
      }
      // Checks 摘要行：状态圆图标 + 文案 + chevron；点击展开全部 checks。
      // 混合失败=红绿占比环（红底全环，绿色成功弧自 12 点钟顺时针，占比=成功/总数）；
      // 全绿/进行中仍用单色圆图标。
      Row({ space: 8 }) {
        if (this.detail.checksState === 'FAILURE') {
          // 官方红绿占比环：绿=成功占比、红=其余（绿色段自 12 点钟顺时针，DataPanel 圆形面板同序）
          DataPanel({
            values: [this.successPercent(), 100 - this.successPercent()],
            max: 100,
            type: DataPanelType.Circle
          })
            .valueColors([$r('app.color.success_text'), $r('app.color.danger_text')])
            .trackBackgroundColor($r('app.color.danger_text'))
            .strokeWidth(2)
            .closeEffect(true)
            .width(14)
            .height(14)
        } else {
          OctIcon({
            res: $r('app.media.oct_circle_16'),
            iconSize: 14,
            iconColor: this.checkColor(this.detail.checksState)
          })
        }
        Text(this.rollupText())
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_primary'))
        Blank()
        OctIcon({
          res: $r('app.media.oct_chevron_down_16'),
          iconSize: 14,
          iconColor: $r('app.color.text_secondary')
        })
        .rotate(this.checksOpen ? { angle: 180 } : { angle: 0 })
      }
      .width('100%')
      .onClick(() => {
        this.checksOpen = !this.checksOpen;
      })
      if (this.checksOpen) {
        // 官方预览前 5 条富行（Spec 048），行间靠留白（无分隔线）；全量经 View all 进 Checks 页
        ForEach(this.detail.checks.slice(0, 5), (c: StatusCheckItem) => {
          CheckRunRow({
            item: c,
            onOpen: (item: StatusCheckItem): void => {
              this.onOpenCheck(item);
            }
          })
        }, (c: StatusCheckItem) => c.key)
        if (this.detail.checksTotal > 0) {
          // View all 收口（官方）：分隔线与文案都缩进到 App 图标列（状态图标 14 + 间距 10）
          Divider()
            .color($r('app.color.divider'))
            .margin({ left: 24 })
          Column({ space: 2 }) {
            Text($r('app.string.checks_view_all'))
              .fontSize($r('app.float.sub_text_font_size'))
              .fontColor($r('app.color.text_primary'))
              .width('100%')
            Text(this.checksTotalText())
              .fontSize($r('app.float.body_font_size'))
              .fontColor($r('app.color.text_secondary'))
              .width('100%')
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          .padding({ left: 24, top: 12, bottom: 4 })
          .onClick((): void => {
            this.onViewAllChecks();
          })
        }
      }
      // Merge 区块（Spec 042 元素8/9/10）：已合并不显示；可用=Ready to merge 行+MERGE 分段按钮
      // （Android 官方形态：主段 MERGE 进确认 sheet、右段 ▾ 选方法）；阻塞=原因（冲突红字）+禁用态
      if (!this.detail.merged) {
        if (canMergePr(this.detail.merged, this.detail.mergeable, this.detail.repoViewerPermission)) {
          Row({ space: 8 }) {
            OctIcon({
              res: $r('app.media.oct_check_circle_fill_16'),
              iconSize: 14,
              iconColor: $r('app.color.success_text')
            })
            Column({ space: 2 }) {
              Text($r('app.string.pr_merge_ready'))
                .fontSize($r('app.float.caption_font_size'))
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.text_primary'))
              Text($r('app.string.pr_merge_ready_sub'))
                .fontSize($r('app.float.caption_font_size'))
                .fontColor($r('app.color.text_secondary'))
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
          }
          .width('100%')
          .alignItems(VerticalAlign.Top)
          Row({ space: 1 }) {
            Button($r('app.string.pr_merge_button'))
              .type(ButtonType.Normal)
              .layoutWeight(1)
              .height(40)
              .fontSize($r('app.float.caption_font_size'))
              .fontColor(Color.White)
              .backgroundColor($r('app.color.success_btn_bg'))
              .borderRadius({ topLeft: 6, bottomLeft: 6 })
              .enabled(!this.merging)
              .onClick((): void => this.onMergeConfirm())
            Stack() {
              OctIcon({ res: $r('app.media.oct_chevron_down_16'), iconSize: 14, iconColor: Color.White })
            }
            .width(44)
            .height(40)
            .backgroundColor($r('app.color.success_btn_bg'))
            .borderRadius({ topRight: 6, bottomRight: 6 })
            .accessibilityDescription($r('app.string.pr_merge_options_title'))
            .onClick((): void => this.onMergeOpen())
          }
          .width('100%')
        } else {
          Row({ space: 8 }) {
            OctIcon({ res: $r('app.media.oct_alert_16'), iconSize: 14, iconColor: $r('app.color.text_secondary') })
            Text(this.mergeReasonText())
              .fontSize($r('app.float.caption_font_size'))
              .fontColor(this.mergeReasonColor())
              .layoutWeight(1)
          }
          .width('100%')
          Button(this.stringOf($r('app.string.pr_merge_confirm_title')))
            .buttonStyle(ButtonStyleMode.NORMAL)
            .width('100%')
            .height(36)
            .fontSize($r('app.float.caption_font_size'))
            .fontColor($r('app.color.text_tertiary'))
            .backgroundColor($r('app.color.card_background'))
            .borderRadius(6)
            .border({ width: 1, color: $r('app.color.border') })
            .enabled(false)
        }
      }
      if (this.detail.merged) {
        // Branch merged 行（紫色 merge icon）
        Row({ space: 8 }) {
          OctIcon({
            res: $r('app.media.oct_git_merge_16'),
            iconSize: 14,
            iconColor: $r('app.color.shortcut_purple_fg')
          })
          Text(this.stringOf($r('app.string.pr_branch_merged')))
            .fontSize($r('app.float.caption_font_size'))
            .fontColor($r('app.color.text_primary'))
        }
        .width('100%')
        // 动作人行：ZM-BAD merged commit a1edbd2 into main 13d ago
        if (this.detail.mergeOid !== '' && this.detail.mergedByLogin !== '') {
          Text() {
            Span(this.detail.mergedByLogin)
              .fontColor($r('app.color.text_primary'))
            Span(` ${this.stringOf($r('app.string.pr_merged_commit_word'))} `)
              .fontColor($r('app.color.text_secondary'))
            Span(this.detail.mergeOid)
              .fontColor($r('app.color.text_primary'))
            Span(` ${this.stringOf($r('app.string.pr_into_word'))} `)
              .fontColor($r('app.color.text_secondary'))
            Span(this.detail.baseRefName)
              .fontColor($r('app.color.text_secondary'))
            Span(` ${this.timeText(timeParts(this.detail.mergedAt, Date.now()))} ${this.stringOf($r('app.string.pr_time_ago'))}`)
              .fontColor($r('app.color.text_secondary'))
          }
          .fontSize($r('app.float.caption_font_size'))
          .width('100%')
          .padding({ left: 22 })
        }
      }
    }
    .padding($r('app.float.card_padding'))
    .borderRadius($r('app.float.card_radius'))
    .backgroundColor($r('app.color.card_background'))
    .width('100%')
    .margin({ bottom: 12 })
  }
}
