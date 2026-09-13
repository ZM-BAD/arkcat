/**
 * 语言筛选底部面板（Trending 与 Repositories 共用，Spec 037/056）：
 * 标题行双态（常态=✕ + 标题 + 🔍；点 🔍 标题**原地**变搜索框 + 左侧 ✕ 变 ← 回退 + 框内 ✕ 清词）
 * + 语言行列表（色点 + 语言名 + 选中蓝勾）。
 * 数据加载与筛选状态留在调用方（本组件只展示与上抛事件）；搜索框显隐/关键词为组件内部态，
 * 选中或回退即复位，每次重新拉起即为干净状态。选中项再点一次=取消（清筛选）由调用方的 onPick 决定。
 *
 * 选中态刷新：每行是独立组件（@Param selected），且 ForEach key 带上选中标记——
 * 面板内容在 bindSheet 内会被复用，若只用「@Builder 值参数 + 静态 key」，切换语言后蓝勾会卡旧值。
 */
import { ExploreLanguage } from '../models/ExploreLanguages';
import { OctIcon } from './OctIcon';
import { resText } from '../utils/I18n';

/** 语言行（独立组件：选中态经 @Param 刷新，规避 @Builder 值参数 + ForEach 复用卡旧值） */
@ComponentV2
struct LanguageOptionRow {
  @Param lang: ExploreLanguage = { name: '', color: '' };
  @Param selected: boolean = false;
  @Event onPick: (name: string) => void = (name: string): void => { };

  build() {
    Row() {
      Circle()
        .width(12)
        .height(12)
        .fill(this.lang.color !== '' ? this.lang.color : $r('app.color.repo_language_unknown'))
        // 色点与语言名之间的固定间隔（不加则紧贴）
        .margin({ right: 16 })
      Text(this.lang.name)
        .fontSize($r('app.float.body_font_size'))
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
      if (this.selected) {
        OctIcon({ res: $r('app.media.oct_check_16'), iconSize: 16, iconColor: $r('app.color.link_blue') })
          .margin({ left: 8 })
      }
    }
    .width('100%')
    .height(56)
    .padding({ left: 20, right: 16 })
    .onClick((): void => this.onPick(this.lang.name))
  }
}

@ComponentV2
export struct LanguageFilterSheet {
  @Require @Param title: Resource;
  /** 语言清单（调用方已完成排序/降级） */
  @Param languages: ExploreLanguage[] = [];
  /** 当前选中的语言名（''=未筛选） */
  @Param selected: string = '';
  /** 搜索态输入框占位文案（Language 面板传「Filter languages」，Spoken 传「Filter spoken languages」） */
  @Param searchPlaceholder: Resource = $r('app.string.search_placeholder');
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
      // 搜索态=←（回退：清空搜索词并退出搜索态）；常态=✕（关闭面板）
      Stack() {
        OctIcon({
          res: this.searchShow ? $r('app.media.oct_arrow_left_24') : $r('app.media.oct_x_16'),
          iconSize: 18,
          iconColor: $r('app.color.text_primary')
        })
      }
      .width(44)
      .height(44)
      .onClick((): void => {
        if (this.searchShow) {
          this.searchText = '';
          this.searchShow = false;
        } else {
          this.onClose();
        }
      })
      if (this.searchShow) {
        // 标题原地变搜索框：对语言清单客户端过滤；框内右端 ✕ 一键清空
        Stack({ alignContent: Alignment.End }) {
          TextInput({ placeholder: this.stringOf(this.searchPlaceholder), text: this.searchText })
            .height(40)
            .fontSize($r('app.float.body_font_size'))
            .width('100%')
            .padding({ right: 34 })
            .borderRadius(6)
            .backgroundColor($r('app.color.chip_bg'))
            .defaultFocus(true)
            .onChange((v: string): void => {
              this.searchText = v;
            })
          if (this.searchText !== '') {
            Stack() {
              OctIcon({ res: $r('app.media.oct_x_16'), iconSize: 14, iconColor: $r('app.color.text_secondary') })
            }
            .width(36)
            .height(36)
            .onClick((): void => {
              this.searchText = '';
            })
          }
        }
        .layoutWeight(1)
        .margin({ right: 8 })
      } else {
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
          this.searchShow = true;
        })
      }
    }
    .padding({ left: 8, right: 8 })
  }

  @Builder
  langRow(lang: ExploreLanguage) {
    LanguageOptionRow({
      lang: lang,
      selected: this.selected === lang.name,
      onPick: (name: string): void => {
        // 选中后面板由调用方关闭：顺手复位搜索态，保证下次拉起干净
        this.searchShow = false;
        this.searchText = '';
        this.onPick(name);
      }
    })
  }

  build() {
    Column() {
      this.sheetHeader()
      Divider()
        .color($r('app.color.divider'))
        .strokeWidth(1)
        .width('100%')
      Scroll() {
        Column() {
          if (this.filtered().length > 0) {
            ForEach(this.filtered(), (lang: ExploreLanguage) => {
              this.langRow(lang)
            }, (lang: ExploreLanguage) => `${lang.name}_${this.selected === lang.name ? 'on' : 'off'}`)
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
      // 内容不足一屏时顶对齐：Scroll 默认居中会把首行推离头部（留白上下各一半）
      .align(Alignment.Top)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.card_background'))
  }
}
