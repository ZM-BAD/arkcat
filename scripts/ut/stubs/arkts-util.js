// 宿主 UT 桩：@kit.ArkTS（CodeSearchService 级联依赖；util 成员按需最小形状）
export const util = {
  Base64Helper: class {},
  TextDecoder: { create: () => ({ decodeToString: () => '' }) }
};
