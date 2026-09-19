/**
 * 弹层双态标题头（Discussions 筛选弹层用，Spec 019；2026-09-20 由页内 @Builder 组件化）：
 * 常态=[✕ 标题 🔍]；搜索态=标题**原地**变搜索框（defaultFocus 自动聚焦），
 * 左侧 ✕ 变 ←（回退=清词退出搜索态），框内右端 ✕ 清词。
 * 组件化原因（坑 1）：@Builder 按值传参在弹层分支不重执行时卡旧态，搜索钮翻转无效；
 * @Param 随父刷新（WorkFilterSelectSheet 同模式已验证）。
 */
import { OctIcon } from './OctIcon';

@ComponentV2
export struct DualStateSheetHeader {
  @Param titleRes: Resource = $r('app.string.discussions_filter_by_category');
  @Param searchShow: boolean = false;
  @Param searchText: string = '';
  /** 搜索态输入框占位文案（Filter categories / Filter labels） */
  @Param placeholder: Resource = $r('app.string.discussions_filter_categories');
  /** 非搜索态点 ✕：调用方关弹层 */
  @Event onClose: () => void = (): void => { };
  /** 🔍 与 ← 共用：搜索态开/关切换（← 时调用方已先清词） */
  @Event onToggle: () => void = (): void => { };
  @Event onSearch: (v: string) => void = (v: string): void => { };
  @Event onClear: () => void = (): void => { };

  build() {
    Row() {
      Stack() {
        OctIcon({
          res: this.searchShow ? $r('app.media.oct_arrow_left_24') : $r('app.media.oct_x_16'),
          iconSize: 18,
          iconColor: $r('app.color.text_primary')
        })
      }
      .width(44)
      .height(44)
      .onClick((): void => {
        if (this.searchShow) {
          this.onClear();
          this.onToggle();
        } else {
          this.onClose();
        }
      })
      if (this.searchShow) {
        Stack({ alignContent: Alignment.End }) {
          TextInput({ placeholder: this.placeholder, text: this.searchText })
            .height(40)
            .fontSize($r('app.float.body_font_size'))
            .width('100%')
            .padding({ right: 34 })
            .borderRadius(6)
            .backgroundColor($r('app.color.chip_bg'))
            .defaultFocus(true)
            .onChange((v: string): void => this.onSearch(v))
          if (this.searchText !== '') {
            Stack() {
              OctIcon({ res: $r('app.media.oct_x_16'), iconSize: 14, iconColor: $r('app.color.text_secondary') })
            }
            .width(36)
            .height(36)
            .onClick((): void => this.onClear())
          }
        }
        .layoutWeight(1)
        .margin({ right: 8 })
      } else {
        Text(this.titleRes)
          .fontSize($r('app.float.title_font_size'))
          .fontWeight(600)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
        Stack() {
          OctIcon({ res: $r('app.media.oct_search_24'), iconSize: 18, iconColor: $r('app.color.link_blue') })
        }
        .width(44)
        .height(44)
        .onClick((): void => this.onToggle())
      }
    }
    .padding({ left: 8, right: 8 })
  }
}
