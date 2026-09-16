/**
 * PR 详情页（Spec 031 + 041 + 042）：Merged 徽章 + Changes 卡片 + Status 卡片 + Conversation +
 * 审阅列表 + ReviewThreads + 评论输入面板 + Review changes 三态审阅面板。
 */
import { promptAction } from '@kit.ArkUI';
import { AppBar, AppBarAction, AppBarActionCfg } from '../components/AppBar';
import { OctIcon } from '../components/OctIcon';
import { MarkdownView } from '../components/MarkdownView';
import { PageShadowBar } from '../components/PageShadowBar';
import { CommentCard } from '../components/CommentCard';
import { CommentComposer } from '../components/CommentComposer';
import { PrStatusCard } from '../components/PrStatusCard';
import { ReviewThreadsCard } from '../components/ReviewThreadsCard';
import { RepoComment, PrDetailPage, PrReview, reviewStateKey } from '../models/RepoSubModels';
import { RepoSubService } from '../services/RepoSubService';
import { StateView } from '../components/StateView';
import { ListLoadingFooter } from '../components/ListLoadingFooter';
import { githubShortTime, timeParts, TimeParts } from '../utils/Format';
import { resText } from '../utils/I18n';
import { pullPageUrl, shareLink } from '../utils/Share';

@ComponentV2
export struct PrDetailView {
  @Param owner: string = '';
  @Param name: string = '';
  @Param number: number = 0;
  @Param token: string = '';
  @Param pathStack: NavPathStack = new NavPathStack();
  /** 路由 onShown 递增：从 prFiles（行内评论）返回时重拉 threads */
  @Param refreshTick: number = 0;
  @Local detail: PrDetailPage | null = null;
  @Local loading: boolean = true;
  @Local errorMsg: string = '';
  /** 滚动顶部阴影（滚动中显示、回顶消失） */
  @Local scrollShadow: boolean = false;
  @Local isRefreshing: boolean = false;
  /**
   * 评论/审阅共用弹层（坑 2：同组件多 bindSheet 只有最后一个生效 → 单 sheet + sheetKind 分派）。
   * sheetKind：'composer'=评论输入（041），'review'=审阅三态/编辑（042）。
   */
  @Local sheetOpen: boolean = false;
  @Local sheetKind: string = 'composer';
  @Local draft: string = '';
  @Local editingId: string = '';
  @Local editingInitial: string = '';
  /** 评论分页（review B7：>20 条 Load more） */
  @Local commentsCursor: string = '';
  @Local commentsHasNext: boolean = false;
  @Local loadingMore: boolean = false;
  /** Review changes 面板（Spec 042 元素5）：三态审阅 + 总结 body */
  @Local reviewEvent: string = 'COMMENT';
  @Local reviewBody: string = '';
  @Local reviewSending: boolean = false;
  /** 审阅编辑模式（元素6：复用面板，仅 body 可改） */
  @Local editingReviewId: string = '';
  /** Merge 确认 sheet（Android 官方流：commit message 默认值 + EDIT + MERGE/CANCEL） */
  @Local mergeMethod: string = 'SQUASH';
  @Local mergeHeadline: string = '';
  @Local mergeBody: string = '';
  @Local mergeEditing: boolean = false;
  @Local mergeSending: boolean = false;
  /** 首个 onShown tick 不重拉（aboutToAppear 已拉过） */
  private skipFirstTick: boolean = true;

  aboutToAppear(): void {
    this.refresh();
  }

  @Monitor('refreshTick')
  onTick(): void {
    if (this.skipFirstTick) {
      this.skipFirstTick = false;
      return;
    }
    this.refresh();
  }

  private refresh(): void {
    this.loading = true;
    this.errorMsg = '';
    RepoSubService.fetchPrDetail(this.token, this.owner, this.name, this.number, '')
      .then((page: PrDetailPage) => {
        this.detail = page;
        this.commentsHasNext = page.commentsHasNext;
        this.commentsCursor = page.commentsCursor;
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

  /** 追加下一批评论（review B7：只拼接不整页替换） */
  private loadMoreComments(): void {
    if (!this.commentsHasNext || this.loadingMore || this.detail === null) {
      return;
    }
    this.loadingMore = true;
    RepoSubService.fetchPrDetail(this.token, this.owner, this.name, this.number, this.commentsCursor)
      .then((page: PrDetailPage) => {
        const prev = this.detail;
        if (prev !== null) {
          // 合并进新页对象后整体重赋值，触发 UI 刷新（同 B4 模式）
          page.comments = prev.comments.concat(page.comments);
          this.detail = page;
        }
        this.commentsHasNext = page.commentsHasNext;
        this.commentsCursor = page.commentsCursor;
        this.loadingMore = false;
      })
      .catch((e: Error) => {
        this.loadingMore = false;
        promptAction.showToast({ message: e.message });
      });
  }

  private stringOf(res: Resource): string {
    return resText(this.getUIContext(), res);
  }

  private timeText(parts: TimeParts | null): string {
    return parts !== null ? githubShortTime(parts) : '';
  }

  @Builder
  sectionTitle(text: string) {
    Text(text)
      .fontSize($r('app.float.sub_text_font_size'))
      .fontWeight(600)
      .fontColor($r('app.color.text_primary'))
      .width('100%')
  }

  /** MarkdownView 站内链接路由（正文/评论点击 GitHub 内部链接 → 对应页面） */
  private navigateLink(name: string, param: string): void {
    this.pathStack.pushPathByName(name, param);
  }

  /** COMMENT 按钮（打开输入面板；PR 不限状态可评论） */
  private openComposer(): void {
    if (this.detail === null) {
      return;
    }
    this.editingId = '';
    this.editingInitial = '';
    this.sheetKind = 'composer';
    this.sheetOpen = true;
  }

  /** 关闭面板：清编辑态；新评论草稿保留在 @Local（重开时预填） */
  private closeComposer(): void {
    this.sheetOpen = false;
    this.editingId = '';
    this.editingInitial = '';
  }

  /** 弹层消失（拖拽/遮罩/关闭回调统一入口）：复位两种模式的临时编辑态 */
  private onSheetDismissed(): void {
    this.editingId = '';
    this.editingInitial = '';
    this.editingReviewId = '';
    this.reviewBody = '';
  }

  /** 发布/编辑成功：清草稿并重拉（评论数 +1、新评论可见，服务端为权威） */
  private afterCommentSaved(): void {
    this.draft = '';
    this.refresh();
  }

  /** 打开 Review changes 面板（三态审阅；默认 COMMENT） */
  private openReviewSheet(): void {
    this.editingReviewId = '';
    this.reviewEvent = 'COMMENT';
    this.reviewBody = '';
    this.sheetKind = 'review';
    this.sheetOpen = true;
  }

  /** 打开审阅编辑（元素6：仅本人审阅；只改总结 body） */
  private openReviewEdit(review: PrReview): void {
    this.editingReviewId = review.id;
    this.reviewBody = review.body;
    this.sheetKind = 'review';
    this.sheetOpen = true;
  }

  private closeReviewSheet(): void {
    this.sheetOpen = false;
    this.editingReviewId = '';
    this.reviewBody = '';
  }

  /** 提交三态审阅 / 保存审阅编辑（COMMENT 空总结被服务端拒绝 → 客户端先拦） */
  private submitReview(): void {
    if (this.detail === null || this.reviewSending) {
      return;
    }
    const body = this.reviewBody.trim();
    if (this.editingReviewId !== '') {
      if (body === '') {
        return;
      }
      this.reviewSending = true;
      RepoSubService.updateReview(this.token, this.editingReviewId, body)
        .then(() => {
          this.reviewSending = false;
          this.closeReviewSheet();
          promptAction.showToast({ message: $r('app.string.pr_review_submitted') });
          this.refresh();
        })
        .catch((e: Error) => {
          this.reviewSending = false;
          promptAction.showToast({ message: e.message });
        });
      return;
    }
    if (this.reviewEvent === 'COMMENT' && body === '') {
      promptAction.showToast({ message: $r('app.string.pr_review_need_body') });
      return;
    }
    this.reviewSending = true;
    RepoSubService.submitReview(this.token, this.detail.subjectId, this.reviewEvent, body)
      .then(() => {
        this.reviewSending = false;
        this.closeReviewSheet();
        promptAction.showToast({ message: $r('app.string.pr_review_submitted') });
        this.refresh();
      })
      .catch((e: Error) => {
        this.reviewSending = false;
        promptAction.showToast({ message: e.message });
      });
  }

  /** 打开 Merge 确认 sheet（官方流：默认 commit message，EDIT 可改，MERGE 执行） */
  private openMergeSheet(method: string): void {
    if (this.detail === null) {
      return;
    }
    this.mergeMethod = method;
    this.mergeHeadline = `Merge pull request #${this.detail.number} from ${this.owner}/${this.detail.headRefName}`;
    this.mergeBody = '';
    this.mergeEditing = false;
    this.sheetKind = 'merge';
    this.sheetOpen = true;
  }

  /** 执行合并（确认 sheet 的 MERGE；headline 空则走默认 message） */
  private confirmMerge(): void {
    if (this.detail === null || this.mergeSending) {
      return;
    }
    this.mergeSending = true;
    RepoSubService.mergePullRequest(this.token, this.detail.subjectId, this.mergeMethod,
      this.mergeEditing ? this.mergeHeadline.trim() : '', this.mergeBody)
      .then(() => {
        this.mergeSending = false;
        this.sheetOpen = false;
        promptAction.showToast({ message: $r('app.string.pr_merge_merged') });
        this.refresh();
      })
      .catch((e: Error) => {
        this.mergeSending = false;
        promptAction.showToast({
          message: this.stringOf($r('app.string.pr_merge_failed')) + ': ' + e.message
        });
      });
  }

  /** 审阅状态徽章色：APPROVED 绿 / CHANGES_REQUESTED 红 / 其余灰 */
  private reviewStateColor(state: string): ResourceColor {
    if (state === 'APPROVED') {
      return $r('app.color.success_text');
    }
    if (state === 'CHANGES_REQUESTED') {
      return $r('app.color.danger_text');
    }
    return $r('app.color.text_secondary');
  }

  /** 审阅状态徽章文案键（pr_review_state_*，映射见 models.reviewStateKey） */
  private reviewStateText(state: string): string {
    switch (reviewStateKey(state)) {
      case 'approved':
        return this.stringOf($r('app.string.pr_review_state_approved'));
      case 'changes_requested':
        return this.stringOf($r('app.string.pr_review_state_changes_requested'));
      case 'dismissed':
        return this.stringOf($r('app.string.pr_review_state_dismissed'));
      case 'pending':
        return this.stringOf($r('app.string.pr_review_state_pending'));
      default:
        return this.stringOf($r('app.string.pr_review_state_commented'));
    }
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

  /** 三态单选行（Comment / Approve / Request changes；选中高亮 link_blue） */
  @Builder
  reviewOption(labelRes: Resource, value: string, colorFg: ResourceColor) {
    Row({ space: 10 }) {
      Stack() {
        Circle()
          .width(18)
          .height(18)
          .fill(Color.Transparent)
          .stroke(this.reviewEvent === value ? $r('app.color.link_blue') : $r('app.color.border'))
          .strokeWidth(1.5)
        if (this.reviewEvent === value) {
          Circle()
            .width(10)
            .height(10)
            .fill($r('app.color.link_blue'))
        }
      }
      Text(labelRes)
        .fontSize($r('app.float.body_font_size'))
        .fontColor(this.reviewEvent === value ? $r('app.color.text_primary') : colorFg)
    }
    .width('100%')
    .height(44)
    .onClick((): void => {
      this.reviewEvent = value;
    })
  }

  /** Review changes 面板（Spec 042 元素5/6）：编辑模式=仅总结；三态模式=单选+总结+提交 */
  @Builder
  reviewSheet() {
    Column({ space: 10 }) {
      Text(this.editingReviewId !== '' ? $r('app.string.pr_review_edit') : $r('app.string.pr_review_changes'))
        .fontSize($r('app.float.sub_text_font_size'))
        .fontWeight(600)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
      if (this.editingReviewId === '') {
        this.reviewOption($r('app.string.pr_review_type_comment'), 'COMMENT', $r('app.color.text_primary'))
        this.reviewOption($r('app.string.pr_review_type_approve'), 'APPROVE', $r('app.color.success_text'))
        this.reviewOption($r('app.string.pr_review_type_request'), 'REQUEST_CHANGES', $r('app.color.danger_text'))
        Divider().color($r('app.color.divider'))
      }
      TextArea({
        text: this.reviewBody,
        placeholder: this.stringOf($r('app.string.pr_review_summary_hint'))
      })
        .fontSize($r('app.float.body_font_size'))
        .height(120)
        .borderRadius(6)
        .backgroundColor($r('app.color.input_bg'))
        .onChange((v: string): void => {
          this.reviewBody = v;
        })
      Button(this.editingReviewId !== '' ? $r('app.string.pr_review_save') : $r('app.string.pr_review_submit'))
        .type(ButtonType.Normal)
        .width('100%')
        .height(44)
        .borderRadius(6)
        .backgroundColor($r('app.color.link_blue'))
        .enabled(!this.reviewSending && (this.editingReviewId !== '' || this.reviewEvent !== 'COMMENT'
          || this.reviewBody.trim() !== ''))
        .onClick((): void => this.submitReview())
    }
    .width('100%')
    .height('100%')
    .padding({ left: 16, right: 16, top: 16, bottom: 16 })
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
          new AppBarAction($r('app.media.oct_share_android_16'), (): void => {
            shareLink(this.getUIContext(), pullPageUrl(this.owner, this.name, this.number),
              `${this.owner}/${this.name} #${this.number}`);
          }, { iconColor: $r('app.color.link_blue'), a11y: $r('app.string.a11y_share') }),
          new AppBarAction($r('app.media.oct_kebab_horizontal_16'), (): void => {
            promptAction.showToast({ message: $r('app.string.home_feature_coming') });
          }, { rotate90: true, iconColor: $r('app.color.link_blue'), a11y: $r('app.string.a11y_more') })
        ]
      })

      PageShadowBar({ show: this.scrollShadow })

      Refresh({ refreshing: $$this.isRefreshing }) {
        Scroll() {
          Column() {
            if (this.detail !== null) {
            // 标题 + 徽章
            Column({ space: 8 }) {
              Text(this.detail.title)
                .fontSize($r('app.float.title_font_size'))
                .fontWeight(600)
                .fontColor($r('app.color.text_primary'))
                .width('100%')
                .lineHeight(28)
                .maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis })

              if (this.detail.merged || this.detail.headRefName !== '') {
                Scroll() {
                  Row({ space: 8 }) {
                    if (this.detail.merged) {
                      Row({ space: 4 }) {
                        OctIcon({ res: $r('app.media.oct_git_merge_16'), iconSize: 12, iconColor: Color.White })
                        Text($r('app.string.pr_merged_badge'))
                          .fontSize($r('app.float.caption_font_size'))
                          .fontColor(Color.White)
                      }
                      .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                      .borderRadius(12)
                      .backgroundColor($r('app.color.merged_badge_bg'))
                    }
                    if (this.detail.headRefName !== '') {
                      Text(this.detail.headRefName)
                        .fontSize($r('app.float.caption_font_size'))
                        .fontColor($r('app.color.shortcut_blue_fg'))
                        .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                        .borderRadius(2)
                        .backgroundColor($r('app.color.shortcut_blue_bg'))
                      if (this.detail.baseRefName !== '') {
                        Text('→')
                          .fontSize($r('app.float.caption_font_size'))
                          .fontColor($r('app.color.text_primary'))
                        Text(this.detail.baseRefName)
                          .fontSize($r('app.float.caption_font_size'))
                          .fontColor($r('app.color.shortcut_blue_fg'))
                          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                          .borderRadius(2)
                          .backgroundColor($r('app.color.shortcut_blue_bg'))
                      }
                    }
                  }
                }
                .scrollable(ScrollDirection.Horizontal)
                .scrollBar(BarState.Off)
                .width('100%')
              }

              Row({ space: 8 }) {
                if (this.detail.authorAvatar !== '') {
                  Image(this.detail.authorAvatar)
                    .width(22)
                    .height(22)
                    .borderRadius(11)
                    .backgroundColor($r('app.color.heat_empty'))
                }
                Text(this.detail.authorLogin)
                  .fontSize($r('app.float.caption_font_size'))
                  .fontColor($r('app.color.text_primary'))
                Text(this.timeText(timeParts(this.detail.createdAt, Date.now())))
                  .fontSize($r('app.float.caption_font_size'))
                  .fontColor($r('app.color.text_secondary'))
              }
              .width('100%')

              if (this.detail.body !== '' || this.detail.bodyHTML !== '') {
                Divider().color($r('app.color.divider'))
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

            // Changes 卡片
            Column({ space: 8 }) {
              this.sectionTitle(this.stringOf($r('app.string.pr_changes_title')))
              Row({ space: 8 }) {
                OctIcon({ res: $r('app.media.oct_file_diff_16'), iconSize: 14, iconColor: $r('app.color.text_secondary') })
                Text(resText(this.getUIContext(), $r('app.string.pr_files_changed'), this.detail.filesCount))
                  .fontSize($r('app.float.body_font_size'))
                  .fontColor($r('app.color.text_primary'))
                Blank()
                Text(`+${this.detail.additions}`)
                  .fontSize($r('app.float.caption_font_size'))
                  .fontColor($r('app.color.success_text'))
                Text(`-${this.detail.deletions}`)
                  .fontSize($r('app.float.caption_font_size'))
                  .fontColor($r('app.color.danger_text'))
              }
              .width('100%')
              .onClick(() => {
                this.pathStack.pushPathByName('prFiles', `${this.owner}/${this.name}/${this.number}`);
              })
              Row({ space: 8 }) {
                OctIcon({ res: $r('app.media.oct_git_commit_16'), iconSize: 14, iconColor: $r('app.color.text_secondary') })
                Text(resText(this.getUIContext(), $r('app.string.pr_commits_count'), this.detail.commitsCount))
                  .fontSize($r('app.float.body_font_size'))
                  .fontColor($r('app.color.text_primary'))
                Blank()
                Text(`${this.timeText(timeParts(this.detail.createdAt, Date.now()))} ${this.stringOf($r('app.string.pr_time_ago'))}`)
                  .fontSize($r('app.float.caption_font_size'))
                  .fontColor($r('app.color.text_secondary'))
              }
              .width('100%')
              .onClick(() => {
                this.pathStack.pushPathByName('repoCommits', `${this.owner}/${this.name}/${this.number}`);
              })
            }
            .padding($r('app.float.card_padding'))
            .borderRadius($r('app.float.card_radius'))
            .backgroundColor($r('app.color.card_background'))
            .width('100%')
            .margin({ bottom: 12 })

            // Status 卡片（组件化，checks 展开态自持有；Merge 区块随 detail 刷新）
            PrStatusCard({
              detail: this.detail,
              token: this.token,
              onRefresh: (): void => this.refresh(),
              onMergeTap: (method: string): void => this.openMergeSheet(method)
            })

            // Conversation
            Column({ space: 8 }) {
              this.sectionTitle(this.stringOf($r('app.string.pr_conversation_title')))
              if (this.detail.comments.length === 0) {
                Text($r('app.string.issues_empty'))
                  .fontSize($r('app.float.caption_font_size'))
                  .fontColor($r('app.color.text_secondary'))
              }
              ForEach(this.detail.comments, (item: RepoComment) => {
                CommentCard({
                  comment: item,
                  token: this.token,
                  onNavigate: (name: string, param: string) => this.navigateLink(name, param),
                  onEdit: (comment: RepoComment) => {
                    this.editingId = comment.id;
                    this.editingInitial = comment.body;
                    this.sheetKind = 'composer';
                    this.sheetOpen = true;
                  },
                  onDelete: (comment: RepoComment) => this.confirmDeleteComment(comment),
                  onReactionChanged: (): void => this.refresh()
                })
              }, (item: RepoComment) => `${item.id}-${item.body.length}`)
              // 已提交审阅卡（Spec 042 元素4/6：状态徽章 + 总结 body；仅本人可编辑）
              ForEach(this.detail.reviews, (review: PrReview) => {
                Divider().color($r('app.color.divider'))
                Column({ space: 6 }) {
                  Row({ space: 6 }) {
                    if (review.authorAvatar !== '') {
                      Image(review.authorAvatar)
                        .width(22)
                        .height(22)
                        .borderRadius(11)
                        .backgroundColor($r('app.color.heat_empty'))
                    }
                    Text(review.authorLogin)
                      .fontSize($r('app.float.caption_font_size'))
                      .fontColor($r('app.color.text_primary'))
                    Text(this.reviewStateText(review.state))
                      .fontSize($r('app.float.caption_font_size'))
                      .fontColor(this.reviewStateColor(review.state))
                      .padding({ left: 6, right: 6, top: 1, bottom: 1 })
                      .borderRadius(4)
                      .backgroundColor($r('app.color.heat_empty'))
                    Blank()
                    if (review.viewerDidAuthor && !this.detail?.merged) {
                      Text($r('app.string.pr_review_edit'))
                        .fontSize($r('app.float.caption_font_size'))
                        .fontColor($r('app.color.link_blue'))
                        .onClick((): void => this.openReviewEdit(review))
                    }
                  }
                  .width('100%')
                  if (review.body !== '' || review.bodyHTML !== '') {
                    MarkdownView({
                      html: review.bodyHTML,
                      fallbackText: review.body,
                      onNavigate: (name: string, param: string) => this.navigateLink(name, param)
                    })
                  }
                }
                .width('100%')
                .alignItems(HorizontalAlign.Start)
              }, (review: PrReview) => `${review.id}-${review.body.length}`)
              if (this.commentsHasNext) {
                ListLoadingFooter({ show: this.loadingMore })
              }
              if (this.detail.merged) {
                Button($r('app.string.pr_delete_branch'))
                  .buttonStyle(ButtonStyleMode.NORMAL)
                  .width('100%')
                  .height(40)
                  .fontSize($r('app.float.caption_font_size'))
                  .fontColor($r('app.color.text_secondary'))
                  .backgroundColor($r('app.color.card_background'))
                  .borderRadius(6)
                  .border({ width: 1, color: $r('app.color.border') })
                  .onClick(() => {
                    const ui = this.getUIContext();
                    ui.getPromptAction().showDialog(
                      {
                        message: this.stringOf($r('app.string.pr_delete_branch_confirm')),
                        buttons: [
                          {
                            text: this.stringOf($r('app.string.pr_delete_branch_cancel')),
                            color: $r('app.color.link_blue')
                          },
                          {
                            text: this.stringOf($r('app.string.pr_delete_branch_confirm_delete')),
                            color: $r('app.color.badge_red')
                          }
                        ]
                      },
                      (err, data) => {
                        if (err) {
                          return;
                        }
                        if (data.index === 1) {
                          promptAction.showToast({ message: $r('app.string.home_feature_coming') });
                        }
                      }
                    );
                  })
              }
            }
            .padding($r('app.float.card_padding'))
            .borderRadius($r('app.float.card_radius'))
            .backgroundColor($r('app.color.card_background'))
            .width('100%')

            // ReviewThreads 卡（Spec 042：diff 行内评论集合；重拉后 Resolved 折叠）
            if (this.detail.threads.length > 0) {
              ReviewThreadsCard({
                threads: this.detail.threads,
                token: this.token,
                onRefresh: (): void => this.refresh(),
                onNavigate: (name: string, param: string): void => this.navigateLink(name, param)
              })
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
        this.loadMoreComments();
      })
      .onScroll((_x: number, y: number): void => {
        this.scrollShadow = y > 0.001;
      })
      }
      .layoutWeight(1)
      .onRefreshing((): void => {
        this.isRefreshing = true;
        this.refresh();
      })

      // 底部操作（041 Comment + 042 Review changes；已合并后审阅入口隐藏）
      Row({ space: 10 }) {
        Button($r('app.string.comment_button'))
          .buttonStyle(ButtonStyleMode.NORMAL)
          .layoutWeight(1)
          .height(44)
          .borderRadius(6)
          .onClick(() => this.openComposer())
        if (this.detail !== null && !this.detail.merged) {
          Button($r('app.string.pr_review_changes'))
            .buttonStyle(ButtonStyleMode.NORMAL)
            .layoutWeight(1)
            .height(44)
            .borderRadius(6)
            .fontColor($r('app.color.link_blue'))
            .onClick(() => this.openReviewSheet())
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 8, bottom: 12 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_page'))
    .bindSheet($$this.sheetOpen, this.sheetBuilder(), {
      height: 560,
      showClose: false,
      backgroundColor: $r('app.color.bg_page'),
      dragBar: false,
      onDisappear: (): void => this.onSheetDismissed()
    })
  }

  /** 弹层内容分派（坑 2：单 bindSheet + sheetKind） */
  @Builder
  sheetBuilder() {
    if (this.sheetKind === 'review') {
      this.reviewSheet()
    } else if (this.sheetKind === 'merge') {
      this.mergeSheet()
    } else {
      this.composerSheet()
    }
  }

  /** Merge 确认 sheet（Android 官方流：Commit message · Default + EDIT + MERGE/CANCEL） */
  @Builder
  mergeSheet() {
    Column({ space: 12 }) {
      Row({ space: 8 }) {
        Text($r('app.string.pr_merge_commit_default'))
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_secondary'))
          .layoutWeight(1)
        Text($r('app.string.pr_merge_edit'))
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.link_blue'))
          .onClick((): void => {
            this.mergeEditing = !this.mergeEditing;
          })
      }
      .width('100%')

      if (this.mergeEditing) {
        TextInput({ text: this.mergeHeadline })
          .fontSize($r('app.float.body_font_size'))
          .height(44)
          .borderRadius(6)
          .backgroundColor($r('app.color.input_bg'))
          .onChange((v: string): void => {
            this.mergeHeadline = v;
          })
        TextArea({ text: this.mergeBody })
          .fontSize($r('app.float.caption_font_size'))
          .fontFamily('monospace')
          .height(120)
          .borderRadius(6)
          .backgroundColor($r('app.color.input_bg'))
          .onChange((v: string): void => {
            this.mergeBody = v;
          })
      } else {
        Text(this.mergeHeadline)
          .fontSize($r('app.float.body_font_size'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .width('100%')
        if (this.mergeBody !== '') {
          Text(this.mergeBody)
            .fontFamily('monospace')
            .fontSize($r('app.float.caption_font_size'))
            .fontColor($r('app.color.text_primary'))
            .width('100%')
        }
      }

      Button($r('app.string.pr_merge_button'))
        .type(ButtonType.Normal)
        .width('100%')
        .height(48)
        .fontSize($r('app.float.body_font_size'))
        .fontColor(Color.White)
        .backgroundColor($r('app.color.success_btn_bg'))
        .enabled(!this.mergeSending)
        .onClick((): void => this.confirmMerge())
      Button($r('app.string.pr_delete_branch_cancel'))
        .buttonStyle(ButtonStyleMode.NORMAL)
        .width('100%')
        .height(48)
        .fontSize($r('app.float.body_font_size'))
        .fontColor($r('app.color.link_blue'))
        .backgroundColor($r('app.color.card_background'))
        .borderRadius(6)
        .border({ width: 1, color: $r('app.color.border') })
        .onClick((): void => {
          this.sheetOpen = false;
        })
    }
    .width('100%')
    .height('100%')
    .padding({ left: 16, right: 16, top: 16, bottom: 16 })
  }
}
