/**
 * 仓库内 PR 列表页（Spec 027）：Repo Detail → PRs Tab。
 * 筛选：状态（All/Open/Closed/Merged）+ Label（GraphQL）+ Author/Assignee（客户端过滤）。
 */
import { promptAction } from '@kit.ArkUI';
import { OctIcon } from '../components/OctIcon';
import { RepoPrItem, RepoPrsPage, filterPrsByAuthor, filterPrsByAssignee, repoPrIconKey } from '../models/RepoSubModels';
import { WorkLabel } from '../models/WorkModels';
import { RepoSubService } from '../services/RepoSubService';
import { StateView } from '../components/StateView';
import { WorkEmptyView } from '../components/WorkEmptyView';
import { timeParts, TimeParts } from '../utils/Format';
import { resText } from '../utils/I18n';

@ComponentV2
export struct RepoPrsView {
  @Param owner: string = '';
  @Param name: string = '';
  @Param token: string = '';
  @Param pathStack: NavPathStack = new NavPathStack();
  @Local state: string = 'all';
  @Local label: string = '';
  @Local author: string = '';
  @Local assignee: string = '';
  @Local all: RepoPrItem[] = [];
  @Local shown: RepoPrItem[] = [];
  @Local labelOptions: string[] = [];
  @Local authorOptions: string[] = [];
  @Local assigneeOptions: string[] = [];
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
    RepoSubService.fetchRepoPrs(this.token, this.owner, this.name, this.state, this.label, '')
      .then((page: RepoPrsPage) => {
        this.all = page.prs;
        this.labelOptions = page.labelOptions;
        this.authorOptions = page.authorOptions;
        this.assigneeOptions = page.assigneeOptions;
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
    RepoSubService.fetchRepoPrs(this.token, this.owner, this.name, this.state, this.label, this.cursor)
      .then((page: RepoPrsPage) => {
        this.all = this.all.concat(page.prs);
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

  private applyFilters(): void {
    let list: RepoPrItem[] = filterPrsByAuthor(this.all, this.author);
    list = filterPrsByAssignee(list, this.assignee);
    this.shown = list;
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

  private prIcon(item: RepoPrItem): Resource {
    const key = repoPrIconKey(item.state, item.merged);
    if (key === 'merged') {
      return $r('app.media.oct_check_circle_fill_16');
    }
    return key === 'open' ? $r('app.media.oct_git_pull_request_16') : $r('app.media.oct_x_circle_16');
  }

  private prColor(item: RepoPrItem): ResourceColor {
    const key = repoPrIconKey(item.state, item.merged);
    if (key === 'merged') {
      return '#8250DF';
    }
    return key === 'open' ? '#2DA44E' : $r('app.color.text_tertiary');
  }

  private labelMenu(): MenuElement[] {
    const items: MenuElement[] = [];
    for (const l of this.labelOptions) {
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
    for (const a of this.authorOptions) {
      items.push({
        value: a,
        action: (): void => { this.author = this.author === a ? '' : a; this.applyFilters(); }
      });
    }
    return items;
  }

  private assigneeMenu(): MenuElement[] {
    const items: MenuElement[] = [];
    for (const a of this.assigneeOptions) {
      items.push({
        value: a,
        action: (): void => { this.assignee = this.assignee === a ? '' : a; this.applyFilters(); }
      });
    }
    return items;
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
  labelChip(label: WorkLabel) {
    Text(label.name)
      .fontSize(10)
      .fontColor(Color.White)
      .padding({ left: 8, right: 8, top: 2, bottom: 2 })
      .borderRadius(4)
      .backgroundColor(label.color !== '' ? label.color : '#57606A')
      .margin({ right: 6 })
  }

  @Builder
  prRow(item: RepoPrItem) {
    Column({ space: 6 }) {
      Row() {
        OctIcon({ res: this.prIcon(item), iconSize: 18, iconColor: this.prColor(item) })
        Text(item.title)
          .fontSize($r('app.float.body_font_size'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .margin({ left: 12 })
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        Text(`#${item.number}`)
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_secondary'))
          .margin({ left: 6 })
      }
      .width('100%')

      Row({ space: 8 }) {
        ForEach(item.labels, (label: WorkLabel) => {
          this.labelChip(label)
        }, (label: WorkLabel) => label.name)
        if (item.checksState === 'SUCCESS') {
          Row({ space: 4 }) {
            OctIcon({ res: $r('app.media.oct_check_16'), iconSize: 12, iconColor: $r('app.color.success_text') })
            Text(this.stringOf($r('app.string.work_pr_checks')))
              .fontSize($r('app.float.caption_font_size'))
              .fontColor($r('app.color.success_text'))
          }
          .padding({ left: 8, right: 8, top: 2, bottom: 2 })
          .borderRadius(10)
          .backgroundColor($r('app.color.checks_success_bg'))
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
          .backgroundColor($r('app.color.chip_bg'))
        }
        if (item.authorAvatar !== '') {
          Image(item.authorAvatar)
            .width(20)
            .height(20)
            .borderRadius(10)
            .backgroundColor($r('app.color.heat_empty'))
        }
        Blank()
        Text(this.timeText(timeParts(item.createdAt, Date.now())))
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
      this.pathStack.pushPathByName('prDetail', `${this.owner}/${this.name}/${item.number}`);
    })
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
        Column({ space: 0 }) {
          Text(this.owner)
            .fontSize($r('app.float.caption_font_size'))
            .fontColor($r('app.color.text_secondary'))
          Text($r('app.string.home_work_pull_requests'))
            .fontSize($r('app.float.title_font_size'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Stack() {
          OctIcon({ res: $r('app.media.oct_search_24'), iconSize: 20, iconColor: $r('app.color.text_primary') })
        }
        .padding(6)
        .onClick(() => {
          this.pathStack.pushPathByName('search', '');
        })
        Stack() {
          OctIcon({ res: $r('app.media.oct_plus_24'), iconSize: 20, iconColor: $r('app.color.link_blue') })
        }
        .padding(6)
        .onClick(() => {
          promptAction.showToast({ message: $r('app.string.home_feature_coming') });
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
                  .fontSize(8)
                  .fontColor(Color.White)
                  .margin({ top: -10, right: -3 })
              }
            }
            .margin({ right: 8 })

            this.filterChip(this.stateLabel(), [
              { value: this.stringOf($r('app.string.work_filter_all')), action: (): void => { this.state = 'all'; this.refresh(); } },
              { value: this.stringOf($r('app.string.issues_state_open')), action: (): void => { this.state = 'open'; this.refresh(); } },
              { value: this.stringOf($r('app.string.issues_state_closed')), action: (): void => { this.state = 'closed'; this.refresh(); } },
              { value: this.stringOf($r('app.string.pr_state_merged')), action: (): void => { this.state = 'merged'; this.refresh(); } }
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
            ForEach(this.shown, (item: RepoPrItem) => {
              this.prRow(item)
            }, (item: RepoPrItem) => item.id)
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
            WorkEmptyView({ iconText: '🐱', title: $r('app.string.repo_prs_empty') })
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
