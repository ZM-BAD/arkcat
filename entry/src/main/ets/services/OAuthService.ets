/**
 * GitHub OAuth Device Flow 服务（Spec 057）。
 *
 * 流程三步：device/code 取设备码 → 轮询 access_token（slow_down 后 interval += 5s）→
 * 调用方用 /user 实测 token 后经 AccountStore 落库（与 PAT 保存前实测口径一致，review A13）。
 * 纯端侧架构：全程只携带公开 client_id，无 client_secret（Device Flow 无需）。
 *
 * 状态机解析（parsePollResponse）为纯函数，与 HTTP I/O 分离，供 ohosTest 五态单测。
 */
import { http } from '@kit.NetworkKit';
import { Json, JsonMap } from '../utils/Json';

const CLIENT_ID = 'Ov23liBbyQ0Am7PNXBcj';
const SCOPES = 'repo read:user notifications read:org';
const DEVICE_CODE_URL = 'https://github.com/login/device/code';
const ACCESS_TOKEN_URL = 'https://github.com/login/oauth/access_token';
const DEFAULT_VERIFICATION_URI = 'https://github.com/login/device';
const DEFAULT_INTERVAL = 5;

export enum OAuthPollState {
  PENDING = 'pending',
  SLOW_DOWN = 'slow_down',
  EXPIRED = 'expired',
  DENIED = 'denied',
  SUCCESS = 'success',
  ERROR = 'error'
}

export interface OAuthDeviceInfo {
  deviceCode: string;
  userCode: string;
  verificationUri: string;
  interval: number;
  expiresIn: number;
}

/** 单轮轮询结果：state 决定下一步（PENDING/SLOW_DOWN 续轮询，其余终止） */
export interface OAuthPollResult {
  state: OAuthPollState;
  token: string;
  /** slow_down 时为 interval + 5s，其余保持传入值 */
  nextInterval: number;
}

/**
 * 轮询响应解析（纯函数，五态单测入口）。
 * 传入 JSON 已解析对象（JsonMap），成功判定 access_token 非空优先，
 * 否则按 error 字段映射状态；未知 error 归入 ERROR。
 */
export function parsePollResponse(parsed: JsonMap, interval: number): OAuthPollResult {
  const token = Json.str(parsed, 'access_token');
  if (token !== '') {
    return { state: OAuthPollState.SUCCESS, token: token, nextInterval: interval };
  }
  const errCode = Json.str(parsed, 'error');
  const pending: OAuthPollResult = { state: OAuthPollState.PENDING, token: '', nextInterval: interval };
  if (errCode === 'authorization_pending') {
    return pending;
  }
  if (errCode === 'slow_down') {
    return { state: OAuthPollState.SLOW_DOWN, token: '', nextInterval: interval + 5 };
  }
  if (errCode === 'expired_token') {
    return { state: OAuthPollState.EXPIRED, token: '', nextInterval: interval };
  }
  if (errCode === 'access_denied') {
    return { state: OAuthPollState.DENIED, token: '', nextInterval: interval };
  }
  return { state: OAuthPollState.ERROR, token: '', nextInterval: interval };
}

/**
 * ① 申请设备码。HTTP 失败/响应异常抛 Error（页面经 friendlyError 转网络文案）。
 */
export async function requestDeviceCode(): Promise<OAuthDeviceInfo> {
  const body = `client_id=${CLIENT_ID}&scope=${encodeURIComponent(SCOPES)}`;
  const parsed = await postForm(DEVICE_CODE_URL, body);
  if (parsed === null) {
    throw new Error('Device code request failed: invalid response');
  }
  const deviceCode = Json.str(parsed, 'device_code');
  if (deviceCode === '') {
    // GitHub 偶尔返回 200 + error 字段（如请求过快），按业务错误抛出
    const err = Json.str(parsed, 'error');
    throw new Error(`Device code request failed: ${err === '' ? 'unknown error' : err}`);
  }
  const info: OAuthDeviceInfo = {
    deviceCode: deviceCode,
    userCode: Json.str(parsed, 'user_code'),
    verificationUri: Json.str(parsed, 'verification_uri', DEFAULT_VERIFICATION_URI),
    interval: Json.num(parsed, 'interval', DEFAULT_INTERVAL),
    expiresIn: Json.num(parsed, 'expires_in', 900)
  };
  return info;
}

/**
 * ② 单次轮询 access_token。HTTP 失败由 postForm 抛 Error；
 * 业务状态（pending/slow_down/expired/denied）由 parsePollResponse 返回，不抛。
 */
export async function pollToken(deviceCode: string, interval: number): Promise<OAuthPollResult> {
  const body =
    `client_id=${CLIENT_ID}&device_code=${encodeURIComponent(deviceCode)}` +
    '&grant_type=urn:ietf:params:oauth:grant-type:device_code';
  const parsed = await postForm(ACCESS_TOKEN_URL, body);
  if (parsed === null) {
    throw new Error('Token poll failed: invalid response');
  }
  return parsePollResponse(parsed, interval);
}

/** 表单 POST（application/x-www-form-urlencoded，Accept JSON）；返回已解析 JSON 或 null */
async function postForm(url: string, body: string): Promise<JsonMap | null> {
  const req = http.createHttp();
  try {
    const options: http.HttpRequestOptions = {
      method: http.RequestMethod.POST,
      header: {
        'Accept': 'application/json',
        'Content-Type': 'application/x-www-form-urlencoded'
      },
      expectDataType: http.HttpDataType.STRING,
      connectTimeout: 15000,
      readTimeout: 20000,
      extraData: body
    };
    const resp = await req.request(url, options);
    const code = typeof resp.responseCode === 'number' ? resp.responseCode : 0;
    const text = typeof resp.result === 'string' ? resp.result : '';
    if (code < 200 || code >= 300) {
      throw new Error(`GitHub device flow ${url} -> HTTP ${code}${text.substring(0, 120)}`);
    }
    return Json.parse(text);
  } catch (e) {
    if (e instanceof Error) {
      throw e;
    }
    throw new Error(`GitHub device flow network failed: ${e}`);
  } finally {
    req.destroy();
  }
}
