// 宿主 UT 桩：@kit.AssetStoreKit（AccountStore 级联依赖；宿主环境无加密存储，仅提供最小形状）
export const asset = {
  Tag: { SECRET: 0, ALIAS: 1, RETURN_TYPE: 2 },
  ReturnType: { ALL: 0 },
  query: () => Promise.resolve([]),
  add: () => Promise.resolve(),
  remove: () => Promise.resolve()
};
