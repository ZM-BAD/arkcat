/**
 * Stargazers 列表页（Spec 053）：仓库详情头部点 N stars 进入。
 * 行样式与 UserList 一致（56 圆头像/粗体显示名/灰 login/两行简介），
 * AppBar = 仓库名（粗体）+ Stargazers（灰副标题）；整行点击进入用户主页。
 */
import { AppBar } from '../components/AppBar';
import { PageShadowBar } from '../components/PageShadowBar';
import { UserSummary } from '../models/GitHubModels';
import { StargazerPage } from '../models/RepoSocialModels';
import { RepoService } from '../services/RepoService';
import { StateView } from '../components/StateView';
import { ListLoadingFooter } from '../components/ListLoadingFooter';
import { UserRow } from '../components/UserRow';
import { resText } from '../utils/I18n';

@ComponentV2
export struct StargazersView {
  @Param owner: string = '';
  @Param name: string = '';
  @Param token: string = '';
  @Param pathStack: NavPathStack = new NavPathStack();
  /** 头部快照：Index 共享 @State 会被同名目的地复用改写，进入时快照防串数据（review D4） */
  @Local headerName: string = '';
  @Local users: UserSummary[] = [];
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
    this.headerName = this.name;
    this.refresh();
  }

  private refresh(): void {
    if (this.owner === '' || this.name === '') {
      return;
    }
    this.loading = true;
    this.errorMsg = '';
    RepoService.fetchStargazers(this.token, this.owner, this.name, '')
      .then((page: StargazerPage) => {
        this.users = page.users;
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
    RepoService.fetchStargazers(this.token, this.owner, this.name, this.cursor)
      .then((page: StargazerPage) => {
        this.users = this.users.concat(page.users);
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

  /** 列表行（与 UserList 一致：无操作按钮，简洁列表） */
  @Builder
  userRow(user: UserSummary) {
    UserRow({
      avatarUrl: user.avatarUrl,
      name: user.name,
      login: user.login,
      bio: user.bio,
      onOpen: (): void => {
        this.pathStack.pushPathByName('userProfile', user.login);
      }
    })
  }

  build() {
    Column() {
      AppBar({
        showBack: true,
        title: this.headerName,
        subtitle: this.stringOf($r('app.string.social_stargazers')),
        onBack: (): void => {
          this.pathStack.pop();
        }
      })

      PageShadowBar({ show: this.scrollShadow })

      Refresh({ refreshing: $$this.isRefreshing }) {
      Scroll() {
        if (this.users.length > 0) {
          Column() {
            ForEach(this.users, (user: UserSummary) => {
              this.userRow(user)
            }, (user: UserSummary) => user.login)
            if (this.hasNextPage) {
              ListLoadingFooter({ show: this.loadingMore })
            }
          }
          .padding({ left: 0, right: 0 })
          .width('100%')
        } else {
          StateView({
            loading: this.loading,
            error: this.errorMsg,
            empty: !this.loading && this.errorMsg === '',
            emptyText: $r('app.string.social_stargazers_empty'),
            onRetry: () => this.refresh()
          })
          .width('100%')
          .height('100%')
        }
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
