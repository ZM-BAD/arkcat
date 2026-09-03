/**
 * 仓库社交列表模型（Spec 053）：Stargazers（用户列表）与 Forks（分叉仓库列表）。
 * 纯模型 + 映射函数，集中便于单元测试。
 */
import { Json, JsonMap } from '../utils/Json';
import { UserSummary, mapUser } from './GitHubModels';

/** Stargazers 一页 */
export interface StargazerPage {
  users: UserSummary[];
  hasNextPage: boolean;
  endCursor: string;
}

/** Fork 行数据（Repository 节点 + parent 上游） */
export interface ForkEntry {
  name: string;
  nameWithOwner: string;
  description: string;
  stargazerCount: number;
  primaryLanguage: string;
  languageColor: string;
  ownerLogin: string;
  ownerAvatarUrl: string;
  /** 上游仓库 owner/name；parent 为 null（上游删除/不可见）时置 ''，UI 隐藏 Forked from 行 */
  parentNameWithOwner: string;
}

/** Forks 一页 */
export interface ForkPage {
  forks: ForkEntry[];
  hasNextPage: boolean;
  endCursor: string;
}

/** GraphQL repository.stargazers → StargazerPage */
export function mapStargazerPage(data: JsonMap): StargazerPage {
  const repo = Json.obj(data, 'repository') ?? ({} as JsonMap);
  const conn = Json.obj(repo, 'stargazers') ?? ({} as JsonMap);
  const pageInfo = Json.obj(conn, 'pageInfo') ?? ({} as JsonMap);
  const users: UserSummary[] = [];
  for (const node of Json.arr(conn, 'nodes')) {
    users.push(mapUser(node as JsonMap));
  }
  return {
    users: users,
    hasNextPage: Json.bool(pageInfo, 'hasNextPage'),
    endCursor: Json.str(pageInfo, 'endCursor')
  };
}

/** GraphQL Repository（fork 节点）→ ForkEntry */
export function mapFork(raw: JsonMap): ForkEntry {
  const owner = Json.obj(raw, 'owner');
  const lang = Json.obj(raw, 'primaryLanguage');
  const parent = Json.obj(raw, 'parent');
  let parentNameWithOwner = '';
  if (parent !== null) {
    const pName = Json.str(parent, 'name');
    if (pName !== '') {
      const pOwner = Json.obj(parent, 'owner');
      const pLogin = pOwner !== null ? Json.str(pOwner, 'login') : '';
      parentNameWithOwner = pLogin === '' ? pName : `${pLogin}/${pName}`;
    }
  }
  return {
    name: Json.str(raw, 'name'),
    nameWithOwner: `${owner !== null ? Json.str(owner, 'login') : ''}/${Json.str(raw, 'name')}`,
    description: Json.str(raw, 'description'),
    stargazerCount: Json.num(raw, 'stargazerCount'),
    primaryLanguage: lang !== null ? Json.str(lang, 'name') : '',
    languageColor: lang !== null ? Json.str(lang, 'color') : '',
    ownerLogin: owner !== null ? Json.str(owner, 'login') : '',
    ownerAvatarUrl: owner !== null ? Json.str(owner, 'avatarUrl') : '',
    parentNameWithOwner: parentNameWithOwner
  };
}

/** GraphQL repository.forks → ForkPage */
export function mapForkPage(data: JsonMap): ForkPage {
  const repo = Json.obj(data, 'repository') ?? ({} as JsonMap);
  const conn = Json.obj(repo, 'forks') ?? ({} as JsonMap);
  const pageInfo = Json.obj(conn, 'pageInfo') ?? ({} as JsonMap);
  const forks: ForkEntry[] = [];
  for (const node of Json.arr(conn, 'nodes')) {
    forks.push(mapFork(node as JsonMap));
  }
  return {
    forks: forks,
    hasNextPage: Json.bool(pageInfo, 'hasNextPage'),
    endCursor: Json.str(pageInfo, 'endCursor')
  };
}
