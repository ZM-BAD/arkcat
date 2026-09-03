/**
 * 仓库 Commits 列表页（Spec 028）：Repo Detail → Commits。
 * 行：提交标题 + 绿✓ + 相对时间 + 作者（头像/登录名/authored）。
 */
import { OctIcon } from '../components/OctIcon';
import { RepoCommitItem, RepoCommitsPage } from '../models/RepoSubModels';
import { RepoSubService } from '../services/RepoSubService';
import { StateView } from '../components/StateView';
import { githubShortTime, timeParts, TimeParts } from '../utils/Format';
import { resText } from '../utils/I18n';

@ComponentV2
export struct RepoCommitsView {
  @Param owner: string = '';
  @Param name: string = '';
  @Param token: string = '';
  @Param pathStack: NavPathStack = new NavPathStack();
  @Local commits: RepoCommitItem[] = [];
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
    RepoSubService.fetchCommits(this.token, this.owner, this.name, '')
      .then((page: RepoCommitsPage) => {
        this.commits = page.commits;
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
    RepoSubService.fetchCommits(this.token, this.owner, this.name, this.cursor)
      .then((page: RepoCommitsPage) => {
        this.commits = this.commits.concat(page.commits);
        this.cursor = page.endCursor;
        this.hasNextPage = page.hasNextPage;
        this.loading = false;
      })
      .catch((e: Error) => {
        this.errorMsg = e.message;
        this.loading = false;
      });
  }

  private timeText(parts: TimeParts | null): string {
    return parts !== null ? githubShortTime(parts) : '';
  }

  @Builder
  commitRow(item: RepoCommitItem) {
    Column({ space: 6 }) {
      Row() {
        Text(item.headline)
          .fontSize($r('app.float.body_font_size'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        if (item.checksState === 'SUCCESS') {
          OctIcon({ res: $r('app.media.oct_check_16'), iconSize: 14, iconColor: $r('app.color.success_text') })
            .margin({ left: 8 })
        }
        Text(this.timeText(timeParts(item.committedDate, Date.now())))
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_secondary'))
          .margin({ left: 10 })
      }
      .width('100%')

      Row({ space: 8 }) {
        if (item.authorAvatar !== '') {
          Image(item.authorAvatar)
            .width(22)
            .height(22)
            .borderRadius(11)
            .backgroundColor($r('app.color.heat_empty'))
        } else {
          Circle()
            .width(22)
            .height(22)
            .fill($r('app.color.heat_empty'))
        }
        Text(item.authorLogin)
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_primary'))
        Text($r('app.string.repo_commits_authored'))
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_tertiary'))
      }
      .width('100%')
    }
    .padding($r('app.float.card_padding'))
    .borderRadius($r('app.float.card_radius'))
    .backgroundColor($r('app.color.card_background'))
    .width('100%')
    .margin({ bottom: 8 })
  }

  build() {
    Column() {
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
        Text($r('app.string.repo_commits_title'))
          .fontSize($r('app.float.title_font_size'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
      }
      .width('100%')
      .height(48)
      .padding({ left: 0, right: 0 })

      Scroll() {
        Column() {
          if (this.commits.length > 0) {
            ForEach(this.commits, (item: RepoCommitItem) => {
              this.commitRow(item)
            }, (item: RepoCommitItem) => item.oid)
            if (this.hasNextPage) {
              Text($r('app.string.issues_load_more'))
                .fontSize($r('app.float.body_font_size'))
                .fontColor($r('app.color.link_blue'))
                .padding(12)
                .onClick(() => this.loadMore())
            }
          } else if (this.loading || this.errorMsg !== '') {
            StateView({ loading: this.loading, error: this.errorMsg, onRetry: () => this.refresh() })
          } else {
            StateView({ empty: true, emptyText: $r('app.string.repo_commits_empty') })
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
