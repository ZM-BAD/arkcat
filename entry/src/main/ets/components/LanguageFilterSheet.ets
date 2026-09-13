/**
 * 语言筛选底部面板（Trending 与 Repositories 共用，Spec 037/056）：
 * 标题行（✕ + 标题 + 🔍 切换内联搜索）+ 语言行列表（色点 + 语言名 + 选中蓝勾）。
 * 数据加载与筛选状态留在调用方（本组件只展示与上抛事件）；搜索框显隐/关键词为组件内部态，
 * 每次重新拉起即为干净状态。选中项再点一次=取消（清筛选）由调用方的 onPick 决定。
 */
import { ExploreLanguage } from '../models/ExploreLanguages';
import { OctIcon } from './OctIcon';
import { resText } from '../utils/I18n';

@ComponentV2
export struct LanguageFilterSheet {
  @Require @Param title: Resource;
  /** 语言清单（调用方已完成排序/降级） */
  @Param languages: ExploreLanguage[] = [];
  /** 当前选中的语言名（''=未筛选） */
  @Param selected: string = '';
  @Event onPick: (name: string) => void = (name: string): void => { };
  @Event onClose: () => void = (): void => { };
  @Local searchShow: boolean = false;
  @Local searchText: string = '';

  private stringOf(res: Resource): string {
    return resText(this.getUIContext(), res);
  }

  /** 关键词模糊过滤（大小写不敏感；空关键词=全量） */
  private filtered(): ExploreLanguage[] {
    const q = this.searchText.trim().toLowerCase();
    if (q === '') {
      return this.languages;
    }
    return this.languages.filter((l: ExploreLanguage): boolean => l.name.toLowerCase().includes(q));
  }

  @Builder
  sheetHeader() {
    Row() {
      Stack() {
        OctIcon({ res: $r('app.media.oct_x_16'), iconSize: 18, iconColor: $r('app.color.text_primary') })
      }
      .width(44)
      .height(44)
      .onClick((): void => this.onClose())
      Text(this.title)
        .fontSize($r('app.float.title_font_size'))
        .fontWeight(600)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
      Stack() {
        OctIcon({ res: $r('app.media.oct_search_24'), iconSize: 18, iconColor: $r('app.color.link_blue') })
      }
      .width(44)
      .height(44)
      .onClick((): void => {
        this.searchShow = !this.searchShow;
      })
    }
    .padding({ left: 8, right: 8 })
  }

  @Builder
  langRow(lang: ExploreLanguage) {
    Row() {
      Circle()
        .width(12)
        .height(12)
        .fill(lang.color !== '' ? lang.color : $r('app.color.repo_language_unknown'))
        // 色点与语言名之间的固定间隔（不加则紧贴）
        .margin({ right: 16 })
      Text(lang.name)
        .fontSize($r('app.float.body_font_size'))
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
      if (this.selected === lang.name) {
        OctIcon({ res: $r('app.media.oct_check_16'), iconSize: 16, iconColor: $r('app.color.link_blue') })
          .margin({ left: 8 })
      }
    }
    .width('100%')
    .height(56)
    .padding({ left: 20, right: 16 })
    .onClick((): void => this.onPick(lang.name))
  }

  build() {
    Column() {
      this.sheetHeader()
      Divider()
        .color($r('app.color.divider'))
        .strokeWidth(1)
        .width('100%')
      if (this.searchShow) {
        TextInput({ placeholder: this.stringOf($r('app.string.search_placeholder')), text: this.searchText })
          .height(40)
          .fontSize($r('app.float.body_font_size'))
          .margin({ left: 16, right: 16, bottom: 4 })
          .borderRadius(6)
          .backgroundColor($r('app.color.chip_bg'))
          .onChange((v: string): void => {
            this.searchText = v;
          })
      }
      Scroll() {
        Column() {
          if (this.filtered().length > 0) {
            ForEach(this.filtered(), (lang: ExploreLanguage) => {
              this.langRow(lang)
            }, (lang: ExploreLanguage) => lang.name)
          } else {
            Text($r('app.string.filter_no_results'))
              .fontSize($r('app.float.caption_font_size'))
              .fontColor($r('app.color.text_secondary'))
              .width('100%')
              .padding({ left: 20, top: 16, bottom: 12 })
          }
        }
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.card_background'))
  }
}
