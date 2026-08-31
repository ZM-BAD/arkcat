/**
 * Explore 页数据模型与映射（Spec 003）。
 */
import { Json, JsonMap } from '../utils/Json';
import { RepoSummary, mapRepo } from './GitHubModels';

/** Topic 仓库搜索结果 */
export interface TopicSearchResult {
  topic: string;
  repositoryCount: number;
  repos: RepoSummary[];
}

/** GraphQL search 响应 → TopicSearchResult */
export function mapSearchResult(data: JsonMap, topic: string): TopicSearchResult {
  const search = Json.obj(data, 'search') ?? ({} as JsonMap);
  const repos: RepoSummary[] = [];
  for (const nodeItem of Json.arr(search, 'nodes')) {
    repos.push(mapRepo(nodeItem as JsonMap));
  }
  return {
    topic: topic,
    repositoryCount: Json.num(search, 'repositoryCount'),
    repos: repos
  };
}
