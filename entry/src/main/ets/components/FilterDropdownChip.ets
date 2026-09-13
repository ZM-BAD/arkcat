/**
 * 通用筛选下拉 chip（Spec 017-019）：文字 + chevron + 自绘弹出卡片（选中项右侧主题蓝勾、遮罩点击关闭）。
 * 统一口径（Primer Token 对齐）：chip 文字 12fp（caption），胶囊轮廓收口高 32/圆角 16/左右 padding 8，
 * chevron 间距 8；responseRegion 扩至 44 触控。
 * 独立组件保证 label/selectedKey 经 @Param 更新可响应（@Builder 传值参数会卡旧值，须走组件状态）。
 * 同款外形的 sheet 型 chip 见 FilterSheetChip（点击拉起底部面板而非弹出卡片）。
 */
import { common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { OctIcon } from './OctIcon';
import { resText } from '../utils/I18n';

/** 下拉选项（调用方以当前语言文案构建；isGroupStart=true 时该项上方画组间分隔线） */
export interface FilterDropdownOption {
  key: string;
  label: string;
  isGroupStart?: boolean;
}

/** 估算 17fp 下字符串宽（vp）：CJK 按 17，其余按 9.0（官方 UIMenu 宽度 = 最长项 + 固定部分） */
function estLabelWidth(label: string): number {
  let w = 0;
  for (let i = 0; i < label.length; i++) {
    w += label.charCodeAt(i) > 0x2E7F ? 17 : 9;
  }
  return w;
}

/** bindPopup 弹出状态事件 */
interface PopupState {
  isVisible: boolean;
}

/** 实例自增 id：同页多实例时唯一（getRectangleById 锚点） */
let chipInstanceSeq: number = 0;

@ComponentV2
export struct FilterDropdownChip {
  /** chip 显示文本（当前选中值，随选择刷新） */
  @Param label: string = '';
  @Param active: boolean = false;
  @Param options: FilterDropdownOption[] = [];
  @Param selectedKey: string = '';
  @Event onPick: (key: string) => void = (key: string): void => { };
  @Local open: boolean = false;
  /** chip 实时宽度（onAreaChange 测量，用于 popup 左对齐） */
  @Local chipWidth: number = 70;
  /** 实例唯一 id（弹层屏幕内自适应锚点） */
  private chipId: string = `filterchip_${chipInstanceSeq++}`;
  /** 窗口宽度（vp；aboutToAppear 时缓存） */
  private windowWidthVp: number = 0;

  aboutToAppear(): void {
    window.getLastWindow(this.getUIContext().getHostContext() as common.Context)
      .then((w: window.Window) => {
        this.windowWidthVp = this.getUIContext().px2vp(w.getWindowProperties().windowRect.width);
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

  /** 官方 UIMenu 宽度 = 最长项文本宽 + 左右 padding 14+14 + 蓝勾 16 + 间距 8 */
  private menuWidth(): number {
    let maxW = 0;
    for (const opt of this.options) {
      maxW = Math.max(maxW, estLabelWidth(opt.label));
    }
    return Math.max(136, maxW + 52);
  }

  /** 弹层水平偏移：左缘对齐 chip 左缘；右侧超屏时回收（自适应保留在屏幕内） */
  private popupOffsetX(): number {
    // bindPopup 默认水平居中于组件；左移半差使弹层左缘与 chip 左缘对齐
    let x = (this.menuWidth() - this.chipWidth) / 2;
    if (this.windowWidthVp > 0) {
      try {
        const rect = this.getUIContext().getComponentUtils().getRectangleById(this.chipId);
        if (rect !== null && rect !== undefined) {
          const chipLeft = this.getUIContext().px2vp(rect.windowOffset.x);
          const maxLeft = this.windowWidthVp - this.menuWidth() - 8;
          x += Math.min(0, maxLeft - chipLeft);
        }
      } catch (e) {
        // 布局未就绪：仅按左缘对齐处理
      }
    }
    return x;
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
    .id(this.chipId)
    .onAreaChange((_o: Area, n: Area): void => {
      // Area.width 为 Length（string|number），归一化为 number 存储
      if (typeof n.width === 'number') {
        this.chipWidth = n.width;
      } else if (n.width !== '' && n.width !== undefined) {
        this.chipWidth = parseFloat(n.width as string);
      }
    })
    .onClick((): void => {
      this.open = !this.open;
    })
    .bindPopup(this.open, {
      builder: (): void => this.dropdownCard(),
      placement: Placement.Bottom,
      enableArrow: false,
      mask: true,
      offset: { x: this.popupOffsetX(), y: 0 },
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
            .fontSize(12)
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
