/**
 * Review threads 卡片（Spec 042 元素4/3/7）：diff 行内评论集合。
 * 每条 thread：path:line 头行 + Outdated/Resolved 标签 + Resolve/Unresolve（服务端权限位）+
 * 评论列表（Markdown）+ 回复输入（Resolved 默认折叠；Outdated 禁回复）。
 * threads 变化（重拉）时 @Monitor 重建展开态与草稿数组——Resolved 折叠口径由此保证。
 */
import { promptAction } from '@kit.ArkUI';
import { OctIcon } from './OctIcon';
import { MarkdownView } from './MarkdownView';
import { ReviewThread, ReviewThreadComment } from '../models/RepoSubModels';
import { RepoSubService } from '../services/RepoSubService';
import { githubShortTime, timeParts, TimeParts } from '../utils/Format';
import { resText } from '../utils/I18n';

@ComponentV2
export struct ReviewThreadsCard {
  @Require @Param threads: ReviewThread[];
  @Param token: string = '';
  @Event onRefresh: () => void = (): void => { };
  @Event onNavigate: (name: string, param: string) => void = (name: string, param: string): void => { };
  /** 展开 thread id 集合（未解析默认展开、已解析默认折叠） */
  @Local expandedIds: string[] = [];
  /** 回复草稿（与 threads 下标平行；重拉时重建） */
  @Local replyDrafts: string[] = [];
  @Local replyingId: string = '';
  @Local sending: boolean = false;

  aboutToAppear(): void {
    this.syncFromThreads();
  }

  @Monitor('threads')
  onThreadsChange(): void {
    this.syncFromThreads();
  }

  /** 未解析默认展开、已解析默认折叠（Spec 042 测试4：Resolved 折叠） */
  private syncFromThreads(): void {
    this.expandedIds = this.threads.filter((t: ReviewThread): boolean => !t.isResolved)
      .map((t: ReviewThread): string => t.id);
    this.replyDrafts = this.threads.map((): string => '');
    this.replyingId = '';
  }

  private stringOf(res: Resource): string {
    return resText(this.getUIContext(), res);
  }

  private timeText(parts: TimeParts | null): string {
    return parts !== null ? githubShortTime(parts) : '';
  }

  private isExpanded(thread: ReviewThread): boolean {
    return this.expandedIds.indexOf(thread.id) >= 0;
  }

  private toggleExpanded(thread: ReviewThread): void {
    this.expandedIds = this.isExpanded(thread)
      ? this.expandedIds.filter((id: string): boolean => id !== thread.id)
      : this.expandedIds.concat(thread.id);
  }

  private updateDraft(index: number, value: string): void {
    this.replyDrafts = this.replyDrafts.map((d: string, i: number): string => i === index ? value : d);
  }

  /** 回复 thread（追加评论，服务端权威 → 父级重拉） */
  private sendReply(thread: ReviewThread, index: number): void {
    const body = this.replyDrafts[index].trim();
    if (body === '' || this.sending) {
      return;
    }
    this.sending = true;
    RepoSubService.replyReviewThread(this.token, thread.id, body)
      .then(() => {
        this.sending = false;
        promptAction.showToast({ message: $r('app.string.pr_thread_created') });
        this.onRefresh();
      })
      .catch((e: Error) => {
        this.sending = false;
        promptAction.showToast({ message: e.message });
      });
  }

  /** 解析/取消解析（权限位由服务端下发：viewerCanResolve / viewerCanUnresolve） */
  private toggleResolved(thread: ReviewThread): void {
    if (this.sending) {
      return;
    }
    const resolve = !thread.isResolved;
    this.sending = true;
    RepoSubService.setThreadResolved(this.token, thread.id, resolve)
      .then(() => {
        this.sending = false;
        if (resolve) {
          promptAction.showToast({ message: $r('app.string.pr_thread_resolved') });
        }
        this.onRefresh();
      })
      .catch((e: Error) => {
        this.sending = false;
        promptAction.showToast({ message: e.message });
      });
  }

  @Builder
  tag(text: Resource, colorBg: ResourceColor, colorFg: ResourceColor) {
    Text(text)
      .fontSize($r('app.float.caption_font_size'))
      .fontColor(colorFg)
      .padding({ left: 5, right: 5, top: 1, bottom: 1 })
      .borderRadius(4)
      .backgroundColor(colorBg)
  }

  @Builder
  threadItem(thread: ReviewThread, index: number) {
    Column({ space: 6 }) {
      // 头行：折叠箭头 + path:line + 标签 + Resolve 切换
      Row({ space: 6 }) {
        OctIcon({
          res: this.isExpanded(thread) ? $r('app.media.oct_triangle_down_16') : $r('app.media.oct_triangle_right_16'),
          iconSize: 14,
          iconColor: $r('app.color.text_secondary')
        })
          .width(20)
        Text(thread.line > 0 ? `${thread.path}:${thread.line}` : thread.path)
          .fontFamily('monospace')
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        if (thread.isOutdated) {
          this.tag($r('app.string.pr_thread_outdated'), $r('app.color.heat_empty'),
            $r('app.color.text_secondary'))
        }
        if (thread.isResolved) {
          this.tag($r('app.string.pr_thread_resolved'), $r('app.color.success_subtle_bg'),
            $r('app.color.success_text'))
        }
        if (thread.isResolved ? thread.viewerCanUnresolve : thread.viewerCanResolve) {
          Text(thread.isResolved ? $r('app.string.pr_thread_unresolve') : $r('app.string.pr_thread_resolve'))
            .fontSize($r('app.float.caption_font_size'))
            .fontColor($r('app.color.link_blue'))
            .padding({ left: 6, right: 2, top: 4, bottom: 4 })
            .onClick((): void => this.toggleResolved(thread))
        }
      }
      .width('100%')
      .onClick((): void => this.toggleExpanded(thread))

      if (this.isExpanded(thread)) {
        ForEach(thread.comments, (comment: ReviewThreadComment, commentIndex: number) => {
          Column({ space: 4 }) {
            Row({ space: 6 }) {
              if (comment.authorAvatar !== '') {
                Image(comment.authorAvatar)
                  .width(20)
                  .height(20)
                  .borderRadius(10)
                  .backgroundColor($r('app.color.heat_empty'))
              }
              Text(comment.authorLogin)
                .fontSize($r('app.float.caption_font_size'))
                .fontColor($r('app.color.text_primary'))
              Text(this.timeText(timeParts(comment.createdAt, Date.now())))
                .fontSize($r('app.float.caption_font_size'))
                .fontColor($r('app.color.text_secondary'))
            }
            MarkdownView({
              html: comment.bodyHTML,
              fallbackText: comment.body,
              onNavigate: (name: string, param: string) => this.onNavigate(name, param)
            })
            if (commentIndex < thread.comments.length - 1) {
              Divider().color($r('app.color.divider')).margin({ left: 26 })
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }, (comment: ReviewThreadComment) => `${comment.id}-${comment.body.length}`)

        // 回复输入：Outdated 禁回复（Spec 042 测试9）；Resolved 展开后仍可回复（与官方一致）
        if (!thread.isOutdated) {
          Row({ space: 8 }) {
            TextInput({
              text: this.replyDrafts[index],
              placeholder: this.stringOf($r('app.string.pr_thread_reply_hint'))
            })
              .fontSize($r('app.float.body_font_size'))
              .height(36)
              .borderRadius(6)
              .backgroundColor($r('app.color.input_bg'))
              .layoutWeight(1)
              .onChange((v: string): void => this.updateDraft(index, v))
              .onSubmit((): void => this.sendReply(thread, index))
            Stack() {
              OctIcon({
                res: $r('app.media.oct_paper_airplane_16'), iconSize: 16,
                iconColor: $r('app.color.link_blue')
              })
            }
            .width(36)
            .height(36)
            .accessibilityDescription($r('app.string.a11y_send'))
            .focusable(true)
            .onClick((): void => this.sendReply(thread, index))
          }
          .width('100%')
        }
      }
    }
    .width('100%')
    .padding({ top: 6, bottom: 6 })
  }

  build() {
    Column({ space: 4 }) {
      ForEach(this.threads, (thread: ReviewThread, index: number) => {
        this.threadItem(thread, index)
        Divider().color($r('app.color.divider'))
      }, (thread: ReviewThread) => `${thread.id}-${thread.commentsTotal}-${thread.isResolved}`)
    }
    .padding($r('app.float.card_padding'))
    .borderRadius($r('app.float.card_radius'))
    .backgroundColor($r('app.color.card_background'))
    .width('100%')
    .margin({ bottom: 12 })
  }
}
