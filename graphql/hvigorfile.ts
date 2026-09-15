// @ts-nocheck – the plugin is injected by the hvigor toolchain at build time
import { harTasks } from '@ohos/hvigor-ohos-plugin';

export default {
  system: harTasks /* Built-in plugin of Hvigor. It cannot be modified. */,
  plugins: [] /* Custom plugin to extend the functionality of Hvigor. */,
};
