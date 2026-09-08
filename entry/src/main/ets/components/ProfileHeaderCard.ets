/**
 * Profile 头卡（Spec 005 + Spec 034/035）：头像/名称/账号 + 状态行 + bio + 元信息行 + 开发者徽章
 * + followers/following 可点计数 + 勋章行。纯展示组件，跳转经 pathStack 直接执行。
 */
import { promptAction } from '@kit.ArkUI';
import { UserProfile, isSelfProfile } from '../models/ProfileModels';
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
  @Local switcherOpen: boolean = false;

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
          .fontSize(16)
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
      showClose: false,
      backgroundColor: $r('app.color.bg_page'),
      dragBar: false,
      onDisappear: () => {
        this.switcherOpen = false;
      }
    })
  }
}
