/**
 * Inbox Tab（Spec 002）：官方四筛选（Inbox▾/Focused/Unread/Repository▾）+ 通知卡片。
 * Inbox▾/Repository▾ 为底部 sheet 面板（官方「Filter notifications by」/「Filter by repository」，
 * 面板组件化于 InboxFilterSheets）：视图单选（Inbox/Saved/Done）+ 类型多选（reason 本地过滤）、
 * 仓库单选列表（头像+计数+搜索）。卡片=仓库+编号 / 标题粗体 / 类型图标+摘要 / 右侧相对时间
 * （组件化于 InboxNotifyCard）；点击标记已读。
 * 详情页为 Spec 030/031 范围，当前点击仅标记已读并提示。
 */
import { promptAction } from '@kit.ArkUI';
import { NotificationItem } from '../models/GitHubModels';
import {
  NotificationsService, filterByInboxView, filterByReasons, collectRepoFilters,
  InboxRepoFilterItem, InboxReasonKey
} from '../services/NotificationsService';
import { StateView } from '../components/StateView';
import { friendlyError } from '../services/GitHttpClient';
import { OctIcon } from '../components/OctIcon';
import { AppBar, AppBarAction } from '../components/AppBar';
import { PageShadowBar } from '../components/PageShadowBar';
import { InboxNotifyCard } from '../components/InboxNotifyCard';
import { InboxFilterSheet, InboxRepoSheet } from '../components/InboxFilterSheets';
import { resText } from '../utils/I18n';

type InboxFilter = 'inbox' | 'focused' | 'unread' | 'repo';

@ComponentV2
export struct InboxView {
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
  @Local isRefreshing: boolean = false;

  aboutToAppear(): void {
    this.refresh();
  }

  /** Spec 049a：切换账号后 token 更新 → 用新 token 重拉（未读 badge 由 Index 侧同刻重算） */
  @Monitor('token')
  onTokenChanged(): void {
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
        this.isRefreshing = false;
      })
      .catch((e: Error) => {
        this.errorMsg = friendlyError(this.getUIContext(), e);
        this.loading = false;
        this.isRefreshing = false;
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
        // items 与 rawItems 同步标记，防止切筛选后已读态复活（review A5）
        const mark = (list: NotificationItem[]): NotificationItem[] => {
          return list.map((it: NotificationItem) => {
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
        };
        this.rawItems = mark(this.rawItems);
        this.items = mark(this.items);
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

  /** chip 公共样式（@Styles 不支持参数：文本/背景等动态部分行内设置） */
  @Styles
  filterPillStyle() {
    .height(30)
    .responseRegion({ x: 0, y: -7, width: '100%', height: '147%' })
    .padding({ left: 12, right: 10 })
    .borderRadius(12)
    .border({ width: 1, color: $r('app.color.border') })
  }

  /** 弹层分派（单个 bindSheet 内切换内容，规避同组件多 bindSheet 失效） */
  @Builder
  overlaySheet() {
    if (this.sheetKind === 'filters') {
      InboxFilterSheet({
        view: this.inboxView,
        selectedReasons: this.reasonKeys.map((k: InboxReasonKey): InboxReasonKey => k),
        onSelectView: (v: string): void => this.selectView(v),
        onToggleReason: (k: InboxReasonKey): void => this.toggleReason(k),
        onClose: (): void => {
          this.sheetKind = '';
        }
      })
    } else if (this.sheetKind === 'repo') {
      InboxRepoSheet({
        searchShow: this.repoSearchShow,
        search: this.repoSearch,
        repos: this.filteredRepos(),
        selectedFullName: this.repoFilter,
        selectedActive: this.filter === 'repo',
        onPick: (fullName: string): void => this.toggleRepoFilter(fullName),
        onClose: (): void => {
          this.sheetKind = '';
        },
        onSearchToggle: (): void => {
          this.repoSearchShow = !this.repoSearchShow;
        },
        onSearchChange: (v: string): void => {
          this.repoSearch = v;
        }
      })
    } else {
      Column()
        .width('100%')
        .height('100%')
    }
  }

  build() {
    Column() {
      AppBar({
        title: $r('app.string.tab_inbox'),
        actions: [
          new AppBarAction($r('app.media.oct_kebab_horizontal_16'), (): void => {}, {
            rotate90: true,
            a11y: $r('app.string.a11y_more'),
            menu: [
              {
                value: $r('app.string.inbox_menu_refresh'),
                action: (): void => this.refresh()
              }
            ]
          })
        ]
      })
        // 原顶栏自带 top:8 呼吸空间（组件行高统一 48，不内置页级间距）
        .margin({ top: 8 })

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
          .onClick((): void => {
            this.sheetKind = 'filters';
          })

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
          .onClick((): void => {
            this.sheetKind = 'repo';
          })
        }
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .padding({ left: 16, right: 16, bottom: 8 })

      Refresh({ refreshing: $$this.isRefreshing }) {
        Scroll() {
          // 独立卡片列表：每张通知自带圆角与间距（同 Pull Requests 列表样式）
          Column() {
            if (this.items.length > 0) {
              ForEach(this.items, (item: NotificationItem) => {
                InboxNotifyCard({
                  item: item,
                  onMarkRead: (it: NotificationItem): void => this.markRead(it)
                })
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
        .scrollBar(BarState.Off)
        .align(Alignment.Top)
        .onScroll((_x: number, y: number): void => {
          this.scrollShadow = y > 0.001;
        })
      }
      .layoutWeight(1)
      .onRefreshing((): void => {
        this.isRefreshing = true;
        this.refresh();
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_page'))
    .bindSheet(this.sheetKind !== '', this.overlaySheet(), {
      height: 600,
      backgroundColor: $r('app.color.card_background'),
      // 关闭钮与标题行均自绘，避免默认 ✕ 与自绘按钮重叠
      showClose: false,
      // 交互关闭（下滑/遮罩）后复位，否则表达式恒 true 再点 chip 拉不起来（review A1）
      onDisappear: (): void => {
        this.sheetKind = '';
      }
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
