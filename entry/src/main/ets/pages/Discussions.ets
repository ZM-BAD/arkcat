/**
 * 工作区 Discussion 列表页（Spec 019）：跨仓库 Discussions（search type: DISCUSSION）。
 * 状态/归属下拉 + Unanswered 快捷标 + 分类胶囊。
 */
import { promptAction } from '@kit.ArkUI';
import { OctIcon } from '../components/OctIcon';
import { PageShadowBar } from '../components/PageShadowBar';
import { FilterDropdownChip, FilterDropdownOption } from '../components/FilterDropdownChip';
import { WorkDiscussionItem, WorkDiscussionsPage, RepoLabelItem, RepoCategoryItem, mapRepoLabels, emojiFromShortcode } from '../models/WorkModels';
import { WorkService } from '../services/WorkService';
import { WorkFilterSelectSheet, FilterSheetItem } from '../components/WorkFilterSelectSheet';
import { LabelPill } from '../components/LabelPill';
import { StateView } from '../components/StateView';
import { ListLoadingFooter } from '../components/ListLoadingFooter';
import { WorkEmptyView } from '../components/WorkEmptyView';
import { githubShortTime, timeParts, TimeParts } from '../utils/Format';
import { resText } from '../utils/I18n';

@ComponentV2
export struct DiscussionsView {
  @Param token: string = '';
  @Param pathStack: NavPathStack = new NavPathStack();
  /** 非空 = 单仓库模式（Share Feedback 入口，如 'ZM-BAD/arkcat'）：搜索限定该仓库、隐藏归属筛选 */
  @Param repo: string = '';
  @Local state: string = 'open';
  @Local scope: string = 'created';
  @Local unanswered: boolean = false;
  /** 'new' | 'top_all' | 'top_yesterday' | 'top_week' | 'top_month' | 'top_year' */
  @Local sortKey: string = 'new';
  /** Author/Label 筛选（Spec 065，单仓库模式；label='none' 表示 Unlabeled） */
  @Local authorFilter: string = '';
  @Local labelFilter: string = '';
  /** Category 筛选（2026-09-14，单仓库模式；值=分类名） */
  @Local categoryFilter: string = '';
  /** 仓库 Discussion 分类全集（打开 Category 弹层时拉取一次） */
  @Local repoCategories: RepoCategoryItem[] = [];
  @Local categoriesLoading: boolean = false;
  @Local categoriesError: string = '';
  @Local categorySearchShow: boolean = false;
  @Local categorySearch: string = '';
  /** 弹层（'' | 'author' | 'category' | 'label'）：单 bindSheet 内切换内容 */
  @Local sheetKind: string = '';
  @Local authorSearchShow: boolean = false;
  @Local authorSearch: string = '';
  @Local labelSearchShow: boolean = false;
  @Local labelSearch: string = '';
  /** 仓库 labels 全集（打开 Label 弹层时拉取一次） */
  @Local repoLabels: RepoLabelItem[] = [];
  @Local labelsLoading: boolean = false;
  @Local labelsError: string = '';
  @Local discussions: WorkDiscussionItem[] = [];
  @Local cursor: string = '';
  @Local hasNextPage: boolean = false;
  @Local inSearch: boolean = false;
  @Local searchQuery: string = '';
  @Local loading: boolean = true;
  @Local errorMsg: string = '';
  /** 滚动顶部阴影（滚动中显示、回顶消失） */
  @Local scrollShadow: boolean = false;
  @Local isRefreshing: boolean = false;
  /** 触底加载更多（底部转圈指示） */
  @Local loadingMore: boolean = false;

  aboutToAppear(): void {
    this.refresh();
  }

  /** 竞态序号：快速切换筛选时丢弃过期响应（review E4） */
  private seq: number = 0;

  private refresh(): void {
    const mySeq = ++this.seq;
    this.loading = true;
    this.errorMsg = '';
    WorkService.fetchDiscussions(this.token, this.state, this.scope, this.unanswered, this.sortKey, '', this.repo,
      this.authorFilter, this.labelFilter, this.categoryFilter)
      .then((page: WorkDiscussionsPage) => {
        if (mySeq !== this.seq) {
          return;
        }
        this.discussions = page.discussions;
        this.cursor = page.endCursor;
        this.hasNextPage = page.hasNextPage;
        this.loading = false;
        this.isRefreshing = false;
        this.loadingMore = false;
      })
      .catch((e: Error) => {
        if (mySeq !== this.seq) {
          return;
        }
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
    const mySeq = ++this.seq;
    this.loading = true;
    this.loadingMore = true;
    WorkService.fetchDiscussions(this.token, this.state, this.scope, this.unanswered, this.sortKey, this.cursor,
      this.repo, this.authorFilter, this.labelFilter, this.categoryFilter)
      .then((page: WorkDiscussionsPage) => {
        if (mySeq !== this.seq) {
          return;
        }
        this.discussions = this.discussions.concat(page.discussions);
        this.cursor = page.endCursor;
        this.hasNextPage = page.hasNextPage;
        this.loading = false;
        this.loadingMore = false;
      })
      .catch((e: Error) => {
        if (mySeq !== this.seq) {
          return;
        }
        this.errorMsg = e.message;
        this.loading = false;
        this.loadingMore = false;
      });
  }

  private stringOf(res: Resource): string {
    return resText(this.getUIContext(), res);
  }

  /** 就地搜索：按标题/仓库全名过滤已加载列表（大小写不敏感） */
  private shownDiscussions(): WorkDiscussionItem[] {
    const q = this.searchQuery.trim().toLowerCase();
    if (q === '') {
      return this.discussions;
    }
    return this.discussions.filter((d: WorkDiscussionItem) =>
      d.title.toLowerCase().includes(q) || d.repoFullName.toLowerCase().includes(q));
  }

  private enterSearch(): void {
    this.inSearch = true;
    this.searchQuery = '';
    // 搜索意图 = 新上下文：清遗留错误态（review E5）
    this.errorMsg = '';
    // 下一帧获焦，自动弹起软键盘
    setTimeout((): void => {
      this.getUIContext().getFocusController().requestFocus('work_discussions_search');
    }, 60);
  }

  private exitSearch(): void {
    this.inSearch = false;
    this.searchQuery = '';
  }

  private timeText(parts: TimeParts | null): string {
    return parts !== null ? githubShortTime(parts) : '';
  }

  private activeFilterCount(): number {
    let count = 0;
    if (this.state !== 'open') {
      count++;
    }
    if (this.scope !== 'created') {
      count++;
    }
    // Author/Label 仅单仓库模式显示，计数同步限定
    if (this.repo !== '' && this.authorFilter !== '') {
      count++;
    }
    if (this.repo !== '' && this.labelFilter !== '') {
      count++;
    }
    if (this.repo !== '' && this.categoryFilter !== '') {
      count++;
    }
    if (this.unanswered) {
      count++;
    }
    if (this.sortKey !== 'new') {
      count++;
    }
    return count;
  }

  /** repo → owner/name 拆分（labels 查询用） */
  private repoOwnerName(): string[] {
    const idx = this.repo.indexOf('/');
    if (idx < 0) {
      return [this.repo, ''];
    }
    return [this.repo.substring(0, idx), this.repo.substring(idx + 1)];
  }

  /** Author 弹层选项：已加载讨论的作者去重 + 客户端搜索过滤 */
  private authorSheetItems(): FilterSheetItem[] {
    const q = this.authorSearch.trim().toLowerCase();
    const seen: Set<string> = new Set();
    const items: FilterSheetItem[] = [];
    for (const d of this.discussions) {
      if (d.authorLogin === '' || seen.has(d.authorLogin)) {
        continue;
      }
      seen.add(d.authorLogin);
      if (q !== '' && !d.authorLogin.toLowerCase().includes(q)
        && !d.authorName.toLowerCase().includes(q)) {
        continue;
      }
      items.push({
        key: d.authorLogin,
        avatarUrl: d.authorAvatar,
        mainText: d.authorLogin,
        subText: d.authorName,
        subOnTop: false,
        selected: this.authorFilter === d.authorLogin
      });
    }
    return items;
  }

  /** Label 弹层可见标签：客户端搜索过滤 */
  private shownRepoLabels(): RepoLabelItem[] {
    const q = this.labelSearch.trim().toLowerCase();
    if (q === '') {
      return this.repoLabels;
    }
    return this.repoLabels.filter((l: RepoLabelItem) => l.name.toLowerCase().includes(q));
  }

  private openAuthorSheet(): void {
    this.authorSearchShow = false;
    this.authorSearch = '';
    this.sheetKind = 'author';
  }

  private openCategorySheet(): void {
    this.categorySearchShow = false;
    this.categorySearch = '';
    this.sheetKind = 'category';
  }

  /** 打开 Category 弹层：分类只在首次打开时拉取（失败可重试） */
  private openCategorySheetAndLoad(): void {
    this.openCategorySheet();
    if (this.repoCategories.length > 0 || this.categoriesLoading) {
      return;
    }
    const ownerName = this.repoOwnerName();
    this.categoriesLoading = true;
    this.categoriesError = '';
    WorkService.fetchDiscussionCategories(this.token, ownerName[0], ownerName[1])
      .then((categories: RepoCategoryItem[]) => {
        this.repoCategories = categories;
        this.categoriesLoading = false;
      })
      .catch((e: Error) => {
        this.categoriesError = e.message;
        this.categoriesLoading = false;
      });
  }

  /** Category 弹层可见分类：客户端搜索过滤（名称/描述） */
  private shownCategories(): RepoCategoryItem[] {
    const q = this.categorySearch.trim().toLowerCase();
    if (q === '') {
      return this.repoCategories;
    }
    return this.repoCategories.filter((c: RepoCategoryItem): boolean =>
      c.name.toLowerCase().includes(q) || c.description.toLowerCase().includes(q));
  }

  /** 选分类：同键再点=取消 */
  private pickCategory(name: string): void {
    this.categoryFilter = this.categoryFilter === name ? '' : name;
    this.sheetKind = '';
    this.refresh();
  }

  /** 打开 Label 弹层：labels 只在首次打开时拉取（失败可重试） */
  private openLabelSheet(): void {
    this.labelSearch = '';
    this.sheetKind = 'label';
    if (this.repoLabels.length > 0 || this.labelsLoading) {
      return;
    }
    const ownerName = this.repoOwnerName();
    this.labelsLoading = true;
    this.labelsError = '';
    WorkService.fetchRepoLabels(this.token, ownerName[0], ownerName[1])
      .then((labels: RepoLabelItem[]) => {
        this.repoLabels = labels;
        this.labelsLoading = false;
      })
      .catch((e: Error) => {
        this.labelsError = e.message;
        this.labelsLoading = false;
      });
  }

  /** 选作者：同键再点=取消；选后收起弹层并刷新 */
  private pickAuthor(login: string): void {
    this.authorFilter = this.authorFilter === login ? '' : login;
    this.sheetKind = '';
    this.refresh();
  }

  /** 选标签：'none'=Unlabeled；同键再点=取消 */
  private pickLabel(key: string): void {
    this.labelFilter = this.labelFilter === key ? '' : key;
    this.sheetKind = '';
    this.refresh();
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

  private scopeLabel(): string {
    if (this.scope === 'commented') {
      return this.stringOf($r('app.string.discussions_filter_scope_commented'));
    }
    return this.stringOf($r('app.string.issues_filter_scope_created'));
  }

  private sortLabel(): string {
    for (const opt of this.sortOptions()) {
      if (opt.key === this.sortKey) {
        return opt.label;
      }
    }
    return this.stringOf($r('app.string.work_filter_sort_new'));
  }

  private stateOptions(): FilterDropdownOption[] {
    return [
      { key: 'open', label: this.stringOf($r('app.string.issues_state_open')) },
      { key: 'closed', label: this.stringOf($r('app.string.issues_state_closed')) },
      { key: 'all', label: this.stringOf($r('app.string.work_filter_all')) }
    ];
  }

  private scopeOptions(): FilterDropdownOption[] {
    return [
      { key: 'created', label: this.stringOf($r('app.string.issues_filter_scope_created')) },
      { key: 'commented', label: this.stringOf($r('app.string.discussions_filter_scope_commented')) }
    ];
  }

  private sortOptions(): FilterDropdownOption[] {
    return [
      { key: 'new', label: this.stringOf($r('app.string.work_filter_sort_new')) },
      { key: 'top_all', label: this.stringOf($r('app.string.discussions_sort_top_all')) },
      { key: 'top_yesterday', label: this.stringOf($r('app.string.discussions_sort_top_yesterday')) },
      { key: 'top_week', label: this.stringOf($r('app.string.discussions_sort_top_week')) },
      { key: 'top_month', label: this.stringOf($r('app.string.discussions_sort_top_month')) },
      { key: 'top_year', label: this.stringOf($r('app.string.discussions_sort_top_year')) }
    ];
  }

  private resetFilters(): void {
    this.state = 'open';
    this.scope = 'created';
    this.unanswered = false;
    this.sortKey = 'new';
    // Author/Category/Label 计入徽标，清空时必须一并重置，否则清完徽标仍非 0
    this.authorFilter = '';
    this.categoryFilter = '';
    this.labelFilter = '';
    this.refresh();
  }

  @Builder
  discussionCard(item: WorkDiscussionItem) {
    Column({ space: 6 }) {
      Row() {
        OctIcon({
          res: $r('app.media.oct_comment_discussion_16'),
          iconSize: 18,
          iconColor: item.iconKey === 'open' ? $r('app.color.shortcut_purple_fg') : $r('app.color.text_tertiary')
        })
        Text(`${item.repoFullName} #${item.number}`)
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_secondary'))
          .margin({ left: 12 })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        Text(this.timeText(timeParts(item.createdAt, Date.now())))
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_secondary'))
      }
      .width('100%')

      Text(item.title)
        .fontSize($r('app.float.body_font_size'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')

      if (item.category !== '' || item.replyCount > 0) {
        Row({ space: 8 }) {
          if (item.category !== '') {
            Text(item.category)
              .fontSize($r('app.float.caption_font_size'))
              .fontColor($r('app.color.shortcut_purple_fg'))
              .padding({ left: 8, right: 8, top: 4, bottom: 4 })
              .borderRadius(12)
              .backgroundColor($r('app.color.discussion_badge_bg'))
          }
          if (item.replyCount > 0) {
            Row({ space: 4 }) {
              OctIcon({ res: $r('app.media.oct_comment_16'), iconSize: 12, iconColor: $r('app.color.text_secondary') })
              Text(`${item.replyCount}`)
                .fontSize($r('app.float.caption_font_size'))
                .fontColor($r('app.color.text_secondary'))
            }
            .padding({ left: 8, right: 8, top: 4, bottom: 4 })
            .borderRadius(12)
            .backgroundColor($r('app.color.chip_bg'))
          }
        }
        .width('100%')
      }
    }
    .padding($r('app.float.card_padding'))
    .borderRadius($r('app.float.card_radius'))
    .backgroundColor($r('app.color.card_background'))
    .width('100%')
    .margin({ bottom: 8 })
  }

  /** 弹层分派（单个 bindSheet 内切换内容，规避同组件多 bindSheet 失效） */
  @Builder
  overlaySheet() {
    if (this.sheetKind === 'author') {
      WorkFilterSelectSheet({
        title: $r('app.string.discussions_filter_by_author'),
        searchShow: this.authorSearchShow,
        searchText: this.authorSearch,
        loading: false,
        error: '',
        items: this.authorSheetItems(),
        onPick: (key: string): void => this.pickAuthor(key),
        onClose: (): void => {
          this.sheetKind = '';
        },
        onRetry: (): void => this.openAuthorSheet(),
        onSearchToggle: (): void => {
          this.authorSearchShow = !this.authorSearchShow;
        },
        onSearchChange: (v: string): void => {
          this.authorSearch = v;
        }
      })
    } else if (this.sheetKind === 'category') {
      this.categorySheet()
    } else if (this.sheetKind === 'label') {
      this.labelSheet()
    }
  }

  /** 弹层头（与 WorkFilterSelectSheet 同构）：✕ + 标题 + 放大镜 */
  @Builder
  sheetHeader(titleRes: Resource, searchOn: boolean, onClose: () => void, onToggle: () => void) {
    Row() {
      Stack() {
        OctIcon({ res: $r('app.media.oct_x_16'), iconSize: 16, iconColor: $r('app.color.text_primary') })
      }
      .width(44)
      .height(44)
      .onClick((): void => onClose())
      Text(titleRes)
        .fontSize($r('app.float.title_font_size'))
        .fontWeight(600)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
      Stack() {
        OctIcon({ res: $r('app.media.oct_search_24'), iconSize: 16, iconColor: $r('app.color.link_blue') })
      }
      .width(44)
      .height(44)
      .onClick((): void => onToggle())
    }
    .padding({ left: 8, right: 8 })
  }

  /**
   * 双态弹层头（官方口径，2026-09-14 统一）：常态=[✕ 标题 🔍]；搜索态=标题**原地**变搜索框
   * （defaultFocus 自动聚焦），左侧 ✕ 变 ←（回退=清词退出搜索态），框内右端 ✕ 清词。
   */
  @Builder
  dualStateSheetHeader(titleRes: Resource, searchShow: boolean, searchText: string,
    onClose: () => void, onToggle: () => void, onSearch: (v: string) => void, onClear: () => void) {
    Row() {
      Stack() {
        OctIcon({
          res: searchShow ? $r('app.media.oct_arrow_left_24') : $r('app.media.oct_x_16'),
          iconSize: 18,
          iconColor: $r('app.color.text_primary')
        })
      }
      .width(44)
      .height(44)
      .onClick((): void => {
        if (searchShow) {
          onClear();
          onToggle();
        } else {
          onClose();
        }
      })
      if (searchShow) {
        Stack({ alignContent: Alignment.End }) {
          TextInput({ text: searchText })
            .height(40)
            .fontSize($r('app.float.body_font_size'))
            .width('100%')
            .padding({ right: 34 })
            .borderRadius(6)
            .backgroundColor($r('app.color.chip_bg'))
            .defaultFocus(true)
            .onChange((v: string): void => onSearch(v))
          if (searchText !== '') {
            Stack() {
              OctIcon({ res: $r('app.media.oct_x_16'), iconSize: 14, iconColor: $r('app.color.text_secondary') })
            }
            .width(36)
            .height(36)
            .onClick((): void => onClear())
          }
        }
        .layoutWeight(1)
        .margin({ right: 8 })
      } else {
        Text(titleRes)
          .fontSize($r('app.float.title_font_size'))
          .fontWeight(600)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
        Stack() {
          OctIcon({ res: $r('app.media.oct_search_24'), iconSize: 18, iconColor: $r('app.color.link_blue') })
        }
        .width(44)
        .height(44)
        .onClick((): void => onToggle())
      }
    }
    .padding({ left: 8, right: 8 })
  }

  /** Category 弹层：emoji + 名称 + 描述两行（客户端搜索过滤；选中蓝勾，与官方一致） */
  @Builder
  categorySheet() {
    Column() {
      this.dualStateSheetHeader($r('app.string.discussions_filter_by_category'), this.categorySearchShow,
        this.categorySearch,
        (): void => {
          this.sheetKind = '';
        }, (): void => {
          this.categorySearchShow = !this.categorySearchShow;
        }, (v: string): void => {
          this.categorySearch = v;
        }, (): void => {
          this.categorySearch = '';
        })
      Divider().color($r('app.color.divider')).strokeWidth(1).width('100%')
      if (this.categoriesLoading) {
        StateView({ loading: true })
      } else if (this.categoriesError !== '') {
        StateView({ error: this.categoriesError, onRetry: (): void => this.openCategorySheetAndLoad() })
      } else {
        Scroll() {
          Column() {
            if (this.shownCategories().length > 0) {
              ForEach(this.shownCategories(), (c: RepoCategoryItem) => {
                Row({ space: 12 }) {
                  Text(emojiFromShortcode(c.emoji))
                    .fontSize(22)
                    .width(32)
                  Column({ space: 2 }) {
                    Text(c.name)
                      .fontSize($r('app.float.body_font_size'))
                      .fontWeight(FontWeight.Medium)
                      .fontColor($r('app.color.text_primary'))
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                    Text(c.description)
                      .fontSize($r('app.float.caption_font_size'))
                      .fontColor($r('app.color.text_secondary'))
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)
                  if (this.categoryFilter === c.name) {
                    OctIcon({ res: $r('app.media.oct_check_16'), iconSize: 20, iconColor: $r('app.color.link_blue') })
                  }
                }
                .width('100%')
                .height(64)
                .padding({ left: 16, right: 16 })
                .onClick((): void => this.pickCategory(c.name))
              }, (c: RepoCategoryItem) => `${c.name}_${this.categoryFilter === c.name ? 'on' : 'off'}`)
            } else {
              Text($r('app.string.filter_no_results'))
                .fontSize($r('app.float.caption_font_size'))
                .fontColor($r('app.color.text_secondary'))
                .width('100%')
                .padding({ left: 20, top: 16, bottom: 12 })
            }
          }
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .align(Alignment.Top)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.card_background'))
  }

  /** Label 弹层：Unlabeled 行 + 彩色标签行（客户端搜索过滤；选中蓝勾） */
  @Builder
  labelSheet() {
    Column() {
      this.dualStateSheetHeader($r('app.string.discussions_filter_by_label'), this.labelSearchShow,
        this.labelSearch,
        (): void => {
          this.sheetKind = '';
        }, (): void => {
          this.labelSearchShow = !this.labelSearchShow;
        }, (v: string): void => {
          this.labelSearch = v;
        }, (): void => {
          this.labelSearch = '';
        })
      if (this.labelsLoading) {
        StateView({ loading: true })
      } else if (this.labelsError !== '') {
        StateView({ error: this.labelsError, onRetry: (): void => this.openLabelSheet() })
      } else {
        Scroll() {
          Column() {
            // Unlabeled 行（官方首项：circle-slash 图标）
            Row({ space: 12 }) {
              Circle()
                .width(20)
                .height(20)
                .fill(Color.Transparent)
                .stroke($r('app.color.text_secondary'))
                .strokeWidth(1.5)
              Text($r('app.string.discussions_filter_unlabeled'))
                .fontSize($r('app.float.body_font_size'))
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.text_primary'))
                .layoutWeight(1)
              if (this.labelFilter === 'none') {
                OctIcon({ res: $r('app.media.oct_check_16'), iconSize: 20, iconColor: $r('app.color.link_blue') })
              }
            }
            .width('100%')
            .height(56)
            .padding({ left: 16, right: 16 })
            .onClick((): void => this.pickLabel('none'))

            ForEach(this.shownRepoLabels(), (label: RepoLabelItem) => {
              Row({ space: 12 }) {
                // GitHub 标签胶囊：统一 LabelPill（官方 IssueLabel 口径，DESIGN.md §10.2）
                LabelPill({ labelName: label.name, colorHex: label.color, large: true })
                Blank()
                if (this.labelFilter === label.name) {
                  OctIcon({ res: $r('app.media.oct_check_16'), iconSize: 20, iconColor: $r('app.color.link_blue') })
                }
              }
              .width('100%')
              .height(56)
              .padding({ left: 16, right: 16 })
              .onClick((): void => this.pickLabel(label.name))
            }, (label: RepoLabelItem) => label.name)
          }
          .width('100%')
        }
        .layoutWeight(1)
        .align(Alignment.Top)
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
  }

  build() {
    Column() {
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
        if (this.inSearch) {
          TextInput({
            placeholder: this.stringOf($r('app.string.page_search_discussions')),
            text: this.searchQuery
          })
            .id('work_discussions_search')
            .layoutWeight(1)
            .height(44)
            .fontSize($r('app.float.title_font_size'))
            .fontColor($r('app.color.text_primary'))
            .caretColor($r('app.color.link_blue'))
            .backgroundColor(Color.Transparent)
            .onChange((v: string) => {
              this.searchQuery = v;
            })
        } else {
          Text($r('app.string.nav_discussions_title'))
            .fontSize($r('app.float.title_font_size'))
            .fontWeight(600)
            .fontColor($r('app.color.text_primary'))
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
  OctIcon({
          res: $r('app.media.oct_search_24'),
          iconSize: 20,
          iconColor: $r('app.color.link_blue')
  })
}
.width(44)
.height(44)
        .accessibilityDescription($r('app.string.a11y_search'))
        .focusable(true)
.onClick((): void => this.enterSearch())
          .padding(6)
        }
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
        .accessibilityDescription($r('app.string.a11y_more'))
        .focusable(true)
.bindMenu([
          {
            value: $r('app.string.inbox_menu_refresh'),
            action: (): void => this.refresh()
          },
          {
            value: $r('app.string.discussions_create_title'),
            action: (): void => {
              promptAction.showToast({ message: $r('app.string.home_feature_coming') });
            }
          }
        ])
          .padding(6)
      }
      .width('100%')
      .height(48)
      .padding({ left: 4, right: 4 })

      PageShadowBar({ show: this.scrollShadow })

      Refresh({ refreshing: $$this.isRefreshing }) {
      Scroll() {
        Column() {
          Row() {
            // 漏斗徽标：激活筛选组数（无激活时隐藏；固定在筛选条最左、不随 chip 横向滚动）
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
            FilterDropdownChip({
              label: this.stateLabel(),
              active: this.state !== 'open',
              options: this.stateOptions(),
              selectedKey: this.state,
              onPick: (key: string): void => {
                this.state = key;
                this.refresh();
              }
            })

            // 归属筛选：单仓库模式（Share Feedback）下无意义，隐藏
            if (this.repo === '') {
              FilterDropdownChip({
                label: this.scopeLabel(),
                active: this.scope !== 'created',
                options: this.scopeOptions(),
                selectedKey: this.scope,
                onPick: (key: string): void => {
                  this.scope = key;
                  this.refresh();
                }
              })
            }

            // Author/Label 筛选（Spec 065，单仓库模式）：官方为弹层选择，位于状态与 Unanswered 之间；
            // chip 带 chevron-down 与下拉芯片视觉一致
            if (this.repo !== '') {
              Row({ space: 4 }) {
                Text(this.authorFilter !== ''
                  ? this.authorFilter : this.stringOf($r('app.string.discussions_filter_author')))
                  .fontSize($r('app.float.caption_font_size'))
                  .fontColor(this.authorFilter !== '' ? $r('app.color.link_blue') : $r('app.color.text_primary'))
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                OctIcon({
                  res: $r('app.media.oct_chevron_down_16'),
                  iconSize: 12,
                  iconColor: this.authorFilter !== '' ? $r('app.color.link_blue') : $r('app.color.text_secondary')
                })
              }
              .height(32)
              .responseRegion({ x: 0, y: -6, width: '100%', height: '144%' })
              .padding({ left: 8, right: 8 })
              .borderRadius(16)
              .backgroundColor(this.authorFilter !== '' ? $r('app.color.chip_active_bg') : $r('app.color.chip_bg'))
              .border({
                width: 1,
                color: this.authorFilter !== '' ? $r('app.color.chip_active_border') : $r('app.color.border')
              })
              .margin({ right: 8 })
              .onClick(() => this.openAuthorSheet())

              // Category 筛选（官方位于 Author 与 Label 之间；值=分类名）
              Row({ space: 4 }) {
                Text(this.categoryFilter !== '' ? this.categoryFilter
                  : this.stringOf($r('app.string.discussions_filter_category')))
                  .fontSize($r('app.float.caption_font_size'))
                  .fontColor(this.categoryFilter !== '' ? $r('app.color.link_blue') : $r('app.color.text_primary'))
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                OctIcon({
                  res: $r('app.media.oct_chevron_down_16'),
                  iconSize: 12,
                  iconColor: this.categoryFilter !== '' ? $r('app.color.link_blue') : $r('app.color.text_secondary')
                })
              }
              .height(32)
              .responseRegion({ x: 0, y: -6, width: '100%', height: '144%' })
              .padding({ left: 8, right: 8 })
              .borderRadius(16)
              .backgroundColor(this.categoryFilter !== '' ? $r('app.color.chip_active_bg') : $r('app.color.chip_bg'))
              .border({
                width: 1,
                color: this.categoryFilter !== '' ? $r('app.color.chip_active_border') : $r('app.color.border')
              })
              .margin({ right: 8 })
              .onClick(() => this.openCategorySheetAndLoad())

              Row({ space: 4 }) {
                Text(this.labelFilter === 'none' ? this.stringOf($r('app.string.discussions_filter_unlabeled'))
                  : (this.labelFilter !== '' ? this.labelFilter
                    : this.stringOf($r('app.string.discussions_filter_label'))))
                  .fontSize($r('app.float.caption_font_size'))
                  .fontColor(this.labelFilter !== '' ? $r('app.color.link_blue') : $r('app.color.text_primary'))
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                OctIcon({
                  res: $r('app.media.oct_chevron_down_16'),
                  iconSize: 12,
                  iconColor: this.labelFilter !== '' ? $r('app.color.link_blue') : $r('app.color.text_secondary')
                })
              }
              .height(32)
              .responseRegion({ x: 0, y: -6, width: '100%', height: '144%' })
              .padding({ left: 8, right: 8 })
              .borderRadius(16)
              .backgroundColor(this.labelFilter !== '' ? $r('app.color.chip_active_bg') : $r('app.color.chip_bg'))
              .border({
                width: 1,
                color: this.labelFilter !== '' ? $r('app.color.chip_active_border') : $r('app.color.border')
              })
              .margin({ right: 8 })
              .onClick(() => this.openLabelSheet())
            }

            // Unanswered 开关 chip（官方：只有选中/未选中两种状态，无下拉；样式与下拉芯片一致）
            Text(this.stringOf($r('app.string.work_discussions_unanswered')))
              .fontSize($r('app.float.caption_font_size'))
              .fontColor(this.unanswered ? $r('app.color.link_blue') : $r('app.color.text_primary'))
              .height(32)
              .responseRegion({ x: 0, y: -6, width: '100%', height: '144%' })
              .padding({ left: 8, right: 8 })
              .borderRadius(16)
              .backgroundColor(this.unanswered ? $r('app.color.chip_active_bg') : $r('app.color.chip_bg'))
              .border({ width: 1, color: this.unanswered ? $r('app.color.chip_active_border') : $r('app.color.border') })
              .margin({ right: 8 })
              .onClick(() => {
                this.unanswered = !this.unanswered;
                this.refresh();
              })

            FilterDropdownChip({
              label: this.sortLabel(),
              active: this.sortKey !== 'new',
              options: this.sortOptions(),
              selectedKey: this.sortKey,
              onPick: (key: string): void => {
                this.sortKey = key;
                this.refresh();
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

          if (this.shownDiscussions().length > 0) {
            ForEach(this.shownDiscussions(), (item: WorkDiscussionItem) => {
              this.discussionCard(item)
            }, (item: WorkDiscussionItem) => item.id)
            if (this.hasNextPage) {
              ListLoadingFooter({ show: this.loadingMore })
            }
          } else if (this.loading || this.errorMsg !== '') {
            StateView({
              loading: this.loading,
              error: this.errorMsg,
              onRetry: () => this.refresh()
            })
          } else {
            // 空态带 RESET ALL FILTERS（Spec 019 元素 14，review E8：此前无重置入口）
            WorkEmptyView({
              iconText: '🐱',
              title: $r('app.string.work_discussions_empty'),
              button: (this.state !== 'open' || this.scope !== 'created' || this.unanswered)
                ? $r('app.string.work_reset_all_filters') : null,
              onButton: (): void => this.resetFilters()
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
    .bindSheet(this.sheetKind !== '', this.overlaySheet(), {
      height: 560,
      backgroundColor: $r('app.color.bg_page'),
      showClose: false,
      onDisappear: (): void => {
        this.sheetKind = '';
      }
    })
  }
}
