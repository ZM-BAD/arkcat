/**
 * 代码查看选项页（Spec 033）：5 开关 + 字号滑杆 + 固定示例 Preview。
 * Always use dark theme 仅控制代码查看器自身明暗，与 App 三态暗黑（Spec 026）解耦。
 */
import { promptAction } from '@kit.ArkUI';
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { OctIcon } from '../components/OctIcon';
import { PageShadowBar } from '../components/PageShadowBar';
import {
  CODE_LIGHT_BG, CODE_LIGHT_TEXT, CODE_LIGHT_KEYWORD, CODE_LIGHT_FUNC, CODE_LIGHT_COMMENT,
  CODE_DARK_BG, CODE_DARK_TEXT, CODE_DARK_KEYWORD, CODE_DARK_FUNC, CODE_DARK_COMMENT,
  CodeSpan, CodeLine
} from '../utils/CodeTheme';

const PREFS_NAME = 'starraft_settings';
const FONT_MIN = 12;
const FONT_MAX = 20;
const FONT_DEFAULT = 16;
const SAMPLE_PATH = 'n/code-scanning/new/README.md';

@ComponentV2
export struct CodeOptionsView {
  @Param pathStack: NavPathStack = new NavPathStack();
  @Local scrollablePath: boolean = true;
  @Local lineNumbers: boolean = true;
  @Local darkTheme: boolean = false;
  @Local overrideFont: boolean = true;
  @Local font: number = FONT_DEFAULT;
  @Local wrapLines: boolean = true;
  /** 偏好加载完成门控：Toggle/Slider 的 isOn/value 仅在创建时生效，须等加载后再渲染 */
  @Local loaded: boolean = false;
  /** 滚动顶部阴影（滚动中显示、回顶消失） */
  @Local scrollShadow: boolean = false;

  aboutToAppear(): void {
    this.loadSettings();
  }

  private loadSettings(): void {
    const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    if (ctx === undefined) {
      return;
    }
    preferences.getPreferences(ctx, PREFS_NAME)
      .then((pref: preferences.Preferences) => {
        this.scrollablePath = pref.getSync('code_scrollable_path', true) as boolean;
        this.lineNumbers = pref.getSync('code_line_numbers', true) as boolean;
        this.darkTheme = pref.getSync('code_dark_theme', false) as boolean;
        this.overrideFont = pref.getSync('code_override_font', true) as boolean;
        this.font = pref.getSync('code_font_size', FONT_DEFAULT) as number;
        this.wrapLines = pref.getSync('code_wrap_lines', true) as boolean;
        this.loaded = true;
      })
      .catch(() => {
      });
  }

  private saveSetting(key: string, value: string | number | boolean): void {
    const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    if (ctx === undefined) {
      return;
    }
    preferences.getPreferences(ctx, PREFS_NAME)
      .then((pref: preferences.Preferences) => {
        pref.putSync(key, value);
        pref.flushSync();
      })
      .catch(() => {
      });
  }

  private featureComing(): void {
    promptAction.showToast({ message: $r('app.string.settings_feature_coming') });
  }

  private codeBg(): string {
    return this.darkTheme ? CODE_DARK_BG : CODE_LIGHT_BG;
  }

  private codeText(): string {
    return this.darkTheme ? CODE_DARK_TEXT : CODE_LIGHT_TEXT;
  }

  private keywordColor(): string {
    return this.darkTheme ? CODE_DARK_KEYWORD : CODE_LIGHT_KEYWORD;
  }

  private funcColor(): string {
    return this.darkTheme ? CODE_DARK_FUNC : CODE_LIGHT_FUNC;
  }

  private commentColor(): string {
    return this.darkTheme ? CODE_DARK_COMMENT : CODE_LIGHT_COMMENT;
  }

  /** 固定示例：GitHub 截图同款 fibonacci 片段（注释行用于演示换行） */
  private sampleLines(): CodeLine[] {
    const kw = (t: string): CodeSpan => new CodeSpan(t, this.keywordColor());
    const fn = (t: string): CodeSpan => new CodeSpan(t, this.funcColor());
    const cm = (t: string): CodeSpan => new CodeSpan(t, this.commentColor());
    const pl = (t: string): CodeSpan => new CodeSpan(t, this.codeText());
    return [
      new CodeLine([kw('def'), pl(' fibonacci'), pl('(n)')]),
      new CodeLine([cm('// A long comment demonstrating the effects of the line wrapping option.')]),
      new CodeLine([kw('return'), pl(' n '), kw('if'), pl(' (0..1).include? n')]),
      new CodeLine([pl('('), fn('fibonacci'), pl('(n-1) + '), fn('fibonacci'), pl('(n-2))')]),
      new CodeLine([kw('end')])
    ];
  }

  /** 分组标题 */
  @Builder
  sectionTitle(labelRes: Resource) {
    Text(labelRes)
      .fontSize($r('app.float.caption_font_size'))
      .fontColor($r('app.color.text_secondary'))
      .width('100%')
      .padding({ left: 4, bottom: 4 })
      .margin({ top: 12 })
  }

  /** 开关行（卡片 + 原生 Switch） */
  @Builder
  toggleRow(labelRes: Resource, isOn: boolean, key: string) {
    Row() {
      Text(labelRes)
        .fontSize($r('app.float.body_font_size'))
        .fontColor($r('app.color.text_primary'))
      Blank()
      Toggle({ type: ToggleType.Switch, isOn: isOn })
        .selectedColor($r('app.color.link_blue'))
        .onChange((checked: boolean) => {
          this.applySwitch(key, checked);
        })
    }
    .width('100%')
    .height(52)
    .padding({ left: 16, right: 16 })
    .backgroundColor($r('app.color.card_background'))
    .borderRadius(12)
    .margin({ bottom: 2 })
  }

  /** 开关 key → 状态字段回写 + 持久化（避免重渲染时 Switch 回弹） */
  private applySwitch(key: string, checked: boolean): void {
    switch (key) {
      case 'code_scrollable_path':
        this.scrollablePath = checked;
        break;
      case 'code_line_numbers':
        this.lineNumbers = checked;
        break;
      case 'code_dark_theme':
        this.darkTheme = checked;
        break;
      case 'code_override_font':
        this.overrideFont = checked;
        break;
      case 'code_wrap_lines':
        this.wrapLines = checked;
        break;
      default:
        break;
    }
    this.saveSetting(key, checked);
  }

  /** 单行代码：行号（可选）+ 着色 TextSpan */
  @Builder
  codeLine(idx: number, line: CodeLine) {
    Row() {
      if (this.lineNumbers) {
        Text(idx + 1 + '')
          .width(28)
          .fontFamily('monospace')
          .textAlign(TextAlign.End)
          .fontSize(this.font)
          .fontColor(this.commentColor())
          .padding({ right: 10 })
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
      .fontColor(this.codeText())
      .lineHeight(this.font * 1.5)
      .maxLines(this.wrapLines ? 100 : 1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
  }

  build() {
    Column() {
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
        Text($r('app.string.settings_code_options'))
          .fontSize($r('app.float.title_font_size'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Blank()
      }
      .width('100%')
      .height(48)
      .padding({ left: 0, right: 0 })

      PageShadowBar({ show: this.scrollShadow })

      Scroll() {
        if (this.loaded) {
          Column() {
            this.toggleRow($r('app.string.settings_code_scrollable_path'), this.scrollablePath, 'code_scrollable_path')
          this.toggleRow($r('app.string.settings_code_line_numbers'), this.lineNumbers, 'code_line_numbers')
          this.toggleRow($r('app.string.settings_code_dark_theme'), this.darkTheme, 'code_dark_theme')
          this.toggleRow($r('app.string.settings_code_override_font'), this.overrideFont, 'code_override_font')

          if (this.overrideFont) {
            Row({ space: 12 }) {
              Text('A')
                .fontSize(12)
                .fontColor($r('app.color.text_secondary'))
              Slider({ value: this.font, min: FONT_MIN, max: FONT_MAX, step: 1 })
                .layoutWeight(1)
                .selectedColor($r('app.color.link_blue'))
                .onChange((value: number) => {
                  this.font = value;
                  this.saveSetting('code_font_size', value);
                })
              Text('A')
                .fontSize(20)
                .fontColor($r('app.color.text_secondary'))
            }
            .width('100%')
            .height(64)
            .padding({ left: 16, right: 16 })
            .backgroundColor($r('app.color.card_background'))
            .borderRadius(12)
            .margin({ bottom: 2 })
          }

          this.toggleRow($r('app.string.settings_code_wrap_lines'), this.wrapLines, 'code_wrap_lines')

          this.sectionTitle($r('app.string.settings_preview'))

          Column() {
            // 路径行：折叠箭头 + 固定示例路径 + 外壳按钮（占位）+ 更多
            Row({ space: 8 }) {
              OctIcon({ res: $r('app.media.oct_chevron_down_16'), iconSize: 14, iconColor: $r('app.color.text_secondary') })
              Scroll() {
                Text(SAMPLE_PATH)
                  .fontSize(14)
                  .fontColor($r('app.color.text_primary'))
              }
              .scrollable(ScrollDirection.Horizontal)
              .scrollBar(BarState.Off)
              .layoutWeight(1)
              Row()
                .width(20)
                .height(20)
                .borderRadius(6)
                .border({ width: 1.5, color: $r('app.color.link_blue') })
                .onClick(() => {
                  this.featureComing();
                })
              Stack() {
                OctIcon({ res: $r('app.media.oct_kebab_horizontal_16'), iconSize: 16, iconColor: $r('app.color.text_secondary') })
              }
.width(44)
.height(44)
              .padding(4)
        .accessibilityDescription($r('app.string.a11y_more'))
        .focusable(true)
              .onClick(() => {
                this.featureComing();
              })
            }
            .width('100%')
            .padding({ left: 12, right: 12, top: 8, bottom: 8 })

            Divider()
              .color($r('app.color.divider'))

            Column({ space: 2 }) {
              ForEach(this.sampleLines(), (line: CodeLine, idx: number) => {
                this.codeLine(idx, line)
              }, (line: CodeLine, idx: number) => `${this.darkTheme ? 'd' : 'l'}-${idx}-${line.spans.length}`)
            }
            .width('100%')
            .padding({ left: 12, right: 12, top: 10, bottom: 10 })
            .backgroundColor(this.codeBg())
          }
          .width('100%')
          .borderRadius(12)
          .backgroundColor($r('app.color.card_background'))

          Row()
            .height(24)
          }
          .padding({ left: 16, right: 16 })
          .width('100%')
        }
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
      .onScroll((_x: number, y: number): void => { this.scrollShadow = y > 0.001; })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_page'))
  }
}
