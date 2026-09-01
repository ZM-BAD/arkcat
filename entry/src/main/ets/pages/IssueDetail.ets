/**
 * Issue 详情页（Spec 030）：标题 + 状态 + 正文（纯文本）+ 评论列表 + 底部 COMMENT 占位。
 */
import { promptAction } from '@kit.ArkUI';
import { OctIcon } from '../components/OctIcon';
import { RepoComment, IssueDetailPage } from '../models/RepoSubModels';
import { RepoSubService } from '../services/RepoSubService';
import { StateView } from '../components/StateView';
import { timeParts, TimeParts } from '../utils/Format';
import { resText } from '../utils/I18n';

@ComponentV2
export struct IssueDetailView {
  @Param owner: string = '';
  @Param name: string = '';
  @Param number: number = 0;
  @Param token: string = '';
  @Param pathStack: NavPathStack = new NavPathStack();
  @Local detail: IssueDetailPage | null = null;
  @Local cursor: string = '';
  @Local hasNextPage: boolean = false;
  @Local loading: boolean = true;
  @Local errorMsg: string = '';

  aboutToAppear(): void {
    this.refresh();
  }

  private refresh(): void {
    this.loading = true;
    this.errorMsg = '';
    RepoSubService.fetchIssueDetail(this.token, this.owner, this.name, this.number, '')
      .then((page: IssueDetailPage) => {
        this.detail = page;
        this.cursor = page.endCursor;
        this.hasNextPage = page.hasNextPage;
        this.loading = false;
      })
      .catch((e: Error) => {
        this.errorMsg = e.message;
        this.loading = false;
      });
  }

  private loadMore(): void {
    if (!this.hasNextPage || this.loading || this.detail === null) {
      return;
    }
    this.loading = true;
    RepoSubService.fetchIssueDetail(this.token, this.owner, this.name, this.number, this.cursor)
      .then((page: IssueDetailPage) => {
        this.detail = page;
        this.cursor = page.endCursor;
        this.hasNextPage = page.hasNextPage;
        this.loading = false;
      })
      .catch((e: Error) => {
        this.errorMsg = e.message;
        this.loading = false;
      });
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

  private stateIcon(): Resource {
    if (this.detail?.state === 'OPEN') {
      return $r('app.media.oct_issue_opened_16');
    }
    return this.detail?.stateReason === 'NOT_PLANNED'
      ? $r('app.media.oct_x_circle_16')
      : $r('app.media.oct_issue_closed_16');
  }

  private stateColor(): ResourceColor {
    if (this.detail?.state === 'OPEN') {
      return $r('app.color.success_text');
    }
    return this.detail?.stateReason === 'NOT_PLANNED' ? $r('app.color.text_tertiary') : $r('app.color.shortcut_purple_fg');
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
          OctIcon({ res: $r('app.media.oct_search_24'), iconSize: 20, iconColor: $r('app.color.text_primary') })
        }
        .padding(6)
        .onClick(() => {
          this.pathStack.pushPathByName('search', '');
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
            Column({ space: 8 }) {
              Text(this.detail.title)
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_primary'))
                .width('100%')
                .lineHeight(28)

              Row({ space: 8 }) {
                OctIcon({ res: this.stateIcon(), iconSize: 16, iconColor: this.stateColor() })
                Text(this.detail.authorLogin)
                  .fontSize($r('app.float.caption_font_size'))
                  .fontColor($r('app.color.text_secondary'))
                Text(this.timeText(timeParts(this.detail.createdAt, Date.now())))
                  .fontSize($r('app.float.caption_font_size'))
                  .fontColor($r('app.color.text_secondary'))
              }
              .width('100%')

              if (this.detail.body !== '') {
                Text(this.detail.body)
                  .fontSize($r('app.float.body_font_size'))
                  .fontColor($r('app.color.text_secondary'))
                  .maxLines(12)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .width('100%')
                  .lineHeight(20)
                if (this.detail.body.length > 300) {
                  Text($r('app.string.issue_detail_read_more'))
                    .fontSize($r('app.float.caption_font_size'))
                    .fontColor($r('app.color.link_blue'))
                    .onClick(() => {
                      promptAction.showToast({ message: $r('app.string.home_feature_coming') });
                    })
                }
              }
            }
            .padding($r('app.float.card_padding'))
            .borderRadius($r('app.float.card_radius'))
            .backgroundColor($r('app.color.card_background'))
            .width('100%')
            .margin({ bottom: 12 })

            Text(resText(this.getUIContext(), $r('app.string.issue_detail_comments'), this.detail.commentCount))
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary'))
              .width('100%')
              .padding({ bottom: 8 })

            ForEach(this.detail.comments, (item: RepoComment) => {
              this.commentItem(item)
            }, (item: RepoComment) => item.id)
            if (this.hasNextPage) {
              Text($r('app.string.issues_load_more'))
                .fontSize($r('app.float.body_font_size'))
                .fontColor($r('app.color.link_blue'))
                .padding(12)
                .onClick(() => this.loadMore())
            }
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

      // 底部操作栏（COMMENT + 表情，写操作后续 Spec）
      Row({ space: 10 }) {
        Button($r('app.string.comment_button'))
          .buttonStyle(ButtonStyleMode.NORMAL)
          .layoutWeight(1)
          .height(44)
          .borderRadius(6)
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
