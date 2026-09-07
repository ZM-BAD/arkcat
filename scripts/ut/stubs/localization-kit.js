// 宿主 UT 桩：@kit.LocalizationKit（点号包名，esbuild 无法解析 → onResolve 插件映射到本目录）
export const intl = { formatByLocale: () => '' };
export const i18n = { System: { setAppPreferredLanguage: (lang) => {} } };
