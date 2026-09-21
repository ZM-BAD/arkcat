/**
 * LinkRouter（Spec 045）：GitHub 通知对象 URL → 页面路由解析器。
 * 纯函数（无 UI/网络依赖），供 Inbox tap 跳转使用；后续 046/047 复用。
 * 输入兼容 api.github.com/repos/... 与 github.com/... 两种形态。
 */

/** 可跳转的通知对象类型（unknown=无法解析，点击仅标已读） */
export type LinkKind = 'issue' | 'pr' | 'release' | 'discussion' | 'unknown';

export interface LinkRoute {
  kind: LinkKind;
  owner: string;
  name: string;
  /** Issue/PR 为编号；release/discussion 为数字 id（详情页路由仍需换算） */
  number: number;
  /** discussion 的网页地址（App 无讨论详情页，经内嵌浏览器打开；issue/pr/release 为空串） */
  webUrl: string;
}

const EMPTY_ROUTE: LinkRoute = { kind: 'unknown', owner: '', name: '', number: 0, webUrl: '' };

/**
 * subject.url → LinkRoute（纯函数，便于宿主单测）。
 * 匹配 /repos/{owner}/{name}/{issues|pulls|discussions|releases}/{n}；pull/Issues 单数形态兼容。
 */
export function parseSubjectUrl(url: string): LinkRoute {
  const m = /repos\/([^\/]+)\/([^\/]+)\/(issues|pulls|pull|discussions|releases)\/([0-9]+)/.exec(url);
  if (m === null || m[1] === undefined || m[2] === undefined || m[3] === undefined || m[4] === undefined) {
    return { kind: 'unknown', owner: '', name: '', number: 0, webUrl: '' };
  }
  const owner = m[1];
  const name = m[2];
  const seg = m[3];
  const num = parseInt(m[4], 10);
  if (seg === 'issues') {
    return { kind: 'issue', owner: owner, name: name, number: num, webUrl: '' };
  }
  if (seg === 'pulls' || seg === 'pull') {
    return { kind: 'pr', owner: owner, name: name, number: num, webUrl: '' };
  }
  if (seg === 'discussions') {
    return {
      kind: 'discussion', owner: owner, name: name, number: num,
      webUrl: `https://github.com/${owner}/${name}/discussions/${num}`
    };
  }
  // release：api id 不能直接当 tagName，页面层先经 REST 换 tag 再跳详情（失败降级列表页）
  return { kind: 'release', owner: owner, name: name, number: num, webUrl: '' };
}

/**
 * release 通知详情路由参数 `owner/name/{tag}`（纯函数）。
 * tag 可能含 '/'（如 app-v1.2.3），parseRouteParam 已按第 3 段起整体还原处理。
 */
export function releaseRouteParam(owner: string, name: string, tag: string): string {
  return `${owner}/${name}/${tag}`;
}
