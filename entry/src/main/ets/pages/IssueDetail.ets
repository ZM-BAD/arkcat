/**
 * Issue 详情页（Spec 030 + 041）：标题 + 状态 + 正文（纯文本）+ 评论列表 + 底部 COMMENT 输入面板。
 */
import { promptAction } from '@kit.ArkUI';
import { OctIcon } from '../components/OctIcon';
import { AppBar, AppBarAction, AppBarActionCfg } from '../components/AppBar';
import { MarkdownView } from '../components/MarkdownView';
import { PageShadowBar } from '../components/PageShadowBar';
import { CommentCard } from '../components/CommentCard';
import { CommentComposer } from '../components/CommentComposer';
import { RepoComment, IssueDetailPage } from '../models/RepoSubModels';
import { RepoSubService } from '../services/RepoSubService';
import { StateView } from '../components/StateView';
import { ListLoadingFooter } from '../components/ListLoadingFooter';
import { githubShortTime, timeParts, TimeParts } from '../utils/Format';
import { resText } from '../utils/I18n';
import { issuePageUrl, shareLink } from '../utils/Share';

@ComponentV2
export struct IssueDetailView {
  @Param owner: string = '';
  @Param name: string = '';
  @Param number: number = 0;
  @Param token: string = '';
  @Param pathStack: NavPathStack = new NavPathStack();
  @Local detail: IssueDetailPage | null = null;
  @Local cursor: string = '';
  @Local hasNextPage: boolean = false;
  @Local loading: boolean = true;
  @Local errorMsg: string = '';
  /** 滚动顶部阴影（滚动中显示、回顶消失） */
  @Local scrollShadow: boolean = false;
  @Local isRefreshing: boolean = false;
  /** 触底加载更多（底部转圈指示） */
  @Local loadingMore: boolean = false;
  /** 评论输入面板（Spec 041） */
  @Local composerOpen: boolean = false;
  @Local draft: string = '';
  @Local editingId: string = '';
  @Local editingInitial: string = '';

  aboutToAppear(): void {
    this.refresh();
  }

  private refresh(): void {
    this.loading = true;
    this.errorMsg = '';
    RepoSubService.fetchIssueDetail(this.token, this.owner, this.name, this.number, '')
      .then((page: IssueDetailPage) => {
        this.detail = page;
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
    if (!this.hasNextPage || this.loading || this.loadingMore || this.detail === null) {
      return;
    }
    this.loading = true;
    this.loadingMore = true;
    RepoSubService.fetchIssueDetail(this.token, this.owner, this.name, this.number, this.cursor)
      .then((page: IssueDetailPage) => {
        // 翻页只追加评论批次，整页替换会把前 20 条评论顶掉（review B4）
        const prev = this.detail;
        if (prev !== null) {
          page.comments = prev.comments.concat(page.comments);
        }
        this.detail = page;
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

  private timeText(parts: TimeParts | null): string {
    return parts !== null ? githubShortTime(parts) : '';
  }

  private stateIcon(): Resource {
    if (this.detail?.state === 'OPEN') {
      return $r('app.media.oct_issue_opened_16');
    }
    return this.detail?.stateReason === 'NOT_PLANNED'
      ? $r('app.media.oct_skip_16')
      : $r('app.media.oct_issue_closed_16');
  }

  private stateColor(): ResourceColor {
    if (this.detail?.state === 'OPEN') {
      return $r('app.color.success_text');
    }
    return this.detail?.stateReason === 'NOT_PLANNED' ? $r('app.color.text_secondary') : $r('app.color.shortcut_purple_fg');
  }

  /** MarkdownView 站内链接路由（正文/评论点击 GitHub 内部链接 → 对应页面） */
  private navigateLink(name: string, param: string): void {
    this.pathStack.pushPathByName(name, param);
  }

  private stringOf(res: Resource): string {
    return resText(this.getUIContext(), res);
  }

  /** COMMENT 按钮（打开输入面板；锁定/关闭由服务端校验兜底，与官方一致） */
  private openComposer(): void {
    if (this.detail === null) {
      return;
    }
    // GitHub 仅 locked 限制评论，closed 未锁定仍可评论（review B8：移除客户端拦截）
    this.editingId = '';
    this.editingInitial = '';
    this.composerOpen = true;
  }

  /** 关闭面板：清编辑态；新评论草稿保留在 @Local（重开时预填） */
  private closeComposer(): void {
    this.composerOpen = false;
    this.editingId = '';
    this.editingInitial = '';
  }

  /** 发布/编辑成功：清草稿并重拉（评论数 +1、新评论可见，服务端为权威） */
  private afterCommentSaved(): void {
    this.draft = '';
    this.refresh();
  }

  /** 删除确认（仅本人评论有入口）：二次确认 → deleteIssueComment → 刷新 */
  private confirmDeleteComment(item: RepoComment): void {
    this.getUIContext().showAlertDialog({
      title: this.stringOf($r('app.string.comment_delete_title')),
      message: this.stringOf($r('app.string.comment_delete_body')),
      autoCancel: true,
      buttons: [
        {
          value: this.stringOf($r('app.string.comment_delete_cancel')),
          action: (): void => {
          }
        },
        {
          style: DialogButtonStyle.HIGHLIGHT,
          value: this.stringOf($r('app.string.comment_delete_ok')),
          action: (): void => {
            RepoSubService.deleteComment(this.token, item.id)
              .then(() => {
                promptAction.showToast({ message: $r('app.string.comment_deleted') });
                this.refresh();
              })
              .catch((e: Error) => {
                promptAction.showToast({ message: this.stringOf($r('app.string.comment_error_delete')) + ': ' + e.message });
              });
          }
        }
      ]
    });
  }

  @Builder
  composerSheet() {
    CommentComposer({
      token: this.token,
      subjectId: this.detail?.subjectId ?? '',
      editingId: this.editingId,
      initial: this.editingId !== '' ? this.editingInitial : this.draft,
      previewContext: `${this.owner}/${this.name}`,
      onClose: (): void => this.closeComposer(),
      onPublished: (): void => this.afterCommentSaved(),
      onDraftChange: (t: string): void => {
        if (this.editingId === '') {
          this.draft = t;
        }
      }
    })
  }

  build() {
    Column() {
      AppBar({
        showBack: true,
        title: `${this.owner}/${this.name} #${this.number}`,
        onBack: (): void => {
          this.pathStack.pop();
        },
        actions: [
          new AppBarAction($r('app.media.oct_search_24'), (): void => {
            this.pathStack.pushPathByName('search', '');
          }, { iconColor: $r('app.color.text_primary'), a11y: $r('app.string.a11y_search') }),
          new AppBarAction($r('app.media.oct_share_android_16'), (): void => {
            const title = this.detail !== null ? this.detail.title : '';
            shareLink(this.getUIContext(), issuePageUrl(this.owner, this.name, this.number), title);
          }, { a11y: $r('app.string.a11y_share') }),
          new AppBarAction($r('app.media.oct_kebab_horizontal_16'), (): void => {
            promptAction.showToast({ message: $r('app.string.home_feature_coming') });
          }, { rotate90: true, a11y: $r('app.string.a11y_more') })
        ]
      })

      PageShadowBar({ show: this.scrollShadow })

      Refresh({ refreshing: $$this.isRefreshing }) {
        Scroll() {
          Column() {
            if (this.detail !== null) {
            Column({ space: 8 }) {
              Text(this.detail.title)
                .fontSize($r('app.float.title_font_size'))
                .fontWeight(600)
                .fontColor($r('app.color.text_primary'))
                .width('100%')
                .lineHeight(28)
                .maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis })

              Row({ space: 8 }) {
                OctIcon({ res: this.stateIcon(), iconSize: 16, iconColor: this.stateColor() })
                Text(this.detail.authorLogin)
                  .fontSize($r('app.float.caption_font_size'))
                  .fontColor($r('app.color.text_secondary'))
                Text(this.timeText(timeParts(this.detail.createdAt, Date.now())))
                  .fontSize($r('app.float.caption_font_size'))
                  .fontColor($r('app.color.text_secondary'))
              }
              .width('100%')

              if (this.detail.body !== '' || this.detail.bodyHTML !== '') {
                MarkdownView({
                  html: this.detail.bodyHTML,
                  fallbackText: this.detail.body,
                  onNavigate: (name: string, param: string) => this.navigateLink(name, param)
                })
              }
            }
            .padding($r('app.float.card_padding'))
            .borderRadius($r('app.float.card_radius'))
            .backgroundColor($r('app.color.card_background'))
            .width('100%')
            .margin({ bottom: 12 })

            Text(resText(this.getUIContext(), $r('app.string.issue_detail_comments'), this.detail.commentCount))
              .fontSize($r('app.float.sub_text_font_size'))
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary'))
              .width('100%')
              .padding({ bottom: 8 })

            ForEach(this.detail.comments, (item: RepoComment) => {
              CommentCard({
                comment: item,
                token: this.token,
                onNavigate: (name: string, param: string) => this.navigateLink(name, param),
                onEdit: (comment: RepoComment) => {
                  this.editingId = comment.id;
                  this.editingInitial = comment.body;
                  this.composerOpen = true;
                },
                onDelete: (comment: RepoComment) => this.confirmDeleteComment(comment),
                onReactionChanged: (): void => this.refresh()
              })
            }, (item: RepoComment) => `${item.id}-${item.body.length}`)
            if (this.hasNextPage) {
              ListLoadingFooter({ show: this.loadingMore })
            }
          } else if (this.loading || this.errorMsg !== '') {
            StateView({ loading: this.loading, error: this.errorMsg, onRetry: () => this.refresh() })
          }
        }
        .padding({ left: 16, right: 16, bottom: 16 })
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

      // 底部操作栏（COMMENT 展开输入面板，Spec 041）
      Row({ space: 10 }) {
        Button($r('app.string.comment_button'))
          .buttonStyle(ButtonStyleMode.NORMAL)
          .layoutWeight(1)
          .height(44)
          .borderRadius(6)
          .onClick(() => this.openComposer())
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 8, bottom: 12 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_page'))
    .bindSheet($$this.composerOpen, this.composerSheet(), {
      height: 560,
      showClose: false,
      backgroundColor: $r('app.color.bg_page'),
      dragBar: false,
      onDisappear: () => this.closeComposer()
    })
  }
}
