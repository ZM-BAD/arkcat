/**
 * Inbox 通知卡片（Spec 002）：仓库+编号 / 标题粗体（未读）/ 类型图标+摘要 / 右侧相对时间。
 * 纯展示组件，点击经 onMarkRead 上抛；图标判定与时间格式化等工具函数随卡片迁入。
 */
import { NotificationItem, issueNumberFromUrl } from '../models/GitHubModels';
import { OctIcon } from './OctIcon';
import { timeParts, githubShortTime, notificationTypeKey, TimeParts } from '../utils/Format';
import { resText } from '../utils/I18n';

@ComponentV2
export struct InboxNotifyCard {
  @Param item: NotificationItem = {
    threadId: '', repoFullName: '', title: '', subjectType: '', reason: '', unread: false, updatedAt: '',
    subjectUrl: '', ownerAvatarUrl: '', prMerged: false
  };
  @Event onMarkRead: (item: NotificationItem) => void = (item: NotificationItem): void => { };

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

  /** 通知类型 → 图标（卡片左上角；PR 已合并显示 merge 图标） */
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

  /** 卡片编号行：编号非空才显示（方法返回，供 @Builder 内 if 判断） */
  private issueNum(item: NotificationItem): string {
    return issueNumberFromUrl(item.subjectUrl);
  }

  /** 通知副行：类型 · reason（API 原文）（Spec 002 摘要降级） */
  private subjectLine(item: NotificationItem): string {
    return `${this.notifTypeLabel(item.subjectType)} · ${item.reason}`;
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
          .fontWeight(item.unread ? 600 : FontWeight.Normal)
          .fontColor($r('app.color.text_primary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        Row({ space: 4 }) {
          // 底行前：仓库属主头像（REST owner.avatar_url，缺失占位灰圆）
          Image(item.ownerAvatarUrl)
            .width(16)
            .height(16)
            .borderRadius(6)
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
    .onClick((): void => this.onMarkRead(item))
  }

  build() {
    this.notifyCard(this.item)
  }
}
