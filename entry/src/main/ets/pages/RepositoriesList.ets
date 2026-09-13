/**
 * 仓库列表页（Spec 037）：通用（用户/组织，owner+mode 参数化）。
 * 筛选三件：Type（官方 8 项下拉）+ Language（底部面板，全量语言清单）+ Sort（服务端排序），
 * 三者均为真实筛选；行点击进仓库详情。
 */
import { AppBar, AppBarAction, AppBarActionCfg } from '../components/AppBar';
import { FilterDropdownChip, FilterDropdownOption, FilterSheetChip } from '../components/FilterDropdownChip';
import { LanguageFilterSheet } from '../components/LanguageFilterSheet';
import { OctIcon } from '../components/OctIcon';
import { PageShadowBar } from '../components/PageShadowBar';
import { RepoListPage } from '../models/ProfileModels';
import { ExploreLanguage, PROGRAM_LANGUAGES, sortLanguages } from '../models/ExploreLanguages';
import { RepoSummary } from '../models/GitHubModels';
import { ExploreService } from '../services/ExploreService';
import { ProfileListService, RepoOrder } from '../services/ProfileListService';
import { StateView } from '../components/StateView';
import { ListLoadingFooter } from '../components/ListLoadingFooter';
import { compactCount } from '../utils/Format';
import { resText } from '../utils/I18n';

@ComponentV2
export struct RepositoriesListView {
  @Param owner: string = '';
  @Param mode: string = 'org';
  @Param token: string = '';
  @Param pathStack: NavPathStack = new NavPathStack();
  @Local repos: RepoSummary[] = [];
  @Local cursor: string = '';
  @Local hasNextPage: boolean = false;
  @Local loading: boolean = true;
  @Local errorMsg: string = '';
  /** 滚动顶部阴影（滚动中显示、回顶消失） */
  @Local scrollShadow: boolean = false;
  @Local isRefreshing: boolean = false;
  /** 触底加载更多（底部转圈指示） */
  @Local loadingMore: boolean = false;
  /** Type 筛选（官方 8 项：all/archived/fork/mirror/private/public/source/template） */
  @Local typeFilter: string = 'all';
  @Local langFilter: string = '';
  @Local sortField: string = 'PUSHED_AT';
  /** 语言面板（''=关闭；全量语言经 GET /languages，失败降级内置子集） */
  @Local langSheetOpen: boolean = false;
  @Local allLanguages: ExploreLanguage[] = [];

  aboutToAppear(): void {
    this.loadLanguages();
    this.refresh();
  }

  /** 全量语言：官方接口 GET /languages（833 项），失败回退内置子集 */
  private loadLanguages(): void {
    ExploreService.fetchAllLanguages(this.token)
      .then((list: ExploreLanguage[]) => {
        this.allLanguages = sortLanguages(list);
      })
      .catch(() => {
        this.allLanguages = sortLanguages(PROGRAM_LANGUAGES);
      });
  }

  private refresh(): void {
    if (this.owner === '') {
      return;
    }
    this.loading = true;
    this.errorMsg = '';
    ProfileListService.fetchRepoList(this.token, this.owner, this.mode, '',
      this.orderRef(), this.langFilter, this.typeFilter)
      .then((page: RepoListPage) => {
        this.repos = page.repos;
        this.cursor = page.endCursor;
        this.hasNextPage = page.hasNextPage;
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
    ProfileListService.fetchRepoList(this.token, this.owner, this.mode, this.cursor,
      this.orderRef(), this.langFilter, this.typeFilter)
      .then((page: RepoListPage) => {
        this.repos = this.repos.concat(page.repos);
        this.cursor = page.endCursor;
        this.hasNextPage = page.hasNextPage;
        this.loading = false;
        this.loadingMore = false;
      })
      .catch((e: Error) => {
        this.errorMsg = e.message;
        this.loading = false;
        this.loadingMore = false;
      });
  }

  /** 筛选变更：重置列表后再查 */
  private applyFilters(): void {
    this.repos = [];
    this.cursor = '';
    this.hasNextPage = false;
    this.refresh();
  }

  /** 激活筛选数（Issues/Inbox 同款漏斗徽标口径）：Type + Language（Sort 是排序不计入） */
  private activeFilterCount(): number {
    let c = 0;
    if (this.typeFilter !== 'all') {
      c++;
    }
    if (this.langFilter !== '') {
      c++;
    }
    return c;
  }

  /** 清除全部筛选：Type 回 All、语言清空（Sort 是排序保留） */
  private clearAllFilters(): void {
    this.typeFilter = 'all';
    this.langFilter = '';
    this.applyFilters();
  }

  private orderRef(): RepoOrder {
    return {
      field: this.sortField,
      direction: this.sortField === 'NAME' ? 'ASC' : 'DESC'
    };
  }

  private stringOf(res: Resource): string {
    return resText(this.getUIContext(), res);
  }

  private typeLabel(): string {
    for (const opt of this.typeOptions()) {
      if (opt.key === this.typeFilter) {
        return opt.label;
      }
    }
    return this.stringOf($r('app.string.repos_filter_all'));
  }

  private sortLabel(): string {
    let key: Resource = $r('app.string.repos_sort_stars');
    if (this.sortField === 'PUSHED_AT') {
      key = $r('app.string.repos_sort_recent');
    } else if (this.sortField === 'NAME') {
      key = $r('app.string.repos_sort_name');
    } else if (this.sortField === 'UPDATED_AT') {
      key = $r('app.string.repos_sort_updated');
    }
    return resText(this.getUIContext(), $r('app.string.repos_sort_format'), this.stringOf(key));
  }

  /** 官方 Type 下拉 8 项（顺序与官方一致，Spec 021 同款口径） */
  private typeOptions(): FilterDropdownOption[] {
    return [
      { key: 'all', label: this.stringOf($r('app.string.repos_filter_all')) },
      { key: 'archived', label: this.stringOf($r('app.string.repos_filter_archived')) },
      { key: 'fork', label: this.stringOf($r('app.string.repos_filter_fork')) },
      { key: 'mirror', label: this.stringOf($r('app.string.repos_filter_mirror')) },
      { key: 'private', label: this.stringOf($r('app.string.repos_filter_private')) },
      { key: 'public', label: this.stringOf($r('app.string.repos_filter_public')) },
      { key: 'source', label: this.stringOf($r('app.string.repos_filter_source')) },
      { key: 'template', label: this.stringOf($r('app.string.repos_filter_template')) }
    ];
  }

  /** 语言选择：再点已选语言=取消筛选（Trending 同款），随后重查 */
  private pickLanguage(name: string): void {
    this.langFilter = this.langFilter === name ? '' : name;
    this.langSheetOpen = false;
    this.applyFilters();
  }

  private sortOptions(): FilterDropdownOption[] {
    return [
      { key: 'PUSHED_AT', label: this.stringOf($r('app.string.repos_sort_recent')) },
      { key: 'STARGAZERS', label: this.stringOf($r('app.string.repos_sort_stars')) },
      { key: 'NAME', label: this.stringOf($r('app.string.repos_sort_name')) },
      { key: 'UPDATED_AT', label: this.stringOf($r('app.string.repos_sort_updated')) }
    ];
  }

  /** 列表行：仓库名（私有带 lock）+ 描述 + 星数（实心）+ 语言 */
  @Builder
  repoRow(repo: RepoSummary) {
    Column({ space: 5 }) {
      Row({ space: 6 }) {
        if (repo.isPrivate) {
          OctIcon({ res: $r('app.media.oct_lock_16'), iconSize: 14, iconColor: $r('app.color.text_secondary') })
        }
        Text(repo.name)
          .fontSize($r('app.float.body_font_size'))
          .fontWeight(600)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
      }
      .width('100%')
      if (repo.description !== '') {
        Text(repo.description)
          .fontSize($r('app.float.body_font_size'))
          .fontColor($r('app.color.text_secondary'))
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .lineHeight(22)
          .width('100%')
      }
      Row({ space: 5 }) {
        OctIcon({ res: $r('app.media.oct_star_fill_16'), iconSize: 14, iconColor: $r('app.color.star_gold') })
        Text(compactCount(repo.stargazerCount))
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_secondary'))
        if (repo.primaryLanguage !== '') {
          Circle()
            .width(10)
            .height(10)
            .fill(repo.languageColor !== '' ? repo.languageColor : $r('app.color.repo_language_unknown'))
            .margin({ left: 8 })
          Text(repo.primaryLanguage)
            .fontSize($r('app.float.caption_font_size'))
            .fontColor($r('app.color.text_secondary'))
        }
      }
      .width('100%')
    }
    .width('100%')
    .padding(14)
    .borderRadius(12)
    .backgroundColor($r('app.color.card_background'))
    .margin({ bottom: 4 })
    .onClick(() => {
      this.pathStack.pushPathByName('repoDetail', repo.nameWithOwner);
    })
  }

  build() {
    Column() {
      // 两行头部：灰 owner（上）+ 粗体标题（下）→ subtitleAbove + 搜索
      AppBar({
        showBack: true,
        title: $r('app.string.repos_list_title'),
        subtitle: this.owner,
        subtitleAbove: true,
        onBack: (): void => {
          this.pathStack.pop();
        },
        actions: [
          new AppBarAction($r('app.media.oct_search_24'), (): void => {
            this.pathStack.pushPathByName('search', '');
          }, { iconColor: $r('app.color.text_primary'), a11y: $r('app.string.a11y_search') })
        ]
      })

      PageShadowBar({ show: this.scrollShadow })

      // 筛选条：漏斗徽标（有激活筛选时）+ All / Language / Sort，整条横向可滑动
      Scroll() {
      Row() {
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
              value: $r('app.string.work_clear_all_filters'),
              action: (): void => this.clearAllFilters()
            }
          ])
        }
        FilterDropdownChip({
          label: this.typeLabel(),
          active: false,
          options: this.typeOptions(),
          selectedKey: this.typeFilter,
          onPick: (key: string): void => {
            this.typeFilter = key;
            this.applyFilters();
          }
        })
        // Language chip：sheet 型（点击拉起底部语言面板），随筛选生效变蓝
        FilterSheetChip({
          label: this.langFilter !== '' ? this.langFilter : this.stringOf($r('app.string.repos_filter_language')),
          active: this.langFilter !== '',
          onTap: (): void => {
            this.langSheetOpen = true;
          }
        })
        FilterDropdownChip({
          label: this.sortLabel(),
          active: false,
          options: this.sortOptions(),
          selectedKey: this.sortField,
          onPick: (key: string): void => {
            this.sortField = key;
            this.applyFilters();
          }
        })
      }
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')
      .padding({ left: 16, right: 16, top: 2, bottom: 8 })

      Refresh({ refreshing: $$this.isRefreshing }) {
      Scroll() {
        if (this.repos.length > 0) {
          Column() {
            ForEach(this.repos, (repo: RepoSummary) => {
              this.repoRow(repo)
            }, (repo: RepoSummary) => repo.id !== '' ? repo.id : repo.nameWithOwner)
            if (this.hasNextPage) {
              ListLoadingFooter({ show: this.loadingMore })
            }
          }
          .padding({ left: 16, right: 16 })
          .width('100%')
        } else {
          Column() {
            StateView({
              loading: this.loading,
              error: this.errorMsg,
              onRetry: () => this.refresh()
            })
            if (!this.loading && this.errorMsg === '') {
              Column() {
                Text($r('app.string.repos_list_empty'))
                  .fontSize($r('app.float.body_font_size'))
                  .fontColor($r('app.color.text_secondary'))
              }
              .layoutWeight(1)
              .justifyContent(FlexAlign.Center)
            }
          }
          .width('100%')
          .height('100%')
        }
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
    .bindSheet(this.langSheetOpen!!, this.languageSheet(), {
      height: 540,
      backgroundColor: $r('app.color.card_background'),
      // 关闭钮与标题行均自绘，避免默认 ✕ 与自绘按钮重叠
      showClose: false,
      // 交互式关闭（下滑/遮罩）后复位，否则表达式恒 true 再点 chip 拉不起来
      onDisappear: (): void => {
        this.langSheetOpen = false;
      }
    })
  }

  /** 语言底部面板（Trending 同构：✕ + 标题 + 🔍 内联搜索 + 色点行列表） */
  @Builder
  languageSheet() {
    LanguageFilterSheet({
      title: $r('app.string.filter_language_title'),
      languages: this.allLanguages,
      selected: this.langFilter,
      onPick: (name: string): void => this.pickLanguage(name),
      onClose: (): void => {
        this.langSheetOpen = false;
      }
    })
  }
}
