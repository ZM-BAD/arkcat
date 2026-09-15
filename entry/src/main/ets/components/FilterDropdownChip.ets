/**
 * 通用筛选下拉 chip（Spec 017-019）：文字 + chevron + 自绘弹出卡片（选中项右侧主题蓝勾、遮罩点击关闭）。
 * 统一口径（Primer Token 对齐）：chip 文字 12fp（caption），胶囊轮廓收口高 32/圆角 16/左右 padding 8，
 * chevron 间距 8；responseRegion 扩至 44 触控。
 * 独立组件保证 label/selectedKey 经 @Param 更新可响应（@Builder 传值参数会卡旧值，须走组件状态）。
 * 同款外形的 sheet 型 chip 见 FilterSheetChip（点击拉起底部面板而非弹出卡片）。
 */
import { common } from '@kit.AbilityKit';
import { display, window } from '@kit.ArkUI';
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
  /** 可用宽度（vp）：收窄菜单卡片用，必须取到值，否则弹层会跑出屏幕 */
  private windowWidthVp: number = 0;

  aboutToAppear(): void {
    this.refreshWindowWidth();
  }

  /**
   * 刷新可用宽度：先用**同步**的 display 宽兜底（弹层定位不能依赖异步结果，取不到时最易跑出屏幕），
   * 再用异步的窗口宽精确覆盖（分屏/悬浮窗场景窗口比屏幕窄）。
   */
  private refreshWindowWidth(): void {
    try {
      const d = display.getDefaultDisplaySync();
      this.windowWidthVp = this.getUIContext().px2vp(d.width);
    } catch (e) {
      // 取不到保持原值
    }
    window.getLastWindow(this.getUIContext().getHostContext() as common.Context)
      .then((w: window.Window) => {
        const vp = this.getUIContext().px2vp(w.getWindowProperties().windowRect.width);
        if (vp > 0) {
          this.windowWidthVp = vp;
        }
      })
      .catch(() => {
      });
  }

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
            .fontSize($r('app.float.menu_font_size'))
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
        .height(52)
        .padding({ left: 14, right: 14 })
        .onClick((): void => {
          this.open = false;
          this.onPick(opt.key);
        })
      }, (opt: FilterDropdownOption) => opt.key)
    }
    .padding({ top: 8, bottom: 8 })
    .width(this.menuWidth())
    .borderRadius(12)
    .backgroundColor($r('app.color.card_background'))
    .shadow({ radius: 24, color: $r('app.color.shadow_floating'), offsetY: 8 })
  }

  /**
   * 菜单宽度 = **实测**最长选项文本宽 + 左右 padding 14+14 + 蓝勾 16 + 间距 8。
   * 用 getMeasureUtils().measureText 真实测量（按 row 同一字号 menu_font_size），
   * 不再按字符估算——估算在中英混排时会明显偏宽，卡片显得空荡。
   */
  private menuWidth(): number {
    const ui = this.getUIContext();
    const utils = ui.getMeasureUtils();
    let maxPx = 0;
    for (const opt of this.options) {
      const w = utils.measureText({
        textContent: opt.label,
        fontSize: $r('app.float.menu_font_size')
      });
      if (w > maxPx) {
        maxPx = w;
      }
    }
    const wanted = Math.max(96, Math.ceil(ui.px2vp(maxPx)) + 52);
    // 宽度按可用宽度封顶：卡片本身不能宽过屏幕（长文案由行内 ellipsis 兜底）
    if (this.windowWidthVp > 0) {
      return Math.min(wanted, this.windowWidthVp - 16);
    }
    return wanted;
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
        .margin({ left: 8 })
    }
    .height(32)
    .responseRegion({ x: 0, y: -6, width: '100%', height: '144%' })
    .padding({ left: 8, right: 8 })
    .borderRadius(16)
    .backgroundColor(this.active ? $r('app.color.chip_active_bg') : $r('app.color.chip_bg'))
    .margin({ right: 8 })
    .border({ width: 1, color: this.active ? $r('app.color.chip_active_border') : $r('app.color.border') })
    .onClick((): void => {
      if (!this.open) {
        this.refreshWindowWidth();
      }
      this.open = !this.open;
    })
    .bindPopup(this.open, {
      builder: (): void => this.dropdownCard(),
      // 首选「弹层左缘对齐 chip 左缘、置于下方」；出屏避让交给框架内建策略
      // （ArkUI popup 按可用空间自动调整位置，勿再手算 offset 叠加，双重修正会把弹层推出屏幕）。
      placement: Placement.BottomLeft,
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

/**
 * 底部面板型筛选 chip（与 FilterDropdownChip 同款胶囊外形）：点击拉起页面 bindSheet 底部面板，
 * 面板内选择（官方 Trending 的 Language/Spoken、Repositories 的 Language/Sort、Work 的
 * Organization/Repository/Sort 均为此型）。
 * 与下拉型的差异仅在于「点击去向」——本组件不自持弹层，激活态由调用方传入 active 决定。
 */
@ComponentV2
export struct FilterSheetChip {
  /** chip 显示文本（未选中时由调用方传入占位文案） */
  @Param label: string = '';
  @Param active: boolean = false;
  /** 前置图标（如仓库筛选单选时显示 repo octicon）；withIcon=false 时不渲染 */
  @Param withIcon: boolean = false;
  @Param iconRes: Resource = $r('app.media.oct_repo_16');
  /** 前置计数徽标（如仓库多选「N Repositories」）；与漏斗徽标同款：蓝底白字圆点，>0 时优先于图标 */
  @Param badgeCount: number = 0;
  @Event onTap: () => void = (): void => { };

  build() {
    Row() {
      if (this.badgeCount > 0) {
        Stack() {
          Text(`${this.badgeCount}`)
            .fontSize($r('app.float.caption_font_size'))
            .fontColor(Color.White)
        }
        .width(18)
        .height(18)
        .borderRadius(9)
        .backgroundColor($r('app.color.link_blue'))
        .margin({ right: 6 })
      } else if (this.withIcon) {
        OctIcon({
          res: this.iconRes,
          iconSize: 14,
          iconColor: this.active ? $r('app.color.link_blue') : $r('app.color.text_primary')
        })
          .margin({ right: 6 })
      }
      Text(this.label)
        .fontSize($r('app.float.caption_font_size'))
        .fontColor(this.active ? $r('app.color.link_blue') : $r('app.color.text_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .constraintSize({ maxWidth: 220 })
      OctIcon({
        res: $r('app.media.oct_chevron_down_16'),
        iconSize: 12,
        iconColor: this.active ? $r('app.color.link_blue') : $r('app.color.text_secondary')
      })
        .margin({ left: 8 })
    }
    .height(32)
    .responseRegion({ x: 0, y: -6, width: '100%', height: '144%' })
    .padding({ left: 8, right: 8 })
    .borderRadius(16)
    .backgroundColor(this.active ? $r('app.color.chip_active_bg') : $r('app.color.chip_bg'))
    .margin({ right: 8 })
    .border({ width: 1, color: this.active ? $r('app.color.chip_active_border') : $r('app.color.border') })
    .onClick((): void => this.onTap())
  }
}
