/**
 * Starred Repositories 页（Spec 023/035）：viewer 星标仓库（默认）；传入 login 展示目标用户星标。
 * My lists 区（+ NEW 预留，v1 恒显空态卡）+ Starred 分组（头像/名称/描述/星数/语言）。
 */
import { promptAction } from '@kit.ArkUI';
import { OctIcon } from '../components/OctIcon';
import { WorkStarredPage, WorkStarredRepoItem } from '../models/WorkModels';
import { WorkService } from '../services/WorkService';
import { StateView } from '../components/StateView';
import { compactCount } from '../utils/Format';
import { resText } from '../utils/I18n';

@ComponentV2
export struct StarredRepositoriesView {
  @Param token: string = '';
  @Param login: string = '';
  @Param pathStack: NavPathStack = new NavPathStack();
  @Local repos: WorkStarredRepoItem[] = [];
  @Local viewerLogin: string = '';
  @Local cursor: string = '';
  @Local hasNextPage: boolean = false;
  @Local loading: boolean = true;
  @Local errorMsg: string = '';

  aboutToAppear(): void {
    this.refresh();
  }

  private refresh(): void {
    this.loading = true;
    this.errorMsg = '';
    WorkService.fetchStarred(this.token, '', this.login)
      .then((page: WorkStarredPage) => {
        this.repos = page.repos;
        this.viewerLogin = page.viewerLogin;
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
    WorkService.fetchStarred(this.token, this.cursor, this.login)
      .then((page: WorkStarredPage) => {
        this.repos = this.repos.concat(page.repos);
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

  private comingSoon(): void {
    promptAction.showToast({ message: $r('app.string.home_feature_coming') });
  }

  @Builder
  repoRow(repo: WorkStarredRepoItem) {
    Column({ space: 6 }) {
      Row({ space: 8 }) {
        if (repo.ownerAvatar !== '') {
          Image(repo.ownerAvatar)
            .width(24)
            .height(24)
            .borderRadius(12)
            .backgroundColor($r('app.color.heat_empty'))
        }
        Text(repo.ownerLogin)
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        Stack() {
  OctIcon({
          res: $r('app.media.oct_kebab_horizontal_16'),
          iconSize: 15,
          iconColor: $r('app.color.text_secondary')
  })
}
.onClick((): void => this.comingSoon())
      }
      .width('100%')

      Text(repo.name)
        .fontSize($r('app.float.body_font_size'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')

      if (repo.description !== '') {
        Text(repo.description)
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_secondary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }

      Row({ space: 8 }) {
        OctIcon({ res: $r('app.media.oct_star_fill_16'), iconSize: 12, iconColor: $r('app.color.star_gold') })
        Text(compactCount(repo.stargazerCount))
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.star_gold'))
        if (repo.language !== '') {
          Text('●')
            .fontSize(12)
            .fontColor(repo.languageColor !== '' ? repo.languageColor : $r('app.color.text_secondary'))
          Text(repo.language)
            .fontSize($r('app.float.caption_font_size'))
            .fontColor($r('app.color.text_secondary'))
        }
      }
      .width('100%')
    }
    .padding($r('app.float.card_padding'))
    .borderRadius($r('app.float.card_radius'))
    .backgroundColor($r('app.color.card_background'))
    .width('100%')
    .margin({ bottom: 8 })
    .onClick(() => {
      this.pathStack.pushPathByName('repoDetail', `${repo.ownerLogin}/${repo.name}`);
    })
  }

  build() {
    Column() {
      // 副标题（viewer login）+ 主标题 + 操作
      Row({ space: 12 }) {
        Stack() {
  OctIcon({
          res: $r('app.media.oct_arrow_left_24'),
          iconSize: 20,
          iconColor: $r('app.color.text_primary')
  })
}
.onClick((): void => {
            this.pathStack.pop();
          })
        Column({ space: 2 }) {
          Text(this.viewerLogin)
            .fontSize($r('app.float.caption_font_size'))
            .fontColor($r('app.color.text_secondary'))
          Text($r('app.string.nav_starred_title'))
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Stack() {
  OctIcon({
          res: $r('app.media.oct_search_24'),
          iconSize: 20,
          iconColor: $r('app.color.text_primary')
  })
}
.onClick((): void => {
            this.pathStack.pushPathByName('search', '');
          })
          .padding(6)
        Stack() {
  OctIcon({
          res: $r('app.media.oct_kebab_horizontal_16'),
          iconSize: 18,
          iconColor: $r('app.color.text_secondary')
  })
}
.onClick((): void => this.comingSoon())
          .padding(6)
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 12 })

      Scroll() {
        Column() {
          // My lists 行（列表 API 后续 Spec，v1 展示行 + 空态卡）
          Row() {
            OctIcon({ res: $r('app.media.oct_three_bars_16'), iconSize: 16, iconColor: $r('app.color.text_secondary') })
            Text($r('app.string.work_starred_my_lists'))
              .fontSize($r('app.float.body_font_size'))
              .fontColor($r('app.color.text_primary'))
              .margin({ left: 10 })
            Blank()
            Text($r('app.string.work_starred_new'))
              .fontSize($r('app.float.body_font_size'))
              .fontColor($r('app.color.link_blue'))
              .onClick(() => this.comingSoon())
          }
          .width('100%')
          .height(44)

          // Create your first list 空态卡
          Column({ space: 12 }) {
            Text($r('app.string.work_starred_first_list_title'))
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
              .textAlign(TextAlign.Center)
              .width('100%')
            Text($r('app.string.work_starred_first_list_desc'))
              .fontSize($r('app.float.body_font_size'))
              .fontColor($r('app.color.text_secondary'))
              .textAlign(TextAlign.Center)
              .width('100%')
            Button($r('app.string.work_starred_create_list'))
              .width('100%')
              .height(44)
              .fontSize($r('app.float.caption_font_size'))
              .fontColor($r('app.color.link_blue'))
              .backgroundColor(Color.Transparent)
              .borderRadius(8)
              .border({ width: 1, color: $r('app.color.border') })
              .onClick(() => this.comingSoon())
          }
          .padding(24)
          .width('100%')

          Divider()
            .color($r('app.color.divider'))
            .margin({ top: 8, bottom: 8 })

          // Starred 分组头
          Row() {
            OctIcon({ res: $r('app.media.oct_star_16'), iconSize: 18, iconColor: $r('app.color.text_secondary') })
            Text($r('app.string.home_work_starred'))
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary'))
              .margin({ left: 10 })
          }
          .width('100%')
          .height(40)

          if (this.repos.length > 0) {
            ForEach(this.repos, (repo: WorkStarredRepoItem) => {
              this.repoRow(repo)
            }, (repo: WorkStarredRepoItem) => repo.id)
            if (this.hasNextPage) {
              Text($r('app.string.issues_load_more'))
                .fontSize($r('app.float.body_font_size'))
                .fontColor($r('app.color.link_blue'))
                .padding(12)
                .onClick(() => this.loadMore())
            }
          } else if (this.loading || this.errorMsg !== '') {
            StateView({
              loading: this.loading,
              error: this.errorMsg,
              onRetry: () => this.refresh()
            })
          }
        }
        .padding({ left: 16, right: 16, bottom: 16 })
        .width('100%')
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_page'))
  }
}
