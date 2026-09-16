/**
 * 工作区筛选行（Spec 017/018 共用）：漏斗徽标 + State/Scope/Visibility 下拉（通用 FilterDropdownChip）
 * + Organization/Repository 多选 Bottom Sheet（头像+搜索+蓝勾 toggle）+ Sort by 单选 Sheet。
 * 弹层内容组件化于 WorkFilterSelectSheet（org/repo 共用）/WorkFilterSortSheet，本组件保留
 * 状态管理与数据加载（emitChange/openOrgSheet 等）；任何变化经 onQueryChange 上抛，页面据此重查。
 * 空列表显示官方「Nothing to see here」（无组织/仓库或搜索无匹配时）。
 */
import { RequestSequencer } from 'graphql';
import { promptAction } from '@kit.ArkUI';
import { OctIcon } from '../components/OctIcon';
import { WorkOrgItem, WorkTopRepoItem, WorkTopReposPage } from '../models/WorkModels';
import { WorkService } from '../services/WorkService';
import { SearchService, SearchResultItem, SearchResultPage } from '../services/SearchService';
import { friendlyError } from '../services/GitHttpClient';
import { ProfileListService } from '../services/ProfileListService';
import { OrgListPage, OrgSummary } from '../models/ProfileModels';
import { FilterDropdownChip, FilterDropdownOption, FilterSheetChip } from './FilterDropdownChip';
import { WorkFilterSelectSheet, FilterSheetItem } from './WorkFilterSelectSheet';
import { WorkFilterSortSheet, FILTER_REACTIONS } from './WorkFilterSortSheet';
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

/** 是否存在偏离默认的筛选（空态的「RESET ALL FILTERS」与「减少筛选」提示仅在有可重置项时显示） */
export function isWorkFilterDirty(s: WorkFilterState): boolean {
  return s.state !== 'open' || s.scope !== 'created' || s.visibility !== 'all'
    || s.sortKey !== 'newest' || s.orgs.length > 0 || s.repos.length > 0;
}

@ComponentV2
export struct WorkFilterBar {
  @Param token: string = '';
  @Param stateOptions: WorkFilterOption[] = [];
  @Param scopeOptions: WorkFilterOption[] = [];
  /** 外部复位信号（空态 RESET ALL FILTERS）：筛选状态在本组件内，页面只能靠递增本值驱动复位 */
  @Param resetTick: number = 0;
  @Event onQueryChange: (s: WorkFilterState) => void = (s: WorkFilterState): void => { };

  @Local state: string = 'open';
  @Local scope: string = 'created';
  @Local visibilityFilter: string = 'all';
  @Local sortKey: string = 'newest';
  @Local selectedOrgs: string[] = [];
  @Local selectedRepos: string[] = [];
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
  /** 仓库搜索（GitHub 全库 type: REPOSITORY）：输入防抖 400ms；序号防竞态（慢响应不覆盖新输入） */
  @Local repoSearchResults: SearchResultItem[] = [];
  @Local repoSearching: boolean = false;
  private repoSearchTimer: number = -1;
  /** 仓库面板搜索竞态守卫（库原语） */
  private repoSearchSeq: RequestSequencer = new RequestSequencer();

  private stringOf(res: Resource): string {
    return resText(this.getUIContext(), res);
  }

  /** 空态 RESET ALL FILTERS → 与漏斗菜单 Clear all filters 走同一函数 */
  @Monitor('resetTick')
  onResetTick(): void {
    this.resetFilters();
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
      for (const r of FILTER_REACTIONS) {
        if (r.key === this.sortKey) {
          return r.emoji;
        }
      }
      return this.stringOf($r('app.string.issues_sort_most_reactions'));
    }
    return this.stringOf($r('app.string.issues_sort_newest'));
  }

  // ────────────────────────── 下拉选项（State/Scope/Visibility，走通用 FilterDropdownChip） ──────────────────────────

  /** 页面传入的选项 → 通用下拉选项（结构一致，显式转换避免跨模块接口耦合） */
  private toDropdownOptions(opts: WorkFilterOption[]): FilterDropdownOption[] {
    const out: FilterDropdownOption[] = [];
    for (const opt of opts) {
      out.push({ key: opt.key, label: opt.label });
    }
    return out;
  }

  private visibilityOptions(): FilterDropdownOption[] {
    return [
      { key: 'all', label: this.stringOf($r('app.string.issues_filter_visibility_all')) },
      { key: 'private', label: this.stringOf($r('app.string.issues_filter_visibility_private')) },
      { key: 'public', label: this.stringOf($r('app.string.issues_filter_visibility_public')) }
    ];
  }

  /** 仓库 chip 文案：单选=owner/name（配 repo 图标），多选=Repositories（前缀蓝底计数徽标），未选=名称 */
  private repoChipLabel(): string {
    if (this.selectedRepos.length === 1) {
      return this.selectedRepos[0];
    }
    if (this.selectedRepos.length > 1) {
      return this.stringOf($r('app.string.work_filter_repositories'));
    }
    return this.stringOf($r('app.string.work_filter_repository'));
  }

  /** 仓库 chip 计数徽标（仅多选显示，口径与漏斗徽标一致：蓝底白字圆点） */
  private repoChipBadge(): number {
    return this.selectedRepos.length > 1 ? this.selectedRepos.length : 0;
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

  /**
   * 仓库面板搜索输入：GitHub 全库真搜索（SearchService type: REPOSITORY），不再只过滤已加载行。
   * 防抖 400ms；结果按 owner/name 字典序自上而下；请求按序号取新弃旧。
   */
  private onRepoSearchInput(v: string): void {
    this.repoSearch = v;
    if (this.repoSearchTimer >= 0) {
      clearTimeout(this.repoSearchTimer);
      this.repoSearchTimer = -1;
    }
    if (v.trim() === '') {
      this.repoSearchSeq.begin();
      this.repoSearching = false;
      this.repoSearchResults = [];
      return;
    }
    this.repoSearching = true;
    const seq = this.repoSearchSeq.begin();
    this.repoSearchTimer = setTimeout((): void => {
      SearchService.fetchSearchResults(this.token, 'repositories', v.trim())
        .then((page: SearchResultPage) => {
          if (!this.repoSearchSeq.isCurrent(seq)) {
            return;
          }
          const hits = page.items.slice();
          hits.sort((a: SearchResultItem, b: SearchResultItem): number => {
            const av = a.title.toLowerCase();
            const bv = b.title.toLowerCase();
            return av < bv ? -1 : (av > bv ? 1 : 0);
          });
          this.repoSearchResults = hits;
          this.repoSearching = false;
        })
        .catch((_e: Error) => {
          // 搜索失败按空结果呈现（保留输入态，用户可改词重试）
          if (!this.repoSearchSeq.isCurrent(seq)) {
            return;
          }
          this.repoSearchResults = [];
          this.repoSearching = false;
        });
    }, 400);
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

  /** 弹层行映射（org/repo 主副文本顺序不同，统一为 FilterSheetItem） */
  private sheetItems(kind: string): FilterSheetItem[] {
    if (kind === 'org') {
      return this.filteredOrgs().map((o: WorkOrgItem): FilterSheetItem => ({
        key: o.login,
        avatarUrl: o.avatarUrl,
        mainText: o.name,
        subText: o.login,
        subOnTop: false,
        selected: this.selectedOrgs.indexOf(o.login) >= 0
      }));
    }
    // 搜索态：GitHub 全库搜索结果（title=owner/name）；空态/常态：已加载的 viewer 仓库
    if (this.repoSearch.trim() !== '') {
      return this.repoSearchResults.map((s: SearchResultItem): FilterSheetItem => {
        const slash = s.title.indexOf('/');
        const owner = slash > 0 ? s.title.substring(0, slash) : '';
        const name = slash > 0 ? s.title.substring(slash + 1) : s.title;
        return {
          key: s.title,
          avatarUrl: s.avatarUrl,
          mainText: name,
          subText: owner,
          subOnTop: true,
          selected: this.selectedRepos.indexOf(s.title) >= 0
        };
      });
    }
    // 常态：已选仓库置顶回显（含经搜索选出、不在已加载列表里的仓库），自己的仓库排除已选后排下方供选
    const selectedItems: FilterSheetItem[] = this.selectedRepos.map((full: string): FilterSheetItem => {
      const slash = full.indexOf('/');
      const knownRepo = this.repoList.find((r: WorkTopRepoItem) => `${r.ownerLogin}/${r.name}` === full);
      const knownHit = this.repoSearchResults.find((s: SearchResultItem) => s.title === full);
      return {
        key: full,
        avatarUrl: knownRepo ? knownRepo.ownerAvatar : (knownHit ? knownHit.avatarUrl : ''),
        mainText: slash > 0 ? full.substring(slash + 1) : full,
        subText: slash > 0 ? full.substring(0, slash) : '',
        subOnTop: true,
        selected: true
      };
    });
    const ownItems: FilterSheetItem[] = this.repoList
      .filter((r: WorkTopRepoItem) => this.selectedRepos.indexOf(`${r.ownerLogin}/${r.name}`) < 0)
      .map((r: WorkTopRepoItem): FilterSheetItem => ({
        key: `${r.ownerLogin}/${r.name}`,
        avatarUrl: r.ownerAvatar,
        mainText: r.name,
        subText: r.ownerLogin,
        subOnTop: true,
        selected: false
      }));
    return selectedItems.concat(ownItems);
  }

  /** 弹层分派（单个 bindSheet 内切换内容，规避同组件多 bindSheet 失效） */
  @Builder
  overlaySheet() {
    if (this.sheetKind === 'org') {
      WorkFilterSelectSheet({
        title: $r('app.string.issues_filter_org_title'),
        searchShow: this.orgSearchShow,
        searchText: this.orgSearch,
        loading: this.orgListLoading,
        error: this.sheetLoadError,
        items: this.sheetItems('org'),
        onPick: (key: string): void => this.toggleOrg(key),
        onClose: (): void => {
          this.sheetKind = '';
        },
        onRetry: (): void => this.openOrgSheet(),
        onSearchToggle: (): void => {
          this.orgSearchShow = !this.orgSearchShow;
        },
        onSearchChange: (v: string): void => {
          this.orgSearch = v;
        }
      })
    } else if (this.sheetKind === 'repo') {
      WorkFilterSelectSheet({
        title: $r('app.string.issues_filter_repo_title'),
        searchShow: this.repoSearchShow,
        searchText: this.repoSearch,
        searchPlaceholder: $r('app.string.work_search_repositories'),
        loading: this.repoSearch.trim() !== '' ? this.repoSearching : this.repoListLoading,
        error: this.sheetLoadError,
        items: this.sheetItems('repo'),
        onPick: (key: string): void => this.toggleRepo(key),
        onClose: (): void => {
          this.sheetKind = '';
        },
        onRetry: (): void => this.openRepoSheet(),
        onSearchToggle: (): void => {
          this.repoSearchShow = !this.repoSearchShow;
        },
        onSearchChange: (v: string): void => {
          this.onRepoSearchInput(v);
        }
      })
    } else {
      WorkFilterSortSheet({
        sortKey: this.sortKey,
        onPick: (key: string): void => {
          this.sortKey = key;
          this.emitChange();
          this.sheetKind = '';
        },
        onClose: (): void => {
          this.sheetKind = '';
        }
      })
    }
  }

  build() {
    Column() {
      Row() {
        // 漏斗徽标：激活筛选组数（固定在筛选条最左，不随 chip 横向滚动）
        if (this.activeFilterCount() > 0) {
            Row({ space: 4 }) {
              OctIcon({
                res: $r('app.media.oct_filter_16'),
                iconSize: 14,
                iconColor: $r('app.color.link_blue')
              })
              Stack() {
                Text(`${this.activeFilterCount()}`)
                  .fontSize($r('app.float.caption_font_size'))
                  .fontColor(Color.White)
              }
              .width(18)
              .height(18)
              .borderRadius(9)
              .backgroundColor($r('app.color.link_blue'))
            }
            .height(32)
            .responseRegion({ x: 0, y: -6, width: '100%', height: '144%' })
            .padding({ left: 8, right: 8 })
            .borderRadius(16)
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

        // chips 滚动区：仅这一段随手指横向滑动
        Scroll() {
          Row() {
            // State / Scope / Visibility：通用下拉 chip（弹层宽度按最长项自适应，长文案不再截断）
          FilterDropdownChip({
            label: this.stateLabel(),
            active: this.state !== 'open',
            options: this.toDropdownOptions(this.stateOptions),
            selectedKey: this.state,
            onPick: (key: string): void => {
              this.state = key;
              this.emitChange();
            }
          })
          FilterDropdownChip({
            label: this.scopeLabel(),
            active: this.scope !== 'created',
            options: this.toDropdownOptions(this.scopeOptions),
            selectedKey: this.scope,
            onPick: (key: string): void => {
              this.scope = key;
              this.emitChange();
            }
          })
          FilterDropdownChip({
            label: this.visibilityLabel(),
            active: this.visibilityFilter !== 'all',
            options: this.visibilityOptions(),
            selectedKey: this.visibilityFilter,
            onPick: (key: string): void => {
              this.visibilityFilter = key;
              this.emitChange();
            }
          })
          // Organization / Repository / Sort：sheet 型 chip
          FilterSheetChip({
            label: this.stringOf($r('app.string.work_filter_organization')),
            active: this.selectedOrgs.length > 0,
            onTap: (): void => this.openOrgSheet()
          })
          FilterSheetChip({
            label: this.repoChipLabel(),
            active: this.selectedRepos.length > 0,
            withIcon: this.selectedRepos.length === 1,
            iconRes: $r('app.media.oct_repo_16'),
            badgeCount: this.repoChipBadge(),
            onTap: (): void => this.openRepoSheet()
          })
          FilterSheetChip({
            label: this.sortLabel(),
            active: this.sortKey !== 'newest',
            onTap: (): void => {
              this.sheetKind = 'sort';
            }
          })
          }
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .layoutWeight(1)
        .align(Alignment.Start)
      }
      .width('100%')
      .margin({ bottom: 12 })
    }
    .width('100%')
    .bindSheet(this.sheetKind !== '', this.overlaySheet(), {
      height: this.sheetKind === 'sort' ? 620 : 560,
      detents: [this.sheetKind === 'sort' ? 620 : 560, SheetSize.LARGE],
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
