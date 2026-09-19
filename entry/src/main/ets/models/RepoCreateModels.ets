/**
 * 创建新仓库（Spec 070）模型与纯函数：建仓 payload 组装、REST/GraphQL 响应映射、
 * 子弹层候选过滤与名称校验。纯逻辑集中此处进宿主单测（services/RepoCreateService 只做传输）。
 */
import { Json, JsonMap } from '../utils/Json';

/** 仓库名/描述长度上限（GitHub REST 限制，官方 App 计数同值） */
export const REPO_NAME_MAX = 100;
export const REPO_DESC_MAX = 350;

/** 官方 License 精选集（choosealicense.com 精选 13 项；全量 /licenses 客户端过滤，Spec 070 §七） */
const LICENSE_SPDX_SET: string[] = [
  'AGPL-3.0', 'Apache-2.0', 'BSD-2-Clause', 'BSD-3-Clause', 'BSL-1.0',
  'CC0-1.0', 'EPL-2.0', 'GPL-2.0', 'GPL-3.0', 'LGPL-2.1',
  'MIT', 'MPL-2.0', 'Unlicense'
];

/** 子弹层选项：key=回传标识（spdx / 模板名 / 仓库节点 id），sublabel 非空时渲染灰字行 */
export interface PickerItem {
  key: string;
  label: string;
  sublabel: string;
}

/** 建仓表单（弹层收集态的纯数据快照） */
export interface NewRepoForm {
  name: string;
  description: string;
  isPrivate: boolean;
  addReadme: boolean;
  /** viewer.id（模板建仓 mutation 的 ownerId 入参；REST 分支不用） */
  ownerId: string;
  /** 选中的 .gitignore 模板名（空=未选） */
  gitignoreTemplate: string;
  /** 选中的许可证 spdx（空=未选） */
  licenseTemplate: string;
  /** 选中的模板仓库 GraphQL 节点 id（空=无模板走 REST /user/repos） */
  templateRepoId: string;
}

/** 建仓结果：跳转 repoDetail 所需最小信息 */
export interface CreatedRepo {
  owner: string;
  name: string;
}

/** 模板仓库候选源：GraphQL 模板建仓 mutation 还需要 viewer.id 作 ownerId */
export interface TemplateRepoSource {
  ownerId: string;
  items: PickerItem[];
}

/** 初始内容（README/.gitignore/license）是否任一勾选：决定 auto_init（模板文件随初始提交落地，Spec 070 §五） */
export function shouldAutoInit(form: NewRepoForm): boolean {
  return form.addReadme || form.gitignoreTemplate !== '' || form.licenseTemplate !== '';
}

/** POST /user/repos body 组装：空可选字段整体省略（模板分支不经过此函数） */
export function buildCreateRepoBody(form: NewRepoForm): string {
  const body: Record<string, Object> = {
    'name': form.name,
    'private': form.isPrivate,
    'auto_init': shouldAutoInit(form)
  };
  if (form.description !== '') {
    body['description'] = form.description;
  }
  if (form.gitignoreTemplate !== '') {
    body['gitignore_template'] = form.gitignoreTemplate;
  }
  if (form.licenseTemplate !== '') {
    body['license_template'] = form.licenseTemplate;
  }
  return JSON.stringify(body);
}

/** 仓库名表单校验：trim 非空且 ≤100；字符白名单不做，服务端 422 兜底 */
export function isValidRepoName(name: string): boolean {
  const trimmed = name.trim();
  return trimmed !== '' && trimmed.length <= REPO_NAME_MAX;
}

/** 可见性 GraphQL 枚举值 */
export function visibilityEnum(isPrivate: boolean): string {
  return isPrivate ? 'PRIVATE' : 'PUBLIC';
}

/** JSON 文本安全解析为数组（失败/非数组返回空） */
function parseArray(text: string): Object[] {
  try {
    const parsed: Object | null = JSON.parse(text);
    return Array.isArray(parsed) ? parsed as Object[] : [];
  } catch (e) {
    return [];
  }
}

/** REST /licenses 全量数组 → 官方 13 精选集（保留 API 返回序，恰与官方一致） */
export function mapRestLicenses(body: string): PickerItem[] {
  const items: PickerItem[] = [];
  const arr = parseArray(body);
  for (const raw of arr) {
    if (raw === null || typeof raw !== 'object') {
      continue;
    }
    const lic = raw as JsonMap;
    const spdx = Json.str(lic, 'spdx_id');
    if (LICENSE_SPDX_SET.indexOf(spdx) < 0) {
      continue;
    }
    items.push({ key: spdx, label: Json.str(lic, 'name'), sublabel: spdx });
  }
  return items;
}

/** REST /gitignore/templates 字符串数组 → 单值行选项（API 返回序即官方展示序） */
export function mapGitignoreTemplates(body: string): PickerItem[] {
  const items: PickerItem[] = [];
  for (const raw of parseArray(body)) {
    if (typeof raw === 'string' && raw !== '') {
      items.push({ key: raw, label: raw, sublabel: '' });
    }
  }
  return items;
}

/** GraphQL viewer 模板仓库节点 → 候选（isTemplate 客户端过滤：RepositoryConnection 无该筛选参数） */
export function mapTemplateRepos(data: JsonMap): PickerItem[] {
  const items: PickerItem[] = [];
  const viewer = Json.obj(data, 'viewer') ?? ({} as JsonMap);
  const conn = Json.obj(viewer, 'repositories') ?? ({} as JsonMap);
  for (const raw of Json.arr(conn, 'nodes')) {
    if (raw === null || typeof raw !== 'object') {
      continue;
    }
    const repo = raw as JsonMap;
    if (!Json.bool(repo, 'isTemplate')) {
      continue;
    }
    items.push({ key: Json.str(repo, 'id'), label: Json.str(repo, 'name'), sublabel: '' });
  }
  return items;
}

/** viewer.id：模板建仓 mutation 的 ownerId */
export function mapViewerId(data: JsonMap): string {
  const viewer = Json.obj(data, 'viewer') ?? ({} as JsonMap);
  return Json.str(viewer, 'id');
}

/** 子弹层搜索过滤：大小写不敏感、trim、空串返回全量 */
export function filterPickerItems(items: PickerItem[], query: string): PickerItem[] {
  const q = query.trim().toLowerCase();
  if (q === '') {
    return items;
  }
  return items.filter((it: PickerItem): boolean => it.label.toLowerCase().indexOf(q) >= 0);
}

/** REST 建仓结果 → CreatedRepo */
export function mapRestCreatedRepo(body: string): CreatedRepo {
  const repo = Json.parse(body) ?? ({} as JsonMap);
  const owner = Json.obj(repo, 'owner') ?? ({} as JsonMap);
  return { owner: Json.str(owner, 'login'), name: Json.str(repo, 'name') };
}

/** GraphQL 模板建仓结果 → CreatedRepo */
export function mapTemplateCreatedRepo(data: JsonMap): CreatedRepo {
  const payload = Json.obj(data, 'createRepositoryFromTemplate') ?? ({} as JsonMap);
  const repo = Json.obj(payload, 'repository') ?? ({} as JsonMap);
  const owner = Json.obj(repo, 'owner') ?? ({} as JsonMap);
  return { owner: Json.str(owner, 'login'), name: Json.str(repo, 'name') };
}
