/**
 * 工作区 PR 列表页（Spec 018）：跨仓库 Pull Requests（search type: PR）。
 * 筛选行由 WorkFilterBar（Spec 017/018 共用）承载：状态 5 项（Open/Merged/Closed/Queued/All）、
 * 归属 5 项（含 Review requested）；本页只负责列表、Checks 胶囊与查询。
 */
import { promptAction } from '@kit.ArkUI';
import { OctIcon } from '../components/OctIcon';
import { PullRequestCard } from '../components/PullRequestCard';
import { PageShadowBar } from '../components/PageShadowBar';
import { WorkFilterBar, WorkFilterOption, WorkFilterState, defaultWorkFilter, isWorkFilterDirty } from '../components/WorkFilterBar';
import { WorkPrItem, WorkPrsPage } from '../models/WorkModels';
import { WorkService } from '../services/WorkService';
import { StateView } from '../components/StateView';
import { ListLoadingFooter } from '../components/ListLoadingFooter';
import { WorkEmptyView } from '../components/WorkEmptyView';
import { githubShortTime, timeParts, TimeParts } from '../utils/Format';
import { resText } from '../utils/I18n';

@ComponentV2
export struct WorkPrsView {
  @Param token: string = '';
  @Param pathStack: NavPathStack = new NavPathStack();
  /** 返回刷新 tick（review B13） */
  @Param returnTick: number = 0;
  @Local filterState: WorkFilterState = defaultWorkFilter();
  /** 空态 RESET ALL FILTERS 的复位信号（递增即触发 WorkFilterBar 内部复位） */
  @Local resetTick: number = 0;
  @Local prs: WorkPrItem[] = [];
  @Local cursor: string = '';
  @Local hasNextPage: boolean = false;
  @Local inSearch: boolean = false;
  @Local searchQuery: string = '';
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

  /** 空态「RESET ALL FILTERS」：恢复默认筛选 + 退出就地搜索后重查（Spec 018 元素 14） */
  private resetFilters(): void {
    // 与漏斗菜单 Clear all filters 完全同口径：由 WorkFilterBar 内部复位并 emitChange（同时不动页内搜索）；
    // 页面不能直接改 filterState —— 那只会改快照，chip/漏斗图标不会复位
    this.resetTick += 1;
  }

  /** 空态是否显示重置入口：只看筛选是否偏离默认（页内搜索不计入，与徽标口径一致） */
  private canResetFilters(): boolean {
    return isWorkFilterDirty(this.filterState);
  }

  private refresh(): void {
    this.loading = true;
    this.errorMsg = '';
    WorkService.fetchPrs(this.token,
      this.filterState.state, this.filterState.scope, this.filterState.visibility,
      this.filterState.sortKey, this.filterState.orgs, this.filterState.repos, '')
      .then((page: WorkPrsPage) => {
        this.prs = page.prs;
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
    WorkService.fetchPrs(this.token,
      this.filterState.state, this.filterState.scope, this.filterState.visibility,
      this.filterState.sortKey, this.filterState.orgs, this.filterState.repos, this.cursor)
      .then((page: WorkPrsPage) => {
        this.prs = this.prs.concat(page.prs);
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
  private shownPrs(): WorkPrItem[] {
    const q = this.searchQuery.trim().toLowerCase();
    if (q === '') {
      return this.prs;
    }
    return this.prs.filter((it: WorkPrItem) =>
      it.title.toLowerCase().includes(q) || it.repoFullName.toLowerCase().includes(q));
  }

  private enterSearch(): void {
    this.inSearch = true;
    this.searchQuery = '';
    // 下一帧获焦，自动弹起软键盘
    setTimeout((): void => {
      this.getUIContext().getFocusController().requestFocus('work_prs_search');
    }, 60);
  }

  private exitSearch(): void {
    this.inSearch = false;
    this.searchQuery = '';
  }

  /** 相对时间结构化数据 → 当前语言文案 */
  private timeText(parts: TimeParts | null): string {
    return parts !== null ? githubShortTime(parts) : '';
  }

  private stateOptions(): WorkFilterOption[] {
    return [
      { key: 'open', label: this.stringOf($r('app.string.issues_state_open')) },
      { key: 'merged', label: this.stringOf($r('app.string.pr_state_merged')) },
      { key: 'closed', label: this.stringOf($r('app.string.issues_state_closed')) },
      { key: 'queued', label: this.stringOf($r('app.string.pr_filter_queued')) },
      { key: 'all', label: this.stringOf($r('app.string.work_filter_all')) }
    ];
  }

  private scopeOptions(): WorkFilterOption[] {
    return [
      { key: 'created', label: this.stringOf($r('app.string.issues_filter_scope_created')) },
      { key: 'assigned', label: this.stringOf($r('app.string.issues_filter_scope_assigned')) },
      { key: 'mentioned', label: this.stringOf($r('app.string.issues_filter_scope_mentioned')) },
      { key: 'review_requested', label: this.stringOf($r('app.string.pr_filter_scope_review_requested')) },
      { key: 'involved', label: this.stringOf($r('app.string.issues_filter_scope_involved')) }
    ];
  }

  /** PR 状态图标（DESIGN.md §10.1：merged 紫 / open 绿 / closed 红 git-pull-request-closed / draft 灰） */
  private prIcon(item: WorkPrItem): Resource {
    if (item.iconKey === 'merged') {
      return $r('app.media.oct_git_merge_16');
    }
    if (item.iconKey === 'draft') {
      return $r('app.media.oct_git_pull_request_draft_16');
    }
    return item.iconKey === 'open' ? $r('app.media.oct_git_pull_request_16') : $r('app.media.oct_git_pull_request_closed_16');
  }

  private prColor(item: WorkPrItem): ResourceColor {
    if (item.iconKey === 'merged') {
      return $r('app.color.shortcut_purple_fg');
    }
    // 官方语义：open=success 绿 / draft=muted 灰 / closed=danger 红
    if (item.iconKey === 'open') {
      return $r('app.color.success_text');
    }
    return item.iconKey === 'draft' ? $r('app.color.text_secondary') : $r('app.color.danger_text');
  }


  @Builder
  prCard(item: WorkPrItem) {
    PullRequestCard({
      iconRes: this.prIcon(item),
      iconColor: this.prColor(item),
      title: item.title,
      number: item.number,
      repoLine: item.repoFullName,
      timeText: this.timeText(timeParts(item.createdAt, Date.now())),
      commentCount: item.commentCount,
      reviewCount: item.reviewCount,
      checksState: item.checksState,
      onOpen: (): void => {
        this.pathStack.pushPathByName('prDetail', `${item.repoFullName}/${item.number}`);
      }
    })
  }

  build() {
    Column() {
      Row() {
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
            placeholder: this.stringOf($r('app.string.page_search_prs')),
            text: this.searchQuery
          })
            .id('work_prs_search')
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
          Text($r('app.string.home_work_pull_requests'))
            .fontSize($r('app.float.title_font_size'))
            .fontWeight(600)
            .fontColor($r('app.color.text_primary'))
            .layoutWeight(1)
        }
        if (this.inSearch) {
          Stack() {
            OctIcon({ res: $r('app.media.oct_x_16'), iconSize: 20, iconColor: $r('app.color.text_secondary') })
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
            iconSize: 20,
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
      .padding({ left: 4, right: 4 })

      PageShadowBar({ show: this.scrollShadow })

      Refresh({ refreshing: $$this.isRefreshing }) {
      Scroll() {
        Column() {
          WorkFilterBar({
            token: this.token,
            resetTick: this.resetTick,
            stateOptions: this.stateOptions(),
            scopeOptions: this.scopeOptions(),
            onQueryChange: (s: WorkFilterState): void => this.onQueryChange(s)
          })

          if (this.shownPrs().length > 0) {
            ForEach(this.shownPrs(), (item: WorkPrItem) => {
              this.prCard(item)
            }, (item: WorkPrItem) => item.id)
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
              title: $r('app.string.work_prs_empty'),
              // 无筛选可重置时不显示「减少筛选」提示与 RESET ALL FILTERS（刚进页即空列表的场景）
              subtitle: this.canResetFilters() ? $r('app.string.work_use_fewer_filters') : null,
              button: this.canResetFilters() ? $r('app.string.work_reset_all_filters') : null,
              onButton: () => this.resetFilters()
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
