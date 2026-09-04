/**
 * 仓库 License 模型（Spec 055）：licenseInfo 映射 + body 首行许可证名剥离（纯函数便于单测）。
 */
import { Json, JsonMap } from '../utils/Json';

/** License 信息（正文页展示） */
export interface LicenseInfo {
  name: string;
  spdxId: string;
  body: string;
}

/** GraphQL repository.licenseInfo → LicenseInfo；未声明许可证（licenseInfo 为 null）返回 null */
export function mapLicenseInfo(data: JsonMap): LicenseInfo | null {
  const repo = Json.obj(data, 'repository') ?? ({} as JsonMap);
  const info = Json.obj(repo, 'licenseInfo');
  if (info === null) {
    return null;
  }
  return {
    name: Json.str(info, 'name'),
    spdxId: Json.str(info, 'spdxId'),
    body: Json.str(info, 'body')
  };
}

/**
 * 剥离 body 首行的许可证全名（如 "MIT License"）及其后空行，使正文从 Copyright 起（对照官方 App）。
 * name 为空（无法比对）时原样返回。
 */
export function stripLicenseTitle(name: string, body: string): string {
  if (name === '' || !body.startsWith(name)) {
    return body;
  }
  const lines = body.split('\n');
  if (lines.length > 1) {
    lines.shift();
    while (lines.length > 0 && lines[0] === '') {
      lines.shift();
    }
  }
  return lines.join('\n');
}
