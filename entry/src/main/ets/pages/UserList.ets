/**
 * 用户列表页（Spec 034）：Followers / Following 同组件两类参数。
 * 行：圆头像 + 显示名（粗体）/用户名（灰）/可选简介；整行点击进入用户主页。
 */
import { AppBar } from '../components/AppBar';
import { PageShadowBar } from '../components/PageShadowBar';
import { UserListPage } from '../models/ProfileModels';
import { UserSummary } from '../models/GitHubModels';
import { ProfileListService } from '../services/ProfileListService';
import { StateView } from '../components/StateView';
import { ListLoadingFooter } from '../components/ListLoadingFooter';
import { UserRow } from '../components/UserRow';
import { resText } from '../utils/I18n';

@ComponentV2
export struct UserListView {
  @Param login: string = '';
  @Param kind: string = 'followers';
  @Param token: string = '';
  @Param pathStack: NavPathStack = new NavPathStack();
  /** 头部快照：Index 共享 @State 会被同名目的地复用改写，进入时快照防串数据（review D4） */
  @Local headerLogin: string = '';
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
    this.headerLogin = this.login;
    this.refresh();
  }

  private refresh(): void {
    if (this.login === '') {
      return;
    }
    this.loading = true;
    this.errorMsg = '';
    ProfileListService.fetchUserList(this.token, this.login, this.kind, '')
      .then((page: UserListPage) => {
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
    ProfileListService.fetchUserList(this.token, this.login, this.kind, this.cursor)
      .then((page: UserListPage) => {
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

  /** 列表行（用户列表专用样式：无操作按钮） */
  @Builder
  userRow(user: UserSummary) {
    UserRow({
      avatarUrl: user.avatarUrl,
      name: user.name,
      login: user.login,
      bio: user.bio,
      verticalPadding: 8,
      onOpen: (): void => {
        this.pathStack.pushPathByName('userProfile', user.login);
      }
    })
  }

  build() {
    Column() {
      AppBar({
        showBack: true,
        title: this.headerLogin,
        subtitle: this.kind === 'following' ? $r('app.string.user_list_following') : $r('app.string.user_list_followers'),
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
                empty: !this.loading && this.errorMsg === '',
                emptyText: $r('app.string.user_list_empty'),
                onRetry: () => this.refresh()
              })
            }
          }
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
