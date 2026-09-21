/**
 * Shortcuts 个性化色板与图标表（Spec 074）。
 * 颜色 8 键走 resources shortcut_*_bg/fg 双套 token（暗色自动切换）；
 * 图标 36 键按官方 Create Shortcut 截图就近映射（行序一致，见 spec 074 §七）。
 * 含 $r 资源表，宿主单测不导入本模块。
 */
export interface ShortcutColorSpec {
  key: string;
  bg: Resource;
  fg: Resource;
}

export interface ShortcutIconSpec {
  key: string;
  res: Resource;
}

/** 颜色板（创建页横滚 7 格，用户 2026-09-21 定案去掉从右往左第二个 purple；gray 为默认选中） */
export const SHORTCUT_COLORS: ShortcutColorSpec[] = [
  { key: 'gray', bg: $r('app.color.shortcut_zap_bg'), fg: $r('app.color.shortcut_gray_fg') },
  { key: 'blue', bg: $r('app.color.shortcut_blue_bg'), fg: $r('app.color.shortcut_blue_fg') },
  { key: 'green', bg: $r('app.color.shortcut_green_bg'), fg: $r('app.color.shortcut_green_fg') },
  { key: 'orange', bg: $r('app.color.shortcut_orange_bg'), fg: $r('app.color.shortcut_orange_fg') },
  { key: 'red', bg: $r('app.color.shortcut_red_bg'), fg: $r('app.color.shortcut_red_fg') },
  { key: 'pink', bg: $r('app.color.shortcut_pink_bg'), fg: $r('app.color.shortcut_pink_fg') },
  { key: 'indigo', bg: $r('app.color.shortcut_indigo_bg'), fg: $r('app.color.shortcut_indigo_fg') }
];

/** 图标网格（固定 7 列分块 × 5 行 + 末行 inbox 单枚居中，默认选中 zap；2026-09-21 用户对齐官方校正：
 *  第2格 issue-opened，第2行 file-diff/code-review/codescan，第5行 hubot/dependabot） */
export const SHORTCUT_ICONS: ShortcutIconSpec[] = [
  { key: 'zap', res: $r('app.media.oct_zap_16') },
  { key: 'issue_opened', res: $r('app.media.oct_issue_opened_16') },
  { key: 'pull_request', res: $r('app.media.oct_git_pull_request_16') },
  { key: 'discussion', res: $r('app.media.oct_comment_discussion_16') },
  { key: 'organization', res: $r('app.media.oct_organization_16') },
  { key: 'people', res: $r('app.media.oct_people_16') },
  { key: 'briefcase', res: $r('app.media.oct_briefcase_16') },
  { key: 'file_diff', res: $r('app.media.oct_file_diff_16') },
  { key: 'code_review', res: $r('app.media.oct_code_review_16') },
  { key: 'codescan', res: $r('app.media.oct_codescan_16') },
  { key: 'comment', res: $r('app.media.oct_comment_16') },
  { key: 'copilot', res: $r('app.media.oct_copilot_16') },
  { key: 'terminal', res: $r('app.media.oct_terminal_16') },
  { key: 'tools', res: $r('app.media.oct_tools_16') },
  { key: 'beaker', res: $r('app.media.oct_beaker_16') },
  { key: 'alert', res: $r('app.media.oct_alert_16') },
  { key: 'eye', res: $r('app.media.oct_eye_16') },
  { key: 'telescope', res: $r('app.media.oct_telescope_16') },
  { key: 'bookmark', res: $r('app.media.oct_bookmark_16') },
  { key: 'calendar', res: $r('app.media.oct_calendar_16') },
  { key: 'meter', res: $r('app.media.oct_meter_16') },
  { key: 'moon', res: $r('app.media.oct_moon_16') },
  { key: 'sun', res: $r('app.media.oct_sun_16') },
  { key: 'flame', res: $r('app.media.oct_flame_16') },
  { key: 'globe', res: $r('app.media.oct_globe_16') },
  { key: 'bug', res: $r('app.media.oct_bug_16') },
  { key: 'north_star', res: $r('app.media.oct_north_star_16') },
  { key: 'rocket', res: $r('app.media.oct_rocket_16') },
  { key: 'squirrel', res: $r('app.media.oct_squirrel_16') },
  { key: 'hubot', res: $r('app.media.oct_hubot_16') },
  { key: 'dependabot', res: $r('app.media.oct_dependabot_16') },
  { key: 'clock', res: $r('app.media.oct_clock_16') },
  { key: 'mention', res: $r('app.media.oct_mention_16') },
  { key: 'smiley', res: $r('app.media.oct_smiley_16') },
  { key: 'person', res: $r('app.media.oct_person_16') },
  { key: 'inbox', res: $r('app.media.oct_inbox_16') }
];

/** 图标网格外补充表：仅建议字形等非个性化网格场景使用（不进创建页 36 格网格） */
export const SHORTCUT_EXTRA_ICONS: ShortcutIconSpec[] = [
  { key: 'repo_forked', res: $r('app.media.oct_repo_forked_16') },
  { key: 'git_compare', res: $r('app.media.oct_git_compare_16') },
  { key: 'code_review', res: $r('app.media.oct_code_review_16') }
];

/** 键 → 颜色对（未知键兜底 gray） */
export function shortcutColor(key: string): ShortcutColorSpec {
  for (const c of SHORTCUT_COLORS) {
    if (c.key === key) {
      return c;
    }
  }
  return SHORTCUT_COLORS[0];
}

/** 键 → 图标资源（网格表 + 网格外补充表；未知键兜底 zap） */
export function shortcutIconRes(key: string): Resource {
  for (const i of SHORTCUT_ICONS) {
    if (i.key === key) {
      return i.res;
    }
  }
  for (const i of SHORTCUT_EXTRA_ICONS) {
    if (i.key === key) {
      return i.res;
    }
  }
  return $r('app.media.oct_zap_16');
}

/** 建议快捷方式（管理页 Suggested 区）：全局 3 条固定 + 仓库建议由页面按 viewer 仓库拼装 */
export interface ShortcutSuggestion {
  sugKey: string;
  iconKey: string;
  iconRes: Resource;
  colorKey: string;
  /** 首行文案（全局建议为类型名；仓库建议由页面拼「owner / name」替代） */
  headRes: Resource;
  /** 次行说明文案，同时是保存时的默认名 */
  labelRes: Resource;
  kind: string;
  query: string;
}

/** 全局 3 条建议（默认态：Open + Created-desc，与官方仓库建议口径一致） */
export function globalShortcutSuggestions(): ShortcutSuggestion[] {
  return [
    {
      sugKey: 'mentioned',
      iconKey: 'eye',
      iconRes: $r('app.media.oct_eye_16'),
      colorKey: 'green',
      headRes: $r('app.string.home_work_issues'),
      labelRes: $r('app.string.shortcut_sugg_mentioned'),
      kind: 'issues',
      query: 'is:open mentions:@me sort:created-desc'
    },
    {
      sugKey: 'assigned',
      iconKey: 'repo_forked',
      iconRes: $r('app.media.oct_repo_forked_16'),
      colorKey: 'red',
      headRes: $r('app.string.home_work_issues'),
      labelRes: $r('app.string.shortcut_sugg_assigned'),
      kind: 'issues',
      query: 'is:open assignee:@me sort:created-desc'
    },
    {
      sugKey: 'review_requested',
      iconKey: 'code_review',
      iconRes: $r('app.media.oct_code_review_16'),
      colorKey: 'blue',
      headRes: $r('app.string.home_work_pull_requests'),
      labelRes: $r('app.string.shortcut_sugg_review_requested'),
      kind: 'prs',
      query: 'is:open review-requested:@me sort:created-desc'
    }
  ];
}

/** 仓库建议的字形/颜色（截图为蓝色分支比对字形，就近映射） */
export const REPO_SUGGESTION_ICON_KEY: string = 'git_compare';
export const REPO_SUGGESTION_ICON: Resource = $r('app.media.oct_git_compare_16');
export const REPO_SUGGESTION_COLOR_KEY: string = 'blue';
