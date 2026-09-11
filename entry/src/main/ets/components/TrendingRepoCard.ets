/**
 * Trending/Awesome 官方风仓库卡（Spec 056 收口，官方参考图 2026-09-07）：
 * 横幅图（openGraphImageUrl 按比例贴宽）+ owner 行 + 仓库名（黑体带下划线）+ 描述 +
 * ★ N today + 语言点 + 👥 N contributors › + 底部三态按钮（全宽 STAR / ★ + ADD TO LIST）。
 * 点击分区为同层兄弟（横幅/内容 → repoDetail，contributors 行 → 贡献者页，按钮独立），
 * 规避 ClickEvent 无 stopPropagation 的冒泡误触（沿 010 批定案拆分模式）。
 */
import { promptAction } from '@kit.ArkUI';
import { RepoSummary } from '../models/GitHubModels';
import { RepoService } from '../services/RepoService';
import { OctIcon } from './OctIcon';
import { resText } from '../utils/I18n';
import { compactCount } from '../utils/Format';

@ComponentV2
export struct TrendingRepoCard {
  @Require @Param repo: RepoSummary;
  @Param token: string = '';
  @Event onOpen: () => void = (): void => { };
  /** contributors 行 → 仓库贡献者列表页（父级注入 pushPathByName('contributors', nameWithOwner)） */
  @Event onOpenContributors: () => void = (): void => { };
  /** ADD TO LIST：父级打开列表选择 sheet（自动并入列表=星标语义，未 Star 时先 Star） */
  @Event onAddToList: (repo: RepoSummary) => void = (repo: RepoSummary): void => { };
  @Local starred: boolean = false;
  @Local working: boolean = false;

  aboutToAppear(): void {
    this.starred = this.repo.viewerHasStarred;
  }

  private toggleStar(): void {
    if (this.working || this.repo.graphqlId === '') {
      return;
    }
    this.working = true;
    RepoService.toggleStar(this.token, this.repo.graphqlId, this.starred)
      .then((nowStarred: boolean): void => {
        this.starred = nowStarred;
        this.working = false;
      })
      .catch((e: Error): void => {
        this.working = false;
        promptAction.showToast({ message: e.message });
      });
  }

  /** ADD TO LIST 语义：并入星标列表（自动 Star）+ 打开列表选择 */
  private addToList(): void {
    if (!this.starred) {
      this.toggleStar();
    }
    this.onAddToList(this.repo);
  }

  build() {
    Column() {
      if (this.repo.openGraphImageUrl !== '') {
        Image(this.repo.openGraphImageUrl)
          .width('100%')
          .height('auto')
          .borderRadius({ topLeft: 11, topRight: 11 })
          .backgroundColor($r('app.color.chip_bg'))
          .onClick(() => this.onOpen())
      }

      // 内容区（owner + 仓库名 + 描述 + 统计行）点击进 repoDetail
      Column({ space: 6 }) {
        if (this.repo.ownerLogin !== '') {
          Row({ space: 8 }) {
            Image(this.repo.ownerAvatarUrl)
              .width(20)
              .height(20)
              .borderRadius(10)
              .backgroundColor($r('app.color.heat_empty'))
            Text(this.repo.ownerLogin)
              .fontSize($r('app.float.caption_font_size'))
              .fontColor($r('app.color.text_secondary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
          }
          .width('100%')
        }

        Text(this.repo.name)
          .fontSize($r('app.float.body_font_size'))
          .fontWeight(600)
          .fontColor($r('app.color.text_primary'))
          .decoration({ type: TextDecorationType.Underline, color: $r('app.color.text_primary') })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        if (this.repo.description !== '') {
          Text(this.repo.description)
            .fontSize($r('app.float.body_font_size'))
            .fontColor($r('app.color.text_primary'))
            .lineHeight(24)
            .maxLines(4)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }

        Row({ space: 12 }) {
          Row({ space: 4 }) {
            OctIcon({ res: $r('app.media.oct_star_fill_16'), iconSize: 16, iconColor: $r('app.color.star_gold') })
            Text(resText(this.getUIContext(), $r('app.string.explore_stars_fmt'),
              compactCount(this.repo.stargazerCount)))
              .fontSize($r('app.float.body_font_size'))
              .fontWeight(600)
              .fontColor($r('app.color.text_primary'))
          }
          if (this.repo.primaryLanguage !== '') {
            Row({ space: 6 }) {
              Circle()
                .width(10)
                .height(10)
                .fill(this.repo.languageColor !== '' ? this.repo.languageColor : $r('app.color.repo_language_unknown'))
              Text(this.repo.primaryLanguage)
                .fontSize($r('app.float.body_font_size'))
                .fontWeight(600)
                .fontColor($r('app.color.text_primary'))
            }
          }
        }
        .width('100%')
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 8 })
      .onClick(() => this.onOpen())

      // contributors 行（兄弟节点：点击进贡献者页，不冒泡到内容区）
      Row({ space: 4 }) {
        OctIcon({ res: $r('app.media.oct_people_16'), iconSize: 16, iconColor: $r('app.color.text_secondary') })
        Text(resText(this.getUIContext(), $r('app.string.explore_contributors_fmt'),
          this.repo.contributorCount))
          .fontSize($r('app.float.body_font_size'))
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
        OctIcon({ res: $r('app.media.oct_chevron_right_16'), iconSize: 14, iconColor: $r('app.color.text_secondary') })
      }
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 8 })
      .onClick(() => this.onOpenContributors())

      // 按钮行（兄弟节点：点击不冒泡到整卡）
      Row({ space: 10 }) {
        if (this.starred) {
          Stack() {
            OctIcon({ res: $r('app.media.oct_star_fill_16'), iconSize: 16, iconColor: $r('app.color.star_gold') })
          }
          .width(52)
          .height(38)
          .borderRadius(8)
          .border({ width: 1, color: $r('app.color.border') })
          .onClick(() => this.toggleStar())

          Row({ space: 6 }) {
            OctIcon({ res: $r('app.media.oct_plus_24'), iconSize: 14, iconColor: $r('app.color.text_primary') })
            Text(resText(this.getUIContext(), $r('app.string.explore_add_to_list')))
              .fontSize($r('app.float.caption_font_size'))
              .fontWeight(600)
              .fontColor($r('app.color.text_primary'))
          }
          .height(38)
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
          .borderRadius(8)
          .border({ width: 1, color: $r('app.color.border') })
          .onClick(() => this.addToList())
        } else {
          Row({ space: 6 }) {
            OctIcon({ res: $r('app.media.oct_star_16'), iconSize: 16, iconColor: $r('app.color.text_primary') })
            Text(resText(this.getUIContext(), $r('app.string.explore_star')))
              .fontSize($r('app.float.caption_font_size'))
              .fontWeight(600)
              .fontColor($r('app.color.text_primary'))
          }
          .height(38)
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
          .borderRadius(8)
          .border({ width: 1, color: $r('app.color.border') })
          .onClick(() => this.toggleStar())
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 14 })
    }
    .width('100%')
    .borderRadius($r('app.float.card_radius'))
    .backgroundColor($r('app.color.card_background'))
    .border({ width: 1, color: $r('app.color.border') })
  }
}
