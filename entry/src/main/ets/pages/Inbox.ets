/**
 * Inbox Tab（Spec 002）：官方四筛选（Inbox▾/Focused/Unread/Repository▾）+ 通知卡片。
 * Inbox▾/Repository▾ 为底部 sheet 面板（官方「Filter notifications by」/「Filter by repository」，
 * 面板组件化于 InboxFilterSheets）：视图单选（Inbox/Saved/Done）+ 类型多选（reason 本地过滤）、
 * 仓库单选列表（头像+计数+搜索）。卡片=仓库+编号 / 标题粗体 / 类型图标+摘要 / 右侧相对时间
 * （组件化于 InboxNotifyCard）。
 * Spec 045：tap=标已读+LinkRouter 跳详情（issue/pr 原生路由、release 换 tag、discussion 内嵌
 * 浏览器）；长按=多选模式（顶栏 ×/N selected/●/✓/⋮，批量已读/批量 Done）；行滑动=左滑 Done、
 * 右滑 Unsubscribe（SwipeAction）。
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
import { shouldAutoLoadMore, isLimitedRangeEmpty } from '../utils/FilterLoading';
import { parseSubjectUrl, releaseRouteParam, LinkRoute } from '../utils/LinkRouter';
import { runBounded } from 'graphql';

type InboxFilter = 'inbox' | 'focused' | 'unread' | 'repo';

/** 通知每页条数（REST /notifications per_page 上限 50；reason 无服务端参数，靠多拉几页缓解假空） */
const NOTIFICATIONS_PER_PAGE = 50;

/** 批量线程操作的有界并发批量（官方无批量端点，逐线程调用防打满网络栈） */
const THREAD_BATCH_SIZE = 5;

@ComponentV2
export struct InboxView {
  @Param token: string = '';
  /** 跳转详情用主路由栈（Tab 页不在 NavDestination 内，由 Index 注入） */
  @Param pathStack: NavPathStack = new NavPathStack();
  @Local filter: InboxFilter = 'inbox';
  @Local repoFilter: string = '';
  /** 下拉面板内容（'' | 'filters' | 'repo'）：同一组件只挂一个 bindSheet，内部切换 */
  @Local sheetKind: string = '';
  @Local inboxView: string = 'inbox';
  @Local reasonKeys: InboxReasonKey[] = [];
  @Local repoFilters: InboxRepoFilterItem[] = [];
  @Local repoSearch: string = '';
  @Local repoSearchShow: boolean = false;
  /** 通知分页：page=当前页；hasMorePages=上一页满载（REST 无 pageInfo，按满载推断） */
  @Local page: number = 1;
  @Local hasMorePages: boolean = true;
  /** 空态自动补拉已用页数（reason/repo 为客户端过滤，防「假空」） */
  @Local extraPages: number = 0;
  /** 补拉/翻页进行中（Inbox 无触底加载入口，仅自动补拉用） */
  @Local loadingMore: boolean = false;
  @Local items: NotificationItem[] = [];
  @Local rawItems: NotificationItem[] = [];
  @Local loading: boolean = true;
  @Local errorMsg: string = '';
  /** 滚动顶部阴影（滚动中显示、回顶消失） */
  @Local scrollShadow: boolean = false;
  @Local isRefreshing: boolean = false;
  /** 多选模式（Spec 045）：顶栏变形 + 行首勾选圈，过滤条隐藏 */
  @Local selectMode: boolean = false;
  /** 多选已选 threadId（以当前视图 items 为操作对象） */
  @Local selectedIds: string[] = [];
  /** 批量操作进行中（防连点，●/✓ 执行期间禁再次触发） */
  @Local batching: boolean = false;
  /** 滑动复位代次：右滑 Unsubscribe 行保留，代次自增令该行 key 变化以收起展开态 */
  @Local swipeEpoch: number = 0;
  /** Snackbar（Spec 045 走查反馈④）：滑动操作后的底部浮条，文案 + UNDO；'' = 隐藏 */
  @Local snackbarText: string = '';
  /** UNDO 动作类型：'done'（本地恢复行）/ 'unsub'（服务端恢复订阅）/ '' 无 UNDO */
  @Local snackbarAction: string = '';
  /** UNDO 目标行（非状态属性：恢复逻辑用，不驱动 UI） */
  private snackbarItem: NotificationItem | null = null;
  /** UNDO 目标行在 rawItems 的原下标（done 恢复原位用） */
  private snackbarIndex: number = -1;
  private snackbarTimer: number = -1;

  aboutToAppear(): void {
    this.refresh();
  }

  /** Spec 049a：切换账号后 token 更新 → 用新 token 重拉（未读 badge 由 Index 侧同刻重算） */
  @Monitor('token')
  onTokenChanged(): void {
    this.refresh();
  }

  /** 拉取后：聚合仓库候选 → 本地链式过滤（视图 → 类型 → 仓库）；重拉即退出多选（选中集已失配） */
  private refresh(): void {
    this.exitSelectMode();
    this.loading = true;
    this.errorMsg = '';
    this.page = 1;
    NotificationsService.fetchNotifications(this.token, this.filter !== 'unread',
      NOTIFICATIONS_PER_PAGE, this.filter === 'focused', 1)
      .then((items: NotificationItem[]) => {
        this.rawItems = items;
        this.hasMorePages = items.length >= NOTIFICATIONS_PER_PAGE;
        this.repoFilters = collectRepoFilters(items);
        this.applyFilters();
        this.loading = false;
        this.isRefreshing = false;
        this.extraPages = 0;
        this.autoLoadIfEmpty();
      })
      .catch((e: Error) => {
        this.errorMsg = friendlyError(this.getUIContext(), e);
        this.loading = false;
        this.isRefreshing = false;
      });
  }

  /** 翻页：追加下一页原始通知（reason/repo 客户端过滤需要更多原始数据时自动调用） */
  private loadMore(): void {
    if (!this.hasMorePages || this.loading || this.loadingMore) {
      return;
    }
    this.loadingMore = true;
    NotificationsService.fetchNotifications(this.token, this.filter !== 'unread',
      NOTIFICATIONS_PER_PAGE, this.filter === 'focused', this.page + 1)
      .then((items: NotificationItem[]) => {
        this.page += 1;
        this.rawItems = this.rawItems.concat(items);
        this.hasMorePages = items.length >= NOTIFICATIONS_PER_PAGE;
        this.repoFilters = collectRepoFilters(this.rawItems);
        this.applyFilters();
        this.loadingMore = false;
        this.autoLoadIfEmpty();
      })
      .catch((e: Error) => {
        this.errorMsg = friendlyError(this.getUIContext(), e);
        this.loadingMore = false;
      });
  }

  /** 过滤后为空且还有下一页 → 自动补拉（上限 5 页），防「假空」 */
  private autoLoadIfEmpty(): void {
    if (shouldAutoLoadMore(this.items.length, this.hasMorePages, this.extraPages)) {
      this.extraPages += 1;
      this.loadMore();
    }
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

  /** 激活筛选数（全库统一口径）：视图（Saved/Done）+ 模式（Focused/Unread/Repo）+ 类型多选，各计 1 */
  private activeFilterCount(): number {
    let c = 0;
    if (this.filter !== 'inbox') {
      c++;
    }
    if (this.inboxView !== 'inbox') {
      c++;
    }
    if (this.reasonKeys.length > 0) {
      c++;
    }
    return c;
  }

  /** 清除全部筛选：视图/模式/多选/仓库全部回默认；与漏斗菜单 Clear all filters 同一函数 */
  private clearAllFilters(): void {
    const needReload = this.filter !== 'inbox';
    this.reasonKeys = [];
    this.repoFilter = '';
    this.inboxView = 'inbox';
    this.filter = 'inbox';
    if (needReload) {
      this.refresh();
    } else {
      this.applyFilters();
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

  /**
   * 本地同步已读态（items 与 rawItems 双份，防切筛选后已读态复活；Spec 045 批量 ● 亦走此）。
   * threadIds 内的行置为 unread，其余不动；数组重赋值驱动 V2 刷新。
   */
  private markLocalRead(threadIds: string[], unread: boolean): void {
    const hit = (it: NotificationItem): boolean => threadIds.indexOf(it.threadId) >= 0;
    const mark = (list: NotificationItem[]): NotificationItem[] => {
      return list.map((it: NotificationItem): NotificationItem => {
        if (!hit(it)) {
          return it;
        }
        return {
          threadId: it.threadId,
          repoFullName: it.repoFullName,
          title: it.title,
          subjectType: it.subjectType,
          reason: it.reason,
          unread: unread,
          updatedAt: it.updatedAt,
          subjectUrl: it.subjectUrl,
          ownerAvatarUrl: it.ownerAvatarUrl,
          prMerged: it.prMerged
        };
      });
    };
    this.rawItems = mark(this.rawItems);
    this.items = mark(this.items);
  }

  /** 从本地列表移除线程（批量 Done / 左滑 Done 后行消失） */
  private removeLocalThreads(threadIds: string[]): void {
    const gone = (it: NotificationItem): boolean => threadIds.indexOf(it.threadId) >= 0;
    this.rawItems = this.rawItems.filter((it: NotificationItem): boolean => !gone(it));
    this.items = this.items.filter((it: NotificationItem): boolean => !gone(it));
    this.repoFilters = collectRepoFilters(this.rawItems);
  }

  /** tap 附带的静默已读（失败不打扰跳转；已读行不重复请求） */
  private quietMarkRead(item: NotificationItem): void {
    if (!item.unread) {
      return;
    }
    NotificationsService.markThreadRead(this.token, item.threadId)
      .then((): void => {
        this.markLocalRead([item.threadId], false);
        AppStorage.setOrCreate('inboxUnreadTick', Date.now());
      })
      .catch((_e: Error) => {
        // 静默失败：跳转优先，已读态以下拉刷新/服务端为准
      });
  }

  /** tap 通知卡（非多选态）：标已读 + LinkRouter 按对象类型跳详情（Spec 045） */
  private openNotification(item: NotificationItem): void {
    const route: LinkRoute = parseSubjectUrl(item.subjectUrl);
    this.quietMarkRead(item);
    switch (route.kind) {
      case 'issue':
        this.pathStack.pushPathByName('issueDetail', `${route.owner}/${route.name}/${route.number}`);
        break;
      case 'pr':
        this.pathStack.pushPathByName('prDetail', `${route.owner}/${route.name}/${route.number}`);
        break;
      case 'discussion':
        // App 无讨论详情页：内嵌浏览器打开网页版（LinkRouter 已换算 github.com 地址）
        this.pathStack.pushPathByName('inAppBrowser', `${item.repoFullName} #${route.number}|${route.webUrl}`);
        break;
      case 'release':
        // subject.url 是数字 id，ReleaseDetail 路由按 tag：先换 tag，失败降级 Releases 列表页
        NotificationsService.fetchReleaseTag(this.token, route.owner, route.name, route.number)
          .then((tag: string): void => {
            if (tag !== '') {
              this.pathStack.pushPathByName('releaseDetail', releaseRouteParam(route.owner, route.name, tag));
            } else {
              this.pathStack.pushPathByName('repoReleases', `${route.owner}/${route.name}`);
            }
          });
        break;
      default:
        promptAction.showToast({ message: $r('app.string.inbox_no_detail') });
    }
  }

  // ───────────── Spec 045：多选模式 ─────────────

  /** 长按进入多选：长按行即选中该行（官方同构） */
  private enterSelectMode(item: NotificationItem): void {
    if (this.selectMode) {
      return;
    }
    this.getUIContext().animateTo({ duration: 250, curve: Curve.EaseInOut }, (): void => {
      this.selectMode = true;
      this.selectedIds = [item.threadId];
    });
  }

  /** 退出多选（× 或取消全选后） */
  private exitSelectMode(): void {
    if (!this.selectMode) {
      return;
    }
    this.getUIContext().animateTo({ duration: 250, curve: Curve.EaseInOut }, (): void => {
      this.selectMode = false;
      this.selectedIds = [];
    });
  }

  /** 多选态点行切换选中；清空即退出多选（勾选圈显隐随 animateTo 过渡） */
  private toggleSelect(item: NotificationItem): void {
    const idx = this.selectedIds.indexOf(item.threadId);
    this.getUIContext().animateTo({ duration: 200, curve: Curve.EaseInOut }, (): void => {
      if (idx >= 0) {
        const next = this.selectedIds.slice();
        next.splice(idx, 1);
        this.selectedIds = next;
      } else {
        this.selectedIds = this.selectedIds.concat([item.threadId]);
      }
      if (this.selectedIds.length === 0) {
        this.selectMode = false;
      }
    });
  }

  private onCardTap(item: NotificationItem): void {
    if (this.selectMode) {
      this.toggleSelect(item);
    } else {
      this.openNotification(item);
    }
  }

  /** ⋮ Select all：全选当前视图 */
  private selectAll(): void {
    this.selectedIds = this.items.map((it: NotificationItem): string => it.threadId);
  }

  /** 当前视图是否已被全选（● 走 PUT 单发的判定之一） */
  private isFullSelection(): boolean {
    return this.items.length > 0 && this.selectedIds.length === this.items.length;
  }

  /** 选中行的当前视图对象（批量操作以视图内数据为准） */
  private selectionTargets(): NotificationItem[] {
    return this.items.filter((it: NotificationItem): boolean => this.selectedIds.indexOf(it.threadId) >= 0);
  }

  /** 无任何筛选时全选才等价「全部通知已读」（PUT /notifications 是账号级操作） */
  private viewIsPlainInbox(): boolean {
    return this.filter === 'inbox' && this.inboxView === 'inbox' &&
      this.reasonKeys.length === 0 && this.repoFilter === '';
  }

  /** 逐线程调用并收集成功 threadId（runBounded 批内 all，单失败会整体 reject → 逐项捕获） */
  private async runPerThread(targets: NotificationItem[],
    call: (item: NotificationItem) => Promise<void>): Promise<string[]> {
    const ids = await runBounded<NotificationItem, string>(targets, THREAD_BATCH_SIZE,
      async (item: NotificationItem): Promise<string> => {
        try {
          await call(item);
          return item.threadId;
        } catch (e) {
          return '';
        }
      });
    const ok: string[] = [];
    for (const id of ids) {
      if (id !== '') {
        ok.push(id);
      }
    }
    return ok;
  }

  private batchFailedToast(failed: number): void {
    promptAction.showToast({ message: this.fmt($r('app.string.inbox_batch_failed'), `${failed}`) });
  }

  /**
   * ● 批量已读（单向）：REST 标回未读实测无效（2026-09-22 gh 实测，PATCH unread=true 205 但
   * 服务端恒 false），故 ● 仅标已读；选中集全为已读时 toast 提示。
   */
  private async batchToggleRead(): Promise<void> {
    if (this.batching) {
      return;
    }
    const targets = this.selectionTargets().filter((t: NotificationItem): boolean => t.unread);
    if (targets.length === 0) {
      promptAction.showToast({ message: $r('app.string.inbox_all_read') });
      return;
    }
    this.batching = true;
    try {
      if (this.isFullSelection() && this.viewIsPlainInbox()) {
        // 全选且无筛选：单发 PUT /notifications（官方「mark all as read」语义）
        await NotificationsService.markAllRead(this.token);
        this.markLocalRead(targets.map((t: NotificationItem): string => t.threadId), false);
      } else {
        const okIds = await this.runPerThread(targets, (t: NotificationItem): Promise<void> =>
          NotificationsService.markThreadRead(this.token, t.threadId));
        if (okIds.length < targets.length) {
          this.batchFailedToast(targets.length - okIds.length);
        }
        this.markLocalRead(okIds, false);
      }
      AppStorage.setOrCreate('inboxUnreadTick', Date.now());
      this.exitSelectMode();
    } finally {
      this.batching = false;
    }
  }

  /** ✓ 批量 Done：逐线程 DELETE，成功项从列表移除（官方无批量端点） */
  private async batchDone(): Promise<void> {
    if (this.batching) {
      return;
    }
    const targets = this.selectionTargets();
    if (targets.length === 0) {
      return;
    }
    this.batching = true;
    try {
      const okIds = await this.runPerThread(targets, (t: NotificationItem): Promise<void> =>
        NotificationsService.markThreadDone(this.token, t.threadId));
      if (okIds.length < targets.length) {
        this.batchFailedToast(targets.length - okIds.length);
      }
      this.removeLocalThreads(okIds);
      AppStorage.setOrCreate('inboxUnreadTick', Date.now());
      this.exitSelectMode();
    } finally {
      this.batching = false;
    }
  }

  // ───────────── Spec 045：行滑动 ─────────────

  /**
   * Snackbar（走查反馈④）：操作后底部浮条「文案 + UNDO」，4s 自动消失。
   * done 的撤销为本地恢复（REST 无撤销 done 端点，2026-09-22 实测 done 为终态，
   * 刷新后以服务端为准）；unsub 的撤销走服务端 PUT subscription（实测可恢复）。
   */
  private showSnackbar(text: string, action: string, item: NotificationItem, index: number): void {
    if (this.snackbarTimer !== -1) {
      clearTimeout(this.snackbarTimer);
    }
    this.getUIContext().animateTo({ duration: 200, curve: Curve.EaseInOut }, (): void => {
      this.snackbarText = text;
      this.snackbarAction = action;
    });
    this.snackbarItem = item;
    this.snackbarIndex = index;
    this.snackbarTimer = setTimeout((): void => this.hideSnackbar(), 4000);
  }

  private hideSnackbar(): void {
    if (this.snackbarTimer !== -1) {
      clearTimeout(this.snackbarTimer);
      this.snackbarTimer = -1;
    }
    this.getUIContext().animateTo({ duration: 200, curve: Curve.EaseInOut }, (): void => {
      this.snackbarText = '';
      this.snackbarAction = '';
    });
    this.snackbarItem = null;
    this.snackbarIndex = -1;
  }

  /** UNDO：done=行插回原位 + 静默同步已读；unsub=服务端恢复订阅 */
  private onSnackbarUndo(): void {
    const item = this.snackbarItem;
    const kind = this.snackbarAction;
    const index = this.snackbarIndex;
    this.hideSnackbar();
    if (item === null) {
      return;
    }
    if (kind === 'done') {
      const at = Math.min(Math.max(index, 0), this.rawItems.length);
      this.rawItems.splice(at, 0, item);
      this.applyFilters();
      NotificationsService.markThreadRead(this.token, item.threadId).catch((_e: Error) => {
        // 撤销仅为本地恢复（done 服务端终态），同步失败不提示
      });
    } else if (kind === 'unsub') {
      NotificationsService.resubscribeThread(this.token, item.threadId)
        .then((): void => {
          promptAction.showToast({ message: $r('app.string.inbox_resubscribed') });
        })
        .catch((_e: Error) => {
          this.batchFailedToast(1);
        });
    }
  }

  /** 左滑 Done：行移除 + Snackbar（UNDO 本地恢复） */
  private swipeDoneAction(item: NotificationItem): void {
    const index = this.rawItems.findIndex((it: NotificationItem): boolean => it.threadId === item.threadId);
    NotificationsService.markThreadDone(this.token, item.threadId)
      .then((): void => {
        this.removeLocalThreads([item.threadId]);
        AppStorage.setOrCreate('inboxUnreadTick', Date.now());
        this.showSnackbar(resText(this.getUIContext(), $r('app.string.inbox_snackbar_done')),
          'done', item, index);
      })
      .catch((_e: Error) => {
        this.batchFailedToast(1);
      });
  }

  /** 右滑 Unsubscribe：退订（行保留）+ Snackbar（UNDO 服务端恢复订阅） */
  private swipeUnsubscribeAction(item: NotificationItem): void {
    NotificationsService.unsubscribeThread(this.token, item.threadId)
      .then((): void => {
        this.swipeEpoch += 1;
        this.showSnackbar(resText(this.getUIContext(), $r('app.string.inbox_unsubscribed')),
          'unsub', item, -1);
      })
      .catch((_e: Error) => {
        this.batchFailedToast(1);
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

  /** chip 公共样式（@Styles 不支持参数：文本/背景等动态部分行内设置）；尺寸与全库下拉 chip 统一（32/16/12fp） */
  @Styles
  filterPillStyle() {
    .height(32)
    .responseRegion({ x: 0, y: -6, width: '100%', height: '144%' })
    .padding({ left: 8, right: 8 })
    .borderRadius(16)
    .border({ width: 1, color: $r('app.color.border') })
  }

  /** 多选顶栏（Spec 045 官方同构）：× + N selected + ● 已读/未读 + ✓ Done + ⋮ 全选菜单；
   * 自绘按 067 数值对齐（行高 48 / 触控区 44×44 / 边距 4+16） */
  @Builder
  selectionBar() {
    Row() {
      Stack() {
        OctIcon({ res: $r('app.media.oct_x_16'), iconSize: 20, iconColor: $r('app.color.text_primary') })
      }
      .width(44)
      .height(44)
      .onClick((): void => this.exitSelectMode())

      Text(this.fmt($r('app.string.inbox_n_selected'), `${this.selectedIds.length}`))
        .fontSize($r('app.float.title_font_size'))
        .fontWeight(600)
        .fontColor($r('app.color.text_primary'))
        .margin({ left: 4 })

      Blank()

      Stack() {
        OctIcon({ res: $r('app.media.oct_dot_fill_16'), iconSize: 20, iconColor: $r('app.color.text_primary') })
      }
      .width(44)
      .height(44)
      .opacity(this.batching ? 0.4 : 1)
      .onClick((): void => {
        this.batchToggleRead();
      })

      Stack() {
        OctIcon({ res: $r('app.media.oct_check_16'), iconSize: 20, iconColor: $r('app.color.text_primary') })
      }
      .width(44)
      .height(44)
      .opacity(this.batching ? 0.4 : 1)
      .onClick((): void => {
        this.batchDone();
      })

      Stack() {
        OctIcon({ res: $r('app.media.oct_kebab_horizontal_16'), iconSize: 20, iconColor: $r('app.color.link_blue') })
          .rotate({ angle: 90 })
      }
      .width(44)
      .height(44)
      .bindMenu([
        {
          value: $r('app.string.inbox_select_all'),
          action: (): void => this.selectAll()
        },
        {
          value: $r('app.string.inbox_deselect_all'),
          action: (): void => this.exitSelectMode()
        }
      ])
    }
    .width('100%')
    .height(48)
    .padding({ left: 4, right: 4 })
    .margin({ top: 8 })
    // 多选顶栏插入/退出的淡入淡出（走查反馈②；插入删除发生在 animateTo 闭包内）
    .transition(TransitionEffect.OPACITY.animation({ duration: 250, curve: Curve.EaseInOut }))
  }

  /** 左滑 Done 滑块（走查反馈⑤：底色随滑动露出，勾固定贴卡片右缘不随滑动移动） */
  @Builder
  swipeDoneBlock() {
    Row() {
      Blank()
      OctIcon({ res: $r('app.media.oct_check_16'), iconSize: 24, iconColor: Color.White })
        .margin({ right: 24 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.success_btn_bg'))
  }

  /** 右滑 Unsubscribe 滑块（灰底全高色块 + 斜线铃铛固定贴卡片左缘，无文字） */
  @Builder
  swipeUnsubscribeBlock() {
    Row() {
      OctIcon({ res: $r('app.media.oct_bell_slash_16'), iconSize: 24, iconColor: Color.White })
        .margin({ left: 24 })
      Blank()
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.text_secondary'))
  }

  /** 底部 Snackbar（走查反馈④）：深底白字文案 + 右侧蓝色 UNDO，4s 自动消失 */
  @Builder
  snackbarBar() {
    Row({ space: 16 }) {
      Text(this.snackbarText)
        .fontSize($r('app.float.body_font_size'))
        .fontColor($r('app.color.card_background'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
      Text($r('app.string.inbox_snackbar_undo'))
        .fontSize($r('app.float.body_font_size'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.link_blue'))
        .onClick((): void => this.onSnackbarUndo())
    }
    .alignItems(VerticalAlign.Center)
    .width('100%')
    .height(48)
    .padding({ left: 16, right: 16 })
    .borderRadius(8)
    .backgroundColor($r('app.color.text_primary'))
    .margin({ left: 16, right: 16, bottom: 16 })
    .transition(TransitionEffect.OPACITY.animation({ duration: 200, curve: Curve.EaseInOut }))
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

  /** 行滑动配置（Spec 045）：左滑=Done（绿底白勾）、右滑=Unsubscribe（灰底斜线铃铛）；
   * 多选态返回空配置禁用滑动。ArkUI 的 swipeAction 是 ListItem 属性，builder 用标准箭头形态。 */
  private swipeOptions(item: NotificationItem): SwipeActionOptions {
    if (this.selectMode) {
      return {};
    }
    return {
      // start=右滑露左侧（Unsubscribe）、end=左滑露右侧（Done）
      end: {
        builder: (): void => {
          this.swipeDoneBlock()
        },
        onAction: (): void => {
          this.swipeDoneAction(item)
        }
      },
      start: {
        builder: (): void => {
          this.swipeUnsubscribeBlock()
        },
        onAction: (): void => {
          this.swipeUnsubscribeAction(item)
        }
      }
    };
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column() {
      if (this.selectMode) {
        this.selectionBar()
      } else {
        AppBar({
          title: $r('app.string.tab_inbox'),
          actions: [
            new AppBarAction($r('app.media.oct_kebab_horizontal_16'), (): void => {}, {
              rotate90: true,
              a11y: $r('app.string.a11y_more'),
              menu: [
                {
                  value: $r('app.string.inbox_menu_refresh'),
                  action: (): void => {
                    // 顶部转圈反馈（走查反馈①）：⋮ Refresh 与下拉刷新同通道
                    this.isRefreshing = true;
                    this.refresh();
                  }
                }
              ]
            })
          ]
        })
          // 原顶栏自带 top:8 呼吸空间（组件行高统一 48，不内置页级间距）
          .margin({ top: 8 })
          .transition(TransitionEffect.OPACITY.animation({ duration: 250, curve: Curve.EaseInOut }))
      }

      PageShadowBar({ show: this.scrollShadow })

        // 四个筛选 chip 内联渲染：@Builder 传值/$$ 引用参数均不随状态刷新（V2 坑，见 memory），
        // 文本/激活态直接读 @Local 才能随筛选变化实时更新。
        // 外层 Row：漏斗徽标固定最左、不随 chip 横向滑动；chips 段单独横向滑动
        // 多选态整条隐藏（官方同构，Spec 045）；随多选切换淡入淡出
        if (!this.selectMode) {
        Row({ space: 8 }) {
          // 漏斗徽标：激活筛选组数（Issues/PR 列表同款；无激活时隐藏），点开菜单可一键清除
          if (this.activeFilterCount() > 0) {
            Row({ space: 4 }) {
              OctIcon({
                res: $r('app.media.oct_filter_16'),
                iconSize: 14,
                iconColor: $r('app.color.link_blue')
              })
              Stack() {
                Text(`${this.activeFilterCount()}`)
                  .fontSize($r('app.float.caption_font_size'))
                  .fontColor(Color.White)
              }
              .width(18)
              .height(18)
              .borderRadius(9)
              .backgroundColor($r('app.color.link_blue'))
            }
            .filterPillStyle()
            .backgroundColor($r('app.color.chip_bg'))
            .bindMenu([
              {
                value: $r('app.string.work_filter_create_shortcut'),
                action: (): void => {
                  promptAction.showToast({ message: $r('app.string.home_feature_coming') });
                }
              },
              {
                value: $r('app.string.work_clear_all_filters'),
                action: (): void => this.clearAllFilters()
              }
            ])
          }

          // chips 滚动区：仅这一段随手指横向滑动
          Scroll() {
          Row({ space: 8 }) {
          // 视图 chip：激活蓝只看自身值是否非默认（inboxView≠inbox），默认值不做激活色（Spec 068）
          Row() {
            Text(this.viewLabel())
              .fontSize($r('app.float.caption_font_size'))
              .fontColor(this.inboxView !== 'inbox' ? $r('app.color.link_blue') : $r('app.color.text_primary'))
            OctIcon({
              res: $r('app.media.oct_chevron_down_16'),
              iconSize: 12,
              iconColor: this.inboxView !== 'inbox' ? $r('app.color.link_blue') : $r('app.color.text_secondary')
            })
              .margin({ left: 8 })
          }
          .filterPillStyle()
          .backgroundColor(this.inboxView !== 'inbox' ? $r('app.color.chip_active_bg') : $r('app.color.chip_bg'))
          .onClick((): void => {
            this.sheetKind = 'filters';
          })

          Row() {
            Text(this.stringOf($r('app.string.inbox_menu_focused')))
              .fontSize($r('app.float.caption_font_size'))
              .fontColor(this.filter === 'focused' ? $r('app.color.link_blue') : $r('app.color.text_primary'))
          }
          .filterPillStyle()
          .backgroundColor(this.filter === 'focused' ? $r('app.color.chip_active_bg') : $r('app.color.chip_bg'))
          .onClick((): void => this.switchFilter('focused'))

          Row() {
            Text(this.stringOf($r('app.string.inbox_menu_unread')))
              .fontSize($r('app.float.caption_font_size'))
              .fontColor(this.filter === 'unread' ? $r('app.color.link_blue') : $r('app.color.text_primary'))
          }
          .filterPillStyle()
          .backgroundColor(this.filter === 'unread' ? $r('app.color.chip_active_bg') : $r('app.color.chip_bg'))
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
              .margin({ left: 8 })
          }
          .filterPillStyle()
          .backgroundColor(this.filter === 'repo' ? $r('app.color.chip_active_bg') : $r('app.color.chip_bg'))
          .onClick((): void => {
            this.sheetKind = 'repo';
          })
          }
          }
          .scrollable(ScrollDirection.Horizontal)
          .scrollBar(BarState.Off)
          .layoutWeight(1)
          .align(Alignment.Start)
        }
        .padding({ left: 16, right: 16, bottom: 8 })
        .transition(TransitionEffect.OPACITY.animation({ duration: 250, curve: Curve.EaseInOut }))
        }

      Refresh({ refreshing: $$this.isRefreshing }) {
        // 独立卡片列表（同 Pull Requests 列表样式）；List+ListItem 承载 swipeAction（Spec 045 行滑动）
        if (this.items.length > 0) {
          List({ space: 0 }) {
            ForEach(this.items, (item: NotificationItem) => {
              ListItem() {
                InboxNotifyCard({
                  item: item,
                  selectMode: this.selectMode,
                  selected: this.selectedIds.indexOf(item.threadId) >= 0,
                  onTap: (it: NotificationItem): void => this.onCardTap(it),
                  onLongPress: (it: NotificationItem): void => this.enterSelectMode(it)
                })
              }
              .swipeAction(this.swipeOptions(item))
            }, (item: NotificationItem) => `${item.threadId}#${this.swipeEpoch}`)
          }
          .width('100%')
          .height('100%')
          .padding({ left: 16, right: 16, bottom: 16 })
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
          .onScrollIndex((start: number, _end: number): void => {
            this.scrollShadow = start > 0;
          })
        } else {
          Column() {
            StateView({
              loading: this.loading,
              error: this.errorMsg,
              empty: !this.loading && this.errorMsg === '',
              emptyText: this.emptyText(),
              emptySub: isLimitedRangeEmpty(this.items.length, this.hasMorePages)
                ? $r('app.string.filter_loaded_range_hint') : null
            })
          }
          .padding({ left: 16, right: 16, bottom: 16 })
          .width('100%')
        }
      }
      .layoutWeight(1)
      .onRefreshing((): void => {
        this.isRefreshing = true;
        this.refresh();
      })
      }
      .width('100%')
      .height('100%')
      // Snackbar 覆盖层（走查反馈④）：悬浮于内容之上、tab 栏之上
      if (this.snackbarAction !== '') {
        this.snackbarBar()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_page'))
    .bindSheet(this.sheetKind !== '', this.overlaySheet(), {
      height: 600,
      detents: [600, SheetSize.LARGE],
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
