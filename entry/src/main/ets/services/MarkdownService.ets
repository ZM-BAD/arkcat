/**
 * Markdown 渲染服务（Spec 040）：官方管线——GraphQL bodyHTML 直渲 + REST 拉取 README/文档 HTML。
 * 页面只把 HTML 字符串喂给 MarkdownView；请求、解析、状态判定集中在此。
 */
import { ApiError, restGet, restPost } from './GitHttpClient';
import { Json } from '../utils/Json';

const ACCEPT_HTML_JSON = 'application/vnd.github.html+json';

/** README/文档 html 拉取结果：notFound=404（无内容），error=网络/其他异常 */
export interface MarkdownFetchResult {
  status: 'ok' | 'notFound' | 'error';
  html: string;
}

/** 站内链接 → 路由映射（MarkdownView 拦截导航用；name 对应 Index.ets destinationMap） */
export interface MarkdownRoute {
  name: string;
  param: string;
}

export class MarkdownService {
  /** 仓库根 README（默认 default branch；branch 非空走 ref 参数） */
  static async fetchReadmeHtml(token: string, owner: string, repo: string, branch: string = ''): Promise<MarkdownFetchResult> {
    let path = `/repos/${owner}/${repo}/readme`;
    if (branch !== '') {
      path = `${path}?ref=${branch}`;
    }
    return MarkdownService.fetchHtmlEnvelope(path, token);
  }

  /** 组织主页 profile README：先 .github/profile/README.md，再 .github/readme（与官方一致） */
  static async fetchOrgProfileReadme(token: string, login: string): Promise<MarkdownFetchResult> {
    const first = await MarkdownService.fetchHtmlEnvelope(`/repos/${login}/.github/contents/profile/README.md`, token);
    if (first.status !== 'notFound') {
      return first;
    }
    return MarkdownService.fetchHtmlEnvelope(`/repos/${login}/.github/readme`, token);
  }

  /** 统一信封解析：html 流兼容 JSON 信封/纯 HTML 两种（2026-09-03 实测 /readme 直接返回纯 HTML 流）；404 → notFound */
  private static async fetchHtmlEnvelope(path: string, token: string): Promise<MarkdownFetchResult> {
    try {
      const resp = await restGet(path, token, ACCEPT_HTML_JSON);
      const html = MarkdownService.parseHtmlBody(resp.body);
      if (html.trim() === '') {
        return { status: 'error', html: '' };
      }
      return { status: 'ok', html: html };
    } catch (e) {
      if (e instanceof ApiError && e.code === 404) {
        return { status: 'notFound', html: '' };
      }
      return { status: 'error', html: '' };
    }
  }

  /** README html 响应解析：JSON 信封（{html}）或纯 HTML 流（实测 /readme 返回纯 HTML 而非 JSON 信封） */
  static parseHtmlBody(body: string): string {
    const env = Json.parse(body);
    if (env !== null) {
      const wrapped = Json.str(env, 'html');
      if (wrapped !== '') {
        return wrapped;
      }
    }
    return body;
  }

  /** 任意 Markdown → 官方 GFM HTML（041 评论预览；context 传入仓库名放大满链接） */
  static async renderMarkdown(token: string, text: string, context: string = ''): Promise<string> {
    const payload: Record<string, Object> = { 'text': text, 'mode': 'gfm' };
    if (context !== '') {
      payload['context'] = context;
    }
    const resp = await restPost('/markdown', token, JSON.stringify(payload), 'text/html');
    return resp.body;
  }

  /**
   * GitHub 站内链接 → 路由：/o/r → repoDetail、/o/r/issues/{n} → issueDetail、
   * /o/r/(pull|pulls)/{n} → prDetail、/o/r/blob/{path} → codeViewer。
   * 外站/未匹配返回 null（调用方一律系统浏览器外开）。
   */
  static routeOf(href: string): MarkdownRoute | null {
    const raw = href.trim();
    if (raw === '') {
      return null;
    }
    let path = raw;
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      const protoEnd = raw.indexOf('://');
      if (protoEnd < 0) {
        return null;
      }
      const rest = raw.substring(protoEnd + 3);
      const slash = rest.indexOf('/');
      const host = slash < 0 ? rest : rest.substring(0, slash);
      if (host !== 'github.com' && host !== 'www.github.com') {
        return null;
      }
      path = slash < 0 ? '/' : rest.substring(slash);
    } else if (!raw.startsWith('/')) {
      // 锚点 / data / mailto 等不路由
      return null;
    }
    const cut = path.search(/[?#]/);
    if (cut >= 0) {
      path = path.substring(0, cut);
    }
    const segs = path.split('/').filter((s: string) => s !== '');
    if (segs.length < 2) {
      return null;
    }
    const owner = segs[0];
    const repo = segs[1];
    if (segs.length === 2) {
      return { name: 'repoDetail', param: `${owner}/${repo}` };
    }
    const third = segs[2];
    if (third === 'issues' && segs.length >= 4) {
      return { name: 'issueDetail', param: `${owner}/${repo}/${segs[3]}` };
    }
    if ((third === 'pull' || third === 'pulls') && segs.length >= 4) {
      return { name: 'prDetail', param: `${owner}/${repo}/${segs[3]}` };
    }
    if (third === 'blob' && segs.length >= 4) {
      return { name: 'codeViewer', param: `${owner}|${repo}|${segs.slice(3).join('/')}` };
    }
    return null;
  }

  /** 超长折叠判定（html 字符数超过阈值才折叠；阈值可配，默认 4000） */
  static shouldCollapse(htmlLength: number, threshold: number): boolean {
    return threshold > 0 && htmlLength > threshold;
  }
}
