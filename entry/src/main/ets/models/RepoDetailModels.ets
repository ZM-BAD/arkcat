/**
 * 仓库详情数据模型与映射（Spec 006）。
 */
import { Json, JsonMap } from '../utils/Json';

/** 文件树条目 */
export interface FileEntry {
  name: string;
  type: string;
}

/** 语言占比切片 */
export interface LanguageSlice {
  name: string;
  color: string;
  percent: number;
}

/** 仓库详情聚合 */
export interface RepoDetail {
  repoId: string;
  nameWithOwner: string;
  description: string;
  stargazerCount: number;
  forkCount: number;
  watcherCount: number;
  viewerHasStarred: boolean;
  licenseName: string;
  topics: string[];
  readmeText: string;
  files: FileEntry[];
  languages: LanguageSlice[];
  lastCommitMessage: string;
}

/** GraphQL Repository 响应 → RepoDetail */
export function mapRepoDetail(data: JsonMap): RepoDetail {
  const repo = Json.obj(data, 'repository') ?? ({} as JsonMap);
  const license = Json.obj(repo, 'licenseInfo');
  const topicsWrap = Json.obj(repo, 'repositoryTopics');
  const topics: string[] = [];
  if (topicsWrap !== null) {
    for (const nodeItem of Json.arr(topicsWrap, 'nodes')) {
      const topic = Json.obj(nodeItem as JsonMap, 'topic');
      if (topic !== null) {
        topics.push(Json.str(topic, 'name'));
      }
    }
  }
  const readmeObj = Json.obj(repo, 'readme');
  const treeObj = Json.obj(repo, 'fileTree');
  const files: FileEntry[] = [];
  if (treeObj !== null) {
    for (const entryItem of Json.arr(treeObj, 'entries')) {
      const entry = entryItem as JsonMap;
      files.push({ name: Json.str(entry, 'name'), type: Json.str(entry, 'type') });
    }
  }
  const langsRaw = Json.obj(repo, 'languages');
  const totalSize = langsRaw !== null ? Json.num(langsRaw, 'totalSize') : 0;
  const languages: LanguageSlice[] = [];
  if (langsRaw !== null) {
    for (const edgeItem of Json.arr(langsRaw, 'edges')) {
      const edge = edgeItem as JsonMap;
      const node = Json.obj(edge, 'node');
      if (node === null) {
        continue;
      }
      const size = Json.num(edge, 'size');
      languages.push({
        name: Json.str(node, 'name'),
        color: Json.str(node, 'color'),
        percent: totalSize > 0 ? Math.round(size * 100 / totalSize) : 0
      });
    }
  }
  let lastCommitMessage = '';
  const branch = Json.obj(repo, 'defaultBranchRef');
  if (branch !== null) {
    const target = Json.obj(branch, 'target');
    if (target !== null) {
      const history = Json.obj(target, 'history');
      if (history !== null) {
        const nodes = Json.arr(history, 'nodes');
        if (nodes.length > 0) {
          lastCommitMessage = Json.str(nodes[0] as JsonMap, 'messageHeadline');
        }
      }
    }
  }
  const watchers = Json.obj(repo, 'watchers');
  return {
    repoId: Json.str(repo, 'id'),
    nameWithOwner: Json.str(repo, 'nameWithOwner'),
    description: Json.str(repo, 'description'),
    stargazerCount: Json.num(repo, 'stargazerCount'),
    forkCount: Json.num(repo, 'forkCount'),
    watcherCount: watchers ? Json.num(watchers, 'totalCount') : 0,
    viewerHasStarred: Json.bool(repo, 'viewerHasStarred'),
    licenseName: license ? Json.str(license, 'name') : '',
    topics: topics,
    readmeText: readmeObj ? Json.str(readmeObj, 'text') : '',
    files: files,
    languages: languages,
    lastCommitMessage: lastCommitMessage
  };
}

/** Star 按钮的下一个动作（纯函数，便于单测）：true=需要加星 */
export function nextStarAction(viewerHasStarred: boolean): boolean {
  return !viewerHasStarred;
}
