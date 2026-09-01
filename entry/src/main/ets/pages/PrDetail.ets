/**
 * PR 详情页（Spec 031）：Merged 徽章 + Changes 卡片 + Status 卡片 + Conversation。
 */
import { promptAction } from '@kit.ArkUI';
import { OctIcon } from '../components/OctIcon';
import { RepoComment, PrDetailPage } from '../models/RepoSubModels';
import { RepoSubService } from '../services/RepoSubService';
import { StateView } from '../components/StateView';
import { timeParts, TimeParts } from '../utils/Format';
import { resText } from '../utils/I18n';

@ComponentV2
export struct PrDetailView {
  @Param owner: string = '';
  @Param name: string = '';
  @Param number: number = 0;
  @Param token: string = '';
  @Param pathStack: NavPathStack = new NavPathStack();
  @Local detail: PrDetailPage | null = null;
  @Local loading: boolean = true;
  @Local errorMsg: string = '';

  aboutToAppear(): void {
    this.refresh();
  }

  private refresh(): void {
    this.loading = true;
    this.errorMsg = '';
    RepoSubService.fetchPrDetail(this.token, this.owner, this.name, this.number)
      .then((page: PrDetailPage) => {
        this.detail = page;
        this.loading = false;
      })
      .catch((e: Error) => {
        this.errorMsg = e.message;
        this.loading = false;
      });
  }

  private stringOf(res: Resource): string {
    return resText(this.getUIContext(), res);
  }

  private timeText(parts: TimeParts | null): string {
    if (parts === null) {
      return '';
    }
    const ui = this.getUIContext();
    switch (parts.unit) {
      case 'just_now':
        return resText(ui, $r('app.string.time_just_now'));
      case 'minute':
        return resText(ui, $r('app.string.time_minutes_ago'), parts.value);
      case 'hour':
        return resText(ui, $r('app.string.time_hours_ago'), parts.value);
      case 'day':
        return resText(ui, $r('app.string.time_days_ago'), parts.value);
      case 'month':
        return resText(ui, $r('app.string.time_months_ago'), parts.value);
      case 'year':
        return resText(ui, $r('app.string.time_years_ago'), parts.value);
    }
  }

  @Builder
  sectionTitle(text: string) {
    Text(text)
      .fontSize(16)
      .fontWeight(FontWeight.Bold)
      .fontColor($r('app.color.text_primary'))
      .width('100%')
  }

  @Builder
  commentItem(item: RepoComment) {
    Column({ space: 6 }) {
      Row({ space: 8 }) {
        if (item.authorAvatar !== '') {
          Image(item.authorAvatar)
            .width(24)
            .height(24)
            .borderRadius(12)
            .backgroundColor($r('app.color.heat_empty'))
        } else {
          Circle().width(24).height(24).fill($r('app.color.heat_empty'))
        }
        Text(item.authorLogin)
          .fontSize($r('app.float.caption_font_size'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
        Text(this.timeText(timeParts(item.createdAt, Date.now())))
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_secondary'))
      }
      .width('100%')

      Text(item.body)
        .fontSize($r('app.float.body_font_size'))
        .fontColor($r('app.color.text_secondary'))
        .maxLines(8)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .lineHeight(20)
    }
    .padding($r('app.float.card_padding'))
    .borderRadius($r('app.float.card_radius'))
    .backgroundColor($r('app.color.card_background'))
    .width('100%')
    .margin({ bottom: 8 })
  }

  build() {
    Column() {
      Row({ space: 8 }) {
        Stack() {
          OctIcon({ res: $r('app.media.oct_arrow_left_24'), iconSize: 20, iconColor: $r('app.color.text_primary') })
        }
        .onClick(() => {
          this.pathStack.pop();
        })
        Text(`${this.owner}/${this.name} #${this.number}`)
          .fontSize($r('app.float.title_font_size'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        Stack() {
          OctIcon({ res: $r('app.media.oct_share_16'), iconSize: 18, iconColor: $r('app.color.text_secondary') })
        }
        .padding(6)
        .onClick(() => {
          promptAction.showToast({ message: $r('app.string.home_feature_coming') });
        })
        Stack() {
          OctIcon({ res: $r('app.media.oct_kebab_horizontal_16'), iconSize: 18, iconColor: $r('app.color.text_secondary') })
        }
        .padding(6)
        .onClick(() => {
          promptAction.showToast({ message: $r('app.string.home_feature_coming') });
        })
      }
      .width('100%')
      .height(48)
      .padding({ left: 16, right: 12 })

      Scroll() {
        Column() {
          if (this.detail !== null) {
            // 标题 + 徽章
            Column({ space: 8 }) {
              Text(this.detail.title)
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_primary'))
                .width('100%')
                .lineHeight(28)

              Row({ space: 8 }) {
                if (this.detail.merged) {
                  Text($r('app.string.pr_merged_badge'))
                    .fontSize(12)
                    .fontColor(Color.White)
                    .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                    .borderRadius(10)
                    .backgroundColor('#2E5FC7')
                }
                if (this.detail.headRefName !== '') {
                  Text(this.detail.headRefName)
                    .fontSize(12)
                    .fontColor(Color.White)
                    .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                    .borderRadius(10)
                    .backgroundColor($r('app.color.primary'))
                }
              }
              .width('100%')

              Row({ space: 8 }) {
                if (this.detail.authorAvatar !== '') {
                  Image(this.detail.authorAvatar)
                    .width(22)
                    .height(22)
                    .borderRadius(11)
                    .backgroundColor($r('app.color.heat_empty'))
                }
                Text(this.detail.authorLogin)
                  .fontSize($r('app.float.caption_font_size'))
                  .fontColor($r('app.color.text_primary'))
                Text(this.timeText(timeParts(this.detail.createdAt, Date.now())))
                  .fontSize($r('app.float.caption_font_size'))
                  .fontColor($r('app.color.text_secondary'))
              }
              .width('100%')

              if (this.detail.body !== '') {
                Divider().color($r('app.color.divider'))
                Text(this.detail.body)
                  .fontSize($r('app.float.body_font_size'))
                  .fontColor($r('app.color.text_secondary'))
                  .maxLines(10)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .width('100%')
                  .lineHeight(20)
                Text($r('app.string.issue_detail_read_more'))
                  .fontSize($r('app.float.caption_font_size'))
                  .fontColor($r('app.color.link_blue'))
                  .onClick(() => {
                    promptAction.showToast({ message: $r('app.string.home_feature_coming') });
                  })
              }
            }
            .padding($r('app.float.card_padding'))
            .borderRadius($r('app.float.card_radius'))
            .backgroundColor($r('app.color.card_background'))
            .width('100%')
            .margin({ bottom: 12 })

            // Changes 卡片
            Column({ space: 8 }) {
              this.sectionTitle(this.stringOf($r('app.string.pr_changes_title')))
              Row({ space: 8 }) {
                OctIcon({ res: $r('app.media.oct_file_16'), iconSize: 14, iconColor: $r('app.color.text_secondary') })
                Text(resText(this.getUIContext(), $r('app.string.pr_files_changed'), this.detail.filesCount))
                  .fontSize($r('app.float.body_font_size'))
                  .fontColor($r('app.color.text_primary'))
                Blank()
                Text(`+${this.detail.additions}`)
                  .fontSize($r('app.float.caption_font_size'))
                  .fontColor($r('app.color.success_text'))
                Text(`-${this.detail.deletions}`)
                  .fontSize($r('app.float.caption_font_size'))
                  .fontColor($r('app.color.danger_text'))
              }
              .width('100%')
              Row({ space: 8 }) {
                OctIcon({ res: $r('app.media.oct_git_commit_16'), iconSize: 14, iconColor: $r('app.color.text_secondary') })
                Text(resText(this.getUIContext(), $r('app.string.pr_commits_count'), this.detail.commitsCount))
                  .fontSize($r('app.float.caption_font_size'))
                  .fontColor($r('app.color.text_secondary'))
                Blank()
                Text(this.timeText(timeParts(this.detail.createdAt, Date.now())))
                  .fontSize($r('app.float.caption_font_size'))
                  .fontColor($r('app.color.text_secondary'))
              }
              .width('100%')
            }
            .padding($r('app.float.card_padding'))
            .borderRadius($r('app.float.card_radius'))
            .backgroundColor($r('app.color.card_background'))
            .width('100%')
            .margin({ bottom: 12 })

            // Status 卡片
            Column({ space: 8 }) {
              this.sectionTitle(this.stringOf($r('app.string.pr_status_title')))
              Row({ space: 8 }) {
                OctIcon({ res: $r('app.media.oct_person_16'), iconSize: 14, iconColor: $r('app.color.text_secondary') })
                Text(this.stringOf($r('app.string.pr_reviews')))
                  .fontSize($r('app.float.caption_font_size'))
                  .fontColor($r('app.color.text_secondary'))
                Text(this.detail.reviewsTotal > 0 ? `${this.detail.reviewsTotal}` : this.stringOf($r('app.string.pr_reviews_none')))
                  .fontSize($r('app.float.caption_font_size'))
                  .fontColor($r('app.color.text_primary'))
              }
              .width('100%')
              Row({ space: 8 }) {
                OctIcon({ res: $r('app.media.oct_check_circle_fill_16'), iconSize: 14, iconColor: $r('app.color.success_text') })
                Text(this.detail.checksState === 'SUCCESS' ? this.stringOf($r('app.string.pr_all_checks_passed'))
                  : this.stringOf($r('app.string.work_pr_checks_failed')))
                  .fontSize($r('app.float.caption_font_size'))
                  .fontColor($r('app.color.text_secondary'))
              }
              .width('100%')
              if (this.detail.merged) {
                Row({ space: 8 }) {
                  OctIcon({ res: $r('app.media.oct_git_merge_16'), iconSize: 14, iconColor: $r('app.color.text_secondary') })
                  Text(this.stringOf($r('app.string.pr_branch_merged')))
                    .fontSize($r('app.float.caption_font_size'))
                    .fontColor($r('app.color.text_secondary'))
                  if (this.detail.mergeOid !== '') {
                    Text(resText(this.getUIContext(), $r('app.string.pr_merged_commit'), this.detail.mergeOid, this.detail.baseRefName))
                      .fontSize($r('app.float.caption_font_size'))
                      .fontColor($r('app.color.text_tertiary'))
                      .maxLines(1)
                  }
                }
                .width('100%')
              }
            }
            .padding($r('app.float.card_padding'))
            .borderRadius($r('app.float.card_radius'))
            .backgroundColor($r('app.color.card_background'))
            .width('100%')
            .margin({ bottom: 12 })

            // Conversation
            Column({ space: 8 }) {
              this.sectionTitle(this.stringOf($r('app.string.pr_conversation_title')))
              if (this.detail.comments.length === 0) {
                Text($r('app.string.issues_empty'))
                  .fontSize($r('app.float.caption_font_size'))
                  .fontColor($r('app.color.text_secondary'))
              }
              ForEach(this.detail.comments, (item: RepoComment) => {
                this.commentItem(item)
              }, (item: RepoComment) => item.id)
              if (this.detail.merged) {
                Button($r('app.string.pr_delete_branch'))
                  .buttonStyle(ButtonStyleMode.NORMAL)
                  .width('100%')
                  .height(40)
                  .fontSize($r('app.float.caption_font_size'))
                  .fontColor($r('app.color.text_secondary'))
                  .backgroundColor($r('app.color.card_background'))
                  .borderRadius(8)
                  .border({ width: 1, color: $r('app.color.border') })
                  .onClick(() => {
                    promptAction.showToast({ message: $r('app.string.home_feature_coming') });
                  })
              }
            }
            .padding($r('app.float.card_padding'))
            .borderRadius($r('app.float.card_radius'))
            .backgroundColor($r('app.color.card_background'))
            .width('100%')
          } else if (this.loading || this.errorMsg !== '') {
            StateView({ loading: this.loading, error: this.errorMsg, onRetry: () => this.refresh() })
          }
        }
        .padding({ left: 16, right: 16, bottom: 16 })
        .width('100%')
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .align(Alignment.Top)

      // 底部 COMMENT（写操作后续 Spec）
      Row({ space: 10 }) {
        Button($r('app.string.comment_button'))
          .buttonStyle(ButtonStyleMode.NORMAL)
          .layoutWeight(1)
          .height(44)
          .borderRadius(8)
          .onClick(() => {
            promptAction.showToast({ message: $r('app.string.home_feature_coming') });
          })
        Text('😊')
          .fontSize(20)
          .padding({ left: 10, right: 4 })
          .onClick(() => {
            promptAction.showToast({ message: $r('app.string.home_feature_coming') });
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 8, bottom: 12 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_page'))
  }
}
