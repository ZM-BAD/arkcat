/**
 * Create Shortcut 编辑页（Spec 074）：命名 + Scope（全部/指定仓库）+ Type（Issues/PRs）
 * + 筛选 chips（复用 WorkFilterBar，showFunnel=false）+ 颜色板 + 图标网格。
 * 查询串端侧拼装（buildShortcutQuery），SAVE 追加进 ShortcutStore 并经 onSaved 泵回刷新。
 * 路由参数 JSON 预填（Work Issues/PRs 漏斗「Create Shortcut」携当前筛选直达）——
 * 参数晚于 aboutToAppear，经 @Monitor('prefill') 应用后再挂 WorkFilterBar（初始态一次性生效）。
 * 官方截图带底部 Tab，本页不进 TAB_BAR_HIDDEN_ROUTES。
 */
import { OctIcon } from '../components/OctIcon';
import { PageShadowBar } from '../components/PageShadowBar';
import { WorkFilterBar, WorkFilterOption, WorkFilterState, defaultWorkFilter } from '../components/WorkFilterBar';
import { common } from '@kit.AbilityKit';
import { display, window } from '@kit.ArkUI';
import {
  ShortcutColorSpec, ShortcutIconSpec, SHORTCUT_COLORS, SHORTCUT_ICONS,
  shortcutColor, shortcutIconRes
} from '../models/ShortcutPalette';
import { ShortcutItem, ShortcutStore, addShortcut, buildShortcutQuery } from '../utils/Shortcuts';
import { RepoPickResult } from './RepoPicker';
import { Json, JsonMap } from '../utils/Json';
import { resText } from '../utils/I18n';

/** bindPopup onStateChange 回调类型（与 PrDetail/CommentCard 同款自声明） */
interface PopupState {
  isVisible: boolean;
}

/** Scope / Type 菜单项（自定义 Menu builder 渲染，选中项尾随蓝色对勾） */
interface MenuEntry {
  key: string;
  label: string;
}

/** 路由预填载荷（Work 页漏斗菜单拼装，字段缺失按默认态兜底） */
interface ShortcutPrefill {
  kind: string;
  state: string;
  scope: string;
  visibility: string;
  sortKey: string;
  orgs: string[];
  repos: string[];
}

@ComponentV2
export struct ShortcutCreateView {
  @Param token: string = '';
  @Param pathStack: NavPathStack = new NavPathStack();
  @Param prefill: string = '';
  /** 选仓库页 pop 回 tick（Index onShown 泵回），触发消费 RepoPickResult 回传槽 */
  @Param repoTick: number = 0;
  @Param onSaved: () => void = () => {};
  /** 表单态（SAVE 时拼装 ShortcutItem） */
  @Local kind: string = 'issues';
  @Local name: string = '';
  /** Scope：'' = All repositories，否则 owner/name */
  @Local scopeRepo: string = '';
  @Local iconKey: string = 'zap';
  @Local colorKey: string = 'gray';
  /** 筛选快照（WorkFilterBar onQueryChange 回写；Type 切换时重置默认并递增 resetTick） */
  @Local filter: WorkFilterState = defaultWorkFilter();
  @Local resetTick: number = 0;
  /** 预填应用后再挂 WorkFilterBar（initialState 仅 aboutToAppear 应用一次，见文件头） */
  @Local filterReady: boolean = false;
  /** Scope / Type 菜单显隐（bindPopup isShow 状态驱动，onStateChange 复位防失同步） */
  @Local scopeMenuShown: boolean = false;
  @Local typeMenuShown: boolean = false;
  /** 滚动顶部阴影（滚动中显示、回顶消失） */
  @Local scrollShadow: boolean = false;
  /** 可用宽度（vp）：Scope 菜单选仓库后第二行=owner/name，超长须按窗口宽封顶（FilterDropdownChip 同款） */
  private windowWidthVp: number = 0;

  aboutToAppear(): void {
    this.refreshWindowWidth();
    // 无预填（管理页 CREATE SHORTCUT 入口）直接挂筛选条；有预填走 @Monitor
    if (this.prefill === '') {
      this.filterReady = true;
    }
  }

  /** 同步 display 宽兜底 + 异步窗口宽精确覆盖（分屏/悬浮窗窗口比屏幕窄，FilterDropdownChip 同款） */
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

  /** 路由参数时序坑：onReady 晚于 aboutToAppear，预填经 @Monitor 应用（050 既定对策） */
  @Monitor('prefill')
  onPrefillChanged(): void {
    const map: JsonMap | null = Json.parse(this.prefill);
    if (map === null) {
      this.filterReady = true;
      return;
    }
    this.kind = Json.str(map, 'kind') === 'prs' ? 'prs' : 'issues';
    const orgs: string[] = [];
    for (const raw of Json.arr(map, 'orgs')) {
      if (typeof raw === 'string') {
        orgs.push(raw);
      }
    }
    const repos: string[] = [];
    for (const raw of Json.arr(map, 'repos')) {
      if (typeof raw === 'string') {
        repos.push(raw);
      }
    }
    this.filter = {
      state: Json.str(map, 'state', 'open'),
      scope: Json.str(map, 'scope', 'created'),
      visibility: Json.str(map, 'visibility', 'all'),
      sortKey: Json.str(map, 'sortKey', 'newest'),
      orgs: orgs,
      repos: repos
    };
    this.filterReady = true;
  }

  /** 选仓库页 pop 回：消费 RepoPickResult 回传槽（onPop 不触发，坑库定案——经 onShown tick 泵回） */
  @Monitor('repoTick')
  onRepoTick(): void {
    if (RepoPickResult.picked !== '') {
      this.scopeRepo = RepoPickResult.picked;
      RepoPickResult.picked = '';
    }
  }

  private stringOf(res: Resource): string {
    return resText(this.getUIContext(), res);
  }

  /** 类型名（名称占位与留空兜底共用） */
  private typeLabelRes(): Resource {
    if (this.kind === 'prs') {
      return $r('app.string.home_work_pull_requests');
    }
    if (this.kind === 'discussions') {
      return $r('app.string.home_work_discussions');
    }
    return $r('app.string.home_work_issues');
  }

  /** Type 菜单三选项（官方口径：Issues / Pull Requests / Discussions，用户 2026-09-21 定案） */
  private typeMenuItems(): MenuEntry[] {
    return [
      { key: 'issues', label: this.stringOf($r('app.string.home_work_issues')) },
      { key: 'prs', label: this.stringOf($r('app.string.home_work_pull_requests')) },
      { key: 'discussions', label: this.stringOf($r('app.string.home_work_discussions')) }
    ];
  }

  /** Scope 菜单两选项（官方口径，2026-09-21 用户定案）：
   *  未选仓库 = All Repositories / Choose Repository；已选仓库 = All Repositories / **owner/name**（当前选中，
   *  点击重新进选仓库页可换仓库）；蓝勾跟随当前态挂对应行 */
  private scopeMenuItems(): MenuEntry[] {
    const items: MenuEntry[] = [
      { key: '__all__', label: this.stringOf($r('app.string.shortcuts_scope_menu_all')) }
    ];
    if (this.scopeRepo !== '') {
      items.push({ key: '__repo__', label: this.scopeRepo });
    } else {
      items.push({ key: '__choose__', label: this.stringOf($r('app.string.shortcuts_scope_menu_choose')) });
    }
    return items;
  }

  /** 菜单项标签集（测宽用） */
  private menuLabels(items: MenuEntry[]): string[] {
    const labels: string[] = [];
    for (const item of items) {
      labels.push(item.label);
    }
    return labels;
  }

  /** Scope 弹出菜单：Type 菜单同款自适应卡片（bindPopup + 实测文本宽度，当前态行尾随蓝勾）。
   *  未选=勾挂 All Repositories 行；已选=第二行变 owner/name 且勾挂该行（用户 2026-09-21 定案） */
  @Builder
  scopeMenuBuilder() {
    Column() {
      ForEach(this.scopeMenuItems(), (item: MenuEntry) => {
        Row() {
          Text(item.label)
            .fontSize($r('app.float.menu_font_size'))
            .fontColor($r('app.color.text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          if ((item.key === '__all__' && this.scopeRepo === '') || item.key === '__repo__') {
            OctIcon({ res: $r('app.media.oct_check_16'), iconSize: 16, iconColor: $r('app.color.link_blue') })
              .margin({ left: 8 })
          }
        }
        .width('100%')
        .height(52)
        .padding({ left: 14, right: 14 })
        .onClick((): void => {
          this.pickScopeMenu(item.key);
          this.scopeMenuShown = false;
        })
      }, (item: MenuEntry) => item.key)
    }
    .padding({ top: 8, bottom: 8 })
    .width(this.menuWidthOf(this.menuLabels(this.scopeMenuItems())))
    .borderRadius(12)
    .backgroundColor($r('app.color.card_background'))
    .shadow({ radius: 24, color: $r('app.color.shadow_floating'), offsetY: 8 })
  }

  /** Type 弹出菜单：FilterDropdownChip 同款自适应卡片（bindPopup + 实测文本宽度）。
   *  此前用 bindMenu 自绘内容被系统菜单容器再包一层致超长，用户 2026-09-21 校正。
   *  选中项尾随蓝色 check octicon（oct_check_16，与全应用一致） */
  @Builder
  typeMenuBuilder() {
    Column() {
      ForEach(this.typeMenuItems(), (item: MenuEntry) => {
        Row() {
          Text(item.label)
            .fontSize($r('app.float.menu_font_size'))
            .fontColor($r('app.color.text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          if (this.kind === item.key) {
            OctIcon({ res: $r('app.media.oct_check_16'), iconSize: 16, iconColor: $r('app.color.link_blue') })
              .margin({ left: 8 })
          }
        }
        .width('100%')
        .height(52)
        .padding({ left: 14, right: 14 })
        .onClick((): void => {
          this.setKind(item.key);
          this.typeMenuShown = false;
        })
      }, (item: MenuEntry) => item.key)
    }
    .padding({ top: 8, bottom: 8 })
    .width(this.menuWidthOf(this.menuLabels(this.typeMenuItems())))
    .borderRadius(12)
    .backgroundColor($r('app.color.card_background'))
    .shadow({ radius: 24, color: $r('app.color.shadow_floating'), offsetY: 8 })
  }

  /** 菜单宽度 = 实测最长选项文本宽 + 行左右 padding 14+14 + 蓝勾 16 + 间距 8
   *  （FilterDropdownChip.menuWidth 同款：measureText 真实测量，不按字符估算）；
   *  下限 96、上限窗口宽 -16——已选仓库后第二行=owner/name，超长由行内 ellipsis 兜底 */
  private menuWidthOf(labels: string[]): number {
    const ui = this.getUIContext();
    const utils = ui.getMeasureUtils();
    let maxPx = 0;
    for (const label of labels) {
      const w = utils.measureText({
        textContent: label,
        fontSize: $r('app.float.menu_font_size')
      });
      if (w > maxPx) {
        maxPx = w;
      }
    }
    const wanted = Math.max(96, Math.ceil(ui.px2vp(maxPx)) + 52);
    if (this.windowWidthVp > 0) {
      return Math.min(wanted, this.windowWidthVp - 16);
    }
    return wanted;
  }

  /** Scope 菜单分发：All=切回全部仓库；Choose / 已选仓库名行=压栈选仓库页（独立路由名
   *  shortcutRepoPicker——官方该页带底部 Tab，不进 TAB_BAR_HIDDEN_ROUTES；选择经 RepoPickResult 槽回传） */
  private pickScopeMenu(key: string): void {
    if (key === '__all__') {
      this.scopeRepo = '';
      return;
    }
    this.pathStack.pushPathByName('shortcutRepoPicker', '');
  }

  /** Type 切换：筛选重置默认（两类状态选项不同，跨类键失效防错） */
  private setKind(kind: string): void {
    if (this.kind === kind) {
      return;
    }
    this.kind = kind;
    this.filter = defaultWorkFilter();
    this.resetTick++;
  }

  private stateOptions(): WorkFilterOption[] {
    if (this.kind === 'prs') {
      return [
        { key: 'open', label: this.stringOf($r('app.string.issues_state_open')) },
        { key: 'merged', label: this.stringOf($r('app.string.pr_state_merged')) },
        { key: 'closed', label: this.stringOf($r('app.string.issues_state_closed')) },
        { key: 'queued', label: this.stringOf($r('app.string.pr_filter_queued')) },
        { key: 'all', label: this.stringOf($r('app.string.work_filter_all')) }
      ];
    }
    return [
      { key: 'open', label: this.stringOf($r('app.string.issues_state_open')) },
      { key: 'closed', label: this.stringOf($r('app.string.issues_state_closed')) },
      { key: 'all', label: this.stringOf($r('app.string.work_filter_all')) }
    ];
  }

  private scopeOptions(): WorkFilterOption[] {
    if (this.kind === 'prs') {
      return [
        { key: 'created', label: this.stringOf($r('app.string.issues_filter_scope_created')) },
        { key: 'assigned', label: this.stringOf($r('app.string.issues_filter_scope_assigned')) },
        { key: 'mentioned', label: this.stringOf($r('app.string.issues_filter_scope_mentioned')) },
        { key: 'review_requested', label: this.stringOf($r('app.string.pr_filter_scope_review_requested')) },
        { key: 'involved', label: this.stringOf($r('app.string.issues_filter_scope_involved')) }
      ];
    }
    return [
      { key: 'created', label: this.stringOf($r('app.string.issues_filter_scope_created')) },
      { key: 'assigned', label: this.stringOf($r('app.string.issues_filter_scope_assigned')) },
      { key: 'mentioned', label: this.stringOf($r('app.string.issues_filter_scope_mentioned')) },
      { key: 'involved', label: this.stringOf($r('app.string.issues_filter_scope_involved')) }
    ];
  }

  /** Scope 行当前值文案 */
  private scopeValue(): string {
    if (this.scopeRepo === '') {
      return this.stringOf($r('app.string.shortcuts_all_repositories'));
    }
    return this.scopeRepo;
  }

  /** 图标网格按官方固定 7 列分块（Flex wrap 会随屏宽变 8 列，用户 2026-09-21 校正）；末行不满居中 */
  private iconRows(): ShortcutIconSpec[][] {
    const rows: ShortcutIconSpec[][] = [];
    let row: ShortcutIconSpec[] = [];
    for (const icon of SHORTCUT_ICONS) {
      row.push(icon);
      if (row.length === 7) {
        rows.push(row);
        row = [];
      }
    }
    if (row.length > 0) {
      rows.push(row);
    }
    return rows;
  }

  /** SAVE：留空名称以类型名兜底；Scope 仓库并入 repos 限定词；幂等去重后落盘泵回 */
  private save(): void {
    const repos = this.scopeRepo !== ''
      ? [this.scopeRepo].concat(this.filter.repos) : this.filter.repos;
    const query = buildShortcutQuery(this.kind, this.filter.state, this.filter.scope,
      this.filter.visibility, this.filter.sortKey, this.filter.orgs, repos);
    const trimmed = this.name.trim();
    const item: ShortcutItem = {
      id: `sc_manual_${Date.now()}`,
      name: trimmed !== '' ? trimmed : this.stringOf(this.typeLabelRes()),
      head: this.stringOf(this.typeLabelRes()),
      kind: this.kind,
      query: query,
      iconKey: this.iconKey,
      colorKey: this.colorKey,
      createdAt: Date.now()
    };
    ShortcutStore.instance.list = addShortcut(ShortcutStore.instance.list, item);
    ShortcutStore.save(this.getUIContext().getHostContext());
    this.onSaved();
    this.pathStack.pop();
  }

  /** 区块间灰隙（官方 Create 页分段） */
  @Builder
  sectionGap() {
    Row()
      .width('100%')
      .height(8)
      .backgroundColor($r('app.color.bg_page'))
  }

  /** 名称行：tile 预览 + 下划线式输入（官方 Material 风格 underline，占位为类型名） */
  @Builder
  nameRow() {
    Row({ space: 14 }) {
      Stack() {
        OctIcon({ res: shortcutIconRes(this.iconKey), iconSize: 20, iconColor: shortcutColor(this.colorKey).fg })
      }
      .width(40)
      .height(40)
      .borderRadius(8)
      .backgroundColor(shortcutColor(this.colorKey).bg)

      Column() {
        TextInput({
          placeholder: this.typeLabelRes(),
          text: this.name
        })
          .id('shortcut_name')
          .width('100%')
          .height(40)
          .fontSize($r('app.float.body_font_size'))
          .fontColor($r('app.color.text_primary'))
          .placeholderColor($r('app.color.text_tertiary'))
          .caretColor($r('app.color.link_blue'))
          .backgroundColor(Color.Transparent)
          .padding({ left: 0, right: 0 })
          .onChange((v: string) => {
            this.name = v;
          })
        // 官方下划线式输入（仅文字域底线，tile 侧无线）
        Divider()
          .color($r('app.color.border'))
          .margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
  }

  /** Scope / Type 行：左标签 + 右蓝色值。注意值文案必须内联直读 this.kind——
   *  @Builder 多参数按值传递不会随状态刷新（坑库条目），抽公共 builder 曾致选中后文案不变 */
  @Builder
  scopeRow() {
    Row() {
      Text($r('app.string.shortcuts_scope'))
        .fontSize($r('app.float.body_font_size'))
        .fontColor($r('app.color.text_primary'))
      Blank()
      Text(this.scopeValue())
        .fontSize($r('app.float.body_font_size'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.link_blue'))
        .textAlign(TextAlign.End)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .constraintSize({ maxWidth: '60%' })
    }
    .width('100%')
    .height(52)
    .alignItems(VerticalAlign.Center)
    .padding({ left: 16, right: 16 })
    .onClick((): void => {
      this.scopeMenuShown = true;
    })
    // Scope 自适应弹层（Type 菜单同款：bindPopup + mask + onStateChange 复位；BottomRight 锚行尾）
    .bindPopup(this.scopeMenuShown, {
      builder: (): void => this.scopeMenuBuilder(),
      placement: Placement.BottomRight,
      enableArrow: false,
      mask: true,
      onStateChange: (e: PopupState): void => {
        if (!e.isVisible) {
          this.scopeMenuShown = false;
        }
      }
    })
  }

  @Builder
  typeRow() {
    Row() {
      Text($r('app.string.shortcuts_type'))
        .fontSize($r('app.float.body_font_size'))
        .fontColor($r('app.color.text_primary'))
      Blank()
      Text(this.stringOf(this.typeLabelRes()))
        .fontSize($r('app.float.body_font_size'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.link_blue'))
        // 官方 Type 值全大写（ISSUES / PULL REQUESTS / DISCUSSIONS）
        .textCase(TextCase.UpperCase)
        .textAlign(TextAlign.End)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .constraintSize({ maxWidth: '60%' })
    }
    .width('100%')
    .height(52)
    .alignItems(VerticalAlign.Center)
    .padding({ left: 16, right: 16 })
    .onClick((): void => {
      this.typeMenuShown = true;
    })
    // Type 自适应弹层（FilterDropdownChip 同款：bindPopup + mask + onStateChange 复位；
    // BottomRight 锚到行右端值区域附近，框架内建出屏避让）
    .bindPopup(this.typeMenuShown, {
      builder: (): void => this.typeMenuBuilder(),
      placement: Placement.BottomRight,
      enableArrow: false,
      mask: true,
      onStateChange: (e: PopupState): void => {
        if (!e.isVisible) {
          this.typeMenuShown = false;
        }
      }
    })
  }

  /** 颜色行：与下方图标网格同形态（无底块、44 槽位等距分布，不横滚，用户 2026-09-21 定案）。
   *  圆点直接用 octicon dot 原生字形（20 渲染，与网格 dot 同视觉尺寸）：未选=空心 dot，选中=实心 dot-fill */
  @Builder
  colorCell(spec: ShortcutColorSpec) {
    Stack() {
      OctIcon({
        res: this.colorKey === spec.key
          ? $r('app.media.oct_dot_fill_16') : $r('app.media.oct_dot_16'),
        iconSize: 20,
        iconColor: spec.fg
      })
    }
    .width(44)
    .height(44)
    .accessibilityDescription(spec.key)
    .focusable(true)
    .onClick((): void => {
      this.colorKey = spec.key;
    })
  }

  /** 图标网格单元：选中 = 灰底白字形，未选 = 透明底黑字形 */
  @Builder
  iconCell(icon: ShortcutIconSpec) {
    Stack() {
      OctIcon({
        res: icon.res,
        iconSize: 20,
        iconColor: this.iconKey === icon.key ? Color.White : $r('app.color.text_primary')
      })
    }
    .width(44)
    .height(44)
    .borderRadius(8)
    .backgroundColor(this.iconKey === icon.key ? $r('app.color.text_secondary') : Color.Transparent)
    .accessibilityDescription(icon.key)
    .focusable(true)
    .onClick((): void => {
      this.iconKey = icon.key;
    })
  }

  build() {
    Column() {
      // 自绘 App Bar（Spec 067：返回 + 标题 + SAVE）
      Row() {
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
        Text($r('app.string.shortcut_create_title'))
          .fontSize($r('app.float.title_font_size'))
          .fontWeight(600)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
        Text($r('app.string.edit_work_save'))
          .fontSize($r('app.float.sub_text_font_size'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.link_blue'))
          .padding({ left: 6, right: 12, top: 6, bottom: 6 })
          .responseRegion({ x: -6, y: -7, width: '130%', height: '147%' })
          .onClick(() => this.save())
      }
      .width('100%')
      .height(48)
      .padding({ left: 4, right: 4 })

      PageShadowBar({ show: this.scrollShadow })

      Scroll() {
        Column() {
          this.nameRow()

          this.sectionGap()

          this.scopeRow()
          this.typeRow()

          // 筛选 chips（复用 WorkFilterBar：漏斗徽标照常显示（激活组数蓝圈计数），菜单只留
          // Clear all filters（创建页内不再嵌 Create Shortcut 入口）；预填应用后再挂，初始态一次性生效）
          if (this.filterReady) {
            WorkFilterBar({
              token: this.token,
              resetTick: this.resetTick,
              initialState: this.filter,
              showCreateShortcutItem: false,
              stateOptions: this.stateOptions(),
              scopeOptions: this.scopeOptions(),
              onQueryChange: (s: WorkFilterState): void => {
                this.filter = s;
              }
            })
          }

          this.sectionGap()

          // 颜色行（7 色，与图标网格同槽位/间距/轮廓，静态一排不横滚——用户 2026-09-21 定案）
          Row() {
            ForEach(SHORTCUT_COLORS, (spec: ShortcutColorSpec) => {
              this.colorCell(spec)
            }, (spec: ShortcutColorSpec) => spec.key)
          }
          .width('100%')
          .justifyContent(FlexAlign.SpaceBetween)
          .padding({ left: 8, right: 8, top: 12, bottom: 12 })

          // 图标网格（官方固定 7 列；整行均匀分布，末行 inbox 单枚居中）
          Column() {
            ForEach(this.iconRows(), (row: ShortcutIconSpec[], rowIndex: number) => {
              Row() {
                ForEach(row, (icon: ShortcutIconSpec) => {
                  this.iconCell(icon)
                }, (icon: ShortcutIconSpec) => icon.key)
              }
              .width('100%')
              .justifyContent(row.length < 7 ? FlexAlign.Center : FlexAlign.SpaceBetween)
            }, (row: ShortcutIconSpec[], rowIndex: number) => `row_${rowIndex}`)
          }
          .width('100%')
          .padding({ left: 8, right: 8, bottom: 24 })
        }
        .width('100%')
      }
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
      .layoutWeight(1)
      .onScroll((_x: number, y: number): void => {
        this.scrollShadow = y > 0.001;
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.card_background'))
  }
}
