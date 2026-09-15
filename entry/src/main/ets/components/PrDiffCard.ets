/**
 * PR Diff 单文件卡（Spec 010）：文件头（路径/±统计/折叠箭头/查看）+ 展开后的 hunk diff 行。
 * 展开态由父页面持有（@Local 数组重建触发刷新），本组件按 @Param 只读渲染；
 * diff 行三色（add/del/ctx）走 color.json token，行内容 monospace，长行钳 4 行防白屏。
 */
import { promptAction } from '@kit.ArkUI';
import { pasteboard } from '@kit.BasicServicesKit';
import { OctIcon } from './OctIcon';
import { PrFileItem } from '../models/PrDiffModels';
import { DiffHunk, DiffLine, fileBaseName } from '../utils/Diff';
import { resText } from '../utils/I18n';

/** bindPopup onStateChange 回调的类型（与 FilterDropdownChip/WorkFilterBar 同款自声明） */
interface PopupState {
  isVisible: boolean;
}

@ComponentV2
export struct PrDiffCard {
  @Param item: PrFileItem | null = null;
  @Param expanded: boolean = false;
  /** Code Options「展示行号」开关（父页面读取后传入） */
  @Param showLineNumbers: boolean = false;
  /** 强制展开/收起（reviewed 勾选切换用；true=展开） */
  @Event onSetExpanded: (expanded: boolean) => void = (expanded: boolean): void => { };
  @Event onToggle: () => void = (): void => { };
  @Event onOpenFile: () => void = (): void => { };
  /** 已标记 reviewed 状态（页面内临时） */
  @Local reviewed: boolean = false;
  /** 三点菜单弹层 */
  @Local menuOpen: boolean = false;

  private stringOf(res: Resource): string {
    return resText(this.getUIContext(), res);
  }

  /** 单列行号文案：del 行旧号，其余新号；0 显示空 */
  private lineNoText(line: DiffLine): string {
    const no = line.kind === 'del' ? line.oldLine : line.newLine;
    return no > 0 ? `${no}` : '';
  }

  private copyPath(): void {
    if (this.item === null) {
      return;
    }
    const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.item.path);
    pasteboard.getSystemPasteboard().setDataSync(data);
    promptAction.showToast({ message: $r('app.string.md_copied') });
  }

  /** 三点菜单项（icon+文案；delete 红色） */
  @Builder
  menuItem(iconRes: Resource, label: string, color: ResourceColor, onTap: () => void) {
    Row({ space: 10 }) {
      OctIcon({ res: iconRes, iconSize: 16, iconColor: color })
      Text(label)
        .fontSize($r('app.float.body_font_size'))
        .fontColor(color)
    }
    .width('100%')
    .height(40)
    .responseRegion({ x: 0, y: -2, width: '100%', height: '110%' })
    .padding({ left: 14, right: 14 })
    .onClick((): void => {
      this.menuOpen = false;
      onTap();
    })
  }

  /** 自绘三点菜单：Copy path/View/Edit/Delete/横线/Add File Comment */
  @Builder
  fileMenu() {
    Column() {
      this.menuItem($r('app.media.oct_paste_16'), this.stringOf($r('app.string.pr_copy_path')),
        $r('app.color.text_primary'), (): void => this.copyPath())
      this.menuItem($r('app.media.oct_file_16'), this.stringOf($r('app.string.pr_file_view_menu')),
        $r('app.color.text_primary'), (): void => this.onOpenFile())
      this.menuItem($r('app.media.oct_pencil_16'), this.stringOf($r('app.string.pr_edit_file')),
        $r('app.color.text_primary'), (): void => promptAction.showToast({ message: $r('app.string.home_feature_coming') }))
      this.menuItem($r('app.media.oct_trash_16'), this.stringOf($r('app.string.pr_delete_file')),
        $r('app.color.badge_red'), (): void => promptAction.showToast({ message: $r('app.string.home_feature_coming') }))
      Divider().color($r('app.color.divider')).width('100%')
      this.menuItem($r('app.media.oct_comment_16'), this.stringOf($r('app.string.pr_add_file_comment')),
        $r('app.color.text_primary'), (): void => promptAction.showToast({ message: $r('app.string.home_feature_coming') }))
    }
    .width(200)
    .borderRadius(12)
    .backgroundColor($r('app.color.card_background'))
    .shadow({ radius: 24, color: $r('app.color.shadow_floating'), offsetY: 8 })
    .padding({ top: 6, bottom: 6 })
  }

  /** 单条 diff 行：行号列（可选，单列：del 行旧号、其他新号）+ ±/空格前缀 + 等宽内容 */
  @Builder
  diffLine(line: DiffLine) {
    Row() {
      if (this.showLineNumbers) {
        Text(this.lineNoText(line))
          .width(32)
          .fontFamily('monospace')
          .fontSize($r('app.float.caption_font_size'))
          .textAlign(TextAlign.End)
          .fontColor($r('app.color.text_tertiary'))
          .padding({ right: 6 })
      }
      Text(line.kind === 'add' ? '+' : (line.kind === 'del' ? '-' : ' '))
        .width(20)
        .fontFamily('monospace')
        .fontSize($r('app.float.caption_font_size'))
        .textAlign(TextAlign.Center)
        .fontColor(line.kind === 'add' ? $r('app.color.diff_add_fg')
          : (line.kind === 'del' ? $r('app.color.diff_del_fg') : $r('app.color.text_secondary')))
      Text(line.text)
        .fontFamily('monospace')
        .fontSize($r('app.float.caption_font_size'))
        .fontColor(line.kind === 'add' ? $r('app.color.diff_add_fg')
          : (line.kind === 'del' ? $r('app.color.diff_del_fg') : $r('app.color.text_primary')))
        .maxLines(4)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
    }
    .width('100%')
    .padding({ left: 8, right: 8, top: 2, bottom: 2 })
    .alignItems(VerticalAlign.Top)
    .backgroundColor(line.kind === 'add' ? $r('app.color.diff_add_bg')
      : (line.kind === 'del' ? $r('app.color.diff_del_bg') : Color.Transparent))
  }

  /** hunk 块：@@ 标题行（左列 fold-up + 蓝字蓝底）+ 行列表 */
  @Builder
  hunkBlock(hunk: DiffHunk) {
    Column() {
      Row() {
        Stack({ alignContent: Alignment.Start }) {
          OctIcon({
            res: $r('app.media.oct_fold_up_16'),
            iconSize: 14,
            iconColor: $r('app.color.diff_hunk_head_fg')
          })
        }
        .width(38)
        Text(hunk.header)
          .fontFamily('monospace')
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.diff_hunk_head_fg'))
          .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 8, right: 8, top: 3, bottom: 3 })
      .backgroundColor($r('app.color.diff_hunk_head_bg'))
      ForEach(hunk.lines, (line: DiffLine, idx: number) => {
        this.diffLine(line)
      }, (line: DiffLine, idx: number) => idx + '_' + line.kind + '_' + line.text)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Column() {
      if (this.item !== null) {
        Row({ space: 6 }) {
          // 主体区（三角+文件 icon+路径）：点击展开/收起；与右侧勾选框/三点同级，互不冒泡
          Row() {
            // 展开/收起三角：收起=triangle-right，展开=triangle-down（最左，文件名前）
            OctIcon({
              res: this.expanded ? $r('app.media.oct_triangle_down_16') : $r('app.media.oct_triangle_right_16'),
              iconSize: 16,
              iconColor: $r('app.color.text_secondary')
            })
              .width(24)
              .accessibilityDescription(this.expanded ? $r('app.string.a11y_collapse') : $r('app.string.a11y_expand'))
            OctIcon({ res: $r('app.media.oct_file_16'), iconSize: 14, iconColor: $r('app.color.text_secondary') })
            // 路径过长时左右滑动（内容行不设 width('100%')，超出即可滑）
            Scroll() {
              Row() {
                Text(this.item.path)
                  .fontFamily('monospace')
                  .fontSize($r('app.float.caption_font_size'))
                  .fontColor($r('app.color.text_primary'))
              }
            }
            .scrollable(ScrollDirection.Horizontal)
            .scrollBar(BarState.Off)
            .layoutWeight(1)
          }
          .layoutWeight(1)
          .onClick((): void => {
            this.onToggle();
          })
          // 勾选框：点击标记 reviewed（收起+toast）；取消勾选展开文件
          Row({ space: 2 }) {
            if (this.reviewed) {
              OctIcon({ res: $r('app.media.oct_check_16'), iconSize: 10, iconColor: Color.White })
            }
          }
          .width(18)
          .height(18)
          .responseRegion({ x: -13, y: -13, width: '244%', height: '244%' })
          .borderRadius(3)
          .justifyContent(FlexAlign.Center)
          .backgroundColor(this.reviewed ? $r('app.color.link_blue') : Color.Transparent)
          .border({ width: 1, color: $r('app.color.link_blue') })
          .onClick((): void => {
            this.reviewed = !this.reviewed;
            if (this.reviewed) {
              promptAction.showToast({ message: $r('app.string.pr_marked_reviewed') });
              this.onSetExpanded(false);
            } else {
              this.onSetExpanded(true);
            }
          })
          // 横向三点（灰）：自绘菜单
          Stack() {
            OctIcon({ res: $r('app.media.oct_kebab_horizontal_16'), iconSize: 16, iconColor: $r('app.color.text_secondary') })
          }
          .width(36)
          .height(36)
          .padding(10)
          .accessibilityDescription($r('app.string.a11y_more'))
          .focusable(true)
          .onClick((): void => {
            this.menuOpen = !this.menuOpen;
          })
          .bindPopup(this.menuOpen, {
            builder: (): void => this.fileMenu(),
            // 右缘对齐「⋯」钮；出屏避让交给框架内建策略（勿手算 offset 叠加，双重修正会把弹层推出屏幕）
            placement: Placement.BottomRight,
            enableArrow: false,
            mask: true,
            onStateChange: (e: PopupState): void => {
              if (!e.isVisible) {
                this.menuOpen = false;
              }
            }
          })
        }
        .width('100%')
        .height(44)
        .padding({ left: 10, right: 2 })

        if (this.expanded) {
          if (this.item.hunks.length === 0) {
            Text(this.item.isBinary ? this.stringOf($r('app.string.diff_binary'))
              : (this.item.diffTooLarge ? this.stringOf($r('app.string.pr_diff_too_large'))
                : this.stringOf($r('app.string.pr_files_empty'))))
              .fontSize($r('app.float.caption_font_size'))
              .fontColor($r('app.color.text_secondary'))
              .width('100%')
              .padding({ left: 10, right: 10, top: 6, bottom: 8 })
          } else {
            ForEach(this.item.hunks, (hunk: DiffHunk, idx: number) => {
              this.hunkBlock(hunk)
            }, (hunk: DiffHunk, idx: number) => idx + '_' + hunk.header)
          }
        }
      }
    }
    .width('100%')
    .margin({ bottom: 10 })
    .borderRadius($r('app.float.card_radius'))
    .backgroundColor($r('app.color.card_background'))
    .clip(true)
  }
}
