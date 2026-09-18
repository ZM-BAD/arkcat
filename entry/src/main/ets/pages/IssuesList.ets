/**
 * 仓库内 Issue 列表页（Spec 007/026 修订 + Spec 063 顶栏改版）：官方布局对齐——
 * 顶栏两行标题（灰小字 owner/name + 粗体 Issues）+ 蓝色搜索（顶栏内联过滤，框内灰 ✕ 清除，返回键退出搜索）
 * + circle-plus 新建；六筛选（State=下拉；Label/Author/Assignee/Milestone/Sort=底部面板）+ 行样式（状态圈/标题/#N/时间/💬/🔁）。
 * Author/Assignee 走服务端 filterBy；Milestone 客户端过滤（候选从已加载 issue 聚合，池子只增不减）；
 * Sort 与工作区一致（WorkFilterSortSheet，6 键映射服务端 orderBy，reactions 本连接不支持不进面板）。
 * 搜索词为客户端过滤，行点击进入 Issue 详情（Spec 030）。
 */
import { promptAction } from '@kit.ArkUI';
import { OctIcon } from '../components/OctIcon';
import { FilterDropdownChip, FilterDropdownOption, FilterSheetChip } from '../components/FilterDropdownChip';
import { WorkFilterSortSheet } from '../components/WorkFilterSortSheet';
import { LabelPill } from '../components/LabelPill';
import { PageShadowBar } from '../components/PageShadowBar';
import { IssueSummary, IssuesPage } from '../models/IssuesModels';
import { WorkLabel } from '../models/WorkModels';
import { IssuesService } from '../services/IssuesService';
import { StateView } from '../components/StateView';
import { WorkEmptyView } from '../components/WorkEmptyView';
import { ListLoadingFooter } from '../components/ListLoadingFooter';
import { githubShortTime, timeParts, TimeParts } from '../utils/Format';
import { resText } from '../utils/I18n';
import { NONE_FILTER_KEY } from '../utils/FilterLoading';
import { FilterOptionSheet } from '../components/FilterOptionSheet';
import { CountChip } from '../components/CountChip';

@ComponentV2
export struct IssuesListView {
  @Param owner: string = '';
  @Param name: string = '';
  @Param token: string = '';
  @Param pathStack: NavPathStack = new NavPathStack();
  /** 返回刷新 tick（review B13） */
  @Param returnTick: number = 0;
  /** State 默认值=Open（2026-09-14 用户拍板，与官方一致；取非默认值计 dirty） */
  @Local state: string = 'open';
  @Local label: string = '';
  @Local author: string = '';
  @Local assignee: string = '';
  /** Milestone（客户端过滤，值为里程碑标题；''=不过滤；候选池从已加载 issue 聚合只增不减） */
  @Local milestone: string = '';
  @Local milestonePool: string[] = [];
  /** Sort（与工作区一致：WorkFilterSortSheet 6 键；reactions 键本连接不支持不进面板） */
  @Local sortKey: string = 'newest';
  /** 弹层内容（'' | 'sort'）：单 bindSheet 内切换 */
  @Local sheetKind: string = '';
  /** 弹层搜索态（与 Home Issues 工作区面板同款交互）：点 🔍 标题就地变搜索框，回退/重开即复位 */
  @Local sheetSearchShow: boolean = false;
  @Local sheetSearchText: string = '';
  @Local all: IssueSummary[] = [];
  @Local shown: IssueSummary[] = [];
  /** 仓库标签全集（带色：Label 筛选面板 LabelPill 用） */
  @Local repoLabels: WorkLabel[] = [];
  @Local cursor: string = '';
  @Local hasNextPage: boolean = false;
  @Local loading: boolean = true;
  @Local errorMsg: string = '';
  /** 滚动顶部阴影（滚动中显示、回顶消失） */
  @Local scrollShadow: boolean = false;
  @Local isRefreshing: boolean = false;
  /** 触底加载更多（底部转圈指示） */
  @Local loadingMore: boolean = false;
  /** 顶栏内联搜索（Spec 063）：开启后标题区换成搜索框，列表按标题/编号本地过滤 */
  @Local searchOn: boolean = false;
  @Local searchQuery: string = '';
  /**
   * Author/Assignee 下拉候选池（只增不减）：二者已服务端筛选，若候选仍从当前结果聚合，
   * 选了一个人之后其他人就会从下拉里消失、无法直接切换 → 用会话内累积的池子维持候选完整度。
   */
  @Local authorPool: string[] = [];
  @Local assigneePool: string[] = [];

  private enterSearch(): void {
    this.searchOn = true;
    this.searchQuery = '';
    this.applyFilters();
    // 下一帧获焦，自动弹起软键盘
    setTimeout((): void => {
      this.getUIContext().getFocusController().requestFocus('issues_search');
    }, 60);
  }

  private exitSearch(): void {
    this.searchOn = false;
    this.searchQuery = '';
    this.applyFilters();
  }

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
    // 「无人分配」无法服务端下推（GraphQL filterBy 无此语义）：服务端不传 assignee，改客户端过滤
    IssuesService.fetchRepoIssues(this.token, this.owner, this.name, this.state, this.label, '',
      this.author, this.assignee === NONE_FILTER_KEY ? '' : this.assignee, this.sortKey)
      .then((page: IssuesPage) => {
        this.all = page.issues;
        this.repoLabels = page.repoLabels;
        this.cursor = page.endCursor;
        this.hasNextPage = page.hasNextPage;
        this.absorbFilterPools(page.issues);
        this.applyFilters();
        this.loading = false;
        this.isRefreshing = false;
        this.loadingMore = false;
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
    IssuesService.fetchRepoIssues(this.token, this.owner, this.name, this.state, this.label, this.cursor,
        this.author, this.assignee === NONE_FILTER_KEY ? '' : this.assignee, this.sortKey)
      .then((page: IssuesPage) => {
        this.all = this.all.concat(page.issues);
        this.cursor = page.endCursor;
        this.hasNextPage = page.hasNextPage;
        this.absorbFilterPools(page.issues);
        this.applyFilters();
        this.loading = false;
        this.loadingMore = false;
      })
      .catch((e: Error) => {
        this.errorMsg = e.message;
        this.loading = false;
        this.loadingMore = false;
      });
  }

  /**
   * 客户端过滤：顶栏搜索词（Spec 063）+ Milestone + 「无人分配」。
   * Milestone/「No milestone」服务端无参数只能本地筛（候选来自已加载集合，选中必有匹配、无「假空」）；
   * Author/Assignee 自 2026-09-13 起走服务端 filterBy（createdBy/assignee），
   * 但「Assigned to nobody」filterBy 推不下去：该态服务端不传 assignee，改按「无 assignees」本地筛。
   */
  private applyFilters(): void {
    const q = this.searchOn ? this.searchQuery.trim().toLowerCase() : '';
    const next: IssueSummary[] = [];
    for (const issue of this.all) {
      if (q !== '' && !this.matchQuery(issue, q)) {
        continue;
      }
      if (this.milestone === NONE_FILTER_KEY) {
        // No milestone：只留没有里程碑的 issue
        if (issue.milestoneTitle !== '') {
          continue;
        }
      } else if (this.milestone !== '' && issue.milestoneTitle !== this.milestone) {
        continue;
      }
      if (this.assignee === NONE_FILTER_KEY && issue.assignees.length > 0) {
        continue;
      }
      next.push(issue);
    }
    this.shown = next;
  }

  /** 搜索词匹配：标题子串，或「#123 / 123」按编号精确匹配 */
  private matchQuery(issue: IssueSummary, q: string): boolean {
    if (issue.title.toLowerCase().includes(q)) {
      return true;
    }
    const num = q.startsWith('#') ? q.substring(1) : q;
    return num !== '' && `${issue.number}` === num;
  }

  /** State 下拉选项（All/Open/Closed） */
  private stateFilterOptions(): FilterDropdownOption[] {
    return [
      { key: 'all', label: this.stringOf($r('app.string.work_filter_all')) },
      { key: 'open', label: this.stringOf($r('app.string.issues_state_open')) },
      { key: 'closed', label: this.stringOf($r('app.string.issues_state_closed')) }
    ];
  }

  /** Label 下拉选项（仓库标签全集） */
  private labelFilterOptions(): FilterDropdownOption[] {
    const opts: FilterDropdownOption[] = [];
    for (const l of this.repoLabels) {
      opts.push({ key: l.name, label: l.name });
    }
    return opts;
  }

  /** 标签名 → 色（面板行 LabelPill 渲染用；池外标签回退无色灰） */
  private labelColorByName(name: string): string {
    const hit = this.repoLabels.find((l: WorkLabel): boolean => l.name === name);
    return hit ? hit.color : '';
  }


  /** 把本页出现的 author/assignee/milestone 并入候选池（会话内只增不减） */
  private absorbFilterPools(issues: IssueSummary[]): void {
    for (const issue of issues) {
      if (issue.authorLogin !== '' && this.authorPool.indexOf(issue.authorLogin) < 0) {
        this.authorPool = this.authorPool.concat([issue.authorLogin]);
      }
      for (const a of issue.assignees) {
        if (this.assigneePool.indexOf(a) < 0) {
          this.assigneePool = this.assigneePool.concat([a]);
        }
      }
      if (issue.milestoneTitle !== '' && this.milestonePool.indexOf(issue.milestoneTitle) < 0) {
        this.milestonePool = this.milestonePool.concat([issue.milestoneTitle]);
      }
    }
  }

  private authorFilterOptions(): FilterDropdownOption[] {
    const options: FilterDropdownOption[] = [];
    for (const login of this.authorPool) {
      options.push({ key: login, label: login });
    }
    return options;
  }

  /** Assignee 下拉选项（首行=官方「Assigned to nobody」；会话内出现过的分配人集合） */
  private assigneeFilterOptions(): FilterDropdownOption[] {
    const options: FilterDropdownOption[] = [];
    options.push({ key: NONE_FILTER_KEY, label: this.stringOf($r('app.string.repo_issues_assigned_nobody')) });
    for (const login of this.assigneePool) {
      options.push({ key: login, label: login });
    }
    return options;
  }

  /** Milestone 下拉选项（首行=官方「No milestone」；会话内出现过的里程碑集合；再点选中项=取消） */
  private milestoneFilterOptions(): FilterDropdownOption[] {
    const options: FilterDropdownOption[] = [];
    options.push({ key: NONE_FILTER_KEY, label: this.stringOf($r('app.string.repo_issues_no_milestone')) });
    for (const m of this.milestonePool) {
      options.push({ key: m, label: m });
    }
    return options;
  }

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

  /** Sort chip 文案（与工作区同款：Sort: <排序名>） */
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

  /** 清空全部筛选（漏斗菜单/空态 RESET 同函数）：含新增的 Milestone 与 Sort */
  private clearAllFilters(): void {
    this.state = 'open';
    this.label = '';
    this.author = '';
    this.assignee = '';
    this.milestone = '';
    this.sortKey = 'newest';
    this.refresh();
  }

  private stringOf(res: Resource): string {
    return resText(this.getUIContext(), res);
  }

  private timeText(parts: TimeParts | null): string {
    return parts !== null ? githubShortTime(parts) : '';
  }

  private stateLabel(): string {
    if (this.state === 'open') {
      return this.stringOf($r('app.string.issues_state_open'));
    }
    if (this.state === 'closed') {
      return this.stringOf($r('app.string.issues_state_closed'));
    }
    return this.stringOf($r('app.string.work_filter_all'));
  }

  private activeFilterCount(): number {
    // State 默认=Open：非 open 才计 1；Milestone/Sort 各计 1（全库口径：dirty=非默认值，排序计入）
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

  private issueIcon(issue: IssueSummary): Resource {
    if (issue.state === 'OPEN') {
      return $r('app.media.oct_issue_opened_16');
    }
    return $r('app.media.oct_issue_closed_16');
  }

  private issueColor(issue: IssueSummary): ResourceColor {
    return issue.state === 'OPEN' ? $r('app.color.success_text') : $r('app.color.shortcut_purple_fg');
  }

  @Builder
  issueCard(issue: IssueSummary) {
    Column({ space: 6 }) {
      Row() {
        OctIcon({ res: this.issueIcon(issue), iconSize: 22, iconColor: this.issueColor(issue) })
        Text(issue.title)
          .fontSize($r('app.float.body_font_size'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .margin({ left: 12 })
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        Text(`#${issue.number}`)
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_secondary'))
          .margin({ left: 8 })
      }
      .width('100%')

      // 标签数量不定：芯片组包横向 Scroll 防溢出卡片，时间锚定右侧不随滚动
      Row({ space: 8 }) {
        Scroll() {
          Row({ space: 8 }) {
            ForEach(issue.labels, (label: WorkLabel) => {
              LabelPill({ labelName: label.name, colorHex: label.color })
            }, (label: WorkLabel) => label.name)
            if (issue.commentCount > 0) {
              CountChip({ icon: $r('app.media.oct_comment_16'), text: `${issue.commentCount}` })
            }
            if (issue.linkedPrCount > 0) {
              CountChip({ icon: $r('app.media.oct_git_pull_request_16'), text: `${issue.linkedPrCount}` })
            }
          }
          .constraintSize({ minWidth: '100%' })
        }
        .scrollBar(BarState.Off)
        .layoutWeight(1)
        Text(this.timeText(timeParts(issue.createdAt, Date.now())))
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_secondary'))
      }
      .width('100%')
    }
    .padding($r('app.float.card_padding'))
    .borderRadius($r('app.float.card_radius'))
    .backgroundColor($r('app.color.card_background'))
    .width('100%')
    .margin({ bottom: 8 })
    .onClick(() => {
      this.pathStack.pushPathByName('issueDetail', `${this.owner}/${this.name}/${issue.number}`);
    })
  }

  /** 当前列表面板的标题（官方措辞：Filter by label / Filter by author / Filter assignee / Filter by milestone） */
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

  /** 搜索态占位文案（与官方一致：Label/Author/Assignee/Milestone 各按官方措辞） */
  private sheetSearchPlaceholder(): Resource {
    if (this.sheetKind === 'label') {
      return $r('app.string.filter_labels');
    }
    if (this.sheetKind === 'author' || this.sheetKind === 'assignee') {
      return $r('app.string.filter_users');
    }
    return $r('app.string.filter_milestones');
  }

  /** 打开列表弹层：每次拉起复位搜索态，保证干净状态 */
  private openListSheet(kind: string): void {
    this.sheetSearchShow = false;
    this.sheetSearchText = '';
    this.sheetKind = kind;
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

  /** 单选即生效并关面板；再点选中项=取消（清筛选）。Milestone 为客户端过滤不重查 */
  private applyListPick(key: string): void {
    const kind = this.sheetKind;
    const picked = this.currentListSelected() === key ? '' : key;
    if (kind === 'label') {
      this.label = picked;
    } else if (kind === 'author') {
      this.author = picked;
    } else if (kind === 'assignee') {
      this.assignee = picked;
    } else if (kind === 'milestone') {
      this.milestone = picked;
    }
    this.sheetKind = '';
    if (kind === 'milestone') {
      this.applyFilters();
    } else {
      this.refresh();
    }
  }

  /** 弹层分派（单 bindSheet）：label/author/assignee/milestone 列表单选（FilterOptionSheet）+ Sort 面板（与工作区同款） */
  @Builder
  sortSheet() {
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

  build() {
    Column() {
      Row() {
        Stack() {
          OctIcon({ res: $r('app.media.oct_arrow_left_24'), iconSize: 20, iconColor: $r('app.color.text_primary') })
        }
.width(44)
.height(44)
        .accessibilityDescription(this.searchOn ? $r('app.string.a11y_close') : $r('app.string.a11y_back'))
        .focusable(true)
        .onClick(() => {
          // 搜索态下返回 = 退出搜索（回标题）；否则退出本页
          if (this.searchOn) {
            this.exitSearch();
            return;
          }
          this.pathStack.pop();
        })
        if (this.searchOn) {
          // 顶栏内联搜索（Spec 063）：标题区换成输入框，占位「Search Issues」
          TextInput({
            placeholder: this.stringOf($r('app.string.page_search_issues')),
            text: this.searchQuery
          })
            .id('issues_search')
            .height(44)
            .fontSize($r('app.float.title_font_size'))
            .fontColor($r('app.color.text_primary'))
            .caretColor($r('app.color.link_blue'))
            .backgroundColor(Color.Transparent)
            .onChange((v: string) => {
              this.searchQuery = v;
              this.applyFilters();
            })
            .layoutWeight(1)
          // 框内灰 ✕（有文字才显示）：只清空关键词、留在搜索态（与 Home 搜索页一致）
          if (this.searchQuery !== '') {
            Stack() {
              OctIcon({ res: $r('app.media.oct_x_16'), iconSize: 20, iconColor: $r('app.color.text_secondary') })
            }
.width(44)
.height(44)
            .accessibilityDescription($r('app.string.a11y_close'))
            .focusable(true)
            .onClick(() => {
              this.searchQuery = '';
              this.applyFilters();
            })
          }
        } else {
          Column({ space: 0 }) {
            Text(`${this.owner}/${this.name}`)
              .fontSize($r('app.float.caption_font_size'))
              .fontColor($r('app.color.text_secondary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text($r('app.string.repo_issues_link'))
              .fontSize($r('app.float.title_font_size'))
              .fontWeight(600)
              .fontColor($r('app.color.text_primary'))
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          // 🔍 仅未搜索态显示：进入搜索后让位给输入框（用户 2026-09-11 定案）
          Stack() {
            OctIcon({ res: $r('app.media.oct_search_24'), iconSize: 20, iconColor: $r('app.color.link_blue') })
          }
.width(44)
.height(44)
          .padding(6)
          .accessibilityDescription($r('app.string.a11y_search'))
          .focusable(true)
          .onClick(() => this.enterSearch())
        }
        Stack() {
          OctIcon({ res: $r('app.media.oct_plus_circle_24'), iconSize: 20, iconColor: $r('app.color.link_blue') })
        }
.width(44)
.height(44)
        .padding(6)
        .accessibilityDescription($r('app.string.a11y_new'))
        .focusable(true)
        .onClick(() => {
          // Spec 043：「+」直接进新建 Issue 表单（仓库上下文已知）
          this.pathStack.pushPathByName('issueForm', `${this.owner}|${this.name}|new|0`);
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
              // State 默认=Open：取非默认值才算 dirty 发蓝
              active: this.state !== 'open',
              options: this.stateFilterOptions(),
              selectedKey: this.state,
              onPick: (key: string): void => { this.state = key; this.refresh(); }
            })

            // Label/Author/Assignee/Milestone：底部面板模式（与 Sort 一致），单选即关、再点选中项=取消
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

            // Sort：底部面板（与工作区同款 WorkFilterSortSheet）
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
            ForEach(this.shown, (issue: IssueSummary) => {
              this.issueCard(issue)
            }, (issue: IssueSummary) => issue.id)
            if (this.hasNextPage) {
              ListLoadingFooter({ show: this.loadingMore })
            }
          } else if (this.loading || this.errorMsg !== '') {
            StateView({ loading: this.loading, error: this.errorMsg, onRetry: () => this.refresh() })
          } else if (this.searchOn && this.searchQuery.trim() !== '') {
            StateView({ empty: true, emptyText: $r('app.string.search_no_results') })
          } else {
            WorkEmptyView({
              iconText: '🐱',
              title: $r('app.string.issues_empty'),
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
      .onScroll((_x: number, y: number): void => { this.scrollShadow = y > 0.001; })
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
    .bindSheet(this.sheetKind !== '', this.sortSheet(), {
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
