/**
 * GitHub 成就徽章服务（Profile 勋章行）：
 * 徽章无 GraphQL/REST 字段，从用户主页 tab=achievements 页面 HTML
 * 抓取已领取徽章的 slug（?achievement=<slug> 链接），组装官方 CDN 图片 URL。
 * 失败静默返回空数组，页面仅隐藏勋章行。
 */
import { http } from '@kit.NetworkKit';

const ACHIEVEMENTS_CSS_URL = (login: string): string => `https://github.com/${login}?tab=achievements`;
const ACHIEVEMENT_CDN = 'https://github.githubassets.com/images/modules/profile/achievements/';

export class AchievementsService {
  /** 返回已领取徽章的官方图片 URL 列表（按页面出现顺序、去重） */
  static async fetch(login: string): Promise<string[]> {
    if (login === '') {
      return [];
    }
    const req = http.createHttp();
    try {
      const resp = await req.request(ACHIEVEMENTS_CSS_URL(login), {
        method: http.RequestMethod.GET,
        header: { 'User-Agent': 'StarRaft' },
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 15000,
        readTimeout: 20000
      });
      const text = typeof resp.result === 'string' ? resp.result : '';
      const slugs: string[] = [];
      const re = /achievement=([a-z0-9-]+)[&"]/g;
      let m: RegExpExecArray | null = re.exec(text);
      while (m !== null) {
        const slug = m[1] ?? '';
        if (slugs.indexOf(slug) === -1) {
          slugs.push(slug);
        }
        m = re.exec(text);
      }
      return slugs.map((slug: string): string => `${ACHIEVEMENT_CDN}${slug}-default.png`);
    } catch (e) {
      return [];
    } finally {
      req.destroy();
    }
  }
}
