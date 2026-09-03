/**
 * Search 结果页（Spec 015 v2）：六类搜索结果统一列表。
 * - repositories/issues/prs/people → GraphQL search（分页 Show more）
 * - code → GraphQL CODE（v1 结果卡迁入）
 * - orgs → REST /search/users?type=organization 兜底
 * 仓库/用户/组织复用 RepoCard/UserCard；Issue/PR 用紧凑行。
 */
import { OctIcon } from '../components/OctIcon';
import { RepoCard } from '../components/RepoCard';
import { UserCard } from '../components/UserCard';
import { StateView } from '../components/StateView';
import { SearchResultItem, SearchEntryKind, SearchService, CodeSearchItem } from '../services/SearchService';
import { RepoSummary, UserSummary } from '../models/GitHubModels';
import { resText } from '../utils/I18n';

@ComponentV2
export struct SearchResultsView {
  @Param token: string = '';
  @Param pathStack: NavPathStack = new NavPathStack();
  @Param kind: string = '';
  @Param keyword: string = '';
  @Local items: SearchResultItem[] = [];
  @Local codeItems: CodeSearchItem[] = [];
  @Local loading: boolean = false;
  @Local errorMsg: string = '';
  @Local hasNext: boolean = false;
  @Local cursor: string = '';
  @Local loaded: boolean = false;

  aboutToAppear(): void {
    this.loadFirst();
  }

  private loadFirst(): void {
    this.loading = true;
    this.errorMsg = '';
    this.items = [];
    this.codeItems = [];
    this.hasNext = false;
    this.cursor = '';
    if (this.kind === 'code') {
      SearchService.fetchCodeResults(this.token, this.keyword)
        .then((list: CodeSearchItem[]) => {
          this.codeItems = list;
          this.loading = false;
          this.loaded = true;
        })
        .catch((e: Error) => {
          this.errorMsg = e.message;
          this.loading = false;
          this.loaded = true;
        });
      return;
    }
    if (this.kind === 'orgs') {
      SearchService.fetchOrgResults(this.token, this.keyword)
        .then((list: SearchResultItem[]) => {
          this.items = list;
          this.loading = false;
          this.loaded = true;
        })
        .catch((e: Error) => {
          this.errorMsg = e.message;
          this.loading = false;
          this.loaded = true;
        });
      return;
    }
    SearchService.fetchSearchResults(this.token, this.kind as SearchEntryKind, this.keyword)
      .then((page) => {
        this.items = page.items;
        this.hasNext = page.hasNextPage;
        this.cursor = page.endCursor;
        this.loading = false;
        this.loaded = true;
      })
      .catch((e: Error) => {
        this.errorMsg = e.message;
        this.loading = false;
        this.loaded = true;
      });
  }

  private loadMore(): void {
    if (this.cursor === '') {
      return;
    }
    this.loading = true;
    SearchService.fetchSearchResults(this.token, this.kind as SearchEntryKind, this.keyword, this.cursor)
      .then((page) => {
        this.items = this.items.concat(page.items);
        this.hasNext = page.hasNextPage;
        this.cursor = page.endCursor;
        this.loading = false;
      })
      .catch((e: Error) => {
        this.errorMsg = e.message;
        this.loading = false;
      });
  }

  /** 分类标题（结果页导航头） */
  private title(): string {
    const ui = this.getUIContext();
    switch (this.kind) {
      case 'code':
        return resText(ui, $r('app.string.search_category_code'));
      case 'repositories':
        return resText(ui, $r('app.string.search_category_repositories'));
      case 'issues':
        return resText(ui, $r('app.string.search_category_issues'));
      case 'prs':
        return resText(ui, $r('app.string.search_category_prs'));
      case 'people':
        return resText(ui, $r('app.string.search_category_people'));
      case 'orgs':
        return resText(ui, $r('app.string.search_category_organizations'));
      default:
        return '';
    }
  }

  /** Repository ⇒ RepoSummary */
  private toRepoSummary(item: SearchResultItem): RepoSummary {
    const parts = item.title.split('/');
    const name = parts.length > 1 ? parts[1] : item.title;
    return {
      id: item.title,
      name: name,
      nameWithOwner: item.title,
      description: item.subtitle,
      stargazerCount: item.stars,
      forkCount: item.forks,
      primaryLanguage: item.language,
      languageColor: item.languageColor,
      isPrivate: false,
      ownerLogin: item.title.split('/')[0],
      ownerAvatarUrl: ''
    };
  }

  /** User/Org ⇒ UserSummary */
  private toUserSummary(item: SearchResultItem): UserSummary {
    return {
      login: item.title,
      name: item.subtitle,
      avatarUrl: item.avatarUrl,
      bio: item.bio,
      followers: item.followers,
      following: item.following
    };
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

  private stringOf(res: Resource): string {
    return resText(this.getUIContext(), res);
  }

  /** 文件卡扩展名徽章（Markdown 等） */
  private badgeText(item: CodeSearchItem): string {
    if (item.isMarkdown) {
      return this.stringOf($r('app.string.markdown_badge'));
    }
    const seg = item.name.split('.');
    return seg.length > 1 ? seg[seg.length - 1].toUpperCase() : '';
  }

  @Builder
  issueRow(item: SearchResultItem) {
    Row({ space: 12 }) {
      Circle()
        .width(12)
        .height(12)
        .fill(item.state === 'OPEN' ? $r('app.color.success_text') :
          (item.kind === 'pr' && item.state === 'MERGED' ? $r('app.color.shortcut_purple_fg') : $r('app.color.danger_text')))
      Column({ space: 4 }) {
        Text(item.title)
          .fontSize($r('app.float.body_font_size'))
          .fontColor($r('app.color.text_primary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Text(`${item.repoFullName} #${item.number}`)
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_secondary'))
          .maxLines(1)
          .width('100%')
      }
      .layoutWeight(1)
    }
    .width('100%')
    .padding({ top: 10, bottom: 10 })
    .onClick(() => {
      if (item.kind === 'pr') {
        this.openPr(item);
      } else {
        this.openIssue(item);
      }
    })
  }

  @Builder
  codeCard(item: CodeSearchItem) {
    Column({ space: 6 }) {
      Row({ space: 6 }) {
        OctIcon({ res: $r('app.media.oct_file_16'), iconSize: 14, iconColor: $r('app.color.text_secondary') })
        Text(item.repoFullName)
          .fontSize($r('app.float.body_font_size'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.link_blue'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        Text(item.name)
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_secondary'))
          .maxLines(1)
      }
      .width('100%')
      .onClick(() => this.pathStack.pushPathByName('repoDetail', item.repoFullName))

      Row({ space: 8 }) {
        Circle()
          .width(12)
          .height(12)
          .fill($r('app.color.shortcut_purple_fg'))
        Text(item.isMarkdown ? this.stringOf($r('app.string.markdown_badge')) : this.badgeText(item))
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_primary'))
      }
      .width('100%')

      // 代码行占位（正文从 REST 兜底，Spec 016 补充）
      Text(item.path)
        .fontSize($r('app.float.caption_font_size'))
        .fontColor($r('app.color.text_secondary'))
        .maxLines(3)
        .width('100%')
        .padding(10)
        .backgroundColor($r('app.color.chip_bg'))
        .borderRadius(6)
    }
    .padding($r('app.float.card_padding'))
    .borderRadius($r('app.float.card_radius'))
    .backgroundColor($r('app.color.card_background'))
    .width('100%')
    .margin({ bottom: 8 })
  }

  build() {
    Column() {
      // 导航头：← + 分类标题
      Row({ space: 8 }) {
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
        Text(this.title())
          .fontSize($r('app.float.title_font_size'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
      }
      .width('100%')
      .height(48)
      .padding({ left: 16, right: 12 })
      .backgroundColor($r('app.color.card_background'))

      Scroll() {
        Column() {
          if (this.kind === 'code') {
            if (this.codeItems.length > 0) {
              ForEach(this.codeItems, (item: CodeSearchItem) => {
                this.codeCard(item)
              }, (item: CodeSearchItem) => `${item.repoFullName}/${item.path}`)
            }
          } else {
            ForEach(this.items, (item: SearchResultItem) => {
              if (item.kind === 'repository') {
                RepoCard({
                  repo: this.toRepoSummary(item),
                  onOpen: (): void => this.openRepo(item)
                })
                  .width('100%')
                  .margin({ bottom: 8 })
              } else if (item.kind === 'user' || item.kind === 'organization') {
                UserCard({
                  user: this.toUserSummary(item),
                  onOpenProfile: (): void => {
                    if (item.kind === 'organization') {
                      this.openOrg(item);
                    } else {
                      this.openUser(item);
                    }
                  }
                })
                  .width('100%')
                  .margin({ bottom: 8 })
              } else {
                this.issueRow(item)
              }
            }, (item: SearchResultItem) => `${item.kind}-${item.title}-${item.number}`)
          }

          // 分页：Show more
          if (this.hasNext) {
            Text($r('app.string.search_matches_more'))
              .fontSize($r('app.float.body_font_size'))
              .fontColor($r('app.color.link_blue'))
              .padding({ top: 12, bottom: 12 })
              .width('100%')
              .textAlign(TextAlign.Center)
              .onClick(() => this.loadMore())
          }

          if (this.loaded && !this.loading && this.items.length === 0 && this.codeItems.length === 0) {
            StateView({ error: this.errorMsg, empty: this.errorMsg === '', emptyText: $r('app.string.search_no_results') })
          }
        }
        .padding({ left: 16, right: 16, top: 8 })
        .width('100%')
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_page'))
  }
}
