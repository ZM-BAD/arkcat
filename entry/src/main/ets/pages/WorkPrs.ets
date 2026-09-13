/**
 * 工作区 PR 列表页（Spec 018）：跨仓库 Pull Requests（search type: PR）。
 * 筛选行由 WorkFilterBar（Spec 017/018 共用）承载：状态 5 项（Open/Merged/Closed/Queued/All）、
 * 归属 5 项（含 Review requested）；本页只负责列表、Checks 胶囊与查询。
 */
import { promptAction } from '@kit.ArkUI';
import { OctIcon } from '../components/OctIcon';
import { PageShadowBar } from '../components/PageShadowBar';
import { WorkFilterBar, WorkFilterOption, WorkFilterState, defaultWorkFilter } from '../components/WorkFilterBar';
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
    this.filterState = defaultWorkFilter();
    this.inSearch = false;
    this.searchQuery = '';
    this.refresh();
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

  /** PR 状态图标（Spec 024：merged 紫 / open 绿 / closed 灰 / draft 灰 draft 字形，review B9） */
  private prIcon(item: WorkPrItem): Resource {
    if (item.iconKey === 'merged') {
      return $r('app.media.oct_git_merge_16');
    }
    if (item.iconKey === 'draft') {
      return $r('app.media.oct_git_pull_request_draft_16');
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

  @Builder
  prCard(item: WorkPrItem) {
    Row({ space: 12 }) {
      OctIcon({ res: this.prIcon(item), iconSize: 18, iconColor: this.prColor(item) })
      Column({ space: 6 }) {
        Row() {
          Text(`${item.repoFullName} #${item.number}`)
            .fontSize($r('app.float.caption_font_size'))
            .fontColor($r('app.color.text_secondary'))
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
                .fontColor($r('app.color.text_primary'))
            }
            .padding({ left: 8, right: 8, top: 2, bottom: 2 })
            .borderRadius(12)
            .border({ width: 1, color: $r('app.color.divider') })
            .backgroundColor(Color.Transparent)
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
      .layoutWeight(1)
    }
    .alignItems(VerticalAlign.Top)
    .padding($r('app.float.card_padding'))
    .borderRadius($r('app.float.card_radius'))
    .backgroundColor($r('app.color.card_background'))
    .width('100%')
    .margin({ bottom: 8 })
    .onClick(() => {
      this.pathStack.pushPathByName('prDetail', `${item.repoFullName}/${item.number}`);
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
              subtitle: $r('app.string.work_use_fewer_filters'),
              button: $r('app.string.work_reset_all_filters'),
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
