/**
 * 工作区 Issue 列表页（Spec 017）：跨仓库 Issues（search type: ISSUE）。
 * 三组筛选（状态/归属/可见性）+ 状态图标（open/completed/not_planned）+ 标签胶囊 + 评论数。
 */
import { promptAction } from '@kit.ArkUI';
import { OctIcon } from '../components/OctIcon';
import { WorkIssueItem, WorkIssuesPage, WorkLabel } from '../models/WorkModels';
import { WorkService } from '../services/WorkService';
import { StateView } from '../components/StateView';
import { WorkEmptyView } from '../components/WorkEmptyView';
import { githubShortTime, timeParts, TimeParts } from '../utils/Format';
import { resText } from '../utils/I18n';

@ComponentV2
export struct WorkIssuesView {
  @Param token: string = '';
  @Param pathStack: NavPathStack = new NavPathStack();
  @Local state: string = 'all';
  @Local scope: string = 'created';
  @Local visibilityFilter: string = 'all';
  @Local orgFilter: string = '';
  @Local repoFilter: string = '';
  @Local sortNewest: boolean = true;
  @Local issues: WorkIssueItem[] = [];
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
    WorkService.fetchIssues(this.token, this.state, this.scope, this.visibilityFilter, '')
      .then((page: WorkIssuesPage) => {
        this.issues = page.issues;
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
    WorkService.fetchIssues(this.token, this.state, this.scope, this.visibilityFilter, this.cursor)
      .then((page: WorkIssuesPage) => {
        this.issues = this.issues.concat(page.issues);
        this.cursor = page.endCursor;
        this.hasNextPage = page.hasNextPage;
        this.loading = false;
      })
      .catch((e: Error) => {
        this.errorMsg = e.message;
        this.loading = false;
      });
  }

  /** 资源 → 当前语言纯文案 */
  private stringOf(res: Resource): string {
    return resText(this.getUIContext(), res);
  }

  /** 相对时间结构化数据 → 当前语言文案 */
  private timeText(parts: TimeParts | null): string {
    return parts !== null ? githubShortTime(parts) : '';
  }

  /** 激活的筛选数（漏斗徽标） */
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
    this.issues.forEach((it: WorkIssueItem) => {
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
    this.issues.forEach((it: WorkIssueItem) => {
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
  private visibleIssues(): WorkIssueItem[] {
    let list: WorkIssueItem[] = this.issues;
    if (this.orgFilter !== '') {
      list = list.filter((it: WorkIssueItem) => it.repoFullName.split('/')[0] === this.orgFilter);
    }
    if (this.repoFilter !== '') {
      list = list.filter((it: WorkIssueItem) => it.repoFullName === this.repoFilter);
    }
    const sorted: WorkIssueItem[] = [...list];
    sorted.sort((a: WorkIssueItem, b: WorkIssueItem) => {
      const cmp = a.createdAt.localeCompare(b.createdAt);
      return this.sortNewest ? -cmp : cmp;
    });
    return sorted;
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

  private resetFilters(): void {
    this.state = 'all';
    this.scope = 'created';
    this.visibilityFilter = 'all';
    this.orgFilter = '';
    this.repoFilter = '';
    this.sortNewest = true;
    this.refresh();
  }

  /** 状态图标（Spec 017/024：OPEN 绿 / COMPLETED 紫 / NOT_PLANNED 灰） */
  private issueIcon(issue: WorkIssueItem): Resource {
    if (issue.iconKey === 'open') {
      return $r('app.media.oct_issue_opened_16');
    }
    return issue.iconKey === 'not_planned'
      ? $r('app.media.oct_x_circle_16')
      : $r('app.media.oct_check_circle_16');
  }

  private issueColor(issue: WorkIssueItem): ResourceColor {
    if (issue.iconKey === 'open') {
      return $r('app.color.success_text');
    }
    return issue.iconKey === 'not_planned' ? $r('app.color.text_tertiary') : $r('app.color.shortcut_purple_fg');
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
  labelChip(label: WorkLabel) {
    Text(label.name)
      .fontSize(12)
      .fontColor(Color.White)
      .padding({ left: 8, right: 8, top: 2, bottom: 2 })
      .borderRadius(6)
      .backgroundColor(label.color !== '' ? label.color : $r('app.color.text_secondary'))
      .margin({ right: 6 })
  }

  @Builder
  issueCard(issue: WorkIssueItem, roundTop: boolean, roundBottom: boolean) {
    Column({ space: 6 }) {
      Row() {
        OctIcon({ res: this.issueIcon(issue), iconSize: 18, iconColor: this.issueColor(issue) })
        Text(`${issue.repoFullName} #${issue.number}`)
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_secondary'))
          .margin({ left: 12 })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        Text(this.timeText(timeParts(issue.createdAt, Date.now())))
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_secondary'))
      }
      .width('100%')

      Text(issue.title)
        .fontSize($r('app.float.body_font_size'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')

      if (issue.labels.length > 0 || issue.commentCount > 0) {
        Row() {
          ForEach(issue.labels, (label: WorkLabel) => {
            this.labelChip(label)
          }, (label: WorkLabel) => label.name)
          if (issue.commentCount > 0) {
            Row({ space: 4 }) {
              OctIcon({ res: $r('app.media.oct_comment_16'), iconSize: 12, iconColor: $r('app.color.text_secondary') })
              Text(`${issue.commentCount}`)
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
    .borderRadius({
      topLeft: roundTop ? $r('app.float.card_radius') : 0,
      topRight: roundTop ? $r('app.float.card_radius') : 0,
      bottomLeft: roundBottom ? $r('app.float.card_radius') : 0,
      bottomRight: roundBottom ? $r('app.float.card_radius') : 0
    })
    .backgroundColor($r('app.color.card_background'))
    .width('100%')
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
        Text($r('app.string.nav_issues_title'))
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
            // 漏斗徽标：激活筛选数
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

          if (this.visibleIssues().length > 0) {
            ForEach(this.visibleIssues(), (issue: WorkIssueItem, index: number) => {
              this.issueCard(issue, index === 0, index === this.visibleIssues().length - 1)
              if (index !== this.visibleIssues().length - 1) {
                Divider()
                  .color($r('app.color.divider'))
                  .strokeWidth(1)
              }
            }, (issue: WorkIssueItem) => issue.id)
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
              title: $r('app.string.work_issues_empty'),
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
