/**
 * User Profile 页（Spec 005 + Spec 034/035 改造）：头像/bio/元信息 + Pinned + 两段可点计数行 + 三导航入口。
 * Packages 无公开 API 不展示，Projects 按边界跳过；··· 菜单提供 Follow/Unfollow；
 * 贡献日历与内嵌切换按官方 App 对齐移除（Spec 035）。
 */
import { promptAction } from '@kit.ArkUI';
import { UserProfile } from '../models/ProfileModels';
import { isSelfProfile } from '../models/ProfileModels';
import { ProfileService } from '../services/ProfileService';
import { AchievementsService } from '../services/AchievementsService';
import { RepoCard } from '../components/RepoCard';
import { StateView } from '../components/StateView';
import { OctIcon } from '../components/OctIcon';
import { PageShadowBar } from '../components/PageShadowBar';
import { RepoSummary } from '../models/GitHubModels';
import { resText } from '../utils/I18n';

/** ··· 菜单项（模块级 interface 供 @Local 类型化数组使用） */
interface FollowMenuEntry {
  value: ResourceStr;
  action: () => void;
}

@ComponentV2
export struct ProfileView {
  @Param login: string = '';
  @Param token: string = '';
  @Param pathStack: NavPathStack = new NavPathStack();
  @Local profile: UserProfile | null = null;
  /** ··· 菜单项：bindMenu 数组不随状态刷新（V2 坑），viewerIsFollowing 变化后显式重建（review D6） */
  @Local followMenuItems: FollowMenuEntry[] = [];
  @Local loading: boolean = true;
  @Local errorMsg: string = '';
  /** 滚动顶部阴影（滚动中显示、回顶消失） */
  @Local scrollShadow: boolean = false;
  /** 勋章图片 URL 列表（官方 CDN，AchievementsService 抓取） */
  @Local achievements: string[] = [];

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
        this.rebuildFollowMenu();
        this.loading = false;
      })
      .catch((e: Error) => {
        this.errorMsg = e.message;
        this.loading = false;
      });
    // 勋章无 GraphQL 字段：HTML 抓取独立于主查询，失败仅隐藏勋章行
    AchievementsService.fetch(this.login)
      .then((urls: string[]) => {
        this.achievements = urls;
      })
      .catch(() => {
        this.achievements = [];
      });
  }

  /** 依 viewerIsFollowing 重建 ··· 菜单（review D6） */
  private rebuildFollowMenu(): void {
    const p = this.profile;
    if (p === null) {
      this.followMenuItems = [];
      return;
    }
    const items: FollowMenuEntry[] = [];
    items.push({
      value: p.viewerIsFollowing ? $r('app.string.profile_unfollow') : $r('app.string.profile_follow'),
      action: (): void => this.toggleFollow()
    });
    this.followMenuItems = items;
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
          email: profile.email,
          statusEmoji: profile.statusEmoji,
          statusMessage: profile.statusMessage,
          viewerIsFollowing: following,
          isDeveloperProgramMember: profile.isDeveloperProgramMember,
          pinned: profile.pinned,
          repositoriesCount: profile.repositoriesCount,
          organizationsCount: profile.organizationsCount,
          starredCount: profile.starredCount
        };
        this.profile = updated;
        this.rebuildFollowMenu();
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

  /** 信息行：icon 固定在 16×16 容器保证跨行对齐；bold 时内容加粗 */
  @Builder
  metaRow(iconRes: Resource, text: string, bold: boolean = false) {
    if (text !== '') {
      Row({ space: 8 }) {
        Stack() {
          OctIcon({ res: iconRes, iconSize: 16, iconColor: $r('app.color.text_secondary') })
        }
        .width(16)
        .height(16)
        Text(text)
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_secondary'))
          .fontWeight(bold ? 600 : FontWeight.Normal)
          .maxLines(1)
      }
      .width('100%')
    }
  }

  /** 状态行：emoji + Focusing 文案 + 最右铅笔（灰）；灰底矩形背景，仅自己主页可编辑入口 */
  @Builder
  statusRow() {
    if (this.profile !== null && this.profile.statusMessage !== '') {
      Row() {
        Text(`${this.profile.statusEmoji} ${this.profile.statusMessage}`)
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_secondary'))
          .maxLines(1)
        Blank()
        if (isSelfProfile(this.profile.viewerLogin, this.profile.user.login)) {
          OctIcon({ res: $r('app.media.oct_pencil_16'), iconSize: 16, iconColor: $r('app.color.text_secondary') })
            .padding(4)
            .responseRegion({ x: -10, y: -10, width: '183%', height: '183%' })
            .onClick(() => {
              promptAction.showToast({ message: $r('app.string.home_feature_coming') });
            })
        }
      }
      .width('100%')
      .padding({ left: 12, right: 4, top: 8, bottom: 8 })
      .borderRadius(6)
      .backgroundColor($r('app.color.heat_empty'))
    }
  }

  /** 勋章行：trophy + GitHub 官方徽章图列表（AchievementsService 抓取 HTML） */
  @Builder
  achievementsRow() {
    if (this.achievements.length > 0) {
      Row({ space: 8 }) {
        OctIcon({ res: $r('app.media.oct_trophy_16'), iconSize: 16, iconColor: $r('app.color.text_secondary') })
        // 徽章数量不定：包横向 Scroll 防溢出，内层行 minWidth 撑满、超宽可滑
        Scroll() {
          Row({ space: 0 }) {
            ForEach(this.achievements, (url: string, index: number) => {
              Image(url)
                .width(24)
                .height(24)
                .borderRadius(12)
                .backgroundColor($r('app.color.heat_empty'))
                .padding(2)
                .onClick(() => {
                  this.pathStack.pushPathByName('achievementDetail', `${this.login}|${index}`);
                })
            }, (url: string, index: number) => `${url}_${index}`)
          }
          .constraintSize({ minWidth: '100%' })
        }
        .scrollBar(BarState.Off)
        .layoutWeight(1)
      }
      .width('100%')
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
          Text(this.profile?.user.name ?? '')
            .fontSize($r('app.float.title_font_size'))
            .fontWeight(600)
            .fontColor($r('app.color.text_primary'))
          Text(`@${this.profile?.user.login ?? ''}`)
            .fontSize($r('app.float.body_font_size'))
            .fontColor($r('app.color.text_secondary'))
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')

      this.statusRow()

      if (this.profile !== null && this.profile.user.bio !== '') {
        Text(this.profile.user.bio)
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_primary'))
          .width('100%')
      }

      Column({ space: 8 }) {
        this.metaRow($r('app.media.oct_location_16'), this.profile?.location ?? '')
        this.metaRow($r('app.media.oct_link_16'), this.profile?.websiteUrl ?? '', true)
        this.metaRow($r('app.media.oct_mail_16'), this.profile?.email ?? '', true)
        if (this.profile?.twitterUsername !== '') {
          Row({ space: 8 }) {
            Stack() {
              Text('𝕏')
                .fontSize(14)
                .fontColor($r('app.color.text_secondary'))
            }
            .width(16)
            .height(16)
            Text(`@${this.profile?.twitterUsername ?? ''}`)
              .fontSize($r('app.float.caption_font_size'))
              .fontColor($r('app.color.text_secondary'))
              .fontWeight(600)
              .maxLines(1)
          }
          .width('100%')
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      // Developer Program Member（用户实际为成员时才显示，官方徽章位序=X 之下、followers 之上）
      if (this.profile !== null && this.profile.isDeveloperProgramMember) {
        Row({ space: 8 }) {
          Stack() {
            OctIcon({ res: $r('app.media.oct_cpu_16'), iconSize: 16, iconColor: $r('app.color.text_secondary') })
          }
          .width(16)
          .height(16)
          Text($r('app.string.profile_dev_program_member'))
            .fontSize($r('app.float.caption_font_size'))
            .fontColor($r('app.color.text_secondary'))
            .maxLines(1)
        }
        .width('100%')
      }

      // 两段可点计数行（Spec 034）：person 图标 + N followers · M following（数字加粗）
      Row({ space: 8 }) {
        Stack() {
          OctIcon({ res: $r('app.media.oct_person_16'), iconSize: 16, iconColor: $r('app.color.text_secondary') })
        }
        .width(16)
        .height(16)
        Text(`${this.profile?.user.followers ?? 0}`)
          .fontSize($r('app.float.caption_font_size'))
          .fontWeight(600)
          .fontColor($r('app.color.text_primary'))
          .responseRegion({ x: 0, y: -12, width: '100%', height: '220%' })
          .onClick(() => {
            this.pathStack.pushPathByName('userList', `${this.profile?.user.login ?? ''}|followers`);
          })
        Text(resText(this.getUIContext(), $r('app.string.profile_followers_unit')))
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_secondary'))
          .responseRegion({ x: 0, y: -12, width: '100%', height: '220%' })
          .onClick(() => {
            this.pathStack.pushPathByName('userList', `${this.profile?.user.login ?? ''}|followers`);
          })
        Text('·')
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_secondary'))
        Text(`${this.profile?.user.following ?? 0}`)
          .fontSize($r('app.float.caption_font_size'))
          .fontWeight(600)
          .fontColor($r('app.color.text_primary'))
          .responseRegion({ x: 0, y: -12, width: '100%', height: '220%' })
          .onClick(() => {
            this.pathStack.pushPathByName('userList', `${this.profile?.user.login ?? ''}|following`);
          })
        Text(resText(this.getUIContext(), $r('app.string.profile_following_unit')))
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_secondary'))
          .responseRegion({ x: 0, y: -12, width: '100%', height: '220%' })
          .onClick(() => {
            this.pathStack.pushPathByName('userList', `${this.profile?.user.login ?? ''}|following`);
          })
        Blank()
      }
      .width('100%')

      this.achievementsRow()
    }
    .padding($r('app.float.card_padding'))
    .borderRadius($r('app.float.card_radius'))
    .backgroundColor($r('app.color.card_background'))
    .width('100%')
  }

  /** 导航入口行（Spec 035）：彩块图标 + 标签 + 计数（行容器由 navRowsSection 提供） */
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
    }
    .width('100%')
    .padding({ left: 10, right: 10, top: 6, bottom: 6 })
    .onClick(onClick)
  }

  /** 三导航入口组（Spec 035）：单卡片容器，一行一行展示 */
  @Builder
  navRowsSection() {
    Column() {
      this.navRow($r('app.media.oct_repo_16'), $r('app.color.text_secondary'), $r('app.string.profile_repositories'), this.profile?.repositoriesCount ?? 0,
        () => this.pathStack.pushPathByName('repositoriesList', `${this.profile?.user.login ?? ''}|user`))
      this.navRow($r('app.media.oct_organization_16'), $r('app.color.shortcut_orange_fg'), $r('app.string.profile_organizations'), this.profile?.organizationsCount ?? 0,
        () => this.pathStack.pushPathByName('orgList', this.profile?.user.login ?? ''))
      this.navRow($r('app.media.oct_star_16'), $r('app.color.star_gold'), $r('app.string.profile_starred'), this.profile?.starredCount ?? 0,
        () => this.pathStack.pushPathByName('starred', this.profile?.user.login ?? ''))
    }
    .padding({ top: 4, bottom: 4 })
    .borderRadius($r('app.float.card_radius'))
    .backgroundColor($r('app.color.card_background'))
    .width('100%')
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
        // 🔗 分享：系统分享能力后续 Spec（Spec 005 边界；右侧组统一 44 触点与左侧返回对称）
        Stack() {
          OctIcon({ res: $r('app.media.oct_share_android_16'), iconSize: 20, iconColor: $r('app.color.link_blue') })
        }
        .width(44)
        .height(44)
        .padding(6)
        .onClick(() => {
          promptAction.showToast({ message: $r('app.string.home_feature_coming') });
        })
        // ⚙ 设置：进入 Settings 页（Spec 014）
        Stack() {
          OctIcon({ res: $r('app.media.oct_gear_16'), iconSize: 20, iconColor: $r('app.color.link_blue') })
        }
        .width(44)
        .height(44)
        .padding(6)
        .onClick(() => {
          this.pathStack.pushPathByName('settings', this.login);
        })
        // ··· 菜单：Follow/Unfollow（自关注时隐藏，见 Spec 边界）
        if (this.profile !== null && !isSelfProfile(this.profile.viewerLogin, this.profile.user.login)) {
          Stack() {
            OctIcon({ res: $r('app.media.oct_kebab_horizontal_16'), iconSize: 20, iconColor: $r('app.color.text_primary') })
          }
          .width(44)
          .height(44)
          .padding(6)
          .bindMenu(this.followMenuItems)
        }
      }
      .width('100%')
      .height(48)
      .padding({ left: 0, right: 0 })

      PageShadowBar({ show: this.scrollShadow })

      Scroll() {
        Column({ space: 12 }) {
          if (this.profile !== null) {
            this.headerCard()

            // Pinned 横滑双列（Spec 005 官方布局）
            Row({ space: 6 }) {
              OctIcon({ res: $r('app.media.oct_pin_16'), iconSize: 16, iconColor: $r('app.color.text_primary') })
              Text($r('app.string.home_pinned_section'))
                .fontSize($r('app.float.title_font_size'))
                .fontWeight(600)
                .fontColor($r('app.color.text_primary'))
            }
            .width('100%')
            Scroll() {
              Row({ space: 8 }) {
                ForEach(this.profile.pinned, (repo: RepoSummary) => {
                  RepoCard({
                    repo: repo,
                    isPinned: true,
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

            // 三导航入口（Spec 035：单容器三行，跳独立列表页）
            this.navRowsSection()
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
      .onScroll((_x: number, y: number): void => {
        this.scrollShadow = y > 0.001;
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_page'))
  }
}
