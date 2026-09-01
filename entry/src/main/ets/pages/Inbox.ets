/**
 * Inbox Tab（Spec 002）：官方四筛选（Inbox▾/Focused/Unread/Repository▾）+ 通知卡片。
 * 卡片=仓库+编号 / 标题粗体 / 类型图标+摘要 / 右侧相对时间；点击标记已读。
 * 详情页为 Spec 008/009 范围，当前点击仅标记已读并提示。
 */
import { promptAction } from '@kit.ArkUI';
import { NotificationItem, issueNumberFromUrl } from '../models/GitHubModels';
import { NotificationsService } from '../services/NotificationsService';
import { StateView } from '../components/StateView';
import { OctIcon } from '../components/OctIcon';
import { timeParts, notificationTypeKey, TimeParts } from '../utils/Format';
import { resText } from '../utils/I18n';

type InboxFilter = 'inbox' | 'focused' | 'unread' | 'repo';

@ComponentV2
export struct InboxView {
  @Param token: string = '';
  @Local filter: InboxFilter = 'inbox';
  @Local repoFilter: string = '';
  @Local items: NotificationItem[] = [];
  @Local rawItems: NotificationItem[] = [];
  @Local repoNames: string[] = [];
  @Local loading: boolean = true;
  @Local errorMsg: string = '';

  aboutToAppear(): void {
    this.refresh();
  }

  private refresh(): void {
    this.loading = true;
    this.errorMsg = '';
    NotificationsService.fetchNotifications(this.token, this.filter !== 'unread', 30, this.filter === 'focused')
      .then((items: NotificationItem[]) => {
        this.rawItems = items;
        this.repoNames = InboxView.collectRepoNames(items);
        this.applyRepoFilter();
        this.loading = false;
      })
      .catch((e: Error) => {
        this.errorMsg = e.message;
        this.loading = false;
      });
  }

  /** 从通知列表提取去重仓库名（Repository▾ 下拉候选，纯函数便于单测） */
  static collectRepoNames(items: NotificationItem[]): string[] {
    const seen: string[] = [];
    for (const it of items) {
      if (it.repoFullName !== '' && seen.indexOf(it.repoFullName) < 0) {
        seen.push(it.repoFullName);
      }
    }
    return seen;
  }

  /** Repository▾ 过滤：本地按选中仓库筛（其余 item 原样） */
  private applyRepoFilter(): void {
    if (this.filter === 'repo' && this.repoFilter !== '') {
      this.items = this.rawItems.filter((it: NotificationItem) => it.repoFullName === this.repoFilter);
    } else {
      this.items = this.rawItems;
    }
  }

  private switchFilter(f: InboxFilter): void {
    if (f === 'repo') {
      this.filter = 'repo';
      if (this.repoFilter === '' && this.repoNames.length > 0) {
        this.repoFilter = this.repoNames[0];
      }
      this.applyRepoFilter();
      return;
    }
    if (this.filter !== f) {
      this.filter = f;
      this.refresh();
    }
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
            subjectUrl: it.subjectUrl
          };
          return copy;
        });
        promptAction.showToast({ message: $r('app.string.inbox_marked_read') });
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

  /** 时间戳 → 相对时间文案；解析失败回退空串 */
  private timeText(parts: TimeParts | null): string {
    if (parts === null) {
      return '';
    }
    const ui = this.getUIContext();
    switch (parts.unit) {
      case 'just_now':
        return resText(ui, $r('app.string.time_just_now'));
      case 'minute':
        return resText(ui, $r('app.string.time_minutes_ago'), parts.value);
      case 'hour':
        return resText(ui, $r('app.string.time_hours_ago'), parts.value);
      case 'day':
        return resText(ui, $r('app.string.time_days_ago'), parts.value);
      case 'month':
        return resText(ui, $r('app.string.time_months_ago'), parts.value);
      case 'year':
        return resText(ui, $r('app.string.time_years_ago'), parts.value);
    }
  }

  @Builder
  filterPill(label: string, active: boolean, onClick: () => void) {
    Text(active ? `${label} ▾` : label)
      .fontSize($r('app.float.caption_font_size'))
      .fontColor(active ? $r('app.color.link_blue') : $r('app.color.text_primary'))
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .borderRadius(12)
      .backgroundColor(active ? $r('app.color.chip_active_green_bg') : $r('app.color.card_background'))
      .border({ width: 1, color: $r('app.color.border') })
      .onClick(onClick)
  }

  /** Repository▾ 下拉菜单：从会话仓库提取（Spec 002） */
  @Builder
  repoMenu() {
    Menu() {
      ForEach(this.repoNames, (repo: string) => {
        MenuItem({
          content: repo
        })
          .onClick(() => {
            this.repoFilter = repo;
            this.filter = 'repo';
            this.applyRepoFilter();
          })
      }, (repo: string) => repo)
    }
  }

  /** 卡片编号行：编号非空才显示（方法返回，供 @Builder 内 if 判断） */
  private issueNum(item: NotificationItem): string {
    return issueNumberFromUrl(item.subjectUrl);
  }

  @Builder
  notifyCard(item: NotificationItem) {
    Row({ space: 8 }) {
      Circle()
        .width(10)
        .height(10)
        .fill($r('app.color.link_blue'))
        .opacity(item.unread ? 1 : 0)
        .margin({ top: 6 })
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
          Text(this.timeText(timeParts(item.updatedAt, Date.now())))
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
          Text(item.unread ? '●' : '○')
            .fontSize(14)
            .fontColor(item.unread ? $r('app.color.link_blue') : $r('app.color.text_secondary'))
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
    .width('100%')
    .padding($r('app.float.card_padding'))
    .borderRadius($r('app.float.card_radius'))
    .backgroundColor($r('app.color.card_background'))
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
          iconColor: $r('app.color.text_secondary')
  })
}
.width(44)
.height(44)
        .accessibilityDescription($r('app.string.a11y_more'))
        .focusable(true)
.onClick((): void => {
            promptAction.showToast({ message: $r('app.string.inbox_detail_coming') });
          })
          .padding(4)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 8 })

      Row({ space: 8 }) {
        this.filterPill(this.stringOf($r('app.string.inbox_menu_inbox')), this.filter === 'inbox', (): void => this.switchFilter('inbox'))
        this.filterPill(this.stringOf($r('app.string.inbox_menu_focused')), this.filter === 'focused', (): void => this.switchFilter('focused'))
        this.filterPill(this.stringOf($r('app.string.inbox_menu_unread')), this.filter === 'unread', (): void => this.switchFilter('unread'))
        Text(this.repoFilter !== ''
          ? `${this.repoFilter} ▾`
          : `${this.stringOf($r('app.string.inbox_menu_repository'))} ▾`)
          .fontSize($r('app.float.caption_font_size'))
          .fontColor(this.filter === 'repo' ? $r('app.color.link_blue') : $r('app.color.text_primary'))
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .borderRadius(12)
          .backgroundColor(this.filter === 'repo' ? $r('app.color.chip_active_green_bg') : $r('app.color.card_background'))
          .border({ width: 1, color: $r('app.color.border') })
          .bindMenu(this.repoMenu())
          .onClick(() => {
            this.switchFilter('repo');
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 8 })

      Scroll() {
        Column({ space: 8 }) {
          if (this.items.length > 0) {
            ForEach(this.items, (item: NotificationItem) => {
              this.notifyCard(item)
            }, (item: NotificationItem) => item.threadId)
          } else {
            StateView({
              loading: this.loading,
              error: this.errorMsg,
              empty: !this.loading && this.errorMsg === '',
              emptyText: $r('app.string.inbox_empty')
            })
          }
        }
        .padding({ left: 16, right: 16, bottom: 16 })
        .width('100%')
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_page'))
  }
}
