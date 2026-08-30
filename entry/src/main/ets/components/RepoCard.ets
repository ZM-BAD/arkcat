/**
 * 仓库摘要卡片：名称 + 描述 + 语言色点 + Star/Fork 计数。
 * Home（Pinned）、Profile（Repos/Stars）、Explore（Topic 结果）复用。
 */
import { RepoSummary } from '../models/GitHubModels';

@ComponentV2
export struct RepoCard {
  @Param repo: RepoSummary | null = null;

  build() {
    Column({ space: 6 }) {
      Row({ space: 6 }) {
        Text(this.repo?.nameWithOwner ?? '')
          .fontSize($r('app.float.body_font_size'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.link_blue'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        if (this.repo !== null && this.repo.primaryLanguage !== '') {
          Row({ space: 4 }) {
            Circle()
              .width(10)
              .height(10)
              .fill(this.repo.languageColor !== '' ? this.repo.languageColor : $r('app.color.repo_language_blue'))
            Text(this.repo.primaryLanguage)
              .fontSize($r('app.float.caption_font_size'))
              .fontColor($r('app.color.text_secondary'))
          }
        }
      }
      .width('100%')

      if (this.repo !== null && this.repo.description !== '') {
        Text(this.repo.description)
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_secondary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }

      Row({ space: 12 }) {
        Text(`★ ${this.repo?.stargazerCount ?? 0}`)
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_secondary'))
        Text(`⑂ ${this.repo?.forkCount ?? 0}`)
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_secondary'))
      }
      .width('100%')
    }
    .padding($r('app.float.card_padding'))
    .borderRadius($r('app.float.card_radius'))
    .backgroundColor($r('app.color.card_background'))
    .width('100%')
  }
}
