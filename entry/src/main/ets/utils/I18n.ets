/**
 * i18n 资源工具（Spec 012）：资源 → 当前语言文案。
 *
 * getContext() 自 API 18 废弃，统一经 getUIContext().getHostContext() 取 ResourceManager；
 * hostContext 缺失或取文案异常时回退空串（极端场景不崩溃）。
 */
import { UIContext } from '@kit.ArkUI';

export function resText(ui: UIContext, res: Resource, ...args: Array<string | number>): string {
  const ctx = ui.getHostContext();
  if (ctx === undefined) {
    return '';
  }
  try {
    // $r(name, p1…) 的实参存于 res.params：getStringSync 必须透传才会做 %1$s/%1$d 替换
    const params = res.params !== undefined && res.params.length > 0
      ? res.params as Array<string | number> : args;
    return ctx.resourceManager.getStringSync(res.id, ...params);
  } catch (e) {
    return '';
  }
}
