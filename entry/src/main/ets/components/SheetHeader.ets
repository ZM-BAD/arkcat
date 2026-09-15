/**
 * 弹层双态标题行（全库统一交互，Spec 068）：
 * 常态=[✕ 标题 🔍]；搜索态=点 🔍 后标题**原地**变搜索框，左侧 ✕ 变 ←
 * （回退=清空搜索词并退出搜索态，由组件内部固定发出 onSearchChange('') + onSearchToggle）。
 * 搜索框右端 ✕ 一键清词、留在搜索态。此前 5 处手写同构头（漂移：图标 16/18、分隔线条件渲染），
 * 差异以参数收口：iconSize、alwaysDivider（常态也渲染分隔线，仓库内列表面板口径）。
 */
import { OctIcon } from './OctIcon';
import { resText } from '../utils/I18n';

@ComponentV2
export struct SheetHeader {
  @Require @Param title: Resource;
  @Param searchShow: boolean = false;
  @Param searchText: string = '';
  @Param searchPlaceholder: Resource = $r('app.string.search_placeholder');
  /** 44 触区内图标尺寸：工作区面板 16、仓库内列表面板 18（历史口径，参数保留防视觉回归） */
  @Param iconSize: number = 16;
  /** true=常态也渲染底部分隔线（仓库内 Issues/PR 面板口径）；false=仅搜索态渲染（工作区面板口径） */
  @Param alwaysDivider: boolean = false;
  /** 非搜索态点 ✕：调用方关弹层 */
  @Event onClose: () => void = (): void => { };
  /** 🔍 与 ← 共用：搜索态开/关切换（← 时组件已先发 onSearchChange('')） */
  @Event onSearchToggle: () => void = (): void => { };
  @Event onSearchChange: (v: string) => void = (v: string): void => { };

  private stringOf(res: Resource): string {
    return resText(this.getUIContext(), res);
  }

  build() {
    Column() {
      Row() {
        Stack() {
          OctIcon({
            res: this.searchShow ? $r('app.media.oct_arrow_left_24') : $r('app.media.oct_x_16'),
            iconSize: this.iconSize,
            iconColor: $r('app.color.text_primary')
          })
        }
        .width(44)
        .height(44)
        .onClick((): void => {
          if (this.searchShow) {
            this.onSearchChange('');
            this.onSearchToggle();
          } else {
            this.onClose();
          }
        })
        if (this.searchShow) {
          Stack({ alignContent: Alignment.End }) {
            TextInput({ placeholder: this.stringOf(this.searchPlaceholder), text: this.searchText })
              .height(40)
              .fontSize($r('app.float.body_font_size'))
              .width('100%')
              .padding({ right: 34 })
              .borderRadius(6)
              .backgroundColor($r('app.color.chip_bg'))
              .defaultFocus(true)
              .onChange((v: string): void => this.onSearchChange(v))
            if (this.searchText !== '') {
              Stack() {
                OctIcon({ res: $r('app.media.oct_x_16'), iconSize: 14, iconColor: $r('app.color.text_secondary') })
              }
              .width(36)
              .height(36)
              .onClick((): void => this.onSearchChange(''))
            }
          }
          .layoutWeight(1)
          .margin({ right: 8 })
        } else {
          Text(this.title)
            .fontSize($r('app.float.title_font_size'))
            .fontWeight(600)
            .fontColor($r('app.color.text_primary'))
            .layoutWeight(1)
          Stack() {
            OctIcon({ res: $r('app.media.oct_search_24'), iconSize: this.iconSize, iconColor: $r('app.color.link_blue') })
          }
          .width(44)
          .height(44)
          .onClick((): void => this.onSearchToggle())
        }
      }
      .padding({ left: 8, right: 8 })
      if (this.searchShow || this.alwaysDivider) {
        Divider()
          .strokeWidth(1)
          .color($r('app.color.divider'))
          .width('100%')
      }
    }
  }
}
