/**
 * Forks 列表页（Spec 053）：仓库详情头部点 N forks 进入。
 * 行 = owner 头像/login（复刻图标）+ 仓库名/描述/「Forked from 上游」/星数/语言；
 * 右上 🔍 就地搜索（名称/描述过滤已加载分页）+ ＋（沿用 RepoDetail 惯例 toast）。
 */
import { promptAction } from '@kit.ArkUI';
import { AppBar, AppBarAction, AppBarActionCfg } from '../components/AppBar';
import { OctIcon } from '../components/OctIcon';
import { PageShadowBar } from '../components/PageShadowBar';
import { ForkEntry, ForkPage } from '../models/RepoSocialModels';
import { RepoService } from '../services/RepoService';
import { StateView } from '../components/StateView';
import { ListLoadingFooter } from '../components/ListLoadingFooter';
import { resText } from '../utils/I18n';
import { compactCount } from '../utils/Format';

@ComponentV2
export struct ForksView {
  @Param owner: string = '';
  @Param name: string = '';
  @Param token: string = '';
  @Param pathStack: NavPathStack = new NavPathStack();
  @Local forks: ForkEntry[] = [];
  @Local cursor: string = '';
  @Local hasNextPage: boolean = false;
  @Local loading: boolean = true;
  @Local errorMsg: string = '';
  @Local inSearch: boolean = false;
  @Local searchQuery: string = '';
  /** 滚动顶部阴影（滚动中显示、回顶消失） */
  @Local scrollShadow: boolean = false;
  @Local isRefreshing: boolean = false;
  /** 触底加载更多（底部转圈指示） */
  @Local loadingMore: boolean = false;

  aboutToAppear(): void {
    this.refresh();
  }

  private refresh(): void {
    if (this.owner === '' || this.name === '') {
      return;
    }
    this.loading = true;
    this.errorMsg = '';
    RepoService.fetchForks(this.token, this.owner, this.name, '')
      .then((page: ForkPage) => {
        this.forks = page.forks;
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
    RepoService.fetchForks(this.token, this.owner, this.name, this.cursor)
      .then((page: ForkPage) => {
        this.forks = this.forks.concat(page.forks);
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

  private stringOf(res: Resource): string {
    return resText(this.getUIContext(), res);
  }

  /** 就地搜索：按仓库名/描述过滤已加载列表（大小写不敏感） */
  private shownForks(): ForkEntry[] {
    const q = this.searchQuery.trim().toLowerCase();
    if (q === '' || !this.inSearch) {
      return this.forks;
    }
    return this.forks.filter((f: ForkEntry) =>
      f.name.toLowerCase().includes(q) || f.description.toLowerCase().includes(q));
  }

  private enterSearch(): void {
    this.inSearch = true;
    this.searchQuery = '';
    // 下一帧获焦，自动弹起软键盘
    setTimeout((): void => {
      this.getUIContext().getFocusController().requestFocus('forks_search');
    }, 60);
  }

  private exitSearch(): void {
    this.inSearch = false;
    this.searchQuery = '';
  }

  private comingSoon(): void {
    promptAction.showToast({ message: $r('app.string.home_feature_coming') });
  }

  /** 列表行（参考截图：头像与 owner 名同高同排，无卡片底、留白分隔） */
  @Builder
  forkRow(fork: ForkEntry) {
    Column({ space: 4 }) {
      Row({ space: 8 }) {
        Image(fork.ownerAvatarUrl)
          .width(20)
          .height(20)
          .borderRadius(12)
          .backgroundColor($r('app.color.text_tertiary'))
        Text(fork.ownerLogin)
          .fontSize($r('app.float.chip_font_size'))
          .fontColor($r('app.color.text_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
      }
      .width('100%')

        Text(fork.name)
          .fontSize($r('app.float.menu_font_size'))
          .fontWeight(600)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        if (fork.description !== '') {
          Text(fork.description)
            .fontSize($r('app.float.body_font_size'))
            .fontColor($r('app.color.text_secondary'))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }

        if (fork.parentNameWithOwner !== '') {
          Row({ space: 4 }) {
            OctIcon({ res: $r('app.media.oct_repo_forked_16'), iconSize: 12, iconColor: $r('app.color.text_tertiary') })
            Text(resText(this.getUIContext(), $r('app.string.social_fork_from'), fork.parentNameWithOwner))
              .fontSize($r('app.float.caption_font_size'))
              .fontColor($r('app.color.text_secondary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
          }
          .width('100%')
        }

        Row({ space: 12 }) {
          Row({ space: 4 }) {
            OctIcon({ res: $r('app.media.oct_star_16'), iconSize: 13, iconColor: $r('app.color.star_gold') })
            Text(compactCount(fork.stargazerCount))
              .fontSize($r('app.float.caption_font_size'))
              .fontColor($r('app.color.text_secondary'))
          }
          if (fork.primaryLanguage !== '') {
            Row({ space: 4 }) {
              Circle()
                .width(9)
                .height(9)
                .fill(fork.languageColor !== '' ? fork.languageColor : $r('app.color.repo_language_unknown'))
              Text(fork.primaryLanguage)
                .fontSize($r('app.float.caption_font_size'))
                .fontColor($r('app.color.text_secondary'))
            }
          }
        }
        .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .onClick(() => {
        this.pathStack.pushPathByName('repoDetail', fork.nameWithOwner);
      })
  }

  build() {
    Column() {
      if (this.inSearch) {
        // 搜索态：内联搜索头不进 AppBar（Spec 067 豁免内联搜索头），保留自绘
        Row() {
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
          TextInput({
            placeholder: this.stringOf($r('app.string.social_forks_search')),
            text: this.searchQuery
          })
            .id('forks_search')
            .fontSize($r('app.float.title_font_size'))
            .fontColor($r('app.color.text_primary'))
            .caretColor($r('app.color.link_blue'))
            .backgroundColor(Color.Transparent)
            .onChange((v: string) => {
              this.searchQuery = v;
            })
            .layoutWeight(1)
          Text(this.stringOf($r('app.string.search_cancel')))
            .fontSize($r('app.float.body_font_size'))
            .fontColor($r('app.color.link_blue'))
            .padding({ left: 6, right: 12, top: 6, bottom: 6 })
            .responseRegion({ x: -6, y: -6, width: '140%', height: '140%' })
            .onClick(() => this.exitSearch())
        }
        .width('100%')
        .height(48)
        .padding({ left: 4, right: 4 })
      } else {
        AppBar({
          showBack: true,
          title: this.name,
          subtitle: this.stringOf($r('app.string.social_forks')),
          onBack: (): void => {
            this.pathStack.pop();
          },
          actions: [
            new AppBarAction($r('app.media.oct_search_24'), (): void => this.enterSearch(),
              { iconColor: $r('app.color.link_blue'), a11y: $r('app.string.social_forks_search') }),
            new AppBarAction($r('app.media.oct_plus_circle_24'), (): void => this.comingSoon(),
              { iconColor: $r('app.color.link_blue'), a11y: $r('app.string.a11y_new') })
          ]
        })
      }
      Divider().strokeWidth(1).color($r('app.color.divider'))

      PageShadowBar({ show: this.scrollShadow })

      Refresh({ refreshing: $$this.isRefreshing }) {
      Scroll() {
        if (this.shownForks().length > 0) {
          Column() {
            ForEach(this.shownForks(), (fork: ForkEntry, index: number) => {
              this.forkRow(fork)
              if (index < this.shownForks().length - 1) {
                Divider().strokeWidth(1).color($r('app.color.divider')).margin({ left: 16 })
              }
            }, (fork: ForkEntry) => fork.nameWithOwner)
            if (this.hasNextPage) {
              ListLoadingFooter({ show: this.loadingMore })
            }
          }
          .padding({ left: 0, right: 0 })
          .width('100%')
        } else if (this.inSearch || this.errorMsg !== '' || this.loading) {
        Column() {
          if (this.inSearch) {
            Text(this.stringOf($r('app.string.social_forks_empty')))
              .fontSize($r('app.float.body_font_size'))
              .fontColor($r('app.color.text_secondary'))
          } else {
            StateView({
              loading: this.loading,
              error: this.errorMsg,
              onRetry: () => this.refresh()
            })
          }
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        Column() {
          Text(this.stringOf($r('app.string.social_forks_empty')))
            .fontSize($r('app.float.body_font_size'))
            .fontColor($r('app.color.text_secondary'))
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
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
  }
}
