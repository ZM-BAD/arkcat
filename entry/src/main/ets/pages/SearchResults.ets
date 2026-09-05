/**
 * 搜索结果单类页（Spec 046 结果页批 / 官方 6 图版式）：
 * - 头部：← + 搜索框（回车重搜）+ ✕ 返回 + ⋮ 刷新菜单
 * - repositories/issues/prs/people/orgs → GraphQL search（分页 Show more）
 * - code → REST /search/code（文件分组卡 + Show more 文件分页）
 * - 行版式与聚合页共用：SearchRows.ets / CodeSearchCard.ets
 */
import { OctIcon } from '../components/OctIcon';
import { PageShadowBar } from '../components/PageShadowBar';
import { StateView } from '../components/StateView';
import { CodeSearchCard } from '../components/CodeSearchCard';
import { RepoSearchRow, IssuePrSearchRow, PersonSearchRow, OrgSearchRow } from '../components/SearchRows';
import { SearchService, SearchResultItem, SearchResultPage, SearchEntryKind, SearchHistoryStore } from '../services/SearchService';
import { CodeFileResult, CodeSearchPage } from '../services/CodeSearchService';
import { resText } from '../utils/I18n';

/** 代码分组（按 repo 聚合；组头 = 头像 + repo 名） */
interface CodeGroup {
  repoFullName: string;
  avatarUrl: string;
  files: CodeFileResult[];
}

@ComponentV2
export struct SearchResultsView {
  @Param token: string = '';
  @Param pathStack: NavPathStack = new NavPathStack();
  @Param kind: string = '';
  @Param keyword: string = '';
  @Local query: string = '';
  @Local items: SearchResultItem[] = [];
  @Local codeFiles: CodeFileResult[] = [];
  @Local codeGroups: CodeGroup[] = [];
  @Local loading: boolean = false;
  @Local errorMsg: string = '';
  @Local hasNext: boolean = false;
  @Local cursor: string = '';
  @Local codePage: number = 1;
  @Local loaded: boolean = false;
  /** 滚动顶部阴影（滚动中显示、回顶消失） */
  @Local scrollShadow: boolean = false;

  aboutToAppear(): void {
    this.query = this.keyword;
    this.loadFirst();
  }

  /** 竞态序号：改词/快速翻页丢弃过期响应（review E4） */
  private seq: number = 0;

  private loadFirst(): void {
    // 空词回车守卫：直接打接口只会得到裸错误（review E15）
    if (this.query.trim() === '') {
      this.pathStack.pop();
      return;
    }
    const mySeq = ++this.seq;
    this.loading = true;
    this.errorMsg = '';
    this.items = [];
    this.codeFiles = [];
    this.codeGroups = [];
    this.hasNext = false;
    this.cursor = '';
    this.codePage = 1;
    this.loaded = false;
    if (this.kind === 'code') {
      SearchService.fetchCodeResults(this.token, this.query, 1)
        .then((page: CodeSearchPage) => {
          if (mySeq !== this.seq) {
            return;
          }
          this.codeFiles = page.files;
          this.codeGroups = this.groupCodes(page.files);
          this.hasNext = page.hasMore;
          this.loading = false;
          this.loaded = true;
          // 记入 Recent searches（review E17）
          SearchHistoryStore.remember(this.getUIContext().getHostContext(), this.query);
        })
        .catch((e: Error) => {
          if (mySeq !== this.seq) {
            return;
          }
          this.errorMsg = e.message;
          this.loading = false;
          this.loaded = true;
        });
      return;
    }
    SearchService.fetchSearchResults(this.token, this.kind as SearchEntryKind, this.query)
      .then((page: SearchResultPage) => {
        if (mySeq !== this.seq) {
          return;
        }
        this.items = page.items;
        this.hasNext = page.hasNextPage;
        this.cursor = page.endCursor;
        this.loading = false;
        this.loaded = true;
        // 记入 Recent searches（review E17）
        SearchHistoryStore.remember(this.getUIContext().getHostContext(), this.query);
      })
      .catch((e: Error) => {
        if (mySeq !== this.seq) {
          return;
        }
        this.errorMsg = e.message;
        this.loading = false;
        this.loaded = true;
      });
  }

  private loadMore(): void {
    // loading 守卫防 Show more 双击并发翻页（review E4）
    if (this.loading) {
      return;
    }
    const mySeq = ++this.seq;
    this.loading = true;
    if (this.kind === 'code') {
      SearchService.fetchCodeResults(this.token, this.query, this.codePage + 1)
        .then((page: CodeSearchPage) => {
          if (mySeq !== this.seq) {
            return;
          }
          this.codePage += 1;
          const merged = this.codeFiles.concat(page.files);
          this.codeFiles = merged;
          this.codeGroups = this.groupCodes(merged);
          this.hasNext = page.hasMore;
          this.loading = false;
        })
        .catch((e: Error) => {
          if (mySeq !== this.seq) {
            return;
          }
          // 翻页失败不打翻整页：仅当尚无任何结果才进错误态（review E3）
          if (this.items.length === 0 && this.codeFiles.length === 0) {
            this.errorMsg = e.message;
          }
          this.loading = false;
        });
      return;
    }
    if (this.cursor === '') {
      return;
    }
    SearchService.fetchSearchResults(this.token, this.kind as SearchEntryKind, this.query, this.cursor)
      .then((page: SearchResultPage) => {
        if (mySeq !== this.seq) {
          return;
        }
        this.items = this.items.concat(page.items);
        this.hasNext = page.hasNextPage;
        this.cursor = page.endCursor;
        this.loading = false;
      })
      .catch((e: Error) => {
        if (mySeq !== this.seq) {
          return;
        }
        // 翻页失败不打翻整页（review E3）
        if (this.items.length === 0 && this.codeFiles.length === 0) {
          this.errorMsg = e.message;
        }
        this.loading = false;
      });
  }

  private groupCodes(files: CodeFileResult[]): CodeGroup[] {
    const groups: CodeGroup[] = [];
    for (const f of files) {
      let g = groups.find((x: CodeGroup) => x.repoFullName === f.repoFullName);
      if (g === undefined) {
        g = { repoFullName: f.repoFullName, avatarUrl: f.repoAvatarUrl, files: [] };
        groups.push(g);
      }
      g.files.push(f);
    }
    return groups;
  }

  private openRepo(item: SearchResultItem): void {
    this.pathStack.pushPathByName('repoDetail', item.title);
  }

  private openUser(item: SearchResultItem): void {
    this.pathStack.pushPathByName('userProfile', item.title);
  }

  private openOrg(item: SearchResultItem): void {
    this.pathStack.pushPathByName('orgProfile', item.title);
  }

  private openIssue(item: SearchResultItem): void {
    if (item.repoFullName === '') {
      return;
    }
    this.pathStack.pushPathByName('issueDetail', `${item.repoFullName}/${item.number}`);
  }

  private openPr(item: SearchResultItem): void {
    if (item.repoFullName === '') {
      return;
    }
    this.pathStack.pushPathByName('prDetail', `${item.repoFullName}/${item.number}`);
  }

  private stringOf(res: Resource, ...args: Array<string | number>): string {
    return resText(this.getUIContext(), res, ...args);
  }

  /** 行内分隔线（repositories/issues/prs；people/orgs 无分隔线） */
  @Builder
  rowDivider() {
    Divider().color($r('app.color.divider')).strokeWidth(1).margin({ left: 16 })
  }

  /** 代码分组：组头 + 文件名 + 卡 */
  @Builder
  codeGroupBlock() {
    ForEach(this.codeGroups, (g: CodeGroup) => {
      Row({ space: 8 }) {
        Image(g.avatarUrl)
          .width(28)
          .height(28)
          .borderRadius(12)
          .backgroundColor($r('app.color.text_tertiary'))
        Text(g.repoFullName)
          .fontSize(16)
          .fontWeight(600)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })
      .onClick(() => this.pathStack.pushPathByName('repoDetail', g.repoFullName))

      ForEach(g.files, (f: CodeFileResult) => {
        Column() {
          Text(f.name)
            .fontSize(16)
            .fontWeight(600)
            .fontColor($r('app.color.text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
            .padding({ left: 16, right: 16, top: 4, bottom: 8 })
          CodeSearchCard({ file: f })
            .padding({ left: 16, right: 16 })
            .margin({ bottom: 8 })
        }
        .width('100%')
      }, (f: CodeFileResult) => `${f.repoFullName}|${f.path}`)
    }, (g: CodeGroup) => `${g.repoFullName}-${g.files.length}`)
  }

  /** Show more 分页尾行 */
  @Builder
  moreRow() {
    Text($r('app.string.search_show_more'))
      .fontSize($r('app.float.body_font_size'))
      .fontWeight(FontWeight.Medium)
      .fontColor($r('app.color.link_blue'))
      .padding({ top: 16, bottom: 20 })
      .width('100%')
      .textAlign(TextAlign.Center)
      .onClick(() => this.loadMore())
  }

  build() {
    Column() {
      // 头部：← / 搜索框 / ✕ / ⋮
      Row({ space: 8 }) {
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

        TextInput({
          placeholder: this.stringOf($r('app.string.search_placeholder')),
          text: this.query
        })
          .layoutWeight(1)
          .height(44)
          .fontSize($r('app.float.title_font_size'))
          .fontColor($r('app.color.text_primary'))
          .caretColor($r('app.color.link_blue'))
          .backgroundColor(Color.Transparent)
          .onChange((v: string) => {
            this.query = v;
          })
          .onSubmit(() => this.loadFirst())

        if (this.query.trim() !== '') {
          Stack() {
            OctIcon({ res: $r('app.media.oct_x_16'), iconSize: 18, iconColor: $r('app.color.text_secondary') })
          }
          .width(44)
          .height(44)
          .accessibilityDescription($r('app.string.a11y_close'))
          .focusable(true)
          .onClick((): void => {
            this.pathStack.pop();
          })
        }
        Stack() {
          OctIcon({ res: $r('app.media.oct_kebab_horizontal_16'), iconSize: 18, iconColor: $r('app.color.link_blue') })
            .rotate({ angle: 90 })
        }
        .width(44)
        .height(44)
        .accessibilityDescription($r('app.string.a11y_more'))
        .focusable(true)
        .bindMenu([
          {
            value: $r('app.string.search_menu_refresh'),
            action: (): void => this.loadFirst()
          }
        ])
      }
      .width('100%')
      .height(48)
      .padding({ left: 0, right: 0 })

      Divider().strokeWidth(1).color($r('app.color.divider'))

      PageShadowBar({ show: this.scrollShadow })

      Scroll() {
        Column() {
          if (!this.loaded) {
            StateView({ loading: this.loading, error: this.errorMsg, empty: false })
              .width('100%')
              .padding({ top: 60 })
          } else if (this.errorMsg !== '') {
            StateView({ loading: false, error: this.errorMsg, empty: false, onRetry: (): void => this.loadFirst() })
              .width('100%')
              .padding({ top: 60 })
          } else if (this.items.length === 0 && this.codeFiles.length === 0) {
            StateView({ loading: false, error: '', empty: true, emptyText: $r('app.string.search_no_results') })
              .width('100%')
              .padding({ top: 60 })
          } else {
            if (this.kind === 'code') {
              this.codeGroupBlock()
            } else if (this.kind === 'repositories') {
              ForEach(this.items, (item: SearchResultItem) => {
                RepoSearchRow({ item: item, onOpen: (): void => this.openRepo(item) })
                  .padding({ left: 16, right: 16 })
                this.rowDivider()
              }, (item: SearchResultItem) => item.title)
            } else if (this.kind === 'issues') {
              ForEach(this.items, (item: SearchResultItem) => {
                IssuePrSearchRow({ item: item, compact: false, onOpen: (): void => this.openIssue(item) })
                  .padding({ left: 16, right: 16 })
                this.rowDivider()
              }, (item: SearchResultItem) => `${item.repoFullName}-${item.number}`)
            } else if (this.kind === 'prs') {
              ForEach(this.items, (item: SearchResultItem) => {
                IssuePrSearchRow({ item: item, compact: false, onOpen: (): void => this.openPr(item) })
                  .padding({ left: 16, right: 16 })
                this.rowDivider()
              }, (item: SearchResultItem) => `${item.repoFullName}-${item.number}`)
            } else if (this.kind === 'people') {
              ForEach(this.items, (item: SearchResultItem) => {
                PersonSearchRow({ item: item, onOpen: (): void => this.openUser(item) })
                  .padding({ left: 16, right: 16 })
              }, (item: SearchResultItem) => item.title)
            } else if (this.kind === 'orgs') {
              ForEach(this.items, (item: SearchResultItem) => {
                OrgSearchRow({ item: item, onOpen: (): void => this.openOrg(item) })
                  .padding({ left: 16, right: 16 })
              }, (item: SearchResultItem) => item.title)
            }

            if (this.hasNext) {
              this.moreRow()
            }
          }
        }
        .width('100%')
        .padding({ bottom: 16 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
      .onScroll((_x: number, y: number): void => { this.scrollShadow = y > 0.001; })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_page'))
  }
}
