/**
 * 搜索服务（Spec 015）：Code 搜索（GraphQL search type: CODE）。
 * 返回 File 节点（仓库/路径/文件名）；代码行正文需 REST 兜底（后续 Spec）。
 */
import { graphql } from './GitHttpClient';
import { Json, JsonMap } from '../utils/Json';

/** 代码搜索结果项 */
export interface CodeSearchItem {
  repoFullName: string;
  path: string;
  name: string;
  isMarkdown: boolean;
}

const CODE_SEARCH_QUERY = `
query CodeSearch($query: String!, $first: Int = 10) {
  search(query: $query, type: CODE, first: $first) {
    codeCount
    nodes {
      ... on File {
        repository { nameWithOwner }
        path
        name
      }
    }
  }
}`;

/** 构造 code 搜索串（纯函数，便于单测） */
export function buildCodeQuery(keyword: string): string {
  return `"${keyword}"`;
}

/** GraphQL CODE search 响应 → CodeSearchItem[] */
export function mapCodeSearch(data: JsonMap): CodeSearchItem[] {
  const search = Json.obj(data, 'search') ?? ({} as JsonMap);
  const items: CodeSearchItem[] = [];
  for (const nodeItem of Json.arr(search, 'nodes')) {
    const node = nodeItem as JsonMap;
    const repo = Json.obj(node, 'repository');
    let name = Json.str(node, 'name');
    const path = Json.str(node, 'path');
    // name 缺失时从 path 末段取
    if (name === '' && path !== '') {
      const parts = path.split('/');
      name = parts.length > 0 ? parts[parts.length - 1] : '';
    }
    items.push({
      repoFullName: repo ? Json.str(repo, 'nameWithOwner') : '',
      path: path,
      name: name,
      isMarkdown: name.toLowerCase().endsWith('.md')
    });
  }
  return items;
}

/** 建议列表：六类搜索入口（纯常量） */
export const SEARCH_SUGGESTION_TYPES: string[] = [
  'code', 'repositories', 'issues', 'prs', 'people', 'orgs'
];

export class SearchService {
  /** 代码搜索（GraphQL CODE） */
  static async fetchCodeResults(token: string, keyword: string): Promise<CodeSearchItem[]> {
    const variables: Record<string, Object> = {
      'query': buildCodeQuery(keyword),
      'first': 10
    };
    const data = await graphql(CODE_SEARCH_QUERY, variables, token);
    return mapCodeSearch(data);
  }
}
