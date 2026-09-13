/**
 * Inbox 筛选面板（Spec 002）：Filter notifications by（视图单选+类型多选）/ Filter by repository（仓库单选+搜索）。
 * 受控展示组件：选中态经 @Param 传入（父级传快照数组），全部交互经事件上抛，本组件不持有筛选状态。
 */
import { OctIcon } from './OctIcon';
import { InboxRepoFilterItem, InboxReasonKey } from '../services/NotificationsService';
import { resText } from '../utils/I18n';

/** 视图组（单选）：inbox=全部；saved/done 本地近似，见 filterByInboxView */
const SHEET_VIEWS: string[] = ['inbox', 'saved', 'done'];

/** 行元素（@Builder 传值参数不随状态刷新，须按引用传参） */
interface RowState {
  label: string;
  selected: boolean;
  emoji: string;
}

/** 类型组选项（key + 官方 emoji 图标 + 文案资源） */
interface ReasonOption {
  key: InboxReasonKey;
  emoji: string;
  labelRes: Resource;
}

/** 类型组（多选）：emoji 为官方 App 面板同款系统 emoji（Spec 002） */
const SHEET_REASONS: ReasonOption[] = [
  { key: 'assign', emoji: '🛡️', labelRes: $r('app.string.inbox_filter_assigned') },
  { key: 'participating', emoji: '💬', labelRes: $r('app.string.inbox_filter_participating') },
  { key: 'mention', emoji: '👋', labelRes: $r('app.string.inbox_filter_mentioned') },
  { key: 'team_mention', emoji: '🙌', labelRes: $r('app.string.inbox_filter_team_mentioned') },
  { key: 'review_requested', emoji: '🔍', labelRes: $r('app.string.inbox_filter_review_requested') }
];

/** 视图单选 + 类型多选面板 */
@ComponentV2
export struct InboxFilterSheet {
  @Param view: string = 'inbox';
  @Param selectedReasons: InboxReasonKey[] = [];
  @Event onSelectView: (v: string) => void = (v: string): void => { };
  @Event onToggleReason: (k: InboxReasonKey) => void = (k: InboxReasonKey): void => { };
  @Event onClose: () => void = (): void => { };

  private stringOf(res: Resource): string {
    return resText(this.getUIContext(), res);
  }

  /** 视图 label（面板选项文本） */
  private viewOptionLabel(v: string): string {
    const ui = this.getUIContext();
    switch (v) {
      case 'saved':
        return resText(ui, $r('app.string.inbox_view_saved'));
      case 'done':
        return resText(ui, $r('app.string.inbox_view_done'));
      default:
        return resText(ui, $r('app.string.inbox_menu_inbox'));
    }
  }

  /** 面板行：可选 emoji 图标 + 选项文本 + 选中蓝勾（$$ 引用参数随状态刷新） */
  @Builder
  sheetRow($$: RowState, onClick: () => void) {
    Row() {
      if ($$.emoji !== '') {
        Text($$.emoji)
          .fontSize(24)
          .width(32)
          .textAlign(TextAlign.Center)
          .margin({ right: 8 })
      }
      Text($$.label)
        .fontSize($r('app.float.body_font_size'))
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
      if ($$.selected) {
        OctIcon({ res: $r('app.media.oct_check_16'), iconSize: 16, iconColor: $r('app.color.link_blue') })
          .margin({ left: 8 })
      }
    }
    .width('100%')
    .height(52)
    .padding({ left: 16, right: 16 })
    .onClick(onClick)
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
        Text($r('app.string.inbox_filter_title'))
          .fontSize($r('app.float.title_font_size'))
          .fontWeight(600)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
        Blank()
          .width(44)
      }
      .padding({ left: 8, right: 8 })
      ForEach(SHEET_VIEWS, (v: string) => {
        this.sheetRow({
          label: this.viewOptionLabel(v),
          selected: this.view === v,
          emoji: ''
        }, (): void => this.onSelectView(v))
        // key 带上选中态：切换后该行强制重建，否则行按静态 key 复用、蓝勾不刷新
      }, (v: string) => `${v}_${this.view === v ? 'on' : 'off'}`)
      Divider()
        .color($r('app.color.divider'))
        .strokeWidth(1)
        .margin({ top: 4, bottom: 4 })
        .width('100%')
      ForEach(SHEET_REASONS, (r: ReasonOption) => {
        this.sheetRow({
          label: this.stringOf(r.labelRes),
          selected: this.selectedReasons.indexOf(r.key) >= 0,
          emoji: r.emoji
        }, (): void => this.onToggleReason(r.key))
      }, (r: ReasonOption) => `${r.key}_${this.selectedReasons.indexOf(r.key) >= 0 ? 'on' : 'off'}`)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.card_background'))
  }
}

/** 仓库单选面板：✕+标题+蓝色放大镜，仓库行=头像+名称+计数（选中蓝勾） */
@ComponentV2
export struct InboxRepoSheet {
  @Param searchShow: boolean = false;
  @Param search: string = '';
  @Param repos: InboxRepoFilterItem[] = [];
  @Param selectedFullName: string = '';
  /** 当前视图是否为 repo 过滤（全量数据源才显示选中态） */
  @Param selectedActive: boolean = false;
  @Event onPick: (fullName: string) => void = (fullName: string): void => { };
  @Event onClose: () => void = (): void => { };
  @Event onSearchToggle: () => void = (): void => { };
  @Event onSearchChange: (v: string) => void = (v: string): void => { };

  private stringOf(res: Resource): string {
    return resText(this.getUIContext(), res);
  }

  /** 仓库行：方形圆角属主头像 + owner/repo + 右侧计数（选中蓝勾） */
  @Builder
  repoRow(r: InboxRepoFilterItem) {
    Row({ space: 12 }) {
      Image(r.avatarUrl)
        .width(40)
        .height(40)
        .borderRadius(6)
        .backgroundColor($r('app.color.chip_bg'))
      Text(r.fullName)
        .fontSize($r('app.float.body_font_size'))
        .fontColor($r('app.color.text_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
      Text(`${r.count}`)
        .fontSize($r('app.float.body_font_size'))
        .fontColor($r('app.color.text_secondary'))
        .margin({ right: 8 })
      if (this.selectedFullName === r.fullName && this.selectedActive) {
        OctIcon({ res: $r('app.media.oct_check_16'), iconSize: 16, iconColor: $r('app.color.link_blue') })
          .margin({ left: 8 })
      }
    }
    .width('100%')
    .height(56)
    .padding({ left: 16, right: 16 })
    .onClick((): void => this.onPick(r.fullName))
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
        Text($r('app.string.inbox_repo_filter_title'))
          .fontSize($r('app.float.title_font_size'))
          .fontWeight(600)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
        Stack() {
          OctIcon({ res: $r('app.media.oct_search_24'), iconSize: 18, iconColor: $r('app.color.link_blue') })
        }
        .width(44)
        .height(44)
        .onClick((): void => this.onSearchToggle())
      }
      .padding({ left: 8, right: 8 })
      if (this.searchShow) {
        TextInput({ placeholder: this.stringOf($r('app.string.search_placeholder')), text: this.search })
          .height(40)
          .fontSize($r('app.float.body_font_size'))
          .margin({ left: 16, right: 16, bottom: 4 })
          .borderRadius(6)
          .backgroundColor($r('app.color.chip_bg'))
          .onChange((v: string): void => {
            this.onSearchChange(v);
          })
      }
      Scroll() {
        Column() {
          ForEach(this.repos, (r: InboxRepoFilterItem) => {
            this.repoRow(r)
            // key 带上选中态：选中仓库后该行强制重建，否则行按静态 key 复用、蓝勾不刷新
          }, (r: InboxRepoFilterItem) => `${r.fullName}_${this.selectedFullName === r.fullName && this.selectedActive ? 'on' : 'off'}`)
        }
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.card_background'))
  }
}
