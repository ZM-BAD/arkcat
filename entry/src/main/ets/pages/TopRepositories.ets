/**
 * 工作区 Top Repositories 页（Spec 021）：viewer 仓库按 PUSHED_AT 降序。
 * 官方仓库筛选下拉 8 项（All/Archived/Fork/Mirror/Private/Public/Source/Template）客户端过滤；
 * 行结构：owner 头像 + owner（灰小字）/ 仓库名（黑大字）；点击进入仓库详情。
 */
import { WorkTopRepoItem, WorkTopReposPage, filterTopRepos } from '../models/WorkModels';
import { FilterDropdownChip, FilterDropdownOption } from '../components/FilterDropdownChip';
import { WorkService } from '../services/WorkService';
import { StateView } from '../components/StateView';
import { ListLoadingFooter } from '../components/ListLoadingFooter';
import { AppBar, AppBarAction, AppBarActionCfg } from '../components/AppBar';
import { PageShadowBar } from '../components/PageShadowBar';
import { resText } from '../utils/I18n';

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

  aboutToAppear(): void {
    this.refresh();
  }

  private refresh(): void {
    this.loading = true;
    this.errorMsg = '';
    WorkService.fetchTopRepositories(this.token, '')
      .then((page: WorkTopReposPage) => {
        this.repos = page.repos;
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
    WorkService.fetchTopRepositories(this.token, this.cursor)
      .then((page: WorkTopReposPage) => {
        this.repos = this.repos.concat(page.repos);
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

  private stringOf(res: Resource): string {
    return resText(this.getUIContext(), res);
  }

  private filterOptions(): FilterDropdownOption[] {
    return [
      { key: 'all', label: this.stringOf($r('app.string.toprepos_filter_all')) },
      { key: 'archived', label: this.stringOf($r('app.string.toprepos_filter_archived')) },
      { key: 'fork', label: this.stringOf($r('app.string.toprepos_filter_fork')) },
      { key: 'mirror', label: this.stringOf($r('app.string.toprepos_filter_mirror')) },
      { key: 'private', label: this.stringOf($r('app.string.toprepos_filter_private')) },
      { key: 'public', label: this.stringOf($r('app.string.toprepos_filter_public')) },
      { key: 'source', label: this.stringOf($r('app.string.toprepos_filter_source')) },
      { key: 'template', label: this.stringOf($r('app.string.toprepos_filter_template')) }
    ];
  }

  private filterLabel(): string {
    for (const opt of this.filterOptions()) {
      if (opt.key === this.filterKey) {
        return opt.label;
      }
    }
    return this.stringOf($r('app.string.toprepos_filter_all'));
  }

  /** 8 项筛选维度客户端过滤（已拉取集合内） */
  private visibleRepos(): WorkTopRepoItem[] {
    return filterTopRepos(this.repos, this.filterKey);
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
          FilterDropdownChip({
            label: this.filterLabel(),
            active: this.filterKey !== 'all',
            options: this.filterOptions(),
            selectedKey: this.filterKey,
            onPick: (key: string): void => {
              this.filterKey = key;
            }
          })
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
            StateView({
              empty: true,
              emptyText: $r('app.string.work_top_repos_empty')
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
