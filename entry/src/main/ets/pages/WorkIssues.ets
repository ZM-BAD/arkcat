/**
 * 工作区 Issue 列表页（Spec 017）：跨仓库 Issues（search type: ISSUE）。
 * 筛选行由 WorkFilterBar（Spec 017/018 共用）承载，此页只负责列表与查询；
 * 官方默认态 Open / Created by me / Show all / Sort: Newest 由组件与页面默认值共同保证。
 */
import { promptAction } from '@kit.ArkUI';
import { OctIcon } from '../components/OctIcon';
import { PageShadowBar } from '../components/PageShadowBar';
import { WorkFilterBar, WorkFilterOption, WorkFilterState, defaultWorkFilter } from '../components/WorkFilterBar';
import { WorkIssueItem, WorkIssuesPage, WorkLabel } from '../models/WorkModels';
import { WorkService } from '../services/WorkService';
import { StateView } from '../components/StateView';
import { ListLoadingFooter } from '../components/ListLoadingFooter';
import { WorkEmptyView } from '../components/WorkEmptyView';
import { githubShortTime, timeParts, TimeParts } from '../utils/Format';
import { resText } from '../utils/I18n';

@ComponentV2
export struct WorkIssuesView {
  @Param token: string = '';
  @Param pathStack: NavPathStack = new NavPathStack();
  /** 返回刷新 tick（review B13） */
  @Param returnTick: number = 0;
  @Local filterState: WorkFilterState = defaultWorkFilter();
  @Local issues: WorkIssueItem[] = [];
  @Local inSearch: boolean = false;
  @Local searchQuery: string = '';
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
    WorkService.fetchIssues(this.token,
      this.filterState.state, this.filterState.scope, this.filterState.visibility,
      this.filterState.sortKey, this.filterState.orgs, this.filterState.repos, '')
      .then((page: WorkIssuesPage) => {
        this.issues = page.issues;
        this.cursor = page.endCursor;
        this.hasNextPage = page.hasNextPage;
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
    WorkService.fetchIssues(this.token,
      this.filterState.state, this.filterState.scope, this.filterState.visibility,
      this.filterState.sortKey, this.filterState.orgs, this.filterState.repos, this.cursor)
      .then((page: WorkIssuesPage) => {
        this.issues = this.issues.concat(page.issues);
        this.cursor = page.endCursor;
        this.hasNextPage = page.hasNextPage;
        this.loading = false;
        this.loadingMore = false;
      })
      .catch((e: Error) => {
        this.errorMsg = e.message;
        this.loading = false;
        this.loadingMore = false;
      });
  }

  private onQueryChange(s: WorkFilterState): void {
    this.filterState = s;
    this.refresh();
  }

  private stringOf(res: Resource): string {
    return resText(this.getUIContext(), res);
  }

  /** 就地搜索：按标题/仓库全名过滤已加载列表（大小写不敏感） */
  private shownIssues(): WorkIssueItem[] {
    const q = this.searchQuery.trim().toLowerCase();
    if (q === '') {
      return this.issues;
    }
    return this.issues.filter((i: WorkIssueItem) =>
      i.title.toLowerCase().includes(q) || i.repoFullName.toLowerCase().includes(q));
  }

  private enterSearch(): void {
    this.inSearch = true;
    this.searchQuery = '';
    // 下一帧获焦，自动弹起软键盘
    setTimeout((): void => {
      this.getUIContext().getFocusController().requestFocus('work_issues_search');
    }, 60);
  }

  private exitSearch(): void {
    this.inSearch = false;
    this.searchQuery = '';
  }

  private stateOptions(): WorkFilterOption[] {
    return [
      { key: 'open', label: this.stringOf($r('app.string.issues_state_open')) },
      { key: 'closed', label: this.stringOf($r('app.string.issues_state_closed')) },
      { key: 'all', label: this.stringOf($r('app.string.work_filter_all')) }
    ];
  }

  private scopeOptions(): WorkFilterOption[] {
    return [
      { key: 'created', label: this.stringOf($r('app.string.issues_filter_scope_created')) },
      { key: 'assigned', label: this.stringOf($r('app.string.issues_filter_scope_assigned')) },
      { key: 'mentioned', label: this.stringOf($r('app.string.issues_filter_scope_mentioned')) },
      { key: 'involved', label: this.stringOf($r('app.string.issues_filter_scope_involved')) }
    ];
  }

  /** 相对时间结构化数据 → 当前语言文案 */
  private timeText(parts: TimeParts | null): string {
    return parts !== null ? githubShortTime(parts) : '';
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
  labelChip(label: WorkLabel) {
    Text(label.name)
      .fontSize(12)
      .fontColor(Color.White)
      .padding({ left: 8, right: 8, top: 2, bottom: 2 })
      .borderRadius(6)
      .backgroundColor(label.color !== '' ? `#${label.color}` : $r('app.color.text_secondary'))
      .margin({ right: 6 })
  }

  @Builder
  issueCard(issue: WorkIssueItem) {
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
        // 标签数量不定：包横向 Scroll 防溢出卡片，内层行 minWidth 撑满、超宽可滑
        Scroll() {
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
          .constraintSize({ minWidth: '100%' })
        }
        .scrollBar(BarState.Off)
        .width('100%')
      }
    }
    .padding($r('app.float.card_padding'))
    .borderRadius($r('app.float.card_radius'))
    .backgroundColor($r('app.color.card_background'))
    .width('100%')
    .margin({ bottom: 8 })
    .onClick(() => {
      // 与 WorkPrs 同款跳转（review B1：列表项此前漏 onClick 无法进详情）
      this.pathStack.pushPathByName('issueDetail', `${issue.repoFullName}/${issue.number}`);
    })
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
        if (this.inSearch) {
          TextInput({
            placeholder: this.stringOf($r('app.string.page_search_issues')),
            text: this.searchQuery
          })
            .id('work_issues_search')
            .layoutWeight(1)
            .height(44)
            .fontSize($r('app.float.title_font_size'))
            .fontColor($r('app.color.text_primary'))
            .caretColor($r('app.color.link_blue'))
            .backgroundColor(Color.Transparent)
            .onChange((v: string) => {
              this.searchQuery = v;
            })
        } else {
          Text($r('app.string.nav_issues_title'))
            .fontSize($r('app.float.title_font_size'))
            .fontWeight(600)
            .fontColor($r('app.color.text_primary'))
            .layoutWeight(1)
        }
        if (this.inSearch) {
          Stack() {
            OctIcon({ res: $r('app.media.oct_x_16'), iconSize: 18, iconColor: $r('app.color.text_secondary') })
          }
          .width(44)
          .height(44)
          .padding(6)
          .accessibilityDescription($r('app.string.a11y_close'))
          .focusable(true)
          .onClick((): void => this.exitSearch())
        } else {
          Stack() {
            OctIcon({
              res: $r('app.media.oct_search_24'),
              iconSize: 20,
              iconColor: $r('app.color.link_blue')
            })
          }
          .width(44)
          .height(44)
          .padding(6)
          .accessibilityDescription($r('app.string.a11y_search'))
          .focusable(true)
          .onClick((): void => this.enterSearch())
        }
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
        .padding(6)
        .accessibilityDescription($r('app.string.a11y_more'))
        .focusable(true)
        .bindMenu([
          {
            value: $r('app.string.inbox_menu_refresh'),
            action: (): void => this.refresh()
          }
        ])
      }
      .width('100%')
      .height(48)
      .padding({ left: 0, right: 0 })

      PageShadowBar({ show: this.scrollShadow })

      Refresh({ refreshing: $$this.isRefreshing }) {
      Scroll() {
        Column() {
          WorkFilterBar({
            token: this.token,
            stateOptions: this.stateOptions(),
            scopeOptions: this.scopeOptions(),
            onQueryChange: (s: WorkFilterState): void => this.onQueryChange(s)
          })

          if (this.shownIssues().length > 0) {
            ForEach(this.shownIssues(), (issue: WorkIssueItem) => {
              this.issueCard(issue)
            }, (issue: WorkIssueItem) => issue.id)
            if (this.hasNextPage) {
              ListLoadingFooter({ show: this.loadingMore })
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
            })
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
      .onScroll((_x: number, y: number): void => {
        this.scrollShadow = y > 0.001;
      })
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
