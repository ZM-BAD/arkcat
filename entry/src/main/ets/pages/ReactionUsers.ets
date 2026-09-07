/**
 * Reactees 整页（Spec 047 走查九轮）：release 反应芯片长按进入，官方同款整页列表。
 * AppBar = emoji（大字）+ Reactees（灰副标题）；行=56 圆头像/粗体显示名/灰 login
 * （无显示名整行灰只显 login），与 Stargazers 同款；整行点击进入用户主页。
 * 数据=node(id) 查 release 指定 content 的 reactors 分页（前 8 之外也能看全）。
 */
import { OctIcon } from '../components/OctIcon';
import { PageShadowBar } from '../components/PageShadowBar';
import { StateView } from '../components/StateView';
import { ListLoadingFooter } from '../components/ListLoadingFooter';
import { ReactionUser, ReactionUsersPage, reactionEmoji } from '../models/RepoSubModels';
import { RepoSubService } from '../services/RepoSubService';
import { resText } from '../utils/I18n';

@ComponentV2
export struct ReactionUsersView {
  /** release 节点 id（addReaction 的 subject 同款） */
  @Param subjectId: string = '';
  /** 反应枚举（THUMBS_UP 等） */
  @Param content: string = '';
  @Param token: string = '';
  @Param pathStack: NavPathStack = new NavPathStack();
  @Local users: ReactionUser[] = [];
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
    if (this.subjectId === '' || this.content === '') {
      return;
    }
    this.loading = true;
    this.errorMsg = '';
    RepoSubService.fetchReactionUsers(this.token, this.subjectId, this.content, '')
      .then((page: ReactionUsersPage) => {
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
    RepoSubService.fetchReactionUsers(this.token, this.subjectId, this.content, this.cursor)
      .then((page: ReactionUsersPage) => {
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

  /** 列表行（与 Stargazers 一致：56 圆头像/粗体显示名/灰 login，无 bio） */
  @Builder
  userRow(user: ReactionUser) {
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
      // 自绘头部：返回 + emoji（大字）+ Reactees（灰副标题，官方同款两行）
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
          Text(reactionEmoji(this.content))
            .fontSize(24)
          Text(resText(this.getUIContext(), $r('app.string.reaction_reactees_title')))
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
          Column() {
            if (this.users.length > 0) {
              ForEach(this.users, (user: ReactionUser) => {
                this.userRow(user)
              }, (user: ReactionUser) => user.login)
              if (this.hasNextPage) {
                ListLoadingFooter({ show: this.loadingMore })
              }
            } else {
              StateView({
                loading: this.loading,
                error: this.errorMsg,
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
