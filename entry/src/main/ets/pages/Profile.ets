/**
 * User Profile 页（Spec 005）：头像/bio/元信息 + Overview/Repos/Stars 子 Tab。
 * Packages 无公开 API 不展示，Projects 按边界跳过；··· 菜单提供 Follow/Unfollow。
 */
import { promptAction } from '@kit.ArkUI';
import { UserProfile } from '../models/ProfileModels';
import { isSelfProfile } from '../models/ProfileModels';
import { ProfileService } from '../services/ProfileService';
import { ContributionCalendar } from '../components/ContributionCalendar';
import { RepoCard } from '../components/RepoCard';
import { StateView } from '../components/StateView';
import { RepoSummary } from '../models/GitHubModels';

@ComponentV2
export struct ProfileView {
  @Param login: string = '';
  @Param token: string = '';
  @Param pathStack: NavPathStack = new NavPathStack();
  @Local profile: UserProfile | null = null;
  @Local tab: number = 0;
  @Local loading: boolean = true;
  @Local errorMsg: string = '';

  aboutToAppear(): void {
    this.refresh();
  }

  private refresh(): void {
    if (this.login === '') {
      return;
    }
    this.loading = true;
    this.errorMsg = '';
    ProfileService.fetchProfile(this.token, this.login)
      .then((profile: UserProfile) => {
        this.profile = profile;
        this.loading = false;
      })
      .catch((e: Error) => {
        this.errorMsg = e.message;
        this.loading = false;
      });
  }

  private toggleFollow(): void {
    const profile = this.profile;
    if (profile === null || profile.userId === '') {
      return;
    }
    const next = !profile.viewerIsFollowing;
    ProfileService.setFollowing(this.token, profile.userId, next)
      .then((following: boolean) => {
        const updated: UserProfile = {
          user: profile.user,
          userId: profile.userId,
          viewerLogin: profile.viewerLogin,
          company: profile.company,
          location: profile.location,
          websiteUrl: profile.websiteUrl,
          statusEmoji: profile.statusEmoji,
          statusMessage: profile.statusMessage,
          viewerIsFollowing: following,
          calendar: profile.calendar,
          pinned: profile.pinned,
          repos: profile.repos,
          stars: profile.stars
        };
        this.profile = updated;
        promptAction.showToast({ message: following ? '已 Follow' : '已 Unfollow' });
      })
      .catch((e: Error) => {
        promptAction.showToast({ message: `操作失败: ${e.message}` });
      });
  }

  @Builder
  repoList(repos: RepoSummary[]) {
    ForEach(repos, (repo: RepoSummary) => {
      RepoCard({
        repo: repo,
        onOpen: (): void => {
          this.pathStack.pushPathByName('repoDetail', repo.nameWithOwner);
        }
      })
        .margin({ bottom: 8 })
    }, (repo: RepoSummary) => repo.id !== '' ? repo.id : repo.nameWithOwner)
  }

  @Builder
  metaRow(icon: string, text: string) {
    if (text !== '') {
      Row({ space: 6 }) {
        Text(icon).fontSize(14)
        Text(text)
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_secondary'))
          .maxLines(1)
      }
    }
  }

  @Builder
  headerCard() {
    Column({ space: 8 }) {
      Row({ space: 12 }) {
        Image(this.profile?.user.avatarUrl ?? '')
          .width(72)
          .height(72)
          .borderRadius(36)
          .backgroundColor($r('app.color.heat_empty'))
        Column({ space: 4 }) {
          if (this.profile !== null && this.profile.statusMessage !== '') {
            Text(`${this.profile.statusEmoji} ${this.profile.statusMessage}`)
              .fontSize($r('app.float.caption_font_size'))
              .fontColor($r('app.color.text_secondary'))
              .maxLines(1)
          }
          Text(this.profile?.user.name ?? '')
            .fontSize($r('app.float.title_font_size'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          Text(`@${this.profile?.user.login ?? ''}`)
            .fontSize($r('app.float.body_font_size'))
            .fontColor($r('app.color.text_secondary'))
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')

      if (this.profile !== null && this.profile.user.bio !== '') {
        Text(this.profile.user.bio)
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_primary'))
          .width('100%')
      }

      Column({ space: 4 }) {
        this.metaRow('🏢', this.profile?.company ?? '')
        this.metaRow('📍', this.profile?.location ?? '')
        this.metaRow('🔗', this.profile?.websiteUrl ?? '')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      Text(`${this.profile?.user.followers ?? 0} followers · ${this.profile?.user.following ?? 0} following`)
        .fontSize($r('app.float.caption_font_size'))
        .fontColor($r('app.color.link_blue'))
        .width('100%')
    }
    .padding($r('app.float.card_padding'))
    .borderRadius($r('app.float.card_radius'))
    .backgroundColor($r('app.color.card_background'))
    .width('100%')
  }

  @Builder
  tabBarLabel(label: string, index: number) {
    Text(label)
      .fontSize($r('app.float.body_font_size'))
      .fontColor(this.tab === index ? $r('app.color.primary') : $r('app.color.text_secondary'))
      .padding({ left: 14, right: 14, top: 8, bottom: 8 })
      .borderWidth({ bottom: 2 })
      .borderColor(this.tab === index ? $r('app.color.primary') : Color.Transparent)
      .onClick(() => {
        this.tab = index;
      })
  }

  build() {
    Column() {
      Row() {
        Text('←')
          .fontSize(20)
          .onClick(() => {
            this.pathStack.pop();
          })
        Blank()
        Text(`@${this.login}`)
          .fontSize($r('app.float.title_font_size'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Blank()
        // ··· 菜单：Follow/Unfollow（自关注时隐藏，见 Spec 边界）
        if (this.profile !== null && !isSelfProfile(this.profile.viewerLogin, this.profile.user.login)) {
          Text('···')
            .fontSize(20)
            .bindMenu([
              {
                value: this.profile.viewerIsFollowing ? 'Unfollow' : 'Follow',
                action: (): void => this.toggleFollow()
              }
            ])
        }
      }
      .width('100%')
      .height(48)
      .padding({ left: 16, right: 16 })

      Scroll() {
        Column({ space: 12 }) {
          if (this.profile !== null) {
            this.headerCard()

            Row({ space: 4 }) {
              this.tabBarLabel('Overview', 0)
              this.tabBarLabel('Repos', 1)
              this.tabBarLabel('Stars', 2)
            }
            .width('100%')

            if (this.tab === 0) {
              ContributionCalendar({ calendar: this.profile.calendar })
              Text('Pinned 仓库')
                .fontSize($r('app.float.title_font_size'))
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_primary'))
                .width('100%')
              this.repoList(this.profile.pinned)
            } else if (this.tab === 1) {
              this.repoList(this.profile.repos)
            } else {
              this.repoList(this.profile.stars)
            }
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
