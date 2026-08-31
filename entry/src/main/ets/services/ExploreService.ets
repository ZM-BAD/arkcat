/**
 * Explore 服务：Discover/Activity/Topic（Spec 003）。
 * Collections 精选集无公开 API，按 Spec 边界隐藏。
 */
import { graphql } from './GitHttpClient';
import { TopicSearchResult, mapSearchResult } from '../models/ExploreModels';
import { RepoSummary, mapRepo } from '../models/GitHubModels';
import { Json, JsonMap } from '../utils/Json';

const TOPIC_SEARCH_QUERY = `
query TopicRepositories($query: String!, $first: Int = 20) {
  search(query: $query, type: REPOSITORY, first: $first) {
    repositoryCount
    nodes {
      ... on Repository {
        id
        nameWithOwner
        description
        stargazerCount
        forkCount
        primaryLanguage { name color }
      }
    }
  }
}`;

/** 首页 Topics 网格展示的热门主题（GitHub 无 topic 浏览 API，客户端固定清单） */
export const FEATURED_TOPICS: string[] = [
  'harmonyos', 'arkts', 'typescript', 'react', 'vue', 'python',
  'rust', 'go', 'swift', 'kotlin', 'machine-learning', 'llm'
];

/** 构造 topic 搜索字符串（纯函数，便于单测） */
export function buildTopicQuery(topic: string): string {
  return `topic:${topic}`;
}

/** 高星推荐搜索串（Spec 003 Recommend for you） */
export function buildRecommendedQuery(): string {
  return 'stars:>1000 topic:typescript sort:stars';
}

/** GraphQL search 响应 → RepoSummary[]（Spec 003 推荐卡） */
export function mapRecommendation(data: JsonMap): RepoSummary[] {
  const search = Json.obj(data, 'search') ?? ({} as JsonMap);
  const repos: RepoSummary[] = [];
  for (const nodeItem of Json.arr(search, 'nodes')) {
    repos.push(mapRepo(nodeItem as JsonMap));
  }
  return repos;
}

export class ExploreService {
  /** 搜索某主题下按星标排序的仓库 */
  static async fetchTopicRepositories(token: string, topic: string): Promise<TopicSearchResult> {
    const variables: Record<string, Object> = {
      'query': buildTopicQuery(topic),
      'first': 20
    };
    const data = await graphql(TOPIC_SEARCH_QUERY, variables, token);
    return mapSearchResult(data, topic);
  }

  /** Activity 推荐仓库（高星热门近似，官方个性化推荐无公开 API） */
  static async fetchRecommendedRepos(token: string): Promise<RepoSummary[]> {
    const variables: Record<string, Object> = {
      'query': buildRecommendedQuery(),
      'first': 5
    };
    const data = await graphql(TOPIC_SEARCH_QUERY, variables, token);
    return mapRecommendation(data);
  }
}
