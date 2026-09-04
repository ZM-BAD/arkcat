/**
 * Markdown 快捷工具栏插入逻辑（Spec 041）：纯函数，输入 TextArea 文本+选区，
 * 输出插入后文本与光标位置（测试 9 断言用）。ArkTS 严格类型，无 DOM 依赖。
 */

export type MarkdownToolKind = 'bold' | 'italic' | 'code' | 'quote' | 'link' | 'strike' | 'task';

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
    }
    return { text: text, selStart: selStart, selEnd: selEnd };
  }
}
