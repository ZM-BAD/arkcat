/**
 * Shortcuts 管理页（Spec 074）：Home 快捷方式（已保存搜索）增删排序与建议添加。
 * Saved 区（× 移除 / 拖拽或 ▲▼ 排序 / 点击行打开结果列表）+ CREATE SHORTCUT 行
 * + Suggested 区（全局 3 条 + viewer 仓库前 3，⊕ 追加）。
 * 快照编辑：返回静默丢弃；SAVE 落盘（Preferences 按 login 分区）后经 onSaved 泵回 Home/管理页。
 * ⋮ 菜单切换重排模式（Show/Hide reorder actions），交互范式同 FavoritesEdit（Spec 050/016）。
 * 官方两截图均带底部 Tab，本页不进 TAB_BAR_HIDDEN_ROUTES。
 */
import { promptAction } from '@kit.ArkUI';
import { OctIcon } from '../components/OctIcon';
import { PageShadowBar } from '../components/PageShadowBar';
import { StateView } from '../components/StateView';
import { AccountStore, AccountInfo } from '../services/AccountStore';
import { RepoSubService } from '../services/RepoSubService';
import { friendlyError } from '../services/GitHttpClient';
import { PickerRepo } from '../models/RepoSubModels';
import {
  ShortcutColorSpec, ShortcutSuggestion, shortcutColor, shortcutIconRes,
  globalShortcutSuggestions, REPO_SUGGESTION_ICON, REPO_SUGGESTION_ICON_KEY, REPO_SUGGESTION_COLOR_KEY
} from '../models/ShortcutPalette';
import {
  ShortcutItem, ShortcutStore, addShortcut, removeShortcut, moveShortcut, sameShortcutQuery
} from '../utils/Shortcuts';
import { resText } from '../utils/I18n';

/** ⋮ 菜单项（bindMenu 数组不随状态刷新，见 FavoritesEdit 同款注释） */
interface ReorderMenuEntry {
  value: ResourceStr;
  action: () => void;
}

/** 建议行视图模型（文案解析为当前语言字符串后统一渲染） */
interface SuggestionRow {
  sugKey: string;
  iconKey: string;
  iconRes: Resource;
  colorKey: string;
  head: string;
  label: string;
  kind: string;
  query: string;
  name: string;
}

/** 列表统一行：Saved/建议两区平铺进同一 List（拖拽索引按平铺位计算，非 Saved 行不可拖） */
interface ShortcutRowItem {
  kind: string; // 'savedHeader' | 'saved' | 'noSaved' | 'gap' | 'createRow' | 'sugHeader' | 'suggestion' | 'sugStatus'
  saved: ShortcutItem | null;
  sugg: SuggestionRow | null;
}

@ComponentV2
export struct ShortcutsView {
  @Param token: string = '';
  @Param pathStack: NavPathStack = new NavPathStack();
  @Param onSaved: () => void = () => {};
  /** 编辑快照：返回不保存；SAVE 时写回 store（同 FavoritesEdit 官方口径） */
  @Local snapshot: ShortcutItem[] = [];
  /** 快照加载完成前不渲染（避免闪一帧空列表） */
  @Local loaded: boolean = false;
  /** 仓库建议（viewer 仓库最近推送序，取前 3） */
  @Local sugRepos: PickerRepo[] = [];
  @Local sugLoading: boolean = true;
  @Local sugError: string = '';
  /** 重排模式（⋮ 菜单切换）：Saved 行右以 ▲▼ 替代拖拽柄 */
  @Local reorderMode: boolean = false;
  @Local menuItems: ReorderMenuEntry[] = [];
  /** 滚动顶部阴影（滚动中显示、回顶消失） */
  @Local scrollShadow: boolean = false;

  aboutToAppear(): void {
    this.rebuildMenu();
    this.loadSnapshot();
    this.loadSuggestionRepos();
  }

  /** 当前账号分区快照（快捷方式为端侧按 login 隔离存储，Spec 074 §四） */
  private loadSnapshot(): void {
    const ctx = this.getUIContext().getHostContext();
    AccountStore.getCurrentAccount(ctx)
      .then((acc: AccountInfo | null) => ShortcutStore.load(ctx, acc !== null ? acc.login : ''))
      .then(() => {
        this.snapshot = ShortcutStore.instance.list.slice();
        this.loaded = true;
      })
      .catch(() => {
        this.loaded = true;
      });
  }

  /** 仓库建议候选（050 候选同源：自有/协作/组织成员，最近推送序） */
  private loadSuggestionRepos(): void {
    this.sugLoading = true;
    this.sugError = '';
    RepoSubService.fetchPickerRepos(this.token)
      .then((list: PickerRepo[]) => {
        this.sugRepos = list;
        this.sugLoading = false;
      })
      .catch((e: Error) => {
        this.sugError = friendlyError(this.getUIContext(), e);
        this.sugLoading = false;
      });
  }

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

  private stringOf(res: Resource): string {
    return resText(this.getUIContext(), res);
  }

  /** kind → 类型标签资源（head 空串兜底用，与创建页名称占位共用文案源） */
  private kindLabelRes(kind: string): Resource {
    return kind === 'prs'
      ? $r('app.string.home_work_pull_requests') : $r('app.string.home_work_issues');
  }

  /** Saved 行首行文案：优先持久化的建议行首行原文（Issues/Pull Requests/owner·name），空则按 kind 兜底 */
  private savedHeadOf(item: ShortcutItem): string {
    if (item.head !== '') {
      return item.head;
    }
    return this.stringOf(this.kindLabelRes(item.kind));
  }

  private removeSaved(item: ShortcutItem): void {
    this.snapshot = removeShortcut(this.snapshot, item.id);
  }

  /** 建议追加到 Saved 快照末尾（两行文案原样保留：head=建议行首行，name=建议行次行；同语义建议随即隐藏） */
  private addSuggestion(row: SuggestionRow): void {
    this.snapshot = addShortcut(this.snapshot, {
      id: `sc_${row.sugKey}_${Date.now()}`,
      name: row.name,
      head: row.head,
      kind: row.kind,
      query: row.query,
      iconKey: row.iconKey,
      colorKey: row.colorKey,
      createdAt: Date.now()
    });
  }

  /** 点击快捷方式 → 结果列表（046 searchResults 通道，kind|query 参数；类型限定词由通道追加）。
   *  discussions 例外：公开 API 无 discussions 搜索（GraphQL is:discussion 实测被忽略返回普通
   *  Issue，spec 074 §五）→ 明确提示而非给出错误结果 */
  private openShortcut(item: ShortcutItem): void {
    if (item.kind === 'discussions') {
      promptAction.showToast({ message: $r('app.string.shortcut_discussions_unsupported') });
      return;
    }
    this.pathStack.pushPathByName('searchResults', `${item.kind}|${item.query}`);
  }

  private save(): void {
    ShortcutStore.instance.list = this.snapshot.slice();
    ShortcutStore.save(this.getUIContext().getHostContext());
    this.onSaved();
    this.pathStack.pop();
  }

  /** 建议行装配：全局 3 条 + 仓库前 3；已保存（快照）中同 kind+query 的建议隐藏 */
  private suggestions(): SuggestionRow[] {
    const savedKeys: Set<string> = new Set();
    for (const s of this.snapshot) {
      savedKeys.add(sameShortcutQuery(s.kind, s.query));
    }
    const rows: SuggestionRow[] = [];
    for (const g of globalShortcutSuggestions()) {
      if (savedKeys.has(sameShortcutQuery(g.kind, g.query))) {
        continue;
      }
      const label = this.stringOf(g.labelRes);
      rows.push({
        sugKey: g.sugKey,
        iconKey: g.iconKey,
        iconRes: g.iconRes,
        colorKey: g.colorKey,
        head: this.stringOf(g.headRes),
        label: label,
        kind: g.kind,
        query: g.query,
        name: label
      });
    }
    if (this.sugError === '' && !this.sugLoading) {
      let taken = 0;
      for (const repo of this.sugRepos) {
        if (taken >= 3) {
          break;
        }
        const query = `repo:${repo.ownerLogin}/${repo.name} is:open sort:created-desc`;
        if (savedKeys.has(sameShortcutQuery('issues', query))) {
          continue;
        }
        rows.push({
          sugKey: 'repo',
          iconKey: REPO_SUGGESTION_ICON_KEY,
          iconRes: REPO_SUGGESTION_ICON,
          colorKey: REPO_SUGGESTION_COLOR_KEY,
          head: `${repo.ownerLogin} / ${repo.name}`,
          label: this.stringOf($r('app.string.shortcut_sugg_repo_summary')),
          kind: 'issues',
          query: query,
          name: repo.name
        });
        taken++;
      }
    }
    return rows;
  }

  /** 两区平铺行 */
  private items(): ShortcutRowItem[] {
    const rows: ShortcutRowItem[] = [];
    rows.push({ kind: 'savedHeader', saved: null, sugg: null });
    if (this.snapshot.length === 0) {
      rows.push({ kind: 'noSaved', saved: null, sugg: null });
    } else {
      for (const s of this.snapshot) {
        rows.push({ kind: 'saved', saved: s, sugg: null });
      }
    }
    rows.push({ kind: 'gap', saved: null, sugg: null });
    rows.push({ kind: 'createRow', saved: null, sugg: null });
    rows.push({ kind: 'gap', saved: null, sugg: null });
    rows.push({ kind: 'sugHeader', saved: null, sugg: null });
    if (this.sugLoading || this.sugError !== '') {
      rows.push({ kind: 'sugStatus', saved: null, sugg: null });
    }
    for (const sugg of this.suggestions()) {
      rows.push({ kind: 'suggestion', saved: null, sugg: sugg });
    }
    return rows;
  }

  /** 拖拽排序（List.onMove 平铺位 → Saved 区间内映射；Saved 行占平铺位 [1, snapshot.length]，0 为区块头；越界即落回原位） */
  private onListMove(from: number, to: number): void {
    const last = this.snapshot.length;
    if (from < 1 || from > last || to < 1 || to > last || from === to) {
      return;
    }
    this.snapshot = moveShortcut(this.snapshot, from - 1, to - 1);
  }

  /** 该方向的相邻位是否存在（首行不可上移 / 末行不可下移，同 FavoritesEdit） */
  private canMove(index: number, delta: number): boolean {
    const target = index + delta;
    return target >= 0 && target < this.snapshot.length;
  }

  private moveBy(index: number, delta: number): void {
    if (this.canMove(index, delta)) {
      this.snapshot = moveShortcut(this.snapshot, index, index + delta);
    }
  }

  /** 建议行 tile：浅色圆角方底 + 同系字形（色板 bg/fg 对） */
  @Builder
  suggestionTile(iconRes: Resource, spec: ShortcutColorSpec) {
    Stack() {
      OctIcon({ res: iconRes, iconSize: 20, iconColor: spec.fg })
    }
    .width(40)
    .height(40)
    .borderRadius(8)
    .backgroundColor(spec.bg)
  }

  /** Saved 行：行首灰圆 × 移除 + tile + 名称 + 拖拽柄/▲▼（行解剖同 FavoritesEdit Selected 行） */
  @Builder
  savedRow(item: ShortcutRowItem, index: number) {
    Row() {
      Stack() {
        Stack() {
          OctIcon({ res: $r('app.media.oct_x_16'), iconSize: 16, iconColor: Color.White })
        }
        .width(30)
        .height(30)
        .borderRadius(15)
        .backgroundColor($r('app.color.text_secondary'))
      }
      .width(40)
      .height(44)
      .accessibilityDescription($r('app.string.a11y_remove'))
      .focusable(true)
      .onClick((): void => this.removeSaved(item.saved as ShortcutItem))

      Row({ space: 14 }) {
        this.suggestionTile(shortcutIconRes((item.saved as ShortcutItem).iconKey),
          shortcutColor((item.saved as ShortcutItem).colorKey))
        // 两行式与建议行同款（用户 2026-09-21 定案）：首行=建议行首行原文持久化，次行=名称主色加粗
        Column({ space: 2 }) {
          Text(this.savedHeadOf(item.saved as ShortcutItem))
            .fontSize($r('app.float.body_font_size'))
            .fontColor($r('app.color.text_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text((item.saved as ShortcutItem).name)
            .fontSize($r('app.float.body_font_size'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .layoutWeight(1)
      .alignItems(VerticalAlign.Center)
      .onClick((): void => this.openShortcut(item.saved as ShortcutItem))

      // 重排模式让位给 ▲▼；常态显示拖拽柄（Spec 016：两种改序方式分模式，不同屏并存）
      // index 为平铺位，Saved 行快照下标 = index - 1（0 是区块头）；首行 ▲/末行 ▼ 边界由此置灰
      if (this.reorderMode) {
        this.moveButton(index - 1, -1)
        this.moveButton(index - 1, 1)
      } else {
        OctIcon({ res: $r('app.media.oct_grabber_16'), iconSize: 18, iconColor: $r('app.color.text_secondary') })
          .padding({ left: 8, right: 8 })
      }
    }
    .width('100%')
    .height(72)
    .alignItems(VerticalAlign.Center)
    .padding({ left: 12, right: 8 })
  }

  /** 建议行：tile + 两行文本（首行次级色 + 次行主色加粗）+ 蓝色 ⊕ */
  @Builder
  suggestionRow(item: ShortcutRowItem) {
    Row() {
      this.suggestionTile((item.sugg as SuggestionRow).iconRes,
        shortcutColor((item.sugg as SuggestionRow).colorKey))
      Column({ space: 2 }) {
        Text((item.sugg as SuggestionRow).head)
          .fontSize($r('app.float.body_font_size'))
          .fontColor($r('app.color.text_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text((item.sugg as SuggestionRow).label)
          .fontSize($r('app.float.body_font_size'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ left: 14 })

      Stack() {
        OctIcon({ res: $r('app.media.oct_plus_circle_24'), iconSize: 24, iconColor: $r('app.color.link_blue') })
      }
      .width(44)
      .height(44)
      .padding(8)
      .accessibilityDescription($r('app.string.a11y_add'))
      .focusable(true)
      .onClick((): void => this.addSuggestion(item.sugg as SuggestionRow))
    }
    .width('100%')
    .height(72)
    .alignItems(VerticalAlign.Center)
    .padding({ left: 16, right: 8 })
  }

  /** 重排模式行右按钮：▲/▼（可点为黑 text_primary，首行 ▲ 与末行 ▼ 置灰不可点） */
  @Builder
  moveButton(index: number, delta: number) {
    Stack() {
      OctIcon({
        res: delta < 0 ? $r('app.media.oct_chevron_up_16') : $r('app.media.oct_chevron_down_16'),
        iconSize: 18,
        iconColor: this.canMove(index, delta) ? $r('app.color.text_primary') : $r('app.color.text_tertiary')
      })
    }
    .width(40)
    .height(44)
    .enabled(this.canMove(index, delta))
    .accessibilityDescription(delta < 0 ? $r('app.string.a11y_move_up') : $r('app.string.a11y_move_down'))
    .focusable(true)
    .onClick((): void => this.moveBy(index, delta))
  }

  /** 建议区状态行：加载 / 错误重试（仅仓库建议通道；全局 3 条不受影响） */
  @Builder
  sugStatusRow() {
    Column() {
      if (this.sugLoading) {
        StateView({ loading: true })
      } else {
        StateView({ error: this.sugError, onRetry: (): void => this.loadSuggestionRepos() })
      }
    }
    .width('100%')
  }

  @Builder
  row(item: ShortcutRowItem, index: number) {
    if (item.kind === 'savedHeader' || item.kind === 'sugHeader') {
      // 官方两区块头均为次级色常规字重（区别于 FavoritesEdit 黑色加粗区块头）
      Text(item.kind === 'savedHeader'
        ? $r('app.string.shortcuts_saved') : $r('app.string.shortcuts_suggested'))
        .fontSize($r('app.float.title_font_size'))
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
        .padding({ left: 16, right: 16, top: 14, bottom: 6 })
    } else if (item.kind === 'saved') {
      this.savedRow(item, index)
    } else if (item.kind === 'noSaved') {
      Text($r('app.string.shortcuts_no_saved'))
        .fontSize($r('app.float.body_font_size'))
        .fontColor($r('app.color.text_primary'))
        .width('100%')
        .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    } else if (item.kind === 'gap') {
      // 官方区块之间的灰隙（页面底色分段）
      Row()
        .width('100%')
        .height(8)
        .backgroundColor($r('app.color.bg_page'))
    } else if (item.kind === 'createRow') {
      Row({ space: 14 }) {
        OctIcon({ res: $r('app.media.oct_plus_16'), iconSize: 20, iconColor: $r('app.color.link_blue') })
        Text($r('app.string.shortcuts_create_shortcut'))
          .fontSize($r('app.float.body_font_size'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.link_blue'))
      }
      .width('100%')
      .height(64)
      .alignItems(VerticalAlign.Center)
      .padding({ left: 16, right: 16 })
      .onClick((): void => this.pathStack.pushPathByName('shortcutCreate', ''))
    } else if (item.kind === 'suggestion') {
      this.suggestionRow(item)
    } else {
      this.sugStatusRow()
    }
  }

  build() {
    Column() {
      // 自绘 App Bar（Spec 067：文字动作头保留自绘，同 FavoritesEdit）
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
          // 官方口径：返回静默丢弃（快照不落盘）
          this.pathStack.pop();
        })
        Text($r('app.string.home_shortcuts'))
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
        // 蓝色竖点（全库惯例 kebab-horizontal 旋转 90°）→ 重排模式菜单
        Stack() {
          OctIcon({
            res: $r('app.media.oct_kebab_horizontal_16'),
            iconSize: 20,
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
      .padding({ left: 4, right: 4 })

      PageShadowBar({ show: this.scrollShadow })

      // 配置加载完成前不渲染（避免闪一帧空列表，同 016 configLoaded 门禁）
      if (this.loaded) {
        List() {
          ForEach(this.items(), (item: ShortcutRowItem, index: number) => {
            ListItem() {
              this.row(item, index)
            }
          // key 必须含 index：顺序变化时若不换 key，ForEach 复用同 key 组件、行不会重排
          }, (item: ShortcutRowItem, index: number) => {
            const id = item.kind === 'saved'
              ? (item.saved as ShortcutItem).id
              : (item.kind === 'suggestion' ? `sugg-${(item.sugg as SuggestionRow).sugKey}-${(item.sugg as SuggestionRow).query}`
                : item.kind);
            return `${index}-${item.kind}-${id}`;
          })
            // 拖拽排序：离手后 onMove 上报平铺位，守卫映射进 Saved 区间（其余行落回原位）
            .onMove((from: number, to: number): void => {
              this.onListMove(from, to);
            })
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .onScroll((scrollOffset: number, _state: number): void => { this.scrollShadow = scrollOffset > 0.001; })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.card_background'))
  }
}
