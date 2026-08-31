/**
 * Issues 列表页（Spec 007）：Open/Closed 切换 + 排序 + Label 筛选 + 分页。
 * 点击 Issue 进入详情为 Spec 008 范围，当前提示。
 */
import { promptAction } from '@kit.ArkUI';
import { IssueSummary } from '../models/IssuesModels';
import { IssuesService } from '../services/IssuesService';
import { StateView } from '../components/StateView';
import { relativeTime } from '../utils/Format';

@ComponentV2
export struct IssuesListView {
  @Param owner: string = '';
  @Param name: string = '';
  @Param token: string = '';
  @Param pathStack: NavPathStack = new NavPathStack();
  @Local closed: boolean = false;
  @Local sort: string = 'created';
  @Local label: string = '';
  @Local issues: IssueSummary[] = [];
  @Local repoLabels: string[] = [];
  @Local totalCount: number = 0;
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
    IssuesService.fetchIssues(this.token, this.owner, this.name, this.closed, this.sort, this.label, '')
      .then((page) => {
        this.issues = page.issues;
        this.repoLabels = page.repoLabels;
        this.totalCount = page.totalCount;
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
    IssuesService.fetchIssues(this.token, this.owner, this.name, this.closed, this.sort, this.label, this.cursor)
      .then((page) => {
        this.issues = this.issues.concat(page.issues);
        this.cursor = page.endCursor;
        this.hasNextPage = page.hasNextPage;
        this.loading = false;
      })
      .catch((e: Error) => {
        this.errorMsg = e.message;
        this.loading = false;
      });
  }

  private switchState(closed: boolean): void {
    if (this.closed === closed) {
      return;
    }
    this.closed = closed;
    this.refresh();
  }

  @Builder
  chip(label: string, active: boolean, onClick: () => void) {
    Text(label)
      .fontSize($r('app.float.caption_font_size'))
      .fontColor(active ? Color.White : $r('app.color.text_primary'))
      .padding({ left: 12, right: 12, top: 5, bottom: 5 })
      .borderRadius(12)
      .backgroundColor(active ? $r('app.color.primary') : $r('app.color.card_background'))
      .margin({ right: 8, bottom: 8 })
      .onClick(onClick)
  }

  @Builder
  issueCard(issue: IssueSummary) {
    Column({ space: 6 }) {
      Row({ space: 6 }) {
        Text(issue.state === 'OPEN' ? '🟢' : '🟣')
          .fontSize(12)
        Text(issue.title)
          .fontSize($r('app.float.body_font_size'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        Text(`#${issue.number}`)
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_secondary'))
      }
      .width('100%')

      if (issue.labels.length > 0) {
        Row({ space: 6 }) {
          ForEach(issue.labels, (label: string) => {
            Text(label)
              .fontSize(10)
              .fontColor($r('app.color.link_blue'))
              .padding({ left: 8, right: 8, top: 2, bottom: 2 })
              .borderRadius(8)
              .backgroundColor('#DBEAFE')
          }, (label: string) => label)
        }
      }

      Row({ space: 10 }) {
        Text(`@${issue.authorLogin}`)
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_secondary'))
        Text(relativeTime(issue.createdAt, Date.now()))
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_secondary'))
        if (issue.linkedPrCount > 0) {
          Text(`🔀 ${issue.linkedPrCount}`)
            .fontSize($r('app.float.caption_font_size'))
            .fontColor($r('app.color.text_secondary'))
        }
        Blank()
        Text(`💬 ${issue.commentCount}`)
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_secondary'))
      }
      .width('100%')
    }
    .padding($r('app.float.card_padding'))
    .borderRadius($r('app.float.card_radius'))
    .backgroundColor($r('app.color.card_background'))
    .width('100%')
    .margin({ bottom: 8 })
    .onClick(() => {
      promptAction.showToast({ message: 'Issue 详情将在 Spec 008 提供' });
    })
  }

  build() {
    Column() {
      Row({ space: 8 }) {
        Text('←')
          .fontSize(20)
          .onClick(() => {
            this.pathStack.pop();
          })
        Text('Issues')
          .fontSize($r('app.float.title_font_size'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
        Text('＋')
          .fontSize(20)
          .onClick(() => {
            promptAction.showToast({ message: '新建 Issue 将在后续 Spec 提供' });
          })
      }
      .width('100%')
      .height(48)
      .padding({ left: 16, right: 16 })

      Scroll() {
        Column() {
          // Open/Closed 切换 + 排序
          Row({ space: 8 }) {
            this.chip(this.closed ? 'Closed' : 'Open', true, (): void => this.switchState(!this.closed))
            Blank()
            Text(`排序：${this.sort === 'created' ? '创建时间' : this.sort === 'updated' ? '更新时间' : '评论数'}`)
              .fontSize($r('app.float.caption_font_size'))
              .fontColor($r('app.color.link_blue'))
              .bindMenu([
                { value: '创建时间', action: (): void => { this.sort = 'created'; this.refresh(); } },
                { value: '更新时间', action: (): void => { this.sort = 'updated'; this.refresh(); } },
                { value: '评论数', action: (): void => { this.sort = 'comments'; this.refresh(); } }
              ])
          }
          .width('100%')
          .margin({ bottom: 8 })

          // Label 筛选（单选走 GraphQL，再次点击取消）
          if (this.repoLabels.length > 0) {
            Flex({ wrap: FlexWrap.Wrap }) {
              ForEach(this.repoLabels, (label: string) => {
                this.chip(label, this.label === label, (): void => {
                  this.label = this.label === label ? '' : label;
                  this.refresh();
                })
              }, (label: string) => label)
            }
            .width('100%')
            .margin({ bottom: 8 })
          }

          Text(`${this.totalCount} 个 Issue`)
            .fontSize($r('app.float.caption_font_size'))
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
            .margin({ bottom: 8 })

          if (this.issues.length > 0) {
            ForEach(this.issues, (issue: IssueSummary) => {
              this.issueCard(issue)
            }, (issue: IssueSummary) => issue.id)
            if (this.hasNextPage) {
              Text('加载更多…')
                .fontSize($r('app.float.body_font_size'))
                .fontColor($r('app.color.link_blue'))
                .padding(12)
                .onClick(() => this.loadMore())
            }
          } else {
            StateView({
              loading: this.loading,
              error: this.errorMsg,
              empty: !this.loading && this.errorMsg === '',
              emptyText: '暂无 Issue',
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
