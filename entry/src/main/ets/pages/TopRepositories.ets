/**
 * 工作区 Top Repositories 页（Spec 021）：viewer 仓库按 PUSHED_AT 降序。
 * 行结构：owner 头像 + owner（灰小字）/ 仓库名（黑大字）；点击进入仓库详情。
 */
import { WorkTopRepoItem, WorkTopReposPage } from '../models/WorkModels';
import { WorkService } from '../services/WorkService';
import { StateView } from '../components/StateView';
import { OctIcon } from '../components/OctIcon';
import { resText } from '../utils/I18n';

@ComponentV2
export struct TopRepositoriesView {
  @Param token: string = '';
  @Param pathStack: NavPathStack = new NavPathStack();
  @Local privacy: string = 'all';
  @Local repos: WorkTopRepoItem[] = [];
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
    WorkService.fetchTopRepositories(this.token, this.privacy, '')
      .then((page: WorkTopReposPage) => {
        this.repos = page.repos;
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
    WorkService.fetchTopRepositories(this.token, this.privacy, this.cursor)
      .then((page: WorkTopReposPage) => {
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

  private privacyLabel(): string {
    if (this.privacy === 'public') {
      return this.stringOf($r('app.string.work_visibility_public'));
    }
    if (this.privacy === 'private') {
      return this.stringOf($r('app.string.work_visibility_private'));
    }
    return this.stringOf($r('app.string.work_filter_all'));
  }

  @Builder
  repoRow(repo: WorkTopRepoItem) {
    Row({ space: 12 }) {
      if (repo.ownerAvatar !== '') {
        Image(repo.ownerAvatar)
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
        Text(repo.ownerLogin)
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
        Text(repo.name)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height(64)
    .padding({ left: 12, right: 12 })
    .onClick(() => {
      this.pathStack.pushPathByName('repoDetail', `${repo.ownerLogin}/${repo.name}`);
    })
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
.onClick((): void => {
            this.pathStack.pop();
          })
        Text($r('app.string.nav_top_repos_title'))
          .fontSize($r('app.float.title_font_size'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
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
      }
      .width('100%')
      .height(48)
      .padding({ left: 16, right: 12 })

      Scroll() {
        Column() {
          // 可见性下拉（All / Public / Private）
          Text(`${this.privacyLabel()} ⌄`)
            .fontSize($r('app.float.caption_font_size'))
            .fontColor(this.privacy === 'all' ? $r('app.color.text_primary') : $r('app.color.link_blue'))
            .padding({ left: 12, right: 12, top: 5, bottom: 5 })
            .borderRadius(12)
            .backgroundColor(this.privacy === 'all' ? $r('app.color.card_background') : $r('app.color.chip_active_bg'))
            .border({ width: 1, color: this.privacy === 'all' ? $r('app.color.border') : $r('app.color.chip_active_border') })
            .bindMenu([
              {
                value: this.stringOf($r('app.string.work_filter_all')),
                action: (): void => { this.privacy = 'all'; this.refresh(); }
              },
              {
                value: this.stringOf($r('app.string.work_visibility_public')),
                action: (): void => { this.privacy = 'public'; this.refresh(); }
              },
              {
                value: this.stringOf($r('app.string.work_visibility_private')),
                action: (): void => { this.privacy = 'private'; this.refresh(); }
              }
            ])
            .margin({ bottom: 12 })

          if (this.repos.length > 0) {
            ForEach(this.repos, (repo: WorkTopRepoItem) => {
              this.repoRow(repo)
            }, (repo: WorkTopRepoItem) => repo.id)
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
          } else {
            StateView({
              empty: true,
              emptyText: $r('app.string.work_top_repos_empty')
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
