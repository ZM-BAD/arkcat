/**
 * 建仓服务（Spec 070）：无模板走 REST POST /user/repos（GraphQL 无 createRepository mutation），
 * 选模板走 GraphQL createRepositoryFromTemplate；模板/.gitignore/license 候选拉取。
 * GitHub 端点知识只落本适配层（docs/graphql-usage.md），页面禁裸 http。
 */
import { ApiError, RawResponse, graphql, restGet, restPost } from './GitHttpClient';
import {
  CreatedRepo, NewRepoForm, PickerItem, TemplateRepoSource,
  buildCreateRepoBody, mapGitignoreTemplates, mapRestCreatedRepo,
  mapRestLicenses, mapTemplateCreatedRepo, mapTemplateRepos,
  mapViewerId, visibilityEnum
} from '../models/RepoCreateModels';

const VIEWER_TEMPLATE_REPOS_QUERY = `
query ViewerTemplateRepos($first: Int!) {
  viewer {
    id
    repositories(first: $first, ownerAffiliations: OWNER, orderBy: {field: NAME, direction: ASC}) {
      nodes { id name isTemplate owner { login } }
    }
  }
}`;

const CREATE_REPO_FROM_TEMPLATE_MUTATION = `
mutation CreateRepoFromTemplate($input: CreateRepositoryFromTemplateInput!) {
  createRepositoryFromTemplate(input: $input) {
    repository { name owner { login } url }
  }
}`;

const TEMPLATE_PAGE_SIZE = 100;

/** REST 响应统一校验：非 2xx 抛 ApiError（422 重名/非法名的专属文案由 UI 层给） */
function ensureOk(resp: RawResponse): string {
  if (resp.code < 200 || resp.code >= 300) {
    throw new ApiError(resp.code, `GitHub REST HTTP ${resp.code}`);
  }
  return resp.body;
}

export class RepoCreateService {
  /** .gitignore 模板候选（API 返回序即官方展示序：AL/Actionscript/Ada…） */
  static async fetchGitignoreTemplates(token: string): Promise<PickerItem[]> {
    return mapGitignoreTemplates(ensureOk(await restGet('/gitignore/templates', token)));
  }

  /** License 候选：全量 /licenses 客户端过滤官方 13 精选集 */
  static async fetchLicenses(token: string): Promise<PickerItem[]> {
    return mapRestLicenses(ensureOk(await restGet('/licenses', token)));
  }

  /** viewer 仓库模板候选 + ownerId（模板建仓 mutation 入参，Spec 070 §四） */
  static async fetchTemplateRepos(token: string): Promise<TemplateRepoSource> {
    const data = await graphql(VIEWER_TEMPLATE_REPOS_QUERY, { 'first': TEMPLATE_PAGE_SIZE }, token);
    return { ownerId: mapViewerId(data), items: mapTemplateRepos(data) };
  }

  /** 建仓：有模板走 GraphQL（与 REST generate 同义），否则 REST POST /user/repos */
  static async createRepository(token: string, form: NewRepoForm): Promise<CreatedRepo> {
    if (form.templateRepoId !== '') {
      // 模板分支 ownerId 不可缺（能选中模板=fetchTemplateRepos 已带出）
      const input: Record<string, Object> = {
        'templateRepositoryId': form.templateRepoId,
        'ownerId': form.ownerId,
        'name': form.name,
        'visibility': visibilityEnum(form.isPrivate),
        'includeAllBranches': false
      };
      if (form.description !== '') {
        input['description'] = form.description;
      }
      const data = await graphql(CREATE_REPO_FROM_TEMPLATE_MUTATION, { 'input': input }, token);
      return mapTemplateCreatedRepo(data);
    }
    const resp = await restPost('/user/repos', token, buildCreateRepoBody(form));
    return mapRestCreatedRepo(ensureOk(resp));
  }
}
