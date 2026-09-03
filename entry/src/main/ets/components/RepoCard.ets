/**
 * 仓库摘要卡片：名称 + 描述 + 语言色点 + Star/Fork 计数。
 * Home（Pinned）、Profile（Repos/Stars）、Explore（Topic 结果）复用。
 * isPinned=true：官方 Pinned 卡片形态（属主头像+用户名 / 仅仓库名 / 黄星+语言 dot），无 Fork 行。
 */
import { RepoSummary } from '../models/GitHubModels';
import { OctIcon } from './OctIcon';
import { resText } from '../utils/I18n';
import { compactCount } from '../utils/Format';

@ComponentV2
export struct RepoCard {
  @Param repo: RepoSummary | null = null;
  /** Pinned 卡片形态（Profile Pinned 横滑区） */
  @Param isPinned: boolean = false;
  @Event onOpen: () => void = () => {};

  build() {
    Column({ space: 6 }) {
      if (this.isPinned) {
        this.pinnedOwnerRow()
      }
      this.titleRow()
      if (this.repo !== null && this.repo.description !== '') {
        Text(this.repo.description)
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_secondary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
      if (this.isPinned) {
        this.pinnedStatsRow()
      } else {
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
    }
    .padding($r('app.float.card_padding'))
    .borderRadius($r('app.float.card_radius'))
    .backgroundColor($r('app.color.card_background'))
    .width('100%')
    .onClick(() => this.onOpen())
  }

  /** Pinned：圆形属主头像 + 用户名（置顶仓库名上方） */
  @Builder
  pinnedOwnerRow() {
    Row({ space: 6 }) {
      Image(this.repo?.ownerAvatarUrl ?? '')
        .width(20)
        .height(20)
        .borderRadius(10)
        .backgroundColor($r('app.color.heat_empty'))
      Text(this.repo?.ownerLogin ?? '')
        .fontSize($r('app.float.caption_font_size'))
        .fontColor($r('app.color.text_secondary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
    }
    .width('100%')
  }

  /** 标题行：Pinned 只显示仓库名，其余显示 nameWithOwner；右侧语言点仅在非 Pinned 显示 */
  @Builder
  titleRow() {
    Row({ space: 6 }) {
      Text(this.isPinned ? (this.repo?.name ?? '') : (this.repo?.nameWithOwner ?? ''))
        .fontSize($r('app.float.body_font_size'))
        .fontWeight(FontWeight.Medium)
        .fontColor(this.isPinned ? $r('app.color.text_primary') : $r('app.color.link_blue'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
      if (!this.isPinned && this.repo !== null && this.repo.primaryLanguage !== '') {
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
  }

  /** Pinned：黄色星 + 计数 + 语言 dot（不展示 Fork） */
  @Builder
  pinnedStatsRow() {
    Row({ space: 12 }) {
      Row({ space: 4 }) {
        OctIcon({ res: $r('app.media.oct_star_fill_16'), iconSize: 14, iconColor: $r('app.color.star_gold') })
        Text(compactCount(this.repo?.stargazerCount ?? 0))
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_secondary'))
      }
      if (this.repo !== null && this.repo.primaryLanguage !== '') {
        Row({ space: 4 }) {
          OctIcon({
            res: $r('app.media.oct_dot_fill_16'),
            iconSize: 12,
            iconColor: this.repo.languageColor !== '' ? this.repo.languageColor : $r('app.color.repo_language_blue')
          })
          Text(this.repo.primaryLanguage)
            .fontSize($r('app.float.caption_font_size'))
            .fontColor($r('app.color.text_secondary'))
        }
      }
    }
    .width('100%')
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
