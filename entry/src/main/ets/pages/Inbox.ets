/**
 * Inbox Tab（Spec 002）：官方四筛选（Inbox▾/Focused/Unread/Repository▾）+ 通知卡片。
 * Inbox▾/Repository▾ 为底部 sheet 面板（官方「Filter notifications by」/「Filter by repository」）：
 * 视图单选（Inbox/Saved/Done）+ 类型多选（reason 本地过滤）、仓库单选列表（头像+计数+搜索）。
 * 卡片=仓库+编号 / 标题粗体 / 类型图标+摘要 / 右侧相对时间；点击标记已读。
 * 详情页为 Spec 008/009 范围，当前点击仅标记已读并提示。
 */
import { promptAction } from '@kit.ArkUI';
import { NotificationItem, issueNumberFromUrl } from '../models/GitHubModels';
import {
  NotificationsService, filterByInboxView, filterByReasons, collectRepoFilters,
  InboxRepoFilterItem, InboxReasonKey
} from '../services/NotificationsService';
import { StateView } from '../components/StateView';
import { OctIcon } from '../components/OctIcon';
import { PageShadowBar } from '../components/PageShadowBar';
import { timeParts, githubShortTime, notificationTypeKey, TimeParts } from '../utils/Format';
import { resText } from '../utils/I18n';

type InboxFilter = 'inbox' | 'focused' | 'unread' | 'repo';

/** 视图组（单选）：inbox=全部；saved/done 本地近似，见 filterByInboxView */
const VIEWS: string[] = ['inbox', 'saved', 'done'];

/** 行元素（@Builder 传值参数不随状态刷新，须按引用传参） */
interface RowState {
  label: string;
  selected: boolean;
  emoji: string;
}

/** 类型组选项（key + 官方 emoji 图标 + 文案资源） */
interface ReasonOption {
  key: InboxReasonKey;
  emoji: string;
  labelRes: Resource;
}

@ComponentV2
export struct InboxView {
  /** 类型组（多选）：emoji 为官方 App 面板同款系统 emoji（Spec 002） */
  private static readonly REASONS: ReasonOption[] = [
    { key: 'assign', emoji: '🛡️', labelRes: $r('app.string.inbox_filter_assigned') },
    { key: 'participating', emoji: '💬', labelRes: $r('app.string.inbox_filter_participating') },
    { key: 'mention', emoji: '👋', labelRes: $r('app.string.inbox_filter_mentioned') },
    { key: 'team_mention', emoji: '🙌', labelRes: $r('app.string.inbox_filter_team_mentioned') },
    { key: 'review_requested', emoji: '🔍', labelRes: $r('app.string.inbox_filter_review_requested') }
  ];

  @Param token: string = '';
  @Local filter: InboxFilter = 'inbox';
  @Local repoFilter: string = '';
  /** 下拉面板内容（'' | 'filters' | 'repo'）：同一组件只挂一个 bindSheet，内部切换 */
  @Local sheetKind: string = '';
  @Local inboxView: string = 'inbox';
  @Local reasonKeys: InboxReasonKey[] = [];
  @Local repoFilters: InboxRepoFilterItem[] = [];
  @Local repoSearch: string = '';
  @Local repoSearchShow: boolean = false;
  @Local items: NotificationItem[] = [];
  @Local rawItems: NotificationItem[] = [];
  @Local loading: boolean = true;
  @Local errorMsg: string = '';
  /** 滚动顶部阴影（滚动中显示、回顶消失） */
  @Local scrollShadow: boolean = false;

  aboutToAppear(): void {
    this.refresh();
  }

  /** 拉取后：聚合仓库候选 → 本地链式过滤（视图 → 类型 → 仓库） */
  private refresh(): void {
    this.loading = true;
    this.errorMsg = '';
    NotificationsService.fetchNotifications(this.token, this.filter !== 'unread', 30, this.filter === 'focused')
      .then((items: NotificationItem[]) => {
        this.rawItems = items;
        this.repoFilters = collectRepoFilters(items);
        this.applyFilters();
        this.loading = false;
      })
      .catch((e: Error) => {
        this.errorMsg = e.message;
        this.loading = false;
      });
  }

  /** 本地过滤链（面板选择后无需重新请求，纯函数见 NotificationsService） */
  private applyFilters(): void {
    let list = filterByInboxView(this.rawItems, this.inboxView);
    list = filterByReasons(list, this.reasonKeys);
    if (this.filter === 'repo' && this.repoFilter !== '') {
      list = list.filter((it: NotificationItem) => it.repoFullName === this.repoFilter);
    }
    this.items = list;
  }

  /** Focused/Unread/回退 Inbox：服务端参数不同，需重新拉取 */
  private switchFilter(f: InboxFilter): void {
    if (this.filter === f) {
      return;
    }
    this.filter = f;
    this.refresh();
  }

  /** 视图单选：立即生效并关闭面板；数据源非 Inbox 时先切回重拉 */
  private selectView(v: string): void {
    this.inboxView = v;
    this.sheetKind = '';
    if (this.filter === 'inbox') {
      this.applyFilters();
    } else {
      this.filter = 'inbox';
      this.refresh();
    }
  }

  /** 类型多选：toggle 后保持面板打开，可继续多选 */
  private toggleReason(key: InboxReasonKey): void {
    const idx = this.reasonKeys.indexOf(key);
    if (idx >= 0) {
      this.reasonKeys.splice(idx, 1);
    } else {
      this.reasonKeys.push(key);
    }
    if (this.filter === 'inbox') {
      this.applyFilters();
    } else {
      this.filter = 'inbox';
      this.refresh();
    }
  }

  /** 仓库单选：点已选项取消（回到 Inbox 视图全量），选中即关 */
  private toggleRepoFilter(fullName: string): void {
    if (this.repoFilter === fullName) {
      this.repoFilter = '';
      this.filter = 'inbox';
    } else {
      this.repoFilter = fullName;
      this.filter = 'repo';
    }
    this.sheetKind = '';
    if (this.filter === 'repo' || this.rawLoadedAll()) {
      this.applyFilters();
    } else {
      this.refresh();
    }
  }

  /** 当前 rawItems 是否来自 Inbox 数据源（all=true）；focused/unread 拉取的是受限子集 */
  private rawLoadedAll(): boolean {
    return this.filter === 'inbox' || this.filter === 'repo';
  }

  /** 仓库搜索过滤（不区分大小写） */
  private filteredRepos(): InboxRepoFilterItem[] {
    const q = this.repoSearch.toLowerCase();
    if (q === '') {
      return this.repoFilters;
    }
    return this.repoFilters.filter((r: InboxRepoFilterItem) => r.fullName.toLowerCase().indexOf(q) >= 0);
  }

  private markRead(item: NotificationItem): void {
    if (!item.unread) {
      promptAction.showToast({ message: $r('app.string.inbox_detail_coming') });
      return;
    }
    NotificationsService.markThreadRead(this.token, item.threadId)
      .then(() => {
        this.items = this.items.map((it: NotificationItem) => {
          const copy: NotificationItem = {
            threadId: it.threadId,
            repoFullName: it.repoFullName,
            title: it.title,
            subjectType: it.subjectType,
            reason: it.reason,
            unread: it.threadId === item.threadId ? false : it.unread,
            updatedAt: it.updatedAt,
            subjectUrl: it.subjectUrl,
            ownerAvatarUrl: it.ownerAvatarUrl,
            prMerged: it.prMerged
          };
          return copy;
        });
        promptAction.showToast({ message: $r('app.string.inbox_marked_read') });
        // 通知 Index 重算未读蓝点（review A4）
        AppStorage.setOrCreate('inboxUnreadTick', Date.now());
      })
      .catch((e: Error) => {
        promptAction.showToast({ message: this.fmt($r('app.string.inbox_mark_failed'), e.message) });
      });
  }

  /** 带 %1$s 格式化：资源模板 + 参数 → 当前语言文案 */
  private fmt(res: Resource, arg: string): string {
    return resText(this.getUIContext(), res, arg);
  }

  /** 资源 → 当前语言的纯文案 */
  private stringOf(res: Resource): string {
    return resText(this.getUIContext(), res);
  }

  /** subject.type → 本地化标签；未知 key 透传原文（Spec 012） */
  private notifTypeLabel(subjectType: string): string {
    const ui = this.getUIContext();
    switch (notificationTypeKey(subjectType)) {
      case 'issue':
        return resText(ui, $r('app.string.notif_type_issue'));
      case 'pr':
        return resText(ui, $r('app.string.notif_type_pr'));
      case 'release':
        return resText(ui, $r('app.string.notif_type_release'));
      case 'ci':
        return resText(ui, $r('app.string.notif_type_ci'));
      case 'discussion':
        return resText(ui, $r('app.string.notif_type_discussion'));
      case 'security':
        return resText(ui, $r('app.string.notif_type_security'));
      default:
        return subjectType;
    }
  }

  /** 通知类型 → 图标（Inbox 卡片左上角；PR 已合并显示 merge 图标） */
  private notifIconRes(subjectType: string, isMerged: boolean): Resource {
    switch (notificationTypeKey(subjectType)) {
      case 'issue':
        return $r('app.media.oct_issue_opened_16');
      case 'pr':
        return isMerged ? $r('app.media.oct_git_merge_16') : $r('app.media.oct_git_pull_request_16');
      case 'release':
        return $r('app.media.oct_tag_16');
      case 'ci':
        return $r('app.media.oct_check_16');
      case 'discussion':
        return $r('app.media.oct_comment_discussion_16');
      case 'security':
        return $r('app.media.oct_alert_16');
      default:
        return $r('app.media.oct_issue_opened_16');
    }
  }

  /** 通知类型 → 图标颜色：issue/PR 绿、PR 合并紫、讨论紫、Release 橙、CI 绿、安全红、未知灰 */
  private notifIconColor(subjectType: string, isMerged: boolean): ResourceColor {
    switch (notificationTypeKey(subjectType)) {
      case 'issue':
      case 'ci':
        return $r('app.color.success_text');
      case 'pr':
        return isMerged ? $r('app.color.shortcut_purple_fg') : $r('app.color.success_text');
      case 'release':
        return $r('app.color.shortcut_orange_fg');
      case 'discussion':
        return $r('app.color.shortcut_purple_fg');
      case 'security':
        return $r('app.color.badge_red');
      default:
        return $r('app.color.text_secondary');
    }
  }

  /** 时间戳 → GitHub 风格相对时间（22h/1d/8d）；解析失败回退空串 */
  private shortTime(item: NotificationItem): string {
    const parts: TimeParts | null = timeParts(item.updatedAt, Date.now());
    return parts !== null ? githubShortTime(parts) : '';
  }

  /** Inbox▾ chip 文本随当前视图（inbox/saved/done） */
  private viewLabel(): string {
    const ui = this.getUIContext();
    switch (this.inboxView) {
      case 'saved':
        return resText(ui, $r('app.string.inbox_view_saved'));
      case 'done':
        return resText(ui, $r('app.string.inbox_view_done'));
      default:
        return resText(ui, $r('app.string.inbox_menu_inbox'));
    }
  }

  /** 视图 label（面板选项文本） */
  private viewOptionLabel(v: string): string {
    const ui = this.getUIContext();
    switch (v) {
      case 'saved':
        return resText(ui, $r('app.string.inbox_view_saved'));
      case 'done':
        return resText(ui, $r('app.string.inbox_view_done'));
      default:
        return resText(ui, $r('app.string.inbox_menu_inbox'));
    }
  }

  /** chip 公共样式（@Styles 不支持参数：文本/背景等动态部分行内设置） */
  @Styles
  filterPillStyle() {
    .height(30)
    .padding({ left: 12, right: 10 })
    .borderRadius(12)
    .border({ width: 1, color: $r('app.color.border') })
  }

  /** 面板头部：✕ 关闭 + 粗体标题（+ 可选蓝色搜索钮，官方 repo 面板样式） */
  @Builder
  sheetHeader(title: Resource, showSearch: boolean, onSearchToggle: () => void) {
    Row() {
      Stack() {
        OctIcon({ res: $r('app.media.oct_x_16'), iconSize: 18, iconColor: $r('app.color.text_primary') })
      }
      .width(44)
      .height(44)
      .onClick((): void => {
        this.sheetKind = '';
      })
      Text(title)
        .fontSize($r('app.float.title_font_size'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
      if (showSearch) {
        Stack() {
          OctIcon({ res: $r('app.media.oct_search_24'), iconSize: 18, iconColor: $r('app.color.link_blue') })
        }
        .width(44)
        .height(44)
        .onClick(onSearchToggle)
      } else {
        Blank()
          .width(44)
      }
    }
    .padding({ left: 8, right: 8 })
  }

  /** 面板行：可选 emoji 图标 + 选项文本 + 选中蓝勾（$$ 引用参数随状态刷新） */
  @Builder
  sheetRow($$: RowState, onClick: () => void) {
    Row() {
      if ($$.emoji !== '') {
        Text($$.emoji)
          .fontSize(22)
          .width(32)
          .textAlign(TextAlign.Center)
          .margin({ right: 8 })
      }
      Text($$.label)
        .fontSize($r('app.float.body_font_size'))
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
      if ($$.selected) {
        OctIcon({ res: $r('app.media.oct_check_16'), iconSize: 16, iconColor: $r('app.color.link_blue') })
          .margin({ left: 8 })
      }
    }
    .width('100%')
    .height(52)
    .padding({ left: 16, right: 16 })
    .onClick(onClick)
  }

  /** 面板一：Filter notifications by（视图单选组 + 分割线 + 类型多选组） */
  @Builder
  filtersSheet() {
    Column() {
      this.sheetHeader($r('app.string.inbox_filter_title'), false, (): void => { })
      ForEach(VIEWS, (v: string) => {
        this.sheetRow({
          label: this.viewOptionLabel(v),
          selected: this.inboxView === v,
          emoji: ''
        }, (): void => this.selectView(v))
      }, (v: string) => v)
      Divider()
        .color($r('app.color.divider'))
        .strokeWidth(1)
        .margin({ top: 4, bottom: 4 })
        .width('100%')
      ForEach(InboxView.REASONS, (r: ReasonOption) => {
        this.sheetRow({
          label: this.stringOf(r.labelRes),
          selected: this.reasonKeys.indexOf(r.key) >= 0,
          emoji: r.emoji
        }, (): void => this.toggleReason(r.key))
      }, (r: ReasonOption) => r.key)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.card_background'))
  }

  /** 面板二：Filter by repository（✕+标题+蓝色放大镜，仓库行=头像+名称+计数） */
  @Builder
  repsSheet() {
    Column() {
      this.sheetHeader($r('app.string.inbox_repo_filter_title'), true, (): void => {
        this.repoSearchShow = !this.repoSearchShow;
      })
      if (this.repoSearchShow) {
        TextInput({ placeholder: this.stringOf($r('app.string.search_placeholder')), text: this.repoSearch })
          .height(40)
          .fontSize($r('app.float.body_font_size'))
          .margin({ left: 16, right: 16, bottom: 4 })
          .borderRadius(8)
          .backgroundColor($r('app.color.chip_bg'))
          .onChange((v: string): void => {
            this.repoSearch = v;
          })
      }
      Scroll() {
        Column() {
          ForEach(this.filteredRepos(), (r: InboxRepoFilterItem) => {
            this.repoRow(r)
          }, (r: InboxRepoFilterItem) => r.fullName)
        }
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.card_background'))
  }

  /** 仓库行：方形圆角属主头像 + owner/repo + 右侧计数（选中蓝勾） */
  @Builder
  repoRow(r: InboxRepoFilterItem) {
    Row({ space: 12 }) {
      Image(r.avatarUrl)
        .width(40)
        .height(40)
        .borderRadius(8)
        .backgroundColor($r('app.color.chip_bg'))
      Text(r.fullName)
        .fontSize($r('app.float.body_font_size'))
        .fontColor($r('app.color.text_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
      Text(`${r.count}`)
        .fontSize($r('app.float.body_font_size'))
        .fontColor($r('app.color.text_secondary'))
        .margin({ right: 8 })
      if (this.repoFilter === r.fullName && this.filter === 'repo') {
        OctIcon({ res: $r('app.media.oct_check_16'), iconSize: 16, iconColor: $r('app.color.link_blue') })
          .margin({ left: 8 })
      }
    }
    .width('100%')
    .height(56)
    .padding({ left: 16, right: 16 })
    .onClick((): void => this.toggleRepoFilter(r.fullName))
  }

  /** 弹层分派（单个 bindSheet 内切换内容，规避同组件多 bindSheet 失效） */
  @Builder
  overlaySheet() {
    if (this.sheetKind === 'filters') {
      this.filtersSheet()
    } else if (this.sheetKind === 'repo') {
      this.repsSheet()
    } else {
      Column()
        .width('100%')
        .height('100%')
    }
  }

  /** 卡片编号行：编号非空才显示（方法返回，供 @Builder 内 if 判断） */
  private issueNum(item: NotificationItem): string {
    return issueNumberFromUrl(item.subjectUrl);
  }

  @Builder
  notifyCard(item: NotificationItem) {
    Row({ space: 8 }) {
      // 左上角：通知类型图标（带色，PR 已合并为紫色 merge）；未读状态由标题加粗表达
      Stack() {
        OctIcon({ res: this.notifIconRes(item.subjectType, item.prMerged), iconSize: 16, iconColor: this.notifIconColor(item.subjectType, item.prMerged) })
      }
      .width(24)
      .height(24)
      .margin({ top: 1 })
      Column({ space: 2 }) {
        Row({ space: 4 }) {
          Text(item.repoFullName)
            .fontSize($r('app.float.caption_font_size'))
            .fontColor($r('app.color.text_secondary'))
            .maxLines(1)
          if (this.issueNum(item) !== '') {
            Text(`#${this.issueNum(item)}`)
              .fontSize($r('app.float.caption_font_size'))
              .fontColor($r('app.color.text_secondary'))
          }
          Blank()
          Text(this.shortTime(item))
            .fontSize($r('app.float.caption_font_size'))
            .fontColor($r('app.color.text_secondary'))
        }
        .width('100%')

        Text(item.title)
          .fontSize($r('app.float.body_font_size'))
          .fontWeight(item.unread ? FontWeight.Bold : FontWeight.Normal)
          .fontColor($r('app.color.text_primary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        Row({ space: 4 }) {
          // 底行前：仓库属主头像（REST owner.avatar_url，缺失占位灰圆）
          Image(item.ownerAvatarUrl)
            .width(16)
            .height(16)
            .borderRadius(8)
            .backgroundColor($r('app.color.heat_empty'))
          Text(this.subjectLine(item))
            .fontSize($r('app.float.caption_font_size'))
            .fontColor($r('app.color.text_secondary'))
            .maxLines(1)
        }
        .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .alignItems(VerticalAlign.Top)
    .width('100%')
    .padding($r('app.float.card_padding'))
    .borderRadius($r('app.float.card_radius'))
    .backgroundColor($r('app.color.card_background'))
    .margin({ bottom: 8 })
    .onClick(() => this.markRead(item))
  }

  /** 通知副行：类型 · reason（API 原文）（Spec 002 摘要降级） */
  private subjectLine(item: NotificationItem): string {
    return `${this.notifTypeLabel(item.subjectType)} · ${item.reason}`;
  }

  build() {
    Column() {
      Row() {
        Text($r('app.string.tab_inbox'))
          .fontSize($r('app.float.title_font_size'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Blank()
        Stack() {
  OctIcon({
          res: $r('app.media.oct_kebab_horizontal_16'),
          iconSize: 18,
          iconColor: $r('app.color.link_blue')
  })
  .rotate({ angle: 90 })
}
.width(44)
.height(44)
        .accessibilityDescription($r('app.string.a11y_more'))
        .focusable(true)
.bindMenu([
          {
            value: $r('app.string.inbox_menu_refresh'),
            action: (): void => this.refresh()
          }
        ])
        .padding(4)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 8 })

      PageShadowBar({ show: this.scrollShadow })

      Scroll() {
        // 四个筛选 chip 内联渲染：@Builder 传值/$$ 引用参数均不随状态刷新（V2 坑，见 memory），
        // 文本/激活态直接读 @Local 才能随筛选变化实时更新
        Row({ space: 8 }) {
        Row() {
          Text(this.viewLabel())
            .fontSize($r('app.float.caption_font_size'))
            .fontColor(this.filter === 'inbox' ? $r('app.color.link_blue') : $r('app.color.text_primary'))
          OctIcon({
            res: $r('app.media.oct_chevron_down_16'),
            iconSize: 12,
            iconColor: this.filter === 'inbox' ? $r('app.color.link_blue') : $r('app.color.text_secondary')
          })
            .margin({ left: 4 })
        }
        .filterPillStyle()
        .backgroundColor(this.filter === 'inbox' ? $r('app.color.chip_active_green_bg') : $r('app.color.card_background'))
        .onClick((): void => { this.sheetKind = 'filters'; })

        Row() {
          Text(this.stringOf($r('app.string.inbox_menu_focused')))
            .fontSize($r('app.float.caption_font_size'))
            .fontColor(this.filter === 'focused' ? $r('app.color.link_blue') : $r('app.color.text_primary'))
        }
        .filterPillStyle()
        .backgroundColor(this.filter === 'focused' ? $r('app.color.chip_active_green_bg') : $r('app.color.card_background'))
        .onClick((): void => this.switchFilter('focused'))

        Row() {
          Text(this.stringOf($r('app.string.inbox_menu_unread')))
            .fontSize($r('app.float.caption_font_size'))
            .fontColor(this.filter === 'unread' ? $r('app.color.link_blue') : $r('app.color.text_primary'))
        }
        .filterPillStyle()
        .backgroundColor(this.filter === 'unread' ? $r('app.color.chip_active_green_bg') : $r('app.color.card_background'))
        .onClick((): void => this.switchFilter('unread'))

        Row() {
          Text(this.repoFilter !== '' ? this.repoFilter : this.stringOf($r('app.string.inbox_menu_repository')))
            .fontSize($r('app.float.caption_font_size'))
            .fontColor(this.filter === 'repo' ? $r('app.color.link_blue') : $r('app.color.text_primary'))
          OctIcon({
            res: $r('app.media.oct_chevron_down_16'),
            iconSize: 12,
            iconColor: this.filter === 'repo' ? $r('app.color.link_blue') : $r('app.color.text_secondary')
          })
            .margin({ left: 4 })
        }
        .filterPillStyle()
        .backgroundColor(this.filter === 'repo' ? $r('app.color.chip_active_green_bg') : $r('app.color.card_background'))
        .onClick((): void => { this.sheetKind = 'repo'; })
      }
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .padding({ left: 16, right: 16, bottom: 8 })

      Scroll() {
        // 独立卡片列表：每张通知自带圆角与间距（同 Pull Requests 列表样式）
        Column() {
          if (this.items.length > 0) {
            ForEach(this.items, (item: NotificationItem) => {
              this.notifyCard(item)
            }, (item: NotificationItem) => item.threadId)
          } else {
            StateView({
              loading: this.loading,
              error: this.errorMsg,
              empty: !this.loading && this.errorMsg === '',
              emptyText: this.emptyText()
            })
          }
        }
        .padding({ left: 16, right: 16, bottom: 16 })
        .width('100%')
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
      .onScroll((_x: number, y: number): void => {
        this.scrollShadow = y > 0.001;
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_page'))
    .bindSheet(this.sheetKind !== '', this.overlaySheet(), {
      height: 600,
      backgroundColor: $r('app.color.card_background'),
      // 关闭钮与标题行均自绘，避免默认 ✕ 与自绘按钮重叠
      showClose: false
    })
  }

  /** 空态文案：按当前视图给出（Saved/Done 视图无数据时更贴切） */
  private emptyText(): Resource {
    if (this.inboxView === 'saved') {
      return $r('app.string.inbox_saved_empty');
    }
    if (this.inboxView === 'done' && this.reasonKeys.length === 0 && this.repoFilter === '') {
      return $r('app.string.inbox_done_empty');
    }
    return $r('app.string.inbox_empty');
  }
}
