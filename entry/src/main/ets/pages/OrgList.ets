/**
 * 组织列表页（Spec 035）：Profile 三入口 Organizations 进入。
 * 头部为灰 login 上 + 粗体标题下的样式；行点击进入组织主页。
 */
import { AppBar } from '../components/AppBar';
import { PageShadowBar } from '../components/PageShadowBar';
import { OrgListPage, OrgSummary } from '../models/ProfileModels';
import { ProfileListService } from '../services/ProfileListService';
import { StateView } from '../components/StateView';
import { ListLoadingFooter } from '../components/ListLoadingFooter';

@ComponentV2
export struct OrgListView {
  @Param login: string = '';
  @Param token: string = '';
  @Param pathStack: NavPathStack = new NavPathStack();
  /** 头部快照：Index 共享 @State 会被同名目的地复用改写，进入时快照防串数据（review D4） */
  @Local headerLogin: string = '';
  @Local orgs: OrgSummary[] = [];
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
    ProfileListService.fetchOrganizations(this.token, this.login, '')
      .then((page: OrgListPage) => {
        this.orgs = page.orgs;
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
    ProfileListService.fetchOrganizations(this.token, this.login, this.cursor)
      .then((page: OrgListPage) => {
        this.orgs = this.orgs.concat(page.orgs);
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

  /** 列表行：logo + 名称 + login + 简介 */
  @Builder
  orgRow(org: OrgSummary) {
    Row({ space: 12 }) {
      Image(org.avatarUrl)
        .width(56)
        .height(56)
        .borderRadius(6)
        .backgroundColor($r('app.color.heat_empty'))
      Column({ space: 3 }) {
        if (org.name !== '') {
          Text(org.name)
            .fontSize($r('app.float.body_font_size'))
            .fontWeight(600)
            .fontColor($r('app.color.text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        Text(org.login)
          .fontSize($r('app.float.body_font_size'))
          .fontColor($r('app.color.text_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (org.description !== '') {
          Text(org.description)
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
      this.pathStack.pushPathByName('orgProfile', org.login);
    })
  }

  build() {
    Column() {
      // Profile 型两行头部：灰 login（上）+ 粗体标题（下）→ subtitleAbove
      AppBar({
        showBack: true,
        title: $r('app.string.org_list_title'),
        subtitle: this.headerLogin,
        subtitleAbove: true,
        onBack: (): void => {
          this.pathStack.pop();
        }
      })

      PageShadowBar({ show: this.scrollShadow })

      Refresh({ refreshing: $$this.isRefreshing }) {
      Scroll() {
        if (this.orgs.length > 0) {
          Column() {
            ForEach(this.orgs, (org: OrgSummary) => {
              this.orgRow(org)
            }, (org: OrgSummary) => org.login)
            if (this.hasNextPage) {
              ListLoadingFooter({ show: this.loadingMore })
            }
          }
          .width('100%')
        } else {
          StateView({
            loading: this.loading,
            error: this.errorMsg,
            empty: !this.loading && this.errorMsg === '',
            emptyText: $r('app.string.org_list_empty'),
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
