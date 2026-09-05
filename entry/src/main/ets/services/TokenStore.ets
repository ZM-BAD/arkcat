/**
 * GitHub Personal Access Token 安全存储（基于 AssetStoreKit 加密存储）。
 *
 * 遵循 AGENTS.md 约定：Token 不得硬编码、不得明文落盘。
 */
import { asset } from '@kit.AssetStoreKit';
import { util } from '@kit.ArkTS';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TOKEN_ALIAS = 'starraft.github.pat';
const TAG = '[StarRaft]';
const DOMAIN = 0xFF00;

function strToBytes(s: string): Uint8Array {
  return new util.TextEncoder().encode(s);
}

function bytesToStr(bytes: Uint8Array): string {
  return util.TextDecoder.create('utf-8').decodeToString(bytes);
}

export class TokenStore {
  /** 保存 Token；已存在时先删后写 */
  static async save(token: string): Promise<void> {
    await TokenStore.remove();
    const attr: asset.AssetMap = new Map<asset.Tag, Uint8Array | boolean | number>();
    attr.set(asset.Tag.SECRET, strToBytes(token));
    attr.set(asset.Tag.ALIAS, strToBytes(TOKEN_ALIAS));
    await asset.add(attr);
  }

  /** 读取 Token；未配置或读取失败返回空串 */
  static async load(): Promise<string> {
    const query: asset.AssetMap = new Map<asset.Tag, Uint8Array | boolean | number>();
    query.set(asset.Tag.ALIAS, strToBytes(TOKEN_ALIAS));
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
      // 未配置 Token（ItemNotFound）属正常路径；系统级故障记录类型便于与「未登录」区分
      // （review G12：此前全部吞成空串，用户以未登录态面对全页 401 无从排查；不含敏感内容）
      hilog.error(DOMAIN, TAG, 'TokenStore load failed: %{public}s', `${e}`);
      return '';
    }
  }

  /** 删除 Token；不存在时静默成功 */
  static async remove(): Promise<void> {
    const query: asset.AssetMap = new Map<asset.Tag, Uint8Array | boolean | number>();
    query.set(asset.Tag.ALIAS, strToBytes(TOKEN_ALIAS));
    try {
      await asset.remove(query);
    } catch (e) {
      // 不存在即视为已删除
    }
  }
}
