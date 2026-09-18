/**
 * Markdown 快捷键工具栏（官方全集，顺序与官方一致）：
 * B / I / 链接 / 图片 / @ / 列表 / 待办(checkbox) / 标题 / 删除线 / 引用 / 行内代码 / 代码块 / 回复(reply)。
 * 横向可滑动（键位多于屏宽）。插入算法在 utils/MarkdownEdit（纯函数），
 * 本组件只发键事件，文本/光标由调用方写回（041 评论与 043 表单共用，Spec 043 §七）。
 */
import { OctIcon } from './OctIcon';

@ComponentV2
export struct MarkdownToolbar {
  /** 是否显示 reply 键（评论场景专属；创建/编辑表单隐藏） */
  @Param showReply: boolean = true;
  /** 键点击（kind 为 MarkdownToolKind 字面量或 'reply'） */
  @Event onTool: (kind: string) => void = (kind: string): void => { };

  @Builder
  toolBtn(iconRes: Resource, kind: string) {
    Stack() {
      OctIcon({ res: iconRes, iconSize: 20, iconColor: $r('app.color.text_primary') })
    }
    .width(40)
    .height(36)
    .responseRegion({ x: -2, y: -6, width: '110%', height: '140%' })
    .onClick(() => this.onTool(kind))
  }

  build() {
    Scroll() {
      Row({ space: 4 }) {
        this.toolBtn($r('app.media.oct_bold_16'), 'bold')
        this.toolBtn($r('app.media.oct_italic_16'), 'italic')
        this.toolBtn($r('app.media.oct_link_16'), 'link')
        this.toolBtn($r('app.media.oct_image_16'), 'image')
        this.toolBtn($r('app.media.oct_mention_16'), 'mention')
        this.toolBtn($r('app.media.oct_list_unordered_16'), 'list')
        this.toolBtn($r('app.media.oct_checkbox_16'), 'task')
        this.toolBtn($r('app.media.oct_heading_16'), 'heading')
        this.toolBtn($r('app.media.oct_strikethrough_16'), 'strike')
        this.toolBtn($r('app.media.oct_quote_16'), 'quote')
        this.toolBtn($r('app.media.oct_code_16'), 'code')
        this.toolBtn($r('app.media.oct_code_square_16'), 'codeblock')
        if (this.showReply) {
          this.toolBtn($r('app.media.oct_reply_16'), 'reply')
        }
      }
      .padding({ left: 12, right: 12 })
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .width('100%')
    .height(48)
    .align(Alignment.Start)
  }
}
