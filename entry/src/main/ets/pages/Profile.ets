/**
 * User Profile 页（Spec 005 + Spec 034/035 改造）：头像/bio/元信息 + Pinned + 两段可点计数行 + 三导航入口。
 * 头卡组件化于 ProfileHeaderCard、导航入口组组件化于 ProfileNavRows，本页保留状态与 Follow 逻辑。
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
import { ProfileHeaderCard } from '../components/ProfileHeaderCard';
import { ProfileNavRows } from '../components/ProfileNavRows';
import { RepoSummary } from '../models/GitHubModels';
import { resText } from '../utils/I18n';
import { AccountInfo } from '../services/AccountStore';

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
  /** Spec 049a：账号列表与切换回调（长按头像快捷切换器） */
  @Param accounts: AccountInfo[] = [];
  @Param currentLogin: string = '';
  @Event onSwitchAccount: (login: string) => void = (login: string) => {};
  @Event onAddAccount: () => void = (): void => {};
  @Local profile: UserProfile | null = null;
  /** ··· 菜单项：bindMenu 数组不随状态刷新（V2 坑），viewerIsFollowing 变化后显式重建（review D6） */
  @Local followMenuItems: FollowMenuEntry[] = [];
  /** 组织计数独立降级查询结果（review G8），不随主查询失败拖垮 */
  @Local orgCount: number = 0;
  @Local loading: boolean = true;
  @Local errorMsg: string = '';
  /** 滚动顶部阴影（滚动中显示、回顶消失） */
  @Local scrollShadow: boolean = false;
  @Local isRefreshing: boolean = false;
  /** 勋章图片 URL 列表（官方 CDN，AchievementsService 抓取） */
  @Local achievements: string[] = [];

  aboutToAppear(): void {
    this.refresh();
  }

  /** 切换账号后 token 更新（@Param 单向同步）→ 用新 token 重拉本页数据 */
  @Monitor('token')
  onTokenChanged(): void {
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
        this.isRefreshing = false;
        // 组织计数独立拉取（review G8）
        ProfileService.fetchOrgCount(this.token, this.login)
          .then((count: number) => {
            this.orgCount = count;
          });
      })
      .catch((e: Error) => {
        this.errorMsg = e.message;
        this.loading = false;
        this.isRefreshing = false;
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

      Refresh({ refreshing: $$this.isRefreshing }) {
        Scroll() {
          Column({ space: 12 }) {
            if (this.profile !== null) {
              ProfileHeaderCard({
                profile: this.profile,
                achievements: this.achievements,
                login: this.login,
                pathStack: this.pathStack,
                accounts: this.accounts,
                currentLogin: this.currentLogin,
                onSwitchAccount: (login: string): void => {
                  this.onSwitchAccount(login);
                },
                onAddAccount: (): void => {
                  this.onAddAccount();
                }
              })

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
              ProfileNavRows({
                login: this.profile.user.login,
                repositoriesCount: this.profile.repositoriesCount,
                orgCount: this.orgCount,
                starredCount: this.profile.starredCount,
                pathStack: this.pathStack
              })
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
        .scrollBar(BarState.Off)
        .align(Alignment.Top)
        .onScroll((_x: number, y: number): void => {
          this.scrollShadow = y > 0.001;
        })
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
