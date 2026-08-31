/**
 * Explore Tab（Spec 003）：搜索入口 + Topics 网格 + Topic 仓库列表。
 * Collections 区块按 Spec 边界隐藏（无公开 API）。
 */
import { promptAction } from '@kit.ArkUI';
import { TopicSearchResult } from '../models/ExploreModels';
import { RepoSummary } from '../models/GitHubModels';
import { ExploreService, FEATURED_TOPICS } from '../services/ExploreService';
import { RepoCard } from '../components/RepoCard';
import { StateView } from '../components/StateView';

@ComponentV2
export struct ExploreView {
  @Param token: string = '';
  @Param pathStack: NavPathStack = new NavPathStack();
  @Local selectedTopic: string = '';
  @Local result: TopicSearchResult | null = null;
  @Local loading: boolean = false;
  @Local errorMsg: string = '';

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

  @Builder
  topicChip(topic: string) {
    Text(topic)
      .fontSize($r('app.float.caption_font_size'))
      .fontColor(this.selectedTopic === topic ? Color.White : $r('app.color.text_primary'))
      .padding({ left: 14, right: 14, top: 6, bottom: 6 })
      .borderRadius(14)
      .backgroundColor(this.selectedTopic === topic ? $r('app.color.primary') : $r('app.color.card_background'))
      .margin({ right: 8, bottom: 8 })
      .onClick(() => this.openTopic(topic))
  }

  build() {
    Column() {
      Text($r('app.string.tab_explore'))
        .fontSize($r('app.float.title_font_size'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
        .padding($r('app.float.page_padding'))

      // 搜索入口：全局搜索页为后续 Spec 范围，先提示
      Row() {
        Text('🔍')
          .fontSize(16)
        Text('搜索仓库 / 开发者')
          .fontSize($r('app.float.body_font_size'))
          .fontColor($r('app.color.text_secondary'))
          .margin({ left: 8 })
        Blank()
      }
      .width('100%')
      .padding(12)
      .borderRadius(20)
      .backgroundColor($r('app.color.card_background'))
      .margin({ left: 16, right: 16 })
      .onClick(() => {
        promptAction.showToast({ message: $r('app.string.home_search_hint') });
      })

      Scroll() {
        Column() {
          Text('Topics')
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
            Text(`topic:${this.selectedTopic} · ${this.result?.repositoryCount ?? 0} 个仓库`)
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
