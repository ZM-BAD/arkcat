/**
 * 主题模式工具（Spec 026）：三态（跟随系统/浅色/深色）应用与持久化。
 * setColorMode 作用于全局（resources dark 覆盖按 colorMode 自动解析）。
 */
import { common, ConfigurationConstant } from '@kit.AbilityKit';

/** mode: 'system' | 'light' | 'dark' → ApplicationContext.setColorMode */
export function applyThemeMode(ctx: common.UIAbilityContext | undefined, mode: string): void {
  if (ctx === undefined) {
    return;
  }
  if (mode === 'dark') {
    ctx.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
  } else if (mode === 'light') {
    ctx.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
  } else {
    ctx.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
  }
}
