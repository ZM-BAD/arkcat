/**
 * Sort by 底部面板（Spec 037 仓库列表）：标题行（✕ + 标题）+ 单选行分组 + 右侧单选圆钮。
 * 分组由 options 的 isGroupStart 标记（该行上方插入 16vp 灰带分隔，官方仓库排序面板形态）；
 * 选项文案与选中态由调用方传入，本组件只负责展示与上抛事件。
 *
 * 选中态刷新：每行是独立组件（@Param selected），且 ForEach key 带上选中标记——
 * 面板内容在 bindSheet 内会被复用，若只用「@Builder 值参数 + 静态 key」，切换排序后圆钮会卡旧值
 * （表现为同时/错误地勾选），故此处两重保险（同 FilterDropdownChip 的组件化理由）。
 */
import { OctIcon } from './OctIcon';
import { resText } from '../utils/I18n';

/** 排序面板选项（isGroupStart=true 时该项上方插入组间分隔带） */
export interface SortSheetOption {
  key: string;
  label: string;
  isGroupStart?: boolean;
}

/** 单选行（独立组件：选中态经 @Param 刷新，规避 @Builder 值参数 + ForEach 复用卡旧值） */
@ComponentV2
struct SortOptionRow {
  @Param option: SortSheetOption = { key: '', label: '' };
  @Param selected: boolean = false;
  @Event onPick: (key: string) => void = (key: string): void => { };

  build() {
    Row() {
      Text(this.option.label)
        .fontSize($r('app.float.body_font_size'))
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
      // 单选圆钮：未选=灰描边空心圆，选中=主题蓝描边 + 蓝色实心点
      Stack() {
        Circle()
          .width(20)
          .height(20)
          .fill(Color.Transparent)
          .stroke(this.selected ? $r('app.color.link_blue') : $r('app.color.text_tertiary'))
          .strokeWidth(2)
        if (this.selected) {
          Circle()
            .width(10)
            .height(10)
            .fill($r('app.color.link_blue'))
        }
      }
    }
    .width('100%')
    .height(56)
    .padding({ left: 16, right: 16 })
    .onClick((): void => this.onPick(this.option.key))
  }
}

@ComponentV2
export struct SortBySheet {
  @Require @Param title: Resource;
  @Param options: SortSheetOption[] = [];
  @Param selectedKey: string = '';
  @Event onPick: (key: string) => void = (key: string): void => { };
  @Event onClose: () => void = (): void => { };

  private stringOf(res: Resource): string {
    return resText(this.getUIContext(), res);
  }

  /** 组间分隔带（官方分组面板的灰带，非细分隔线） */
  @Builder
  groupGap() {
    Row()
      .width('100%')
      .height(16)
      .backgroundColor($r('app.color.heat_empty'))
  }

  build() {
    Column() {
      Row() {
        Stack() {
          OctIcon({ res: $r('app.media.oct_x_16'), iconSize: 18, iconColor: $r('app.color.text_primary') })
        }
        .width(44)
        .height(44)
        .onClick((): void => this.onClose())
        Text(this.title)
          .fontSize($r('app.float.title_font_size'))
          .fontWeight(600)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
      }
      .padding({ left: 8, right: 8 })
      Divider()
        .color($r('app.color.divider'))
        .strokeWidth(1)
        .width('100%')
      Scroll() {
        Column() {
          ForEach(this.options, (opt: SortSheetOption) => {
            if (opt.isGroupStart) {
              this.groupGap()
            }
            SortOptionRow({
              option: opt,
              selected: this.selectedKey === opt.key,
              onPick: (key: string): void => this.onPick(key)
            })
          }, (opt: SortSheetOption) => `${opt.key}_${this.selectedKey === opt.key ? 'on' : 'off'}`)
        }
        .padding({ top: 0, bottom: 16 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      // 内容不足一屏时顶对齐：Scroll 默认居中会把首行推离头部（留白上下各一半）
      .align(Alignment.Top)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.card_background'))
  }
}
