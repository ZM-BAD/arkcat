/**
 * 仓库摘要卡片：名称 + 描述 + 语言色点 + Star/Fork 计数。
 * Home（Pinned）、Profile（Repos/Stars）、Explore（Topic 结果）复用。
 */
import { RepoSummary } from '../models/GitHubModels';
import { resText } from '../utils/I18n';

@ComponentV2
export struct RepoCard {
  @Param repo: RepoSummary | null = null;
  @Event onOpen: () => void = () => {};

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
        Text(this.starsText())
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_secondary'))
        Text(this.forksText())
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_secondary'))
      }
      .width('100%')
    }
    .padding($r('app.float.card_padding'))
    .borderRadius($r('app.float.card_radius'))
    .backgroundColor($r('app.color.card_background'))
    .width('100%')
    .onClick(() => this.onOpen())
  }

  private starsText(): string {
    return resText(this.getUIContext(), $r('app.string.repo_stars_fmt'),
      this.repo?.stargazerCount ?? 0);
  }

  private forksText(): string {
    return resText(this.getUIContext(), $r('app.string.repo_forks_fmt'),
      this.repo?.forkCount ?? 0);
  }
}
