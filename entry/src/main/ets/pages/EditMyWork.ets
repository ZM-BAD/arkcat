/**
 * Edit My Work 页（Spec 016）：Home My Work 条目编辑。
 * 复选框控制显示/隐藏；常态按住六个点拖拽排序，重排模式下用行内 ▲▼ 逐格移动
 * （App Bar 蓝色竖点 ⋮ 菜单切换）；SAVE 持久化（Preferences）后 Home 立即反映。
 */
import { OctIcon } from '../components/OctIcon';
import { PageShadowBar } from '../components/PageShadowBar';
import { WorkSection, WorkConfigStore, defaultWorkSections, moveWorkSection } from '../utils/WorkConfig';

/** 条目元信息（图标/色/文案/路由 与 Home 013/024 保持一致） */
interface WorkEntryMeta {
  iconRes: Resource;
  color: ResourceColor;
  label: Resource;
}

/** ⋮ 菜单项（bindMenu 数组不随状态刷新，见 menuItems 注释） */
interface ReorderMenuEntry {
  value: ResourceStr;
  action: () => void;
}

@ComponentV2
export struct EditMyWorkView {
  @Param pathStack: NavPathStack = new NavPathStack();
  @Param onSaved: () => void = () => {};
  /** 编辑快照：返回不保存；SAVE 时写回 store */
  @Local snapshot: WorkSection[] = defaultWorkSections();
  /** 持久化配置加载完成前不渲染列表（review D5：Checkbox select 仅创建时生效，早渲染会显示错误的默认勾选态） */
  @Local configLoaded: boolean = false;
  /** 重排模式（⋮ 菜单切换）：行右以 ▲▼ 替代拖拽柄 */
  @Local reorderMode: boolean = false;
  /** ⋮ 菜单项：bindMenu 数组不随状态刷新（V2 坑）→ 模式切换后显式重建（同 Profile 的 Follow 菜单） */
  @Local menuItems: ReorderMenuEntry[] = [];
  /** 滚动顶部阴影（滚动中显示、回顶消失） */
  @Local scrollShadow: boolean = false;

  aboutToAppear(): void {
    this.rebuildMenu();
    WorkConfigStore.load(this.getUIContext().getHostContext())
      .then(() => {
        this.snapshot = WorkConfigStore.instance.sections.slice();
        this.configLoaded = true;
      })
      .catch(() => {
        // 读取失败按默认配置渲染，避免页面空白
        this.configLoaded = true;
      });
  }

  /** 重建 ⋮ 菜单项：标签随当前模式取反 */
  private rebuildMenu(): void {
    this.menuItems = [{
      value: this.reorderMode ? $r('app.string.edit_work_hide_reorder') : $r('app.string.edit_work_show_reorder'),
      action: (): void => this.toggleReorderMode()
    }];
  }

  private toggleReorderMode(): void {
    this.reorderMode = !this.reorderMode;
    this.rebuildMenu();
  }

  private meta(id: string): WorkEntryMeta {
    switch (id) {
      case 'prs':
        return { iconRes: $r('app.media.oct_git_pull_request_16'), color: $r('app.color.link_blue'), label: $r('app.string.home_work_pull_requests') };
      case 'discussions':
        return { iconRes: $r('app.media.oct_comment_discussion_16'), color: $r('app.color.shortcut_purple_fg'), label: $r('app.string.home_work_discussions') };
      case 'projects':
        return { iconRes: $r('app.media.oct_table_16'), color: $r('app.color.text_secondary'), label: $r('app.string.home_work_projects') };
      case 'topRepos':
        // 与 Home 同一入口保持同色（白图标需深底；浅底上不可见）
        return { iconRes: $r('app.media.oct_repo_16'), color: $r('app.color.work_dark_bg'), label: $r('app.string.home_work_top_repos') };
      case 'orgs':
        return { iconRes: $r('app.media.oct_organization_16'), color: $r('app.color.shortcut_orange_fg'), label: $r('app.string.home_work_organizations') };
      case 'starred':
        return { iconRes: $r('app.media.oct_star_fill_16'), color: $r('app.color.star_gold'), label: $r('app.string.home_work_starred') };
      default:
        return { iconRes: $r('app.media.oct_issue_opened_16'), color: $r('app.color.success_text'), label: $r('app.string.home_work_issues') };
    }
  }

  private setVisible(index: number, isOn: boolean): void {
    const next: WorkSection[] = [];
    for (let i = 0; i < this.snapshot.length; i++) {
      const item = this.snapshot[i];
      next.push({ id: item.id, visible: i === index ? isOn : item.visible });
    }
    this.snapshot = next;
  }

  /** 拖拽排序：oldIndex 移到 newIndex（越界原样返回，见 WorkConfig.moveWorkSection） */
  private move(from: number, to: number): void {
    this.snapshot = moveWorkSection(this.snapshot, from, to);
  }

  /** 该方向的相邻位是否存在（首行不可上移 / 末行不可下移） */
  private canMove(id: string, delta: number): boolean {
    const index = this.snapshot.findIndex((s: WorkSection): boolean => s.id === id);
    if (index < 0) {
      return false;
    }
    const target = index + delta;
    return target >= 0 && target < this.snapshot.length;
  }

  /** ▲▼ 逐格移动：按 id 定位当前下标（ForEach 复用组件时 item 引用可能过期，同复选框的定位方式） */
  private moveBy(id: string, delta: number): void {
    const index = this.snapshot.findIndex((s: WorkSection): boolean => s.id === id);
    if (index < 0) {
      return;
    }
    this.move(index, index + delta);
  }

  private save(): void {
    WorkConfigStore.instance.sections = this.snapshot.slice();
    WorkConfigStore.save(this.getUIContext().getHostContext());
    this.onSaved();
    this.pathStack.pop();
  }

  /** 重排模式行右按钮：▲/▼（可点为黑 text_primary，首行 ▲ 与末行 ▼ 置灰不可点） */
  @Builder
  moveButton(id: string, delta: number) {
    Stack() {
      OctIcon({
        res: delta < 0 ? $r('app.media.oct_chevron_up_16') : $r('app.media.oct_chevron_down_16'),
        iconSize: 18,
        iconColor: this.canMove(id, delta) ? $r('app.color.text_primary') : $r('app.color.text_tertiary')
      })
    }
    .width(40)
    .height(44)
    .enabled(this.canMove(id, delta))
    .accessibilityDescription(delta < 0 ? $r('app.string.a11y_move_up') : $r('app.string.a11y_move_down'))
    .focusable(true)
    .onClick((): void => this.moveBy(id, delta))
  }

  @Builder
  workRow(item: WorkSection) {
    Row() {
      // 官方 App 为方形勾选框：Checkbox 走 ROUNDED_SQUARE 形状（Toggle 默认圆形）
      Checkbox()
        .shape(CheckBoxShape.ROUNDED_SQUARE)
        .selectedColor($r('app.color.link_blue'))
        .select(item.visible)
        .width(22)
        .height(22)
        .onChange((isOn: boolean) => {
          // ForEach 按 key 复用组件，item 引用可能是旧数组对象 → 按 id 定位
          const index = this.snapshot.findIndex((s: WorkSection): boolean => s.id === item.id);
          if (index >= 0) {
            this.setVisible(index, isOn);
          }
        })
      Stack() {
          OctIcon({ res: this.meta(item.id).iconRes, iconSize: 18, iconColor: Color.White })
      }
      .width(44)
      .height(44)
      .backgroundColor(this.meta(item.id).color)
      .borderRadius(6)
      .margin({ left: 12 })
      Text(this.meta(item.id).label)
        .fontSize($r('app.float.body_font_size'))
        .fontColor($r('app.color.text_primary'))
        .margin({ left: 12 })
        .layoutWeight(1)
      // 重排模式让位给 ▲▼；常态显示拖拽柄（Spec 016：两种改序方式分模式，不同屏并存）
      if (this.reorderMode) {
        this.moveButton(item.id, -1)
        this.moveButton(item.id, 1)
      } else {
        OctIcon({
          res: $r('app.media.oct_grabber_16'),
          iconSize: 18,
          iconColor: $r('app.color.text_secondary')
        })
          .padding({ left: 8, right: 8 })
      }
    }
    .width('100%')
    .height(56)
    .alignItems(VerticalAlign.Center)
    .padding({ left: 12, right: 8 })
  }

  build() {
    Column() {
      Row({ space: 8 }) {
        Stack() {
          OctIcon({
            res: $r('app.media.oct_arrow_left_24'),
            iconSize: 20,
            iconColor: $r('app.color.text_primary')
          })
        }
        .width(44)
        .height(44)
        .accessibilityDescription($r('app.string.a11y_back'))
        .focusable(true)
        .onClick((): void => {
          this.pathStack.pop();
        })
        Text($r('app.string.edit_work_title'))
          .fontSize($r('app.float.title_font_size'))
          .fontWeight(600)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
        Text($r('app.string.edit_work_save'))
          .fontSize($r('app.float.body_font_size'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.link_blue'))
          .padding(6)
          .responseRegion({ x: -6, y: -7, width: '130%', height: '147%' })
          .onClick(() => this.save())
        // Spec 016：蓝色竖点（全库惯例 kebab-horizontal 旋转 90°）→ 重排模式菜单
        Stack() {
          OctIcon({
            res: $r('app.media.oct_kebab_horizontal_16'),
            iconSize: 18,
            iconColor: $r('app.color.link_blue')
          })
            .rotate({ angle: 90 })
        }
        .width(44)
        .height(44)
        .padding(6)
        .accessibilityDescription($r('app.string.a11y_more'))
        .focusable(true)
        .bindMenu(this.menuItems)
      }
      .width('100%')
      .height(48)
      .padding({ left: 0, right: 0 })

      PageShadowBar({ show: this.scrollShadow })

      // 配置加载完成前不渲染（review D5），防止勾选框以默认态创建
      if (this.configLoaded) {
        List() {
          ForEach(this.snapshot, (item: WorkSection, index: number) => {
            ListItem() {
              this.workRow(item)
            }
            .borderRadius(6)
            .backgroundColor($r('app.color.card_background'))
            .margin({ bottom: 4 })
          // key 必须含 index：顺序变化时若不换 key，ForEach 复用同 key 组件、行不会重排
          }, (item: WorkSection, index: number) => `${index}-${item.id}-${item.visible ? 1 : 0}`)
            // 拖拽排序：离手后 onMove 上报 from/to，改数据源即落位（自带落位动画与边缘自动滚动）
            .onMove((from: number, to: number): void => {
              this.move(from, to);
            })
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 16, right: 16, top: 8 })
        .scrollBar(BarState.Off)
        .onScroll((scrollOffset: number, _state: number): void => { this.scrollShadow = scrollOffset > 0.001; })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_page'))
  }
}
