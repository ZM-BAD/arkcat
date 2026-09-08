/**
 * 多账号安全存储（Spec 049a）：
 * - token 列表经 AssetStoreKit 加密存储（单 alias 存 JSON，先删后写，同原 TokenStore 模式）
 * - 当前账号 active_login 为非敏感信息，走 Preferences（arkcat_accounts）
 * - 旧版单 token（arkcat.github.pat）启动时自动迁移：viewer 查询补 login，失败置空占位
 */
import { asset } from '@kit.AssetStoreKit';
import { util } from '@kit.ArkTS';
import { preferences } from '@kit.ArkData';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { common } from '@kit.AbilityKit';
import { HomeService } from './HomeService';
import { Json, JsonMap } from '../utils/Json';

const ACCOUNTS_ALIAS = 'arkcat.accounts.v2';
const LEGACY_ALIAS = 'arkcat.github.pat';
const MAX_ACCOUNTS = 5;
const PREFS_NAME = 'arkcat_accounts';
const KEY_ACTIVE = 'active_login';
const TAG = '[ArkCat]';
const DOMAIN = 0xFF00;

/** 账号条目（token 仅存在于加密 JSON 内） */
export interface AccountInfo {
  login: string;
  token: string;
  name: string;
  addedAt: number;
}

export enum AddAccountResult {
  OK = 0,
  DUPLICATE = 1,
  LIMIT = 2
}

function strToBytes(s: string): Uint8Array {
  return new util.TextEncoder().encode(s);
}

function bytesToStr(bytes: Uint8Array): string {
  return util.TextDecoder.create('utf-8').decodeToString(bytes);
}

/** 账号列表 → 存储 JSON（纯函数，三域可测） */
export function accountsToStorage(accounts: AccountInfo[]): string {
  return JSON.stringify(accounts);
}

/** 存储 JSON → 账号列表；坏 JSON/非数组/残缺条目一律过滤回退（纯函数） */
export function accountsFromStorage(raw: string): AccountInfo[] {
  if (raw === '') {
    return [];
  }
  try {
    const parsed: Object | null = JSON.parse(raw);
    if (parsed === null || !Array.isArray(parsed)) {
      return [];
    }
    const out: AccountInfo[] = [];
    for (const item of parsed as Object[]) {
      const m = item as JsonMap;
      const login = Json.str(m, 'login');
      const token = Json.str(m, 'token');
      if (login === '' || token === '') {
        continue;
      }
      out.push({
        login: login,
        token: token,
        name: Json.str(m, 'name'),
        addedAt: Json.num(m, 'addedAt')
      });
    }
    return out;
  } catch (e) {
    return [];
  }
}

/** v1 单 token → v2 账号条目（login/name 由调用方经 viewer 查询补齐，失败为空串） */
export function legacyToAccount(token: string, login: string, name: string, addedAt: number): AccountInfo {
  return { login: login, token: token, name: name, addedAt: addedAt };
}

/** 添加账号前的查重+上限判定（纯函数：同 login=重新授权 DUPLICATE；达到上限=LIMIT） */
export function nextAddResult(accounts: AccountInfo[], login: string): AddAccountResult {
  for (const a of accounts) {
    if (a.login === login) {
      return AddAccountResult.DUPLICATE;
    }
  }
  if (accounts.length >= MAX_ACCOUNTS) {
    return AddAccountResult.LIMIT;
  }
  return AddAccountResult.OK;
}

export class AccountStore {
  /** 加载全部账号（含 v1 迁移）；坏数据回退空表 */
  static async loadAccounts(context: common.Context | undefined): Promise<AccountInfo[]> {
    await AccountStore.migrateIfNeeded(context);
    return accountsFromStorage(await AccountStore.readAccountsRaw());
  }

  /** 当前账号；无账号返回 null；active 缺失/失效时回退第一个账号并回写 */
  static async getCurrentAccount(context: common.Context | undefined): Promise<AccountInfo | null> {
    const accounts = await AccountStore.loadAccounts(context);
    if (accounts.length === 0) {
      return null;
    }
    const active = await AccountStore.readActiveLogin(context);
    let target: AccountInfo | null = null;
    for (const a of accounts) {
      if (a.login === active) {
        target = a;
      }
    }
    if (target === null) {
      target = accounts[0];
      await AccountStore.writeActiveLogin(context, target.login);
    }
    return target;
  }

  /** 添加账号：查重（同 login 视为重新授权，更新 token 并切为当前）+ 上限 5；成功则切为当前账号 */
  static async addAccount(context: common.Context | undefined, login: string, token: string, name: string): Promise<AddAccountResult> {
    const accounts = await AccountStore.loadAccounts(context);
    const result = nextAddResult(accounts, login);
    const next: AccountInfo[] = [];
    let duplicate = false;
    for (const a of accounts) {
      if (a.login === login) {
        // 同一账号重新登录：更新 token 并切换（官方语义=切到该账号）
        duplicate = true;
        next.push({
          login: a.login,
          token: token,
          name: name === '' ? a.name : name,
          addedAt: a.addedAt
        });
      } else {
        next.push(a);
      }
    }
    if (duplicate) {
      await AccountStore.writeAccountsRaw(accountsToStorage(next));
      await AccountStore.writeActiveLogin(context, login);
      return AddAccountResult.DUPLICATE;
    }
    if (result === AddAccountResult.LIMIT) {
      return AddAccountResult.LIMIT;
    }
    next.push({ login: login, token: token, name: name, addedAt: Date.now() });
    await AccountStore.writeAccountsRaw(accountsToStorage(next));
    await AccountStore.writeActiveLogin(context, login);
    return AddAccountResult.OK;
  }

  /** 切换当前账号；返回该账号 token，未命中返回 '' */
  static async switchAccount(context: common.Context | undefined, login: string): Promise<string> {
    const accounts = await AccountStore.loadAccounts(context);
    for (const a of accounts) {
      if (a.login === login) {
        await AccountStore.writeActiveLogin(context, login);
        return a.token;
      }
    }
    return '';
  }

  /** 移除账号；若移除的是当前账号则重指向剩余第一个（无剩余则清空 active） */
  static async removeAccount(context: common.Context | undefined, login: string): Promise<void> {
    const accounts = await AccountStore.loadAccounts(context);
    const next: AccountInfo[] = [];
    for (const a of accounts) {
      if (a.login !== login) {
        next.push(a);
      }
    }
    await AccountStore.writeAccountsRaw(accountsToStorage(next));
    const active = await AccountStore.readActiveLogin(context);
    if (active === login) {
      await AccountStore.writeActiveLogin(context, next.length > 0 ? next[0].login : '');
    }
  }

  /** 移除全部账号（Sign out all accounts） */
  static async removeAll(context: common.Context | undefined): Promise<void> {
    await AccountStore.writeAccountsRaw('[]');
    await AccountStore.writeActiveLogin(context, '');
  }

  /** v1 → v2 一次性迁移：检测旧 alias，viewer 补 login（网络失败置空），写入后删旧 */
  private static async migrateIfNeeded(context: common.Context | undefined): Promise<void> {
    const v2 = await AccountStore.readAccountsRaw();
    if (v2 !== '') {
      // 已迁移过（或已是新结构）
      return;
    }
    const legacyToken = await AccountStore.readLegacyRaw();
    if (legacyToken === '') {
      return;
    }
    let login = '';
    let name = '';
    try {
      const viewer = await HomeService.fetchViewerBasic(legacyToken);
      login = viewer.login;
      name = viewer.name;
    } catch (e) {
      // 离线等：login 置空占位，账号行显示「未验证」，用户可移除重加
      hilog.warn(DOMAIN, TAG, 'AccountStore migrate: viewer query failed, login placeholder');
    }
    const accounts: AccountInfo[] = [legacyToAccount(legacyToken, login, name, Date.now())];
    await AccountStore.writeAccountsRaw(accountsToStorage(accounts));
    await AccountStore.removeLegacy();
  }

  // ---- AssetStoreKit 读写 ----

  private static async readAccountsRaw(): Promise<string> {
    return AccountStore.readAliasSecret(ACCOUNTS_ALIAS);
  }

  private static async writeAccountsRaw(json: string): Promise<void> {
    try {
      await AccountStore.removeAlias(ACCOUNTS_ALIAS);
      const attr: asset.AssetMap = new Map<asset.Tag, Uint8Array | boolean | number>();
      attr.set(asset.Tag.SECRET, strToBytes(json));
      attr.set(asset.Tag.ALIAS, strToBytes(ACCOUNTS_ALIAS));
      await asset.add(attr);
    } catch (e) {
      // 加密存储故障：不阻断 UI，下轮加载回退空表（无 token 即进入未登录态，属安全侧失败）
      hilog.error(DOMAIN, TAG, 'AccountStore write failed: %{public}s', `${e}`);
    }
  }

  private static async readLegacyRaw(): Promise<string> {
    return AccountStore.readAliasSecret(LEGACY_ALIAS);
  }

  private static async removeLegacy(): Promise<void> {
    await AccountStore.removeAlias(LEGACY_ALIAS);
  }

  private static async readAliasSecret(alias: string): Promise<string> {
    const query: asset.AssetMap = new Map<asset.Tag, Uint8Array | boolean | number>();
    query.set(asset.Tag.ALIAS, strToBytes(alias));
    query.set(asset.Tag.RETURN_TYPE, asset.ReturnType.ALL);
    try {
      const results: asset.AssetMap[] = await asset.query(query);
      if (results.length === 0) {
        return '';
      }
      const secret: Uint8Array | boolean | number | undefined = results[0].get(asset.Tag.SECRET);
      if (secret instanceof Uint8Array) {
        return bytesToStr(secret);
      }
      return '';
    } catch (e) {
      // 未配置属正常路径（ItemNotFound）；系统级故障也按「未配置」处理，用户以未登录态看到落地页
      return '';
    }
  }

  private static async removeAlias(alias: string): Promise<void> {
    const query: asset.AssetMap = new Map<asset.Tag, Uint8Array | boolean | number>();
    query.set(asset.Tag.ALIAS, strToBytes(alias));
    try {
      await asset.remove(query);
    } catch (e) {
      // 不存在即视为已删除
    }
  }

  // ---- Preferences（active_login）----

  private static async readActiveLogin(context: common.Context | undefined): Promise<string> {
    if (context === undefined) {
      return '';
    }
    try {
      const prefs = await preferences.getPreferences(context, PREFS_NAME);
      const value = await prefs.get(KEY_ACTIVE, '');
      return typeof value === 'string' ? value as string : '';
    } catch (e) {
      return '';
    }
  }

  private static async writeActiveLogin(context: common.Context | undefined, login: string): Promise<void> {
    if (context === undefined) {
      return;
    }
    try {
      const prefs = await preferences.getPreferences(context, PREFS_NAME);
      await prefs.put(KEY_ACTIVE, login);
      await prefs.flush();
    } catch (e) {
      // 失败不阻断：下次启动回退第一个账号
    }
  }
}
