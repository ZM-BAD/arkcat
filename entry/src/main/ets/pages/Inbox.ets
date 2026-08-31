/**
 * Inbox Tab（Spec 002）：通知列表 + All/Unread 筛选 + 点击标记已读。
 * 详情页为 Spec 008/009 范围，当前点击仅标记已读并提示。
 */
import { promptAction } from '@kit.ArkUI';
import { NotificationItem } from '../models/GitHubModels';
import { NotificationsService } from '../services/NotificationsService';
import { StateView } from '../components/StateView';
import { relativeTime, notificationTypeLabel } from '../utils/Format';

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
      promptAction.showToast({ message: '详情页将在后续 Spec 实现' });
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
        promptAction.showToast({ message: '已标记为已读' });
      })
      .catch((e: Error) => {
        promptAction.showToast({ message: `标记失败: ${e.message}` });
      });
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
        Text(`${notificationTypeLabel(item.subjectType)} · ${item.reason} · ${relativeTime(item.updatedAt, Date.now())}`)
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
        this.filterTab('All', this.all, (): void => this.switchFilter(true))
        this.filterTab('Unread', !this.all, (): void => this.switchFilter(false))
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
              emptyText: '暂无通知'
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
