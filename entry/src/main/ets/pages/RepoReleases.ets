/**
 * 仓库 Releases 页（Spec 029）：最新 Release 头卡（Latest release + What's Changed）+ All Releases。
 */
import { OctIcon } from '../components/OctIcon';
import { MarkdownView } from '../components/MarkdownView';
import { PageShadowBar } from '../components/PageShadowBar';
import { ReleaseItem, RepoReleasesPage, monthDayText } from '../models/RepoSubModels';
import { RepoSubService } from '../services/RepoSubService';
import { MarkdownService } from '../services/MarkdownService';
import { StateView } from '../components/StateView';
import { githubShortTime, timeParts, TimeParts } from '../utils/Format';
import { resText } from '../utils/I18n';

@ComponentV2
export struct RepoReleasesView {
  @Param owner: string = '';
  @Param name: string = '';
  @Param token: string = '';
  @Param pathStack: NavPathStack = new NavPathStack();
  @Local releases: ReleaseItem[] = [];
  @Local cursor: string = '';
  @Local hasNextPage: boolean = false;
  @Local loading: boolean = true;
  @Local errorMsg: string = '';
  /** 滚动顶部阴影（滚动中显示、回顶消失） */
  @Local scrollShadow: boolean = false;
  /** 最新发布正文渲染 HTML（Release 无 bodyHTML，走 /markdown 渲染） */
  @Local latestBodyHtml: string = '';

  aboutToAppear(): void {
    this.refresh();
  }

  private refresh(): void {
    this.loading = true;
    this.errorMsg = '';
    RepoSubService.fetchReleases(this.token, this.owner, this.name, '')
      .then((page: RepoReleasesPage) => {
        this.releases = page.releases;
        this.cursor = page.endCursor;
        this.hasNextPage = page.hasNextPage;
        this.loading = false;
        this.renderLatestBody();
      })
      .catch((e: Error) => {
        this.errorMsg = e.message;
        this.loading = false;
      });
  }

  /** 最新发布正文渲染（异步；MarkdownView 以 body 原文兜底） */
  private renderLatestBody(): void {
    if (this.releases.length === 0) {
      return;
    }
    MarkdownService.renderMarkdown(this.token, this.releases[0].body, `${this.owner}/${this.name}`)
      .then((html: string) => {
        this.latestBodyHtml = html;
      })
      .catch(() => {
      });
  }

  private loadMore(): void {
    if (!this.hasNextPage || this.loading) {
      return;
    }
    this.loading = true;
    RepoSubService.fetchReleases(this.token, this.owner, this.name, this.cursor)
      .then((page: RepoReleasesPage) => {
        this.releases = this.releases.concat(page.releases);
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

  private timeText(parts: TimeParts | null): string {
    return parts !== null ? githubShortTime(parts) : '';
  }

  @Builder
  releaseRow(item: ReleaseItem) {
    Column({ space: 4 }) {
      // 标题=release name（1.3.2），tag 仅作回退（走查修正）
      Text(item.name !== '' ? item.name : item.tagName)
        .fontSize($r('app.float.body_font_size'))
        .fontWeight(600)
        .fontColor($r('app.color.text_primary'))
      // 官方布局：时间 · Latest release 徽章（绿字绿描边）一排，时间在前（走查修正四轮）
      Row({ space: 6 }) {
        Text(this.timeText(timeParts(item.createdAt, Date.now())))
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_secondary'))
        if (item.isLatest) {
          Text('·')
            .fontSize($r('app.float.caption_font_size'))
            .fontColor($r('app.color.text_secondary'))
          Text($r('app.string.releases_latest'))
            .fontSize(12)
            .fontColor($r('app.color.success_text'))
            .padding({ left: 6, right: 6, top: 1, bottom: 1 })
            .borderRadius(6)
            .outline({ width: 1.5, color: $r('app.color.success_text'), radius: 6, style: OutlineStyle.SOLID })
        }
      }
      .alignItems(VerticalAlign.Center)
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding({ top: 10, bottom: 12 })
    .onClick(() => {
      this.pathStack.pushPathByName('releaseDetail', `${this.owner}/${this.name}/${item.tagName}`);
    })
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
        Column({ space: 0 }) {
          Text(this.owner)
            .fontSize($r('app.float.caption_font_size'))
            .fontColor($r('app.color.text_secondary'))
          Text($r('app.string.repo_releases_title'))
            .fontSize($r('app.float.title_font_size'))
            .fontWeight(600)
            .fontColor($r('app.color.text_primary'))
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .height(56)
      .padding({ left: 0, right: 0 })

      PageShadowBar({ show: this.scrollShadow })

      Scroll() {
        Column() {
          if (this.releases.length > 0) {
            // 最新版本头卡：标题=name（1.3.2），左对齐（走查修正二轮）
            Column({ space: 8 }) {
              Text(this.releases[0].name !== '' ? this.releases[0].name : this.releases[0].tagName)
                .fontSize(32)
                .fontWeight(600)
                .fontColor($r('app.color.text_primary'))
              if (this.releases[0].isLatest) {
                Text($r('app.string.releases_latest'))
                  .fontSize(12)
                  .fontColor($r('app.color.success_text'))
                  .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                  .borderRadius(6)
                  .outline({ width: 1.5, color: $r('app.color.success_text'), radius: 6, style: OutlineStyle.SOLID })
              }
              Row({ space: 8 }) {
                if (this.releases[0].authorAvatar !== '') {
                  Image(this.releases[0].authorAvatar)
                    .width(22)
                    .height(22)
                    .borderRadius(11)
                    .backgroundColor($r('app.color.heat_empty'))
                }
                Text(resText(this.getUIContext(), $r('app.string.releases_released_this'),
                  this.timeText(timeParts(this.releases[0].createdAt, Date.now()))))
                  .fontSize($r('app.float.caption_font_size'))
                  .fontColor($r('app.color.text_secondary'))
              }
              .width('100%')

              Divider().color($r('app.color.divider'))

              Column({ space: 6 }) {
                // 官方语义：正文原样渲染（description 自带 What's Changed 标题，自绘会重复——走查修正）
                MarkdownView({
                  html: this.latestBodyHtml,
                  fallbackText: this.releases[0].body,
                  onNavigate: (name: string, param: string) => {
                    this.pathStack.pushPathByName(name, param);
                  }
                })
                Text($r('app.string.releases_view_details'))
                  .fontSize($r('app.float.sub_text_font_size'))
                  .fontColor($r('app.color.link_blue'))
                  .padding({ top: 4, bottom: 4 })
                  .onClick(() => {
                    this.pathStack.pushPathByName('releaseDetail',
                      `${this.owner}/${this.name}/${this.releases[0].tagName}`);
                  })
              }
              .width('100%')
            }
            .alignItems(HorizontalAlign.Start)
            .padding($r('app.float.card_padding'))
            .borderRadius($r('app.float.card_radius'))
            .backgroundColor($r('app.color.card_background'))
            .width('100%')
            .margin({ bottom: 12 })

            Divider().color($r('app.color.divider'))

            // 官方样式：节标题灰色小字（走查修正）
            Text($r('app.string.releases_all'))
              .fontSize($r('app.float.caption_font_size'))
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_secondary'))
              .width('100%')
              .padding({ top: 12, bottom: 4 })

            ForEach(this.releases, (item: ReleaseItem) => {
              this.releaseRow(item)
            }, (item: ReleaseItem) => item.id)
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
            StateView({ empty: true, emptyText: $r('app.string.releases_empty') })
          }
        }
        .padding({ left: 16, right: 16, bottom: 16 })
        .width('100%')
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
      .onScroll((_x: number, y: number): void => { this.scrollShadow = y > 0.001; })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_page'))
  }
}
