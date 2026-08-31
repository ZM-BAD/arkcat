/**
 * 用户卡片组件：头像 + 用户名 + bio + followers/following。
 * Spec 001 元素 4；点击头像区域触发 onOpenProfile（Spec 005 实现路由目的地）。
 */
import { UserSummary } from '../models/GitHubModels';
import { resText } from '../utils/I18n';

@ComponentV2
export struct UserCard {
  @Param user: UserSummary | null = null;
  @Event onOpenProfile: () => void = () => {};

  build() {
    Row({ space: 12 }) {
      Image(this.user?.avatarUrl ?? '')
        .width($r('app.float.avatar_size_medium'))
        .height($r('app.float.avatar_size_medium'))
        .borderRadius($r('app.float.avatar_size_medium'))
        .backgroundColor($r('app.color.heat_empty'))
        .onClick(() => this.onOpenProfile())

      Column({ space: 4 }) {
        Text(this.user && this.user.name !== '' ? this.user.name : this.user?.login ?? '')
          .fontSize($r('app.float.title_font_size'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`@${this.user?.login ?? ''}`)
          .fontSize($r('app.float.body_font_size'))
          .fontColor($r('app.color.text_secondary'))
        if (this.user !== null && this.user.bio !== '') {
          Text(this.user.bio)
            .fontSize($r('app.float.caption_font_size'))
            .fontColor($r('app.color.text_secondary'))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        Text(this.followersText())
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
  }

  /** followers/following 本地化文案（Spec 012：%1$d/%2$d 位置占位） */
  private followersText(): string {
    return resText(this.getUIContext(), $r('app.string.followers_suffix'),
      this.user?.followers ?? 0, this.user?.following ?? 0);
  }
}
