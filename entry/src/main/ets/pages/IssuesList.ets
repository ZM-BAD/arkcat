/**
 * 仓库内 Issue 列表页（Spec 007/026 修订）：官方布局对齐——
 * 副标题 owner + 四筛选（状态/Label/Author/Assignee）+ 行样式（状态圈/标题/#N/时间/💬/🔁）。
 * Author/Assignee 为客户端过滤（首屏集合），行点击进入 Issue 详情（Spec 030）。
 */
import { promptAction } from '@kit.ArkUI';
import { OctIcon } from '../components/OctIcon';
import { IssueSummary, IssuesPage } from '../models/IssuesModels';
import { IssuesService } from '../services/IssuesService';
import { StateView } from '../components/StateView';
import { timeParts, TimeParts } from '../utils/Format';
import { resText } from '../utils/I18n';

@ComponentV2
export struct IssuesListView {
  @Param owner: string = '';
  @Param name: string = '';
  @Param token: string = '';
  @Param pathStack: NavPathStack = new NavPathStack();
  @Local state: string = 'all';
  @Local label: string = '';
  @Local author: string = '';
  @Local assignee: string = '';
  @Local all: IssueSummary[] = [];
  @Local shown: IssueSummary[] = [];
  @Local repoLabels: string[] = [];
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
    IssuesService.fetchRepoIssues(this.token, this.owner, this.name, this.state, this.label, '')
      .then((page: IssuesPage) => {
        this.all = page.issues;
        this.repoLabels = page.repoLabels;
        this.cursor = page.endCursor;
        this.hasNextPage = page.hasNextPage;
        this.applyFilters();
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
    IssuesService.fetchRepoIssues(this.token, this.owner, this.name, this.state, this.label, this.cursor)
      .then((page: IssuesPage) => {
        this.all = this.all.concat(page.issues);
        this.cursor = page.endCursor;
        this.hasNextPage = page.hasNextPage;
        this.applyFilters();
        this.loading = false;
      })
      .catch((e: Error) => {
        this.errorMsg = e.message;
        this.loading = false;
      });
  }

  /** 客户端过滤：Author/Assignee（Spec 027 边界） */
  private applyFilters(): void {
    const next: IssueSummary[] = [];
    for (const issue of this.all) {
      if (this.author !== '' && issue.authorLogin !== this.author) {
        continue;
      }
      if (this.assignee !== '' && issue.assignees.indexOf(this.assignee) < 0) {
        continue;
      }
      next.push(issue);
    }
    this.shown = next;
  }

  /** Author 下拉选项（首屏作者集合） */
  private authorOptions(): string[] {
    const seen: Set<string> = new Set();
    const options: string[] = [];
    for (const issue of this.all) {
      if (issue.authorLogin !== '' && !seen.has(issue.authorLogin)) {
        seen.add(issue.authorLogin);
        options.push(issue.authorLogin);
      }
    }
    return options;
  }

  /** Assignee 下拉选项（首屏分配人集合） */
  private assigneeOptions(): string[] {
    const seen: Set<string> = new Set();
    const options: string[] = [];
    for (const issue of this.all) {
      for (const a of issue.assignees) {
        if (!seen.has(a)) {
          seen.add(a);
          options.push(a);
        }
      }
    }
    return options;
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

  private stateLabel(): string {
    if (this.state === 'open') {
      return this.stringOf($r('app.string.issues_state_open'));
    }
    if (this.state === 'closed') {
      return this.stringOf($r('app.string.issues_state_closed'));
    }
    return this.stringOf($r('app.string.work_filter_all'));
  }

  private activeFilterCount(): number {
    let c = this.state === 'all' ? 0 : 1;
    if (this.label !== '') {
      c++;
    }
    if (this.author !== '') {
      c++;
    }
    if (this.assignee !== '') {
      c++;
    }
    return c;
  }

  private issueIcon(issue: IssueSummary): Resource {
    if (issue.state === 'OPEN') {
      return $r('app.media.oct_issue_opened_16');
    }
    return $r('app.media.oct_issue_closed_16');
  }

  private issueColor(issue: IssueSummary): ResourceColor {
    return issue.state === 'OPEN' ? $r('app.color.success_text') : $r('app.color.shortcut_purple_fg');
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

  private labelMenu(): MenuElement[] {
    const items: MenuElement[] = [];
    for (const l of this.repoLabels) {
      items.push({
        value: l,
        action: (): void => { this.label = this.label === l ? '' : l; this.refresh(); }
      });
    }
    if (items.length === 0) {
      items.push({ value: this.stringOf($r('app.string.repo_prs_label')), action: (): void => { } });
    }
    return items;
  }

  private authorMenu(): MenuElement[] {
    const items: MenuElement[] = [];
    for (const a of this.authorOptions()) {
      items.push({
        value: a,
        action: (): void => { this.author = this.author === a ? '' : a; this.applyFilters(); }
      });
    }
    return items;
  }

  private assigneeMenu(): MenuElement[] {
    const items: MenuElement[] = [];
    for (const a of this.assigneeOptions()) {
      items.push({
        value: a,
        action: (): void => { this.assignee = this.assignee === a ? '' : a; this.applyFilters(); }
      });
    }
    return items;
  }

  @Builder
  labelChip(label: string) {
    Text(label)
      .fontSize(12)
      .fontColor(Color.White)
      .padding({ left: 8, right: 8, top: 2, bottom: 2 })
      .borderRadius(6)
      .backgroundColor($r('app.color.text_secondary'))
      .margin({ right: 6 })
  }

  @Builder
  issueCard(issue: IssueSummary) {
    Column({ space: 6 }) {
      Row() {
        OctIcon({ res: this.issueIcon(issue), iconSize: 22, iconColor: this.issueColor(issue) })
        Text(issue.title)
          .fontSize($r('app.float.body_font_size'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .margin({ left: 12 })
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        Text(`#${issue.number}`)
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_secondary'))
          .margin({ left: 8 })
      }
      .width('100%')

      Row({ space: 8 }) {
        ForEach(issue.labels, (label: string) => {
          this.labelChip(label)
        }, (label: string) => label)
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
        if (issue.linkedPrCount > 0) {
          Row({ space: 4 }) {
            OctIcon({ res: $r('app.media.oct_git_pull_request_16'), iconSize: 12, iconColor: $r('app.color.text_secondary') })
            Text(`${issue.linkedPrCount}`)
              .fontSize($r('app.float.caption_font_size'))
              .fontColor($r('app.color.text_secondary'))
          }
          .padding({ left: 8, right: 8, top: 2, bottom: 2 })
          .borderRadius(12)
          .backgroundColor($r('app.color.chip_bg'))
        }
        Blank()
        Text(this.timeText(timeParts(issue.createdAt, Date.now())))
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_secondary'))
      }
      .width('100%')
    }
    .padding($r('app.float.card_padding'))
    .borderRadius($r('app.float.card_radius'))
    .backgroundColor($r('app.color.card_background'))
    .width('100%')
    .margin({ bottom: 8 })
    .onClick(() => {
      this.pathStack.pushPathByName('issueDetail', `${this.owner}/${this.name}/${issue.number}`);
    })
  }

  build() {
    Column() {
      Row({ space: 8 }) {
        Stack() {
          OctIcon({ res: $r('app.media.oct_arrow_left_24'), iconSize: 20, iconColor: $r('app.color.text_primary') })
        }
.width(44)
.height(44)
        .accessibilityDescription($r('app.string.a11y_back'))
        .focusable(true)
        .onClick(() => {
          this.pathStack.pop();
        })
        Column({ space: 0 }) {
          Text(this.owner)
            .fontSize($r('app.float.caption_font_size'))
            .fontColor($r('app.color.text_secondary'))
          Text($r('app.string.repo_issues_link'))
            .fontSize($r('app.float.title_font_size'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Stack() {
          OctIcon({ res: $r('app.media.oct_search_24'), iconSize: 20, iconColor: $r('app.color.text_primary') })
        }
.width(44)
.height(44)
        .padding(6)
        .accessibilityDescription($r('app.string.a11y_search'))
        .focusable(true)
        .onClick(() => {
          this.pathStack.pushPathByName('search', '');
        })
        Stack() {
          OctIcon({ res: $r('app.media.oct_plus_24'), iconSize: 20, iconColor: $r('app.color.link_blue') })
        }
.width(44)
.height(44)
        .padding(6)
        .accessibilityDescription($r('app.string.a11y_new'))
        .focusable(true)
        .onClick(() => {
          promptAction.showToast({ message: $r('app.string.issues_new_coming') });
        })
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 8 })

      Scroll() {
        Column() {
          Row() {
            Stack({ alignContent: Alignment.TopEnd }) {
              OctIcon({ res: $r('app.media.oct_filter_16'), iconSize: 14, iconColor: $r('app.color.text_primary') })
                .padding({ left: 8, right: 8, top: 5, bottom: 5 })
                .borderRadius(12)
                .backgroundColor($r('app.color.card_background'))
                .border({ width: 1, color: $r('app.color.border') })
              if (this.activeFilterCount() > 0) {
                Circle()
                  .width(12)
                  .height(12)
                  .fill($r('app.color.link_blue'))
                  .margin({ top: -6, right: -6 })
                Text(`${this.activeFilterCount()}`)
                  .fontSize(12)
                  .fontColor(Color.White)
                  .margin({ top: -10, right: -3 })
              }
            }
            .margin({ right: 8 })

            this.filterChip(this.stateLabel(), [
              { value: this.stringOf($r('app.string.work_filter_all')), action: (): void => { this.state = 'all'; this.refresh(); } },
              { value: this.stringOf($r('app.string.issues_state_open')), action: (): void => { this.state = 'open'; this.refresh(); } },
              { value: this.stringOf($r('app.string.issues_state_closed')), action: (): void => { this.state = 'closed'; this.refresh(); } }
            ], this.state !== 'all')

            this.filterChip(this.label === '' ? this.stringOf($r('app.string.repo_prs_label')) : this.label,
              this.labelMenu(), this.label !== '')

            this.filterChip(this.author === '' ? this.stringOf($r('app.string.repo_prs_author')) : this.author,
              this.authorMenu(), this.author !== '')

            this.filterChip(this.assignee === '' ? this.stringOf($r('app.string.repo_prs_assignee')) : this.assignee,
              this.assigneeMenu(), this.assignee !== '')
          }
          .width('100%')
          .margin({ bottom: 12 })

          if (this.shown.length > 0) {
            ForEach(this.shown, (issue: IssueSummary) => {
              this.issueCard(issue)
            }, (issue: IssueSummary) => issue.id)
            if (this.hasNextPage) {
              Text($r('app.string.issues_load_more'))
                .fontSize($r('app.float.body_font_size'))
                .fontColor($r('app.color.link_blue'))
                .padding(12)
                .onClick(() => this.loadMore())
            }
          } else if (this.loading || this.errorMsg !== '') {
            StateView({ loading: this.loading, error: this.errorMsg, onRetry: () => this.refresh() })
          } else {
            StateView({ empty: true, emptyText: $r('app.string.issues_empty') })
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
