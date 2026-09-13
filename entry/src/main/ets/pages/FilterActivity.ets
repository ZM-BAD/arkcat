/**
 * Filter Activity 设置页（Spec 056 收口，官方参考图 2026-09-07）：
 * 返回 + Filter Activity 标题 + 右上 SAVE；六类勾选行（蓝复选框 + 彩色圆角图标 + 名称），
 * 行点击即时翻转、SAVE 持久化到 Preferences 后返回（未保存用默认全选，读取无状态回滚）。
 */
import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { OctIcon } from '../components/OctIcon';
import { readActivityKinds, saveActivityKinds } from '../models/ActivityKinds';
import { resText } from '../utils/I18n';

/** 官方六类：方块底色 + 白色前景图标（色值复用现有语义令牌，双套 color.json 自动适配） */
interface ActivityKindMeta {
  key: string;
  labelRes: Resource;
  iconRes: Resource;
  bgRes: Resource;
}

const KIND_META: ActivityKindMeta[] = [
  { key: 'announcements', labelRes: $r('app.string.explore_kind_announcements'), iconRes: $r('app.media.oct_megaphone_16'), bgRes: $r('app.color.shortcut_purple_fg') },
  { key: 'releases', labelRes: $r('app.string.explore_kind_releases'), iconRes: $r('app.media.oct_tag_16'), bgRes: $r('app.color.shortcut_green_fg') },
  { key: 'stars', labelRes: $r('app.string.explore_kind_stars'), iconRes: $r('app.media.oct_star_fill_16'), bgRes: $r('app.color.star_gold') },
  { key: 'repositories', labelRes: $r('app.string.explore_kind_repositories'), iconRes: $r('app.media.oct_repo_16'), bgRes: $r('app.color.text_secondary') },
  { key: 'follows', labelRes: $r('app.string.explore_kind_follows'), iconRes: $r('app.media.oct_person_add_16'), bgRes: $r('app.color.link_blue') },
  // 官方此处为 mark-github（GitHub logo）；避品牌红线改用中性图形（spec 024 §五、spec 056 §七）
  { key: 'recommendations', labelRes: $r('app.string.explore_kind_recommendations'), iconRes: $r('app.media.oct_graph_stacked_area_16'), bgRes: $r('app.color.text_primary') }
];

@ComponentV2
export struct FilterActivityView {
  @Param token: string = '';
  @Param pathStack: NavPathStack = new NavPathStack();
  @Local kinds: string[] = [];

  aboutToAppear(): void {
    const ctx = this.getUIContext().getHostContext() as common.Context | undefined;
    this.kinds = readActivityKinds(ctx);
  }

  private selected(key: string): boolean {
    return this.kinds.indexOf(key) >= 0;
  }

  private toggle(key: string): void {
    const idx = this.kinds.indexOf(key);
    if (idx >= 0) {
      this.kinds.splice(idx, 1);
    } else {
      this.kinds.push(key);
    }
  }

  private save(): void {
    const ctx = this.getUIContext().getHostContext() as common.Context | undefined;
    if (saveActivityKinds(ctx, this.kinds)) {
      this.pathStack.pop();
    } else {
      promptAction.showToast({ message: this.stringOf($r('app.string.explore_filter_save_failed')) });
    }
  }

  private stringOf(res: Resource): string {
    return resText(this.getUIContext(), res);
  }

  build() {
    Column() {
      // 自绘头部（二级页约定：hideTitleBar；右 SAVE 为蓝色文字操作）
      Row() {
        // 返回键触控区用 Stack（图标居中）：视觉左缘 = 4 + (44-20)/2 = 16，与 AppBar 组件一致
        Stack() {
          OctIcon({ res: $r('app.media.oct_arrow_left_24'), iconSize: 20, iconColor: $r('app.color.text_primary') })
        }
        .width(44)
        .height(44)
        .accessibilityDescription($r('app.string.a11y_back'))
        .focusable(true)
        .onClick(() => this.pathStack.pop())

        Text($r('app.string.explore_filter_activity'))
          .fontSize($r('app.float.title_font_size'))
          .fontWeight(600)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)

        // 右缘对齐规范：行 padding 4 + 文字右 padding 12 = 视觉 16（CreateList SAVE 同款写法）
        Text($r('app.string.explore_filter_save'))
          .fontSize($r('app.float.body_font_size'))
          .fontWeight(600)
          .fontColor($r('app.color.link_blue'))
          .padding({ left: 6, right: 12, top: 6, bottom: 6 })
          .responseRegion({ x: -6, y: -7, width: '130%', height: '147%' })
          .onClick(() => this.save())
      }
      .width('100%')
      .height(48)
      .padding({ left: 4, right: 4 })

      Scroll() {
        Column() {
          ForEach(KIND_META, (meta: ActivityKindMeta) => {
            Row({ space: 16 }) {
              // 复选框（官方蓝底白勾 / 空态灰描边）
              Stack() {
                if (this.selected(meta.key)) {
                  OctIcon({ res: $r('app.media.oct_check_16'), iconSize: 14, iconColor: Color.White })
                }
              }
              .width(22)
              .height(22)
              .borderRadius(6)
              .backgroundColor(this.selected(meta.key) ? $r('app.color.link_blue') : Color.Transparent)
              .border({
                width: 1.5,
                color: this.selected(meta.key) ? $r('app.color.link_blue') : $r('app.color.border')
              })

              Stack() {
                OctIcon({ res: meta.iconRes, iconSize: 15, iconColor: Color.White })
              }
              .width(26)
              .height(26)
              .borderRadius(8)
              .backgroundColor(meta.bgRes)

              Text(this.stringOf(meta.labelRes))
                .fontSize($r('app.float.body_font_size'))
                .fontColor($r('app.color.text_primary'))
                .layoutWeight(1)
            }
            .width('100%')
            .height(64)
            .padding({ left: 20, right: 20 })
            .onClick(() => this.toggle(meta.key))
            .id(`activity_kind_${meta.key}`)
          }, (meta: ActivityKindMeta) => meta.key)
        }
        .width('100%')
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.card_background'))
  }
}
