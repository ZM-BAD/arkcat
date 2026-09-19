/**
 * 仓库内 PR 列表页（Spec 027）：Repo Detail → PRs Tab。
 * 筛选（2026-09-14 对齐仓库内 Issues 口径，Spec 068）：State 下拉（默认 Open）+ Label/Author/Assignee/Milestone
 * 底部面板（双态搜索，与 IssuesList 同款；面板首行官方「空值」选项：Assigned to nobody / No milestone）
 * + Sort 面板（WorkFilterSortSheet 6 键 → 服务端 PullRequestOrder，与 IssueOrder 同构复用 repoIssueOrder）
 * + Reviews 面板占位（交互待详设）。Author/Assignee/Milestone 为客户端过滤 + 空态自动补拉。
 */
import { promptAction } from '@kit.ArkUI';
import { OctIcon } from '../components/OctIcon';
import { PullRequestCard } from '../components/PullRequestCard';
import { PageShadowBar } from '../components/PageShadowBar';
import { FilterDropdownChip, FilterDropdownOption, FilterSheetChip } from '../components/FilterDropdownChip';
import { WorkFilterSortSheet } from '../components/WorkFilterSortSheet';
import { RepoPrItem, RepoPrsPage, filterPrsByAuthor, filterPrsByAssignee, filterPrsByMilestone, repoPrIconKey } from '../models/RepoSubModels';
import { WorkLabel } from '../models/WorkModels';
import { RepoSubService } from '../services/RepoSubService';
import { StateView } from '../components/StateView';
import { ListLoadingFooter } from '../components/ListLoadingFooter';
import { WorkEmptyView } from '../components/WorkEmptyView';
import { githubShortTime, timeParts, TimeParts } from '../utils/Format';
import { resText } from '../utils/I18n';
import { shouldAutoLoadMore, isLimitedRangeEmpty, NONE_FILTER_KEY } from '../utils/FilterLoading';
import { FilterOptionSheet } from '../components/FilterOptionSheet';

@ComponentV2
export struct RepoPrsView {
  @Param owner: string = '';
  @Param name: string = '';
  @Param token: string = '';
  @Param pathStack: NavPathStack = new NavPathStack();
  /** 返回刷新 tick（review B13） */
  @Param returnTick: number = 0;
  /** State 默认=Open（2026-09-14 用户拍板与官方/仓库内 Issues 一致；取非默认值计 dirty） */
  @Local state: string = 'open';
  @Local label: string = '';
  @Local author: string = '';
  @Local assignee: string = '';
  /** Milestone（客户端过滤，值为里程碑标题；哨兵值=No milestone；候选池从已加载 PR 聚合只增不减） */
  @Local milestone: string = '';
  @Local milestonePool: string[] = [];
  /** Sort（与仓库内 Issues 一致：WorkFilterSortSheet 6 键 → 服务端 PullRequestOrder） */
  @Local sortKey: string = 'newest';
  /** 弹层内容：单 bindSheet 内切换（label/author/assignee/milestone 列表 + sort） */
  @Local sheetKind: string = '';
  /** 面板搜索态（与 IssuesList 同款：点 🔍 标题就地变搜索框，回退/重开即复位） */
  @Local sheetSearchShow: boolean = false;
  @Local sheetSearchText: string = '';
  /** 顶栏就地搜索（WorkPrs 同款）：按标题/编号过滤已加载列表 */
  @Local inSearch: boolean = false;
  @Local searchQuery: string = '';
  @Local all: RepoPrItem[] = [];
  @Local shown: RepoPrItem[] = [];
  /** 仓库标签全集（带色：Label 面板 LabelPill 渲染用） */
  @Local labelOptions: WorkLabel[] = [];
  @Local authorOptions: string[] = [];
  @Local assigneeOptions: string[] = [];
  @Local cursor: string = '';
  @Local hasNextPage: boolean = false;
  @Local loading: boolean = true;
  @Local errorMsg: string = '';
  /** 滚动顶部阴影（滚动中显示、回顶消失） */
  @Local scrollShadow: boolean = false;
  @Local isRefreshing: boolean = false;
  /** 触底加载更多（底部转圈指示） */
  @Local loadingMore: boolean = false;
  /** 空态自动补拉已用页数（author/assignee 为客户端过滤，防「假空」） */
  @Local extraPages: number = 0;

  /** 返回刷新（review B13） */
  @Monitor('returnTick')
  onReturnTick(): void {
    this.refresh();
  }

  aboutToAppear(): void {
    this.refresh();
  }

  private refresh(): void {
    this.loading = true;
    this.errorMsg = '';
    RepoSubService.fetchRepoPrs(this.token, this.owner, this.name, this.state, this.label, '', this.sortKey)
      .then((page: RepoPrsPage) => {
        this.all = page.prs;
        this.labelOptions = page.labelOptions;
        this.authorOptions = page.authorOptions;
        this.assigneeOptions = page.assigneeOptions;
        this.absorbMilestonePool(page.prs);
        this.cursor = page.endCursor;
        this.hasNextPage = page.hasNextPage;
        this.applyFilters();
        this.loading = false;
        this.isRefreshing = false;
        this.loadingMore = false;
        this.extraPages = 0;
        this.autoLoadIfEmpty();
      })
      .catch((e: Error) => {
        this.errorMsg = e.message;
        this.loading = false;
        this.isRefreshing = false;
        this.loadingMore = false;
      });
  }

  private loadMore(): void {
    if (!this.hasNextPage || this.loading || this.loadingMore) {
      return;
    }
    this.loading = true;
    this.loadingMore = true;
    RepoSubService.fetchRepoPrs(this.token, this.owner, this.name, this.state, this.label, this.cursor, this.sortKey)
      .then((page: RepoPrsPage) => {
        this.all = this.all.concat(page.prs);
        this.cursor = page.endCursor;
        this.hasNextPage = page.hasNextPage;
        this.absorbMilestonePool(page.prs);
        this.applyFilters();
        this.loading = false;
        this.loadingMore = false;
        this.autoLoadIfEmpty();
      })
      .catch((e: Error) => {
        this.errorMsg = e.message;
        this.loading = false;
        this.loadingMore = false;
      });
  }

  /** 过滤后为空且还有下一页 → 自动补拉（上限 5 页），防「假空」 */
  private autoLoadIfEmpty(): void {
    if (shouldAutoLoadMore(this.shown.length, this.hasNextPage, this.extraPages)) {
      this.extraPages += 1;
      this.loadMore();
    }
  }

  /** 里程碑候选池（只增不减）：从已加载 PR 聚合，避免选中后其他里程碑从下拉消失 */
  private absorbMilestonePool(prs: RepoPrItem[]): void {
    for (const pr of prs) {
      if (pr.milestoneTitle !== '' && this.milestonePool.indexOf(pr.milestoneTitle) < 0) {
        this.milestonePool = this.milestonePool.concat([pr.milestoneTitle]);
      }
    }
  }

  private applyFilters(): void {
    let list: RepoPrItem[] = filterPrsByAuthor(this.all, this.author);
    list = filterPrsByAssignee(list, this.assignee);
    list = filterPrsByMilestone(list, this.milestone);
    // 顶栏就地搜索：标题/编号包含匹配（大小写不敏感）
    const q = this.searchQuery.trim().toLowerCase();
    if (q !== '') {
      list = list.filter((item: RepoPrItem): boolean =>
        item.title.toLowerCase().includes(q) || `#${item.number}`.includes(q) || String(item.number).includes(q));
    }
    this.shown = list;
  }

  /** 筛选变更后统一入口：本地过滤 + 空结果自动补拉（客户端筛选防「假空」） */
  private applyFiltersAndAutoLoad(): void {
    this.applyFilters();
    this.autoLoadIfEmpty();
  }

  private stringOf(res: Resource): string {
    return resText(this.getUIContext(), res);
  }

  private timeText(parts: TimeParts | null): string {
    return parts !== null ? githubShortTime(parts) : '';
  }

  private activeFilterCount(): number {
    // 全库口径（Spec 068）：dirty = 当前值 ≠ 默认值；State 默认 Open，排序计入
    let c = this.state === 'open' ? 0 : 1;
    if (this.label !== '') {
      c++;
    }
    if (this.author !== '') {
      c++;
    }
    if (this.assignee !== '') {
      c++;
    }
    if (this.milestone !== '') {
      c++;
    }
    if (this.sortKey !== 'newest') {
      c++;
    }
    return c;
  }

  private stateLabel(): string {
    if (this.state === 'open') {
      return this.stringOf($r('app.string.issues_state_open'));
    }
    if (this.state === 'closed') {
      return this.stringOf($r('app.string.issues_state_closed'));
    }
    if (this.state === 'merged') {
      return this.stringOf($r('app.string.pr_state_merged'));
    }
    return this.stringOf($r('app.string.work_filter_all'));
  }

  private prIcon(item: RepoPrItem): Resource {
    const key = repoPrIconKey(item.state, item.merged, item.isDraft);
    if (key === 'merged') {
      return $r('app.media.oct_git_merge_16');
    }
    if (key === 'draft') {
      return $r('app.media.oct_git_pull_request_draft_16');
    }
    // 官方字形（DESIGN.md §10.1）：closed 未合并=git-pull-request-closed
    return key === 'open' ? $r('app.media.oct_git_pull_request_16') : $r('app.media.oct_git_pull_request_closed_16');
  }

  private prColor(item: RepoPrItem): ResourceColor {
    const key = repoPrIconKey(item.state, item.merged, item.isDraft);
    if (key === 'merged') {
      return $r('app.color.shortcut_purple_fg');
    }
    // 官方语义（DESIGN.md §10.1）：open=success 绿 / draft=muted 灰 / closed=danger 红
    return key === 'open' ? $r('app.color.success_text')
      : (key === 'draft' ? $r('app.color.text_secondary') : $r('app.color.danger_text'));
  }

  private stateFilterOptions(): FilterDropdownOption[] {
    return [
      { key: 'all', label: this.stringOf($r('app.string.work_filter_all')) },
      { key: 'open', label: this.stringOf($r('app.string.issues_state_open')) },
      { key: 'closed', label: this.stringOf($r('app.string.issues_state_closed')) },
      { key: 'merged', label: this.stringOf($r('app.string.pr_state_merged')) }
    ];
  }

  /** Label 面板选项（仓库标签全集） */
  private labelFilterOptions(): FilterDropdownOption[] {
    return this.labelOptions.map((l: WorkLabel): FilterDropdownOption => ({ key: l.name, label: l.name }));
  }

  /** 标签名 → 色（面板行 LabelPill 渲染用；池外标签回退无色灰） */
  private labelColorByName(name: string): string {
    const hit = this.labelOptions.find((l: WorkLabel): boolean => l.name === name);
    return hit ? hit.color : '';
  }

  /** Author 面板选项 */
  private authorFilterOptions(): FilterDropdownOption[] {
    return this.authorOptions.map((a: string): FilterDropdownOption => ({ key: a, label: a }));
  }

  /** Assignee 面板选项（首行=官方「Assigned to nobody」） */
  private assigneeFilterOptions(): FilterDropdownOption[] {
    const options: FilterDropdownOption[] = [];
    options.push({ key: NONE_FILTER_KEY, label: this.stringOf($r('app.string.repo_issues_assigned_nobody')) });
    for (const a of this.assigneeOptions) {
      options.push({ key: a, label: a });
    }
    return options;
  }

  /** Milestone 面板选项（首行=官方「No milestone」） */
  private milestoneFilterOptions(): FilterDropdownOption[] {
    const options: FilterDropdownOption[] = [];
    options.push({ key: NONE_FILTER_KEY, label: this.stringOf($r('app.string.repo_issues_no_milestone')) });
    for (const m of this.milestonePool) {
      options.push({ key: m, label: m });
    }
    return options;
  }

  /** Milestone chip 文案（哨兵值显示官方「No milestone」） */
  private milestoneLabel(): string {
    if (this.milestone === NONE_FILTER_KEY) {
      return this.stringOf($r('app.string.repo_issues_no_milestone'));
    }
    return this.milestone !== '' ? this.milestone : this.stringOf($r('app.string.repo_issues_milestone'));
  }

  /** Assignee chip 文案（哨兵值显示官方「Assigned to nobody」） */
  private assigneeChipLabel(): string {
    if (this.assignee === NONE_FILTER_KEY) {
      return this.stringOf($r('app.string.repo_issues_assigned_nobody'));
    }
    return this.assignee !== '' ? this.assignee : this.stringOf($r('app.string.repo_prs_assignee'));
  }

  /** Sort chip 文案（与仓库内 Issues 同款：Sort: <排序名>） */
  private sortChipLabel(): string {
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
    return this.stringOf($r('app.string.issues_sort_newest'));
  }

  /** 当前面板标题（与仓库内 Issues 同款官方措辞） */
  private currentListTitle(): Resource {
    if (this.sheetKind === 'label') {
      return $r('app.string.repo_issues_filter_label_title');
    }
    if (this.sheetKind === 'author') {
      return $r('app.string.repo_issues_filter_author_title');
    }
    if (this.sheetKind === 'assignee') {
      return $r('app.string.repo_issues_filter_assignee_title');
    }
    return $r('app.string.repo_issues_filter_milestone_title');
  }

  private currentListOptions(): FilterDropdownOption[] {
    let base: FilterDropdownOption[] = [];
    if (this.sheetKind === 'label') {
      base = this.labelFilterOptions();
    } else if (this.sheetKind === 'author') {
      base = this.authorFilterOptions();
    } else if (this.sheetKind === 'assignee') {
      base = this.assigneeFilterOptions();
    } else {
      base = this.milestoneFilterOptions();
    }
    // 搜索态：对候选池客户端过滤（大小写不敏感包含匹配，空词=全量）
    const q = this.sheetSearchText.trim().toLowerCase();
    if (q === '') {
      return base;
    }
    return base.filter((opt: FilterDropdownOption): boolean => opt.label.toLowerCase().includes(q));
  }

  /** 搜索态占位文案（与仓库内 Issues 一致） */
  private sheetSearchPlaceholder(): Resource {
    if (this.sheetKind === 'label') {
      return $r('app.string.filter_labels');
    }
    if (this.sheetKind === 'author' || this.sheetKind === 'assignee') {
      return $r('app.string.filter_users');
    }
    return $r('app.string.filter_milestones');
  }

  private currentListSelected(): string {
    if (this.sheetKind === 'label') {
      return this.label;
    }
    if (this.sheetKind === 'author') {
      return this.author;
    }
    if (this.sheetKind === 'assignee') {
      return this.assignee;
    }
    return this.milestone;
  }

  /** 打开列表面板：每次拉起复位搜索态，保证干净状态 */
  private openListSheet(kind: string): void {
    this.sheetSearchShow = false;
    this.sheetSearchText = '';
    this.sheetKind = kind;
  }


  /** 单选即生效并关面板；再点选中项=取消（清筛选）。Label 走服务端重查，其余客户端过滤 */
  private applyListPick(key: string): void {
    const kind = this.sheetKind;
    const picked = this.currentListSelected() === key ? '' : key;
    if (kind === 'label') {
      this.label = picked;
      this.sheetKind = '';
      this.refresh();
    } else if (kind === 'author') {
      this.author = picked;
      this.sheetKind = '';
      this.applyFiltersAndAutoLoad();
    } else if (kind === 'assignee') {
      this.assignee = picked;
      this.sheetKind = '';
      this.applyFiltersAndAutoLoad();
    } else if (kind === 'milestone') {
      this.milestone = picked;
      this.sheetKind = '';
      this.applyFiltersAndAutoLoad();
    }
  }

  /** 弹层分派（单 bindSheet）：label/author/assignee/milestone 列表单选（FilterOptionSheet，与 IssuesList 同组件）+ Sort 面板 */
  @Builder
  listSheet() {
    if (this.sheetKind === 'label' || this.sheetKind === 'author'
      || this.sheetKind === 'assignee' || this.sheetKind === 'milestone') {
      FilterOptionSheet({
        title: this.currentListTitle(),
        searchPlaceholder: this.sheetSearchPlaceholder(),
        options: this.currentListOptions(),
        selectedKey: this.currentListSelected(),
        rowKind: this.sheetKind === 'label' ? 'label' : 'plain',
        noneRow: this.sheetKind === 'milestone' || this.sheetKind === 'assignee',
        labelColorOf: (key: string): string => this.labelColorByName(key),
        searchShow: this.sheetSearchShow,
        searchText: this.sheetSearchText,
        onPick: (key: string): void => this.applyListPick(key),
        onClose: (): void => {
          this.sheetKind = '';
        },
        onSearchToggle: (): void => {
          this.sheetSearchShow = !this.sheetSearchShow;
        },
        onSearchChange: (v: string): void => {
          this.sheetSearchText = v;
        }
      })
    } else {
      WorkFilterSortSheet({
        sortKey: this.sortKey,
        onPick: (key: string): void => {
          if (this.sortKey !== key) {
            this.sortKey = key;
            this.refresh();
          }
          this.sheetKind = '';
        },
        onClose: (): void => {
          this.sheetKind = '';
        }
      })
    }
  }

  /** 清空全部筛选（漏斗菜单/空态 RESET 同函数，Spec 068 复位同口径）：State 回默认 Open */
  private clearAllFilters(): void {
    this.state = 'open';
    this.label = '';
    this.author = '';
    this.assignee = '';
    this.milestone = '';
    this.sortKey = 'newest';
    this.refresh();
  }

  private enterSearch(): void {
    this.inSearch = true;
    this.searchQuery = '';
    // 下一帧获焦，自动弹起软键盘（WorkPrs 同款）
    setTimeout((): void => {
      this.getUIContext().getFocusController().requestFocus('repo_prs_search');
    }, 60);
  }

  private exitSearch(): void {
    this.inSearch = false;
    this.searchQuery = '';
    this.applyFilters();
  }

  @Builder
  prRow(item: RepoPrItem) {
    PullRequestCard({
      iconRes: this.prIcon(item),
      iconColor: this.prColor(item),
      title: item.title,
      number: item.number,
      timeText: this.timeText(timeParts(item.createdAt, Date.now())),
      labels: item.labels,
      commentCount: item.commentCount,
      reviewCount: item.reviewCount,
      checksState: item.checksState,
      authorAvatar: item.authorAvatar,
      onOpen: (): void => {
        this.pathStack.pushPathByName('prDetail', `${this.owner}/${this.name}/${item.number}`);
      }
    })
  }

  build() {
    Column() {
      // 顶栏（Spec 067 自绘内联搜索头口径）：两行头 repoName（灰小字·上）+ Pull requests（粗体·下）；
      // 点🔍就地变搜索框（WorkPrs 同款），⊕=circle-plus
      Row() {
        Stack() {
          OctIcon({ res: $r('app.media.oct_arrow_left_24'), iconSize: 20, iconColor: $r('app.color.text_primary') })
        }
        .width(44)
        .height(44)
        .accessibilityDescription($r('app.string.a11y_back'))
        .focusable(true)
        .onClick((): void => {
          this.pathStack.pop();
        })
        if (this.inSearch) {
          TextInput({
            placeholder: this.stringOf($r('app.string.repo_prs_search_pr')),
            text: this.searchQuery
          })
            .id('repo_prs_search')
            .layoutWeight(1)
            .height(44)
            .fontSize($r('app.float.title_font_size'))
            .fontColor($r('app.color.text_primary'))
            .caretColor($r('app.color.link_blue'))
            .backgroundColor(Color.Transparent)
            .onChange((v: string) => {
              this.searchQuery = v;
              this.applyFilters();
            })
        } else {
          Column() {
            Text(this.name)
              .fontSize($r('app.float.caption_font_size'))
              .fontColor($r('app.color.text_secondary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text($r('app.string.home_work_pull_requests'))
              .fontSize($r('app.float.title_font_size'))
              .fontWeight(600)
              .fontColor($r('app.color.text_primary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        if (this.inSearch) {
          Stack() {
            OctIcon({ res: $r('app.media.oct_x_16'), iconSize: 20, iconColor: $r('app.color.text_secondary') })
          }
          .width(44)
          .height(44)
          .padding(6)
          .accessibilityDescription($r('app.string.a11y_close'))
          .focusable(true)
          .onClick((): void => this.exitSearch())
        } else {
          Stack() {
            OctIcon({ res: $r('app.media.oct_search_24'), iconSize: 20, iconColor: $r('app.color.link_blue') })
          }
          .width(44)
          .height(44)
          .padding(6)
          .accessibilityDescription($r('app.string.a11y_search'))
          .focusable(true)
          .onClick((): void => this.enterSearch())
        }
        Stack() {
          OctIcon({ res: $r('app.media.oct_plus_circle_24'), iconSize: 20, iconColor: $r('app.color.link_blue') })
        }
        .width(44)
        .height(44)
        .padding(6)
        .accessibilityDescription($r('app.string.a11y_new'))
        .focusable(true)
        .onClick((): void => {
          // Spec 043：「+」进 Compare changes 页选 base/compare（官方动线，2026-09-19 重做）
          this.pathStack.pushPathByName('prCompare', `${this.owner}|${this.name}`);
        })
      }
      .width('100%')
      .height(48)
      .padding({ left: 4, right: 4 })

      PageShadowBar({ show: this.scrollShadow })

      Refresh({ refreshing: $$this.isRefreshing }) {
      Scroll() {
        Column() {
          Row() {
            // 漏斗徽标：激活筛选组数（工作区同款；无激活时隐藏；固定在筛选条最左、不随 chip 横向滚动）
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
                  action: (): void => this.clearAllFilters()
                }
              ])
            }

            // chips 滚动区：仅这一段随手指横向滑动
            Scroll() {
            Row() {
            FilterDropdownChip({
              label: this.stateLabel(),
              // State 默认=Open：取非默认值才算 dirty 发蓝（与仓库内 Issues 同口径）
              active: this.state !== 'open',
              options: this.stateFilterOptions(),
              selectedKey: this.state,
              onPick: (key: string): void => { this.state = key; this.refresh(); }
            })

            // Label/Author/Assignee/Milestone：底部面板（与仓库内 Issues 同款），单选即关、再点选中项=取消
            FilterSheetChip({
              label: this.label === '' ? this.stringOf($r('app.string.repo_prs_label')) : this.label,
              active: this.label !== '',
              onTap: (): void => { this.openListSheet('label'); }
            })

            FilterSheetChip({
              label: this.author === '' ? this.stringOf($r('app.string.repo_prs_author')) : this.author,
              active: this.author !== '',
              onTap: (): void => { this.openListSheet('author'); }
            })

            FilterSheetChip({
              label: this.assigneeChipLabel(),
              active: this.assignee !== '',
              onTap: (): void => { this.openListSheet('assignee'); }
            })

            FilterSheetChip({
              label: this.milestoneLabel(),
              active: this.milestone !== '',
              onTap: (): void => { this.openListSheet('milestone'); }
            })

            // Reviews：面板占位（交互待详设，先挂官方同款 chip）
            FilterSheetChip({
              label: this.stringOf($r('app.string.search_reviews_badge')),
              active: false,
              onTap: (): void => {
                promptAction.showToast({ message: $r('app.string.home_feature_coming') });
              }
            })

            // Sort：底部面板（与仓库内 Issues 同款 WorkFilterSortSheet）
            FilterSheetChip({
              label: this.sortChipLabel(),
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

          if (this.shown.length > 0) {
            ForEach(this.shown, (item: RepoPrItem) => {
              this.prRow(item)
            }, (item: RepoPrItem) => item.id)
            if (this.hasNextPage) {
              ListLoadingFooter({ show: this.loadingMore })
            }
          } else if (this.loading || this.errorMsg !== '') {
            StateView({ loading: this.loading, error: this.errorMsg, onRetry: () => this.refresh() })
          } else {
            WorkEmptyView({
              iconText: '🐱',
              title: $r('app.string.repo_prs_empty'),
              subtitle: isLimitedRangeEmpty(this.shown.length, this.hasNextPage)
                ? $r('app.string.filter_loaded_range_hint') : null,
              button: this.activeFilterCount() > 0 ? $r('app.string.work_reset_all_filters') : null,
              onButton: (): void => this.clearAllFilters()
            })
          }
        }
        .padding({ left: 16, right: 16, bottom: 16 })
        .width('100%')
      }
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
      .onReachEnd((): void => {
        this.loadMore();
      })
      .onScroll((_x: number, y: number): void => {
        this.scrollShadow = y > 0.001;
      })
      }
      .layoutWeight(1)
      .onRefreshing((): void => {
        this.isRefreshing = true;
        this.refresh();
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_page'))
    .bindSheet(this.sheetKind !== '', this.listSheet(), {
      height: this.sheetKind === 'sort' ? 620 : 560,
      detents: [this.sheetKind === 'sort' ? 620 : 560, SheetSize.LARGE],
      backgroundColor: $r('app.color.bg_page'),
      // 关闭钮自绘，避免默认 ✕ 重叠（全库 bindSheet 口径）
      showClose: false,
      // 交互关闭后复位，否则 isShow 表达式恒 true 弹层失效（review B3）
      onDisappear: (): void => {
        this.sheetKind = '';
      }
    })
  }
}
