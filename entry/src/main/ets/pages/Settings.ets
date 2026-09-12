/**
 * Settings 页（Spec 014）：官方式分组（Notifications/General/Subscriptions/More Options）。
 * 真功能：Theme（导入 preferences 持久化）、Language（i18n 切换，重启生效）、Sign Out（清 Token）。
 * 其余分组行为入口 + 点击提示后续。
 */
import { promptAction } from '@kit.ArkUI';
import { i18n } from '@kit.LocalizationKit';
import { preferences } from '@kit.ArkData';
import { common, bundleManager } from '@kit.AbilityKit';
import { AccountStore } from '../services/AccountStore';
import { OctIcon } from '../components/OctIcon';
import { PageShadowBar } from '../components/PageShadowBar';
import { resText } from '../utils/I18n';
import { applyThemeMode } from '../utils/ThemeMode';

const PREFS_NAME = 'arkcat_settings';
const KEY_THEME = 'theme_mode';
const KEY_LANG = 'app_language';

@ComponentV2
export struct SettingsView {
  @Param pathStack: NavPathStack = new NavPathStack();
  /** Spec 049a：当前账号 login（Accounts 行右侧显示；Sign Out 移除的对象） */
  @Param currentLogin: string = '';
  /** 退出登录成功：通知 Index 清 token 状态并切回登录页 */
  @Event onSignedOut: () => void = (): void => {};
  @Local themeMode: string = 'system';
  /** 语言三态：system=跟随系统（默认，未持久化时 App 按系统语言回退）/ zh / en */
  @Local language: string = 'system';
  /** 滚动顶部阴影（滚动中显示、回顶消失） */
  @Local scrollShadow: boolean = false;
  /** 版本号：运行时读 bundle 清单的 versionName，避免与 AppScope/app.json5 手工同步（review 2026-09-10） */
  @Local versionText: ResourceStr = $r('app.string.settings_version');

  aboutToAppear(): void {
    this.loadSettings();
    this.loadVersion();
  }

  /** 版本号取自 bundle 清单；取不到时保留静态回退串 */
  private loadVersion(): void {
    try {
      const info = bundleManager.getBundleInfoForSelfSync(bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT);
      this.versionText = `ArkCat v${info.versionName}`;
    } catch (e) {
      // 保持回退串
    }
  }

  private loadSettings(): void {
    const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    if (ctx === undefined) {
      return;
    }
    try {
      // 同步读取：避免异步未返回时页面停在初始默认值（语言/主题行显示错误）
      const pref = preferences.getPreferencesSync(ctx, { name: PREFS_NAME });
      this.themeMode = pref.getSync(KEY_THEME, 'system') as string;
      this.language = pref.getSync(KEY_LANG, 'system') as string;
    } catch (e) {
      // 读取失败保持默认
    }
  }

  private saveSetting(key: string, value: string): void {
    const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    if (ctx === undefined) {
      return;
    }
    preferences.getPreferences(ctx, PREFS_NAME)
      .then((pref: preferences.Preferences) => {
        pref.putSync(key, value);
        pref.flushSync();
      })
      .catch(() => {
      });
  }

  /** 当前主题的本地化显示文案（Spec 026） */
  private themeLabel(): string {
    if (this.themeMode === 'dark') {
      return this.stringOf($r('app.string.settings_theme_dark'));
    }
    if (this.themeMode === 'light') {
      return this.stringOf($r('app.string.settings_theme_light'));
    }
    return this.stringOf($r('app.string.settings_theme_follow_system'));
  }

  /** Theme 选择：system/light/dark（真功能，持久化） */
  private pickTheme(): void {
    const ui = this.getUIContext();
    ui.getPromptAction().showActionMenu(
      {
        title: resText(ui, $r('app.string.settings_theme')),
        buttons: [
          { text: resText(ui, $r('app.string.settings_theme_follow_system')), color: $r('app.color.link_blue') },
          { text: resText(ui, $r('app.string.settings_theme_light')), color: $r('app.color.link_blue') },
          { text: resText(ui, $r('app.string.settings_theme_dark')), color: $r('app.color.link_blue') }
        ]
      },
      (err, data) => {
        if (err) {
          return;
        }
        const idx: number = data.index;
        this.themeMode = idx === 1 ? 'light' : idx === 2 ? 'dark' : 'system';
        this.saveSetting(KEY_THEME, this.themeMode);
        applyThemeMode(this.getUIContext().getHostContext() as common.UIAbilityContext | undefined, this.themeMode);
      });
  }

  /** 当前语言的本地化显示文案（跟随系统/中文/英文，未设置时=跟随系统） */
  private languageLabel(): string {
    if (this.language === 'zh') {
      return this.stringOf($r('app.string.settings_language_zh'));
    }
    if (this.language === 'en') {
      return this.stringOf($r('app.string.settings_language_en'));
    }
    return this.stringOf($r('app.string.settings_language_follow_system'));
  }

  /** Language 选择：system/zh/en（真功能，均即时生效；system=系统语言快照，下次冷启动回归真·跟随系统） */
  private pickLanguage(): void {
    const ui = this.getUIContext();
    ui.getPromptAction().showActionMenu(
      {
        title: resText(ui, $r('app.string.settings_language')),
        buttons: [
          { text: resText(ui, $r('app.string.settings_language_follow_system')), color: $r('app.color.link_blue') },
          { text: resText(ui, $r('app.string.settings_language_zh')), color: $r('app.color.link_blue') },
          { text: resText(ui, $r('app.string.settings_language_en')), color: $r('app.color.link_blue') }
        ]
      },
      (err, data) => {
        if (err) {
          return;
        }
        const idx: number = data.index;
        this.language = idx === 1 ? 'zh' : idx === 2 ? 'en' : 'system';
        this.saveSetting(KEY_LANG, this.language);
        try {
          if (this.language !== 'system') {
            i18n.System.setAppPreferredLanguage(this.language);
          } else {
            // 跟随系统：官方无「即时清除覆盖」路径（'default' 须冷启动生效，API 26 d.ts 定案），
            // 改设系统语言快照实现即时切换；冷启动不设覆盖仍为真·跟随系统（EntryAbility 兜底）
            i18n.System.setAppPreferredLanguage(i18n.System.getSystemLanguage());
          }
        } catch (e) {
        }
      });
  }

  /** Sign Out = 移除当前账号（官方弹窗样式，2026-09-12 定案）：仅标题 Sign Out + CANCEL/SIGN OUT 两蓝钮，无正文 */
  private signOut(): void {
    const ui = this.getUIContext();
    ui.getPromptAction().showDialog(
      {
        title: $r('app.string.settings_sign_out'),
        buttons: [
          {
            text: resText(ui, $r('app.string.settings_sign_out_cancel')),
            color: $r('app.color.link_blue')
          },
          {
            text: resText(ui, $r('app.string.settings_sign_out_action')),
            color: $r('app.color.link_blue')
          }
        ]
      },
      (err, data) => {
        if (err) {
          return;
        }
        if (data.index === 1) {
          const ctx = this.getUIContext().getHostContext() as common.Context | undefined;
          AccountStore.removeAccount(ctx, this.currentLogin)
            .then(() => {
              this.onSignedOut();
            })
            .catch(() => {
            });
        }
      });
  }

  /** Accounts 行：右侧显示当前账号 login（动态值，仿 themeRow 内联——row() 的参数不随状态刷新） */
  @Builder
  accountsRow() {
    Row() {
      Text($r('app.string.settings_accounts'))
        .fontSize($r('app.float.body_font_size'))
        .fontColor($r('app.color.text_primary'))
      Blank()
      Text(this.currentLogin)
        .fontSize($r('app.float.body_font_size'))
        .fontColor($r('app.color.text_secondary'))
      OctIcon({ res: $r('app.media.oct_chevron_right_16'), iconSize: 14, iconColor: $r('app.color.text_secondary') })
        .margin({ left: 6 })
    }
    .width('100%')
    .height(46)
    .padding({ left: 16, right: 16 })
    .backgroundColor($r('app.color.card_background'))
    .borderRadius(12)
    .margin({ bottom: 2 })
    .onClick(() => {
      this.pathStack.pushPathByName('accounts', '');
    })
  }

  private comingSoon(): void {
    promptAction.showToast({ message: $r('app.string.settings_feature_coming') });
  }

  /** 资源 → 当前语言纯文案 */
  private stringOf(res: Resource): string {
    return resText(this.getUIContext(), res);
  }

  /** 分组标题（灰底浅色） */
  @Builder
  sectionTitle(labelRes: Resource) {
    Text(labelRes)
      .fontSize($r('app.float.caption_font_size'))
      .fontColor($r('app.color.text_secondary'))
      .width('100%')
      .padding({ left: 4, bottom: 4 })
      .margin({ top: 12 })
  }

  /** 行：左文案 + 可选右侧值 */
  @Builder
  row(labelRes: Resource, value: string, onClick: () => void) {
    Row() {
      Text(labelRes)
        .fontSize($r('app.float.body_font_size'))
        .fontColor($r('app.color.text_primary'))
      Blank()
      if (value !== '') {
        Text(value)
          .fontSize($r('app.float.body_font_size'))
          .fontColor($r('app.color.text_secondary'))
      }
      OctIcon({ res: $r('app.media.oct_chevron_right_16'), iconSize: 14, iconColor: $r('app.color.text_secondary') })
        .margin({ left: 6 })
    }
    .width('100%')
    .height(46)
    .padding({ left: 16, right: 16 })
    .backgroundColor($r('app.color.card_background'))
    .borderRadius(12)
    .margin({ bottom: 2 })
    .onClick(onClick)
  }

  /** Theme 行：右侧值直读 this（@Builder 传值参数不随状态刷新，动态值须内联渲染） */
  @Builder
  themeRow() {
    Row() {
      Text($r('app.string.settings_theme'))
        .fontSize($r('app.float.body_font_size'))
        .fontColor($r('app.color.text_primary'))
      Blank()
      Text(this.themeLabel())
        .fontSize($r('app.float.body_font_size'))
        .fontColor($r('app.color.text_secondary'))
      OctIcon({ res: $r('app.media.oct_chevron_right_16'), iconSize: 14, iconColor: $r('app.color.text_secondary') })
        .margin({ left: 6 })
    }
    .width('100%')
    .height(46)
    .padding({ left: 16, right: 16 })
    .backgroundColor($r('app.color.card_background'))
    .borderRadius(12)
    .margin({ bottom: 2 })
    .onClick((): void => this.pickTheme())
  }

  /** Language 行：右侧值直读 this（同上，切换后行文本即时刷新） */
  @Builder
  langRow() {
    Row() {
      Text($r('app.string.settings_language'))
        .fontSize($r('app.float.body_font_size'))
        .fontColor($r('app.color.text_primary'))
      Blank()
      Text(this.languageLabel())
        .fontSize($r('app.float.body_font_size'))
        .fontColor($r('app.color.text_secondary'))
      OctIcon({ res: $r('app.media.oct_chevron_right_16'), iconSize: 14, iconColor: $r('app.color.text_secondary') })
        .margin({ left: 6 })
    }
    .width('100%')
    .height(46)
    .padding({ left: 16, right: 16 })
    .backgroundColor($r('app.color.card_background'))
    .borderRadius(12)
    .margin({ bottom: 2 })
    .onClick((): void => this.pickLanguage())
  }

  build() {
    Column() {
      Row({ space: 8 }) {
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
        Text($r('app.string.profile_settings'))
          .fontSize($r('app.float.title_font_size'))
          .fontWeight(600)
          .fontColor($r('app.color.text_primary'))
        Blank()
      }
      .width('100%')
      .height(48)
      .padding({ left: 0, right: 0 })

      PageShadowBar({ show: this.scrollShadow })

      Scroll() {
        Column() {
          this.sectionTitle($r('app.string.settings_notifications'))
          this.row($r('app.string.settings_notification_options'), '', () => this.pathStack.pushPathByName('notificationSettings', ''))

          this.sectionTitle($r('app.string.settings_general'))
          this.themeRow()
          this.row($r('app.string.settings_code_options'), '', () => this.pathStack.pushPathByName('codeOptions', ''))
          this.langRow()
          // Spec 049a：Accounts 真入口（右侧动态显示当前 login）；App Lock 子页见 Spec 066
          this.accountsRow()
          this.row($r('app.string.settings_app_lock'), '', () => this.pathStack.pushPathByName('appLock', ''))

          this.sectionTitle($r('app.string.settings_more_options'))
          this.row($r('app.string.settings_share_feedback'), '', () => this.pathStack.pushPathByName('repoDiscussions', 'ZM-BAD/arkcat'))
          this.row($r('app.string.settings_terms'), '', () => this.pathStack.pushPathByName('inAppBrowser', 'Terms of Service|https://docs.github.com/en/site-policy/github-terms/github-terms-of-service'))
          // Privacy：无自建后端/无数据收集，官方页的 Optional Activity Data Tracking 不做（假 UI + 合规冲突），
          // 仅保留隐私政策链接——应用内浏览器打开 GitHub 官方 General Privacy Statement（同 Terms 行管道）
          // Get Help 行已移除（2026-09-12 用户拍板）：官方该行=向 GitHub Support 提工单的应用内表单，
          // 第三方无合法提交管道且语义错位（App 自身问题应走仓库 Discussions），偏离理由记 spec 014 §七
          this.row($r('app.string.settings_privacy'), '', () => this.pathStack.pushPathByName('inAppBrowser', 'Privacy Policy|https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement'))
          this.row($r('app.string.settings_open_source'), '', () => this.pathStack.pushPathByName('openSourceLibraries', ''))
          this.row($r('app.string.settings_sign_out'), '', () => this.signOut())

          Text(this.versionText)
            .fontSize($r('app.float.caption_font_size'))
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
            .textAlign(TextAlign.Center)
            .margin({ top: 24, bottom: 24 })
        }
        .padding({ left: 16, right: 16 })
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
