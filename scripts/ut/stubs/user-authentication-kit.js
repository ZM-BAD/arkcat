// 宿主 UT 桩：@kit.UserAuthenticationKit（utils/AppLock 仅在被测纯函数之外引用其 API）
export const userAuth = {
  UserAuthType: { PIN: 1, FACE: 2, FINGERPRINT: 4 },
  AuthTrustLevel: { ATL1: 10000, ATL2: 20000, ATL3: 30000, ATL4: 40000 },
  UserAuthResultCode: { SUCCESS: 12500000, FAIL: 12500001, CANCELED: 12500002, TIMEOUT: 12500003 },
  getAvailableStatus() {
    throw new Error('stub: not available in host tests');
  },
  getUserAuthInstance() {
    throw new Error('stub: not available in host tests');
  }
};
