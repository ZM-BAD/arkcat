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

/** 仓库用户列表一页（Spec 054：Contributors/Watchers 统一分页结构） */
export interface PeoplePage {
  users: UserSummary[];
  hasNextPage: boolean;
  /** 下一页游标（watchers=GraphQL endCursor；contributors=页码字符串） */
  endCursor: string;
}

/** GraphQL repository.watchers → PeoplePage（结构与 stargazers 连接一致） */
export function mapWatcherPage(data: JsonMap): PeoplePage {
  const repo = Json.obj(data, 'repository') ?? ({} as JsonMap);
  const conn = Json.obj(repo, 'watchers') ?? ({} as JsonMap);
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

/** REST /contributors 原始项（仅 login/avatar_url；补全见 mapContributorPage 的 meta 参数） */
export interface RawContributor {
  login: string;
  avatarUrl: string;
}

export function mapRawContributor(raw: JsonMap): RawContributor {
  // REST /contributors 为 snake_case：avatar_url（GraphQL user(login) 才是 avatarUrl）
  return { login: Json.str(raw, 'login'), avatarUrl: Json.str(raw, 'avatar_url') };
}

/**
 * 合并 REST 贡献者数组与 GraphQL 元信息（key=login 的 user(login) 补全）→ PeoplePage。
 * 顺序保留 REST 原序（贡献数降序）；GraphQL 缺失的用户降级为 REST 字段（name/bio 空）。
 */
export function mapContributorPage(restNodes: JsonMap[], meta: Map<string, JsonMap>, page: number): PeoplePage {
  const users: UserSummary[] = [];
  for (const raw of restNodes) {
    const rc = mapRawContributor(raw);
    const gql = meta.get(rc.login);
    if (gql !== undefined && (gql['login'] !== undefined && gql['login'] !== null)) {
      users.push(mapUser(gql));
    } else {
      users.push({ login: rc.login, name: '', avatarUrl: rc.avatarUrl, bio: '', followers: 0, following: 0 });
    }
  }
  return {
    users: users,
    // REST 无 Link 头透出：长度=per_page(50) 视为可能还有下一页
    hasNextPage: restNodes.length >= 50,
    endCursor: `${page + 1}`
  };
}

/** POST /repos/{owner}/{repo}/forks body 组装（Spec 075）：fork 名走 JSON 转义，开关=「仅复制默认分支」 */
export function buildForkBody(forkName: string, defaultBranchOnly: boolean): string {
  const body: Record<string, Object> = {
    'name': forkName,
    'default_branch_only': defaultBranchOnly
  };
  return JSON.stringify(body);
}
