/**
 * PR 详情页（Spec 031 + 041）：Merged 徽章 + Changes 卡片 + Status 卡片 + Conversation + 评论输入面板。
 */
import { promptAction } from '@kit.ArkUI';
import { OctIcon } from '../components/OctIcon';
import { MarkdownView } from '../components/MarkdownView';
import { PageShadowBar } from '../components/PageShadowBar';
import { CommentCard } from '../components/CommentCard';
import { CommentComposer } from '../components/CommentComposer';
import { RepoComment, PrDetailPage, StatusCheckItem } from '../models/RepoSubModels';
import { RepoSubService } from '../services/RepoSubService';
import { StateView } from '../components/StateView';
import { githubShortTime, timeParts, TimeParts } from '../utils/Format';
import { resText } from '../utils/I18n';

@ComponentV2
export struct PrDetailView {
  @Param owner: string = '';
  @Param name: string = '';
  @Param number: number = 0;
  @Param token: string = '';
  @Param pathStack: NavPathStack = new NavPathStack();
  @Local detail: PrDetailPage | null = null;
  @Local loading: boolean = true;
  @Local errorMsg: string = '';
  /** Status 卡片 checks 列表展开态 */
  @Local checksOpen: boolean = false;
  /** 滚动顶部阴影（滚动中显示、回顶消失） */
  @Local scrollShadow: boolean = false;
  /** 评论输入面板（Spec 041） */
  @Local composerOpen: boolean = false;
  @Local draft: string = '';
  @Local editingId: string = '';
  @Local editingInitial: string = '';
  /** 评论分页（review B7：>20 条 Load more） */
  @Local commentsCursor: string = '';
  @Local commentsHasNext: boolean = false;
  @Local loadingMore: boolean = false;

  aboutToAppear(): void {
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
      })
      .catch((e: Error) => {
        this.errorMsg = e.message;
        this.loading = false;
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

  /** 展开态每个 check 行的图标：SUCCESS 绿勾 / FAILURE 红叉 / 其余黄点 */
  private checkItemIcon(state: string): Resource {
    if (state === 'SUCCESS') {
      return $r('app.media.oct_check_16');
    }
    if (state === 'FAILURE') {
      return $r('app.media.oct_x_16');
    }
    return $r('app.media.oct_dot_fill_16');
  }

  private checkColor(state: string): ResourceColor {
    if (state === 'SUCCESS') {
      return $r('app.color.success_text');
    }
    if (state === 'FAILURE') {
      return $r('app.color.danger_text');
    }
    return $r('app.color.warning_text');
  }

  @Builder
  sectionTitle(text: string) {
    Text(text)
      .fontSize(16)
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
        Text(`${this.owner}/${this.name} #${this.number}`)
          .fontSize($r('app.float.title_font_size'))
          .fontWeight(600)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        Stack() {
          OctIcon({ res: $r('app.media.oct_share_android_16'), iconSize: 18, iconColor: $r('app.color.link_blue') })
        }
.width(44)
.height(44)
        .padding(6)
        .accessibilityDescription($r('app.string.a11y_share'))
        .focusable(true)
        .onClick(() => {
          promptAction.showToast({ message: $r('app.string.home_feature_coming') });
        })
        Stack() {
          OctIcon({ res: $r('app.media.oct_kebab_horizontal_16'), iconSize: 18, iconColor: $r('app.color.link_blue') })
            .rotate({ angle: 90 })
        }
.width(44)
.height(44)
        .padding(6)
        .accessibilityDescription($r('app.string.a11y_more'))
        .focusable(true)
        .onClick(() => {
          promptAction.showToast({ message: $r('app.string.home_feature_coming') });
        })
      }
      .width('100%')
      .height(48)
      .padding({ left: 0, right: 0 })

      PageShadowBar({ show: this.scrollShadow })

      Scroll() {
        Column() {
          if (this.detail !== null) {
            // 标题 + 徽章
            Column({ space: 8 }) {
              Text(this.detail.title)
                .fontSize(20)
                .fontWeight(600)
                .fontColor($r('app.color.text_primary'))
                .width('100%')
                .lineHeight(28)

              if (this.detail.merged || this.detail.headRefName !== '') {
                Scroll() {
                  Row({ space: 8 }) {
                    if (this.detail.merged) {
                      Row({ space: 4 }) {
                        OctIcon({ res: $r('app.media.oct_git_merge_16'), iconSize: 12, iconColor: Color.White })
                        Text($r('app.string.pr_merged_badge'))
                          .fontSize(12)
                          .fontColor(Color.White)
                      }
                      .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                      .borderRadius(12)
                      .backgroundColor($r('app.color.merged_badge_bg'))
                    }
                    if (this.detail.headRefName !== '') {
                      Text(this.detail.headRefName)
                        .fontSize(12)
                        .fontColor($r('app.color.shortcut_blue_fg'))
                        .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                        .borderRadius(2)
                        .backgroundColor($r('app.color.shortcut_blue_bg'))
                      if (this.detail.baseRefName !== '') {
                        Text('→')
                          .fontSize(12)
                          .fontColor($r('app.color.text_primary'))
                        Text(this.detail.baseRefName)
                          .fontSize(12)
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

            // Status 卡片
            Column({ space: 8 }) {
              this.sectionTitle(this.stringOf($r('app.string.pr_status_title')))
              // Reviews（黑）· None requested（灰）
              Row({ space: 6 }) {
                OctIcon({ res: $r('app.media.oct_person_16'), iconSize: 14, iconColor: $r('app.color.text_secondary') })
                Text(this.stringOf($r('app.string.pr_reviews')))
                  .fontSize($r('app.float.caption_font_size'))
                  .fontColor($r('app.color.text_primary'))
                Text('·')
                  .fontSize($r('app.float.caption_font_size'))
                  .fontColor($r('app.color.text_tertiary'))
                Text(this.detail.reviewsTotal > 0 ? `${this.detail.reviewsTotal}` : this.stringOf($r('app.string.pr_reviews_none')))
                  .fontSize($r('app.float.caption_font_size'))
                  .fontColor(this.detail.reviewsTotal > 0 ? $r('app.color.text_primary') : $r('app.color.text_secondary'))
              }
              .width('100%')
              // Checks 摘要行：状态色圆圈 + 文案 + chevron；点击展开全部 checks
              Row({ space: 8 }) {
                OctIcon({
                  res: $r('app.media.oct_circle_16'),
                  iconSize: 14,
                  iconColor: this.checkColor(this.detail.checksState)
                })
                Text(this.detail.checksState === 'SUCCESS' ? this.stringOf($r('app.string.pr_all_checks_passed'))
                  : this.stringOf($r('app.string.work_pr_checks_failed')))
                  .fontSize($r('app.float.caption_font_size'))
                  .fontColor($r('app.color.text_primary'))
                Blank()
                OctIcon({
                  res: $r('app.media.oct_chevron_down_16'),
                  iconSize: 14,
                  iconColor: $r('app.color.text_secondary')
                })
                .rotate(this.checksOpen ? { angle: 180 } : { angle: 0 })
              }
              .width('100%')
              .onClick(() => {
                this.checksOpen = !this.checksOpen;
              })
              if (this.checksOpen) {
                ForEach(this.detail.checks, (c: StatusCheckItem) => {
                  Row({ space: 8 }) {
                    OctIcon({ res: this.checkItemIcon(c.state), iconSize: 12, iconColor: this.checkColor(c.state) })
                    Text(c.name)
                      .fontSize($r('app.float.caption_font_size'))
                      .fontColor($r('app.color.text_primary'))
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .layoutWeight(1)
                  }
                  .width('100%')
                  .padding({ left: 22 })
                }, (c: StatusCheckItem) => c.name)
              }
              if (this.detail.merged) {
                // Branch merged 行（紫色 merge icon）
                Row({ space: 8 }) {
                  OctIcon({
                    res: $r('app.media.oct_git_merge_16'),
                    iconSize: 14,
                    iconColor: $r('app.color.shortcut_purple_fg')
                  })
                  Text(this.stringOf($r('app.string.pr_branch_merged')))
                    .fontSize($r('app.float.caption_font_size'))
                    .fontColor($r('app.color.text_primary'))
                }
                .width('100%')
                // 动作人行：ZM-BAD merged commit a1edbd2 into main 13d ago
                if (this.detail.mergeOid !== '' && this.detail.mergedByLogin !== '') {
                  Text() {
                    Span(this.detail.mergedByLogin)
                      .fontColor($r('app.color.text_primary'))
                    Span(` ${this.stringOf($r('app.string.pr_merged_commit_word'))} `)
                      .fontColor($r('app.color.text_secondary'))
                    Span(this.detail.mergeOid)
                      .fontColor($r('app.color.text_primary'))
                    Span(` ${this.stringOf($r('app.string.pr_into_word'))} `)
                      .fontColor($r('app.color.text_secondary'))
                    Span(this.detail.baseRefName)
                      .fontColor($r('app.color.text_secondary'))
                    Span(` ${this.timeText(timeParts(this.detail.mergedAt, Date.now()))} ${this.stringOf($r('app.string.pr_time_ago'))}`)
                      .fontColor($r('app.color.text_secondary'))
                  }
                  .fontSize($r('app.float.caption_font_size'))
                  .width('100%')
                  .padding({ left: 22 })
                }
              }
            }
            .padding($r('app.float.card_padding'))
            .borderRadius($r('app.float.card_radius'))
            .backgroundColor($r('app.color.card_background'))
            .width('100%')
            .margin({ bottom: 12 })

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
                    this.composerOpen = true;
                  },
                  onDelete: (comment: RepoComment) => this.confirmDeleteComment(comment),
                  onReactionChanged: (): void => this.refresh()
                })
              }, (item: RepoComment) => `${item.id}-${item.body.length}`)
              if (this.commentsHasNext) {
                Text($r('app.string.issues_load_more'))
                  .fontSize($r('app.float.body_font_size'))
                  .fontColor($r('app.color.link_blue'))
                  .width('100%')
                  .textAlign(TextAlign.Center)
                  .padding(12)
                  .onClick(() => this.loadMoreComments())
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
          } else if (this.loading || this.errorMsg !== '') {
            StateView({ loading: this.loading, error: this.errorMsg, onRetry: () => this.refresh() })
          }
        }
        .padding({ left: 16, right: 16, bottom: 16 })
        .width('100%')
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
      .onScroll((_x: number, y: number): void => {
        this.scrollShadow = y > 0.001;
      })

      // 底部 COMMENT（Spec 041：展开输入面板）
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
