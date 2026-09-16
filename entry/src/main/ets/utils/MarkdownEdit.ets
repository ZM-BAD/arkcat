/**
 * Markdown 快捷工具栏插入逻辑（Spec 041）：纯函数，输入 TextArea 文本+选区，
 * 输出插入后文本与光标位置（测试 9 断言用）。ArkTS 严格类型，无 DOM 依赖。
 */

export type MarkdownToolKind = 'bold' | 'italic' | 'code' | 'quote' | 'link' | 'strike' | 'task'
  | 'image' | 'mention' | 'list' | 'heading' | 'codeblock';

export interface MarkdownInsert {
  text: string;
  selStart: number;
  selEnd: number;
}

export class MarkdownEdit {
  /** 包裹式（bold/italic/code/strike）：选中被包裹并全选；未选中插入对，光标居中 */
  static wrap(text: string, selStart: number, selEnd: number, prefix: string, suffix: string): MarkdownInsert {
    if (selStart > selEnd) {
      const t = selStart;
      selStart = selEnd;
      selEnd = t;
    }
    const selected = text.substring(selStart, selEnd);
    const result = text.substring(0, selStart) + prefix + selected + suffix + text.substring(selEnd);
    if (selected === '') {
      return { text: result, selStart: selStart + prefix.length, selEnd: selStart + prefix.length };
    }
    return { text: result, selStart: selStart, selEnd: selEnd + prefix.length + suffix.length };
  }

  /** 行前缀式（quote/task）：选区每行加前缀；未选中在光标处插入前缀 */
  static prefixLines(text: string, selStart: number, selEnd: number, prefix: string): MarkdownInsert {
    if (selStart > selEnd) {
      const t = selStart;
      selStart = selEnd;
      selEnd = t;
    }
    if (selStart === selEnd) {
      const result = text.substring(0, selStart) + prefix + text.substring(selEnd);
      return { text: result, selStart: selStart + prefix.length, selEnd: selStart + prefix.length };
    }
    // 选区起点对齐到所在行行首（review H6：行中选中时前缀会插进行中间破坏块语法）
    selStart = text.lastIndexOf('\n', selStart - 1) + 1;
    const lines = text.substring(selStart, selEnd).split('\n');
    const prefixed = lines.map((l: string) => prefix + l).join('\n');
    const result = text.substring(0, selStart) + prefixed + text.substring(selEnd);
    return { text: result, selStart: selStart, selEnd: selEnd + prefix.length * lines.length };
  }

  /** 链接：选中 → [text]()，光标进入 ()；未选中 → []()，光标进入 () */
  static link(text: string, selStart: number, selEnd: number): MarkdownInsert {
    if (selStart > selEnd) {
      const t = selStart;
      selStart = selEnd;
      selEnd = t;
    }
    const selected = text.substring(selStart, selEnd);
    const result = text.substring(0, selStart) + '[' + selected + ']()' + text.substring(selEnd);
    if (selected === '') {
      return { text: result, selStart: selStart + 3, selEnd: selStart + 3 };
    }
    return { text: result, selStart: selEnd + 3, selEnd: selEnd + 3 };
  }

  /** 图片：选中 → ![alt]()，光标进入 ()；未选中 → ![]() */
  static image(text: string, selStart: number, selEnd: number): MarkdownInsert {
    if (selStart > selEnd) {
      const t = selStart;
      selStart = selEnd;
      selEnd = t;
    }
    const selected = text.substring(selStart, selEnd);
    const result = text.substring(0, selStart) + '![' + selected + ']()' + text.substring(selEnd);
    const caret = selected === '' ? selStart + 4 : selEnd + 4;
    return { text: result, selStart: caret, selEnd: caret };
  }

  /** 提及：光标处插入 @（官方工具栏 @ 键） */
  static mention(text: string, selStart: number, selEnd: number): MarkdownInsert {
    if (selStart > selEnd) {
      const t = selStart;
      selStart = selEnd;
      selEnd = t;
    }
    const result = text.substring(0, selStart) + '@' + text.substring(selEnd);
    return { text: result, selStart: selStart + 1, selEnd: selStart + 1 };
  }

  /**
   * 代码块：选区多行 → 每行前加 4 空格缩进包裹的围栏；未选中 → 插入空围栏并把光标放进中间。
   * （官方工具栏 { } 键；用 \`\`\` 围栏 + 语言位留空）
   */
  static codeBlock(text: string, selStart: number, selEnd: number): MarkdownInsert {
    if (selStart > selEnd) {
      const t = selStart;
      selStart = selEnd;
      selEnd = t;
    }
    const fence = '```\n';
    const tail = '\n```';
    const selected = text.substring(selStart, selEnd);
    const result = text.substring(0, selStart) + fence + selected + tail + text.substring(selEnd);
    if (selected === '') {
      const caret = selStart + fence.length;
      return { text: result, selStart: caret, selEnd: caret };
    }
    return { text: result, selStart: selStart, selEnd: selEnd + fence.length + tail.length };
  }

  /**
   * 回复（官方工具栏最后一键 reply）：把「被回复的内容」（PR/Issue 正文，或引用的评论正文）
   * 按 `> line` 引用进光标处，尾随空行方便继续输入；编辑器为空时即为整段引用。
   * source 为空（无正文/编辑既有评论）时不改动文本。
   */
  static reply(text: string, selStart: number, selEnd: number, source: string): MarkdownInsert {
    if (selStart > selEnd) {
      const t = selStart;
      selStart = selEnd;
      selEnd = t;
    }
    if (source.trim() === '') {
      return { text: text, selStart: selStart, selEnd: selEnd };
    }
    const quoted = source.split('\n').map((l: string): string => `> ${l}`).join('\n');
    const block = `${quoted}\n\n`;
    const result = text.substring(0, selStart) + block + text.substring(selEnd);
    const caret = selStart + block.length;
    return { text: result, selStart: caret, selEnd: caret };
  }

  /** 按工具 kind 应用；kind 未匹配返回原样 */
  static apply(text: string, selStart: number, selEnd: number, kind: MarkdownToolKind): MarkdownInsert {
    switch (kind) {
      case 'bold':
        return MarkdownEdit.wrap(text, selStart, selEnd, '**', '**');
      case 'italic':
        return MarkdownEdit.wrap(text, selStart, selEnd, '*', '*');
      case 'code':
        return MarkdownEdit.wrap(text, selStart, selEnd, '`', '`');
      case 'strike':
        return MarkdownEdit.wrap(text, selStart, selEnd, '~~', '~~');
      case 'quote':
        return MarkdownEdit.prefixLines(text, selStart, selEnd, '> ');
      case 'task':
        return MarkdownEdit.prefixLines(text, selStart, selEnd, '- [ ] ');
      case 'link':
        return MarkdownEdit.link(text, selStart, selEnd);
      case 'image':
        return MarkdownEdit.image(text, selStart, selEnd);
      case 'mention':
        return MarkdownEdit.mention(text, selStart, selEnd);
      case 'list':
        return MarkdownEdit.prefixLines(text, selStart, selEnd, '- ');
      case 'heading':
        return MarkdownEdit.prefixLines(text, selStart, selEnd, '# ');
      case 'codeblock':
        return MarkdownEdit.codeBlock(text, selStart, selEnd);
    }
    return { text: text, selStart: selStart, selEnd: selEnd };
  }
}
