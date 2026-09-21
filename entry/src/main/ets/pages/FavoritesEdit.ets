/**
 * Favorites 编辑页（Spec 050）：Home 收藏仓库管理。
 * Selected 区（× 移除 / 拖拽或 ▲▼ 排序）+ Select Repositories 区
 * （默认 Top Repositories，搜索时为全 GitHub 检索，⊕ 添加）。
 * 快照编辑：返回静默丢弃；SAVE 落盘（Preferences 按 login 分区）后经 onSaved 泵回 Home。
 * ⋮ 菜单切换重排模式（Show/Hide reorder actions），交互范式同 Edit My Work（Spec 016）。
 */
import { OctIcon } from '../components/OctIcon';
import { PageShadowBar } from '../components/PageShadowBar';
import { StateView } from '../components/StateView';
import { Avatar } from '../components/Avatar';
import { RepoSubService } from '../services/RepoSubService';
import { friendlyError } from '../services/GitHttpClient';
import { AccountStore, AccountInfo } from '../services/AccountStore';
import { PickerRepo, pickerRepoFullName } from '../models/RepoSubModels';
import { resText } from '../utils/I18n';
import {
  FavoriteRepo, FavoritesStore, addFavorite, removeFavorite, moveFavorite,
  filterCandidates, isSearchable
} from '../utils/Favorites';

/** ⋮ 菜单项（bindMenu 数组不随状态刷新，见 EditMyWork 同款注释） */
interface ReorderMenuEntry {
  value: ResourceStr;
  action: () => void;
}

/** 列表统一行：Selected 与候选两区平铺进同一 List（拖拽索引按平铺位计算，gap 行不可拖） */
interface FavRowItem {
  kind: string; // 'selHeader' | 'selected' | 'gap' | 'candHeader' | 'candidate' | 'status'
  sel: FavoriteRepo | null;
  cand: PickerRepo | null;
}

@ComponentV2
export struct FavoritesEditView {
  @Param token: string = '';
  @Param pathStack: NavPathStack = new NavPathStack();
  @Param onSaved: () => void = () => {};
  /** 编辑快照：返回不保存；SAVE 时写回 store（Spec 050：官方口径静默丢弃） */
  @Local snapshot: FavoriteRepo[] = [];
  /** 快照加载完成前不渲染（避免闪一帧空列表） */
  @Local loaded: boolean = false;
  /** 候选区（Top Repositories）状态 */
  @Local candidates: PickerRepo[] = [];
  @Local candLoading: boolean = true;
  @Local candError: string = '';
  /** 搜索（服务端全网检索，竞态按代际丢弃，同 RepoPicker 范式） */
  @Local keyword: string = '';
  @Local searchResults: PickerRepo[] = [];
  @Local searching: boolean = false;
  @Local searchError: string = '';
  private searchSeq: number = 0;
  /** 重排模式（⋮ 菜单切换）：Selected 行右以 ▲▼ 替代拖拽柄 */
  @Local reorderMode: boolean = false;
  @Local menuItems: ReorderMenuEntry[] = [];
  /** 滚动顶部阴影（滚动中显示、回顶消失） */
  @Local scrollShadow: boolean = false;

  aboutToAppear(): void {
    this.rebuildMenu();
    this.loadSnapshot();
    this.loadCandidates();
  }

  /** 当前账号分区快照（收藏为端侧按 login 隔离存储，Spec 050 §四） */
  private loadSnapshot(): void {
    const ctx = this.getUIContext().getHostContext();
    AccountStore.getCurrentAccount(ctx)
      .then((acc: AccountInfo | null) => FavoritesStore.load(ctx, acc !== null ? acc.login : ''))
      .then(() => {
        this.snapshot = FavoritesStore.instance.list.slice();
        this.loaded = true;
      })
      .catch(() => {
        this.loaded = true;
      });
  }

  /** Top Repositories 候选（官方选仓同源：自有/协作/组织成员 ∪ 贡献过，最近推送序前 100） */
  private loadCandidates(): void {
    this.candLoading = true;
    this.candError = '';
    RepoSubService.fetchPickerRepos(this.token)
      .then((list: PickerRepo[]) => {
        this.candidates = list;
        this.candLoading = false;
      })
      .catch((e: Error) => {
        this.candError = friendlyError(this.getUIContext(), e);
        this.candLoading = false;
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

  /** 服务端全 GitHub 仓库搜索（trim 为空不触发；代际守卫丢弃过期响应） */
  private runSearch(): void {
    const q = this.keyword.trim();
    const seq = ++this.searchSeq;
    if (!isSearchable(q)) {
      this.searchResults = [];
      this.searching = false;
      this.searchError = '';
      return;
    }
    this.searching = true;
    this.searchError = '';
    RepoSubService.searchPickerRepos(this.token, q)
      .then((list: PickerRepo[]) => {
        if (seq === this.searchSeq) {
          this.searchResults = list;
          this.searching = false;
        }
      })
      .catch((e: Error) => {
        if (seq === this.searchSeq) {
          this.searchResults = [];
          this.searchError = friendlyError(this.getUIContext(), e);
          this.searching = false;
        }
      });
  }

  private addCandidate(repo: PickerRepo): void {
    this.snapshot = addFavorite(this.snapshot, {
      ownerLogin: repo.ownerLogin,
      name: repo.name,
      ownerAvatar: repo.ownerAvatar,
      addedAt: Date.now()
    });
  }

  private removeSel(item: FavoriteRepo): void {
    this.snapshot = removeFavorite(this.snapshot, item.ownerLogin, item.name);
  }

  private save(): void {
    FavoritesStore.instance.list = this.snapshot.slice();
    FavoritesStore.save(this.getUIContext().getHostContext());
    this.onSaved();
    this.pathStack.pop();
  }

  /** 两区平铺行（Selected 区间 = [1, snapshot.length]，0 为区块头） */
  private items(): FavRowItem[] {
    const rows: FavRowItem[] = [{ kind: 'selHeader', sel: null, cand: null }];
    for (const f of this.snapshot) {
      rows.push({ kind: 'selected', sel: f, cand: null });
    }
    rows.push({ kind: 'gap', sel: null, cand: null });
    rows.push({ kind: 'candHeader', sel: null, cand: null });
    if (isSearchable(this.keyword)) {
      if (this.searching || this.searchError !== '') {
        rows.push({ kind: 'status', sel: null, cand: null });
      } else if (this.searchResults.length > 0) {
        for (const c of filterCandidates(this.searchResults, this.snapshot)) {
          rows.push({ kind: 'candidate', sel: null, cand: c });
        }
      } else {
        rows.push({ kind: 'status', sel: null, cand: null });
      }
    } else if (this.candLoading || this.candError !== '') {
      rows.push({ kind: 'status', sel: null, cand: null });
    } else {
      for (const c of filterCandidates(this.candidates, this.snapshot)) {
        rows.push({ kind: 'candidate', sel: null, cand: c });
      }
    }
    return rows;
  }

  /** 拖拽排序（List.onMove 平铺位 → Selected 区间内映射；越界即落回原位） */
  private onListMove(from: number, to: number): void {
    const last = this.snapshot.length;
    if (from < 1 || from > last || to < 1 || to > last || from === to) {
      return;
    }
    this.snapshot = moveFavorite(this.snapshot, from - 1, to - 1);
  }

  /** 该方向的相邻位是否存在（首行不可上移 / 末行不可下移，同 EditMyWork） */
  private canMove(index: number, delta: number): boolean {
    const target = index + delta;
    return target >= 0 && target < this.snapshot.length;
  }

  private moveBy(index: number, delta: number): void {
    if (this.canMove(index, delta)) {
      this.snapshot = moveFavorite(this.snapshot, index, index + delta);
    }
  }

  private stringOf(res: Resource): string {
    return resText(this.getUIContext(), res);
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

  /** 行主内容：头像 + owner 灰字 + 仓库名（与 RepoPicker 行同款，官方两行式） */
  @Builder
  repoTexts(ownerLogin: string, ownerAvatar: string, name: string) {
    Row({ space: 14 }) {
      Avatar({ url: ownerAvatar, diameter: 40, fallbackIcon: true })
      Column({ space: 2 }) {
        Text(ownerLogin)
          .fontSize($r('app.float.body_font_size'))
          .fontColor($r('app.color.text_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(name)
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
  }

  @Builder
  selectedRow(item: FavRowItem, index: number) {
    Row() {
      // 官方：行首实心灰圆 × 移除钮（44×44 触点内 30 圆面）
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
      .onClick((): void => this.removeSel(item.sel as FavoriteRepo))

      this.repoTexts((item.sel as FavoriteRepo).ownerLogin, (item.sel as FavoriteRepo).ownerAvatar,
        (item.sel as FavoriteRepo).name)

      // 重排模式让位给 ▲▼；常态显示拖拽柄（Spec 016：两种改序方式分模式，不同屏并存）
      if (this.reorderMode) {
        this.moveButton(index - 1, -1)
        this.moveButton(index - 1, 1)
      } else {
        OctIcon({ res: $r('app.media.oct_grabber_16'), iconSize: 18, iconColor: $r('app.color.text_secondary') })
          .padding({ left: 8, right: 8 })
      }
    }
    .width('100%')
    .height(64)
    .alignItems(VerticalAlign.Center)
    .padding({ left: 12, right: 8 })
  }

  @Builder
  candidateRow(item: FavRowItem) {
    Row() {
      this.repoTexts((item.cand as PickerRepo).ownerLogin, (item.cand as PickerRepo).ownerAvatar,
        (item.cand as PickerRepo).name)
      Stack() {
        OctIcon({ res: $r('app.media.oct_plus_circle_24'), iconSize: 24, iconColor: $r('app.color.link_blue') })
      }
      .width(44)
      .height(44)
      .padding(8)
      .accessibilityDescription($r('app.string.a11y_add'))
      .focusable(true)
      .onClick((): void => this.addCandidate(item.cand as PickerRepo))
    }
    .width('100%')
    .height(64)
    .alignItems(VerticalAlign.Center)
    .padding({ left: 16, right: 8 })
  }

  /** 候选区状态行：加载 / 错误重试 / 搜索无结果 */
  @Builder
  statusRow() {
    Column() {
      if (isSearchable(this.keyword)) {
        if (this.searching) {
          StateView({ loading: true })
        } else if (this.searchError !== '') {
          StateView({ error: this.searchError, onRetry: (): void => this.runSearch() })
        } else {
          StateView({ empty: true, emptyText: $r('app.string.search_no_results') })
        }
      } else if (this.candLoading) {
        StateView({ loading: true })
      } else {
        StateView({ error: this.candError, onRetry: (): void => this.loadCandidates() })
      }
    }
    .width('100%')
  }

  @Builder
  row(item: FavRowItem, index: number) {
    if (item.kind === 'selHeader') {
      Text($r('app.string.favorites_selected'))
        .fontSize($r('app.float.section_title_font_size'))
        .fontWeight(600)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
        .padding({ left: 16, right: 16, top: 12, bottom: 4 })
    } else if (item.kind === 'selected') {
      this.selectedRow(item, index)
    } else if (item.kind === 'gap') {
      // 官方两区之间的灰隙（页面底色分段）
      Row()
        .width('100%')
        .height(8)
        .backgroundColor($r('app.color.bg_page'))
    } else if (item.kind === 'candHeader') {
      Text($r('app.string.favorites_select_repositories'))
        .fontSize($r('app.float.section_title_font_size'))
        .fontWeight(600)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
        .padding({ left: 16, right: 16, top: 12, bottom: 4 })
    } else if (item.kind === 'candidate') {
      this.candidateRow(item)
    } else {
      this.statusRow()
    }
  }

  build() {
    Column() {
      // 自绘 App Bar（Spec 067：文字动作头保留自绘，同 EditMyWork）
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
        Text($r('app.string.home_favorites'))
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

      // 搜索框（官方：🔍 + Search Repositories 占位；输入切换候选区为全网检索）
      Row({ space: 8 }) {
        OctIcon({ res: $r('app.media.oct_search_16'), iconSize: 16, iconColor: $r('app.color.text_secondary') })
        TextInput({
          placeholder: this.stringOf($r('app.string.favorites_search_hint')),
          text: this.keyword
        })
          .id('favorites_search')
          .layoutWeight(1)
          .height(40)
          .fontSize($r('app.float.body_font_size'))
          .fontColor($r('app.color.text_primary'))
          .placeholderColor($r('app.color.text_tertiary'))
          .caretColor($r('app.color.link_blue'))
          .backgroundColor(Color.Transparent)
          .onChange((v: string) => {
            this.keyword = v;
            this.runSearch();
          })
      }
      .width('100%')
      .height(40)
      .padding({ left: 12, right: 12 })
      .backgroundColor($r('app.color.input_bg'))
      .borderRadius($r('app.float.button_radius'))
      .margin({ left: 16, right: 16, top: 4, bottom: 12 })

      // 配置加载完成前不渲染 Selected（避免闪一帧空列表，同 016 configLoaded 门禁）
      if (this.loaded) {
        List() {
          ForEach(this.items(), (item: FavRowItem, index: number) => {
            ListItem() {
              this.row(item, index)
            }
          // key 必须含 index：顺序变化时若不换 key，ForEach 复用同 key 组件、行不会重排
          }, (item: FavRowItem, index: number) => {
            const id = item.kind === 'selected'
              ? `${(item.sel as FavoriteRepo).ownerLogin}/${(item.sel as FavoriteRepo).name}`
              : (item.kind === 'candidate'
                ? pickerRepoFullName(item.cand as PickerRepo)
                : item.kind);
            return `${index}-${item.kind}-${id}`;
          })
            // 拖拽排序：离手后 onMove 上报平铺位，守卫映射进 Selected 区间（候选/gap 行落回原位）
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
