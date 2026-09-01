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
import { githubShortTime, timeParts, TimeParts } from '../utils/Format';
import { resText } from '../utils/I18n';

@ComponentV2
export struct WorkPrsView {
  @Param token: string = '';
  @Param pathStack: NavPathStack = new NavPathStack();
  @Local state: string = 'all';
  @Local scope: string = 'created';
  @Local visibilityFilter: string = 'all';
  @Local orgFilter: string = '';
  @Local repoFilter: string = '';
  @Local sortNewest: boolean = true;
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
    return parts !== null ? githubShortTime(parts) : '';
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
    if (this.orgFilter !== '') {
      count++;
    }
    if (this.repoFilter !== '') {
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

  private orgLabel(): string {
    return this.orgFilter !== '' ? this.orgFilter : this.stringOf($r('app.string.work_filter_organization'));
  }

  private repoLabel(): string {
    return this.repoFilter !== '' ? this.repoFilter : this.stringOf($r('app.string.work_filter_repository'));
  }

  private sortLabel(): string {
    return this.sortNewest
      ? this.stringOf($r('app.string.work_filter_sort_newest'))
      : this.stringOf($r('app.string.work_filter_sort_oldest'));
  }

  /** Organization 下拉：All organizations + 当前页数据中出现的组织（仓库属主） */
  private orgMenu(): MenuElement[] {
    const opts: string[] = [];
    this.prs.forEach((it: WorkPrItem) => {
      const owner = it.repoFullName.split('/')[0];
      if (owner !== '' && !opts.includes(owner)) {
        opts.push(owner);
      }
    });
    const items: MenuElement[] = [{
      value: this.stringOf($r('app.string.work_filter_all_orgs')),
      action: (): void => { this.orgFilter = ''; }
    }];
    opts.forEach((o: string) => {
      items.push({
        value: o,
        action: (): void => { this.orgFilter = o; }
      });
    });
    return items;
  }

  /** Repository 下拉：All repositories + 当前页数据中出现的仓库 */
  private repoMenu(): MenuElement[] {
    const opts: string[] = [];
    this.prs.forEach((it: WorkPrItem) => {
      if (!opts.includes(it.repoFullName)) {
        opts.push(it.repoFullName);
      }
    });
    const items: MenuElement[] = [{
      value: this.stringOf($r('app.string.work_filter_all_repos')),
      action: (): void => { this.repoFilter = ''; }
    }];
    opts.forEach((r: string) => {
      items.push({
        value: r,
        action: (): void => { this.repoFilter = r; }
      });
    });
    return items;
  }

  /** 客户端组合过滤 + 排序（Organization / Repository / Sort） */
  private visiblePrs(): WorkPrItem[] {
    let list: WorkPrItem[] = this.prs;
    if (this.orgFilter !== '') {
      list = list.filter((it: WorkPrItem) => it.repoFullName.split('/')[0] === this.orgFilter);
    }
    if (this.repoFilter !== '') {
      list = list.filter((it: WorkPrItem) => it.repoFullName === this.repoFilter);
    }
    const sorted: WorkPrItem[] = [...list];
    sorted.sort((a: WorkPrItem, b: WorkPrItem) => {
      const cmp = a.createdAt.localeCompare(b.createdAt);
      return this.sortNewest ? -cmp : cmp;
    });
    return sorted;
  }

  private resetFilters(): void {
    this.state = 'all';
    this.scope = 'created';
    this.visibilityFilter = 'all';
    this.orgFilter = '';
    this.repoFilter = '';
    this.sortNewest = true;
    this.refresh();
  }

  /** PR 状态图标（Spec 024：merged 紫 / open 绿 / closed 灰） */
  private prIcon(item: WorkPrItem): Resource {
    if (item.iconKey === 'merged') {
      return $r('app.media.oct_check_circle_fill_16');
    }
    return item.iconKey === 'open' ? $r('app.media.oct_git_pull_request_16') : $r('app.media.oct_x_circle_16');
  }

  private prColor(item: WorkPrItem): ResourceColor {
    if (item.iconKey === 'merged') {
      return $r('app.color.shortcut_purple_fg');
    }
    return item.iconKey === 'open' ? $r('app.color.success_text') : $r('app.color.text_tertiary');
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

  private checksColor(state: string): ResourceColor {
    if (state === 'SUCCESS') {
      return $r('app.color.success_text');
    }
    if (state === 'FAILURE' || state === 'ERROR') {
      return $r('app.color.danger_text');
    }
    return $r('app.color.warning_text');
  }

  private checksBg(state: string): ResourceColor {
    if (state === 'SUCCESS') {
      return $r('app.color.checks_success_bg');
    }
    if (state === 'FAILURE' || state === 'ERROR') {
      return $r('app.color.checks_failure_bg');
    }
    return $r('app.color.checks_pending_bg');
  }

  @Builder
  filterChip(label: string, menu: MenuElement[], active: boolean) {
    Row() {
      Text(label)
        .fontSize($r('app.float.caption_font_size'))
        .fontColor(active ? $r('app.color.link_blue') : $r('app.color.text_primary'))
      OctIcon({
        res: $r('app.media.oct_chevron_down_16'),
        iconSize: 12,
        iconColor: active ? $r('app.color.link_blue') : $r('app.color.text_secondary')
      })
        .margin({ left: 4 })
    }
    .height(30)
    .padding({ left: 12, right: 10 })
    .borderRadius(12)
    .backgroundColor(active ? $r('app.color.chip_active_bg') : $r('app.color.card_background'))
    .margin({ right: 8 })
    .border({ width: 1, color: active ? $r('app.color.chip_active_border') : $r('app.color.border') })
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
          .borderRadius(12)
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
          .borderRadius(12)
          .backgroundColor($r('app.color.chip_bg'))
        }
        if (item.reviewCount > 0) {
          Row({ space: 4 }) {
            OctIcon({ res: $r('app.media.oct_eye_16'), iconSize: 12, iconColor: $r('app.color.text_secondary') })
            Text(`${item.reviewCount}`)
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
        Text($r('app.string.home_work_pull_requests'))
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

            this.filterChip(this.orgLabel(), this.orgMenu(), this.orgFilter !== '')
            this.filterChip(this.repoLabel(), this.repoMenu(), this.repoFilter !== '')
            this.filterChip(this.sortLabel(), [
              {
                value: this.stringOf($r('app.string.work_sort_newest')),
                action: (): void => { this.sortNewest = true; }
              },
              {
                value: this.stringOf($r('app.string.work_sort_oldest')),
                action: (): void => { this.sortNewest = false; }
              }
            ], !this.sortNewest)
          }
          .width('100%')
          }
          .scrollable(ScrollDirection.Horizontal)
          .scrollBar(BarState.Off)
          .margin({ bottom: 12 })

          if (this.visiblePrs().length > 0) {
            ForEach(this.visiblePrs(), (item: WorkPrItem) => {
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
