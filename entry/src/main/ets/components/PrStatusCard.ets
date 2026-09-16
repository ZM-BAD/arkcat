/**
 * PR 详情 Status 卡片（Spec 031 + 041 定案）：Reviews 计数行 + Checks 摘要行（点击展开全部 checks，
 * 状态色图标/黑体文案）+ merged 分支行（紫 merge icon + 动作人行多 Span）。
 * Spec 042 增补：Merge 区块（可用=绿色按钮+三方法菜单；阻塞=原因文案+禁用态）。
 * checks 展开态为本组件内部状态；detail 变化（重拉）时随 @Param 更新。
 */
import { promptAction } from '@kit.ArkUI';
import { OctIcon } from './OctIcon';
import { PrDetailPage, StatusCheckItem, canMergePr, mergeStateReasonKey } from '../models/RepoSubModels';
import { RepoSubService } from '../services/RepoSubService';
import { githubShortTime, timeParts, TimeParts } from '../utils/Format';
import { resText } from '../utils/I18n';

@ComponentV2
export struct PrStatusCard {
  @Require @Param detail: PrDetailPage;
  @Param token: string = '';
  /** 合并成功后通知页面重拉（merged badge / 分支行 / Merge 区块随之刷新） */
  @Event onRefresh: () => void = (): void => { };
  /** Status 卡片 checks 列表展开态（仅本卡消费，自持有） */
  @Local checksOpen: boolean = false;
  /** 合并进行中（防重复提交；按钮禁用） */
  @Local merging: boolean = false;
  /** MERGE 主按钮/方法菜单选择 → 页面打开 Merge 确认 sheet（Android 官方截图对齐） */
  @Event onMergeTap: (method: string) => void = (method: string): void => { };

  private stringOf(res: Resource): string {
    return resText(this.getUIContext(), res);
  }

  private timeText(parts: TimeParts | null): string {
    return parts !== null ? githubShortTime(parts) : '';
  }

  /** 展开态每个 check 行的图标：SUCCESS 绿勾 / FAILURE 红叉 / 其余黄点 */
  private checkItemIcon(state: string): Resource {
    if (state === 'SUCCESS') {
      return $r('app.media.oct_check_16');
    }
    if (state === 'FAILURE') {
      return $r('app.media.oct_x_16');
    }
    return $r('app.media.oct_dot_fill_16');
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

  /** 冲突类原因（CONFLICTING/DIRTY）用红色提示，其余次级灰（Spec 042 元素9） */
  private mergeReasonColor(): ResourceColor {
    const conflicting = this.detail.mergeable === 'CONFLICTING'
      || mergeStateReasonKey(this.detail.mergeStateStatus) === 'conflicting';
    return conflicting ? $r('app.color.danger_text') : $r('app.color.text_secondary');
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

  /** 三方法菜单项（官方默认 squash） */
  private mergeMenuItems(): MenuElement[] {
    return [
      {
        value: this.stringOf($r('app.string.pr_merge_squash')),
        action: (): void => this.onMergeTap('SQUASH')
      },
      {
        value: this.stringOf($r('app.string.pr_merge_merge_commit')),
        action: (): void => this.onMergeTap('MERGE')
      },
      {
        value: this.stringOf($r('app.string.pr_merge_rebase')),
        action: (): void => this.onMergeTap('REBASE')
      }
    ];
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
      // Reviews（黑）· None requested（灰）
      Row({ space: 6 }) {
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
      }
      .width('100%')
      // Checks 摘要行：状态色圆圈 + 文案 + chevron；点击展开全部 checks
      Row({ space: 8 }) {
        OctIcon({
          res: $r('app.media.oct_circle_16'),
          iconSize: 14,
          iconColor: this.checkColor(this.detail.checksState)
        })
        Text(this.detail.checksState === 'SUCCESS' ? this.stringOf($r('app.string.pr_all_checks_passed'))
          : this.stringOf($r('app.string.work_pr_checks_failed')))
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
        ForEach(this.detail.checks, (c: StatusCheckItem) => {
          Row({ space: 8 }) {
            OctIcon({ res: this.checkItemIcon(c.state), iconSize: 12, iconColor: this.checkColor(c.state) })
            Text(c.name)
              .fontSize($r('app.float.caption_font_size'))
              .fontColor($r('app.color.text_primary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
          }
          .width('100%')
          .padding({ left: 22 })
        }, (c: StatusCheckItem) => c.name)
      }
      // Merge 区块（Spec 042 元素8/9/10）：已合并不显示；可用=Ready to merge 行+MERGE 分段按钮
      // （Android 官方形态：主段 MERGE 进确认 sheet、右段 ▾ 选方法）；阻塞=原因（冲突红字）+禁用态
      if (!this.detail.merged) {
        if (canMergePr(this.detail.merged, this.detail.mergeable, this.detail.repoViewerPermission)) {
          Row({ space: 8 }) {
            OctIcon({
              res: $r('app.media.oct_check_circle_fill_16'),
              iconSize: 16,
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
              .onClick((): void => this.onMergeTap('SQUASH'))
            Stack() {
              OctIcon({ res: $r('app.media.oct_chevron_down_16'), iconSize: 14, iconColor: Color.White })
            }
            .width(44)
            .height(40)
            .backgroundColor($r('app.color.success_btn_bg'))
            .borderRadius({ topRight: 6, bottomRight: 6 })
            .bindMenu(this.mergeMenuItems())
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
