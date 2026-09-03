/**
 * GitHub 成就徽章服务（Profile 勋章行 + Spec 052 详情页）：
 * 徽章无 GraphQL/REST 字段，slug 列表从用户主页 tab=achievements 页面 HTML 抓取，
 * 详情从官方懒加载片段 /users/{login}/achievements/{slug}/detail 解析
 * （需 X-Requested-With: XMLHttpRequest，否则 406）。
 * 列表失败静默返回空数组（页面仅隐藏勋章行）；详情失败抛错（页面展示错误态/降级条目）。
 */
import { http } from '@kit.NetworkKit';
import { AchievementDetail, extractAchievementSlugs, parseAchievementDetail } from '../models/AchievementModels';

const ACHIEVEMENTS_CSS_URL = (login: string): string => `https://github.com/${login}?tab=achievements`;
const ACHIEVEMENT_DETAIL_URL = (login: string, slug: string): string =>
  `https://github.com/users/${login}/achievements/${slug}/detail`;
const ACHIEVEMENT_CDN = 'https://github.githubassets.com/images/modules/profile/achievements/';

export class AchievementsService {
  /** 已解锁徽章 slug 列表（按页面出现顺序、去重） */
  static async fetchSlugs(login: string): Promise<string[]> {
    if (login === '') {
      return [];
    }
    const text = await AchievementsService.getHtml(ACHIEVEMENTS_CSS_URL(login), '');
    return extractAchievementSlugs(text);
  }

  /** 已解锁徽章的官方图片 URL 列表（Profile 勋章行） */
  static async fetch(login: string): Promise<string[]> {
    const slugs = await AchievementsService.fetchSlugs(login);
    return slugs.map((slug: string): string => `${ACHIEVEMENT_CDN}${slug}-default.png`);
  }

  /** 单枚徽章详情（名称/描述/图/解锁时间/触发事件） */
  static async fetchDetail(login: string, slug: string): Promise<AchievementDetail> {
    const text = await AchievementsService.getHtml(ACHIEVEMENT_DETAIL_URL(login, slug), 'XMLHttpRequest');
    return parseAchievementDetail(text, slug, AchievementsService.cdnUrl(slug));
  }

  /** 兜底 CDN URL（无 hash 版，服务端仍有效） */
  static cdnUrl(slug: string): string {
    return `${ACHIEVEMENT_CDN}${slug}-default.png`;
  }

  private static async getHtml(url: string, xhr: string): Promise<string> {
    const req = http.createHttp();
    try {
      const header: Record<string, string> = { 'User-Agent': 'StarRaft' };
      if (xhr !== '') {
        header['X-Requested-With'] = xhr;
      }
      const resp = await req.request(url, {
        method: http.RequestMethod.GET,
        header: header,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 15000,
        readTimeout: 20000
      });
      return typeof resp.result === 'string' ? resp.result : '';
    } catch (e) {
      throw new Error('achievement fetch failed');
    } finally {
      req.destroy();
    }
  }
}
