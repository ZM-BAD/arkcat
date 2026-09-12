/**
 * User Profile 页（Spec 005 + Spec 034/035 改造）：头像/bio/元信息 + Pinned + 两段可点计数行 + 三导航入口。
 * 头卡组件化于 ProfileHeaderCard、导航入口组组件化于 ProfileNavRows，本页保留状态与 Follow 逻辑。
 * Packages 无公开 API 不展示，Projects 按边界跳过；··· 菜单提供 Follow/Unfollow；
 * 贡献日历与内嵌切换按官方 App 对齐移除（Spec 035）。
 * Spec 060：本页复用为底栏 tab4 根页（当前账号，showBack=false）；他人主页仍由 userProfile 路由压栈进入。
 * 顶栏两行标题（灰小字 login + 粗体 name）：下滑头卡滚出视野后出现，本人/他人主页一致。
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
import { UserSummary } from '../models/GitHubModels';
import { resText } from '../utils/I18n';
import { shareLink, userPageUrl } from '../utils/Share';
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
  /** Spec 060：false = 作为底栏 tab4 根页（无上级页可返回，隐藏返回钮） */
  @Param showBack: boolean = true;
  /** Spec 060：重新进入 Tab / 从二级页返回的刷新泵（Index 自增，驱动静默重取） */
  @Param refreshTick: number = 0;
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
  /** 顶栏两行标题（灰小字 login + 粗体 name）：下滑超过阈值后出现，与官方一致 */
  @Local titleShown: boolean = false;
  @Local isRefreshing: boolean = false;
  /** 勋章图片 URL 列表（官方 CDN，AchievementsService 抓取） */
  @Local achievements: string[] = [];
  /** 请求代际：切号/换 login 后旧响应直接丢弃（防旧账号数据覆盖新账号） */
  private reqSeq: number = 0;

  aboutToAppear(): void {
    this.refresh();
  }

  /** 切换账号后 token 更新（@Param 单向同步）→ 先清旧身份内容再用新 token 重拉
   *  （Spec 060：tab4 是常驻根页，不先清空则切号瞬间会显示上一个账号的数据） */
  @Monitor('token')
  onTokenChanged(): void {
    this.profile = null;
    this.achievements = [];
    this.orgCount = 0;
    this.followMenuItems = [];
    this.refresh();
  }

  /** Spec 060：Tab 重新进入 / 从二级页返回的静默重取（Index 泵 refreshTick） */
  @Monitor('refreshTick')
  onRefreshTick(): void {
    this.refresh(true);
  }

  /**
   * 拉取本页数据。
   * @param silent 静默重取（重新进入 Tab / 从二级页返回）：保留当前内容与错误态、不回退到 loading，
   *               失败也不接管页面；首次加载、下拉刷新与重试走非静默分支。
   */
  private refresh(silent: boolean = false): void {
    if (this.login === '') {
      return;
    }
    this.reqSeq += 1;
    const seq: number = this.reqSeq;
    if (!silent) {
      this.loading = true;
      this.errorMsg = '';
    }
    ProfileService.fetchProfile(this.token, this.login)
      .then((profile: UserProfile) => {
        if (seq !== this.reqSeq) {
          return;
        }
        this.profile = profile;
        this.rebuildFollowMenu();
        this.loading = false;
        this.isRefreshing = false;
        // 组织计数独立拉取（review G8）
        ProfileService.fetchOrgCount(this.token, this.login)
          .then((count: number) => {
            if (seq !== this.reqSeq) {
              return;
            }
            this.orgCount = count;
          });
      })
      .catch((e: Error) => {
        if (seq !== this.reqSeq) {
          return;
        }
        this.isRefreshing = false;
        if (!silent) {
          this.errorMsg = e.message;
          this.loading = false;
        }
      });
    // 勋章无 GraphQL 字段：HTML 抓取独立于主查询，失败仅隐藏勋章行
    AchievementsService.fetch(this.login)
      .then((urls: string[]) => {
        if (seq !== this.reqSeq) {
          return;
        }
        this.achievements = urls;
      })
      .catch(() => {
        if (seq !== this.reqSeq) {
          return;
        }
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
        // followers 计数同步 ±1，按钮与数字立即随关注态变化
        const user: UserSummary = {
          login: profile.user.login,
          name: profile.user.name,
          avatarUrl: profile.user.avatarUrl,
          bio: profile.user.bio,
          followers: profile.user.followers + (following ? 1 : -1),
          following: profile.user.following
        };
        const updated: UserProfile = {
          user: user,
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
        if (this.showBack) {
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
        }
        // 两行标题：上=灰小字 login、下=粗体 name（他人主页同款；tab4 根页 showBack=false 时补左距）
        if (this.profile !== null && this.titleShown) {
          Column({ space: 0 }) {
            Text(this.profile.user.login)
              .fontSize($r('app.float.caption_font_size'))
              .fontColor($r('app.color.text_secondary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(this.profile.user.name !== '' ? this.profile.user.name : this.profile.user.login)
              .fontSize($r('app.float.title_font_size'))
              .fontWeight(600)
              .fontColor($r('app.color.text_primary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          .margin({ left: this.showBack ? 0 : 16 })
        }
        Blank()
        // 🔗 分享：系统分享面板分享本主页（Spec 061；右侧组统一 44 触点与左侧返回对称）
        Stack() {
          OctIcon({ res: $r('app.media.oct_share_android_16'), iconSize: 20, iconColor: $r('app.color.link_blue') })
        }
        .width(44)
        .height(44)
        .padding(6)
        .accessibilityDescription($r('app.string.a11y_share'))
        .focusable(true)
        .onClick(() => {
          shareLink(this.getUIContext(), userPageUrl(this.login), this.login);
        })
        // ⚙ 设置：进入 Settings 页（Spec 014）——仅本人主页显示（他人主页顶栏 = 分享 + ⋮，与官方一致）
        if (this.login !== '' && this.login === this.currentLogin) {
          Stack() {
            OctIcon({ res: $r('app.media.oct_gear_16'), iconSize: 20, iconColor: $r('app.color.link_blue') })
          }
          .width(44)
          .height(44)
          .padding(6)
          .onClick(() => {
            this.pathStack.pushPathByName('settings', this.login);
          })
        }
        // ⋮ 菜单：Follow/Unfollow——仅他人主页显示；竖三点走全库惯例（kebab-horizontal + rotate 90），头部用蓝色
        if (this.profile !== null && !isSelfProfile(this.profile.viewerLogin, this.profile.user.login)) {
          Stack() {
            OctIcon({
              res: $r('app.media.oct_kebab_horizontal_16'),
              iconSize: 18,
              iconColor: $r('app.color.link_blue')
            })
            .rotate({ angle: 90 })
          }
          .width(44)
          .height(44)
          .padding(6)
          .accessibilityDescription($r('app.string.a11y_more'))
          .focusable(true)
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
                },
                onToggleFollow: (): void => {
                  this.toggleFollow();
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
          // 阴影与两行标题同阀值：只要滚动就浮现——本账号内容常不足一屏（滚动余量仅十几 vp），深阈值会永远触发不了
          this.scrollShadow = y > 0.001;
          this.titleShown = y > 0.001;
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
