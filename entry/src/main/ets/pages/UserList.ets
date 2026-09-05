/**
 * 用户列表页（Spec 034）：Followers / Following 同组件两类参数。
 * 行：圆头像 + 显示名（粗体）/用户名（灰）/可选简介；整行点击进入用户主页。
 */
import { OctIcon } from '../components/OctIcon';
import { PageShadowBar } from '../components/PageShadowBar';
import { UserListPage } from '../models/ProfileModels';
import { UserSummary } from '../models/GitHubModels';
import { ProfileListService } from '../services/ProfileListService';
import { StateView } from '../components/StateView';
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
    ProfileListService.fetchUserList(this.token, this.login, this.kind, this.cursor)
      .then((page: UserListPage) => {
        this.users = this.users.concat(page.users);
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

  /** 列表行（用户列表专用样式：无操作按钮） */
  @Builder
  userRow(user: UserSummary) {
    Row({ space: 12 }) {
      Image(user.avatarUrl)
        .width(56)
        .height(56)
        .borderRadius(28)
        .backgroundColor($r('app.color.heat_empty'))
      Column({ space: 3 }) {
        // 有显示名：粗体显示名 + 灰用户名；无显示名：仅灰用户名（截图样式）
        if (user.name !== '') {
          Text(user.name)
            .fontSize($r('app.float.body_font_size'))
            .fontWeight(FontWeight.Bold)
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
            .fontColor($r('app.color.text_secondary'))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .lineHeight(20)
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 8, bottom: 8 })
    .onClick(() => {
      this.pathStack.pushPathByName('userProfile', user.login);
    })
  }

  build() {
    Column() {
      // 自绘头部：粗体 login + 灰副标题（Followers/Following）
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
          Text(`@${this.headerLogin}`)
            .fontSize($r('app.float.title_font_size'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          Text(this.kind === 'following' ? $r('app.string.user_list_following') : $r('app.string.user_list_followers'))
            .fontSize($r('app.float.body_font_size'))
            .fontColor($r('app.color.text_secondary'))
        }
        .alignItems(HorizontalAlign.Start)
        Blank()
      }
      .width('100%')
      .height(60)
      .padding({ left: 0, right: 0 })

      PageShadowBar({ show: this.scrollShadow })

      if (this.users.length > 0) {
        Scroll() {
          Column() {
            ForEach(this.users, (user: UserSummary) => {
              this.userRow(user)
            }, (user: UserSummary) => user.login)
            if (this.hasNextPage) {
              Text($r('app.string.issues_load_more'))
                .fontSize($r('app.float.body_font_size'))
                .fontColor($r('app.color.link_blue'))
                .padding(12)
                .onClick(() => this.loadMore())
            }
          }
          .padding({ left: 16, right: 16 })
          .width('100%')
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .align(Alignment.Top)
        .onScroll((_x: number, y: number): void => { this.scrollShadow = y > 0.001; })
      } else {
        StateView({
          loading: this.loading,
          error: this.errorMsg,
          onRetry: () => this.refresh()
        })
        if (!this.loading && this.errorMsg === '') {
          Column() {
            Text($r('app.string.user_list_empty'))
              .fontSize($r('app.float.body_font_size'))
              .fontColor($r('app.color.text_secondary'))
          }
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_page'))
  }
}
