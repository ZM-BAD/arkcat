// 宿主 UT 桩：@kit.ArkData（点号包名，esbuild 无法解析 → onResolve 插件映射到本目录）
export const preferences = {
  getPreferences: () => Promise.resolve({}),
  getPreferencesSync: () => ({ getSync: () => null })
};
export const uniformTypeDescriptor = { UniformDataType: { HYPERLINK: 'ohos.arkui.hyperlink' } };
