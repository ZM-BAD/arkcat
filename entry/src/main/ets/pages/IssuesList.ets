/**
 * 仓库内 Issue 列表页（Spec 007/026 修订 + Spec 063 顶栏改版）：官方布局对齐——
 * 顶栏两行标题（灰小字 owner/name + 粗体 Issues）+ 蓝色搜索（顶栏内联过滤，框内灰 ✕ 清除，返回键退出搜索）
 * + circle-plus 新建；四筛选（状态/Label/Author/Assignee）+ 行样式（状态圈/标题/#N/时间/💬/🔁）。
 * Author/Assignee 与搜索词均为客户端过滤（已加载集合），行点击进入 Issue 详情（Spec 030）。
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
  /** 顶栏内联搜索（Spec 063）：开启后标题区换成搜索框，列表按标题/编号本地过滤 */
  @Local searchOn: boolean = false;
  @Local searchQuery: string = '';
  /**
   * Author/Assignee 下拉候选池（只增不减）：二者已服务端筛选，若候选仍从当前结果聚合，
   * 选了一个人之后其他人就会从下拉里消失、无法直接切换 → 用会话内累积的池子维持候选完整度。
   */
  @Local authorPool: string[] = [];
  @Local assigneePool: string[] = [];

  private enterSearch(): void {
    this.searchOn = true;
    this.searchQuery = '';
    this.applyFilters();
    // 下一帧获焦，自动弹起软键盘
    setTimeout((): void => {
      this.getUIContext().getFocusController().requestFocus('issues_search');
    }, 60);
  }

  private exitSearch(): void {
    this.searchOn = false;
    this.searchQuery = '';
    this.applyFilters();
  }

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
    IssuesService.fetchRepoIssues(this.token, this.owner, this.name, this.state, this.label, '',
      this.author, this.assignee)
      .then((page: IssuesPage) => {
        this.all = page.issues;
        this.repoLabels = page.repoLabels;
        this.cursor = page.endCursor;
        this.hasNextPage = page.hasNextPage;
        this.absorbFilterPools(page.issues);
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
    IssuesService.fetchRepoIssues(this.token, this.owner, this.name, this.state, this.label, this.cursor,
        this.author, this.assignee)
      .then((page: IssuesPage) => {
        this.all = this.all.concat(page.issues);
        this.cursor = page.endCursor;
        this.hasNextPage = page.hasNextPage;
        this.absorbFilterPools(page.issues);
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

  /**
   * 客户端过滤：仅顶栏搜索词（Spec 063）。
   * Author/Assignee 自 2026-09-13 起走服务端 filterBy（createdBy/assignee），不再本地过滤。
   */
  private applyFilters(): void {
    const q = this.searchOn ? this.searchQuery.trim().toLowerCase() : '';
    const next: IssueSummary[] = [];
    for (const issue of this.all) {
      if (q !== '' && !this.matchQuery(issue, q)) {
        continue;
      }
      next.push(issue);
    }
    this.shown = next;
  }

  /** 搜索词匹配：标题子串，或「#123 / 123」按编号精确匹配 */
  private matchQuery(issue: IssueSummary, q: string): boolean {
    if (issue.title.toLowerCase().includes(q)) {
      return true;
    }
    const num = q.startsWith('#') ? q.substring(1) : q;
    return num !== '' && `${issue.number}` === num;
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
  /** 把本页出现的 author/assignee 并入候选池（会话内只增不减） */
  private absorbFilterPools(issues: IssueSummary[]): void {
    for (const issue of issues) {
      if (issue.authorLogin !== '' && this.authorPool.indexOf(issue.authorLogin) < 0) {
        this.authorPool = this.authorPool.concat([issue.authorLogin]);
      }
      for (const a of issue.assignees) {
        if (this.assigneePool.indexOf(a) < 0) {
          this.assigneePool = this.assigneePool.concat([a]);
        }
      }
    }
  }

  private authorFilterOptions(): FilterDropdownOption[] {
    const options: FilterDropdownOption[] = [];
    for (const login of this.authorPool) {
      options.push({ key: login, label: login });
    }
    return options;
  }

  /** Assignee 下拉选项（会话内出现过的分配人集合） */
  private assigneeFilterOptions(): FilterDropdownOption[] {
    const options: FilterDropdownOption[] = [];
    for (const login of this.assigneePool) {
      options.push({ key: login, label: login });
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

      // 标签数量不定：芯片组包横向 Scroll 防溢出卡片，时间锚定右侧不随滚动
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
      Row() {
        Stack() {
          OctIcon({ res: $r('app.media.oct_arrow_left_24'), iconSize: 20, iconColor: $r('app.color.text_primary') })
        }
.width(44)
.height(44)
        .accessibilityDescription(this.searchOn ? $r('app.string.a11y_close') : $r('app.string.a11y_back'))
        .focusable(true)
        .onClick(() => {
          // 搜索态下返回 = 退出搜索（回标题）；否则退出本页
          if (this.searchOn) {
            this.exitSearch();
            return;
          }
          this.pathStack.pop();
        })
        if (this.searchOn) {
          // 顶栏内联搜索（Spec 063）：标题区换成输入框，占位「Search Issues」
          TextInput({
            placeholder: this.stringOf($r('app.string.page_search_issues')),
            text: this.searchQuery
          })
            .id('issues_search')
            .height(44)
            .fontSize($r('app.float.title_font_size'))
            .fontColor($r('app.color.text_primary'))
            .caretColor($r('app.color.link_blue'))
            .backgroundColor(Color.Transparent)
            .onChange((v: string) => {
              this.searchQuery = v;
              this.applyFilters();
            })
            .layoutWeight(1)
          // 框内灰 ✕（有文字才显示）：只清空关键词、留在搜索态（与 Home 搜索页一致）
          if (this.searchQuery !== '') {
            Stack() {
              OctIcon({ res: $r('app.media.oct_x_16'), iconSize: 20, iconColor: $r('app.color.text_secondary') })
            }
.width(44)
.height(44)
            .accessibilityDescription($r('app.string.a11y_close'))
            .focusable(true)
            .onClick(() => {
              this.searchQuery = '';
              this.applyFilters();
            })
          }
        } else {
          Column({ space: 0 }) {
            Text(`${this.owner}/${this.name}`)
              .fontSize($r('app.float.caption_font_size'))
              .fontColor($r('app.color.text_secondary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text($r('app.string.repo_issues_link'))
              .fontSize($r('app.float.title_font_size'))
              .fontWeight(600)
              .fontColor($r('app.color.text_primary'))
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          // 🔍 仅未搜索态显示：进入搜索后让位给输入框（用户 2026-09-11 定案）
          Stack() {
            OctIcon({ res: $r('app.media.oct_search_24'), iconSize: 20, iconColor: $r('app.color.link_blue') })
          }
.width(44)
.height(44)
          .padding(6)
          .accessibilityDescription($r('app.string.a11y_search'))
          .focusable(true)
          .onClick(() => this.enterSearch())
        }
        Stack() {
          OctIcon({ res: $r('app.media.oct_plus_circle_24'), iconSize: 20, iconColor: $r('app.color.link_blue') })
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
      .height(48)
      .padding({ left: 4, right: 4 })

      PageShadowBar({ show: this.scrollShadow })

      Refresh({ refreshing: $$this.isRefreshing }) {
      Scroll() {
        Column() {
          Row() {
            // 漏斗徽标：激活筛选组数（工作区同款；无激活时隐藏；固定在筛选条最左、不随 chip 横向滚动）
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
              .height(32)
              .responseRegion({ x: 0, y: -6, width: '100%', height: '144%' })
              .padding({ left: 8, right: 8 })
              .borderRadius(16)
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

          // chips 滚动区：仅这一段随手指横向滑动
          Scroll() {
            Row() {
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
              onPick: (key: string): void => { this.author = this.author === key ? '' : key; this.refresh(); }
            })

            FilterDropdownChip({
              label: this.assignee === '' ? this.stringOf($r('app.string.repo_prs_assignee')) : this.assignee,
              active: this.assignee !== '',
              options: this.assigneeFilterOptions(),
              selectedKey: this.assignee,
              onPick: (key: string): void => { this.assignee = this.assignee === key ? '' : key; this.refresh(); }
            })
            }
          }
          .scrollable(ScrollDirection.Horizontal)
          .scrollBar(BarState.Off)
          .layoutWeight(1)
          .align(Alignment.Start)
          }
          .width('100%')
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
          } else if (this.searchOn && this.searchQuery.trim() !== '') {
            StateView({ empty: true, emptyText: $r('app.string.search_no_results') })
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
