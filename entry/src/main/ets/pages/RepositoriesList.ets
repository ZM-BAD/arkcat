/**
 * 仓库列表页（Spec 037）：通用（用户/组织，owner+mode 参数化）。
 * 三个筛选下拉（All/Language/Sort）均为真实筛选；行点击进仓库详情。
 */
import { OctIcon } from '../components/OctIcon';
import { RepoListPage } from '../models/ProfileModels';
import { RepoSummary } from '../models/GitHubModels';
import { ProfileListService, RepoOrder } from '../services/ProfileListService';
import { StateView } from '../components/StateView';
import { compactCount } from '../utils/Format';
import { resText } from '../utils/I18n';

const LANGUAGES: string[] = ['Go', 'Rust', 'TypeScript', 'JavaScript', 'Python', 'Java', 'C',
  'C++', 'C#', 'Ruby', 'Shell', 'Kotlin', 'Swift', 'Dart'];

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
  @Local typeFilter: string = 'all';
  @Local langFilter: string = '';
  @Local sortField: string = 'PUSHED_AT';

  aboutToAppear(): void {
    this.refresh();
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
      })
      .catch((e: Error) => {
        this.errorMsg = e.message;
        this.loading = false;
      });
  }

  private loadMore(): void {
    if (!this.hasNextPage || this.loading) {
      return;
    }
    this.loading = true;
    ProfileListService.fetchRepoList(this.token, this.owner, this.mode, this.cursor,
      this.orderRef(), this.langFilter, this.typeFilter)
      .then((page: RepoListPage) => {
        this.repos = this.repos.concat(page.repos);
        this.cursor = page.endCursor;
        this.hasNextPage = page.hasNextPage;
        this.loading = false;
      })
      .catch((e: Error) => {
        this.errorMsg = e.message;
        this.loading = false;
      });
  }

  /** 筛选变更：重置列表后再查 */
  private applyFilters(): void {
    this.repos = [];
    this.cursor = '';
    this.hasNextPage = false;
    this.refresh();
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
    if (this.typeFilter === 'public') {
      return this.stringOf($r('app.string.repos_filter_public'));
    }
    if (this.typeFilter === 'private') {
      return this.stringOf($r('app.string.repos_filter_private'));
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

  private typeMenu(): MenuElement[] {
    return [
      { value: this.stringOf($r('app.string.repos_filter_all')), action: () => { this.typeFilter = 'all'; this.applyFilters(); } },
      { value: this.stringOf($r('app.string.repos_filter_public')), action: () => { this.typeFilter = 'public'; this.applyFilters(); } },
      { value: this.stringOf($r('app.string.repos_filter_private')), action: () => { this.typeFilter = 'private'; this.applyFilters(); } }
    ];
  }

  private langMenu(): MenuElement[] {
    const items: MenuElement[] = [{
      value: this.stringOf($r('app.string.repos_lang_all')),
      action: () => {
        this.langFilter = '';
        this.applyFilters();
      }
    }];
    for (const lang of LANGUAGES) {
      items.push({
        value: lang,
        action: () => {
          this.langFilter = lang;
          this.applyFilters();
        }
      });
    }
    return items;
  }

  private sortMenu(): MenuElement[] {
    const mk = (key: Resource, field: string): MenuElement => {
      return {
        value: this.stringOf(key),
        action: () => {
          this.sortField = field;
          this.applyFilters();
        }
      };
    };
    return [
      mk($r('app.string.repos_sort_recent'), 'PUSHED_AT'),
      mk($r('app.string.repos_sort_stars'), 'STARGAZERS'),
      mk($r('app.string.repos_sort_name'), 'NAME'),
      mk($r('app.string.repos_sort_updated'), 'UPDATED_AT')
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
          .fontWeight(FontWeight.Bold)
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
            .fill(repo.languageColor !== '' ? repo.languageColor : $r('app.color.repo_language_blue'))
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
      // 自绘头部：灰 owner（上）+ 粗体标题（下）+ 🔍
      Row({ space: 8 }) {
        Stack() {
          OctIcon({ res: $r('app.media.oct_arrow_left_24'), iconSize: 20, iconColor: $r('app.color.text_primary') })
        }
.width(44)
.height(44)
        .accessibilityDescription($r('app.string.a11y_back'))
        .focusable(true)
        .onClick(() => {
          this.pathStack.pop();
        })
        Column({ space: 2 }) {
          Text(this.owner)
            .fontSize($r('app.float.caption_font_size'))
            .fontColor($r('app.color.text_secondary'))
          Text($r('app.string.repos_list_title'))
            .fontSize($r('app.float.title_font_size'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
        }
        .alignItems(HorizontalAlign.Start)
        Blank()
        Stack() {
          OctIcon({ res: $r('app.media.oct_search_24'), iconSize: 18, iconColor: $r('app.color.text_primary') })
        }
.width(44)
.height(44)
        .padding(6)
        .accessibilityDescription($r('app.string.a11y_search'))
        .focusable(true)
        .onClick(() => {
          this.pathStack.pushPathByName('search', '');
        })
      }
      .width('100%')
      .height(64)
      .padding({ left: 16, right: 8 })

      // 筛选条：All / Language / Sort（内联 Text，避免 @Builder 参数不刷新）
      Row() {
        Text(this.typeLabel())
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_primary'))
          .padding({ left: 12, right: 10, top: 7, bottom: 7 })
          .borderRadius(12)
          .backgroundColor($r('app.color.card_background'))
          .margin({ right: 8 })
          .bindMenu(this.typeMenu())
        Text(this.langFilter === '' ? this.stringOf($r('app.string.repos_filter_language')) : this.langFilter)
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_primary'))
          .padding({ left: 12, right: 10, top: 7, bottom: 7 })
          .borderRadius(12)
          .backgroundColor($r('app.color.card_background'))
          .margin({ right: 8 })
          .bindMenu(this.langMenu())
        Text(this.sortLabel())
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_primary'))
          .padding({ left: 12, right: 10, top: 7, bottom: 7 })
          .borderRadius(12)
          .backgroundColor($r('app.color.card_background'))
          .margin({ right: 8 })
          .bindMenu(this.sortMenu())
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 2, bottom: 8 })

      if (this.repos.length > 0) {
        Scroll() {
          Column() {
            ForEach(this.repos, (repo: RepoSummary) => {
              this.repoRow(repo)
            }, (repo: RepoSummary) => repo.id !== '' ? repo.id : repo.nameWithOwner)
            if (this.hasNextPage) {
              Text($r('app.string.issues_load_more'))
                .fontSize($r('app.float.body_font_size'))
                .fontColor($r('app.color.link_blue'))
                .padding(12)
                .onClick(() => this.loadMore())
            }
          }
          .padding({ left: 16, right: 16 })
          .width('100%')
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .align(Alignment.Top)
      } else {
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
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_page'))
  }
}
