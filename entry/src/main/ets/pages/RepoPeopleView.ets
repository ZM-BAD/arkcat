/**
 * 仓库用户列表页（Spec 054）：Contributors / Watchers 共用。
 * kind 分派副标题、数据源与空态文案；行样式与 Stargazers 一致
 * （56 圆头像/粗体显示名/灰 login/两行 bio，整行点击进入用户主页）。
 */
import { AppBar } from '../components/AppBar';
import { PageShadowBar } from '../components/PageShadowBar';
import { UserSummary } from '../models/GitHubModels';
import { PeoplePage } from '../models/RepoSocialModels';
import { RepoService } from '../services/RepoService';
import { StateView } from '../components/StateView';
import { ListLoadingFooter } from '../components/ListLoadingFooter';
import { UserRow } from '../components/UserRow';
import { resText } from '../utils/I18n';

@ComponentV2
export struct RepoPeopleView {
  @Param owner: string = '';
  @Param name: string = '';
  /** contributors | watchers */
  @Param kind: string = 'contributors';
  @Param token: string = '';
  @Param pathStack: NavPathStack = new NavPathStack();
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
    this.refresh();
  }

  private refresh(): void {
    if (this.owner === '' || this.name === '') {
      return;
    }
    this.loading = true;
    this.errorMsg = '';
    this.fetchPage('')
      .then((page: PeoplePage) => {
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
    this.fetchPage(this.cursor)
      .then((page: PeoplePage) => {
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

  /** kind 分派：watchers 走 GraphQL；contributors 走 REST+元信息补全（service 内部分派） */
  private fetchPage(cursor: string): Promise<PeoplePage> {
    if (this.kind === 'watchers') {
      return RepoService.fetchWatchers(this.token, this.owner, this.name, cursor);
    }
    return RepoService.fetchContributors(this.token, this.owner, this.name, cursor);
  }

  /** 副标题：Watchers / Contributors */
  private subtitleRes(): Resource {
    return this.kind === 'watchers' ? $r('app.string.repo_watchers') : $r('app.string.repo_contributors');
  }

  /** 空态文案 */
  private emptyRes(): Resource {
    return this.kind === 'watchers'
      ? $r('app.string.social_watchers_empty')
      : $r('app.string.social_contributors_empty');
  }

  private stringOf(res: Resource): string {
    return resText(this.getUIContext(), res);
  }

  /** 列表行（与 Stargazers 一致：无操作按钮，简洁列表；空头像走组件内 person 兜底） */
  @Builder
  userRow(user: UserSummary) {
    UserRow({
      avatarUrl: user.avatarUrl,
      name: user.name,
      login: user.login,
      bio: user.bio,
      fallbackIcon: true,
      onOpen: (): void => {
        this.pathStack.pushPathByName('userProfile', user.login);
      }
    })
  }

  build() {
    Column() {
      AppBar({
        showBack: true,
        title: this.name,
        subtitle: this.stringOf(this.subtitleRes()),
        onBack: (): void => {
          this.pathStack.pop();
        }
      })

      PageShadowBar({ show: this.scrollShadow })

      Refresh({ refreshing: $$this.isRefreshing }) {
        Scroll() {
          Column() {
            if (this.users.length > 0) {
              ForEach(this.users, (user: UserSummary) => {
                this.userRow(user)
              }, (user: UserSummary) => user.login)
              if (this.hasNextPage) {
                ListLoadingFooter({ show: this.loadingMore })
              }
            } else {
              StateView({
                loading: this.loading,
                error: this.errorMsg,
                onRetry: () => this.refresh()
              })
              if (!this.loading && this.errorMsg === '') {
                Column() {
                  Text(this.stringOf(this.emptyRes()))
                    .fontSize($r('app.float.body_font_size'))
                    .fontColor($r('app.color.text_secondary'))
                }
                .layoutWeight(1)
                .justifyContent(FlexAlign.Center)
              }
            }
          }
          .padding({ left: 0, right: 0 })
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
