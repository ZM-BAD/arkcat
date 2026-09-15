/**
 * 列表单选筛选面板（弹层内容）：双态标题头 + 单选行列表（纯文本/官方彩色胶囊/空值哨兵三态行）。
 *
 * 此前 IssuesList 与 RepoPrs 各自内联整段（每页约 290 行，逐行同构），现收敛为本组件。
 * 搜索过滤候选池在调用方完成（本组件只渲染 options），选中态/语义（单选即关、再点取消）也留在调用方。
 */
import { OctIcon } from './OctIcon';
import { SheetHeader } from './SheetHeader';
import { LabelPill } from './LabelPill';
import { FilterDropdownOption } from './FilterDropdownChip';
import { NONE_FILTER_KEY } from '../utils/FilterLoading';

@ComponentV2
export struct FilterOptionSheet {
  @Require @Param title: Resource;
  /** 搜索态输入框占位文案（Filter labels / Filter users / Filter milestones） */
  @Require @Param searchPlaceholder: Resource;
  /** 候选池（调用方已按搜索词过滤） */
  @Param options: FilterDropdownOption[] = [];
  @Param selectedKey: string = '';
  /** 行形态：plain=纯文本；label=官方彩色胶囊行（LabelPill large） */
  @Param rowKind: string = 'plain';
  /** true=key 命中 NONE_FILTER_KEY 的行渲染 circle-slash 空值行（No milestone / Assigned to nobody） */
  @Param noneRow: boolean = false;
  /** rowKind=label 时按 key 取胶囊色 */
  @Param labelColorOf: (key: string) => string = (key: string): string => '';
  @Param searchShow: boolean = false;
  @Param searchText: string = '';
  /** 单选点击（含取消）；调用方负责关面板与刷新 */
  @Event onPick: (key: string) => void = (key: string): void => { };
  @Event onClose: () => void = (): void => { };
  @Event onSearchToggle: () => void = (): void => { };
  @Event onSearchChange: (v: string) => void = (v: string): void => { };

  private isNoneRow(key: string): boolean {
    return this.noneRow && key === NONE_FILTER_KEY;
  }

  build() {
    Column() {
      SheetHeader({
        title: this.title,
        searchShow: this.searchShow,
        searchText: this.searchText,
        searchPlaceholder: this.searchPlaceholder,
        iconSize: 18,
        alwaysDivider: true,
        onClose: (): void => this.onClose(),
        onSearchToggle: (): void => this.onSearchToggle(),
        onSearchChange: (v: string): void => this.onSearchChange(v)
      })
      Scroll() {
        Column() {
          if (this.options.length > 0) {
            ForEach(this.options, (opt: FilterDropdownOption) => {
              Row() {
                if (this.isNoneRow(opt.key)) {
                  // 官方「空值」行：circle-slash 图标 + 文案
                  Row({ space: 12 }) {
                    OctIcon({ res: $r('app.media.oct_circle_slash_16'), iconSize: 16,
                      iconColor: $r('app.color.text_secondary') })
                    Text(opt.label)
                      .fontSize($r('app.float.body_font_size'))
                      .fontColor($r('app.color.text_primary'))
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                  }
                  .alignItems(VerticalAlign.Center)
                  .layoutWeight(1)
                } else if (this.rowKind === 'label') {
                  // Label 面板行：官方为彩色胶囊（DESIGN.md §10.2），选中勾仍在右缘
                  LabelPill({ labelName: opt.label, colorHex: this.labelColorOf(opt.key), large: true })
                  Blank()
                } else {
                  Text(opt.label)
                    .fontSize($r('app.float.body_font_size'))
                    .fontColor($r('app.color.text_primary'))
                    .layoutWeight(1)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }
                if (this.selectedKey === opt.key) {
                  OctIcon({ res: $r('app.media.oct_check_16'), iconSize: 16, iconColor: $r('app.color.link_blue') })
                    .margin({ left: 8 })
                }
              }
              .width('100%')
              .height(56)
              .padding({ left: 20, right: 16 })
              .onClick((): void => this.onPick(opt.key))
            }, (opt: FilterDropdownOption) => `${opt.key}_${this.selectedKey === opt.key ? 'on' : 'off'}`)
          } else {
            // 搜索无结果（与语言面板同款文案）
            Text($r('app.string.filter_no_results'))
              .fontSize($r('app.float.caption_font_size'))
              .fontColor($r('app.color.text_secondary'))
              .width('100%')
              .padding({ left: 20, top: 16, bottom: 12 })
          }
        }
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.card_background'))
  }
}
