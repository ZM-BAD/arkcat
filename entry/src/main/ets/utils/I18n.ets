/**
 * i18n 资源工具（Spec 012）：资源 → 当前语言文案。
 *
 * getContext() 自 API 18 废弃，统一经 getUIContext().getHostContext() 取 ResourceManager；
 * hostContext 缺失时回退空串（极端场景不崩溃）。
 */
import { UIContext } from '@kit.ArkUI';

export function resText(ui: UIContext, res: Resource, ...args: Array<string | number>): string {
  const ctx = ui.getHostContext();
  if (ctx === undefined) {
    return '';
  }
  return ctx.resourceManager.getStringSync(res.id, ...args);
}
