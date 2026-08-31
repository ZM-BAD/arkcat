/**
 * Inbox Tab（Spec 002）：通知列表 + All/Unread 筛选 + 点击标记已读。
 * 详情页为 Spec 008/009 范围，当前点击仅标记已读并提示。
 */
import { promptAction } from '@kit.ArkUI';
import { NotificationItem } from '../models/GitHubModels';
import { NotificationsService } from '../services/NotificationsService';
import { StateView } from '../components/StateView';
import { timeParts, notificationTypeKey, TimeParts } from '../utils/Format';
import { resText } from '../utils/I18n';

@ComponentV2
export struct InboxView {
  @Param token: string = '';
  @Local all: boolean = true;
  @Local items: NotificationItem[] = [];
  @Local loading: boolean = true;
  @Local errorMsg: string = '';

  aboutToAppear(): void {
    this.refresh();
  }

  private refresh(): void {
    this.loading = true;
    this.errorMsg = '';
    NotificationsService.fetchNotifications(this.token, this.all)
      .then((items: NotificationItem[]) => {
        this.items = items;
        this.loading = false;
      })
      .catch((e: Error) => {
        this.errorMsg = e.message;
        this.loading = false;
      });
  }

  private switchFilter(all: boolean): void {
    if (this.all === all) {
      return;
    }
    this.all = all;
    this.refresh();
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
            updatedAt: it.updatedAt
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

  /** 通知副行：本地化类型 · reason（API 原文）· 相对时间 */
  private subjectLine(item: NotificationItem): string {
    const type = this.notifTypeLabel(item.subjectType);
    const parts = timeParts(item.updatedAt, Date.now());
    const time = parts === null ? '' : this.timeText(parts);
    return `${type} · ${item.reason} · ${time}`;
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

  /** 相对时间结构化数据 → 当前语言文案（%1$d 位置占位） */
  private timeText(parts: TimeParts): string {
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
    }
  }

  @Builder
  filterTab(label: string, active: boolean, onClick: () => void) {
    Text(label)
      .fontSize($r('app.float.body_font_size'))
      .fontColor(active ? $r('app.color.primary') : $r('app.color.text_secondary'))
      .padding({ left: 16, right: 16, top: 6, bottom: 6 })
      .borderRadius(16)
      .backgroundColor(active ? '#DBEFE3' : $r('app.color.card_background'))
      .onClick(onClick)
  }

  @Builder
  notifyCard(item: NotificationItem) {
    Row({ space: 8 }) {
      Circle()
        .width(8)
        .height(8)
        .fill($r('app.color.badge_red'))
        .opacity(item.unread ? 1 : 0)
        .margin({ top: 6 })
      Column({ space: 4 }) {
        Text(item.repoFullName)
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_secondary'))
          .maxLines(1)
        Text(item.title)
          .fontSize($r('app.float.body_font_size'))
          .fontWeight(item.unread ? FontWeight.Bold : FontWeight.Normal)
          .fontColor($r('app.color.text_primary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.subjectLine(item))
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_secondary'))
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

  build() {
    Column() {
      Text($r('app.string.tab_inbox'))
        .fontSize($r('app.float.title_font_size'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
        .padding($r('app.float.page_padding'))

      Row({ space: 8 }) {
        this.filterTab(this.stringOf($r('app.string.inbox_filter_all')), this.all, (): void => this.switchFilter(true))
        this.filterTab(this.stringOf($r('app.string.inbox_filter_unread')), !this.all, (): void => this.switchFilter(false))
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
