/**
 * Explore 二级列表页（Spec 056）：Trending / Awesome Lists 共用（kind 参数分派）。
 * REST search 基线样式（RepoCard），官方参考图到位后单独收口。
 */
import { RepoSummary } from '../models/GitHubModels';
import { ExploreService } from '../services/ExploreService';
import { friendlyError } from '../services/GitHttpClient';
import { RepoCard } from '../components/RepoCard';
import { StateView } from '../components/StateView';
import { OctIcon } from '../components/OctIcon';
import { PageShadowBar } from '../components/PageShadowBar';

@ComponentV2
export struct ExploreRepoListView {
  @Param kind: string = 'trending';
  @Param token: string = '';
  @Param pathStack: NavPathStack = new NavPathStack();
  @Local repos: RepoSummary[] = [];
  @Local loading: boolean = true;
  @Local errorMsg: string = '';
  /** 滚动顶部阴影（滚动中显示、回顶消失） */
  @Local scrollShadow: boolean = false;

  aboutToAppear(): void {
    this.load();
  }

  private load(): void {
    this.loading = true;
    this.errorMsg = '';
    const task = this.kind === 'awesome'
      ? ExploreService.fetchAwesome(this.token)
      : ExploreService.fetchTrending(this.token);
    task.then((repos: RepoSummary[]) => {
      this.repos = repos;
      this.loading = false;
    }).catch((e: Error) => {
      this.errorMsg = friendlyError(this.getUIContext(), e);
      this.loading = false;
    });
  }

  private titleRes(): Resource {
    return this.kind === 'awesome'
      ? $r('app.string.explore_awesome')
      : $r('app.string.explore_trending');
  }

  build() {
    Column() {
      // 自绘头部（二级页约定：NavDestination hideTitleBar，不设 .title() 防双标题）
      Row() {
        Row() {
          OctIcon({ res: $r('app.media.oct_arrow_left_24'), iconSize: 20, iconColor: $r('app.color.text_primary') })
        }
        .width(44)
        .height(44)
        .onClick(() => this.pathStack.pop())

        Text(this.titleRes())
          .fontSize($r('app.float.title_font_size'))
          .fontWeight(600)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)

        Row()
          .width(44)
          .height(44)
      }
      .width('100%')
      .height(48)
      .padding({ left: 12, right: 12 })

      PageShadowBar({ show: this.scrollShadow })

      if (this.loading || this.errorMsg !== '' || this.repos.length === 0) {
        StateView({
          loading: this.loading,
          error: this.errorMsg,
          empty: !this.loading && this.errorMsg === '' && this.repos.length === 0,
          onRetry: (): void => this.load()
        })
      } else {
        Scroll() {
          Column() {
            ForEach(this.repos, (repo: RepoSummary) => {
              RepoCard({
                repo: repo,
                onOpen: (): void => {
                  this.pathStack.pushPathByName('repoDetail', repo.nameWithOwner);
                }
              })
                .margin({ bottom: 8 })
            }, (repo: RepoSummary) => repo.id !== '' ? repo.id : repo.nameWithOwner)
          }
          .padding({ left: 16, right: 16, top: 8, bottom: 16 })
          .width('100%')
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .align(Alignment.Top)
        .onScroll((_x: number, y: number): void => {
          this.scrollShadow = y > 0.001;
        })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_page'))
  }
}
