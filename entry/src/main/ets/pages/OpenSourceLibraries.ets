/**
 * Open Source Libraries 页（Spec 064）：静态开源披露，复刻官方 App 三段式——
 * 引言 → 项目链接清单（系统浏览器打开）→ 分隔线后逐库许可全文（等宽字体）。
 * 正文纯英文（法律文本惯例，用户 2026-09-12 定案）；App Bar 标题走 i18n。
 * 纯静态零网络请求；页脚标注 X 品牌资产（非开源条目）。
 */
import { common } from '@kit.AbilityKit';
import { AppBar } from '../components/AppBar';
import { PageShadowBar } from '../components/PageShadowBar';
import { OPEN_SOURCE_ENTRIES, OpenSourceEntry } from '../models/OpenSourceModels';
import { resText } from '../utils/I18n';

@ComponentV2
export struct OpenSourceLibrariesView {
  @Param pathStack: NavPathStack = new NavPathStack();
  @Local scrollShadow: boolean = false;

  /** 拉起系统浏览器（TokenSetup 同款 viewData want） */
  private openExternal(url: string): void {
    const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    if (ctx === undefined) {
      return;
    }
    ctx.startAbility({
      action: 'ohos.want.action.viewData',
      entities: ['entity.system.browsable'],
      uri: url
    }).catch(() => {
      // 无浏览器可接住时静默（Spec 064 边界 1）
    });
  }

  /** 圆点链接条目：蓝色下划线项目名，点击开源仓库 */
  @Builder
  entryLink(entry: OpenSourceEntry) {
    Row({ space: 8 }) {
      Text('•')
        .fontSize($r('app.float.body_font_size'))
        .fontColor($r('app.color.text_primary'))
      Text(entry.name)
        .fontSize($r('app.float.body_font_size'))
        .fontColor($r('app.color.link_blue'))
        .decoration({ type: TextDecorationType.Underline, color: $r('app.color.link_blue') })
    }
    .width('100%')
    .padding({ top: 4, bottom: 4 })
    .onClick(() => this.openExternal(entry.url))
  }

  /** 逐库许可区块：粗体库名 + 等宽许可全文 */
  @Builder
  licenseSection(entry: OpenSourceEntry) {
    Column({ space: 12 }) {
      Text(entry.name)
        .fontSize($r('app.float.title_font_size'))
        .fontWeight(600)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
      Text(entry.licenseName)
        .fontSize($r('app.float.caption_font_size'))
        .fontFamily('monospace')
        .fontColor($r('app.color.text_primary'))
        .width('100%')
      Text(entry.copyrightLine)
        .fontSize($r('app.float.caption_font_size'))
        .fontFamily('monospace')
        .fontColor($r('app.color.text_primary'))
        .width('100%')
      Text(entry.licenseText)
        .fontSize($r('app.float.caption_font_size'))
        .fontFamily('monospace')
        .fontColor($r('app.color.text_primary'))
        .width('100%')
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  build() {
    Column() {
      AppBar({
        showBack: true,
        title: $r('app.string.settings_open_source'),
        onBack: (): void => {
          this.pathStack.pop();
        }
      })

      PageShadowBar({ show: this.scrollShadow })

      Scroll() {
        Column({ space: 16 }) {
          Text(resText(this.getUIContext(), $r('app.string.open_source_intro')))
            .fontSize($r('app.float.body_font_size'))
            .fontColor($r('app.color.text_primary'))
            .width('100%')

          Column({ space: 4 }) {
            ForEach(OPEN_SOURCE_ENTRIES, (entry: OpenSourceEntry) => {
              this.entryLink(entry)
            }, (entry: OpenSourceEntry) => entry.name)
          }
          .width('100%')

          Divider().color($r('app.color.border'))

          ForEach(OPEN_SOURCE_ENTRIES, (entry: OpenSourceEntry) => {
            Column({ space: 16 }) {
              this.licenseSection(entry)
              Divider().color($r('app.color.border'))
            }
            .width('100%')
          }, (entry: OpenSourceEntry) => entry.name)
        }
        .alignItems(HorizontalAlign.Start)
        .padding($r('app.float.page_padding'))
        .width('100%')
      }
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
      .onScroll((_x: number, y: number): void => {
        this.scrollShadow = y > 0.001;
      })
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_page'))
  }
}
