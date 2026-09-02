/**
 * 通用筛选下拉 chip（Spec 017-019）：文字 + chevron + 自绘弹出卡片（选中项右侧主题蓝勾、遮罩点击关闭）。
 * 独立组件保证 label/selectedKey 经 @Param 更新可响应（@Builder 传值参数会卡旧值，须走组件状态）。
 */
import { OctIcon } from './OctIcon';
import { resText } from '../utils/I18n';

/** 下拉选项（调用方以当前语言文案构建；isGroupStart=true 时该项上方画组间分隔线） */
export interface FilterDropdownOption {
  key: string;
  label: string;
  isGroupStart?: boolean;
}

/** bindPopup 弹出状态事件 */
interface PopupState {
  isVisible: boolean;
}

@ComponentV2
export struct FilterDropdownChip {
  /** chip 显示文本（当前选中值，随选择刷新） */
  @Param label: string = '';
  @Param active: boolean = false;
  @Param options: FilterDropdownOption[] = [];
  @Param selectedKey: string = '';
  @Event onPick: (key: string) => void = (key: string): void => { };
  @Local open: boolean = false;

  private stringOf(res: Resource): string {
    return resText(this.getUIContext(), res);
  }

  @Builder
  dropdownCard() {
    Column() {
      ForEach(this.options, (opt: FilterDropdownOption) => {
        if (opt.isGroupStart) {
          Divider()
            .color($r('app.color.divider'))
            .strokeWidth(1)
            .margin({ top: 4, bottom: 4 })
            .width('100%')
        }
        Row() {
          Text(opt.label)
            .fontSize($r('app.float.body_font_size'))
            .fontColor($r('app.color.text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          if (this.selectedKey === opt.key) {
            OctIcon({ res: $r('app.media.oct_check_16'), iconSize: 16, iconColor: $r('app.color.link_blue') })
              .margin({ left: 8 })
          }
        }
        .width('100%')
        .height(44)
        .padding({ left: 14, right: 14 })
        .onClick((): void => {
          this.open = false;
          this.onPick(opt.key);
        })
      }, (opt: FilterDropdownOption) => opt.key)
    }
    .padding({ top: 6, bottom: 6 })
    .width(210)
    .borderRadius(12)
    .backgroundColor($r('app.color.card_background'))
    .shadow({ radius: 16, color: '#29000000', offsetY: 4 })
  }

  build() {
    Row() {
      Text(this.label)
        .fontSize($r('app.float.caption_font_size'))
        .fontColor(this.active ? $r('app.color.link_blue') : $r('app.color.text_primary'))
      OctIcon({
        res: $r('app.media.oct_chevron_down_16'),
        iconSize: 12,
        iconColor: this.active ? $r('app.color.link_blue') : $r('app.color.text_secondary')
      })
        .margin({ left: 4 })
    }
    .height(30)
    .padding({ left: 12, right: 10 })
    .borderRadius(12)
    .backgroundColor(this.active ? $r('app.color.chip_active_bg') : $r('app.color.card_background'))
    .margin({ right: 8 })
    .border({ width: 1, color: this.active ? $r('app.color.chip_active_border') : $r('app.color.border') })
    .onClick((): void => {
      this.open = !this.open;
    })
    .bindPopup(this.open, {
      builder: (): void => this.dropdownCard(),
      placement: Placement.Bottom,
      enableArrow: false,
      mask: true,
      onStateChange: (e: PopupState): void => {
        if (!e.isVisible) {
          this.open = false;
        }
      }
    })
  }
}
