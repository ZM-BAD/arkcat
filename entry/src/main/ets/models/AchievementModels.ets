/**
 * GitHub 成就徽章模型（Spec 052 详情页 + 复用 Spec 005 勋章行）：
 * 徽章无 GraphQL/REST 字段，slug 列表与详情均来自官方页面 HTML，
 * 解析函数保持纯函数，便于单元测试（失败由服务层降级/页面兜底）。
 */

/** 单次达成事件（引用 + 标签；私有仓库引用不可见时 ref 为 ''） */
export interface AchievementEvent {
  /** 触发事件引用（owner/repo #N）；inaccessible/缺失为 '' */
  ref: string;
  /** 触发事件标签（Merged without a review 等） */
  label: string;
}

/** 成就徽章详情（一页） */
export interface AchievementDetail {
  /** 徽章 slug（yolo/quickdraw/…，兼作翻页 key） */
  slug: string;
  /** 名称（YOLO） */
  name: string;
  /** 描述（You want it? You merge it.） */
  description: string;
  /** 官方徽章图（详情片段内 hash 版；解析失败为兜底 CDN URL） */
  badgeImageUrl: string;
  /** 官方详情主题横幅图（纯色主题底，官方详情头图即背景；未解析到为 ''） */
  detailBgUrl: string;
  /** 解锁时间 ISO UTC（relative-time datetime）；未解析到为 '' */
  unlockedAt: string;
  /** 达成事件列表（多次达成/多 tier 时多条；无则空数组，UI 隐藏区域） */
  events: AchievementEvent[];
}

/** tab=achievements 页面 → 已解锁 slug 列表（按页面顺序、去重） */
export function extractAchievementSlugs(html: string): string[] {
  const slugs: string[] = [];
  const re = /achievement=([a-z0-9-]+)[&"]/g;
  let m: RegExpExecArray | null = re.exec(html);
  while (m !== null) {
    const slug = m[1] ?? '';
    if (slug !== '' && slugs.indexOf(slug) === -1) {
      slugs.push(slug);
    }
    m = re.exec(html);
  }
  return slugs;
}

/**
 * 详情懒加载片段 → AchievementDetail。
 * 片段结构：h3 名称 / div.mt-1 描述 / tier-badge 图 / relative-time 解锁 /
 * .achievement-history-tier 内「引用 · 事件标签」（引用可能为 inaccessible）。
 */
export function parseAchievementDetail(html: string, slug: string, fallbackImageUrl: string): AchievementDetail {
  const nameMatch = /<h3[^>]*>([^<]+)<\/h3>/.exec(html);
  if (nameMatch === null || (nameMatch[1] ?? '') === '') {
    throw new Error('achievement detail parse failed');
  }
  const descMatch = /<div class="mt-1">([^<]+)<\/div>/.exec(html);
  let badgeImageUrl = fallbackImageUrl;
  const imgTag = /<img\b[^>]*\bdata-targets="achievement-badge-flip\.tiers"[^>]*>/.exec(html);
  if (imgTag !== null) {
    const src = /src="([^"]+)"/.exec(imgTag[0]);
    if (src !== null && (src[1] ?? '') !== '') {
      badgeImageUrl = src[1] ?? '';
    }
  }
  const timeMatch = /<relative-time[^>]*datetime="([^"]+)"/.exec(html);
  // 详情头图 div 的 background-image 即官方每徽章主题横幅（纯色底），页面用它铺满作整页背景
  const bgMatch = /background-image:\s*url\('([^']+)'\)/.exec(html);
  const events: AchievementEvent[] = [];
  // 每条「达成/层级」为一段 achievement-history-tier，内部为「引用 · 事件标签」（引用可为 inaccessible）
  const tierRegex = /achievement-history-tier/g;
  let tierMatch: RegExpExecArray | null = tierRegex.exec(html);
  while (tierMatch !== null) {
    const segStart = tierMatch.index;
    tierMatch = tierRegex.exec(html);
    const segEnd = tierMatch !== null ? tierMatch.index : html.length;
    const tierHtml = html.substring(segStart, segEnd);
    // tier body 兼容三种线上形态：
    // ① 「<a>引用</a> · <span>标签</span>」（Pull Shark/YOLO/Pair 等，标签内可嵌套 user-mention 链接）
    // ② 仅「<a>引用</a>」（Arctic Code Vault：被归档的仓库列表，无标签）
    // ③ 仅「<span>标签</span>」（Arctic Code Vault 尾注 these repositories... were archived）
    // ④ 「<span class="color-fg-muted">inaccessible</span> · <span>标签</span>」（私有仓库匿名不可见）
    const combined = /<span class="color-fg-muted">([^<]+)<\/span>\s*·\s*<span>([\s\S]*?)<\/span>/.exec(tierHtml) ??
      /<a[^>]*>([\s\S]*?)<\/a>\s*·\s*<span>([\s\S]*?)<\/span>/.exec(tierHtml);
    if (combined !== null) {
      const ref = (combined[1] ?? '').replace(/<[^>]*>/g, '').replace(/\s+/g, ' ').trim();
      const label = (combined[2] ?? '').replace(/<[^>]*>/g, '').replace(/\s+/g, ' ').trim();
      // 私有仓库匿名不可见：隐藏引用，仅保留事件标签（移动端因登录态可见原文）
      events.push({
        ref: ref === 'inaccessible' ? '' : ref,
        label: label
      });
    } else {
      // 形态②：body 内首个链接即引用（无标签）
      const refOnly = /<a[^>]*>([\s\S]*?)<\/a>/.exec(tierHtml);
      if (refOnly !== null) {
        events.push({
          ref: (refOnly[1] ?? '').replace(/<[^>]*>/g, '').replace(/\s+/g, ' ').trim(),
          label: ''
        });
      } else {
        // 形态③：纯文本标签（无引用）
        const labelOnly = /<span>([\s\S]*?)<\/span>/.exec(tierHtml);
        if (labelOnly !== null) {
          const label = (labelOnly[1] ?? '').replace(/<[^>]*>/g, '').replace(/\s+/g, ' ').trim();
          if (label !== '') {
            events.push({ ref: '', label: label });
          }
        }
      }
    }
  }
  return {
    slug: slug,
    name: (nameMatch[1] ?? '').trim(),
    description: descMatch !== null && descMatch[1] !== undefined ? (descMatch[1] ?? '').trim() : '',
    badgeImageUrl: badgeImageUrl,
    detailBgUrl: bgMatch !== null && bgMatch[1] !== undefined ? (bgMatch[1] ?? '').trim() : '',
    unlockedAt: timeMatch !== null && timeMatch[1] !== undefined ? (timeMatch[1] ?? '').trim() : '',
    events: events
  };
}
