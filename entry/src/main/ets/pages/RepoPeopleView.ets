/**
 * 仓库用户列表页（Spec 054）：Contributors / Watchers 共用。
 * kind 分派副标题、数据源与空态文案；行样式与 Stargazers 一致
 * （56 圆头像/粗体显示名/灰 login/两行 bio，整行点击进入用户主页）。
 */
import { OctIcon } from '../components/OctIcon';
import { PageShadowBar } from '../components/PageShadowBar';
import { UserSummary } from '../models/GitHubModels';
import { PeoplePage } from '../models/RepoSocialModels';
import { RepoService } from '../services/RepoService';
import { StateView } from '../components/StateView';
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
    this.fetchPage(this.cursor)
      .then((page: PeoplePage) => {
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

  /** 列表行（与 Stargazers 一致：无操作按钮，简洁列表） */
  @Builder
  userRow(user: UserSummary) {
    Row({ space: 12 }) {
      Stack() {
        Image(user.avatarUrl)
          .width(56)
          .height(56)
          .borderRadius(28)
          .backgroundColor($r('app.color.heat_empty'))
        if (user.avatarUrl === '') {
          OctIcon({ res: $r('app.media.oct_person_16'), iconSize: 28, iconColor: $r('app.color.text_secondary') })
        }
      }
      .width(56)
      .height(56)
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
    .padding({ left: 16, right: 16, top: 10, bottom: 10 })
    .onClick(() => {
      this.pathStack.pushPathByName('userProfile', user.login);
    })
  }

  build() {
    Column() {
      // 自绘头部：返回 + 仓库名（粗体）+ 副标题（灰）
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
          Text(this.name)
            .fontSize($r('app.float.title_font_size'))
            .fontWeight(600)
            .fontColor($r('app.color.text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.stringOf(this.subtitleRes()))
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
          .padding({ left: 0, right: 0 })
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
            Text(this.stringOf(this.emptyRes()))
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
