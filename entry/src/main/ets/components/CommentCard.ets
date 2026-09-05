/**
 * 评论卡片（Spec 041）：头像/作者/时间/正文（040 MarkdownView）+ 反应条 + 行尾菜单。
 * 编辑/删除仅 viewerDidAuthor 显示；动作回调给页面（传入评论回填/确认弹窗）。
 */
import { MarkdownView } from './MarkdownView';
import { ReactionBar } from './ReactionBar';
import { RepoComment } from '../models/RepoSubModels';
import { githubShortTime, timeParts, TimeParts } from '../utils/Format';
import { resText } from '../utils/I18n';

@ComponentV2
export struct CommentCard {
  @Require @Param comment: RepoComment = {} as RepoComment;
  @Param token: string = '';
  /** 站内链接路由（MarkdownView onNavigate 透传） */
  @Event onNavigate: (name: string, param: string) => void = (name: string, param: string): void => { };
  @Event onEdit: (comment: RepoComment) => void = (comment: RepoComment): void => { };
  @Event onDelete: (comment: RepoComment) => void = (comment: RepoComment): void => { };
  /** 反应变化（本地翻转后仍通知父级做远期数据校准） */
  @Event onReactionChanged: () => void = (): void => { };

  private stringOf(res: Resource): string {
    return resText(this.getUIContext(), res);
  }

  private timeText(parts: TimeParts | null): string {
    return parts !== null ? githubShortTime(parts) : '';
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
        Text(this.comment.authorLogin)
          .fontSize($r('app.float.caption_font_size'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
        Text(this.timeText(timeParts(this.comment.createdAt, Date.now())))
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_secondary'))
        if (this.comment.viewerDidAuthor) {
          Text('⋯')
            .fontSize(16)
            .fontColor($r('app.color.text_secondary'))
            .width(28)
            .height(28)
            .responseRegion({ x: -8, y: -8, width: '160%', height: '160%' })
            .textAlign(TextAlign.Center)
            .accessibilityDescription($r('app.string.a11y_more'))
            .bindMenu([
              {
                value: $r('app.string.comment_edit_title'),
                action: (): void => this.onEdit(this.comment)
              },
              {
                value: $r('app.string.comment_delete_title'),
                action: (): void => this.onDelete(this.comment)
              }
            ])
        }
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
        onChanged: (): void => this.onReactionChanged()
      })
    }
    .padding($r('app.float.card_padding'))
    .borderRadius($r('app.float.card_radius'))
    .backgroundColor($r('app.color.card_background'))
    .width('100%')
    .margin({ bottom: 8 })
  }
}
