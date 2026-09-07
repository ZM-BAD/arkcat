/**
 * Explore 二级列表页（Spec 056 官方化收口，参考图 2026-09-07）：
 * Trending = 筛选行（Today/Language/Spoken language 三个下拉）+ 官方风仓库卡列表；
 * Awesome Lists = 无筛选行的同构列表；kind 参数分派共用。
 * 筛选：Today 为下拉菜单（FilterDropdownChip 复用），语言/口语为底部 sheet（单 bindSheet 分派，
 * 规避同组件多 bindSheet 只生效最后一个）；qualifier 均服务端过滤（language:/spoken_language: 实测有效）。
 * 列表卡：TrendingRepoCard（横幅图 + 三态按钮 + STAR/列表 mutation）。
 */
import { promptAction } from '@kit.ArkUI';
import { RepoSummary } from '../models/GitHubModels';
import { WorkUserList } from '../models/WorkModels';
import { ExploreLanguage, PROGRAM_LANGUAGES, SPOKEN_LANGUAGES } from '../models/ExploreLanguages';
import { ExploreService } from '../services/ExploreService';
import { friendlyError } from '../services/GitHttpClient';
import { WorkService } from '../services/WorkService';
import { StateView } from '../components/StateView';
import { OctIcon } from '../components/OctIcon';
import { PageShadowBar } from '../components/PageShadowBar';
import { FilterDropdownChip, FilterDropdownOption } from '../components/FilterDropdownChip';
import { TrendingRepoCard } from '../components/TrendingRepoCard';
import { resText } from '../utils/I18n';

/** 官方 Today/This week/This month → 窗口天数（created:>N 近似，Spec 056 边界） */
interface WindowOption {
  key: string;
  days: number;
  labelRes: Resource;
}

const WINDOW_OPTIONS: WindowOption[] = [
  { key: 'today', days: 1, labelRes: $r('app.string.explore_filter_today') },
  { key: 'week', days: 7, labelRes: $r('app.string.explore_filter_this_week') },
  { key: 'month', days: 31, labelRes: $r('app.string.explore_filter_this_month') }
];

/** 面板行对象（$$ 引用参数随状态刷新，沿 Inbox sheetRow 模式） */
interface SheetRowState {
  label: string;
  color: string;
  selected: boolean;
}

@ComponentV2
export struct ExploreRepoListView {
  @Param kind: string = 'trending';
  @Param token: string = '';
  @Param pathStack: NavPathStack = new NavPathStack();
  @Local repos: RepoSummary[] = [];
  @Local loading: boolean = true;
  @Local errorMsg: string = '';
  /** 滚动顶部阴影（滚动中显示、回顶消失） */
  @Local scrollShadow: boolean = false;
  /** 窗口（today/week/month，默认 week：近 7 天近似的星数质量最接近官方榜单） */
  @Local windowKey: string = 'week';
  /** 语言筛选（''=全部；qualifier language:） */
  @Local language: string = '';
  /** 口语筛选（''=全部；qualifier spoken_language: 实测有效） */
  @Local spoken: string = '';
  /** 面板（'' | 'language' | 'spoken' | 'lists'）：单 bindSheet 分派 */
  @Local sheetKind: string = '';
  @Local sheetSearch: string = '';
  @Local sheetSearchShow: boolean = false;
  /** ADD TO LIST 目标仓库（GraphQL 节点 id） */
  @Local listRepoId: string = '';
  @Local lists: WorkUserList[] = [];
  @Local listsLoaded: boolean = false;
  @Local toggling: boolean = false;

  aboutToAppear(): void {
    this.load();
  }

  private load(): void {
    this.loading = true;
    this.errorMsg = '';
    const days = this.windowDays();
    ExploreService.fetchRepoList(this.token, this.kind, days, this.language, this.spoken)
      .then((repos: RepoSummary[]) => {
        this.repos = repos;
        this.loading = false;
      })
      .catch((e: Error) => {
        this.errorMsg = friendlyError(this.getUIContext(), e);
        this.loading = false;
      });
  }

  private windowDays(): number {
    for (const opt of WINDOW_OPTIONS) {
      if (opt.key === this.windowKey) {
        return opt.days;
      }
    }
    return 7;
  }

  private titleRes(): Resource {
    return this.kind === 'awesome'
      ? $r('app.string.explore_awesome')
      : $r('app.string.explore_trending');
  }

  private windowOptions(): FilterDropdownOption[] {
    const opts: FilterDropdownOption[] = [];
    for (const opt of WINDOW_OPTIONS) {
      opts.push({ key: opt.key, label: this.stringOf(opt.labelRes) });
    }
    return opts;
  }

  private stringOf(res: Resource): string {
    return resText(this.getUIContext(), res);
  }

  // ─── 语言/口语 sheet ────────────────────────────────────────────────

  private openSheet(kind: string): void {
    this.sheetSearch = '';
    this.sheetSearchShow = false;
    this.sheetKind = kind;
  }

  private filteredLanguages(): ExploreLanguage[] {
    const q = this.sheetSearch.trim().toLowerCase();
    if (q === '') {
      return PROGRAM_LANGUAGES;
    }
    return PROGRAM_LANGUAGES.filter((l: ExploreLanguage): boolean => l.name.toLowerCase().includes(q));
  }

  private filteredSpoken(): string[] {
    const q = this.sheetSearch.trim().toLowerCase();
    if (q === '') {
      return SPOKEN_LANGUAGES;
    }
    return SPOKEN_LANGUAGES.filter((n: string): boolean => n.toLowerCase().includes(q));
  }

  private pickLanguage(name: string): void {
    this.language = this.language === name ? '' : name;
    this.sheetKind = '';
    this.load();
  }

  private pickSpoken(name: string): void {
    this.spoken = this.spoken === name ? '' : name;
    this.sheetKind = '';
    this.load();
  }

  // ─── ADD TO LIST（星标列表选择，沿 StarredRepositories 定案） ───────

  private openListSheet(repo: RepoSummary): void {
    this.listRepoId = repo.graphqlId;
    if (this.listRepoId === '') {
      return;
    }
    this.sheetKind = 'lists';
    this.fetchLists();
  }

  private fetchLists(): void {
    if (this.listsLoaded) {
      return;
    }
    WorkService.fetchUserLists(this.token)
      .then((lists: WorkUserList[]) => {
        this.lists = lists;
        this.listsLoaded = true;
      })
      .catch((e: Error) => {
        promptAction.showToast({ message: e.message });
      });
  }

  private repoInList(list: WorkUserList): boolean {
    return list.repoIds.indexOf(this.listRepoId) >= 0;
  }

  /** 切换仓库与某列表的成员关系：乐观更新，失败重取回滚（沿 Starred 定案） */
  private toggleListMember(list: WorkUserList): void {
    if (this.listRepoId === '' || this.toggling) {
      return;
    }
    const targetMember = this.repoInList(list);
    const nextLists = this.lists.map((l: WorkUserList): WorkUserList => {
      if (l.id !== list.id) {
        return l;
      }
      const ids = l.repoIds.slice();
      const idx = ids.indexOf(this.listRepoId);
      if (targetMember) {
        if (idx >= 0) {
          ids.splice(idx, 1);
        }
      } else {
        ids.push(this.listRepoId);
      }
      return {
        id: l.id,
        name: l.name,
        description: l.description,
        itemCount: targetMember ? l.itemCount - 1 : l.itemCount + 1,
        repoIds: ids,
        repoHasNext: l.repoHasNext,
        repoCursor: l.repoCursor
      };
    });
    this.lists = nextLists;
    // mutation 全量 listIds：翻转后按新成员集发送（updateUserListsForItem 语义）
    const sendIds: string[] = [];
    for (const l of nextLists) {
      if (l.repoIds.includes(this.listRepoId)) {
        sendIds.push(l.id);
      }
    }
    this.toggling = true;
    WorkService.updateUserListsForItem(this.token, this.listRepoId, sendIds)
      .then(() => {
        this.toggling = false;
        this.listsLoaded = false;
        this.fetchLists();
      })
      .catch((e: Error) => {
        this.toggling = false;
        promptAction.showToast({ message: e.message });
        this.listsLoaded = false;
        this.fetchLists();
      });
  }

  // ─── sheet 视图 ─────────────────────────────────────────────────────

  @Builder
  sheetHeader(title: Resource, onSearchToggle: () => void) {
    Row() {
      Stack() {
        OctIcon({ res: $r('app.media.oct_x_16'), iconSize: 18, iconColor: $r('app.color.text_primary') })
      }
      .width(44)
      .height(44)
      .onClick(() => {
        this.sheetKind = '';
      })
      Text(title)
        .fontSize($r('app.float.title_font_size'))
        .fontWeight(600)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
      Stack() {
        OctIcon({ res: $r('app.media.oct_search_24'), iconSize: 18, iconColor: $r('app.color.link_blue') })
      }
      .width(44)
      .height(44)
      .onClick(onSearchToggle)
    }
    .padding({ left: 8, right: 8 })
  }

  @Builder
  sheetRow($$: SheetRowState, onClick: () => void) {
    Row() {
      if ($$.color !== '') {
        Circle()
          .width(12)
          .height(12)
          .fill($$.color !== '' ? $$.color : $r('app.color.repo_language_unknown'))
      }
      Text($$.label)
        .fontSize($r('app.float.body_font_size'))
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
      if ($$.selected) {
        OctIcon({ res: $r('app.media.oct_check_16'), iconSize: 16, iconColor: $r('app.color.link_blue') })
          .margin({ left: 8 })
      }
    }
    .width('100%')
    .height(56)
    .padding({ left: 20, right: 16 })
    .onClick(onClick)
  }

  @Builder
  languageSheet() {
    Column() {
      this.sheetHeader($r('app.string.explore_filter_language_title'), (): void => {
        this.sheetSearchShow = !this.sheetSearchShow;
      })
      Divider()
        .color($r('app.color.divider'))
        .strokeWidth(1)
        .width('100%')
      if (this.sheetSearchShow) {
        TextInput({ placeholder: this.stringOf($r('app.string.search_placeholder')), text: this.sheetSearch })
          .height(40)
          .fontSize($r('app.float.body_font_size'))
          .margin({ left: 16, right: 16, bottom: 4 })
          .borderRadius(6)
          .backgroundColor($r('app.color.chip_bg'))
          .onChange((v: string): void => {
            this.sheetSearch = v;
          })
      }
      Scroll() {
        Column() {
          ForEach(this.filteredLanguages(), (lang: ExploreLanguage) => {
            this.sheetRow({
              label: lang.name,
              color: lang.color,
              selected: this.language === lang.name
            }, (): void => this.pickLanguage(lang.name))
          }, (lang: ExploreLanguage) => lang.name)
        }
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.card_background'))
  }

  @Builder
  spokenSheet() {
    Column() {
      this.sheetHeader($r('app.string.explore_filter_spoken_title'), (): void => {
        this.sheetSearchShow = !this.sheetSearchShow;
      })
      Divider()
        .color($r('app.color.divider'))
        .strokeWidth(1)
        .width('100%')
      if (this.sheetSearchShow) {
        TextInput({ placeholder: this.stringOf($r('app.string.search_placeholder')), text: this.sheetSearch })
          .height(40)
          .fontSize($r('app.float.body_font_size'))
          .margin({ left: 16, right: 16, bottom: 4 })
          .borderRadius(6)
          .backgroundColor($r('app.color.chip_bg'))
          .onChange((v: string): void => {
            this.sheetSearch = v;
          })
      }
      Scroll() {
        Column() {
          ForEach(this.filteredSpoken(), (name: string) => {
            this.sheetRow({
              label: name,
              color: '',
              selected: this.spoken === name
            }, (): void => this.pickSpoken(name))
          }, (name: string) => name)
        }
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.card_background'))
  }

  @Builder
  listsSheet() {
    Column() {
      this.sheetHeader($r('app.string.explore_add_to_list'), (): void => { })
      Scroll() {
        Column() {
          if (this.lists.length > 0) {
            ForEach(this.lists, (list: WorkUserList) => {
              Row({ space: 14 }) {
                Text(list.name)
                  .fontSize($r('app.float.body_font_size'))
                  .fontColor($r('app.color.text_primary'))
                  .layoutWeight(1)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                Stack() {
                  Circle()
                    .width(22)
                    .height(22)
                    .fill(this.repoInList(list) ? $r('app.color.link_blue') : Color.Transparent)
                    .stroke(this.repoInList(list) ? $r('app.color.link_blue') : $r('app.color.border'))
                    .strokeWidth(1.5)
                  if (this.repoInList(list)) {
                    OctIcon({ res: $r('app.media.oct_check_16'), iconSize: 12, iconColor: Color.White })
                  }
                }
              }
              .width('100%')
              .height(52)
              .padding({ left: 20, right: 20 })
              .onClick(() => {
                this.toggleListMember(list);
              })
            }, (list: WorkUserList) => `${list.id}_${list.itemCount}_${list.repoIds.join(',')}`)
          } else {
            Text(this.stringOf($r('app.string.explore_lists_empty')))
              .fontSize($r('app.float.caption_font_size'))
              .fontColor($r('app.color.text_secondary'))
              .width('100%')
              .padding({ left: 20, top: 16, bottom: 12 })
          }

          Row({ space: 12 }) {
            OctIcon({ res: $r('app.media.oct_plus_24'), iconSize: 18, iconColor: $r('app.color.link_blue') })
            Text(this.stringOf($r('app.string.starred_create_list')))
              .fontSize($r('app.float.body_font_size'))
              .fontColor($r('app.color.link_blue'))
          }
          .width('100%')
          .height(52)
          .padding({ left: 20, right: 20 })
          .onClick(() => {
            // 先收 sheet 再推页，避免弹窗盖在新页面上（沿 Starred 定案）
            this.sheetKind = '';
            this.pathStack.pushPathByName('createList', '');
          })
        }
        .width('100%')
      }
      .layoutWeight(1)
      .align(Alignment.Top)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.card_background'))
  }

  /** 弹层分派（单个 bindSheet 内切换内容，规避同组件多 bindSheet 失效） */
  @Builder
  overlaySheet() {
    if (this.sheetKind === 'language') {
      this.languageSheet()
    } else if (this.sheetKind === 'spoken') {
      this.spokenSheet()
    } else if (this.sheetKind === 'lists') {
      this.listsSheet()
    } else {
      Column()
        .width('100%')
        .height('100%')
    }
  }

  build() {
    Column() {
      // 自绘头部（二级页约定：NavDestination hideTitleBar，不设 .title() 防双标题）
      Row() {
        Row() {
          OctIcon({ res: $r('app.media.oct_arrow_left_24'), iconSize: 20, iconColor: $r('app.color.text_primary') })
        }
          .width(44)
          .height(44)
          .onClick(() => this.pathStack.pop())

          Text(this.titleRes())
            .fontSize($r('app.float.title_font_size'))
            .fontWeight(600)
            .fontColor($r('app.color.text_primary'))
            .layoutWeight(1)

          Row()
            .width(44)
            .height(44)
        }
        .width('100%')
        .height(48)
        .padding({ left: 12, right: 12 })

        if (this.kind === 'trending') {
          Row({ space: 8 }) {
            FilterDropdownChip({
              label: this.stringOf(this.windowLabelRes()),
              active: false,
              options: this.windowOptions(),
              selectedKey: this.windowKey,
              onPick: (key: string): void => {
                if (this.windowKey !== key) {
                  this.windowKey = key;
                  this.load();
                }
              }
            })
            // Language chip：sheet 型（点击底部面板），随筛选生效变蓝（沿筛选行官方化约定）
            Row() {
              Text(this.language !== '' ? this.language : this.stringOf($r('app.string.explore_filter_language')))
                .fontSize($r('app.float.chip_font_size'))
                .fontColor(this.language !== '' ? $r('app.color.link_blue') : $r('app.color.text_primary'))
              OctIcon({
                res: $r('app.media.oct_chevron_down_16'),
                iconSize: 12,
                iconColor: this.language !== '' ? $r('app.color.link_blue') : $r('app.color.text_secondary')
              })
                .margin({ left: 8 })
            }
            .height(38)
            .padding({ left: 10, right: 12 })
            .borderRadius(19)
            .backgroundColor(this.language !== '' ? $r('app.color.chip_active_bg') : $r('app.color.chip_bg'))
            .border({
              width: 1,
              color: this.language !== '' ? $r('app.color.chip_active_border') : $r('app.color.border')
            })
            .onClick(() => this.openSheet('language'))

            // Spoken language chip：同上（sheet 型）
            Row() {
              Text(this.spoken !== '' ? this.spoken : this.stringOf($r('app.string.explore_filter_spoken')))
                .fontSize($r('app.float.chip_font_size'))
                .fontColor(this.spoken !== '' ? $r('app.color.link_blue') : $r('app.color.text_primary'))
              OctIcon({
                res: $r('app.media.oct_chevron_down_16'),
                iconSize: 12,
                iconColor: this.spoken !== '' ? $r('app.color.link_blue') : $r('app.color.text_secondary')
              })
                .margin({ left: 8 })
            }
            .height(38)
            .padding({ left: 10, right: 12 })
            .borderRadius(19)
            .backgroundColor(this.spoken !== '' ? $r('app.color.chip_active_bg') : $r('app.color.chip_bg'))
            .border({
              width: 1,
              color: this.spoken !== '' ? $r('app.color.chip_active_border') : $r('app.color.border')
            })
            .onClick(() => this.openSheet('spoken'))
          }
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 8 })
        }

        PageShadowBar({ show: this.scrollShadow })

        if (this.loading || this.errorMsg !== '' || this.repos.length === 0) {
          StateView({
            loading: this.loading,
            error: this.errorMsg,
            empty: !this.loading && this.errorMsg === '' && this.repos.length === 0,
            onRetry: (): void => this.load()
          })
        } else {
          Scroll() {
            Column({ space: 10 }) {
              ForEach(this.repos, (repo: RepoSummary) => {
                TrendingRepoCard({
                  repo: repo,
                  token: this.token,
                  onOpen: (): void => {
                    this.pathStack.pushPathByName('repoDetail', repo.nameWithOwner);
                  },
                  onOpenContributors: (): void => {
                    this.pathStack.pushPathByName('contributors', repo.nameWithOwner);
                  },
                  onAddToList: (target: RepoSummary): void => {
                    this.openListSheet(target);
                  }
                })
              }, (repo: RepoSummary) => repo.id !== '' ? repo.id : repo.nameWithOwner)
            }
            .padding({ left: 14, right: 14, top: 8, bottom: 16 })
            .width('100%')
          }
          .layoutWeight(1)
          .scrollBar(BarState.Off)
          .align(Alignment.Top)
          .onScroll((_x: number, y: number): void => {
            this.scrollShadow = y > 0.001;
          })
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.card_background'))
      .bindSheet(this.sheetKind !== '', this.overlaySheet(), {
        height: this.sheetKind === 'lists' ? 300 : 540,
      backgroundColor: $r('app.color.card_background'),
      // 关闭钮与标题行均自绘，避免默认 ✕ 与自绘按钮重叠
      showClose: false,
      // 交互关闭（下滑/遮罩）后复位，否则表达式恒 true 再点 chip 拉不起来（review A1）
      onDisappear: (): void => {
        this.sheetKind = '';
      }
    })
  }

  private windowLabelRes(): Resource {
    for (const opt of WINDOW_OPTIONS) {
      if (opt.key === this.windowKey) {
        return opt.labelRes;
      }
    }
    return $r('app.string.explore_filter_this_week');
  }
}
