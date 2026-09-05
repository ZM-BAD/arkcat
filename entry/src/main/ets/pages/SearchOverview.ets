/**
 * 搜索结果聚合页（Spec 046 结果页批 / 官方 7 图：回车直进）：
 * - 头部：← + 搜索框（回车重搜）+ ✕ 返回 + ⋮ 刷新菜单
 * - 六区块（Code/Repositories/Issues/Pull Requests/People/Organizations），
 *   每区块 3 条预览 + 「See X more Y results」链接 → 单类结果页（searchResults）
 * - 区块间细分割线；区块首（Code）不画上分隔线
 */
import { OctIcon } from '../components/OctIcon';
import { PageShadowBar } from '../components/PageShadowBar';
import { StateView } from '../components/StateView';
import { CodeSearchCard } from '../components/CodeSearchCard';
import { RepoSearchRow, IssuePrSearchRow, PersonSearchRow, OrgSearchRow } from '../components/SearchRows';
import {
  SearchService, SearchResultItem, SearchOverviewData, formatBigCount, SearchEntryKind
} from '../services/SearchService';
import { CodeFileResult } from '../services/CodeSearchService';
import { resText } from '../utils/I18n';

/** 代码分组（按 repo 聚合；组头 = 头像 + repo 名） */
interface CodeGroup {
  repoFullName: string;
  avatarUrl: string;
  files: CodeFileResult[];
}

@ComponentV2
export struct SearchOverviewView {
  @Param token: string = '';
  @Param pathStack: NavPathStack = new NavPathStack();
  @Param keyword: string = '';
  @Local query: string = '';
  @Local data: SearchOverviewData | null = null;
  @Local codeGroups: CodeGroup[] = [];
  @Local loading: boolean = false;
  @Local errorMsg: string = '';
  @Local loaded: boolean = false;
  /** 滚动顶部阴影（滚动中显示、回顶消失） */
  @Local scrollShadow: boolean = false;

  aboutToAppear(): void {
    this.query = this.keyword;
    this.load();
  }

  /** 竞态序号：连续搜索丢弃过期响应（review E4） */
  private seq: number = 0;

  private load(): void {
    const q = this.query.trim();
    if (q === '') {
      this.pathStack.pop();
      return;
    }
    const mySeq = ++this.seq;
    this.loading = true;
    this.errorMsg = '';
    this.loaded = false;
    SearchService.fetchOverview(this.token, q)
      .then((d: SearchOverviewData) => {
        if (mySeq !== this.seq) {
          return;
        }
        this.data = d;
        this.codeGroups = this.groupCodes(d.codeFiles);
        this.loading = false;
        this.loaded = true;
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

  /** codeFiles 按 repo 聚合（组序 = 首次出现顺序） */
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

  private areAllEmpty(d: SearchOverviewData | null): boolean {
    return d !== null && d.repoItems.length === 0 && d.issueItems.length === 0 && d.prItems.length === 0 &&
      d.userItems.length === 0 && d.orgItems.length === 0 && d.codeFiles.length === 0;
  }

  private openKind(kind: SearchEntryKind): void {
    const q = this.query.trim();
    if (q === '') {
      return;
    }
    this.pathStack.pushPathByName('searchResults', `${kind}|${q}`);
  }

  private openRepo(item: SearchResultItem): void {
    this.pathStack.pushPathByName('repoDetail', item.title);
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

  private openUser(item: SearchResultItem): void {
    this.pathStack.pushPathByName('userProfile', item.title);
  }

  private openOrg(item: SearchResultItem): void {
    this.pathStack.pushPathByName('orgProfile', item.title);
  }

  private stringOf(res: Resource, ...args: Array<string | number>): string {
    return resText(this.getUIContext(), res, ...args);
  }

  /** 区块标题行 */
  @Builder
  sectionHeader(res: Resource) {
    Text(resText(this.getUIContext(), res))
      .fontSize(20)
      .fontWeight(600)
      .fontColor($r('app.color.text_primary'))
      .width('100%')
      .padding({ top: 16, left: 16, right: 16, bottom: 8 })
  }

  /** See X more Y results 链接行 */
  @Builder
  moreLink(text: string, onOpen: () => void) {
    Row() {
      Text(text)
        .fontSize($r('app.float.menu_font_size'))
        .fontWeight(600)
        .fontColor($r('app.color.text_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
      OctIcon({ res: $r('app.media.oct_chevron_right_16'), iconSize: 16, iconColor: $r('app.color.text_tertiary') })
    }
    .width('100%')
    .height(52)
    .padding({ left: 16, right: 16 })
    .onClick(onOpen)
  }

  /** 代码分组：组头 + 文件名 + 卡 */
  @Builder
  codeGroupsBlock() {
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
          .onSubmit(() => this.load())

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
            action: (): void => this.load()
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
            StateView({ loading: false, error: this.errorMsg, empty: false, onRetry: (): void => this.load() })
              .width('100%')
              .padding({ top: 60 })
          } else if (this.areAllEmpty(this.data)) {
            StateView({ loading: false, error: '', empty: true, emptyText: $r('app.string.search_no_results') })
              .width('100%')
              .padding({ top: 60 })
          } else if (this.data !== null) {
            // 区块一：Code（无上分隔线）
            if (this.codeGroups.length > 0) {
              this.sectionHeader($r('app.string.search_category_code'))
              this.codeGroupsBlock()
              this.moreLink(this.stringOf($r('app.string.search_see_more_code')),
                (): void => this.openKind('code'))
            }
            // 区块二：Repositories
            if (this.data.repoItems.length > 0) {
              Divider().color($r('app.color.divider'))
              this.sectionHeader($r('app.string.search_category_repositories'))
              ForEach(this.data.repoItems, (item: SearchResultItem) => {
                RepoSearchRow({ item: item, onOpen: (): void => this.openRepo(item) })
                  .padding({ left: 16, right: 16 })
              }, (item: SearchResultItem) => item.title)
              if (this.data.repoCount > this.data.repoItems.length) {
                this.moreLink(
                  this.stringOf($r('app.string.search_see_more_repositories'),
                    formatBigCount(this.data.repoCount - this.data.repoItems.length)),
                  (): void => this.openKind('repositories'))
              }
            }
            // 区块三：Issues
            if (this.data.issueItems.length > 0) {
              Divider().color($r('app.color.divider'))
              this.sectionHeader($r('app.string.search_category_issues'))
              ForEach(this.data.issueItems, (item: SearchResultItem) => {
                IssuePrSearchRow({ item: item, onOpen: (): void => this.openIssue(item) })
                  .padding({ left: 16, right: 16 })
              }, (item: SearchResultItem) => `${item.repoFullName}-${item.number}`)
              if (this.data.issueCount > this.data.issueItems.length) {
                this.moreLink(
                  this.stringOf($r('app.string.search_see_more_issues'),
                    formatBigCount(this.data.issueCount - this.data.issueItems.length)),
                  (): void => this.openKind('issues'))
              }
            }
            // 区块四：Pull Requests
            if (this.data.prItems.length > 0) {
              Divider().color($r('app.color.divider'))
              this.sectionHeader($r('app.string.search_category_prs'))
              ForEach(this.data.prItems, (item: SearchResultItem) => {
                IssuePrSearchRow({ item: item, onOpen: (): void => this.openPr(item) })
                  .padding({ left: 16, right: 16 })
              }, (item: SearchResultItem) => `${item.repoFullName}-${item.number}`)
              if (this.data.prCount > this.data.prItems.length) {
                this.moreLink(
                  this.stringOf($r('app.string.search_see_more_prs'),
                    formatBigCount(this.data.prCount - this.data.prItems.length)),
                  (): void => this.openKind('prs'))
              }
            }
            // 区块五：People
            if (this.data.userItems.length > 0) {
              Divider().color($r('app.color.divider'))
              this.sectionHeader($r('app.string.search_category_people'))
              ForEach(this.data.userItems, (item: SearchResultItem) => {
                PersonSearchRow({ item: item, onOpen: (): void => this.openUser(item) })
                  .padding({ left: 16, right: 16 })
              }, (item: SearchResultItem) => item.title)
              if (this.data.userCount > this.data.userItems.length) {
                this.moreLink(
                  this.stringOf($r('app.string.search_see_more_people'),
                    formatBigCount(this.data.userCount - this.data.userItems.length)),
                  (): void => this.openKind('people'))
              }
            }
            // 区块六：Organizations
            if (this.data.orgItems.length > 0) {
              Divider().color($r('app.color.divider'))
              this.sectionHeader($r('app.string.search_category_organizations'))
              ForEach(this.data.orgItems, (item: SearchResultItem) => {
                OrgSearchRow({ item: item, onOpen: (): void => this.openOrg(item) })
                  .padding({ left: 16, right: 16 })
              }, (item: SearchResultItem) => item.title)
              if (this.data.orgCount > this.data.orgItems.length) {
                this.moreLink(
                  this.stringOf($r('app.string.search_see_more_orgs'),
                    formatBigCount(this.data.orgCount - this.data.orgItems.length)),
                  (): void => this.openKind('orgs'))
              }
            }
          }
        }
        .width('100%')
        .padding({ bottom: 24 })
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
