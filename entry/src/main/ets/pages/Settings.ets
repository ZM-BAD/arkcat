/**
 * Settings 页（Spec 014）：官方式分组（Notifications/General/Subscriptions/More Options）。
 * 真功能：Theme（导入 preferences 持久化）、Language（i18n 切换，重启生效）、Sign Out（清 Token）。
 * 其余分组行为入口 + 点击提示后续。
 */
import { promptAction } from '@kit.ArkUI';
import { i18n } from '@kit.LocalizationKit';
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
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
  @Local language: string = 'zh';
  /** 滚动顶部阴影（滚动中显示、回顶消失） */
  @Local scrollShadow: boolean = false;

  aboutToAppear(): void {
    this.loadSettings();
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
      this.language = pref.getSync(KEY_LANG, 'zh') as string;
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

  /** Language 选择：en/zh（真功能，冷启动生效） */
  private pickLanguage(): void {
    const ui = this.getUIContext();
    ui.getPromptAction().showActionMenu(
      {
        title: resText(ui, $r('app.string.settings_language')),
        buttons: [
          { text: resText(ui, $r('app.string.settings_language_zh')), color: $r('app.color.link_blue') },
          { text: resText(ui, $r('app.string.settings_language_en')), color: $r('app.color.link_blue') }
        ]
      },
      (err, data) => {
        if (err) {
          return;
        }
        const idx: number = data.index;
        this.language = idx === 1 ? 'en' : 'zh';
        this.saveSetting(KEY_LANG, this.language);
        try {
          i18n.System.setAppPreferredLanguage(this.language);
        } catch (e) {
        }
      });
  }

  /** Sign Out = 移除当前账号（官方语义，2026-09 调研定案）：确认后删除账号，余号自动切换 */
  private signOut(): void {
    const ui = this.getUIContext();
    ui.getPromptAction().showDialog(
      {
        title: $r('app.string.settings_sign_out_confirm'),
        message: resText(ui, $r('app.string.accounts_remove_message'), this.currentLogin),
        buttons: [
          {
            text: resText(ui, $r('app.string.settings_cancel')),
            color: $r('app.color.text_secondary')
          },
          {
            text: resText(ui, $r('app.string.settings_confirm')),
            color: $r('app.color.badge_red')
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
      Text(this.language === 'zh' ? this.stringOf($r('app.string.settings_language_zh')) : this.stringOf($r('app.string.settings_language_en')))
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
          // Spec 049a：Accounts 真入口（右侧动态显示当前 login；App Lock 行留待 049b）
          this.accountsRow()
          this.row($r('app.string.settings_app_lock'), '', () => this.comingSoon())

          this.sectionTitle($r('app.string.settings_subscriptions'))
          this.row($r('app.string.settings_copilot'), this.stringOf($r('app.string.settings_copilot_free')), () => this.comingSoon())

          this.sectionTitle($r('app.string.settings_more_options'))
          this.row($r('app.string.settings_share_feedback'), '', () => this.comingSoon())
          this.row($r('app.string.settings_get_help'), '', () => this.comingSoon())
          this.row($r('app.string.settings_terms'), '', () => this.comingSoon())
          this.row($r('app.string.settings_privacy'), '', () => this.comingSoon())
          this.row($r('app.string.settings_open_source'), '', () => this.comingSoon())
          this.row($r('app.string.settings_sign_out'), '', () => this.signOut())

          Text($r('app.string.settings_version'))
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
