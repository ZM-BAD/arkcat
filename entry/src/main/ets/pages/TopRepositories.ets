/**
 * 工作区 Top Repositories 页（Spec 021）：viewer 仓库按 PUSHED_AT 降序。
 * 官方仓库筛选下拉 8 项（All/Archived/Fork/Mirror/Private/Public/Source/Template）客户端过滤；
 * 行结构：owner 头像 + owner（灰小字）/ 仓库名（黑大字）；点击进入仓库详情。
 */
import { WorkTopRepoItem, WorkTopReposPage, filterTopRepos } from '../models/WorkModels';
import { FilterDropdownChip, FilterDropdownOption } from '../components/FilterDropdownChip';
import { WorkService } from '../services/WorkService';
import { StateView } from '../components/StateView';
import { OctIcon } from '../components/OctIcon';
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
    WorkService.fetchTopRepositories(this.token, this.cursor)
      .then((page: WorkTopReposPage) => {
        this.repos = this.repos.concat(page.repos);
        this.cursor = page.endCursor;
        this.hasNextPage = page.hasNextPage;
        this.loading = false;
      })
      .catch((e: Error) => {
        this.errorMsg = e.message;
        this.loading = false;
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
          .fontSize(28)
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
          .fontSize(17)
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
    .padding({ left: 0, right: 0 })
    .onClick(() => {
      this.pathStack.pushPathByName('repoDetail', `${repo.ownerLogin}/${repo.name}`);
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
        Text($r('app.string.nav_top_repos_title'))
          .fontSize($r('app.float.title_font_size'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
        Stack() {
  OctIcon({
          res: $r('app.media.oct_search_24'),
          iconSize: 20,
          iconColor: $r('app.color.text_primary')
  })
}
.width(44)
.height(44)
        .accessibilityDescription($r('app.string.a11y_search'))
        .focusable(true)
.onClick((): void => {
            this.pathStack.pushPathByName('search', '');
          })
          .padding(6)
      }
      .width('100%')
      .height(48)
      .padding({ left: 16, right: 12 })

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
              Text($r('app.string.issues_load_more'))
                .fontSize($r('app.float.body_font_size'))
                .fontColor($r('app.color.link_blue'))
                .padding(12)
                .onClick(() => this.loadMore())
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
