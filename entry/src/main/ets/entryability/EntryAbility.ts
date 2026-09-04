import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { preferences } from '@kit.ArkData';
import { i18n } from '@kit.LocalizationKit';

const TAG = '[StarRaft]';
const DOMAIN = 0xFF00;
const PREFS_NAME = 'starraft_settings';
const KEY_LANG = 'app_language';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, TAG, 'onCreate');
    // 恢复 App 内语言选择（Settings 切换后重启生效；无恢复逻辑会回落到系统默认）
    try {
      preferences.getPreferences(this.context, PREFS_NAME)
        .then((pref: preferences.Preferences) => {
          const lang = pref.getSync(KEY_LANG, 'zh') as string;
          i18n.System.setAppPreferredLanguage(lang);
        })
        .catch(() => {
        });
    } catch (e) {
      // 读取失败按系统默认
    }
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, 'onDestroy');
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

  onBackground(): void {
    hilog.info(DOMAIN, TAG, 'onBackground');
  }
}
