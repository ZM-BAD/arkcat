/**
 * App Lock（Spec 066）：两个组件。
 * AppLockSettingsView——Settings 子页：单 Toggle「使用设备凭据解锁应用」；
 *   开启先探测设备凭据 + 弹一次系统认证确认本人，通过才落开关；关闭直接落。
 * AppLockOverlay——全屏锁定遮罩（Index 根 Stack 顶层渲染，覆盖底栏）：
 *   出现时自动拉起系统认证，取消/失败停留可重试；成功清 AppStorage 锁定态。
 * 开关/锁定状态经 AppStorage（appLockEnabled/appLockLocked）与 EntryAbility 联动，见 utils/AppLock.ets。
 */
import { promptAction } from '@kit.ArkUI';
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { OctIcon } from '../components/OctIcon';
import { PageShadowBar } from '../components/PageShadowBar';
import { resText } from '../utils/I18n';
import {
  KEY_APP_LOCK, APP_LOCK_ENABLED_KEY, APP_LOCK_LOCKED_KEY,
  probeDeviceCredential, startAppLockAuth
} from '../utils/AppLock';

const PREFS_NAME = 'arkcat_settings';

@ComponentV2
export struct AppLockSettingsView {
  @Param pathStack: NavPathStack = new NavPathStack();
  /** 开关回显：进入页面从 AppStorage 读（EntryAbility/本页写） */
  @Local lockOn: boolean = false;

  aboutToAppear(): void {
    this.lockOn = AppStorage.get<boolean>(APP_LOCK_ENABLED_KEY) === true;
  }

  /** 偏好落盘 + AppStorage 广播（Index 遮罩与 EntryAbility 置锁都读 AppStorage） */
  private persist(enabled: boolean): void {
    const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    if (ctx !== undefined) {
      try {
        const pref = preferences.getPreferencesSync(ctx, { name: PREFS_NAME });
        pref.putSync(KEY_APP_LOCK, enabled ? '1' : '0');
        pref.flushSync();
      } catch (e) {
        // 落盘失败不阻断（下次冷启动按 OFF 处理）
      }
    }
    AppStorage.setOrCreate(APP_LOCK_ENABLED_KEY, enabled);
    if (!enabled) {
      AppStorage.setOrCreate(APP_LOCK_LOCKED_KEY, false);
    }
  }

  /** 开启流程：探测凭据 → 系统认证确认本人 → 通过才落开关 */
  private enableWithAuth(): void {
    const ui = this.getUIContext();
    if (!probeDeviceCredential()) {
      promptAction.showToast({ message: resText(ui, $r('app.string.app_lock_no_credential')) });
      this.lockOn = false;
      return;
    }
    startAppLockAuth(resText(ui, $r('app.string.app_lock_auth_title')), (ok: boolean) => {
      this.lockOn = ok;
      this.persist(ok);
    });
  }

  build() {
    Column() {
      // 自绘 App Bar：返回 + 大标题（同 064 模式）
      Row({ space: 8 }) {
        Stack() {
          OctIcon({ res: $r('app.media.oct_arrow_left_24'), iconSize: 20, iconColor: $r('app.color.text_primary') })
        }
        .width(44)
        .height(44)
        .accessibilityDescription($r('app.string.a11y_back'))
        .focusable(true)
        .onClick(() => {
          this.pathStack.pop();
        })
        Text($r('app.string.settings_app_lock'))
          .fontSize($r('app.float.title_font_size'))
          .fontWeight(700)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
          .maxLines(1)
        Row().width(44)
      }
      .width('100%')
      .height(56)

      PageShadowBar({ show: false })

      Column() {
        Row() {
          Text($r('app.string.app_lock_toggle'))
            .fontSize($r('app.float.body_font_size'))
            .fontColor($r('app.color.text_primary'))
            .layoutWeight(1)
            .margin({ right: 12 })
          Toggle({ type: ToggleType.Switch, isOn: this.lockOn })
            .selectedColor($r('app.color.link_blue'))
            .onChange((isOn: boolean) => {
              if (isOn) {
                // 先留在 OFF，认证通过后才落开关（enableWithAuth 内回调置位）
                this.enableWithAuth();
              } else {
                this.lockOn = false;
                this.persist(false);
              }
            })
        }
        .width('100%')
        .padding(16)
        .backgroundColor($r('app.color.card_background'))
        .borderRadius(12)
      }
      .padding({ left: 16, right: 16 })
      .width('100%')
      .margin({ top: 12 })
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('app.color.bg_page'))
  }
}

@ComponentV2
export struct AppLockOverlay {
  /** 防抖：认证进行中不重复拉起（连点/重复 aboutToAppear） */
  @Local authenticating: boolean = false;

  aboutToAppear(): void {
    this.authenticate();
  }

  private authenticate(): void {
    if (this.authenticating) {
      return;
    }
    this.authenticating = true;
    const title = resText(this.getUIContext(), $r('app.string.app_lock_auth_title'));
    startAppLockAuth(title, (ok: boolean) => {
      this.authenticating = false;
      if (ok) {
        AppStorage.setOrCreate(APP_LOCK_LOCKED_KEY, false);
      }
    });
  }

  build() {
    // 全屏遮罩：盖住 Navigation 与底栏（Index 根 Stack 顶层）；拦截触摸
    Column({ space: 20 }) {
      Image($r('app.media.foreground'))
        .width(120)
        .height(120)
      Text($r('app.string.app_lock_locked_title'))
        .fontSize($r('app.float.title_font_size'))
        .fontWeight(600)
        .fontColor($r('app.color.text_primary'))
      Button($r('app.string.app_lock_unlock'))
        .type(ButtonType.Normal)
        .width(160)
        .height(44)
        .fontSize($r('app.float.body_font_size'))
        .fontColor($r('app.color.link_blue'))
        // Button 默认背景是蓝色强调色，不显式透明会变成蓝底蓝字（实测踩坑，同 Home outlineButton）
        .backgroundColor(Color.Transparent)
        .borderRadius($r('app.float.button_radius'))
        .border({ width: 1, color: $r('app.color.border') })
        .onClick(() => this.authenticate())
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_page'))
  }
}
