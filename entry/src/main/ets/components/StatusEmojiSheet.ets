/**
 * Select an emoji 子弹层（Spec 076 §二-D）：六列 emoji 网格，当前项高亮，点即生效并关闭（无 SAVE）。
 * 挂在 Edit status 弹层内容上（同组件单 bindSheet + sheetKind 分派），抓取条自绘。
 */
import { OctIcon } from './OctIcon';
import { STATUS_EMOJI_GRID } from '../models/StatusEmojiPalette';

@ComponentV2
export struct StatusEmojiSheet {
  /** 当前选中 emoji 字形（'' = 无） */
  @Param selected: string = '';
  @Event onPick: (emoji: string) => void = (emoji: string): void => { };
  @Event onClose: () => void = (): void => { };

  build() {
    Column() {
      // 自绘抓取条（与建仓弹层同款；框架抓取条在弹层内档位不渲染）
      Row() {
        Row()
          .width(36)
          .height(5)
          .borderRadius(2.5)
          .backgroundColor($r('app.color.text_tertiary'))
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .padding({ top: 8, bottom: 6 })

      Row() {
        Stack() {
          OctIcon({ res: $r('app.media.oct_x_16'), iconSize: 20, iconColor: $r('app.color.text_primary') })
        }
        .width(44)
        .height(44)
        .onClick((): void => this.onClose())
        Text($r('app.string.status_emoji_title'))
          .fontSize($r('app.float.title_font_size'))
          .fontWeight(600)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 8, right: 8 })

      // Grid 自带滚动：不套外层 Scroll（避免嵌套滚动争抢）
      Grid() {
        ForEach(STATUS_EMOJI_GRID, (emoji: string) => {
          GridItem() {
            Stack() {
              Text(emoji)
                .fontSize($r('app.float.title_font_size'))
            }
            .width('100%')
            .height(48)
            .borderRadius(6)
            .border({
              width: 1,
              color: this.selected === emoji ? $r('app.color.link_blue') : Color.Transparent
            })
            .backgroundColor(this.selected === emoji ? $r('app.color.chip_active_bg') : Color.Transparent)
            .onClick((): void => this.onPick(emoji))
          }
        }, (emoji: string) => emoji)
      }
      .columnsTemplate('1fr 1fr 1fr 1fr 1fr 1fr')
      .rowsGap(4)
      .columnsGap(4)
      .padding({ left: 12, right: 12, top: 8, bottom: 16 })
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.card_background'))
  }
}
