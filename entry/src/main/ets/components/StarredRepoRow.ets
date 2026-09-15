/**
 * Starred 仓库卡（Spec 023/035）：归属行（头像/owner/⋯）+ 名称 + 描述 + 星数/语言。
 * ⋯ 打开列表成员 sheet 经 onOpenList 上抛（仅本人 Starred 页展示，showListAction 控制）；
 * 点卡片跳仓库详情经 onOpenDetail 上抛。
 */
import { OctIcon } from './OctIcon';
import { WorkStarredRepoItem } from '../models/WorkModels';
import { compactCount } from '../utils/Format';

@ComponentV2
export struct StarredRepoRow {
  @Param repo: WorkStarredRepoItem = {
    id: '', name: '', ownerLogin: '', ownerAvatar: '', description: '',
    stargazerCount: 0, language: '', languageColor: ''
  };
  /** 行内 ⋯（加入我的列表）是否展示：他人 Starred 页隐藏 */
  @Param showListAction: boolean = true;
  @Event onOpenDetail: () => void = (): void => { };
  /** ⋯ 点击：打开列表成员 sheet */
  @Event onOpenList: () => void = (): void => { };

  build() {
    Column({ space: 6 }) {
      Row({ space: 8 }) {
        if (this.repo.ownerAvatar !== '') {
          Image(this.repo.ownerAvatar)
            .width(18)
            .height(18)
            .borderRadius(9)
            .backgroundColor($r('app.color.heat_empty'))
        }
        Text(this.repo.ownerLogin)
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        // 图标贴触点框右上、行内容顶对齐：顶部留白与下方 star 行一致（card_padding 12）
        if (this.showListAction) {
          Stack({ alignContent: Alignment.TopEnd }) {
            OctIcon({
              res: $r('app.media.oct_kebab_horizontal_16'),
              iconSize: 15,
              iconColor: $r('app.color.text_secondary')
            })
          }
          .width(32)
          .height(32)
          .accessibilityDescription($r('app.string.a11y_more'))
          .focusable(true)
          .onClick((): void => this.onOpenList())
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      Text(this.repo.name)
        .fontSize($r('app.float.body_font_size'))
        .fontWeight(600)
        .fontColor($r('app.color.text_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')

      if (this.repo.description !== '') {
        Text(this.repo.description)
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_secondary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }

      Row({ space: 8 }) {
        OctIcon({ res: $r('app.media.oct_star_fill_16'), iconSize: 12, iconColor: $r('app.color.star_gold') })
        Text(compactCount(this.repo.stargazerCount))
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_primary'))
        if (this.repo.language !== '') {
          // 与左侧 star 同规格：dot-fill 图标 + iconSize 12（走查拍板：圆点须与 star 图标等大）
          OctIcon({ res: $r('app.media.oct_dot_fill_16'), iconSize: 12,
            iconColor: this.repo.languageColor !== '' ? this.repo.languageColor : $r('app.color.repo_language_unknown') })
          Text(this.repo.language)
            .fontSize($r('app.float.caption_font_size'))
            .fontColor($r('app.color.text_secondary'))
        }
      }
      .width('100%')
    }
    .padding($r('app.float.card_padding'))
    .borderRadius($r('app.float.card_radius'))
    .backgroundColor($r('app.color.card_background'))
    .width('100%')
    .margin({ bottom: 8 })
    .onClick((): void => this.onOpenDetail())
  }
}
