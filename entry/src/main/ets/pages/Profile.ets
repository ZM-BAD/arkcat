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
import { resText } from '../utils/I18n';

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
          twitterUsername: profile.twitterUsername,
          statusEmoji: profile.statusEmoji,
          statusMessage: profile.statusMessage,
          viewerIsFollowing: following,
          calendar: profile.calendar,
          pinned: profile.pinned,
          repos: profile.repos,
          stars: profile.stars,
          repositoriesCount: profile.repositoriesCount,
          organizationsCount: profile.organizationsCount,
          starredCount: profile.starredCount
        };
        this.profile = updated;
        const ui = this.getUIContext();
        promptAction.showToast({
          message: following
            ? resText(ui, $r('app.string.profile_followed_toast'))
            : resText(ui, $r('app.string.profile_unfollowed_toast'))
        });
      })
      .catch((e: Error) => {
        promptAction.showToast({ message: this.fmt($r('app.string.profile_action_failed'), e.message) });
      });
  }

  /** 带 %1$s 格式化：资源模板 + 参数 → 当前语言文案 */
  private fmt(res: Resource, arg: string): string {
    return resText(this.getUIContext(), res, arg);
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
        this.metaRow('📍', this.profile?.location ?? '')
        this.metaRow('🔗', this.profile?.websiteUrl ?? '')
        this.metaRow('𝕏', this.profile?.twitterUsername !== '' ? `@${this.profile?.twitterUsername ?? ''}` : '')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      Text(this.followersText())
        .fontSize($r('app.float.caption_font_size'))
        .fontColor($r('app.color.link_blue'))
        .width('100%')
    }
    .padding($r('app.float.card_padding'))
    .borderRadius($r('app.float.card_radius'))
    .backgroundColor($r('app.color.card_background'))
    .width('100%')
  }

  /** followers/following 本地化文案（%1$d/%2$d 位置占位） */
  private followersText(): string {
    return resText(this.getUIContext(), $r('app.string.followers_suffix'),
      this.profile?.user.followers ?? 0, this.profile?.user.following ?? 0);
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
        // 🔗 分享：系统分享能力后续 Spec（Spec 005 边界）
        Text('🔗')
          .fontSize(18)
          .padding(6)
          .onClick(() => {
            promptAction.showToast({ message: $r('app.string.home_feature_coming') });
          })
        // ⚙ 设置：进入 Settings 页（Spec 014）
        Text('⚙')
          .fontSize(18)
          .padding(6)
          .onClick(() => {
            this.pathStack.pushPathByName('settings', this.login);
          })
        // ··· 菜单：Follow/Unfollow（自关注时隐藏，见 Spec 边界）
        if (this.profile !== null && !isSelfProfile(this.profile.viewerLogin, this.profile.user.login)) {
          Text('···')
            .fontSize(20)
            .bindMenu([
              {
                value: this.profile.viewerIsFollowing
                  ? $r('app.string.profile_unfollow') : $r('app.string.profile_follow'),
                action: (): void => this.toggleFollow()
              }
            ])
        }
      }
      .width('100%')
      .height(48)
      .padding({ left: 16, right: 8 })

      Scroll() {
        Column({ space: 12 }) {
          if (this.profile !== null) {
            this.headerCard()

            // Pinned 横滑双列（Spec 005 官方布局）
            Text($r('app.string.home_pinned_section'))
              .fontSize($r('app.float.title_font_size'))
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
              .width('100%')
            Scroll() {
              Row({ space: 8 }) {
                ForEach(this.profile.pinned, (repo: RepoSummary) => {
                  RepoCard({
                    repo: repo,
                    onOpen: (): void => {
                      this.pathStack.pushPathByName('repoDetail', repo.nameWithOwner);
                    }
                  })
                    .width(200)
                }, (repo: RepoSummary) => repo.id !== '' ? repo.id : repo.nameWithOwner)
              }
              .alignItems(VerticalAlign.Top)
            }
            .scrollable(ScrollDirection.Horizontal)
            .width('100%')
            .scrollBar(BarState.Off)

            // 三计数入口（Spec 005 官方布局）
            this.countEntry('▤', '#57606A', $r('app.string.profile_repositories'), this.profile.repositoriesCount, 0)
            this.countEntry('◫', '#E87B2E', $r('app.string.profile_organizations'), this.profile.organizationsCount, 1)
            this.countEntry('★', '#E3B341', $r('app.string.profile_starred'), this.profile.starredCount, 2)

            // 展开视图（三计数入口对应内容；0=Overview 日历）
            if (this.tab === 0) {
              ContributionCalendar({ calendar: this.profile.calendar })
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

  /** 计数入口：彩块图标 + 标签 + 计数；点击切换展开视图 */
  @Builder
  countEntry(icon: string, color: string, labelRes: Resource, count: number, tabIndex: number) {
    Row({ space: 12 }) {
      Text(icon)
        .fontSize(18)
        .fontColor(Color.White)
        .width(30)
        .height(30)
        .textAlign(TextAlign.Center)
        .backgroundColor(color)
        .borderRadius(8)
      Text(labelRes)
        .fontSize($r('app.float.body_font_size'))
        .fontWeight(this.tab === tabIndex ? FontWeight.Bold : FontWeight.Normal)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
      Text(`${count}`)
        .fontSize($r('app.float.body_font_size'))
        .fontColor($r('app.color.text_secondary'))
    }
    .width('100%')
    .padding(10)
    .borderRadius(10)
    .backgroundColor(this.tab === tabIndex ? '#DBEFE3' : $r('app.color.card_background'))
    .margin({ bottom: 6 })
    .onClick(() => {
      this.tab = tabIndex;
    })
  }
}
