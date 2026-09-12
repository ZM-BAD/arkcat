/**
 * Open Source Libraries 页数据（Spec 064）：随 HAP 分发的开源内容披露。
 * 只列实际打进包里的素材——Octicons（图标）与 Primer Design Primitives（设计令牌数据）。
 * 许可正文为英文法律文本，不参与 i18n；Octicons 全文须与 assets/octicons/LICENSE 逐字一致
 * （单测 scripts/ut/unit.test.ts 读文件比对，防双处漂移）。
 */

/** 单条开源披露（官方 notice 页同构：库名 + 仓库链接 + 许可名 + 版权行 + 正文） */
export interface OpenSourceEntry {
  name: string;
  url: string;
  licenseName: string;
  copyrightLine: string;
  licenseText: string;
}

/** MIT 授权正文（标准全文；与 assets/octicons/LICENSE 正文段一致） */
const MIT_BODY: string = 'Permission is hereby granted, free of charge, to any person obtaining a copy\n' +
  'of this software and associated documentation files (the "Software"), to deal\n' +
  'in the Software without restriction, including without limitation the rights\n' +
  'to use, copy, modify, merge, publish, distribute, sublicense, and/or sell\n' +
  'copies of the Software, and to permit persons to whom the Software is\n' +
  'furnished to do so, subject to the following conditions:\n' +
  '\n' +
  'The above copyright notice and this permission notice shall be included in all\n' +
  'copies or substantial portions of the Software.\n' +
  '\n' +
  'THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR\n' +
  'IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,\n' +
  'FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE\n' +
  'AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER\n' +
  'LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,\n' +
  'OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE\n' +
  'SOFTWARE.';

/** Octicons 条目：fullText 与 assets/octicons/LICENSE 逐字一致（单测守护） */
const OCTICONS_FULL_TEXT: string = 'MIT License\n' +
  '\n' +
  'Copyright (c) 2026 GitHub Inc.\n' +
  '\n' +
  MIT_BODY;

/** 披露条目（页面渲染顺序即数组顺序） */
export const OPEN_SOURCE_ENTRIES: OpenSourceEntry[] = [
  {
    name: 'Octicons',
    url: 'https://github.com/primer/octicons',
    licenseName: 'The MIT License (MIT)',
    copyrightLine: 'Copyright (c) 2026 GitHub Inc.',
    licenseText: OCTICONS_FULL_TEXT
  },
  {
    name: 'Primer Design Primitives',
    url: 'https://github.com/primer/primitives',
    licenseName: 'The MIT License (MIT)',
    copyrightLine: 'Copyright (c) GitHub, Inc.',
    licenseText: 'MIT License\n' +
      '\n' +
      'Copyright (c) GitHub, Inc.\n' +
      '\n' +
      MIT_BODY
  }
];
