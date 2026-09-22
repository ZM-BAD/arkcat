/**
 * Profile 头卡（Spec 005 + Spec 034/035 + Spec 076）：头像/名称/账号 + 状态行 + bio + 元信息行
 * + 开发者徽章 + followers/following 可点计数 + 勋章行。纯展示组件，跳转经 pathStack 直接执行。
 */
import { common } from '@kit.AbilityKit';
import { UserProfile, isSelfProfile, statusVisible } from '../models/ProfileModels';
import { OctIcon } from './OctIcon';
import { resText } from '../utils/I18n';
import { AccountInfo } from '../services/AccountStore';

@ComponentV2
export struct ProfileHeaderCard {
  @Param profile: UserProfile | null = null;
  /** 勋章图片 URL 列表（官方 CDN，AchievementsService 抓取） */
  @Param achievements: string[] = [];
  @Param login: string = '';
  @Param pathStack: NavPathStack = new NavPathStack();
  /** Spec 049a：长按头像切换器（官方 Profile tab 长按等价，位置=头像） */
  @Param accounts: AccountInfo[] = [];
  @Param currentLogin: string = '';
  @Event onSwitchAccount: (login: string) => void = (login: string) => {};
  @Event onAddAccount: () => void = (): void => {};
  /** Follow 按钮点击（切换关注态；请求与 toast 在 Profile 页处理） */
  @Event onToggleFollow: () => void = (): void => {};
  /** 状态铅笔点击（Spec 076）：打开 Edit status 弹层（弹层挂在 Profile 页上） */
  @Event onEditStatus: () => void = (): void => {};
  @Local switcherOpen: boolean = false;

  /** 拉起系统浏览器/邮件应用（MarkdownView.openExternal 同款 viewData want；mailto: 由系统分发给邮件应用） */
  private openExternal(uri: string): void {
    const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    if (ctx === undefined) {
      return;
    }
    ctx.startAbility({
      action: 'ohos.want.action.viewData',
      entities: ['entity.system.browsable'],
      uri: uri
    }).catch(() => {
      // 无应用接住（如模拟器无邮件应用）时静默，不打断浏览
    });
  }

  /** 网站链接补全协议（GitHub 资料允许只填 example.com） */
  private websiteUri(): string {
    const raw = this.profile?.websiteUrl ?? '';
    return raw !== '' && !raw.startsWith('http://') && !raw.startsWith('https://') ? `https://${raw}` : raw;
  }

  /** 信息行：icon 固定在 16×16 容器保证跨行对齐；bold 时内容加粗；uri 非空时整行可点（拉起系统应用） */
  @Builder
  metaRow(iconRes: Resource, text: string, bold: boolean = false, uri: string = '') {
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
      .onClick(() => {
        if (uri !== '') {
          this.openExternal(uri);
        }
      })
    }
  }

  // 状态取值走私有方法：@Builder 内不做可空收窄（V2 闭包收窄会丢，坑 44）

  /** 是否有可展示状态（Spec 076）：文案或 emoji 任一存在，emoji-only 状态同样展示 */
  private hasStatus(): boolean {
    return this.profile !== null && statusVisible(this.profile.status);
  }

  /** 状态 emoji 的文本字形（无则空串） */
  private statusGlyph(): string {
    return this.profile !== null && this.profile.status !== null ? this.profile.status.emoji.text : '';
  }

  /** 状态 emoji 的图片地址（自定义 emoji，无则空串） */
  private statusImage(): string {
    return this.profile !== null && this.profile.status !== null ? this.profile.status.emoji.image : '';
  }

  /** 状态文案（无则空串） */
  private statusMessage(): string {
    return this.profile !== null && this.profile.status !== null ? this.profile.status.message : '';
  }

  /** 状态是否为 Busy（GraphQL indicatesLimitedAvailability）：黄底 amber 文案（Spec 076 §二-A） */
  private statusBusy(): boolean {
    return this.profile !== null && this.profile.status !== null && this.profile.status.busy;
  }

  /** 本人主页（决定状态行是否带编辑入口） */
  private isSelf(): boolean {
    return this.profile !== null && isSelfProfile(this.profile.viewerLogin, this.profile.user.login);
  }

  /** 状态行（Spec 076）：emoji 字形/自定义图 + 文案 + 最右铅笔；灰底圆角矩形。
   *  本人主页无状态时仍渲染（显示引导语）——编辑器入口只此一处，整行不渲染会让功能不可达（§七）。 */
  @Builder
  statusRow() {
    if (this.hasStatus() || this.isSelf()) {
      Row({ space: 6 }) {
        if (this.hasStatus()) {
          if (this.statusGlyph() !== '') {
            Text(this.statusGlyph())
              .fontSize($r('app.float.sub_text_font_size'))
              .maxLines(1)
          } else if (this.statusImage() !== '') {
            // 非 Unicode 的 GitHub 自定义 emoji（:shipit: 等）无字形可画，走官方 CDN 图
            Image(this.statusImage())
              .width(18)
              .height(18)
          }
          if (this.statusMessage() !== '') {
            Text(this.statusMessage())
              .fontSize($r('app.float.sub_text_font_size'))
              .fontColor(this.statusBusy() ? $r('app.color.warning_text') : $r('app.color.text_primary'))
              .maxLines(1)
          }
        } else {
          // 无状态：smiley 字形占 emoji 位（官方口径，2026-09-22 走查用户指出）
          Stack() {
            OctIcon({ res: $r('app.media.oct_smiley_16'), iconSize: 16, iconColor: $r('app.color.text_secondary') })
          }
          .width(16)
          .height(16)
          Text($r('app.string.status_set_prompt'))
            .fontSize($r('app.float.sub_text_font_size'))
            .fontColor($r('app.color.text_secondary'))
            .maxLines(1)
        }
        Blank()
        if (this.isSelf()) {
          OctIcon({
            res: $r('app.media.oct_pencil_16'),
            iconSize: 16,
            iconColor: this.statusBusy() ? $r('app.color.warning_text') : $r('app.color.text_primary')
          })
            .padding(4)
            .responseRegion({ x: -10, y: -10, width: '183%', height: '183%' })
            .onClick(() => {
              this.onEditStatus();
            })
        }
      }
      .width('100%')
      .padding({ left: 12, right: 4, top: 10, bottom: 10 })
      .borderRadius(6)
      // Busy=黄底（官方 busy 态）；常态灰底。描边已按走查口径去掉（2026-09-22，无论是否 busy）
      .backgroundColor(this.statusBusy() ? $r('app.color.status_busy_bg') : $r('app.color.bg_page'))
      // 官方为「点状态即改状态」：本人主页整行可点（与铅笔同动作，重复触发无副作用）
      .onClick(() => {
        if (this.isSelf()) {
          this.onEditStatus();
        }
      })
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
        // 长按头像 = 账号切换器（官方 Profile tab 长按等价，位置自定义为头像）
        Image(this.profile?.user.avatarUrl ?? '')
          .width(72)
          .height(72)
          .borderRadius(36)
          .backgroundColor($r('app.color.heat_empty'))
          .gesture(LongPressGesture({ repeat: false })
            .onAction(() => {
              this.switcherOpen = true;
            }))
        Column({ space: 4 }) {
          Text(this.profile?.user.name ?? '')
            .fontSize($r('app.float.title_font_size'))
            .fontWeight(600)
            .fontColor($r('app.color.text_primary'))
          Text(this.profile?.user.login ?? '')
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
        this.metaRow($r('app.media.oct_organization_16'), this.profile?.company ?? '')
        this.metaRow($r('app.media.oct_location_16'), this.profile?.location ?? '')
        this.metaRow($r('app.media.oct_link_16'), this.profile?.websiteUrl ?? '', true, this.websiteUri())
        this.metaRow($r('app.media.oct_mail_16'), this.profile?.email ?? '', true, `mailto:${this.profile?.email ?? ''}`)
        if (this.profile?.twitterUsername !== '') {
          Row({ space: 8 }) {
            Stack() {
              // X 品牌图标（Octicon 无此 logo；与 metaRow 同为 16×16 容器对齐，替换原 𝕏 文本字符——字形偏小不齐）
              OctIcon({ res: $r('app.media.x_logo_16'), iconSize: 14, iconColor: $r('app.color.text_secondary') })
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
          .onClick(() => {
            // X 主页：系统浏览器打开（资料里只存 handle，不存完整链接）
            this.openExternal(`https://x.com/${this.profile?.twitterUsername ?? ''}`);
          })
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

      // 两段可点计数行（Spec 034）：person 图标 + N followers · M following（数字加粗）。
      // 数字与单位包成同一个可点整体，间隔一个字符宽（4vp）；两组之间用 · 分隔
      Row({ space: 8 }) {
        Stack() {
          OctIcon({ res: $r('app.media.oct_person_16'), iconSize: 16, iconColor: $r('app.color.text_secondary') })
        }
        .width(16)
        .height(16)
        Row({ space: 4 }) {
          Text(`${this.profile?.user.followers ?? 0}`)
            .fontSize($r('app.float.caption_font_size'))
            .fontWeight(600)
            .fontColor($r('app.color.text_primary'))
          Text(resText(this.getUIContext(), $r('app.string.profile_followers_unit')))
            .fontSize($r('app.float.caption_font_size'))
            .fontColor($r('app.color.text_secondary'))
        }
        .onClick(() => {
          this.pathStack.pushPathByName('userList', `${this.profile?.user.login ?? ''}|followers`);
        })
        Text('·')
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_secondary'))
        Row({ space: 4 }) {
          Text(`${this.profile?.user.following ?? 0}`)
            .fontSize($r('app.float.caption_font_size'))
            .fontWeight(600)
            .fontColor($r('app.color.text_primary'))
          Text(resText(this.getUIContext(), $r('app.string.profile_following_unit')))
            .fontSize($r('app.float.caption_font_size'))
            .fontColor($r('app.color.text_secondary'))
        }
        .onClick(() => {
          this.pathStack.pushPathByName('userList', `${this.profile?.user.login ?? ''}|following`);
        })
        Blank()
      }
      .width('100%')

      this.achievementsRow()

      // Follow 按钮（仅他人主页，宽度铺满）：官方为中性灰底按钮——未关注=plus+FOLLOW；已关注=绿色 check+FOLLOWING
      if (this.profile !== null && !isSelfProfile(this.profile.viewerLogin, this.profile.user.login)) {
        Row({ space: 6 }) {
          OctIcon({
            res: this.profile.viewerIsFollowing ? $r('app.media.oct_check_16') : $r('app.media.oct_plus_16'),
            iconSize: 16,
            iconColor: this.profile.viewerIsFollowing ? $r('app.color.success_text') : $r('app.color.text_primary')
          })
          Text(this.profile.viewerIsFollowing
            ? $r('app.string.profile_following') : $r('app.string.profile_follow'))
            .fontSize($r('app.float.body_font_size'))
            .fontWeight(600)
            .textCase(TextCase.UpperCase)
            .fontColor($r('app.color.text_primary'))
        }
        .width('100%')
        .height(36)
        .justifyContent(FlexAlign.Center)
        .borderRadius($r('app.float.button_radius'))
        // 两态都有描边：未关注=白底；已关注=灰底（官方语义）
        .backgroundColor(this.profile.viewerIsFollowing ? $r('app.color.chip_bg') : $r('app.color.card_background'))
        .border({ width: 1, color: $r('app.color.border') })
        .margin({ top: 4 })
        .onClick(() => this.onToggleFollow())
      }
    }
    .padding($r('app.float.card_padding'))
    .borderRadius($r('app.float.card_radius'))
    .backgroundColor($r('app.color.card_background'))
    .width('100%')
  }

  /** 账号切换器（长按头像弹出，官方切换器交互）：账号行+当前勾+Add account */
  @Builder
  switcherSheet() {
    Column() {
      Text($r('app.string.settings_accounts'))
        .fontSize($r('app.float.body_font_size'))
        .fontWeight(600)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
        .padding({ left: 16, bottom: 8 })
        .alignSelf(ItemAlign.Start)

      ForEach(this.accounts, (acc: AccountInfo) => {
        Row({ space: 12 }) {
          Image(`https://github.com/${acc.login}.png`)
            .width(44)
            .height(44)
            .borderRadius(22)
            .backgroundColor($r('app.color.heat_empty'))
          Column({ space: 2 }) {
            Text(acc.login)
              .fontSize($r('app.float.body_font_size'))
              .fontWeight(500)
              .fontColor($r('app.color.text_primary'))
            if (acc.name !== '') {
              Text(acc.name)
                .fontSize($r('app.float.caption_font_size'))
                .fontColor($r('app.color.text_secondary'))
            }
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          if (acc.login === this.currentLogin) {
            OctIcon({ res: $r('app.media.oct_check_circle_fill_16'), iconSize: 18, iconColor: $r('app.color.link_blue') })
          }
        }
        .width('100%')
        .height(56)
        .padding({ left: 16, right: 16 })
        .onClick(() => {
          if (acc.login === this.currentLogin) {
            this.switcherOpen = false;
            return;
          }
          this.switcherOpen = false;
          this.onSwitchAccount(acc.login);
        })
      }, (acc: AccountInfo) => `${acc.login}_${acc.addedAt}`)

      Row({ space: 8 }) {
        OctIcon({ res: $r('app.media.oct_plus_24'), iconSize: 16, iconColor: $r('app.color.link_blue') })
        Text($r('app.string.accounts_add'))
          .fontSize($r('app.float.sub_text_font_size'))
          .fontWeight(500)
          .fontColor($r('app.color.link_blue'))
      }
      .width('100%')
      .height(48)
      .padding({ left: 16, right: 16 })
      .onClick(() => {
        this.switcherOpen = false;
        this.onAddAccount();
      })
    }
    .width('100%')
    .padding({ top: 12, bottom: 8 })
    .backgroundColor($r('app.color.bg_page'))
  }

  build() {
    Column() {
      this.headerCard()
    }
    .width('100%')
    // 切换器高度随账号数变化（单账号 ≈ 210，上限 5 ≈ 420）
    .bindSheet(this.switcherOpen, this.switcherSheet(), {
      height: 110 + this.accounts.length * 56,
      detents: [110 + this.accounts.length * 56, SheetSize.LARGE],
      showClose: false,
      backgroundColor: $r('app.color.bg_page'),
      dragBar: true,
      onDisappear: () => {
        this.switcherOpen = false;
      }
    })
  }
}
