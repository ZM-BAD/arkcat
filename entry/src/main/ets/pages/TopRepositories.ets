/**
 * 工作区 Top Repositories 页（Spec 021）：viewer 仓库按 PUSHED_AT 降序。
 * 官方仓库筛选下拉 8 项（All/Archived/Fork/Mirror/Private/Public/Source/Template）客户端过滤；
 * 行结构：owner 头像 + owner（灰小字）/ 仓库名（黑大字）；点击进入仓库详情。
 */
import { WorkTopRepoItem, WorkTopReposPage, filterTopRepos } from '../models/WorkModels';
import { FilterDropdownChip, FilterDropdownOption } from '../components/FilterDropdownChip';
import { OctIcon } from '../components/OctIcon';
import { WorkService } from '../services/WorkService';
import { StateView } from '../components/StateView';
import { WorkEmptyView } from '../components/WorkEmptyView';
import { ListLoadingFooter } from '../components/ListLoadingFooter';
import { AppBar, AppBarAction, AppBarActionCfg } from '../components/AppBar';
import { PageShadowBar } from '../components/PageShadowBar';
import { resText } from '../utils/I18n';
import { shouldAutoLoadMore, isLimitedRangeEmpty } from '../utils/FilterLoading';

@ComponentV2
export struct TopRepositoriesView {
  @Param token: string = '';
  @Param pathStack: NavPathStack = new NavPathStack();
  /** 官方 8 项仓库筛选维度（all/archived/fork/mirror/private/public/source/template） */
  @Local filterKey: string = 'all';
  @Local repos: WorkTopRepoItem[] = [];
  @Local cursor: string = '';
  @Local hasNextPage: boolean = false;
  @Local loading: boolean = true;
  @Local errorMsg: string = '';
  /** 滚动顶部阴影（滚动中显示、回顶消失） */
  @Local scrollShadow: boolean = false;
  @Local isRefreshing: boolean = false;
  /** 触底加载更多（底部转圈指示） */
  @Local loadingMore: boolean = false;
  /** 空态自动补拉已用页数（客户端过滤页防「假空」，上限 AUTO_LOAD_MAX_EXTRA_PAGES） */
  @Local extraPages: number = 0;

  aboutToAppear(): void {
    this.refresh();
  }

  private refresh(): void {
    this.loading = true;
    this.errorMsg = '';
    // Type 的可下推项走服务端（mirror/template 仍在客户端兜底过滤）
    WorkService.fetchTopRepositories(this.token, '', this.filterKey)
      .then((page: WorkTopReposPage) => {
        this.repos = page.repos;
        this.cursor = page.endCursor;
        this.hasNextPage = page.hasNextPage;
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
    WorkService.fetchTopRepositories(this.token, this.cursor, this.filterKey)
      .then((page: WorkTopReposPage) => {
        this.repos = this.repos.concat(page.repos);
        this.cursor = page.endCursor;
        this.hasNextPage = page.hasNextPage;
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

  private stringOf(res: Resource): string {
    return resText(this.getUIContext(), res);
  }

  private filterOptions(): FilterDropdownOption[] {
    return [
      { key: 'all', label: this.stringOf($r('app.string.repos_filter_all')) },
      { key: 'archived', label: this.stringOf($r('app.string.repos_filter_archived')) },
      { key: 'fork', label: this.stringOf($r('app.string.repos_filter_fork')) },
      { key: 'mirror', label: this.stringOf($r('app.string.repos_filter_mirror')) },
      { key: 'private', label: this.stringOf($r('app.string.repos_filter_private')) },
      { key: 'public', label: this.stringOf($r('app.string.repos_filter_public')) },
      { key: 'source', label: this.stringOf($r('app.string.repos_filter_source')) },
      { key: 'template', label: this.stringOf($r('app.string.repos_filter_template')) }
    ];
  }

  private filterLabel(): string {
    for (const opt of this.filterOptions()) {
      if (opt.key === this.filterKey) {
        return opt.label;
      }
    }
    return this.stringOf($r('app.string.repos_filter_all'));
  }

  /** 漏斗徽标计数：Type 非 All 计 1（全库口径：dirty=非默认值） */
  private activeFilterCount(): number {
    return this.filterKey !== 'all' ? 1 : 0;
  }

  /** 漏斗菜单 Clear all filters：全部回默认并重查 */
  private clearAllFilters(): void {
    if (this.filterKey === 'all') {
      return;
    }
    this.filterKey = 'all';
    this.refresh();
  }

  /** 空态 RESET ALL FILTERS 门控：仅存在 dirty 筛选且列表为空时显示（全库口径，点击=Clear all filters 同函数） */
  private canResetFilters(): boolean {
    return this.activeFilterCount() > 0;
  }

  /** 8 项筛选维度客户端过滤（已拉取集合内；服务端已下推的项在此幂等复核） */
  private visibleRepos(): WorkTopRepoItem[] {
    return filterTopRepos(this.repos, this.filterKey);
  }

  /** 过滤后为空且还有下一页 → 自动补拉（上限 AUTO_LOAD_MAX_EXTRA_PAGES 页），防「假空」 */
  private autoLoadIfEmpty(): void {
    if (shouldAutoLoadMore(this.visibleRepos().length, this.hasNextPage, this.extraPages)) {
      this.extraPages += 1;
      this.loadMore();
    }
  }

  @Builder
  repoRow(repo: WorkTopRepoItem) {
    Row({ space: 20 }) {
      if (repo.ownerAvatar !== '') {
        Image(repo.ownerAvatar)
          .width(34)
          .height(34)
          .borderRadius(17)
          .backgroundColor($r('app.color.heat_empty'))
      } else {
        Text('◯')
          .fontSize($r('app.float.title_font_size'))
          .width(34)
          .height(34)
          .borderRadius(17)
          .textAlign(TextAlign.Center)
          .backgroundColor($r('app.color.heat_empty'))
      }
      Column({ space: 3 }) {
        Text(repo.ownerLogin)
          .fontSize($r('app.float.body_font_size'))
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
        Text(repo.name)
          .fontSize($r('app.float.menu_font_size'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height(73)
    .padding({ left: 16, right: 16 })
    .onClick(() => {
      this.pathStack.pushPathByName('repoDetail', `${repo.ownerLogin}/${repo.name}`);
    })
  }

  build() {
    Column() {
      AppBar({
        showBack: true,
        title: $r('app.string.nav_top_repos_title'),
        onBack: (): void => {
          this.pathStack.pop();
        },
        actions: [
          new AppBarAction($r('app.media.oct_search_24'), (): void => {
            this.pathStack.pushPathByName('search', '');
          }, { iconColor: $r('app.color.text_primary'), a11y: $r('app.string.a11y_search') })
        ]
      })

      PageShadowBar({ show: this.scrollShadow })

      Refresh({ refreshing: $$this.isRefreshing }) {
      Scroll() {
        Column() {
          Row() {
            // 漏斗徽标：激活筛选组数（全库同款；无激活时隐藏；固定在筛选条最左、不随 chip 横向滚动）
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
                  value: $r('app.string.work_clear_all_filters'),
                  action: (): void => this.clearAllFilters()
                }
              ])
            }

            // chips 滚动区：仅这一段随手指横向滑动
            Scroll() {
              Row() {
                FilterDropdownChip({
                  label: this.filterLabel(),
                  active: this.filterKey !== 'all',
                  options: this.filterOptions(),
                  selectedKey: this.filterKey,
                  onPick: (key: string): void => {
                    if (this.filterKey !== key) {
                      this.filterKey = key;
                      this.refresh();
                    }
                  }
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
          if (this.visibleRepos().length > 0) {
            ForEach(this.visibleRepos(), (repo: WorkTopRepoItem) => {
              this.repoRow(repo)
            }, (repo: WorkTopRepoItem) => repo.id)
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
              title: $r('app.string.work_top_repos_empty'),
              subtitle: isLimitedRangeEmpty(this.visibleRepos().length, this.hasNextPage)
                ? $r('app.string.filter_loaded_range_hint') : null,
              button: this.canResetFilters() ? $r('app.string.work_reset_all_filters') : null,
              onButton: (): void => this.clearAllFilters()
            })
          }
        }
        .padding({ left: 16, right: 16, bottom: 16 })
        .width('100%')
        .alignItems(HorizontalAlign.Start)
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
