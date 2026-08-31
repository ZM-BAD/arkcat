// @ts-nocheck – the plugin is injected by the hvigor toolchain at build time
import { hapTasks } from '@ohos/hvigor-ohos-plugin';

export default {
  system: hapTasks /* Built-in plugin of Hvigor. It cannot be modified. */,
  plugins: [] /* Custom plugin to extend the functionality of Hvigor. */,
};
