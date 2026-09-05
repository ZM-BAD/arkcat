/**
 * Explore Tab（Spec 056 官方化）：Discover 入口（Trending/Awesome Lists）+ Activity 合并 PR 动态流。
 * 003 的 Topics 网格/高星推荐已随官方版式移除；
 * 官方个性化 feed 无公开 API，Activity 用 received_events 近似（Spec 056 边界）。
 */
import { promptAction } from '@kit.ArkUI';
import { ExploreActivityEvent } from '../models/ExploreModels';
import { ExploreService } from '../services/ExploreService';
import { friendlyError } from '../services/GitHttpClient';
import { StateView } from '../components/StateView';
import { OctIcon } from '../components/OctIcon';
import { PageShadowBar } from '../components/PageShadowBar';
import { ExploreActivityCard } from '../components/ExploreActivityCard';

@ComponentV2
export struct ExploreView {
  @Param token: string = '';
  @Param pathStack: NavPathStack = new NavPathStack();
  @Local events: ExploreActivityEvent[] = [];
  @Local loading: boolean = true;
  @Local errorMsg: string = '';
  /** 滚动顶部阴影（滚动中显示、回顶消失） */
  @Local scrollShadow: boolean = false;

  aboutToAppear(): void {
    this.load();
  }

  private load(): void {
    this.loading = true;
    this.errorMsg = '';
    ExploreService.fetchActivity(this.token)
      .then((events: ExploreActivityEvent[]) => {
        this.events = events;
        this.loading = false;
      })
      .catch((e: Error) => {
        this.errorMsg = friendlyError(this.getUIContext(), e);
        this.loading = false;
      });
  }

  private openListPage(kind: string): void {
    this.pathStack.pushPathByName('exploreRepoList', kind);
  }

  /** Activity 类型筛选：官方面板无参考图，占位待下批（Spec 056 边界） */
  private filterComing(): void {
    promptAction.showToast({ message: $r('app.string.home_feature_coming') });
  }

  /** Discover 入口行：彩色方标 + 标题（入参均为静态资源，无状态刷新问题） */
  @Builder
  discoverEntry(iconRes: Resource, bg: ResourceColor, labelRes: Resource, kind: string) {
    Row({ space: 12 }) {
      Stack() {
        OctIcon({ res: iconRes, iconSize: 22, iconColor: Color.White })
      }
      .width(44)
      .height(44)
      .borderRadius(12)
      .backgroundColor(bg)
      Text(labelRes)
        .fontSize($r('app.float.sub_text_font_size'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
    .onClick(() => this.openListPage(kind))
  }

  build() {
    Column() {
      Text($r('app.string.tab_explore'))
        .fontSize($r('app.float.title_font_size'))
        .fontWeight(600)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
        .padding($r('app.float.page_padding'))

      PageShadowBar({ show: this.scrollShadow })

      Scroll() {
        Column() {
          // Discover 区（白画布，水平 padding）
          Column() {
            Text($r('app.string.explore_discover'))
              .fontSize($r('app.float.title_font_size'))
              .fontWeight(600)
              .fontColor($r('app.color.text_primary'))
              .width('100%')
              .margin({ bottom: 4 })

            this.discoverEntry($r('app.media.oct_flame_16'), $r('app.color.flame_fg'),
              $r('app.string.explore_trending'), 'trending')
            this.discoverEntry($r('app.media.oct_smiley_16'), $r('app.color.merged_badge_bg'),
              $r('app.string.explore_awesome'), 'awesome')
          }
          .width('100%')
          .padding({ left: 16, right: 16 })

          // Activity 区（灰带全宽：官方 canvas.inset，页面画布为 canvas.default 白）
          Column() {
            Row() {
              Text($r('app.string.explore_activity'))
                .fontSize($r('app.float.title_font_size'))
                .fontWeight(600)
                .fontColor($r('app.color.text_primary'))
              Blank()
              Row() {
                OctIcon({ res: $r('app.media.oct_filter_16'), iconSize: 18, iconColor: $r('app.color.text_primary') })
              }
              .width(36)
              .height(36)
              .onClick(() => this.filterComing())
            }
            .width('100%')

            if (this.events.length > 0) {
              Column({ space: 16 }) {
                ForEach(this.events, (event: ExploreActivityEvent) => {
                  ExploreActivityCard({
                    token: this.token,
                    event: event,
                    onOpenPr: (): void => {
                      this.pathStack.pushPathByName('prDetail', `${event.repoFullName}/${event.number}`);
                    },
                    onOpenRepo: (): void => {
                      this.pathStack.pushPathByName('repoDetail', event.repoFullName);
                    },
                    onOpenUser: (): void => {
                      this.pathStack.pushPathByName('userProfile', event.authorLogin);
                    }
                  })
                }, (event: ExploreActivityEvent) => event.key)
              }
              .width('100%')
              .margin({ top: 8 })
            } else if (!this.loading && this.errorMsg === '') {
              StateView({
                loading: false,
                error: '',
                empty: true,
                emptyText: $r('app.string.explore_activity_empty')
              })
            } else {
              StateView({
                loading: this.loading,
                error: this.errorMsg,
                onRetry: (): void => this.load()
              })
            }
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 12, bottom: 24 })
          .backgroundColor($r('app.color.bg_page'))
          .margin({ top: 8 })
        }
        .width('100%')
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
      .onScroll((_x: number, y: number): void => {
        this.scrollShadow = y > 0.001;
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.card_background'))
  }
}
