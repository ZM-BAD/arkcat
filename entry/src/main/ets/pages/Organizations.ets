/**
 * 工作区 Organizations 页（Spec 022）：viewer 所属组织。
 * 行结构：组织头像 + 名称（大字）/ 登录名（灰小字）；点击进入组织主页（userProfile 路由）。
 * 空态为纯文字居中（官方截图无插图）。
 */
import { WorkOrgItem, WorkOrgsPage } from '../models/WorkModels';
import { WorkService } from '../services/WorkService';
import { StateView } from '../components/StateView';
import { ListLoadingFooter } from '../components/ListLoadingFooter';
import { OctIcon } from '../components/OctIcon';
import { PageShadowBar } from '../components/PageShadowBar';
import { resText } from '../utils/I18n';

@ComponentV2
export struct OrganizationsView {
  @Param token: string = '';
  @Param pathStack: NavPathStack = new NavPathStack();
  @Local orgs: WorkOrgItem[] = [];
  @Local cursor: string = '';
  @Local hasNextPage: boolean = false;
  @Local loading: boolean = true;
  @Local errorMsg: string = '';
  /** 滚动顶部阴影（滚动中显示、回顶消失） */
  @Local scrollShadow: boolean = false;
  @Local isRefreshing: boolean = false;
  /** 触底加载更多（底部转圈指示） */
  @Local loadingMore: boolean = false;

  private scopeName(): string {
    return 'read:org';
  }

  aboutToAppear(): void {
    this.refresh();
  }

  private refresh(): void {
    this.loading = true;
    this.errorMsg = '';
    WorkService.fetchOrganizations(this.token, '')
      .then((page: WorkOrgsPage) => {
        this.orgs = page.orgs;
        this.cursor = page.endCursor;
        this.hasNextPage = page.hasNextPage;
        this.loading = false;
        this.isRefreshing = false;
        this.loadingMore = false;
      })
      .catch((e: Error) => {
        // Token scope 不足时给出可操作提示（GraphQL scopes 错误）而非裸接口错误
        const hint = e.message.indexOf('scopes') >= 0
          ? resText(this.getUIContext(), $r('app.string.work_scope_hint'), this.scopeName())
          : e.message;
        this.errorMsg = hint;
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
    WorkService.fetchOrganizations(this.token, this.cursor)
      .then((page: WorkOrgsPage) => {
        this.orgs = this.orgs.concat(page.orgs);
        this.cursor = page.endCursor;
        this.hasNextPage = page.hasNextPage;
        this.loading = false;
        this.loadingMore = false;
      })
      .catch((e: Error) => {
        // Token scope 不足时给出可操作提示（GraphQL scopes 错误）而非裸接口错误
        const hint = e.message.indexOf('scopes') >= 0
          ? resText(this.getUIContext(), $r('app.string.work_scope_hint'), this.scopeName())
          : e.message;
        this.errorMsg = hint;
        this.loading = false;
        this.loadingMore = false;
      });
  }

  @Builder
  orgRow(org: WorkOrgItem) {
    Row({ space: 12 }) {
      if (org.avatarUrl !== '') {
        Image(org.avatarUrl)
          .width(40)
          .height(40)
          .borderRadius(20)
          .backgroundColor($r('app.color.heat_empty'))
      } else {
        Text('◯')
          .fontSize(32)
          .width(40)
          .height(40)
          .borderRadius(20)
          .textAlign(TextAlign.Center)
          .backgroundColor($r('app.color.heat_empty'))
      }
      Column({ space: 2 }) {
        Text(org.name)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Text(`@${org.login}`)
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height(64)
    .padding({ left: 12, right: 12 })
    .onClick(() => {
      // 组织是 Organization 节点，GraphQL user(login:) 解析不了 → 走组织主页（review D2）
      this.pathStack.pushPathByName('orgProfile', org.login);
    })
  }

  @Builder
  emptyState() {
    Column() {
      Blank()
      Text($r('app.string.work_orgs_empty'))
        .fontSize(20)
        .fontWeight(600)
        .fontColor($r('app.color.text_primary'))
        .textAlign(TextAlign.Center)
        .width('100%')
      Blank()
    }
    .width('100%')
    .height('100%')
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
        Text($r('app.string.nav_organizations_title'))
          .fontSize($r('app.float.title_font_size'))
          .fontWeight(600)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
      }
      .width('100%')
      .height(48)
      .padding({ left: 0, right: 0 })

      PageShadowBar({ show: this.scrollShadow })

      Refresh({ refreshing: $$this.isRefreshing }) {
      Scroll() {
        if (this.orgs.length > 0) {
          Column() {
            ForEach(this.orgs, (org: WorkOrgItem) => {
              this.orgRow(org)
            }, (org: WorkOrgItem) => org.login)
            if (this.hasNextPage) {
              ListLoadingFooter({ show: this.loadingMore })
            }
          }
          .padding({ left: 16, right: 16, bottom: 16 })
          .width('100%')
        } else if (this.loading || this.errorMsg !== '') {
          StateView({
            loading: this.loading,
            error: this.errorMsg,
            onRetry: () => this.refresh()
          })
          .layoutWeight(1)
        } else {
          this.emptyState()
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
