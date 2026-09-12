/**
 * Stargazers 列表页（Spec 053）：仓库详情头部点 N stars 进入。
 * 行样式与 UserList 一致（56 圆头像/粗体显示名/灰 login/两行简介），
 * AppBar = 仓库名（粗体）+ Stargazers（灰副标题）；整行点击进入用户主页。
 */
import { OctIcon } from '../components/OctIcon';
import { PageShadowBar } from '../components/PageShadowBar';
import { UserSummary } from '../models/GitHubModels';
import { StargazerPage } from '../models/RepoSocialModels';
import { RepoService } from '../services/RepoService';
import { StateView } from '../components/StateView';
import { ListLoadingFooter } from '../components/ListLoadingFooter';
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
    Row({ space: 12 }) {
      Image(user.avatarUrl)
        .width(56)
        .height(56)
        .borderRadius(28)
        .backgroundColor($r('app.color.heat_empty'))
      Column({ space: 3 }) {
        if (user.name !== '') {
          Text(user.name)
            .fontSize($r('app.float.body_font_size'))
            .fontWeight(600)
            .fontColor($r('app.color.text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        Text(user.login)
          .fontSize($r('app.float.body_font_size'))
          .fontColor($r('app.color.text_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (user.bio !== '') {
          Text(user.bio)
            .fontSize($r('app.float.body_font_size'))
            .fontColor($r('app.color.text_primary'))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .lineHeight(20)
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 10, bottom: 10 })
    .onClick(() => {
      this.pathStack.pushPathByName('userProfile', user.login);
    })
  }

  build() {
    Column() {
      // 自绘头部：返回 + 仓库名（粗体）+ Stargazers（灰）
      Row({ space: 8 }) {
        Stack() {
          OctIcon({ res: $r('app.media.oct_arrow_left_24'), iconSize: 20, iconColor: $r('app.color.text_primary') })
        }
        .width(44)
        .height(44)
        .accessibilityDescription($r('app.string.a11y_back'))
        .focusable(true)
        .onClick(() => {
          this.pathStack.pop();
        })
        Column({ space: 2 }) {
          Text(this.headerName)
            .fontSize($r('app.float.title_font_size'))
            .fontWeight(600)
            .fontColor($r('app.color.text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.stringOf($r('app.string.social_stargazers')))
            .fontSize($r('app.float.body_font_size'))
            .fontColor($r('app.color.text_secondary'))
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Blank()
      }
      .width('100%')
      .height(60)
      .padding({ left: 0, right: 0 })

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
          Column() {
            StateView({
              loading: this.loading,
              error: this.errorMsg,
              onRetry: () => this.refresh()
            })
            if (!this.loading && this.errorMsg === '') {
              Column() {
                Text(this.stringOf($r('app.string.social_stargazers_empty')))
                  .fontSize($r('app.float.body_font_size'))
                  .fontColor($r('app.color.text_secondary'))
              }
              .layoutWeight(1)
              .justifyContent(FlexAlign.Center)
            }
          }
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
