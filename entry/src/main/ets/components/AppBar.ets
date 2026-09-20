import { OctIcon } from './OctIcon';
import { headEllipsisByWidth } from '../utils/Format';

/** bindPopup onStateChange 回调类型（与 CommentCard / PrDetail 同款自声明） */
interface PopupState {
  isVisible: boolean;
}

/**
 * 统一顶栏组件（Spec 067）。
 *
 * 全库顶栏骨架、边距、中心距、行高、图标尺寸在此收敛为官方 App 口径，
 * 页面不可覆写：
 * - 行高 48，行 padding 左右 4
 * - 返回键/动作图标触控区 44×44 顶满行缘 → 左右视觉内边距 = 4 + (44-20)/2 = 16
 * - 相邻动作图标触控区紧邻（Row space 0）→ 中心距 44、视觉缝 24
 * - 无返回键时标题区补 12 内距，标题左缘对齐 16
 * - 副标题两行型共用行高 48（纵向紧凑排列）
 *
 * 不进本组件的头部（保留自绘但按上述数值对齐，见 Spec 067 第五节）：
 * 内联搜索头（Search 系/Discussions）、文字动作头（Accounts/CreateList）、
 * 全幅横幅页（AchievementDetail）。
 */

/** 动作项可选覆盖项：不给的字段用默认值（默认 20vp / link_blue） */
export interface AppBarActionCfg {
  iconSize?: number;
  iconColor?: ResourceColor;
  /** 竖三点：kebab 横向资源旋转 90°，全库口径见 spec 061 */
  rotate90?: boolean;
  a11y?: Resource;
  /** 传入则绑定弹出菜单（MenuElement[] 由页面构造，闭包仍指向页面） */
  menu?: MenuElement[] | null;
  /** 自绘弹层菜单（可上色，原生 MenuElement 无法着色）：与 menu 二选一，menu 优先 */
  menuItems?: AppBarMenuItem[];
}

/**
 * 自绘弹层菜单项（与评论卡/正文卡同一视觉口径）：
 * danger=整行红（Close/Report/Block 等危险项）。
 */
export interface AppBarMenuItem {
  /** 左侧图标；不给=纯文字项（如 Checks 详情 ⋮ 的 Refresh，官方无图标） */
  icon?: Resource;
  label: ResourceStr;
  onAction: () => void;
  danger?: boolean;
}

export class AppBarAction {
  icon: Resource;
  onAction: () => void;
  iconSize: number = 20;
  iconColor: ResourceColor = $r('app.color.link_blue');
  rotate90: boolean = false;
  a11y: Resource = $r('app.string.a11y_more');
  menu: MenuElement[] | null = null;
  menuItems: AppBarMenuItem[] | null = null;

  constructor(icon: Resource, onAction: () => void, cfg?: AppBarActionCfg) {
    this.icon = icon;
    this.onAction = onAction;
    if (cfg) {
      this.iconSize = cfg.iconSize ?? 20;
      this.iconColor = cfg.iconColor ?? $r('app.color.link_blue');
      this.rotate90 = cfg.rotate90 ?? false;
      this.a11y = cfg.a11y ?? $r('app.string.a11y_more');
      this.menu = cfg.menu ?? null;
      this.menuItems = cfg.menuItems ?? null;
    }
  }
}

@ComponentV2
export struct AppBar {
  @Param showBack: boolean = false;
  @Param title: ResourceStr = '';
  @Param subtitle: ResourceStr = '';
  /** Profile 型两行：副标题（小字）在上、主标题在下；默认副标题在主标题下方 */
  @Param subtitleAbove: boolean = false;
  /** 标题头部省略（…尾部完整呈现，Android 官方 PR/Issue 详情口径）；默认关 */
  @Param titleHeadEllipsis: boolean = false;
  @Param actions: AppBarAction[] = [];
  /** 返回键回调，由页面传入（通常 () => this.pathStack.pop()） */
  @Param onBack: () => void = () => {};
  /** 标题区实测可用宽度（vp，onAreaChange 回填）：按宽度裁剪头省略，保证结尾完整可见 */
  @Local titleAvailVp: number = 0;
  /** 自绘菜单当前展开的动作序号（-1=全部收起；原生 menu 走 bindMenu 不用本状态） */
  @Local openActionIndex: number = -1;

  /** 菜单项颜色（danger 整行红） */
  private menuItemColor(item: AppBarMenuItem): ResourceColor {
    return item.danger === true ? $r('app.color.danger_text') : $r('app.color.text_primary');
  }

  /** 自绘动作菜单（与评论卡/正文卡同款：半径 12 + 悬浮阴影 + 灰线分组） */
  @Builder
  actionMenu(items: AppBarMenuItem[]) {
    Column() {
      ForEach(items, (item: AppBarMenuItem, index: number) => {
        Row({ space: 10 }) {
          if (item.icon !== undefined) {
            OctIcon({ res: item.icon, iconSize: 16, iconColor: this.menuItemColor(item) })
          }
          Text(item.label)
            .fontSize($r('app.float.body_font_size'))
            .fontColor(this.menuItemColor(item))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width('100%')
        .height(40)
        .responseRegion({ x: 0, y: -2, width: '100%', height: '110%' })
        .padding({ left: 14, right: 14 })
        .onClick((): void => {
          this.openActionIndex = -1;
          item.onAction();
        })
      }, (item: AppBarMenuItem, index: number) => `${index}-${item.label}`)
    }
    .width(230)
    .borderRadius(12)
    .backgroundColor($r('app.color.card_background'))
    .shadow({ radius: 24, color: $r('app.color.shadow_floating'), offsetY: 8 })
    .padding({ top: 6, bottom: 6 })
  }

  /** 按标题字号实测文本宽度（vp）；fontWeight 与标题渲染一致（600） */
  private measureVp(text: string): number {
    const ui = this.getUIContext();
    return ui.px2vp(ui.getMeasureUtils().measureText({
      textContent: text,
      fontSize: $r('app.float.title_font_size'),
      fontWeight: 600
    }));
  }

  /**
   * 顶栏标题：不开头省略时**原样返回**（title 可能是 `$r(...)`，字符串化会渲染成 [object Object]）；
   * 仅头省略分支需要按字符裁剪，才做字符串化。首帧未测到宽度时退回定长裁剪。
   */
  private displayTitle(): ResourceStr {
    if (!this.titleHeadEllipsis) {
      return this.title;
    }
    const raw = `${this.title}`;
    if (this.titleAvailVp <= 0) {
      return headEllipsis(raw);
    }
    return headEllipsisByWidth(raw, this.titleAvailVp, (t: string): number => this.measureVp(t));
  }

  build() {
    Row() {
      if (this.showBack) {
        Stack() {
          OctIcon({ res: $r('app.media.oct_arrow_left_24'), iconSize: 20, iconColor: $r('app.color.text_primary') })
        }
        .width(44)
        .height(44)
        .accessibilityDescription($r('app.string.a11y_back'))
        .focusable(true)
        .onClick(() => {
          this.onBack();
        })
      }
      if (this.title !== '' || this.subtitle !== '') {
        Column({ space: 0 }) {
          if (this.subtitleAbove && this.subtitle !== '') {
            Text(this.subtitle)
              .fontSize($r('app.float.caption_font_size'))
              .fontColor($r('app.color.text_secondary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          if (this.title !== '') {
            Text(this.displayTitle())
              .fontSize($r('app.float.title_font_size'))
              .fontWeight(600)
              .fontColor($r('app.color.text_primary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          if (!this.subtitleAbove && this.subtitle !== '') {
            Text(this.subtitle)
              .fontSize($r('app.float.body_font_size'))
              .fontColor($r('app.color.text_secondary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        .padding({ left: this.showBack ? 0 : 12 })
        .onAreaChange((_oldArea: Area, newArea: Area) => {
          this.titleAvailVp = Number(newArea.width);
        })
      } else {
        Blank()
      }
      ForEach(this.actions, (action: AppBarAction, index: number) => {
        if (action.menu !== null) {
          Stack() {
            OctIcon({ res: action.icon, iconSize: action.iconSize, iconColor: action.iconColor })
              .rotate({ angle: action.rotate90 ? 90 : 0 })
          }
          .width(44)
          .height(44)
          .accessibilityDescription(action.a11y)
          .focusable(true)
          .bindMenu(action.menu)
          .onClick(() => {
            action.onAction();
          })
        } else if (action.menuItems !== null) {
          // 自绘弹层菜单：可上色（danger 红），点开与收起都在本组件内闭环
          Stack() {
            OctIcon({ res: action.icon, iconSize: action.iconSize, iconColor: action.iconColor })
              .rotate({ angle: action.rotate90 ? 90 : 0 })
          }
          .width(44)
          .height(44)
          .accessibilityDescription(action.a11y)
          .focusable(true)
          .onClick(() => {
            this.openActionIndex = this.openActionIndex === index ? -1 : index;
          })
          .bindPopup(this.openActionIndex === index, {
            builder: (): void => this.actionMenu(action.menuItems ?? []),
            placement: Placement.BottomRight,
            enableArrow: false,
            mask: true,
            onStateChange: (e: PopupState): void => {
              if (!e.isVisible) {
                this.openActionIndex = -1;
              }
            }
          })
        } else {
          Stack() {
            OctIcon({ res: action.icon, iconSize: action.iconSize, iconColor: action.iconColor })
              .rotate({ angle: action.rotate90 ? 90 : 0 })
          }
          .width(44)
          .height(44)
          .accessibilityDescription(action.a11y)
          .focusable(true)
          .onClick(() => {
            action.onAction();
          })
        }
      }, (action: AppBarAction, index: number) => `${index}`)
    }
    .width('100%')
    .height(48)
    .padding({ left: 4, right: 4 })
  }
}

/** 标题头省略（Spec 042 官方对齐）：超长时头截尾全（…tup-node action to v7 口径）；短标题原样 */
export function headEllipsis(title: string, keep: number = 24): string {
  if (title.length <= keep + 3) {
    return title;
  }
  return `...${title.substring(title.length - keep)}`;
}
