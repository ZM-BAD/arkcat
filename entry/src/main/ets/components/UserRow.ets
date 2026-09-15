/**
 * 用户列表行：56/48 圆头像 + 粗体显示名（可省）+ 灰 login + 两行 bio（可省）。
 *
 * 此前 Stargazers/UserList/RepoPeopleView/ReactionUsers 四页逐字手写同构行
 * （仅有无 bio、空头像兜底两处漂移），现统一收口；SearchRows 的搜索行（48 档）亦同型。
 */
import { Avatar } from './Avatar';

@ComponentV2
export struct UserRow {
  @Param avatarUrl: string = '';
  /** 显示名；空串不渲染（仅显 login） */
  @Param name: string = '';
  @Param login: string = '';
  /** 个人简介；空串不渲染（ReactionUsers 等无 bio 列表） */
  @Param bio: string = '';
  /** 头像边长：列表行 56、搜索行 48 */
  @Param avatarSize: number = 56;
  /** 空头像时显示 person 兜底图标 */
  @Param fallbackIcon: boolean = false;
  /** 行上下内边距：标准 10，用户列表紧凑 8 */
  @Param verticalPadding: number = 10;
  @Event onOpen: () => void = () => {};

  build() {
    Row({ space: 12 }) {
      Avatar({ url: this.avatarUrl, diameter: this.avatarSize, fallbackIcon: this.fallbackIcon })
      Column({ space: 3 }) {
        if (this.name !== '') {
          Text(this.name)
            .fontSize($r('app.float.body_font_size'))
            .fontWeight(600)
            .fontColor($r('app.color.text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        Text(this.login)
          .fontSize($r('app.float.body_font_size'))
          .fontColor($r('app.color.text_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (this.bio !== '') {
          Text(this.bio)
            .fontSize($r('app.float.body_font_size'))
            .fontColor($r('app.color.text_primary'))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .lineHeight(20)
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: this.verticalPadding, bottom: this.verticalPadding })
    .onClick(() => this.onOpen())
  }
}
