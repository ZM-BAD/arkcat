/**
 * 仓库文件数据模型与映射（Spec 038 / 011）。
 */
import { Json, JsonMap } from '../utils/Json';

/** 文件树条目（目录或文件） */
export interface DirEntry {
  name: string;
  type: string;
}

/** 目录页（一次性返回全部条目，无分页） */
export interface DirPage {
  entries: DirEntry[];
}

/** 文件内容（GraphQL Blob） */
export interface FileContent {
  text: string;
  isBinary: boolean;
  isTruncated: boolean;
  byteSize: number;
}

/** GraphQL 目录查询响应 → DirPage */
export function mapDirPage(data: JsonMap): DirPage {
  const repo = Json.obj(data, 'repository') ?? ({} as JsonMap);
  const obj = Json.obj(repo, 'object');
  const entries: DirEntry[] = [];
  if (obj !== null) {
    for (const entryItem of Json.arr(obj, 'entries')) {
      const entry = entryItem as JsonMap;
      entries.push({ name: Json.str(entry, 'name'), type: Json.str(entry, 'type') });
    }
  }
  return { entries: entries };
}

/** GraphQL Blob 查询响应 → FileContent */
export function mapFileContent(data: JsonMap): FileContent {
  const repo = Json.obj(data, 'repository') ?? ({} as JsonMap);
  const obj = Json.obj(repo, 'object');
  if (obj === null) {
    return { text: '', isBinary: false, isTruncated: false, byteSize: 0 };
  }
  return {
    text: Json.str(obj, 'text'),
    isBinary: Json.bool(obj, 'isBinary'),
    isTruncated: Json.bool(obj, 'isTruncated'),
    byteSize: Json.num(obj, 'byteSize')
  };
}
