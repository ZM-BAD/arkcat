/**
 * 工作区 PR 列表页（Spec 018）：跨仓库 Pull Requests（search type: PR）。
 * 状态（All/Open/Closed/Merged）+ Checks 胶囊（✔ Checks / ✗ Checks failed / ⏳ pending）。
 */
import { promptAction } from '@kit.ArkUI';
import { OctIcon } from '../components/OctIcon';
import { WorkPrItem, WorkPrsPage } from '../models/WorkModels';
import { WorkService } from '../services/WorkService';
import { StateView } from '../components/StateView';
import { WorkEmptyView } from '../components/WorkEmptyView';
import { timeParts, TimeParts } from '../utils/Format';
import { resText } from '../utils/I18n';

@ComponentV2
export struct WorkPrsView {
  @Param token: string = '';
  @Param pathStack: NavPathStack = new NavPathStack();
  @Local state: string = 'all';
  @Local scope: string = 'created';
  @Local visibilityFilter: string = 'all';
  @Local prs: WorkPrItem[] = [];
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
    WorkService.fetchPrs(this.token, this.state, this.scope, this.visibilityFilter, '')
      .then((page: WorkPrsPage) => {
        this.prs = page.prs;
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
    WorkService.fetchPrs(this.token, this.state, this.scope, this.visibilityFilter, this.cursor)
      .then((page: WorkPrsPage) => {
        this.prs = this.prs.concat(page.prs);
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
    if (this.visibilityFilter !== 'all') {
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
    if (this.state === 'merged') {
      return this.stringOf($r('app.string.pr_state_merged'));
    }
    return this.stringOf($r('app.string.work_filter_all'));
  }

  private scopeLabel(): string {
    if (this.scope === 'assigned') {
      return this.stringOf($r('app.string.work_scope_assigned'));
    }
    if (this.scope === 'mentioned') {
      return this.stringOf($r('app.string.work_scope_mentioned'));
    }
    return this.stringOf($r('app.string.work_scope_created'));
  }

  private visibilityLabel(): string {
    if (this.visibilityFilter === 'public') {
      return this.stringOf($r('app.string.work_visibility_public'));
    }
    if (this.visibilityFilter === 'private') {
      return this.stringOf($r('app.string.work_visibility_private'));
    }
    return this.stringOf($r('app.string.work_visibility'));
  }

  private resetFilters(): void {
    this.state = 'all';
    this.scope = 'created';
    this.visibilityFilter = 'all';
    this.refresh();
  }

  /** PR 状态图标（Spec 024：merged 紫 / open 绿 / closed 灰） */
  private prIcon(item: WorkPrItem): Resource {
    if (item.iconKey === 'merged') {
      return $r('app.media.oct_check_circle_fill_16');
    }
    return item.iconKey === 'open' ? $r('app.media.oct_git_pull_request_16') : $r('app.media.oct_x_circle_16');
  }

  private prColor(item: WorkPrItem): string {
    if (item.iconKey === 'merged') {
      return '#8250DF';
    }
    return item.iconKey === 'open' ? '#2DA44E' : '#8C959F';
  }

  /** Checks 胶囊文案（SUCCESS/FAILURE/PENDING；未知静默，图标由 checksIcon 提供） */
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
    return '';
  }

  private checksIcon(state: string): Resource {
    if (state === 'SUCCESS') {
      return $r('app.media.oct_check_16');
    }
    return $r('app.media.oct_x_16');
  }

  private checksColor(state: string): string {
    if (state === 'SUCCESS') {
      return '#1A7F37';
    }
    if (state === 'FAILURE' || state === 'ERROR') {
      return '#CF222E';
    }
    return '#9A6700';
  }

  private checksBg(state: string): string {
    if (state === 'SUCCESS') {
      return '#DAFBE1';
    }
    if (state === 'FAILURE' || state === 'ERROR') {
      return '#FFEBE9';
    }
    return '#FFF8C5';
  }

  @Builder
  filterChip(label: string, menu: MenuElement[], active: boolean) {
    Text(`${label} ⌄`)
      .fontSize($r('app.float.caption_font_size'))
      .fontColor(active ? '#0969DA' : $r('app.color.text_primary'))
      .padding({ left: 12, right: 12, top: 5, bottom: 5 })
      .borderRadius(12)
      .backgroundColor(active ? '#DDF4FF' : $r('app.color.card_background'))
      .margin({ right: 8 })
      .border({ width: 1, color: active ? '#B6E1FF' : '#D0D7DE' })
      .bindMenu(menu)
  }

  @Builder
  prCard(item: WorkPrItem) {
    Column({ space: 6 }) {
      Row() {
        OctIcon({ res: this.prIcon(item), iconSize: 18, iconColor: this.prColor(item) })
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

      Row({ space: 8 }) {
        if (item.checksState !== '') {
          Row({ space: 4 }) {
            OctIcon({
              res: this.checksIcon(item.checksState),
              iconSize: 12,
              iconColor: this.checksColor(item.checksState)
            })
            Text(this.checksLabel(item.checksState))
              .fontSize($r('app.float.caption_font_size'))
              .fontColor(this.checksColor(item.checksState))
          }
          .padding({ left: 8, right: 8, top: 2, bottom: 2 })
          .borderRadius(10)
          .backgroundColor(this.checksBg(item.checksState))
        }
        if (item.commentCount > 0) {
          Row({ space: 4 }) {
            OctIcon({ res: $r('app.media.oct_comment_16'), iconSize: 12, iconColor: $r('app.color.text_secondary') })
            Text(`${item.commentCount}`)
              .fontSize($r('app.float.caption_font_size'))
              .fontColor($r('app.color.text_secondary'))
          }
          .padding({ left: 8, right: 8, top: 2, bottom: 2 })
          .borderRadius(10)
          .backgroundColor('#F6F8FA')
        }
        if (item.reviewCount > 0) {
          Row({ space: 4 }) {
            OctIcon({ res: $r('app.media.oct_eye_16'), iconSize: 12, iconColor: $r('app.color.text_secondary') })
            Text(`${item.reviewCount}`)
              .fontSize($r('app.float.caption_font_size'))
              .fontColor($r('app.color.text_secondary'))
          }
          .padding({ left: 8, right: 8, top: 2, bottom: 2 })
          .borderRadius(10)
          .backgroundColor('#F6F8FA')
        }
      }
      .width('100%')
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
        Text($r('app.string.home_work_pull_requests'))
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
                .border({ width: 1, color: '#D0D7DE' })
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
              },
              {
                value: this.stringOf($r('app.string.pr_state_merged')),
                action: (): void => { this.state = 'merged'; this.refresh(); }
              }
            ], this.state !== 'all')

            this.filterChip(this.scopeLabel(), [
              {
                value: this.stringOf($r('app.string.work_scope_created')),
                action: (): void => { this.scope = 'created'; this.refresh(); }
              },
              {
                value: this.stringOf($r('app.string.work_scope_assigned')),
                action: (): void => { this.scope = 'assigned'; this.refresh(); }
              },
              {
                value: this.stringOf($r('app.string.work_scope_mentioned')),
                action: (): void => { this.scope = 'mentioned'; this.refresh(); }
              }
            ], this.scope !== 'created')

            this.filterChip(this.visibilityLabel(), [
              {
                value: this.stringOf($r('app.string.work_visibility')),
                action: (): void => { this.visibilityFilter = 'all'; this.refresh(); }
              },
              {
                value: this.stringOf($r('app.string.work_visibility_public')),
                action: (): void => { this.visibilityFilter = 'public'; this.refresh(); }
              },
              {
                value: this.stringOf($r('app.string.work_visibility_private')),
                action: (): void => { this.visibilityFilter = 'private'; this.refresh(); }
              }
            ], this.visibilityFilter !== 'all')
          }
          .width('100%')
          .margin({ bottom: 12 })

          if (this.prs.length > 0) {
            ForEach(this.prs, (item: WorkPrItem) => {
              this.prCard(item)
            }, (item: WorkPrItem) => item.id)
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
              title: $r('app.string.work_prs_empty'),
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
