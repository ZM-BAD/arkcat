/**
 * 仓库内 Issue 列表页（Spec 007/026 修订）：官方布局对齐——
 * 副标题 owner + 四筛选（状态/Label/Author/Assignee）+ 行样式（状态圈/标题/#N/时间/💬/🔁）。
 * Author/Assignee 为客户端过滤（首屏集合），行点击进入 Issue 详情（Spec 030）。
 */
import { promptAction } from '@kit.ArkUI';
import { OctIcon } from '../components/OctIcon';
import { FilterDropdownChip, FilterDropdownOption } from '../components/FilterDropdownChip';
import { PageShadowBar } from '../components/PageShadowBar';
import { IssueSummary, IssuesPage } from '../models/IssuesModels';
import { IssuesService } from '../services/IssuesService';
import { StateView } from '../components/StateView';
import { ListLoadingFooter } from '../components/ListLoadingFooter';
import { githubShortTime, timeParts, TimeParts } from '../utils/Format';
import { resText } from '../utils/I18n';

@ComponentV2
export struct IssuesListView {
  @Param owner: string = '';
  @Param name: string = '';
  @Param token: string = '';
  @Param pathStack: NavPathStack = new NavPathStack();
  /** 返回刷新 tick（review B13） */
  @Param returnTick: number = 0;
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
  /** 滚动顶部阴影（滚动中显示、回顶消失） */
  @Local scrollShadow: boolean = false;
  @Local isRefreshing: boolean = false;
  /** 触底加载更多（底部转圈指示） */
  @Local loadingMore: boolean = false;

  /** 返回刷新（review B13） */
  @Monitor('returnTick')
  onReturnTick(): void {
    this.refresh();
  }

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
        this.isRefreshing = false;
        this.loadingMore = false;
      })
      .catch((e: Error) => {
        this.errorMsg = e.message;
        this.loading = false;
        this.isRefreshing = false;
        this.loadingMore = false;
      });
  }

  private loadMore(): void {
    if (!this.hasNextPage || this.loading || this.loadingMore) {
      return;
    }
    this.loading = true;
    this.loadingMore = true;
    IssuesService.fetchRepoIssues(this.token, this.owner, this.name, this.state, this.label, this.cursor)
      .then((page: IssuesPage) => {
        this.all = this.all.concat(page.issues);
        this.cursor = page.endCursor;
        this.hasNextPage = page.hasNextPage;
        this.applyFilters();
        this.loading = false;
        this.loadingMore = false;
      })
      .catch((e: Error) => {
        this.errorMsg = e.message;
        this.loading = false;
        this.loadingMore = false;
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

  /** State 下拉选项（All/Open/Closed） */
  private stateFilterOptions(): FilterDropdownOption[] {
    return [
      { key: 'all', label: this.stringOf($r('app.string.work_filter_all')) },
      { key: 'open', label: this.stringOf($r('app.string.issues_state_open')) },
      { key: 'closed', label: this.stringOf($r('app.string.issues_state_closed')) }
    ];
  }

  /** Label 下拉选项（仓库标签全集） */
  private labelFilterOptions(): FilterDropdownOption[] {
    const opts: FilterDropdownOption[] = [];
    for (const l of this.repoLabels) {
      opts.push({ key: l, label: l });
    }
    return opts;
  }

  /** Author 下拉选项（首屏作者集合） */
  private authorFilterOptions(): FilterDropdownOption[] {
    const seen: Set<string> = new Set();
    const options: FilterDropdownOption[] = [];
    for (const issue of this.all) {
      if (issue.authorLogin !== '' && !seen.has(issue.authorLogin)) {
        seen.add(issue.authorLogin);
        options.push({ key: issue.authorLogin, label: issue.authorLogin });
      }
    }
    return options;
  }

  /** Assignee 下拉选项（首屏分配人集合） */
  private assigneeFilterOptions(): FilterDropdownOption[] {
    const seen: Set<string> = new Set();
    const options: FilterDropdownOption[] = [];
    for (const issue of this.all) {
      for (const a of issue.assignees) {
        if (!seen.has(a)) {
          seen.add(a);
          options.push({ key: a, label: a });
        }
      }
    }
    return options;
  }

  /** 清空全部筛选（漏斗菜单） */
  private clearAllFilters(): void {
    this.state = 'all';
    this.label = '';
    this.author = '';
    this.assignee = '';
    this.refresh();
  }

  private stringOf(res: Resource): string {
    return resText(this.getUIContext(), res);
  }

  private timeText(parts: TimeParts | null): string {
    return parts !== null ? githubShortTime(parts) : '';
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
  labelChip(label: string) {
    Text(label)
      .fontSize(12)
      .fontColor(Color.White)
      .padding({ left: 8, right: 8, top: 2, bottom: 2 })
      .borderRadius(6)
      .backgroundColor($r('app.color.text_secondary'))
      .margin({ right: 6 })
  }

  /** 打开 Issue 详情（标题行与 meta 行的可点区域共用） */
  private openIssue(issue: IssueSummary): void {
    this.pathStack.pushPathByName('issueDetail', `${this.owner}/${this.name}/${issue.number}`);
  }

  @Builder
  issueCard(issue: IssueSummary) {
    // 可点区域拆为同层兄弟：作者单元格 → Profile，标题行/其余 meta → 详情。
    // 规避 ClickEvent 无 stopPropagation 的冒泡误触（沿 010 批定案拆分模式）。
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
      .onClick(() => this.openIssue(issue))

      // 标签数量不定：芯片组包横向 Scroll 防溢出卡片，时间锚定右侧不随滚动
      Row({ space: 8 }) {
        if (issue.authorLogin !== '') {
          Text(`@${issue.authorLogin}`)
            .fontSize($r('app.float.caption_font_size'))
            .fontColor($r('app.color.text_secondary'))
            .onClick(() => {
              this.pathStack.pushPathByName('userProfile', issue.authorLogin);
            })
        }
        Row({ space: 8 }) {
          Scroll() {
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
            }
            .constraintSize({ minWidth: '100%' })
          }
          .scrollBar(BarState.Off)
          .layoutWeight(1)
          Text(this.timeText(timeParts(issue.createdAt, Date.now())))
            .fontSize($r('app.float.caption_font_size'))
            .fontColor($r('app.color.text_secondary'))
        }
        .layoutWeight(1)
        .onClick(() => this.openIssue(issue))
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
            .fontWeight(600)
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
      .padding({ left: 0, right: 0 })

      PageShadowBar({ show: this.scrollShadow })

      Refresh({ refreshing: $$this.isRefreshing }) {
      Scroll() {
        Column() {
          Scroll() {
          Row() {
            // 漏斗徽标：激活筛选组数（工作区同款；无激活时隐藏）
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
              .height(38)
              .padding({ left: 10, right: 12 })
              .borderRadius(19)
              .backgroundColor($r('app.color.chip_bg'))
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
                  action: (): void => this.clearAllFilters()
                }
              ])
            }

            FilterDropdownChip({
              label: this.stateLabel(),
              active: this.state !== 'all',
              options: this.stateFilterOptions(),
              selectedKey: this.state,
              onPick: (key: string): void => { this.state = key; this.refresh(); }
            })

            FilterDropdownChip({
              label: this.label === '' ? this.stringOf($r('app.string.repo_prs_label')) : this.label,
              active: this.label !== '',
              options: this.labelFilterOptions(),
              selectedKey: this.label,
              onPick: (key: string): void => { this.label = this.label === key ? '' : key; this.refresh(); }
            })

            FilterDropdownChip({
              label: this.author === '' ? this.stringOf($r('app.string.repo_prs_author')) : this.author,
              active: this.author !== '',
              options: this.authorFilterOptions(),
              selectedKey: this.author,
              onPick: (key: string): void => { this.author = this.author === key ? '' : key; this.applyFilters(); }
            })

            FilterDropdownChip({
              label: this.assignee === '' ? this.stringOf($r('app.string.repo_prs_assignee')) : this.assignee,
              active: this.assignee !== '',
              options: this.assigneeFilterOptions(),
              selectedKey: this.assignee,
              onPick: (key: string): void => { this.assignee = this.assignee === key ? '' : key; this.applyFilters(); }
            })
          }
          }
          .scrollable(ScrollDirection.Horizontal)
          .scrollBar(BarState.Off)
          .margin({ bottom: 12 })

          if (this.shown.length > 0) {
            ForEach(this.shown, (issue: IssueSummary) => {
              this.issueCard(issue)
            }, (issue: IssueSummary) => issue.id)
            if (this.hasNextPage) {
              ListLoadingFooter({ show: this.loadingMore })
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
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
      .onReachEnd((): void => {
        this.loadMore();
      })
      .onScroll((_x: number, y: number): void => { this.scrollShadow = y > 0.001; })
      }
      .layoutWeight(1)
      .onRefreshing((): void => {
        this.isRefreshing = true;
        this.refresh();
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_page'))
  }
}
