/**
 * 仓库文件服务（Spec 038 / 011）：目录树（GraphQL Tree）+ 文件内容（GraphQL Blob）。
 * GraphQL 目录/文件一次性返回；二进制/截断文件由页面按 FileContent 标志位降级展示。
 */
import { graphql } from './GitHttpClient';
import { JsonMap } from '../utils/Json';
import { DirPage, FileContent, mapDirPage, mapFileContent } from '../models/FileModels';

const DIR_QUERY = `
query DirEntries($owner: String!, $name: String!, $expression: String!) {
  repository(owner: $owner, name: $name) {
    object(expression: $expression) {
      ... on Tree { entries { name type } }
    }
  }
}`;

const BLOB_QUERY = `
query FileContent($owner: String!, $name: String!, $expression: String!) {
  repository(owner: $owner, name: $name) {
    object(expression: $expression) {
      ... on Blob { text isBinary isTruncated byteSize }
    }
  }
}`;

export class FileService {
  /** 目录条目：path 为空表示仓库根目录（expression "HEAD:"），否则 "HEAD:path" */
  static async fetchDir(token: string, owner: string, name: string, path: string): Promise<DirPage> {
    const expression: string = path === '' ? 'HEAD:' : `HEAD:${path}`;
    const variables: Record<string, Object> = {
      'owner': owner,
      'name': name,
      'expression': expression
    };
    const data: JsonMap = await graphql(DIR_QUERY, variables, token);
    return mapDirPage(data);
  }

  /** 文件内容（文本）；二进制/截断由页面按标志位降级 */
  static async fetchFileContent(token: string, owner: string, name: string, path: string): Promise<FileContent> {
    const variables: Record<string, Object> = {
      'owner': owner,
      'name': name,
      'expression': `HEAD:${path}`
    };
    const data: JsonMap = await graphql(BLOB_QUERY, variables, token);
    return mapFileContent(data);
  }
}
