/**
 * 评论卡片（Spec 041）：头像/作者/时间/正文（040 MarkdownView）+ 反应条 + 行尾菜单。
 * 编辑/删除仅 viewerDidAuthor 显示；动作回调给页面（传入评论回填/确认弹窗）。
 */
import { MarkdownView } from './MarkdownView';
import { OctIcon } from './OctIcon';
import { ReactionBar } from './ReactionBar';
import { RepoComment, actorDisplayLogin } from '../models/RepoSubModels';
import { githubShortTime, timeParts, TimeParts } from '../utils/Format';
import { resText } from '../utils/I18n';

/** bindPopup onStateChange 回调类型（与 PrDiffCard 同款自声明） */
interface PopupState {
  isVisible: boolean;
}

@ComponentV2
export struct CommentCard {
  @Require @Param comment: RepoComment = {} as RepoComment;
  @Param token: string = '';
  /** 站内链接路由（MarkdownView onNavigate 透传） */
  @Event onNavigate: (name: string, param: string) => void = (name: string, param: string): void => { };
  @Event onEdit: (comment: RepoComment) => void = (comment: RepoComment): void => { };
  @Event onDelete: (comment: RepoComment) => void = (comment: RepoComment): void => { };
  /** 分享（评论卡菜单，Android 官方对齐；页面分享 issue 链接） */
  @Event onShare: (comment: RepoComment) => void = (comment: RepoComment): void => { };
  /** 引用回复（官方 Quote reply：`> 正文` 填入评论草稿并打开输入面板） */
  @Event onQuoteReply: (comment: RepoComment) => void = (comment: RepoComment): void => { };
  /** 行内菜单开合（自绘弹层，可上色 Delete 红） */
  @Local menuOpen: boolean = false;
  /** 反应变化（本地翻转后仍通知父级做远期数据校准） */
  @Event onReactionChanged: () => void = (): void => { };

  private stringOf(res: Resource): string {
    return resText(this.getUIContext(), res);
  }

  private timeText(parts: TimeParts | null): string {
    return parts !== null ? githubShortTime(parts) : '';
  }

  /** 官方评论菜单（自绘可上色）：Share / Quote reply / Edit(本人) / Delete(本人红)；其余项切刀 */
  @Builder
  commentMenu() {
    Column() {
      this.menuItem($r('app.media.oct_share_android_16'), $r('app.string.a11y_share'),
        $r('app.color.text_primary'), (): void => this.onShare(this.comment))
      this.menuItem($r('app.media.oct_comment_16'), $r('app.string.menu_quote_reply'),
        $r('app.color.text_primary'), (): void => this.onQuoteReply(this.comment))
      if (this.comment.viewerDidAuthor) {
        this.menuItem($r('app.media.oct_pencil_16'), $r('app.string.comment_edit_title'),
          $r('app.color.text_primary'), (): void => this.onEdit(this.comment))
        this.menuItem($r('app.media.oct_trash_16'), $r('app.string.comment_delete_title'),
          $r('app.color.danger_text'), (): void => this.onDelete(this.comment))
      }
    }
    .width(190)
    .borderRadius(12)
    .backgroundColor($r('app.color.card_background'))
    .shadow({ radius: 24, color: $r('app.color.shadow_floating'), offsetY: 8 })
    .padding({ top: 6, bottom: 6 })
  }

  @Builder
  menuItem(iconRes: Resource, label: ResourceStr, color: ResourceColor, onTap: () => void) {
    Row({ space: 10 }) {
      OctIcon({ res: iconRes, iconSize: 16, iconColor: color })
      Text(label)
        .fontSize($r('app.float.body_font_size'))
        .fontColor(color)
    }
    .width('100%')
    .height(40)
    .responseRegion({ x: 0, y: -2, width: '100%', height: '110%' })
    .padding({ left: 14, right: 14 })
    .onClick((): void => {
      this.menuOpen = false;
      onTap();
    })
  }

  build() {
    Column({ space: 6 }) {
      Row({ space: 8 }) {
        if (this.comment.authorAvatar !== '') {
          Image(this.comment.authorAvatar)
            .width(24)
            .height(24)
            .borderRadius(12)
            .backgroundColor($r('app.color.heat_empty'))
        } else {
          Circle().width(24).height(24).fill($r('app.color.heat_empty'))
        }
        Text(actorDisplayLogin(this.comment.authorLogin, this.comment.authorIsBot))
          .fontSize($r('app.float.caption_font_size'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
        Text(this.timeText(timeParts(this.comment.createdAt, Date.now())))
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_secondary'))
        // 右上灰三横点（Android 官方：全员可见；项按权限显隐）
        Stack() {
          OctIcon({ res: $r('app.media.oct_kebab_horizontal_16'), iconSize: 16,
            iconColor: $r('app.color.text_secondary') })
        }
        .width(28)
        .height(28)
        .responseRegion({ x: -8, y: -8, width: '160%', height: '160%' })
        .accessibilityDescription($r('app.string.a11y_more'))
        .onClick((): void => {
          this.menuOpen = !this.menuOpen;
        })
        .bindPopup(this.menuOpen, {
          builder: (): void => this.commentMenu(),
          placement: Placement.BottomRight,
          enableArrow: false,
          mask: true,
          onStateChange: (e: PopupState): void => {
            if (!e.isVisible) {
              this.menuOpen = false;
            }
          }
        })
      }
      .width('100%')

      MarkdownView({
        html: this.comment.bodyHTML,
        fallbackText: this.comment.body,
        foldThreshold: 0,
        onNavigate: (name: string, param: string) => this.onNavigate(name, param)
      })

      ReactionBar({
        token: this.token,
        subjectId: this.comment.id,
        reactions: this.comment.reactions,
        // 官方评论卡反应行：圆轮廓笑脸钮弹 8 种全集（与正文反应行同款）；
        // 芯片整颗可点翻转，长按芯片进 Reactees 整页（release/正文同口径）
        smileyTrigger: true,
        pickerFull: true,
        onChanged: (): void => this.onReactionChanged(),
        onOpenUsers: (subjectId: string, content: string): void => {
          this.onNavigate('reactionUsers', `${encodeURIComponent(subjectId)}/${content}`);
        }
      })
    }
    .padding($r('app.float.card_padding'))
    .borderRadius($r('app.float.card_radius'))
    .backgroundColor($r('app.color.card_background'))
    .width('100%')
    .margin({ bottom: 8 })
  }
}
