/**
 * App Lock（Spec 066）：设备凭据锁定引擎。
 * 开关状态存偏好 app_lock_enabled（'1'/'0'），经 AppStorage 全局广播：
 * EntryAbility 写（冷启动读取 + 退后台置锁），Index 根读（锁定遮罩渲染），App Lock 子页写（开关切换）。
 * 认证走 userIAM userAuth 系统弹窗：先逐类型探测可用性，仅把实际可用的凭据类型传入认证实例
 * （整组硬传会在模拟器等无生物识别设备上抛「类型不支持」导致认证起不来——编译期无法发现，实测修正）。
 */
import { userAuth } from '@kit.UserAuthenticationKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = '[ArkCat]';
const DOMAIN = 0xFF00;

/** 偏好键（arkcat_settings） */
export const KEY_APP_LOCK = 'app_lock_enabled';
/** AppStorage 键：开关状态 / 当前是否处于锁定态 */
export const APP_LOCK_ENABLED_KEY = 'appLockEnabled';
export const APP_LOCK_LOCKED_KEY = 'appLockLocked';

/** 偏好值归一化：仅 '1' 视为开启（缺省/脏值一律 OFF——宿主单测覆盖） */
export function normalizeAppLockPref(value: string | undefined | null): boolean {
  return value === '1';
}

/** 探测当前设备实际可用的凭据类型（人脸/指纹/锁屏密码；逐类型 getAvailableStatus） */
export function availableAuthTypes(): userAuth.UserAuthType[] {
  const candidates: userAuth.UserAuthType[] = [
    userAuth.UserAuthType.FACE,
    userAuth.UserAuthType.FINGERPRINT,
    userAuth.UserAuthType.PIN
  ];
  const available: userAuth.UserAuthType[] = [];
  for (const t of candidates) {
    try {
      userAuth.getAvailableStatus(t, userAuth.AuthTrustLevel.ATL1);
      available.push(t);
    } catch (e) {
      // 该类型不可用（未录入/硬件缺失），跳过
    }
  }
  return available;
}

/** 探测设备是否已录任何可用锁屏凭据（人脸/指纹/锁屏密码任一） */
export function probeDeviceCredential(): boolean {
  return availableAuthTypes().length > 0;
}

/**
 * 拉起系统认证弹窗，结果经回调返回（true=验证通过）。
 * 调用方须保证窗口已加载（Index 锁定遮罩出现后调用）；取消/失败均回调 false。
 */
export function startAppLockAuth(title: string, onResult: (ok: boolean) => void): void {
  try {
    // 只传探测可用的类型：未录入/无硬件的类型混入会让 start() 直接抛 12500005
    const types = availableAuthTypes();
    if (types.length === 0) {
      hilog.error(DOMAIN, TAG, 'AppLock auth skipped: no available credential type');
      onResult(false);
      return;
    }
    // 挑战值：16 字节随机数（防重放；我们只用认证结论不用 token，普通随机即可；
    // 空挑战会被参数校验 401 拒绝——实测踩坑）
    const challenge = new Uint8Array(16);
    for (let i = 0; i < challenge.length; i++) {
      challenge[i] = Math.floor(Math.random() * 256);
    }
    const instance = userAuth.getUserAuthInstance(
      {
        challenge: challenge,
        authType: types,
        authTrustLevel: userAuth.AuthTrustLevel.ATL1
      },
      { title }
    );
    // IAuthCallback 是带 onResult 方法的接口（不可传裸 lambda）；UserAuthResult.result ≠ SUCCESS 即未通过
    const callback: userAuth.IAuthCallback = {
      onResult: (result: userAuth.UserAuthResult): void => {
        hilog.info(DOMAIN, TAG, 'AppLock auth result: %{public}d', result.result);
        onResult(result.result === userAuth.UserAuthResultCode.SUCCESS);
      }
    };
    instance.on('result', callback);
    instance.start();
    hilog.info(DOMAIN, TAG, 'AppLock auth started with %{public}d type(s)', types.length);
  } catch (e) {
    // 实例化/启动失败（凭据环境异常、类型不支持等）按未通过处理，停留在锁定态可重试
    hilog.error(DOMAIN, TAG, 'AppLock auth failed to start: %{public}s', JSON.stringify(e));
    onResult(false);
  }
}
