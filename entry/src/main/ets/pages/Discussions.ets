/**
 * 工作区 Discussion 列表页（Spec 019）：跨仓库 Discussions（search type: DISCUSSION）。
 * 状态/归属下拉 + Unanswered 快捷标 + 分类胶囊。
 */
import { promptAction } from '@kit.ArkUI';
import { OctIcon } from '../components/OctIcon';
import { WorkDiscussionItem, WorkDiscussionsPage } from '../models/WorkModels';
import { WorkService } from '../services/WorkService';
import { StateView } from '../components/StateView';
import { WorkEmptyView } from '../components/WorkEmptyView';
import { timeParts, TimeParts } from '../utils/Format';
import { resText } from '../utils/I18n';

@ComponentV2
export struct DiscussionsView {
  @Param token: string = '';
  @Param pathStack: NavPathStack = new NavPathStack();
  @Local state: string = 'all';
  @Local scope: string = 'created';
  @Local unanswered: boolean = false;
  @Local discussions: WorkDiscussionItem[] = [];
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
    WorkService.fetchDiscussions(this.token, this.state, this.scope, this.unanswered, '')
      .then((page: WorkDiscussionsPage) => {
        this.discussions = page.discussions;
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
    if (!this.hasNextPage || this.loading) {
      return;
    }
    this.loading = true;
    WorkService.fetchDiscussions(this.token, this.state, this.scope, this.unanswered, this.cursor)
      .then((page: WorkDiscussionsPage) => {
        this.discussions = this.discussions.concat(page.discussions);
        this.cursor = page.endCursor;
        this.hasNextPage = page.hasNextPage;
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

  private activeFilterCount(): number {
    let count = 0;
    if (this.state !== 'all') {
      count++;
    }
    if (this.scope !== 'created') {
      count++;
    }
    if (this.unanswered) {
      count++;
    }
    return count;
  }

  private stateLabel(): string {
    if (this.state === 'open') {
      return this.stringOf($r('app.string.issues_state_open'));
    }
    if (this.state === 'closed') {
      return this.stringOf($r('app.string.issues_state_closed'));
    }
    return this.stringOf($r('app.string.work_filter_all'));
  }

  private scopeLabel(): string {
    if (this.scope === 'mentioned') {
      return this.stringOf($r('app.string.work_scope_mentioned'));
    }
    return this.stringOf($r('app.string.work_scope_created'));
  }

  private resetFilters(): void {
    this.state = 'all';
    this.scope = 'created';
    this.unanswered = false;
    this.refresh();
  }

  @Builder
  filterChip(label: string, menu: MenuElement[], active: boolean) {
    Text(`${label} ⌄`)
      .fontSize($r('app.float.caption_font_size'))
      .fontColor(active ? $r('app.color.link_blue') : $r('app.color.text_primary'))
      .padding({ left: 12, right: 12, top: 5, bottom: 5 })
      .borderRadius(12)
      .backgroundColor(active ? $r('app.color.chip_active_bg') : $r('app.color.card_background'))
      .margin({ right: 8 })
      .border({ width: 1, color: active ? $r('app.color.chip_active_border') : $r('app.color.border') })
      .bindMenu(menu)
  }

  @Builder
  discussionCard(item: WorkDiscussionItem) {
    Column({ space: 6 }) {
      Row() {
        OctIcon({
          res: $r('app.media.oct_comment_discussion_16'),
          iconSize: 18,
          iconColor: item.iconKey === 'open' ? '#8250DF' : $r('app.color.text_tertiary')
        })
        Text(`${item.repoFullName} #${item.number}`)
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_secondary'))
          .margin({ left: 12 })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        Text(this.timeText(timeParts(item.createdAt, Date.now())))
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_secondary'))
      }
      .width('100%')

      Text(item.title)
        .fontSize($r('app.float.body_font_size'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')

      if (item.category !== '' || item.replyCount > 0) {
        Row({ space: 8 }) {
          if (item.category !== '') {
            Text(item.category)
              .fontSize($r('app.float.caption_font_size'))
              .fontColor('#8250DF')
              .padding({ left: 8, right: 8, top: 2, bottom: 2 })
              .borderRadius(10)
              .backgroundColor($r('app.color.discussion_badge_bg'))
          }
          if (item.replyCount > 0) {
            Row({ space: 4 }) {
              OctIcon({ res: $r('app.media.oct_comment_16'), iconSize: 12, iconColor: $r('app.color.text_secondary') })
              Text(`${item.replyCount}`)
                .fontSize($r('app.float.caption_font_size'))
                .fontColor($r('app.color.text_secondary'))
            }
            .padding({ left: 8, right: 8, top: 2, bottom: 2 })
            .borderRadius(10)
            .backgroundColor($r('app.color.chip_bg'))
          }
        }
        .width('100%')
      }
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
  OctIcon({
          res: $r('app.media.oct_arrow_left_24'),
          iconSize: 20,
          iconColor: $r('app.color.text_primary')
  })
}
.onClick((): void => {
            this.pathStack.pop();
          })
        Text($r('app.string.nav_discussions_title'))
          .fontSize($r('app.float.title_font_size'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
        Stack() {
  OctIcon({
          res: $r('app.media.oct_search_24'),
          iconSize: 20,
          iconColor: $r('app.color.text_primary')
  })
}
.onClick((): void => {
            this.pathStack.pushPathByName('search', '');
          })
          .padding(6)
        Stack() {
  OctIcon({
          res: $r('app.media.oct_kebab_horizontal_16'),
          iconSize: 18,
          iconColor: $r('app.color.text_secondary')
  })
}
.onClick((): void => {
            promptAction.showToast({ message: $r('app.string.home_feature_coming') });
          })
          .padding(6)
      }
      .width('100%')
      .height(48)
      .padding({ left: 16, right: 12 })

      Scroll() {
        Column() {
          Row() {
            Stack({ alignContent: Alignment.TopEnd }) {
              OctIcon({
                res: $r('app.media.oct_filter_16'),
                iconSize: 14,
                iconColor: $r('app.color.text_primary')
              })
                .padding({ left: 8, right: 8, top: 5, bottom: 5 })
                .borderRadius(12)
                .backgroundColor($r('app.color.card_background'))
                .border({ width: 1, color: $r('app.color.border') })
              if (this.activeFilterCount() > 0) {
                Circle()
                  .width(12)
                  .height(12)
                  .fill($r('app.color.primary'))
                  .margin({ top: -6, right: -6 })
                Text(`${this.activeFilterCount()}`)
                  .fontSize(8)
                  .fontColor(Color.White)
                  .margin({ top: -10, right: -3 })
              }
            }
            .margin({ right: 8 })

            this.filterChip(this.stateLabel(), [
              {
                value: this.stringOf($r('app.string.work_filter_all')),
                action: (): void => { this.state = 'all'; this.refresh(); }
              },
              {
                value: this.stringOf($r('app.string.issues_state_open')),
                action: (): void => { this.state = 'open'; this.refresh(); }
              },
              {
                value: this.stringOf($r('app.string.issues_state_closed')),
                action: (): void => { this.state = 'closed'; this.refresh(); }
              }
            ], this.state !== 'all')

            this.filterChip(this.scopeLabel(), [
              {
                value: this.stringOf($r('app.string.work_scope_created')),
                action: (): void => { this.scope = 'created'; this.refresh(); }
              },
              {
                value: this.stringOf($r('app.string.work_scope_mentioned')),
                action: (): void => { this.scope = 'mentioned'; this.refresh(); }
              }
            ], this.scope !== 'created')

            // Unanswered 快捷标（开关式 chip，无下拉）
            Text(this.stringOf($r('app.string.work_discussions_unanswered')))
              .fontSize($r('app.float.caption_font_size'))
              .fontColor(this.unanswered ? $r('app.color.link_blue') : $r('app.color.text_primary'))
              .padding({ left: 12, right: 12, top: 5, bottom: 5 })
              .borderRadius(12)
              .backgroundColor(this.unanswered ? $r('app.color.chip_active_bg') : $r('app.color.card_background'))
              .border({ width: 1, color: this.unanswered ? $r('app.color.chip_active_border') : $r('app.color.border') })
              .onClick(() => {
                this.unanswered = !this.unanswered;
                this.refresh();
              })
          }
          .width('100%')
          .margin({ bottom: 12 })

          if (this.discussions.length > 0) {
            ForEach(this.discussions, (item: WorkDiscussionItem) => {
              this.discussionCard(item)
            }, (item: WorkDiscussionItem) => item.id)
            if (this.hasNextPage) {
              Text($r('app.string.issues_load_more'))
                .fontSize($r('app.float.body_font_size'))
                .fontColor($r('app.color.link_blue'))
                .padding(12)
                .onClick(() => this.loadMore())
            }
          } else if (this.loading || this.errorMsg !== '') {
            StateView({
              loading: this.loading,
              error: this.errorMsg,
              onRetry: () => this.refresh()
            })
          } else {
            WorkEmptyView({
              iconText: '🐱',
              title: $r('app.string.work_discussions_empty'),
              subtitle: $r('app.string.work_use_fewer_filters'),
              button: $r('app.string.work_reset_all_filters'),
              onButton: (): void => this.resetFilters()
            })
          }
        }
        .padding({ left: 16, right: 16, bottom: 16 })
        .width('100%')
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_page'))
  }
}
