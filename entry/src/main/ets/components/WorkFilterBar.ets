/**
 * 工作区筛选行（Spec 017/018 共用）：State/Scope/Visibility 自绘下拉（选中蓝勾）+ Organization/Repository
 * 多选 Bottom Sheet（头像+搜索+蓝勾 toggle）+ Sort by 四组单选 Sheet（radio + Most reactions emoji）。
 * 全部筛选进服务端 qualifier（org:/repo: 多值、sort: 键）；任何变化经 onQueryChange 上抛，页面据此重查。
 * 空列表显示官方「Nothing to see here」（无组织/仓库或搜索无匹配时）。
 */
import { promptAction } from '@kit.ArkUI';
import { OctIcon } from '../components/OctIcon';
import { WorkOrgItem, WorkTopRepoItem, WorkTopReposPage } from '../models/WorkModels';
import { WorkService } from '../services/WorkService';
import { friendlyError } from '../services/GitHttpClient';
import { ProfileListService } from '../services/ProfileListService';
import { OrgListPage, OrgSummary } from '../models/ProfileModels';
import { StateView } from './StateView';
import { resText } from '../utils/I18n';

/** 下拉选项（调用方以当前语言文案构建） */
export interface WorkFilterOption {
  key: string;
  label: string;
}

/** 筛选快照（页面据此拼服务端查询） */
export interface WorkFilterState {
  state: string;
  scope: string;
  visibility: string;
  sortKey: string;
  orgs: string[];
  repos: string[];
}

/** 默认筛选（官方默认态：Open / Created by me / Show all / Sort: Newest） */
export function defaultWorkFilter(): WorkFilterState {
  return { state: 'open', scope: 'created', visibility: 'all', sortKey: 'newest', orgs: [], repos: [] };
}

/** 自绘下拉选项 */
interface DropdownOption {
  key: string;
  label: string;
}

/** Sort by 单选选项 */
interface SortOption {
  key: string;
  label: string;
}

/** Most reactions emoji 槽位（confused 无服务端排序键，保留位） */
interface ReactionOption {
  key: string;
  emoji: string;
  disabled: boolean;
}

/** bindPopup 弹出状态事件 */
interface PopupState {
  isVisible: boolean;
}

/** 筛选 chip 参数（按引用传递，@Builder 传值参数不随状态刷新） */
interface ChipState {
  kind: string;
  label: string;
  active: boolean;
}

/** Sort 单选圆钮参数（按引用传递） */
interface SortRadioState {
  selected: boolean;
}

@ComponentV2
export struct WorkFilterBar {
  @Param token: string = '';
  @Param stateOptions: WorkFilterOption[] = [];
  @Param scopeOptions: WorkFilterOption[] = [];
  @Event onQueryChange: (s: WorkFilterState) => void = (s: WorkFilterState): void => { };

  @Local state: string = 'open';
  @Local scope: string = 'created';
  @Local visibilityFilter: string = 'all';
  @Local sortKey: string = 'newest';
  @Local selectedOrgs: string[] = [];
  @Local selectedRepos: string[] = [];
  /** 当前打开的弹出下拉（'state' | 'scope' | 'visibility' | ''） */
  @Local dropdownOpen: string = '';
  /** 弹层内容（'' | 'org' | 'repo' | 'sort'）：同一组件只挂一个 bindSheet，内部切换内容 */
  @Local sheetKind: string = '';
  @Local orgList: WorkOrgItem[] = [];
  @Local repoList: WorkTopRepoItem[] = [];
  @Local viewerLogin: string = '';
  @Local orgListLoading: boolean = false;
  /** 组织/仓库弹层拉取失败文案（review F15：失败不再伪装成空态） */
  @Local sheetLoadError: string = '';
  @Local repoListLoading: boolean = false;
  @Local orgSearch: string = '';
  @Local repoSearch: string = '';
  @Local orgSearchShow: boolean = false;
  @Local repoSearchShow: boolean = false;

  private static readonly REACTIONS: ReactionOption[] = [
    { key: 'reactions:+1', emoji: '👍', disabled: false },
    { key: 'reactions:-1', emoji: '👎', disabled: false },
    { key: 'reactions:laugh', emoji: '😂', disabled: false },
    { key: 'reactions:hooray', emoji: '🎉', disabled: false },
    { key: 'reactions:confused', emoji: '😕', disabled: true },
    { key: 'reactions:heart', emoji: '❤️', disabled: false },
    { key: 'reactions:rocket', emoji: '🚀', disabled: false },
    { key: 'reactions:eyes', emoji: '👀', disabled: false }
  ];

  private stringOf(res: Resource): string {
    return resText(this.getUIContext(), res);
  }

  /** 当前筛选变化 → 上抛快照，页面据此重查 */
  private emitChange(): void {
    this.onQueryChange({
      state: this.state,
      scope: this.scope,
      visibility: this.visibilityFilter,
      sortKey: this.sortKey,
      orgs: this.selectedOrgs,
      repos: this.selectedRepos
    });
  }

  private resetFilters(): void {
    this.state = 'open';
    this.scope = 'created';
    this.visibilityFilter = 'all';
    this.sortKey = 'newest';
    this.selectedOrgs = [];
    this.selectedRepos = [];
    this.emitChange();
  }

  /** 激活的筛选组数（漏斗徽标，按筛选组计） */
  private activeFilterCount(): number {
    let count = 0;
    if (this.state !== 'open') {
      count++;
    }
    if (this.scope !== 'created') {
      count++;
    }
    if (this.visibilityFilter !== 'all') {
      count++;
    }
    if (this.selectedOrgs.length > 0) {
      count++;
    }
    if (this.selectedRepos.length > 0) {
      count++;
    }
    if (this.sortKey !== 'newest') {
      count++;
    }
    return count;
  }

  private optionLabel(opts: WorkFilterOption[], key: string, fallback: string): string {
    for (const opt of opts) {
      if (opt.key === key) {
        return opt.label;
      }
    }
    return fallback;
  }

  private stateLabel(): string {
    return this.optionLabel(this.stateOptions, this.state, this.stringOf($r('app.string.work_filter_all')));
  }

  private scopeLabel(): string {
    return this.optionLabel(this.scopeOptions, this.scope, '');
  }

  /** 可见性：未筛选时 chip 显示名称（官方图 3），选中后显示值 */
  private visibilityLabel(): string {
    if (this.visibilityFilter === 'private') {
      return this.stringOf($r('app.string.issues_filter_visibility_private'));
    }
    if (this.visibilityFilter === 'public') {
      return this.stringOf($r('app.string.issues_filter_visibility_public'));
    }
    return this.stringOf($r('app.string.work_visibility'));
  }

  private sortLabel(): string {
    return resText(this.getUIContext(), $r('app.string.issues_filter_sort_prefix'), this.sortLabelCore());
  }

  private sortLabelCore(): string {
    if (this.sortKey === 'oldest') {
      return this.stringOf($r('app.string.issues_sort_oldest'));
    }
    if (this.sortKey === 'most_commented') {
      return this.stringOf($r('app.string.issues_sort_most_commented'));
    }
    if (this.sortKey === 'least_commented') {
      return this.stringOf($r('app.string.issues_sort_least_commented'));
    }
    if (this.sortKey === 'recently_updated') {
      return this.stringOf($r('app.string.issues_sort_recently_updated'));
    }
    if (this.sortKey === 'least_recently_updated') {
      return this.stringOf($r('app.string.issues_sort_least_recently_updated'));
    }
    if (this.sortKey.startsWith('reactions:')) {
      // 按 emoji 排序时，chip 显示 "Sort: <emoji>"（如 Sort: 👍）
      for (const r of WorkFilterBar.REACTIONS) {
        if (r.key === this.sortKey) {
          return r.emoji;
        }
      }
      return this.stringOf($r('app.string.issues_sort_most_reactions'));
    }
    return this.stringOf($r('app.string.issues_sort_newest'));
  }

  // ────────────────────────── 自绘下拉（State/Scope/Visibility） ──────────────────────────

  private menuOptions(kind: string): DropdownOption[] {
    if (kind === 'state') {
      return this.stateOptions;
    }
    if (kind === 'scope') {
      return this.scopeOptions;
    }
    return [
      { key: 'all', label: this.stringOf($r('app.string.issues_filter_visibility_all')) },
      { key: 'private', label: this.stringOf($r('app.string.issues_filter_visibility_private')) },
      { key: 'public', label: this.stringOf($r('app.string.issues_filter_visibility_public')) }
    ];
  }

  private menuSelected(kind: string, key: string): boolean {
    if (kind === 'state') {
      return this.state === key;
    }
    if (kind === 'scope') {
      return this.scope === key;
    }
    return this.visibilityFilter === key;
  }

  private onMenuPick(kind: string, key: string): void {
    if (kind === 'state') {
      this.state = key;
    } else if (kind === 'scope') {
      this.scope = key;
    } else {
      this.visibilityFilter = key;
    }
    this.dropdownOpen = '';
    this.emitChange();
  }

  @Builder
  dropdownCard(kind: string) {
    Column() {
      ForEach(this.menuOptions(kind), (opt: DropdownOption) => {
        Row() {
          Text(opt.label)
            .fontSize($r('app.float.body_font_size'))
            .fontColor($r('app.color.text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          if (this.menuSelected(kind, opt.key)) {
            OctIcon({ res: $r('app.media.oct_check_16'), iconSize: 16, iconColor: $r('app.color.link_blue') })
              .margin({ left: 8 })
          }
        }
        .width('100%')
        .height(44)
        .padding({ left: 14, right: 14 })
        .onClick((): void => this.onMenuPick(kind, opt.key))
      }, (opt: DropdownOption) => `${kind}:${opt.key}`)
    }
    .padding({ top: 6, bottom: 6 })
    .width(210)
    .borderRadius(12)
    .backgroundColor($r('app.color.card_background'))
    .shadow({ radius: 24, color: $r('app.color.shadow_floating'), offsetY: 8 })
  }

  @Builder
  filterChip($$: ChipState) {
    Row() {
      Text($$.label)
        .fontSize($r('app.float.chip_font_size'))
        .fontColor($$.active ? $r('app.color.link_blue') : $r('app.color.text_primary'))
      OctIcon({
        res: $r('app.media.oct_chevron_down_16'),
        iconSize: 12,
        iconColor: $$.active ? $r('app.color.link_blue') : $r('app.color.text_secondary')
      })
        .margin({ left: 8 })
    }
    .height(38)
    .responseRegion({ x: 0, y: -3, width: '100%', height: '116%' })
    .padding({ left: 10, right: 12 })
    .borderRadius(19)
    .backgroundColor($$.active ? $r('app.color.chip_active_bg') : $r('app.color.chip_bg'))
    .margin({ right: 8 })
    .border({ width: 1, color: $$.active ? $r('app.color.chip_active_border') : $r('app.color.border') })
    .onClick((): void => {
      if ($$.kind === 'org') {
        this.openOrgSheet();
      } else if ($$.kind === 'repo') {
        this.openRepoSheet();
      } else if ($$.kind === 'sort') {
        this.sheetKind = 'sort';
      } else {
        this.dropdownOpen = this.dropdownOpen === $$.kind ? '' : $$.kind;
      }
    })
    .bindPopup(this.dropdownOpen === $$.kind, {
      builder: (): void => this.dropdownCard($$.kind),
      placement: Placement.Bottom,
      enableArrow: false,
      mask: true,
      onStateChange: (e: PopupState): void => {
        if (!e.isVisible) {
          this.dropdownOpen = '';
        }
      }
    })
  }

  // ────────────────────────── 筛选弹层（Organization/Repository 多选） ──────────────────────────

  private openOrgSheet(): void {
    this.sheetKind = 'org';
    this.sheetLoadError = '';
    if (this.orgList.length === 0 && !this.orgListLoading) {
      this.loadOrgList();
    }
  }

  /** 组织列表：viewer login（GraphQL）→ REST /users/{login}/orgs（免 read:org scope） */
  private loadOrgList(): void {
    this.orgListLoading = true;
    const load = (login: string): void => {
      ProfileListService.fetchOrganizations(this.token, login, '')
        .then((page: OrgListPage) => {
          this.orgList = page.orgs.map((o: OrgSummary): WorkOrgItem => ({
            id: o.login,
            login: o.login,
            name: o.name !== '' ? o.name : o.login,
            avatarUrl: o.avatarUrl
          }));
          this.orgListLoading = false;
        })
        .catch((e: Error) => {
          this.orgListLoading = false;
          this.sheetLoadError = friendlyError(this.getUIContext(), e);
        });
    };
    if (this.viewerLogin !== '') {
      load(this.viewerLogin);
      return;
    }
    WorkService.fetchViewerLogin(this.token)
      .then((login: string) => {
        this.viewerLogin = login;
        load(login);
      })
      .catch((e: Error) => {
        this.orgListLoading = false;
        this.sheetLoadError = friendlyError(this.getUIContext(), e);
      });
  }

  private openRepoSheet(): void {
    this.sheetKind = 'repo';
    this.sheetLoadError = '';
    if (this.repoList.length === 0 && !this.repoListLoading) {
      this.repoListLoading = true;
      WorkService.fetchTopRepositories(this.token, '')
        .then((page: WorkTopReposPage) => {
          this.repoList = page.repos;
          this.repoListLoading = false;
        })
        .catch((e: Error) => {
          this.repoListLoading = false;
          this.sheetLoadError = friendlyError(this.getUIContext(), e);
        });
    }
  }

  private filteredOrgs(): WorkOrgItem[] {
    if (this.orgSearch === '') {
      return this.orgList;
    }
    const needle = this.orgSearch.toLowerCase();
    return this.orgList.filter((o: WorkOrgItem) =>
      o.login.toLowerCase().includes(needle) || o.name.toLowerCase().includes(needle));
  }

  private filteredRepos(): WorkTopRepoItem[] {
    if (this.repoSearch === '') {
      return this.repoList;
    }
    const needle = this.repoSearch.toLowerCase();
    return this.repoList.filter((r: WorkTopRepoItem) =>
      r.name.toLowerCase().includes(needle) || r.ownerLogin.toLowerCase().includes(needle));
  }

  private toggleOrg(login: string): void {
    const idx = this.selectedOrgs.indexOf(login);
    if (idx >= 0) {
      this.selectedOrgs.splice(idx, 1);
    } else {
      this.selectedOrgs.push(login);
    }
    this.emitChange();
  }

  private toggleRepo(nameWithOwner: string): void {
    const idx = this.selectedRepos.indexOf(nameWithOwner);
    if (idx >= 0) {
      this.selectedRepos.splice(idx, 1);
    } else {
      this.selectedRepos.push(nameWithOwner);
    }
    this.emitChange();
  }

  @Builder
  sheetHeader(title: Resource, close: () => void, onSearchToggle: () => void) {
    Row() {
      Stack() {
        OctIcon({ res: $r('app.media.oct_x_16'), iconSize: 16, iconColor: $r('app.color.text_primary') })
      }
      .width(44)
      .height(44)
      .onClick(close)
      Text(title)
        .fontSize($r('app.float.title_font_size'))
        .fontWeight(600)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
      Stack() {
        OctIcon({ res: $r('app.media.oct_search_24'), iconSize: 16, iconColor: $r('app.color.link_blue') })
      }
      .width(44)
      .height(44)
      .onClick(onSearchToggle)
    }
    .padding({ left: 8, right: 8 })
  }

  /** 弹层内联搜索框（点右上放大镜展开） */
  @Builder
  sheetSearch(value: string, onChange: (v: string) => void) {
    TextInput({ placeholder: this.stringOf($r('app.string.search_placeholder')), text: value })
      .height(40)
      .fontSize($r('app.float.body_font_size'))
      .margin({ left: 16, right: 16, bottom: 4 })
      .borderRadius(6)
      .backgroundColor($r('app.color.chip_bg'))
      .onChange(onChange)
  }

  /** 弹层空态（官方「Nothing to see here」） */
  @Builder
  sheetEmpty() {
    Column() {
      Blank()
      Text($r('app.string.work_filter_nothing'))
        .fontSize(20)
        .fontWeight(600)
        .fontColor($r('app.color.text_primary'))
      Blank()
    }
    .layoutWeight(1)
    .width('100%')
  }

  @Builder
  orgSheetRow(org: WorkOrgItem) {
    Row({ space: 12 }) {
      if (org.avatarUrl !== '') {
        Image(org.avatarUrl)
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
        Text(org.name)
          .fontSize($r('app.float.body_font_size'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(org.login)
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      if (this.selectedOrgs.indexOf(org.login) >= 0) {
        OctIcon({ res: $r('app.media.oct_check_16'), iconSize: 20, iconColor: $r('app.color.link_blue') })
      }
    }
    .width('100%')
    .height(64)
    .padding({ left: 16, right: 16 })
    .onClick((): void => this.toggleOrg(org.login))
  }

  @Builder
  repoSheetRow(repo: WorkTopRepoItem) {
    Row({ space: 12 }) {
      if (repo.ownerAvatar !== '') {
        Image(repo.ownerAvatar)
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
        Text(repo.ownerLogin)
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(repo.name)
          .fontSize($r('app.float.body_font_size'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      if (this.selectedRepos.indexOf(`${repo.ownerLogin}/${repo.name}`) >= 0) {
        OctIcon({ res: $r('app.media.oct_check_16'), iconSize: 20, iconColor: $r('app.color.link_blue') })
      }
    }
    .width('100%')
    .height(64)
    .padding({ left: 16, right: 16 })
    .onClick((): void => this.toggleRepo(`${repo.ownerLogin}/${repo.name}`))
  }

  /** 弹层分派（单个 bindSheet 内切换内容，规避同组件多 bindSheet 失效） */
  @Builder
  overlaySheet() {
    if (this.sheetKind === 'org') {
      this.orgSheet()
    } else if (this.sheetKind === 'repo') {
      this.repoSheet()
    } else {
      this.sortSheet()
    }
  }

  @Builder
  orgSheet() {
    Column() {
      this.sheetHeader($r('app.string.issues_filter_org_title'),
        (): void => { this.sheetKind = ''; },
        (): void => { this.orgSearchShow = !this.orgSearchShow; })
      if (this.orgSearchShow) {
        this.sheetSearch(this.orgSearch, (v: string): void => {
          this.orgSearch = v;
        })
      }
      if (this.orgListLoading) {
        StateView({ loading: true })
      } else if (this.sheetLoadError !== '') {
        StateView({ error: this.sheetLoadError, onRetry: (): void => this.openOrgSheet() })
      } else if (this.filteredOrgs().length === 0) {
        this.sheetEmpty()
      } else {
        Scroll() {
          Column() {
            ForEach(this.filteredOrgs(), (org: WorkOrgItem) => {
              this.orgSheetRow(org)
            }, (org: WorkOrgItem) => org.id)
          }
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  repoSheet() {
    Column() {
      this.sheetHeader($r('app.string.issues_filter_repo_title'),
        (): void => { this.sheetKind = ''; },
        (): void => { this.repoSearchShow = !this.repoSearchShow; })
      if (this.repoSearchShow) {
        this.sheetSearch(this.repoSearch, (v: string): void => {
          this.repoSearch = v;
        })
      }
      if (this.repoListLoading) {
        StateView({ loading: true })
      } else if (this.sheetLoadError !== '') {
        StateView({ error: this.sheetLoadError, onRetry: (): void => this.openRepoSheet() })
      } else if (this.filteredRepos().length === 0) {
        this.sheetEmpty()
      } else {
        Scroll() {
          Column() {
            ForEach(this.filteredRepos(), (repo: WorkTopRepoItem) => {
              this.repoSheetRow(repo)
            }, (repo: WorkTopRepoItem) => repo.id)
          }
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
  }

  // ────────────────────────── Sort by 弹层（四组单选） ──────────────────────────

  /** Sort by 单选圆钮（按引用传递，勾选态随状态刷新） */
  @Builder
  radioCircle($$: SortRadioState) {
    Stack() {
      Circle()
        .width(20)
        .height(20)
        .fill(Color.Transparent)
        .stroke($$.selected ? $r('app.color.link_blue') : $r('app.color.text_tertiary'))
        .strokeWidth(2)
      if ($$.selected) {
        Circle()
          .width(10)
          .height(10)
          .fill($r('app.color.link_blue'))
      }
    }
  }

  @Builder
  sortGroup(opts: SortOption[]) {
    Column() {
      ForEach(opts, (opt: SortOption) => {
        Row() {
          Text(opt.label)
            .fontSize($r('app.float.body_font_size'))
            .fontColor($r('app.color.text_primary'))
            .layoutWeight(1)
          this.radioCircle({ selected: this.sortKey === opt.key })
        }
        .width('100%')
        .height(52)
        .padding({ left: 16, right: 16 })
        .onClick((): void => {
          this.sortKey = opt.key;
          this.emitChange();
          this.sheetKind = '';
        })
      }, (opt: SortOption) => opt.key)
    }
    .backgroundColor($r('app.color.card_background'))
    .borderRadius(12)
    .margin({ left: 12, right: 12, bottom: 12 })
  }

  @Builder
  reactionsGroup() {
    Column() {
      Text($r('app.string.issues_sort_most_reactions'))
        .fontSize($r('app.float.caption_font_size'))
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
        .padding({ left: 16, top: 14, bottom: 6 })
      Grid() {
        ForEach(WorkFilterBar.REACTIONS, (it: ReactionOption) => {
          GridItem() {
            Stack() {
              Text(it.emoji)
                .fontSize($r('app.float.title_font_size'))
            }
            .width(64)
            .height(56)
            .borderRadius(6)
            .border({
              width: 1,
              color: this.sortKey === it.key ? $r('app.color.link_blue') : Color.Transparent
            })
            .backgroundColor(this.sortKey === it.key ? $r('app.color.chip_active_bg') : Color.Transparent)
            .onClick((): void => {
              if (it.disabled) {
                return;
              }
              this.sortKey = it.key;
              this.emitChange();
              this.sheetKind = '';
            })
          }
        }, (it: ReactionOption) => it.key)
      }
      .columnsTemplate('1fr 1fr 1fr 1fr')
      .rowsGap(8)
      .columnsGap(8)
      .padding({ left: 12, right: 12, bottom: 20 })
      .width('100%')
    }
    .backgroundColor($r('app.color.card_background'))
    .borderRadius(12)
    .margin({ left: 12, right: 12, bottom: 12 })
  }

  @Builder
  sortSheet() {
    Column() {
      Row() {
        Stack() {
          OctIcon({ res: $r('app.media.oct_x_16'), iconSize: 16, iconColor: $r('app.color.text_primary') })
        }
        .width(44)
        .height(44)
        .onClick((): void => {
          this.sheetKind = '';
        })
        Text($r('app.string.issues_sort_title'))
          .fontSize($r('app.float.title_font_size'))
          .fontWeight(600)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
      }
      .padding({ left: 8, right: 8 })
      Scroll() {
        Column() {
          this.sortGroup([
            { key: 'newest', label: this.stringOf($r('app.string.issues_sort_newest')) },
            { key: 'oldest', label: this.stringOf($r('app.string.issues_sort_oldest')) }
          ])
          this.sortGroup([
            { key: 'most_commented', label: this.stringOf($r('app.string.issues_sort_most_commented')) },
            { key: 'least_commented', label: this.stringOf($r('app.string.issues_sort_least_commented')) }
          ])
          this.sortGroup([
            { key: 'recently_updated', label: this.stringOf($r('app.string.issues_sort_recently_updated')) },
            { key: 'least_recently_updated', label: this.stringOf($r('app.string.issues_sort_least_recently_updated')) }
          ])
          this.reactionsGroup()
        }
        .padding({ top: 8, bottom: 16 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
  }

  build() {
    Column() {
      Scroll() {
        Row() {
          // 漏斗徽标：激活筛选组数
          if (this.activeFilterCount() > 0) {
            Row({ space: 4 }) {
              OctIcon({
                res: $r('app.media.oct_filter_16'),
                iconSize: 14,
                iconColor: $r('app.color.link_blue')
              })
              Stack() {
                Text(`${this.activeFilterCount()}`)
                  .fontSize(12)
                  .fontColor(Color.White)
              }
              .width(18)
              .height(18)
              .borderRadius(9)
              .backgroundColor($r('app.color.link_blue'))
            }
            .height(38)
            .responseRegion({ x: 0, y: -3, width: '100%', height: '116%' })
            .padding({ left: 10, right: 12 })
            .borderRadius(19)
            .backgroundColor($r('app.color.chip_bg'))
            .border({ width: 1, color: $r('app.color.border') })
            .margin({ right: 8 })
            .bindMenu([
              {
                value: $r('app.string.work_filter_create_shortcut'),
                action: (): void => {
                  promptAction.showToast({ message: $r('app.string.home_feature_coming') });
                }
              },
              {
                value: $r('app.string.work_clear_all_filters'),
                action: (): void => this.resetFilters()
              }
            ])
          }

          this.filterChip({ kind: 'state', label: this.stateLabel(), active: this.state !== 'open' })
          this.filterChip({ kind: 'scope', label: this.scopeLabel(), active: this.scope !== 'created' })
          this.filterChip({
            kind: 'visibility',
            label: this.visibilityLabel(),
            active: this.visibilityFilter !== 'all'
          })
          this.filterChip({
            kind: 'org',
            label: this.stringOf($r('app.string.work_filter_organization')),
            active: this.selectedOrgs.length > 0
          })
          this.filterChip({
            kind: 'repo',
            label: this.stringOf($r('app.string.work_filter_repository')),
            active: this.selectedRepos.length > 0
          })
          this.filterChip({ kind: 'sort', label: this.sortLabel(), active: this.sortKey !== 'newest' })
        }
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .margin({ bottom: 12 })
    }
    .width('100%')
    .bindSheet(this.sheetKind !== '', this.overlaySheet(), {
      height: this.sheetKind === 'sort' ? 620 : 560,
      backgroundColor: $r('app.color.bg_page'),
      // 关闭钮与标题行均自绘，避免默认 ✕ 与放大镜重叠
      showClose: false,
      // 交互关闭后复位，否则 isShow 表达式恒 true 弹层失效（review B3）
      onDisappear: (): void => {
        this.sheetKind = '';
      }
    })
  }
}
