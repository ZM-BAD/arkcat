/**
 * Search 页（Spec 015）：搜索栏 + 六类建议入口 + Code 结果卡。
 * GitHub GraphQL CODE search 只返回文件名/路径/仓库；代码行正文/高亮为后续 Spec。
 */
import { promptAction } from '@kit.ArkUI';
import { SearchService, CodeSearchItem, SEARCH_SUGGESTION_TYPES } from '../services/SearchService';
import { StateView } from '../components/StateView';
import { resText } from '../utils/I18n';

@ComponentV2
export struct SearchView {
  @Param token: string = '';
  @Param pathStack: NavPathStack = new NavPathStack();
  @Local keyword: string = '';
  @Local activeCategory: string = '';
  @Local results: CodeSearchItem[] = [];
  @Local loading: boolean = false;
  @Local errorMsg: string = '';
  @Local searched: boolean = false;

  private onSearchInput(v: string): void {
    this.keyword = v;
    // 关键词变化后清空结果，回到建议列表
    if (this.activeCategory !== '') {
      this.activeCategory = '';
      this.results = [];
      this.searched = false;
    }
  }

  private runCodeSearch(): void {
    const kw = this.keyword.trim();
    if (kw === '') {
      return;
    }
    this.activeCategory = 'code';
    this.loading = true;
    this.errorMsg = '';
    this.searched = true;
    SearchService.fetchCodeResults(this.token, kw)
      .then((items: CodeSearchItem[]) => {
        this.results = items;
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

  /** 资源 → 当前语言纯文案 */
  private stringOf(res: Resource): string {
    return resText(this.getUIContext(), res);
  }

  /** 建议行文案（Spec 015：Code/Repos/Issues/PRs/People/Orgs with "q"） */
  private suggestionLabel(type: string): string {
    const ui = this.getUIContext();
    const kw = this.keyword.trim();
    switch (type) {
      case 'code':
        return resText(ui, $r('app.string.search_suggestion_code'), kw);
      case 'repositories':
        return resText(ui, $r('app.string.search_suggestion_repositories'), kw);
      case 'issues':
        return resText(ui, $r('app.string.search_suggestion_issues'), kw);
      case 'prs':
        return resText(ui, $r('app.string.search_suggestion_prs'), kw);
      case 'people':
        return resText(ui, $r('app.string.search_suggestion_people'), kw);
      case 'orgs':
        return resText(ui, $r('app.string.search_suggestion_orgs'), kw);
      default:
        return type;
    }
  }

  private suggestionIcon(type: string): string {
    switch (type) {
      case 'code':
        return '<>';
      case 'repositories':
        return '▣';
      case 'issues':
        return '◷';
      case 'prs':
        return '⑂';
      case 'people':
        return '👤';
      case 'orgs':
        return '▤';
      default:
        return '?';
    }
  }

  /** 文件卡片扩展名徽章（Markdown 等） */
  private badgeText(item: CodeSearchItem): string {
    if (item.isMarkdown) {
      return this.stringOf($r('app.string.markdown_badge'));
    }
    const seg = item.name.split('.');
    return seg.length > 1 ? seg[seg.length - 1].toUpperCase() : '';
  }

  @Builder
  suggestionRow(icon: string, label: string, onClick: () => void) {
    Row({ space: 14 }) {
      Text(icon)
        .fontSize(18)
        .fontColor($r('app.color.text_secondary'))
        .width(28)
        .textAlign(TextAlign.Center)
      Text(label)
        .fontSize($r('app.float.body_font_size'))
        .fontColor($r('app.color.text_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .height(54)
    .padding({ left: 16, right: 16 })
    .onClick(onClick)
  }

  @Builder
  codeCard(item: CodeSearchItem) {
    Column({ space: 6 }) {
      Row({ space: 6 }) {
        Text('📄')
          .fontSize(14)
        Text(item.repoFullName)
          .fontSize($r('app.float.body_font_size'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.link_blue'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        Text(item.name)
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_secondary'))
          .maxLines(1)
      }
      .width('100%')
      .onClick(() => this.comingSoon())

      Row({ space: 8 }) {
        Circle()
          .width(12)
          .height(12)
          .fill('#8250DF')
        Text(this.badgeText(item))
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_primary'))
      }
      .width('100%')

      // 代码行占位（正文从 REST 兜底，Spec 016 补充）
      Text(item.path)
        .fontSize($r('app.float.caption_font_size'))
        .fontColor($r('app.color.text_secondary'))
        .maxLines(3)
        .width('100%')
        .padding(10)
        .backgroundColor('#F6F8FA')
        .borderRadius(6)
    }
    .padding($r('app.float.card_padding'))
    .borderRadius($r('app.float.card_radius'))
    .backgroundColor($r('app.color.card_background'))
    .width('100%')
    .margin({ bottom: 8 })
  }

  build() {
    Column() {
      // 搜索栏
      Row({ space: 8 }) {
        Text('←')
          .fontSize(20)
          .onClick(() => {
            this.pathStack.pop();
          })
        TextInput({
          placeholder: this.stringOf($r('app.string.search_placeholder')),
          text: this.keyword
        })
          .layoutWeight(1)
          .height(40)
          .onChange((v: string) => this.onSearchInput(v))
        if (this.keyword !== '') {
          Text('×')
            .fontSize(18)
            .fontColor($r('app.color.text_secondary'))
            .onClick(() => {
              this.keyword = '';
              this.activeCategory = '';
              this.results = [];
              this.searched = false;
            })
        }
        Text('⋯')
          .fontSize(20)
          .fontColor($r('app.color.text_secondary'))
          .onClick(() => this.comingSoon())
      }
      .width('100%')
      .height(48)
      .padding({ left: 16, right: 12 })

      Scroll() {
        Column() {
          if (this.keyword.trim() === '') {
            // 未输入：空态提示（Spec 015）
            Column({ space: 8 }) {
              Text('🔍')
                .fontSize(40)
                .margin({ top: 60 })
              Text($r('app.string.search_empty_query'))
                .fontSize($r('app.float.body_font_size'))
                .fontColor($r('app.color.text_secondary'))
            }
            .width('100%')
            .alignItems(HorizontalAlign.Center)
          } else if (this.activeCategory === '') {
            // 建议列表
            ForEach(SEARCH_SUGGESTION_TYPES, (type: string) => {
              this.suggestionRow(this.suggestionIcon(type), this.suggestionLabel(type),
                (): void => {
                  if (type === 'code') {
                    this.runCodeSearch();
                  } else {
                    this.comingSoon();
                  }
                })
            }, (type: string) => type)
          } else if (this.activeCategory === 'code') {
            // Code 结果
            Text($r('app.string.search_category_code'))
              .fontSize($r('app.float.title_font_size'))
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
              .width('100%')
              .padding({ top: 8, bottom: 12 })

            if (this.results.length > 0) {
              ForEach(this.results, (item: CodeSearchItem) => {
                this.codeCard(item)
              }, (item: CodeSearchItem) => `${item.repoFullName}/${item.path}`)
              // Show more（测试 6：分页后续）
              Text(resText(this.getUIContext(), $r('app.string.search_matches_more'), 20))
                .fontSize($r('app.float.caption_font_size'))
                .fontColor($r('app.color.text_secondary'))
                .padding(12)
                .onClick(() => this.comingSoon())
            } else {
              StateView({
                loading: this.loading,
                error: this.errorMsg,
                empty: !this.loading && this.errorMsg === '',
                emptyText: $r('app.string.search_no_results')
              })
            }
          }
        }
        .padding({ left: 16, right: 16 })
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
