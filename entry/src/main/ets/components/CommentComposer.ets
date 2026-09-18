/**
 * 评论输入面板（Spec 041）：Markdown 快捷键工具栏 + 发布前预览 + 草稿记忆。
 * 由 IssueDetail/PrDetail 底部 COMMENT 按钮经 bindSheet 展开；发布/编辑/预览统一。
 */
import { promptAction } from '@kit.ArkUI';
import { MarkdownView } from './MarkdownView';
import { OctIcon } from './OctIcon';
import { MarkdownToolbar } from './MarkdownToolbar';
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
  /** reply 键引用源（PR/Issue 正文；编辑既有评论时由页面传被回复内容） */
  @Param quoteSource: string = '';
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
  /** 预览区站内链接路由（官方预览里点链接可跳转） */
  @Event onNavigate: (name: string, param: string) => void = (name: string, param: string): void => { };
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

  /** reply 键：引用被回复的内容（正文/评论体由页面传入） */
  private applyReply(): void {
    const ins = MarkdownEdit.reply(this.text, this.selStart, this.selEnd, this.quoteSource);
    this.text = ins.text;
    this.textController.setTextSelection(ins.selStart, ins.selEnd);
    if (this.editingId === '') {
      this.onDraftChange(this.text);
    }
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

  /** 工具栏键分派：插入算法纯函数计算新文本+光标，写入 TextArea 并恢复光标 */
  private onToolbarTool(kind: string): void {
    if (kind === 'reply') {
      this.applyReply();
    } else {
      this.applyTool(kind as MarkdownToolKind);
    }
  }

  /** Edit / Preview 页签（等分，选中项蓝色下划线） */
  @Builder
  editorTab(label: ResourceStr, key: string) {
    Column() {
      Text(label)
        .fontSize($r('app.float.sub_text_font_size'))
        .fontColor($r('app.color.text_primary'))
      Row()
        .width('100%')
        .height(2)
        .backgroundColor(this.mode === key ? $r('app.color.link_blue') : Color.Transparent)
        .margin({ top: 10 })
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
    .padding({ top: 8 })
    .onClick((): void => {
      if (this.mode !== key) {
        this.togglePreview();
      }
    })
  }

  build() {
    Column() {
      // 头部：✕ 关闭 + 标题 + 蓝色纸飞机发送（官方 Comment 页）
      Row({ space: 4 }) {
        Stack() {
          OctIcon({ res: $r('app.media.oct_x_24'), iconSize: 20, iconColor: $r('app.color.text_primary') })
        }
        .width(44)
        .height(44)
        .accessibilityDescription($r('app.string.a11y_back'))
        .onClick((): void => this.onClose())
        Text(this.editingId !== ''
          ? this.stringOf($r('app.string.comment_edit_title'))
          : this.stringOf($r('app.string.comment_button')))
          .fontSize($r('app.float.title_font_size'))
          .fontWeight(600)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
        Stack() {
          OctIcon({
            res: $r('app.media.oct_paper_airplane_16'),
            iconSize: 20,
            iconColor: this.submitting ? $r('app.color.text_tertiary') : $r('app.color.link_blue')
          })
        }
        .width(44)
        .height(44)
        .accessibilityDescription($r('app.string.comment_publish'))
        .onClick((): void => this.publish())
      }
      .width('100%')
      .padding({ left: 4, right: 4 })

      // Edit / Preview 页签 + 全幅细分隔线
      Row() {
        this.editorTab($r('app.string.comment_tab_edit'), 'write')
        this.editorTab($r('app.string.comment_preview'), 'preview')
      }
      .width('100%')
      Divider()
        .color($r('app.color.divider'))
        .strokeWidth(1)
        .width('100%')

      if (this.mode === 'write') {
        TextArea({
          text: this.text,
          placeholder: this.stringOf($r('app.string.comment_placeholder')),
          controller: this.textController
        })
          .fontSize($r('app.float.sub_text_font_size'))
          .fontColor($r('app.color.text_primary'))
          .placeholderFont({ size: $r('app.float.sub_text_font_size') })
          .placeholderColor($r('app.color.text_tertiary'))
          .backgroundColor(Color.Transparent)
          .borderRadius(0)
          .width('100%')
          .layoutWeight(1)
          .padding({ left: 16, right: 16, top: 12 })
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
        // 工具条贴着输入区底部 → 键盘弹起时正好位于键盘上方
        MarkdownToolbar({ showReply: true, onTool: (kind: string): void => this.onToolbarTool(kind) })
      } else {
        Scroll() {
          // 最小高度撑满滚动区：内容不足一屏时 Scroll 会竖直居中 → 顶到顶部（官方预览从首行起排）；
          // 用 minHeight 而非 height，长预览仍按内容增长、外滚可滚到底。
          Column() {
            MarkdownView({
              html: this.previewHtml,
              fallbackText: this.text,
              collapse: false,
              foldThreshold: 0,
              onNavigate: (name: string, param: string) => this.onNavigate(name, param)
            })
          }
          .width('100%')
          .constraintSize({ minHeight: '100%' })
          .justifyContent(FlexAlign.Start)
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .width('100%')
        .padding({ left: 16, right: 16, top: 12 })
      }

      if (this.errorMsg !== '') {
        Text(this.errorMsg)
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.danger_text'))
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 8 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.card_background'))
  }
}
