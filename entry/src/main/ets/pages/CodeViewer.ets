/**
 * 代码文件查看页（Spec 011）：038 File Tree → 点击文件。
 * 行号 + 本地语法着色；行为（行号/字号/换行/明暗）由 Code Options（Spec 033）配置；
 * 头部对齐官方截图：← 文件名 + ⭮ ⚙ ⋮（gear 进 Code Options）。
 */
import { promptAction } from '@kit.ArkUI';
import { pasteboard } from '@kit.BasicServicesKit';
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { OctIcon } from '../components/OctIcon';
import { StateView } from '../components/StateView';
import { CodeLine, CodeSpan, CODE_DARK_BG, CODE_LIGHT_BG, codeTextColorOf } from '../utils/CodeTheme';
import { highlightLine, extOf } from '../utils/Highlight';
import { FileService } from '../services/FileService';
import { FileContent } from '../models/FileModels';
import { resText } from '../utils/I18n';

const PREFS_NAME = 'starraft_settings';
const FONT_DEFAULT = 16;

@ComponentV2
export struct CodeViewerView {
  @Param owner: string = '';
  @Param name: string = '';
  @Param token: string = '';
  @Param pathStack: NavPathStack = new NavPathStack();
  /** 文件路径（路由参数 owner|name|path 解析） */
  @Param filePath: string = '';
  @Local content: string = '';
  @Local lines: CodeLine[] = [];
  @Local loading: boolean = true;
  @Local errorMsg: string = '';
  @Local isBinary: boolean = false;
  @Local isTruncated: boolean = false;
  /** Code Options（Spec 033）行为配置 */
  @Local lineNumbers: boolean = true;
  @Local wrapLines: boolean = true;
  @Local darkTheme: boolean = false;
  @Local overrideFont: boolean = true;
  @Local font: number = FONT_DEFAULT;
  @Local codeBg: ResourceColor = CODE_LIGHT_BG;
  @Local codeText: ResourceColor = $r('app.color.text_primary');
  @Local contentLoaded: boolean = false;
  @Local settingsLoaded: boolean = false;

  aboutToAppear(): void {
    this.loadSettings();
    this.fetchContent();
  }

  private loadSettings(): void {
    const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    if (ctx === undefined) {
      this.settingsLoaded = true;
      this.tryRender();
      return;
    }
    preferences.getPreferences(ctx, PREFS_NAME)
      .then((pref: preferences.Preferences) => {
        this.lineNumbers = pref.getSync('code_line_numbers', true) as boolean;
        this.darkTheme = pref.getSync('code_dark_theme', false) as boolean;
        this.overrideFont = pref.getSync('code_override_font', true) as boolean;
        this.font = pref.getSync('code_font_size', FONT_DEFAULT) as number;
        this.wrapLines = pref.getSync('code_wrap_lines', true) as boolean;
        this.settingsLoaded = true;
        this.tryRender();
      })
      .catch(() => {
        this.settingsLoaded = true;
        this.tryRender();
      });
  }

  private fetchContent(): void {
    this.loading = true;
    this.errorMsg = '';
    FileService.fetchFileContent(this.token, this.owner, this.name, this.filePath)
      .then((fc: FileContent) => {
        this.content = fc.text;
        this.isBinary = fc.isBinary;
        this.isTruncated = fc.isTruncated;
        this.contentLoaded = true;
        this.loading = false;
        this.tryRender();
      })
      .catch((e: Error) => {
        this.errorMsg = e.message;
        this.loading = false;
      });
  }

  /** 内容与设置就绪后计算着色行（避免设置加载竞态） */
  private tryRender(): void {
    if (!this.contentLoaded || !this.settingsLoaded) {
      return;
    }
    const rawLines: string[] = this.content.split('\n');
    const out: CodeLine[] = [];
    let inBlock: boolean = false;
    const ext: string = extOf(this.filePath);
    for (const raw of rawLines) {
      const normalized: string = raw.endsWith('\r') ? raw.substring(0, raw.length - 1) : raw;
      const r = highlightLine(normalized, ext, this.darkTheme, inBlock);
      out.push(r.line);
      inBlock = r.inBlockComment;
    }
    this.lines = out;
    this.codeBg = this.darkTheme ? CODE_DARK_BG : CODE_LIGHT_BG;
    this.codeText = codeTextColorOf(this.darkTheme);
  }

  private stringOf(res: Resource): string {
    return resText(this.getUIContext(), res);
  }

  private fileName(): string {
    const idx = this.filePath.lastIndexOf('/');
    return idx >= 0 ? this.filePath.substring(idx + 1) : this.filePath;
  }

  private blobUrl(): string {
    return `https://github.com/${this.owner}/${this.name}/blob/HEAD/${this.filePath}`;
  }

  private copyText(text: string, okRes: Resource): void {
    const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
    pasteboard.getSystemPasteboard().setData(data)
      .then(() => {
        promptAction.showToast({ message: okRes });
      })
      .catch(() => {
        promptAction.showToast({ message: $r('app.string.file_copy_failed') });
      });
  }

  private menuItems(): MenuElement[] {
    return [
      { value: this.stringOf($r('app.string.file_copy_contents')), action: (): void => {
        this.copyText(this.content, $r('app.string.file_content_copied'));
      } },
      { value: this.stringOf($r('app.string.file_copy_link')), action: (): void => {
        this.copyText(this.blobUrl(), $r('app.string.file_link_copied'));
      } }
    ];
  }

  /** 代码行：行号（可选）+ 着色 Span 列表 */
  @Builder
  codeLine(idx: number, line: CodeLine) {
    Row() {
      if (this.lineNumbers) {
        Text(idx + 1 + '')
          .width(44)
          .fontFamily('monospace')
          .textAlign(TextAlign.End)
          .fontSize(this.font)
          .fontColor(this.codeText)
          .opacity(0.5)
          .padding({ right: 12 })
      } else {
        Row()
          .width(12)
      }
      Text() {
        ForEach(line.spans, (sp: CodeSpan) => {
          Span(sp.text)
            .fontColor(sp.color)
        }, (sp: CodeSpan, i: number) => i + sp.text)
      }
      .fontFamily('monospace')
      .fontSize(this.font)
      .fontColor(this.codeText)
      .lineHeight(this.font * 1.5)
      .maxLines(this.wrapLines ? 100 : 1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
  }

  /** 二进制文件占位 */
  @Builder
  binaryPlaceholder() {
    Column({ space: 10 }) {
      OctIcon({ res: $r('app.media.oct_file_16'), iconSize: 36, iconColor: $r('app.color.text_secondary') })
      Text($r('app.string.file_binary_unsupported'))
        .fontSize($r('app.float.body_font_size'))
        .fontColor($r('app.color.text_secondary'))
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .layoutWeight(1)
  }

  build() {
    Column() {
      // 自绘头部：← 文件名 + 分享/齿轮/更多
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
        Text(this.fileName())
          .fontSize($r('app.float.title_font_size'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        OctIcon({ res: $r('app.media.oct_share_16'), iconSize: 20, iconColor: $r('app.color.text_secondary') })
          .margin({ left: 12 })
        .accessibilityDescription($r('app.string.a11y_share'))
        .focusable(true)
          .onClick(() => {
            this.copyText(this.content, $r('app.string.file_content_copied'));
          })
        OctIcon({ res: $r('app.media.oct_gear_16'), iconSize: 20, iconColor: $r('app.color.text_secondary') })
          .margin({ left: 12 })
        .accessibilityDescription($r('app.string.a11y_settings'))
        .focusable(true)
          .onClick(() => {
            this.pathStack.pushPathByName('codeOptions', '');
          })
        OctIcon({ res: $r('app.media.oct_kebab_vertical_16'), iconSize: 20, iconColor: $r('app.color.text_secondary') })
          .margin({ left: 12 })
          .bindMenu(this.menuItems())
      }
      .width('100%')
      .height(60)
      .padding({ left: 16, right: 16 })

      // 大文件截断提示（GitHub 官方样式黄条）
      if (this.isTruncated) {
        Text($r('app.string.file_truncated_hint'))
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.warning_text'))
          .backgroundColor($r('app.color.checks_pending_bg'))
          .width('100%')
          .padding({ left: 16, right: 16, top: 6, bottom: 6 })
      }

      if (this.loading || this.errorMsg !== '') {
        StateView({ loading: this.loading, error: this.errorMsg, onRetry: (): void => { this.fetchContent(); } })
          .layoutWeight(1)
      } else if (this.isBinary) {
        this.binaryPlaceholder()
      } else {
        Scroll() {
          Column() {
            ForEach(this.lines, (line: CodeLine, index: number) => {
              this.codeLine(index, line)
            }, (line: CodeLine, index: number) => index + '_' + line.spans.length)
            Row()
              .height(16)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding({ left: 4, top: 4 })
        }
        .layoutWeight(1)
        .width('100%')
        .backgroundColor(this.codeBg)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_page'))
  }
}
