import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { preferences } from '@kit.ArkData';
import { i18n } from '@kit.LocalizationKit';
import { KEY_APP_LOCK, APP_LOCK_ENABLED_KEY, APP_LOCK_LOCKED_KEY, normalizeAppLockPref } from '../utils/AppLock';

const TAG = '[ArkCat]';
const DOMAIN = 0xFF00;
const PREFS_NAME = 'arkcat_settings';
const KEY_LANG = 'app_language';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, TAG, 'onCreate');
    // Spec 066：App Lock 开关进 AppStorage（Index 遮罩经 @StorageLink 渲染锁定态；
    // 开着则启动即锁定）。同步读避免晚于 loadContent 首帧闪切
    try {
      const pref = preferences.getPreferencesSync(this.context, { name: 'arkcat_settings' });
      const enabled = normalizeAppLockPref(pref.getSync(KEY_APP_LOCK, '') as string);
      AppStorage.setOrCreate(APP_LOCK_ENABLED_KEY, enabled);
      AppStorage.setOrCreate(APP_LOCK_LOCKED_KEY, enabled);
    } catch (e) {
      AppStorage.setOrCreate(APP_LOCK_ENABLED_KEY, false);
      AppStorage.setOrCreate(APP_LOCK_LOCKED_KEY, false);
    }
    // 恢复 App 内语言选择（Spec 012：仅当用户在 Settings 显式设置过才应用，
    // 'system'=跟随系统不应用，未设置跟随系统语言非中文回退 base；同步读取避免晚于 loadContent 首帧闪切）
    try {
      const pref = preferences.getPreferencesSync(this.context, { name: PREFS_NAME });
      const lang = pref.getSync(KEY_LANG, '') as string;
      if (lang !== '' && lang !== 'system') {
        i18n.System.setAppPreferredLanguage(lang);
      }
    } catch (e) {
      // 读取失败按系统默认
    }
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, 'onDestroy');
  }

  onBackground(): void {
    hilog.info(DOMAIN, TAG, 'onBackground');
    // Spec 066：开着 App Lock 时退后台即置锁，回前台由 Index 锁定遮罩接住并弹系统认证
    if (AppStorage.get<boolean>(APP_LOCK_ENABLED_KEY) === true) {
      AppStorage.setOrCreate(APP_LOCK_LOCKED_KEY, true);
    }
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, TAG, 'onWindowStageCreate');
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, 'Failed to load content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, TAG, 'Succeeded in loading content.');
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, TAG, 'onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, TAG, 'onForeground');
  }
}
