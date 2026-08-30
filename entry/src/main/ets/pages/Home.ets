/**
 * Home Tab（Spec 001）：App Bar（Logo/搜索/铃铛角标）+ 用户卡片 + 贡献日历 + Pinned 仓库。
 */
import { promptAction } from '@kit.ArkUI';
import { HomeOverview, RepoSummary } from '../models/GitHubModels';
import { HomeService } from '../services/HomeService';
import { UserCard } from '../components/UserCard';
import { ContributionCalendar } from '../components/ContributionCalendar';
import { RepoCard } from '../components/RepoCard';
import { StateView } from '../components/StateView';

@ComponentV2
export struct HomeView {
  @Param token: string = '';
  @Param pathStack: NavPathStack = new NavPathStack();
  @Local overview: HomeOverview | null = null;
  @Local loading: boolean = true;
  @Local errorMsg: string = '';
  @Local hasUnread: boolean = false;

  aboutToAppear(): void {
    this.refresh();
  }

  private refresh(): void {
    this.loading = true;
    this.errorMsg = '';
    HomeService.fetchHomeOverview(this.token)
      .then((overview: HomeOverview) => {
        this.overview = overview;
        this.loading = false;
        return HomeService.hasUnreadNotifications(this.token);
      })
      .then((hasUnread: boolean) => {
        this.hasUnread = hasUnread;
      })
      .catch((e: Error) => {
        this.errorMsg = e.message;
        this.loading = false;
      });
  }

  @Builder
  appBar() {
    Row() {
      Text('🐙')
        .fontSize(24)
      Blank()
      Text('🔍')
        .fontSize(20)
        .onClick(() => {
          promptAction.showToast({ message: $r('app.string.home_search_hint') });
        })
      // 未读角标：REST 兜底，有未读显示 1+
      if (this.hasUnread) {
        Badge({ value: '1+', position: BadgePosition.RightTop, style: { badgeSize: 16, badgeColor: '#D1242F' } }) {
          Text('🔔')
            .fontSize(20)
            .margin({ right: 8 })
        }
      } else {
        Text('🔔')
          .fontSize(20)
          .margin({ left: 16 })
      }
    }
    .width('100%')
    .height(48)
    .padding({ left: 16, right: 16 })
    .backgroundColor($r('app.color.card_background'))
  }

  @Builder
  pinnedSection() {
    Text($r('app.string.home_pinned_section'))
      .fontSize($r('app.float.title_font_size'))
      .fontWeight(FontWeight.Bold)
      .fontColor($r('app.color.text_primary'))
      .margin({ top: 16, bottom: 8 })

    ForEach(this.overview?.pinned ?? [], (repo: RepoSummary) => {
      RepoCard({ repo: repo })
        .margin({ bottom: 8 })
    }, (repo: RepoSummary) => repo.id !== '' ? repo.id : repo.nameWithOwner)
  }

  build() {
    Column() {
      this.appBar()

      Scroll() {
        Column() {
          if (this.overview !== null) {
            UserCard({
              user: this.overview.user,
              onOpenProfile: () => {
                // Spec 005 将注册 userProfile 路由目的地
                this.pathStack.pushPathByName('userProfile', this.overview?.user.login ?? '');
              }
            })
              .margin({ top: 12 })

            Text($r('app.string.home_calendar_section'))
              .fontSize($r('app.float.title_font_size'))
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
              .margin({ top: 16, bottom: 8 })

            ContributionCalendar({ calendar: this.overview.calendar })

            this.pinnedSection()
          } else {
            StateView({
              loading: this.loading,
              error: this.errorMsg,
              onRetry: () => this.refresh()
            })
          }
        }
        .padding($r('app.float.page_padding'))
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
