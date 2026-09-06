/**
 * Starred 列表成员 sheet（Spec 023/035）：已建列表行（名称+成员圆钮，点击整行切换）或
 * 官方 Suggestions 三件套（点击直接创建同名列表）+ Create list 入口。
 * 成员态由 sheetRepoId（@Param []）派生，切换/创建经事件上抛，本组件不调服务。
 */
import { OctIcon } from './OctIcon';
import { WorkUserList } from '../models/WorkModels';
import { resText } from '../utils/I18n';

/** 建议列表（官方 Suggestions 三件套 + Create list 入口；StarredRepositoriesView 创建时复用） */
export const STARRED_SUGGESTIONS: Resource[] = [
  $r('app.string.starred_suggestion_future_ideas'),
  $r('app.string.starred_suggestion_my_stack'),
  $r('app.string.starred_suggestion_inspiration')
];

@ComponentV2
export struct StarredListSheet {
  @Param lists: WorkUserList[] = [];
  /** 当前 sheet 仓库 id（成员态判定） */
  @Param sheetRepoId: string = '';
  @Event onToggleMember: (list: WorkUserList) => void = (list: WorkUserList): void => { };
  /** 官方语义：点建议直接创建同名列表（review D8：勾选态此前无消费） */
  @Event onCreateSuggestion: (index: number) => void = (index: number): void => { };
  @Event onCreateList: () => void = (): void => { };

  private stringOf(res: Resource): string {
    return resText(this.getUIContext(), res);
  }

  /** 建议行 emoji（官方三件套） */
  private suggestionEmoji(index: number): string {
    if (index === 0) {
      return '🔮';
    }
    if (index === 1) {
      return '🪄';
    }
    return '✨';
  }

  /** 当前 sheet 仓库是否已在列表内 */
  private repoInList(list: WorkUserList): boolean {
    return this.sheetRepoId !== '' && list.repoIds.includes(this.sheetRepoId);
  }

  build() {
    // 内容包 Scroll：列表行数多时 300 高 sheet 内可滚（review D7）
    Scroll() {
      Column() {
        if (this.lists.length > 0) {
          // 已建列表：行 = 名称 + 成员圆钮（点击整行切换），官方样式
          ForEach(this.lists, (list: WorkUserList) => {
            Row({ space: 14 }) {
              Text(list.name)
                .fontSize($r('app.float.body_font_size'))
                .fontColor($r('app.color.text_primary'))
                .layoutWeight(1)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              Stack() {
                Circle()
                  .width(22)
                  .height(22)
                  .fill(this.repoInList(list) ? $r('app.color.link_blue') : Color.Transparent)
                  // Shape 外轮廓须用 stroke：通用 .border() 在 Shape 上按组件矩形外框绘制
                  .stroke(this.repoInList(list) ? $r('app.color.link_blue') : $r('app.color.border'))
                  .strokeWidth(1.5)
                if (this.repoInList(list)) {
                  OctIcon({ res: $r('app.media.oct_check_16'), iconSize: 12, iconColor: Color.White })
                }
              }
            }
            .width('100%')
            .height(52)
            .padding({ left: 20, right: 20 })
            .onClick((): void => {
              this.onToggleMember(list);
            })
            // key 含 itemCount/成员集合：数据变更强制重建行（同 key 复用 => 闭包陈旧不刷新）
          }, (list: WorkUserList) => `${list.id}_${list.itemCount}_${list.repoIds.join(',')}`)
        } else {
          // 无列表：官方 Suggestions 三件套（已建列表后由列表行替代）
          Text($r('app.string.starred_suggestions_title'))
            .fontSize($r('app.float.caption_font_size'))
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
            .padding({ left: 20, top: 16, bottom: 12 })

          ForEach(STARRED_SUGGESTIONS, (item: Resource, index: number) => {
            Row({ space: 14 }) {
              Text(this.suggestionEmoji(index))
                .fontSize(20)
              Text(this.stringOf(item))
                .fontSize($r('app.float.body_font_size'))
                .fontColor($r('app.color.text_primary'))
                .layoutWeight(1)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              Stack() {
                Circle()
                  .width(22)
                  .height(22)
                  .fill(Color.Transparent)
                  // Shape 外轮廓须用 stroke：通用 .border() 在 Shape 上按组件矩形外框绘制
                  .stroke($r('app.color.border'))
                  .strokeWidth(1.5)
              }
            }
            .width('100%')
            .height(52)
            .padding({ left: 20, right: 20 })
            .onClick((): void => {
              this.onCreateSuggestion(index);
            })
          }, (item: Resource, index: number) => `s_${index}`)
        }

        Row({ space: 12 }) {
          OctIcon({ res: $r('app.media.oct_plus_24'), iconSize: 18, iconColor: $r('app.color.link_blue') })
          Text($r('app.string.starred_create_list'))
            .fontSize($r('app.float.body_font_size'))
            .fontColor($r('app.color.link_blue'))
        }
        .width('100%')
        .height(52)
        .padding({ left: 20, right: 20 })
        .onClick((): void => this.onCreateList())
      }
      .width('100%')
    }
    .align(Alignment.Top)
    .scrollBar(BarState.Off)
    .width('100%')
  }
}
