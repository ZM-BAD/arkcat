/**
 * 组织列表页（Spec 035）：Profile 三入口 Organizations 进入。
 * 头部为灰 login 上 + 粗体标题下的样式；行点击进入组织主页。
 */
import { OctIcon } from '../components/OctIcon';
import { OrgListPage, OrgSummary } from '../models/ProfileModels';
import { ProfileListService } from '../services/ProfileListService';
import { StateView } from '../components/StateView';

@ComponentV2
export struct OrgListView {
  @Param login: string = '';
  @Param token: string = '';
  @Param pathStack: NavPathStack = new NavPathStack();
  @Local orgs: OrgSummary[] = [];
  @Local cursor: string = '';
  @Local hasNextPage: boolean = false;
  @Local loading: boolean = true;
  @Local errorMsg: string = '';

  aboutToAppear(): void {
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
    ProfileListService.fetchOrganizations(this.token, this.login, this.cursor)
      .then((page: OrgListPage) => {
        this.orgs = this.orgs.concat(page.orgs);
        this.cursor = page.endCursor;
        this.hasNextPage = page.hasNextPage;
        this.loading = false;
      })
      .catch((e: Error) => {
        this.errorMsg = e.message;
        this.loading = false;
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
            .fontWeight(FontWeight.Bold)
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
      // 自绘头部：灰 login（上）+ 粗体标题（下）
      Row({ space: 8 }) {
        Stack() {
          OctIcon({ res: $r('app.media.oct_arrow_left_24'), iconSize: 20, iconColor: $r('app.color.text_primary') })
        }
        .onClick(() => {
          this.pathStack.pop();
        })
        Column({ space: 2 }) {
          Text(this.login)
            .fontSize($r('app.float.caption_font_size'))
            .fontColor($r('app.color.text_secondary'))
          Text($r('app.string.org_list_title'))
            .fontSize($r('app.float.title_font_size'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
        }
        .alignItems(HorizontalAlign.Start)
        Blank()
      }
      .width('100%')
      .height(64)
      .padding({ left: 16, right: 16 })

      if (this.orgs.length > 0) {
        Scroll() {
          Column() {
            ForEach(this.orgs, (org: OrgSummary) => {
              this.orgRow(org)
            }, (org: OrgSummary) => org.login)
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
      } else {
        StateView({
          loading: this.loading,
          error: this.errorMsg,
          onRetry: () => this.refresh()
        })
        if (!this.loading && this.errorMsg === '') {
          Column() {
            Text($r('app.string.org_list_empty'))
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
