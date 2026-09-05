/**
 * 评论输入面板（Spec 041）：Markdown 快捷键工具栏 + 发布前预览 + 草稿记忆。
 * 由 IssueDetail/PrDetail 底部 COMMENT 按钮经 bindSheet 展开；发布/编辑/预览统一。
 */
import { promptAction } from '@kit.ArkUI';
import { MarkdownView } from './MarkdownView';
import { RepoSubService } from '../services/RepoSubService';
import { MarkdownService } from '../services/MarkdownService';
import { MarkdownEdit, MarkdownToolKind } from '../utils/MarkdownEdit';
import { ApiError, friendlyError } from '../services/GitHttpClient';
import { resText } from '../utils/I18n';

@ComponentV2
export struct CommentComposer {
  @Param token: string = '';
  /** 发布用 SubjectId（Issue/PR 节点 id） */
  @Param subjectId: string = '';
  /** 编辑模式：非空 = 被编辑评论的 id */
  @Param editingId: string = '';
  /** 打开时预填内容（草稿 / 编辑回填） */
  @Param initial: string = '';
  /** renderMarkdown context（owner/repo，放大为满链接） */
  @Param previewContext: string = '';
  @Local text: string = '';
  @Local mode: string = 'write';
  @Local submitting: boolean = false;
  @Local previewHtml: string = '';
  @Local previewLoading: boolean = false;
  @Local errorMsg: string = '';
  @Local selStart: number = 0;
  @Local selEnd: number = 0;
  @Event onClose: () => void = (): void => { };
  @Event onPublished: () => void = (): void => { };
  /** 草稿实时回传（父级 @Local 保存；取消/关闭后重开恢复） */
  @Event onDraftChange: (text: string) => void = (text: string): void => { };

  private textController: TextAreaController = new TextAreaController();

  aboutToAppear(): void {
    this.text = this.initial;
  }

  @Monitor('initial')
  onInitialChanged(): void {
    this.text = this.initial;
    // 重开时重置预览/错误态，防残留上一次会话内容（review F5）
    this.mode = 'write';
    this.previewHtml = '';
    this.previewLoading = false;
    this.errorMsg = '';
  }

  private stringOf(res: Resource): string {
    return resText(this.getUIContext(), res);
  }

  /** 错误 → 本地化文案（429/403/关闭锁定/其他 GraphQL message） */
  private mapError(e: Error): string {
    if (e instanceof ApiError) {
      if (e.code === 429) {
        return this.stringOf($r('app.string.comment_error_rate_limit'));
      }
      if (e.code === 403) {
        return this.stringOf($r('app.string.comment_error_forbidden'));
      }
      const lower = e.message.toLowerCase();
      if (lower.indexOf('closed') >= 0 || lower.indexOf('locked') >= 0) {
        return this.stringOf($r('app.string.comment_error_closed_locked'));
      }
    }
    return e.message;
  }

  /** 工具栏插入：纯函数计算新文本+光标，写入 TextArea 并恢复光标 */
  private applyTool(kind: MarkdownToolKind): void {
    const ins = MarkdownEdit.apply(this.text, this.selStart, this.selEnd, kind);
    this.text = ins.text;
    this.textController.setTextSelection(ins.selStart, ins.selEnd);
  }

  private togglePreview(): void {
    if (this.mode === 'write') {
      this.mode = 'preview';
      this.loadPreview();
    } else {
      this.mode = 'write';
    }
  }

  private loadPreview(): void {
    if (this.text.trim() === '') {
      this.previewHtml = '';
      return;
    }
    this.previewLoading = true;
    MarkdownService.renderMarkdown(this.token, this.text, this.previewContext)
      .then((html: string) => {
        this.previewHtml = html;
        this.previewLoading = false;
      })
      .catch((e: Error) => {
        this.previewHtml = '';
        this.previewLoading = false;
        // 失败不再静默（review F14）
        this.errorMsg = friendlyError(this.getUIContext(), e);
      });
  }

  /** 发布/保存：空内容客户端拦截；失败保留输入内容并展示错误 */
  private publish(): void {
    if (this.submitting) {
      return;
    }
    const body = this.text.trim();
    if (body === '') {
      this.errorMsg = this.stringOf($r('app.string.comment_empty_body'));
      return;
    }
    const editing = this.editingId !== '';
    this.submitting = true;
    this.errorMsg = '';
    const task = editing
      ? RepoSubService.updateComment(this.token, this.editingId, this.text)
      : RepoSubService.addComment(this.token, this.subjectId, this.text);
    task.then(() => {
      this.submitting = false;
      promptAction.showToast({
        message: editing ? $r('app.string.comment_updated') : $r('app.string.comment_published')
      });
      this.onPublished();
      this.onClose();
    }).catch((e: Error) => {
      this.submitting = false;
      this.errorMsg = this.mapError(e);
    });
  }

  @Builder
  toolBtn(label: string, kind: MarkdownToolKind, bold: boolean = false, strike: boolean = false) {
    Text(label)
      .fontSize($r('app.float.chip_font_size'))
      .fontWeight(bold ? 600 : FontWeight.Medium)
      .fontColor($r('app.color.text_secondary'))
      .textAlign(TextAlign.Center)
      .width(36)
      .height(32)
      .responseRegion({ x: -4, y: -6, width: '122%', height: '138%' })
      .borderRadius(6)
      .decoration(strike ? { type: TextDecorationType.LineThrough, color: $r('app.color.text_secondary') }
        : { type: TextDecorationType.None, color: Color.Transparent })
      .onClick(() => this.applyTool(kind))
  }

  @Builder
  markdownToolbar() {
    Scroll() {
      Row({ space: 2 }) {
        this.toolBtn('B', 'bold', true)
        this.toolBtn('I', 'italic')
        this.toolBtn('❝', 'quote')
        this.toolBtn('🔗', 'link')
        this.toolBtn('`', 'code')
        this.toolBtn('S', 'strike', false, true)
        this.toolBtn('☐', 'task')
        Text('')
          .width(8)
      }
      .padding({ left: 4, right: 8 })
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .width('100%')
    .height(36)
    .backgroundColor($r('app.color.search_chips_row_bg'))
    .borderRadius(6)
  }

  build() {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        Text(this.editingId !== ''
          ? this.stringOf($r('app.string.comment_edit_title'))
          : this.stringOf($r('app.string.comment_button')))
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
        Text(this.mode === 'write' ? $r('app.string.comment_preview') : $r('app.string.comment_write'))
          .fontSize(14)
          .fontColor($r('app.color.link_blue'))
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .onClick(() => this.togglePreview())
      }
      .width('100%')

      if (this.mode === 'write') {
        TextArea({
          text: this.text,
          placeholder: this.stringOf($r('app.string.comment_button')),
          controller: this.textController
        })
          .fontSize($r('app.float.body_font_size'))
          .fontColor($r('app.color.text_primary'))
          .placeholderFont({ size: $r('app.float.body_font_size') })
          .placeholderColor($r('app.color.text_tertiary'))
          .backgroundColor($r('app.color.card_background'))
          .borderRadius(6)
          .border({ width: 1, color: $r('app.color.border') })
          .width('100%')
          .height(140)
          .padding(8)
          .onChange((v: string) => {
            this.text = v;
            if (this.editingId === '') {
              this.onDraftChange(v);
            }
          })
          .onTextSelectionChange((start: number, end: number) => {
            this.selStart = start;
            this.selEnd = end;
          })
        this.markdownToolbar()
      } else {
        if (this.previewHtml !== '') {
          Scroll() {
            MarkdownView({
              html: this.previewHtml,
              fallbackText: this.text,
              collapse: false,
              foldThreshold: 0
            })
          }
          .layoutWeight(1)
          .scrollBar(BarState.Off)
          .width('100%')
        } else {
          Column() {
            if (this.previewLoading) {
              LoadingProgress().width(28).height(28).color($r('app.color.link_blue'))
            } else {
              // 降级文本可滚（review F14：固定 120 高会截断长文）
              Scroll() {
                Text(this.text)
                  .fontSize($r('app.float.body_font_size'))
                  .fontColor($r('app.color.text_secondary'))
                  .width('100%')
              }
              .scrollBar(BarState.Off)
              .width('100%')
              .constraintSize({ minHeight: 120, maxHeight: 320 })
            }
          }
          .width('100%')
          .constraintSize({ minHeight: 120, maxHeight: 320 })
          .justifyContent(FlexAlign.Center)
        }
      }

      if (this.errorMsg !== '') {
        Text(this.errorMsg)
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.danger_text'))
          .width('100%')
      }

      Row({ space: 8 }) {
        Button(this.mode === 'write' ? $r('app.string.comment_preview') : $r('app.string.comment_write'))
          .buttonStyle(ButtonStyleMode.NORMAL)
          .layoutWeight(1)
          .height(40)
          .borderRadius(6)
          .onClick(() => this.togglePreview())
        Button($r('app.string.comment_publish'))
          .buttonStyle(ButtonStyleMode.NORMAL)
          .layoutWeight(2)
          .height(40)
          .borderRadius(6)
          .fontColor(Color.White)
          .backgroundColor($r('app.color.primary'))
          .enabled(!this.submitting)
          .onClick(() => this.publish())
      }
      .width('100%')
    }
    .padding({ left: 16, right: 16, top: 12, bottom: 16 })
    .width('100%')
    .backgroundColor($r('app.color.bg_page'))
  }
}
