/**
 * 仓库内 PR 列表页（Spec 027）：Repo Detail → PRs Tab。
 * 筛选：状态（All/Open/Closed/Merged）+ Label（GraphQL）+ Author/Assignee（客户端过滤）。
 */
import { promptAction } from '@kit.ArkUI';
import { AppBar, AppBarAction, AppBarActionCfg } from '../components/AppBar';
import { OctIcon } from '../components/OctIcon';
import { PageShadowBar } from '../components/PageShadowBar';
import { FilterDropdownChip, FilterDropdownOption } from '../components/FilterDropdownChip';
import { RepoPrItem, RepoPrsPage, filterPrsByAuthor, filterPrsByAssignee, repoPrIconKey } from '../models/RepoSubModels';
import { WorkLabel } from '../models/WorkModels';
import { RepoSubService } from '../services/RepoSubService';
import { StateView } from '../components/StateView';
import { ListLoadingFooter } from '../components/ListLoadingFooter';
import { WorkEmptyView } from '../components/WorkEmptyView';
import { githubShortTime, timeParts, TimeParts } from '../utils/Format';
import { resText } from '../utils/I18n';
import { shouldAutoLoadMore, isLimitedRangeEmpty } from '../utils/FilterLoading';

@ComponentV2
export struct RepoPrsView {
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
  @Local all: RepoPrItem[] = [];
  @Local shown: RepoPrItem[] = [];
  @Local labelOptions: string[] = [];
  @Local authorOptions: string[] = [];
  @Local assigneeOptions: string[] = [];
  @Local cursor: string = '';
  @Local hasNextPage: boolean = false;
  @Local loading: boolean = true;
  @Local errorMsg: string = '';
  /** 滚动顶部阴影（滚动中显示、回顶消失） */
  @Local scrollShadow: boolean = false;
  @Local isRefreshing: boolean = false;
  /** 触底加载更多（底部转圈指示） */
  @Local loadingMore: boolean = false;
  /** 空态自动补拉已用页数（author/assignee 为客户端过滤，防「假空」） */
  @Local extraPages: number = 0;

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
        this.isRefreshing = false;
        this.loadingMore = false;
        this.extraPages = 0;
        this.autoLoadIfEmpty();
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
    RepoSubService.fetchRepoPrs(this.token, this.owner, this.name, this.state, this.label, this.cursor)
      .then((page: RepoPrsPage) => {
        this.all = this.all.concat(page.prs);
        this.cursor = page.endCursor;
        this.hasNextPage = page.hasNextPage;
        this.applyFilters();
        this.loading = false;
        this.loadingMore = false;
        this.autoLoadIfEmpty();
      })
      .catch((e: Error) => {
        this.errorMsg = e.message;
        this.loading = false;
        this.loadingMore = false;
      });
  }

  /** 过滤后为空且还有下一页 → 自动补拉（上限 5 页），防「假空」 */
  private autoLoadIfEmpty(): void {
    if (shouldAutoLoadMore(this.shown.length, this.hasNextPage, this.extraPages)) {
      this.extraPages += 1;
      this.loadMore();
    }
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
    return parts !== null ? githubShortTime(parts) : '';
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
    const key = repoPrIconKey(item.state, item.merged, item.isDraft);
    if (key === 'merged') {
      return $r('app.media.oct_git_merge_16');
    }
    if (key === 'draft') {
      return $r('app.media.oct_git_pull_request_draft_16');
    }
    return key === 'open' ? $r('app.media.oct_git_pull_request_16') : $r('app.media.oct_x_circle_16');
  }

  private prColor(item: RepoPrItem): ResourceColor {
    const key = repoPrIconKey(item.state, item.merged, item.isDraft);
    if (key === 'merged') {
      return $r('app.color.shortcut_purple_fg');
    }
    // draft 官方为灰色调（review B9）
    return key === 'open' ? $r('app.color.success_text')
      : (key === 'draft' ? $r('app.color.text_secondary') : $r('app.color.text_tertiary'));
  }

  private stateFilterOptions(): FilterDropdownOption[] {
    return [
      { key: 'all', label: this.stringOf($r('app.string.work_filter_all')) },
      { key: 'open', label: this.stringOf($r('app.string.issues_state_open')) },
      { key: 'closed', label: this.stringOf($r('app.string.issues_state_closed')) },
      { key: 'merged', label: this.stringOf($r('app.string.pr_state_merged')) }
    ];
  }

  /** Label 下拉选项（仓库标签全集） */
  private labelFilterOptions(): FilterDropdownOption[] {
    return this.labelOptions.map((l: string): FilterDropdownOption => ({ key: l, label: l }));
  }

  /** Author 下拉选项 */
  private authorFilterOptions(): FilterDropdownOption[] {
    return this.authorOptions.map((a: string): FilterDropdownOption => ({ key: a, label: a }));
  }

  /** Assignee 下拉选项 */
  private assigneeFilterOptions(): FilterDropdownOption[] {
    return this.assigneeOptions.map((a: string): FilterDropdownOption => ({ key: a, label: a }));
  }

  /** 清空全部筛选（漏斗菜单） */
  private clearAllFilters(): void {
    this.state = 'all';
    this.label = '';
    this.author = '';
    this.assignee = '';
    this.refresh();
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
  prRow(item: RepoPrItem) {
    Row({ space: 12 }) {
      OctIcon({ res: this.prIcon(item), iconSize: 18, iconColor: this.prColor(item) })
      Column({ space: 6 }) {
        Row() {
          Text(item.title)
            .fontSize($r('app.float.body_font_size'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          Text(`#${item.number}`)
            .fontSize($r('app.float.caption_font_size'))
            .fontColor($r('app.color.text_secondary'))
            .margin({ left: 8 })
        }
        .width('100%')

        // 标签数量不定：芯片组包横向 Scroll 防溢出卡片，头像/时间锚定右侧不随滚动
        Row({ space: 8 }) {
          Scroll() {
            Row({ space: 8 }) {
              ForEach(item.labels, (label: WorkLabel) => {
                this.labelChip(label)
              }, (label: WorkLabel) => label.name)
              if (item.checksState === 'SUCCESS') {
                Row({ space: 4 }) {
                  OctIcon({ res: $r('app.media.oct_check_16'), iconSize: 12, iconColor: $r('app.color.success_text') })
                  Text(this.stringOf($r('app.string.work_pr_checks')))
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
            }
            .constraintSize({ minWidth: '100%' })
          }
          .scrollBar(BarState.Off)
          .layoutWeight(1)
          if (item.authorAvatar !== '') {
            Image(item.authorAvatar)
              .width(20)
              .height(20)
              .borderRadius(12)
              .backgroundColor($r('app.color.heat_empty'))
          }
          Text(this.timeText(timeParts(item.createdAt, Date.now())))
            .fontSize($r('app.float.caption_font_size'))
            .fontColor($r('app.color.text_secondary'))
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
      this.pathStack.pushPathByName('prDetail', `${this.owner}/${this.name}/${item.number}`);
    })
  }

  build() {
    Column() {
      // 两行头部：owner（灰小字·上）+ Pull requests（黑粗体·下）→ subtitleAbove
      AppBar({
        showBack: true,
        title: $r('app.string.home_work_pull_requests'),
        subtitle: this.owner,
        subtitleAbove: true,
        onBack: (): void => {
          this.pathStack.pop();
        },
        actions: [
          new AppBarAction($r('app.media.oct_search_24'), (): void => {
            this.pathStack.pushPathByName('search', '');
          }, { iconColor: $r('app.color.text_primary'), a11y: $r('app.string.a11y_search') }),
          new AppBarAction($r('app.media.oct_plus_24'), (): void => {
            promptAction.showToast({ message: $r('app.string.home_feature_coming') });
          }, { iconColor: $r('app.color.link_blue'), a11y: $r('app.string.a11y_new') })
        ]
      })

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
            .layoutWeight(1)
            .align(Alignment.Start)
          }
          .width('100%')
          .margin({ bottom: 12 })

          if (this.shown.length > 0) {
            ForEach(this.shown, (item: RepoPrItem) => {
              this.prRow(item)
            }, (item: RepoPrItem) => item.id)
            if (this.hasNextPage) {
              ListLoadingFooter({ show: this.loadingMore })
            }
          } else if (this.loading || this.errorMsg !== '') {
            StateView({ loading: this.loading, error: this.errorMsg, onRetry: () => this.refresh() })
          } else {
            WorkEmptyView({
              iconText: '🐱',
              title: $r('app.string.repo_prs_empty'),
              subtitle: isLimitedRangeEmpty(this.shown.length, this.hasNextPage)
                ? $r('app.string.filter_loaded_range_hint') : null
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
