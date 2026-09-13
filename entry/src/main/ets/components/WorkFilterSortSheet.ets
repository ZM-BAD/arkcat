/**
 * 工作区 Sort by 弹层（Spec 017/018）：四组单选（时间/评论/更新）+ Most reactions emoji 网格。
 * 选中经 onPick 上抛，关闭经 onClose；选中态由调用方传入 sortKey 驱动。
 */
import { OctIcon } from './OctIcon';
import { resText } from '../utils/I18n';

/** Sort by 单选选项 */
interface SortOption {
  key: string;
  label: string;
}

/** Most reactions emoji 槽位（confused 无服务端排序键，保留位） */
export interface FilterReactionOption {
  key: string;
  emoji: string;
  disabled: boolean;
}

/** Most reactions emoji 清单（WorkFilterBar 计算 chip 标签时复用） */
export const FILTER_REACTIONS: FilterReactionOption[] = [
  { key: 'reactions:+1', emoji: '👍', disabled: false },
  { key: 'reactions:-1', emoji: '👎', disabled: false },
  { key: 'reactions:laugh', emoji: '😂', disabled: false },
  { key: 'reactions:hooray', emoji: '🎉', disabled: false },
  { key: 'reactions:confused', emoji: '😕', disabled: true },
  { key: 'reactions:heart', emoji: '❤️', disabled: false },
  { key: 'reactions:rocket', emoji: '🚀', disabled: false },
  { key: 'reactions:eyes', emoji: '👀', disabled: false }
];

/** Sort 单选圆钮参数（按引用传递，勾选态随状态刷新） */
interface SortRadioState {
  selected: boolean;
}

@ComponentV2
export struct WorkFilterSortSheet {
  @Param sortKey: string = 'newest';
  @Event onPick: (key: string) => void = (key: string): void => { };
  @Event onClose: () => void = (): void => { };

  private stringOf(res: Resource): string {
    return resText(this.getUIContext(), res);
  }

  /** Sort by 单选圆钮（按引用传递，勾选态随状态刷新） */
  @Builder
  radioCircle($$: SortRadioState) {
    Stack() {
      Circle()
        .width(20)
        .height(20)
        .fill(Color.Transparent)
        .stroke($$.selected ? $r('app.color.link_blue') : $r('app.color.text_tertiary'))
        .strokeWidth(2)
      if ($$.selected) {
        Circle()
          .width(10)
          .height(10)
          .fill($r('app.color.link_blue'))
      }
    }
  }

  @Builder
  sortGroup(opts: SortOption[]) {
    Column() {
      ForEach(opts, (opt: SortOption) => {
        Row() {
          Text(opt.label)
            .fontSize($r('app.float.body_font_size'))
            .fontColor($r('app.color.text_primary'))
            .layoutWeight(1)
          this.radioCircle({ selected: this.sortKey === opt.key })
        }
        .width('100%')
        .height(52)
        .padding({ left: 16, right: 16 })
        .onClick((): void => {
          this.onPick(opt.key);
        })
      }, (opt: SortOption) => opt.key)
    }
    .backgroundColor($r('app.color.card_background'))
    .borderRadius(12)
    .margin({ left: 12, right: 12, bottom: 12 })
  }

  @Builder
  reactionsGroup() {
    Column() {
      Text($r('app.string.issues_sort_most_reactions'))
        .fontSize($r('app.float.caption_font_size'))
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
        .padding({ left: 16, top: 14, bottom: 6 })
      Grid() {
        ForEach(FILTER_REACTIONS, (it: FilterReactionOption) => {
          GridItem() {
            Stack() {
              Text(it.emoji)
                .fontSize($r('app.float.title_font_size'))
            }
            .width(64)
            .height(56)
            .borderRadius(6)
            .border({
              width: 1,
              color: this.sortKey === it.key ? $r('app.color.link_blue') : Color.Transparent
            })
            .backgroundColor(this.sortKey === it.key ? $r('app.color.chip_active_bg') : Color.Transparent)
            .onClick((): void => {
              if (it.disabled) {
                return;
              }
              this.onPick(it.key);
            })
          }
        }, (it: FilterReactionOption) => it.key)
      }
      .columnsTemplate('1fr 1fr 1fr 1fr')
      .rowsGap(8)
      .columnsGap(8)
      .padding({ left: 12, right: 12, bottom: 20 })
      .width('100%')
    }
    .backgroundColor($r('app.color.card_background'))
    .borderRadius(12)
    .margin({ left: 12, right: 12, bottom: 12 })
  }

  build() {
    Column() {
      Row() {
        Stack() {
          OctIcon({ res: $r('app.media.oct_x_16'), iconSize: 16, iconColor: $r('app.color.text_primary') })
        }
        .width(44)
        .height(44)
        .onClick((): void => this.onClose())
        Text($r('app.string.filter_sort_title'))
          .fontSize($r('app.float.title_font_size'))
          .fontWeight(600)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
      }
      .padding({ left: 8, right: 8 })
      Scroll() {
        Column() {
          this.sortGroup([
            { key: 'newest', label: this.stringOf($r('app.string.issues_sort_newest')) },
            { key: 'oldest', label: this.stringOf($r('app.string.issues_sort_oldest')) }
          ])
          this.sortGroup([
            { key: 'most_commented', label: this.stringOf($r('app.string.issues_sort_most_commented')) },
            { key: 'least_commented', label: this.stringOf($r('app.string.issues_sort_least_commented')) }
          ])
          this.sortGroup([
            { key: 'recently_updated', label: this.stringOf($r('app.string.issues_sort_recently_updated')) },
            { key: 'least_recently_updated', label: this.stringOf($r('app.string.issues_sort_least_recently_updated')) }
          ])
          this.reactionsGroup()
        }
        .padding({ top: 8, bottom: 16 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
  }
}
