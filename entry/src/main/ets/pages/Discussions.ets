/**
 * 工作区 Discussion 列表页（Spec 019）：跨仓库 Discussions（search type: DISCUSSION）。
 * 状态/归属下拉 + Unanswered 快捷标 + 分类胶囊。
 */
import { promptAction } from '@kit.ArkUI';
import { OctIcon } from '../components/OctIcon';
import { FilterDropdownChip, FilterDropdownOption } from '../components/FilterDropdownChip';
import { WorkDiscussionItem, WorkDiscussionsPage } from '../models/WorkModels';
import { WorkService } from '../services/WorkService';
import { StateView } from '../components/StateView';
import { WorkEmptyView } from '../components/WorkEmptyView';
import { githubShortTime, timeParts, TimeParts } from '../utils/Format';
import { resText } from '../utils/I18n';

@ComponentV2
export struct DiscussionsView {
  @Param token: string = '';
  @Param pathStack: NavPathStack = new NavPathStack();
  @Local state: string = 'open';
  @Local scope: string = 'created';
  @Local unanswered: boolean = false;
  /** 'new' | 'top_all' | 'top_yesterday' | 'top_week' | 'top_month' | 'top_year' */
  @Local sortKey: string = 'new';
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
    WorkService.fetchDiscussions(this.token, this.state, this.scope, this.unanswered, this.sortKey, '')
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
    WorkService.fetchDiscussions(this.token, this.state, this.scope, this.unanswered, this.sortKey, this.cursor)
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
    return parts !== null ? githubShortTime(parts) : '';
  }

  private activeFilterCount(): number {
    let count = 0;
    if (this.state !== 'open') {
      count++;
    }
    if (this.scope !== 'created') {
      count++;
    }
    if (this.unanswered) {
      count++;
    }
    if (this.sortKey !== 'new') {
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
    if (this.scope === 'commented') {
      return this.stringOf($r('app.string.discussions_filter_scope_commented'));
    }
    return this.stringOf($r('app.string.issues_filter_scope_created'));
  }

  private sortLabel(): string {
    for (const opt of this.sortOptions()) {
      if (opt.key === this.sortKey) {
        return opt.label;
      }
    }
    return this.stringOf($r('app.string.work_filter_sort_new'));
  }

  private stateOptions(): FilterDropdownOption[] {
    return [
      { key: 'open', label: this.stringOf($r('app.string.issues_state_open')) },
      { key: 'closed', label: this.stringOf($r('app.string.issues_state_closed')) },
      { key: 'all', label: this.stringOf($r('app.string.work_filter_all')) }
    ];
  }

  private scopeOptions(): FilterDropdownOption[] {
    return [
      { key: 'created', label: this.stringOf($r('app.string.issues_filter_scope_created')) },
      { key: 'commented', label: this.stringOf($r('app.string.discussions_filter_scope_commented')) }
    ];
  }

  private sortOptions(): FilterDropdownOption[] {
    return [
      { key: 'new', label: this.stringOf($r('app.string.work_filter_sort_new')) },
      { key: 'top_all', label: this.stringOf($r('app.string.discussions_sort_top_all')) },
      { key: 'top_yesterday', label: this.stringOf($r('app.string.discussions_sort_top_yesterday')) },
      { key: 'top_week', label: this.stringOf($r('app.string.discussions_sort_top_week')) },
      { key: 'top_month', label: this.stringOf($r('app.string.discussions_sort_top_month')) },
      { key: 'top_year', label: this.stringOf($r('app.string.discussions_sort_top_year')) }
    ];
  }

  private resetFilters(): void {
    this.state = 'open';
    this.scope = 'created';
    this.unanswered = false;
    this.sortKey = 'new';
    this.refresh();
  }

  @Builder
  discussionCard(item: WorkDiscussionItem) {
    Column({ space: 6 }) {
      Row() {
        OctIcon({
          res: $r('app.media.oct_comment_discussion_16'),
          iconSize: 18,
          iconColor: item.iconKey === 'open' ? $r('app.color.shortcut_purple_fg') : $r('app.color.text_tertiary')
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
              .fontColor($r('app.color.shortcut_purple_fg'))
              .padding({ left: 8, right: 8, top: 2, bottom: 2 })
              .borderRadius(12)
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
            .borderRadius(12)
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
.width(44)
.height(44)
        .accessibilityDescription($r('app.string.a11y_back'))
        .focusable(true)
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
          iconColor: $r('app.color.link_blue')
  })
}
.width(44)
.height(44)
        .accessibilityDescription($r('app.string.a11y_search'))
        .focusable(true)
.onClick((): void => {
            this.pathStack.pushPathByName('search', '');
          })
          .padding(6)
        Stack() {
  OctIcon({
          res: $r('app.media.oct_kebab_horizontal_16'),
          iconSize: 18,
          iconColor: $r('app.color.link_blue')
  })
  .rotate({ angle: 90 })
}
.width(44)
.height(44)
        .accessibilityDescription($r('app.string.a11y_more'))
        .focusable(true)
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
          Scroll() {
          Row() {
            if (this.activeFilterCount() > 0) {
              Row({ space: 4 }) {
                OctIcon({
                  res: $r('app.media.oct_filter_16'),
                  iconSize: 14,
                  iconColor: $r('app.color.link_blue')
                })
                Stack() {
                  Text(`${this.activeFilterCount()}`)
                    .fontSize(12)
                    .fontColor(Color.White)
                }
                .width(18)
                .height(18)
                .borderRadius(9)
                .backgroundColor($r('app.color.link_blue'))
              }
              .height(30)
              .padding({ left: 8, right: 8 })
              .borderRadius(12)
              .backgroundColor($r('app.color.card_background'))
              .border({ width: 1, color: $r('app.color.border') })
              .margin({ right: 8 })
              .bindMenu([
                {
                  value: $r('app.string.work_filter_create_shortcut'),
                  action: (): void => {
                    promptAction.showToast({ message: $r('app.string.home_feature_coming') });
                  }
                },
                {
                  value: $r('app.string.work_clear_all_filters'),
                  action: (): void => this.resetFilters()
                }
              ])
            }

            FilterDropdownChip({
              label: this.stateLabel(),
              active: this.state !== 'open',
              options: this.stateOptions(),
              selectedKey: this.state,
              onPick: (key: string): void => {
                this.state = key;
                this.refresh();
              }
            })

            FilterDropdownChip({
              label: this.scopeLabel(),
              active: this.scope !== 'created',
              options: this.scopeOptions(),
              selectedKey: this.scope,
              onPick: (key: string): void => {
                this.scope = key;
                this.refresh();
              }
            })

            // Unanswered 开关 chip（官方：只有选中/未选中两种状态，无下拉）
            Text(this.stringOf($r('app.string.work_discussions_unanswered')))
              .fontSize($r('app.float.caption_font_size'))
              .fontColor(this.unanswered ? $r('app.color.link_blue') : $r('app.color.text_primary'))
              .height(30)
              .padding({ left: 12, right: 12 })
              .borderRadius(12)
              .backgroundColor(this.unanswered ? $r('app.color.chip_active_bg') : $r('app.color.card_background'))
              .border({ width: 1, color: this.unanswered ? $r('app.color.chip_active_border') : $r('app.color.border') })
              .margin({ right: 8 })
              .onClick(() => {
                this.unanswered = !this.unanswered;
                this.refresh();
              })

            FilterDropdownChip({
              label: this.sortLabel(),
              active: this.sortKey !== 'new',
              options: this.sortOptions(),
              selectedKey: this.sortKey,
              onPick: (key: string): void => {
                this.sortKey = key;
                this.refresh();
              }
            })
          }
          .width('100%')
          }
          .scrollable(ScrollDirection.Horizontal)
          .scrollBar(BarState.Off)
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
              subtitle: $r('app.string.work_use_fewer_filters')
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
