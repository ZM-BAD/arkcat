/**
 * Issue/PR 表单纯规则（Spec 043）：标题校验 / 分支选择校验 / base 默认值 /
 * 路由参数解析 / 分支候选过滤。无 UI 依赖，宿主单测直测（scripts/ut/unit.test.ts）。
 */

/** 官方标题上限（255 字符，超长提交被服务端 422 拒绝，客户端先行拦截） */
export const ISSUE_TITLE_MAX: number = 255;

/** 标题错误键：''=合法；'required'=空白；'too_long'=超上限（页面按键取 i18n 文案） */
export function issueTitleError(title: string): string {
  const trimmed = title.trim();
  if (trimmed === '') {
    return 'required';
  }
  if (trimmed.length > ISSUE_TITLE_MAX) {
    return 'too_long';
  }
  return '';
}

/** 标题可提交：无错误键 */
export function canSubmitIssue(title: string): boolean {
  return issueTitleError(title) === '';
}

/** PR 分支选择错误键：''=合法；'head_required'=未选 head；'head_equals_base'=head 与 base 相同 */
export function validatePrHeads(base: string, head: string): string {
  if (head.trim() === '') {
    return 'head_required';
  }
  if (head === base) {
    return 'head_equals_base';
  }
  return '';
}

/**
 * base 默认值：默认分支在分支列表内直接用之；
 * 否则（异常数据）退回首个分支；无分支回空串由提交校验兜底。
 */
export function defaultBaseBranch(defaultBranch: string, branches: string[]): string {
  if (defaultBranch !== '' && branches.indexOf(defaultBranch) >= 0) {
    return defaultBranch;
  }
  return branches.length > 0 ? branches[0] : '';
}

/** 表单路由参数（owner|name|mode|editNumber；owner/name 为空 = Home 入口先选仓库） */
export interface FormRoute {
  owner: string;
  name: string;
  mode: string;
  editNumber: number;
}

/** 解析表单路由参数：缺段/非法段回落默认值（mode=new，editNumber=0） */
export function parseFormRoute(param: string): FormRoute {
  const parts: string[] = param.split('|');
  const numberRaw: string = parts.length > 3 ? parts[3] : '0';
  const parsed = parseInt(numberRaw, 10);
  return {
    owner: parts.length > 0 ? parts[0] : '',
    name: parts.length > 1 ? parts[1] : '',
    mode: parts.length > 2 && parts[2] !== '' ? parts[2] : 'new',
    editNumber: isNaN(parsed) ? 0 : parsed
  };
}

/** 分支候选按关键字过滤（大小写不敏感包含匹配；供 base/head 选择面板搜索） */
export function filterBranches(branches: string[], keyword: string): string[] {
  const q = keyword.trim().toLowerCase();
  if (q === '') {
    return branches;
  }
  return branches.filter((b: string): boolean => b.toLowerCase().indexOf(q) >= 0);
}
