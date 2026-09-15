#!/usr/bin/env python3
# -*- coding: utf-8 -*-
'''
排版机械门禁（DESIGN.md §3.1/§3.2）：禁止在 entry/src/main/ets 直接硬编码字号与禁用字重。

拦截两类（与 DESIGN.md 定案一致）：
1. `.fontSize(<纯数字>)` 字面量 —— 字号必须走 resources/base/element/float.json（$r 引用）。
2. `.fontWeight(FontWeight.Bold)` / `.fontWeight(700)` —— 官方字重上限 semibold 600，
   Bold=700 禁用（标题/强调一律 600）。

豁免：行内标注 `// typography-exempt`（装饰字形 emoji、OAuth 码展示位、走查定案的局部黑体）。
注释（// 与 /* */）中的字面量不报；豁免标记在原始行匹配（注释剥离前）。
用法：python3 scripts/check-hardcoded-fontsize.py
退出码：0 = 通过；1 = 发现违规。
'''

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ETS_DIR = ROOT / 'entry/src/main/ets'

MARKER = 'typography-exempt'

# `.fontSize(12)` / `.fontSize(1.5)` 纯数字字面量（动态表达式与 $r 引用不匹配）
FONT_SIZE_RE = re.compile(r'\.fontSize\(\s*(\d+(?:\.\d+)?)\s*\)')
# `FontWeight.Bold`（=700）与数字 700
WEIGHT_RE = re.compile(r'\.fontWeight\(\s*(?:FontWeight\.Bold|700)\s*\)')


def strip_comments(text: str) -> str:
    '''把 // 行注释与 /* */ 块注释替换为等长空格（保留换行与列号）。'''
    out = list(text)
    i = 0
    n = len(out)
    in_block = False
    while i < n:
        if in_block:
            if out[i] == '*' and i + 1 < n and out[i + 1] == '/':
                out[i] = ' '
                out[i + 1] = ' '
                i += 2
                in_block = False
            else:
                if out[i] != '\n':
                    out[i] = ' '
                i += 1
        else:
            if out[i] == '/' and i + 1 < n and out[i + 1] == '/':
                while i < n and out[i] != '\n':
                    out[i] = ' '
                    i += 1
            elif out[i] == '/' and i + 1 < n and out[i + 1] == '*':
                out[i] = ' '
                out[i + 1] = ' '
                i += 2
                in_block = True
            else:
                i += 1
    return ''.join(out)


def main() -> int:
    if not ETS_DIR.is_dir():
        print(f'[check-hardcoded-fontsize] 目录不存在: {ETS_DIR}')
        return 1

    violations = []
    exempt_count = 0
    files = sorted(ETS_DIR.rglob('*.ets'))
    if not files:
        print('[check-hardcoded-fontsize] 未找到 .ets 文件')
        return 1

    for path in files:
        rel = path.relative_to(ETS_DIR).as_posix()
        raw_lines = path.read_text(encoding='utf-8').splitlines(keepends=True)
        cleaned_lines = strip_comments(''.join(raw_lines)).splitlines(keepends=True)
        for idx, cleaned in enumerate(cleaned_lines):
            raw = raw_lines[idx] if idx < len(raw_lines) else ''
            line_no = idx + 1
            hits = list(FONT_SIZE_RE.finditer(cleaned)) + list(WEIGHT_RE.finditer(cleaned))
            if not hits:
                continue
            if MARKER in raw:
                exempt_count += 1
                continue
            for m in hits:
                violations.append(f'  {rel}:{line_no}  {m.group(0).strip()}')

    if violations:
        print('[check-hardcoded-fontsize] 发现违规（字号走 float.json $r；字重上限 600）：')
        for v in violations:
            print(v)
        print(f'\n共 {len(violations)} 处。装饰字形/走查定案例外：行内标注 // {MARKER}'
              f'（当前已标注 {exempt_count} 处）。详见 DESIGN.md §3.1/§3.2。')
        return 1

    print(f'[check-hardcoded-fontsize] 通过（{len(files)} 个 .ets 文件，0 处违规，'
          f'豁免标注 {exempt_count} 处）')
    return 0


if __name__ == '__main__':
    sys.exit(main())
