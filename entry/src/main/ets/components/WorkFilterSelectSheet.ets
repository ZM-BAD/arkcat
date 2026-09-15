/**
 * 工作区筛选多选弹层（org/repo 共用，Spec 017/018）：标题行 + 行列表（头像/两行文本/蓝勾）。
 * 行数据由调用方映射为 FilterSheetItem（主副文本顺序与选中态均由调用方决定）；
 * 数据加载和筛选状态留在调用方，本组件只负责展示与上抛事件。
 * 标题行双态（Spec 068）：常态=[✕ 标题 🔍]；搜索态=点 🔍 后标题**原地**变为搜索框
 * （对已加载行做客户端过滤），左侧 ✕ 变 ←（回退=清空搜索词并退出搜索态）。
 */
import { OctIcon } from './OctIcon';
import { StateView } from './StateView';
import { SheetHeader } from './SheetHeader';
import { resText } from '../utils/I18n';

/** 弹层行数据（key=逻辑键：org 为 login，repo 为 owner/name，供回调与 ForEach） */
export interface FilterSheetItem {
  key: string;
  avatarUrl: string;
  /** 主行（粗体） */
  mainText: string;
  /** 副行（灰色小字） */
  subText: string;
  /** 副行显示在主行之上（repo 行：owner 小字在上、名称在下） */
  subOnTop: boolean;
  selected: boolean;
}

@ComponentV2
export struct WorkFilterSelectSheet {
  @Require @Param title: Resource;
  @Param searchShow: boolean = false;
  @Param searchText: string = '';
  /** 搜索态输入框占位文案（repo 面板传「Search repositories」，其余用通用占位） */
  @Param searchPlaceholder: Resource = $r('app.string.search_placeholder');
  @Param loading: boolean = false;
  @Param error: string = '';
  @Param items: FilterSheetItem[] = [];
  @Event onPick: (key: string) => void = (key: string): void => { };
  @Event onClose: () => void = (): void => { };
  @Event onRetry: () => void = (): void => { };
  @Event onSearchToggle: () => void = (): void => { };
  @Event onSearchChange: (v: string) => void = (v: string): void => { };

  private stringOf(res: Resource): string {
    return resText(this.getUIContext(), res);
  }

  /** 弹层空态（官方「Nothing to see here」） */
  @Builder
  sheetEmpty() {
    Column() {
      Blank()
      Text($r('app.string.work_filter_nothing'))
        .fontSize($r('app.float.title_font_size'))
        .fontWeight(600)
        .fontColor($r('app.color.text_primary'))
      Blank()
    }
    .layoutWeight(1)
    .width('100%')
  }

  /** 行：头像 + 两行文本（主/副顺序按 subOnTop）+ 选中蓝勾 */
  @Builder
  sheetRow(item: FilterSheetItem) {
    Row({ space: 12 }) {
      if (item.avatarUrl !== '') {
        Image(item.avatarUrl)
          .width(40)
          .height(40)
          .borderRadius(20)
          .backgroundColor($r('app.color.chip_bg'))
      } else {
        Text('◯')
          .fontSize($r('app.float.title_font_size'))
          .width(40)
          .height(40)
          .borderRadius(20)
          .textAlign(TextAlign.Center)
          .backgroundColor($r('app.color.chip_bg'))
      }
      Column({ space: 2 }) {
        if (item.subOnTop) {
          Text(item.subText)
            .fontSize($r('app.float.caption_font_size'))
            .fontColor($r('app.color.text_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(item.mainText)
            .fontSize($r('app.float.body_font_size'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        } else {
          Text(item.mainText)
            .fontSize($r('app.float.body_font_size'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(item.subText)
            .fontSize($r('app.float.caption_font_size'))
            .fontColor($r('app.color.text_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      if (item.selected) {
        OctIcon({ res: $r('app.media.oct_check_16'), iconSize: 20, iconColor: $r('app.color.link_blue') })
      }
    }
    .width('100%')
    .height(64)
    .padding({ left: 16, right: 16 })
    .onClick((): void => this.onPick(item.key))
  }

  build() {
    Column() {
      SheetHeader({
        title: this.title,
        searchShow: this.searchShow,
        searchText: this.searchText,
        searchPlaceholder: this.searchPlaceholder,
        onClose: (): void => this.onClose(),
        onSearchToggle: (): void => this.onSearchToggle(),
        onSearchChange: (v: string): void => this.onSearchChange(v)
      })
      if (this.loading) {
        StateView({ loading: true })
      } else if (this.error !== '') {
        StateView({ error: this.error, onRetry: (): void => this.onRetry() })
      } else if (this.items.length === 0) {
        this.sheetEmpty()
      } else {
        Scroll() {
          Column() {
            // key 带上选中态：勾选后该行强制重建，否则行按静态 key 复用、蓝勾不刷新
            ForEach(this.items, (item: FilterSheetItem) => this.sheetRow(item),
              (item: FilterSheetItem) => `${item.key}_${item.selected ? 'on' : 'off'}`)
          }
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
  }
}
