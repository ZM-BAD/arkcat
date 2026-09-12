#!/usr/bin/env python3
# -*- coding: utf-8 -*-
'''
样式机械门禁：禁止在 entry/src/main/ets 直接硬编码颜色字面量（#RRGGBB / #AARRGGBB）。
颜色必须走 resources/base + dark/element/color.json（$r）或 PrimerTokens.ets 常量。

豁免（数据色板文件，非 UI 样式，允许集中定义；其余一律禁止）：
- utils/CodeTheme.ets            GitHub 官方代码高亮明/暗两套配色
- models/LanguageColors.ets      GitHub linguist 常用语言色（REST 兜底字段缺失时）
- utils/MarkdownPalette.ets      GitHub Markdown 官方明/暗配色（Spec 040，MarkdownView 引用）
- models/ExploreLanguages.ets   Explore 语言筛选全量表（GET /languages 全量 + linguist 色表）

注释（// 与 /* */）中的色值不报；行号保留，便于定位。
用法：python3 scripts/check-hardcoded-colors.py
退出码：0 = 通过；1 = 发现硬编码色。
'''

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ETS_DIR = ROOT / 'entry/src/main/ets'

# 数据色板白名单（相对 entry/src/main/ets 的文件名）
ALLOWED = {'utils/CodeTheme.ets', 'models/LanguageColors.ets', 'utils/MarkdownPalette.ets',
           'models/ExploreLanguages.ets', 'models/AchievementThemeColors.ets'}

# 6 位（#RRGGBB）或 8 位（#AARRGGBB）
HEX_RE = re.compile(r'#[0-9a-fA-F](?:[0-9a-fA-F]{5}|[0-9a-fA-F]{7})\b')


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
        print(f'[check-hardcoded-colors] 目录不存在: {ETS_DIR}')
        return 1

    violations = []
    files = sorted(ETS_DIR.rglob('*.ets'))
    if not files:
        print('[check-hardcoded-colors] 未找到 .ets 文件')
        return 1

    for path in files:
        rel = path.relative_to(ETS_DIR).as_posix()
        if rel in ALLOWED:
            continue
        raw = path.read_text(encoding='utf-8')
        cleaned = strip_comments(raw)
        for m in HEX_RE.finditer(cleaned):
            line_no = cleaned.count('\n', 0, m.start()) + 1
            violations.append(f'  {rel}:{line_no}  {m.group(0)}')

    if violations:
        print('[check-hardcoded-colors] 发现 UI 硬编码颜色（走 color.json / PrimerTokens）：')
        for v in violations:
            print(v)
        print(f'\n共 {len(violations)} 处。豁免白名单（数据色板）：{", ".join(sorted(ALLOWED))}')
        return 1

    print(f'[check-hardcoded-colors] 通过（{len(files)} 个 .ets 文件，0 处硬编码色）')
    return 0


if __name__ == '__main__':
    sys.exit(main())
