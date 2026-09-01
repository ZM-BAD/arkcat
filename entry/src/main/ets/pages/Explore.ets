/**
 * Explore Tab（Spec 003）：Discover 区（Trending/Awesome Lists）+ Activity 推荐流 + Topics 网格。
 * Collections 区块按 Spec 边界隐藏（无公开 API）。
 */
import { promptAction } from '@kit.ArkUI';
import { TopicSearchResult } from '../models/ExploreModels';
import { RepoSummary } from '../models/GitHubModels';
import { ExploreService, FEATURED_TOPICS } from '../services/ExploreService';
import { RepoCard } from '../components/RepoCard';
import { StateView } from '../components/StateView';
import { resText } from '../utils/I18n';

@ComponentV2
export struct ExploreView {
  @Param token: string = '';
  @Param pathStack: NavPathStack = new NavPathStack();
  @Local selectedTopic: string = '';
  @Local result: TopicSearchResult | null = null;
  @Local recommended: RepoSummary[] = [];
  @Local loading: boolean = false;
  @Local errorMsg: string = '';

  aboutToAppear(): void {
    this.loadRecommendations();
  }

  /** Activity 推荐仓库（高星近似，官方个性化推荐无公开 API） */
  private loadRecommendations(): void {
    ExploreService.fetchRecommendedRepos(this.token)
      .then((repos: RepoSummary[]) => {
        this.recommended = repos;
      })
      .catch((e: Error) => {
        // 推荐失败不影响 Discover/Topics 使用
      });
  }

  private openTopic(topic: string): void {
    this.selectedTopic = topic;
    this.loading = true;
    this.errorMsg = '';
    ExploreService.fetchTopicRepositories(this.token, topic)
      .then((result: TopicSearchResult) => {
        this.result = result;
        this.loading = false;
      })
      .catch((e: Error) => {
        this.errorMsg = e.message;
        this.loading = false;
      });
  }

  private comingSoon(): void {
    promptAction.showToast({ message: $r('app.string.home_feature_coming') });
  }

  @Builder
  topicChip(topic: string) {
    Text(topic)
      .fontSize($r('app.float.caption_font_size'))
      .fontColor(this.selectedTopic === topic ? Color.White : $r('app.color.text_primary'))
      .padding({ left: 14, right: 14, top: 6, bottom: 6 })
      .borderRadius(14)
      .backgroundColor(this.selectedTopic === topic ? $r('app.color.link_blue') : $r('app.color.card_background'))
      .margin({ right: 8, bottom: 8 })
      .onClick(() => this.openTopic(topic))
  }

  /** Discover 入口块：彩色方标 + 标题 */
  @Builder
  discoverEntry(icon: string, color: ResourceColor, labelRes: Resource) {
    Row({ space: 10 }) {
      Text(icon)
        .fontSize(20)
        .fontColor(Color.White)
        .width(36)
        .height(36)
        .textAlign(TextAlign.Center)
        .backgroundColor(color)
        .borderRadius(6)
      Text(labelRes)
        .fontSize($r('app.float.body_font_size'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
    }
    .width('100%')
    .padding(12)
    .borderRadius(12)
    .backgroundColor($r('app.color.card_background'))
    .margin({ bottom: 10 })
    .onClick(() => this.comingSoon())
  }

  @Builder
  recommendedCard(repo: RepoSummary) {
    Column({ space: 6 }) {
      Row({ space: 4 }) {
        Text('●')
          .fontSize(12)
          .fontColor($r('app.color.link_blue'))
        Text(repo.nameWithOwner)
          .fontSize($r('app.float.body_font_size'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.link_blue'))
          .maxLines(1)
          .layoutWeight(1)
        Text(this.starsText(repo))
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_secondary'))
      }
      .width('100%')
      .onClick(() => {
        this.pathStack.pushPathByName('repoDetail', repo.nameWithOwner);
      })

      if (repo.primaryLanguage !== '') {
        Text(`${repo.primaryLanguage}`)
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
      }

      Button($r('app.string.explore_star'))
        .fontSize($r('app.float.caption_font_size'))
        .fontColor($r('app.color.link_blue'))
        .backgroundColor(Color.Transparent)
        .height(36)
        .borderRadius(6)
        .border({ width: 1, color: $r('app.color.border') })
        .onClick(() => this.comingSoon())
    }
    .padding($r('app.float.card_padding'))
    .borderRadius($r('app.float.card_radius'))
    .backgroundColor($r('app.color.card_background'))
    .width('100%')
    .margin({ bottom: 8 })
  }

  /** topic 仓库计数文案（Spec 012：%1$s/%2$d 位置占位） */
  private topicCountText(): string {
    return resText(this.getUIContext(), $r('app.string.explore_topic_count'),
      this.selectedTopic, this.result?.repositoryCount ?? 0);
  }

  private starsText(repo: RepoSummary): string {
    return resText(this.getUIContext(), $r('app.string.repo_stars_fmt'), repo.stargazerCount);
  }

  build() {
    Column() {
      Text($r('app.string.tab_explore'))
        .fontSize($r('app.float.title_font_size'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
        .padding($r('app.float.page_padding'))

      Scroll() {
        Column() {
          // Discover 区（Spec 003）
          Text($r('app.string.explore_discover'))
            .fontSize($r('app.float.title_font_size'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .width('100%')
            .margin({ top: 8, bottom: 8 })

          this.discoverEntry('🔥', '#D94130', $r('app.string.explore_trending'))
          this.discoverEntry('✦', $r('app.color.shortcut_purple_fg'), $r('app.string.explore_awesome'))

          // Activity 区（Spec 003 推荐流）
          Text($r('app.string.explore_activity'))
            .fontSize($r('app.float.title_font_size'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .width('100%')
            .margin({ top: 16, bottom: 8 })

          if (this.recommended.length > 0) {
            ForEach(this.recommended, (repo: RepoSummary) => {
              this.recommendedCard(repo)
            }, (repo: RepoSummary) => repo.id !== '' ? repo.id : repo.nameWithOwner)
          }

          // Topics 区（原功能保留）
          Text($r('app.string.explore_topics_title'))
            .fontSize($r('app.float.title_font_size'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .width('100%')
            .margin({ top: 16, bottom: 8 })

          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(FEATURED_TOPICS, (topic: string) => {
              this.topicChip(topic)
            }, (topic: string) => topic)
          }
          .width('100%')

          if (this.selectedTopic !== '') {
            Text(this.topicCountText())
              .fontSize($r('app.float.caption_font_size'))
              .fontColor($r('app.color.text_secondary'))
              .width('100%')
              .margin({ top: 12, bottom: 8 })

            if (this.result !== null && !this.loading && this.errorMsg === '') {
              ForEach(this.result.repos, (repo: RepoSummary) => {
                RepoCard({
                  repo: repo,
                  onOpen: (): void => {
                    this.pathStack.pushPathByName('repoDetail', repo.nameWithOwner);
                  }
                })
                  .margin({ bottom: 8 })
              }, (repo: RepoSummary) => repo.id !== '' ? repo.id : repo.nameWithOwner)
            } else {
              StateView({
                loading: this.loading,
                error: this.errorMsg,
                onRetry: () => this.openTopic(this.selectedTopic)
              })
            }
          }
        }
        .padding({ left: 16, right: 16, bottom: 16 })
        .width('100%')
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_page'))
  }
}
