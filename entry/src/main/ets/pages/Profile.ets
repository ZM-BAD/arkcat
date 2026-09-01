/**
 * User Profile 页（Spec 005 + Spec 034/035 改造）：头像/bio/元信息 + Pinned + 两段可点计数行 + 三导航入口。
 * Packages 无公开 API 不展示，Projects 按边界跳过；··· 菜单提供 Follow/Unfollow；
 * 贡献日历与内嵌切换按官方 App 对齐移除（Spec 035）。
 */
import { promptAction } from '@kit.ArkUI';
import { UserProfile } from '../models/ProfileModels';
import { isSelfProfile } from '../models/ProfileModels';
import { ProfileService } from '../services/ProfileService';
import { RepoCard } from '../components/RepoCard';
import { StateView } from '../components/StateView';
import { OctIcon } from '../components/OctIcon';
import { RepoSummary } from '../models/GitHubModels';
import { resText } from '../utils/I18n';

@ComponentV2
export struct ProfileView {
  @Param login: string = '';
  @Param token: string = '';
  @Param pathStack: NavPathStack = new NavPathStack();
  @Local profile: UserProfile | null = null;
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
          pinned: profile.pinned,
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
  metaRow(iconRes: Resource, text: string) {
    if (text !== '') {
      Row({ space: 6 }) {
        OctIcon({ res: iconRes, iconSize: 14, iconColor: $r('app.color.text_secondary') })
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
        this.metaRow($r('app.media.oct_pin_16'), this.profile?.location ?? '')
        this.metaRow($r('app.media.oct_link_16'), this.profile?.websiteUrl ?? '')
        if (this.profile?.twitterUsername !== '') {
          Row({ space: 6 }) {
            Text('𝕏')
              .fontSize(14)
              .fontColor($r('app.color.text_secondary'))
            Text(`@${this.profile?.twitterUsername ?? ''}`)
              .fontSize($r('app.float.caption_font_size'))
              .fontColor($r('app.color.text_secondary'))
          }
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      // 两段可点计数行（Spec 034）：N followers · M following，中间 · 分隔
      Row({ space: 4 }) {
        Text(this.followersStat())
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_primary'))
          .onClick(() => {
            this.pathStack.pushPathByName('userList', `${this.profile?.user.login ?? ''}|followers`);
          })
        Text('·')
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_secondary'))
        Text(this.followingStat())
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_primary'))
          .onClick(() => {
            this.pathStack.pushPathByName('userList', `${this.profile?.user.login ?? ''}|following`);
          })
      }
      .width('100%')
    }
    .padding($r('app.float.card_padding'))
    .borderRadius($r('app.float.card_radius'))
    .backgroundColor($r('app.color.card_background'))
    .width('100%')
  }

  /** 计数行两段本地化文案（%1$d 占位） */
  private followersStat(): string {
    return resText(this.getUIContext(), $r('app.string.profile_followers_stat'),
      this.profile?.user.followers ?? 0);
  }

  private followingStat(): string {
    return resText(this.getUIContext(), $r('app.string.profile_following_stat'),
      this.profile?.user.following ?? 0);
  }

  /** 导航入口行（Spec 035）：彩块图标 + 标签 + 计数 + › */
  @Builder
  navRow(iconRes: Resource, color: ResourceColor, labelRes: Resource, count: number, onClick: () => void) {
    Row({ space: 12 }) {
      Stack() {
        OctIcon({ res: iconRes, iconSize: 16, iconColor: Color.White })
      }
      .width(44)
      .height(44)
      .backgroundColor(color)
      .borderRadius(6)
      Text(labelRes)
        .fontSize($r('app.float.body_font_size'))
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
      Text(`${count}`)
        .fontSize($r('app.float.body_font_size'))
        .fontColor($r('app.color.text_secondary'))
      OctIcon({ res: $r('app.media.oct_chevron_right_16'), iconSize: 14, iconColor: $r('app.color.text_secondary') })
    }
    .width('100%')
    .padding(10)
    .borderRadius(12)
    .backgroundColor($r('app.color.card_background'))
    .margin({ bottom: 6 })
    .onClick(onClick)
  }

  build() {
    Column() {
      Row() {
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
        Blank()
        Text(`@${this.login}`)
          .fontSize($r('app.float.title_font_size'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Blank()
        // 🔗 分享：系统分享能力后续 Spec（Spec 005 边界）
        OctIcon({ res: $r('app.media.oct_share_16'), iconSize: 20, iconColor: $r('app.color.text_primary') })
          .padding(6)
          .onClick(() => {
            promptAction.showToast({ message: $r('app.string.home_feature_coming') });
          })
        // ⚙ 设置：进入 Settings 页（Spec 014）
        OctIcon({ res: $r('app.media.oct_gear_16'), iconSize: 20, iconColor: $r('app.color.text_primary') })
          .padding(6)
          .onClick(() => {
            this.pathStack.pushPathByName('settings', this.login);
          })
        // ··· 菜单：Follow/Unfollow（自关注时隐藏，见 Spec 边界）
        if (this.profile !== null && !isSelfProfile(this.profile.viewerLogin, this.profile.user.login)) {
          OctIcon({ res: $r('app.media.oct_kebab_horizontal_16'), iconSize: 20, iconColor: $r('app.color.text_primary') })
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

            // 三导航入口（Spec 035：跳独立列表页）
            this.navRow($r('app.media.oct_repo_16'), $r('app.color.text_secondary'), $r('app.string.profile_repositories'), this.profile.repositoriesCount,
              () => this.pathStack.pushPathByName('repositoriesList', `${this.profile?.user.login ?? ''}|user`))
            this.navRow($r('app.media.oct_organization_16'), $r('app.color.shortcut_orange_fg'), $r('app.string.profile_organizations'), this.profile.organizationsCount,
              () => this.pathStack.pushPathByName('orgList', this.profile?.user.login ?? ''))
            this.navRow($r('app.media.oct_star_16'), $r('app.color.star_gold'), $r('app.string.profile_starred'), this.profile.starredCount,
              () => this.pathStack.pushPathByName('starred', this.profile?.user.login ?? ''))
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
