import { OctIcon } from './OctIcon';

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
}

export class AppBarAction {
  icon: Resource;
  onAction: () => void;
  iconSize: number = 20;
  iconColor: ResourceColor = $r('app.color.link_blue');
  rotate90: boolean = false;
  a11y: Resource = $r('app.string.a11y_more');
  menu: MenuElement[] | null = null;

  constructor(icon: Resource, onAction: () => void, cfg?: AppBarActionCfg) {
    this.icon = icon;
    this.onAction = onAction;
    if (cfg) {
      this.iconSize = cfg.iconSize ?? 20;
      this.iconColor = cfg.iconColor ?? $r('app.color.link_blue');
      this.rotate90 = cfg.rotate90 ?? false;
      this.a11y = cfg.a11y ?? $r('app.string.a11y_more');
      this.menu = cfg.menu ?? null;
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
  @Param actions: AppBarAction[] = [];
  /** 返回键回调，由页面传入（通常 () => this.pathStack.pop()） */
  @Param onBack: () => void = () => {};

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
            Text(this.title)
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
