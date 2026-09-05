/**
 * 反应条（Spec 041）：reactionGroups 渲染（emoji+count），点击 emoji add/remove，
 * 点击 count 展开用户列表；「+」打开 8 种官方 reaction 选择面板。
 * mutation 成功后本地翻转（flipReactionGroups），刷新由父级 onChanged 驱动。
 * smileyTrigger（release 详情官方变体）：圆轮廓笑脸触发钮 + 居中六宫格弹层（6 种正向反应）。
 */
import { promptAction } from '@kit.ArkUI';
import { ReactionGroup, ReactionUser, ReactionMeta, REACTION_META, RELEASE_REACTION_META,
  reactionEmoji, findReactionGroup, flipReactionGroups } from '../models/RepoSubModels';
import { RepoSubService } from '../services/RepoSubService';
import { ApiError } from '../services/GitHttpClient';
import { OctIcon } from './OctIcon';
import { resText } from '../utils/I18n';

@ComponentV2
export struct ReactionBar {
  @Param token: string = '';
  /** add/remove 的 subjectId（评论节点 id） */
  @Param subjectId: string = '';
  @Param reactions: ReactionGroup[] = [];
  /** 官方 release 变体：笑脸圆钮 + 六宫格弹层替代「+」chip（走查修正九轮） */
  @Param smileyTrigger: boolean = false;
  /** 笑脸精简态（Explore 信息流卡，Spec 056）：仅笑脸按钮，点击直达选择面板 */
  @Param smileyOnly: boolean = false;
  /** mutation 成功回调（父级远期刷新；即时翻转由组件本地完成） */
  @Event onChanged: () => void = (): void => { };
  /** release 变体长按芯片：跳 Reactees 整页（评论变体保持底部 sheet） */
  @Event onOpenUsers: (subjectId: string, content: string) => void = (): void => { };
  @Local mirror: ReactionGroup[] = [];
  @Local pending: string = '';
  /** sheet 打开状态 + 分派 kind（记忆坑：同组件多 bindSheet 只有最后一个生效，须合并） */
  @Local sheetOpen: boolean = false;
  @Local sheetKind: string = '';
  /** 当前打开用户列表的反应 content */
  @Local sheetContent: string = '';
  /** release 六宫格弹层（bindPopup $$ 双向：点外部自动回写关闭） */
  @Local pickerOpen: boolean = false;

  aboutToAppear(): void {
    this.mirror = this.reactions;
  }

  @Monitor('reactions')
  onReactionsChanged(): void {
    this.mirror = this.reactions;
  }

  private stringOf(res: Resource): string {
    return resText(this.getUIContext(), res);
  }

  private toastError(e: Error): void {
    if (e instanceof ApiError && e.code === 429) {
      promptAction.showToast({ message: $r('app.string.comment_error_rate_limit') });
      return;
    }
    promptAction.showToast({ message: $r('app.string.comment_error_reaction') });
  }

  /** 点击 emoji：add/remove（按 viewerHasReacted 决定方向） */
  private toggle(content: string): void {
    if (this.pending !== '') {
      return;
    }
    const group = findReactionGroup(this.mirror, content);
    const adding = group === null || !group.viewerHasReacted;
    this.pending = content;
    const task = adding
      ? RepoSubService.addReaction(this.token, this.subjectId, content)
      : RepoSubService.removeReaction(this.token, this.subjectId, content);
    task.then(() => {
      this.pending = '';
      this.mirror = flipReactionGroups(this.mirror, content, adding);
      this.onChanged();
    }).catch((e: Error) => {
      this.pending = '';
      this.toastError(e);
    });
  }

  /** 点击 count：展开反应用户列表 */
  private openUsers(group: ReactionGroup): void {
    if (group.users.length === 0) {
      return;
    }
    this.sheetContent = group.content;
    this.sheetKind = 'users';
    this.sheetOpen = true;
  }

  /** 芯片长按：release 变体跳 Reactees 整页（整页拉全量，不受前 8 预取限制）；评论变体保持 sheet */
  private onChipLongPress(content: string): void {
    if (this.smileyTrigger) {
      this.onOpenUsers(this.subjectId, content);
      return;
    }
    const group = findReactionGroup(this.mirror, content);
    if (group !== null) {
      this.openUsers(group);
    }
  }

  private openAll(): void {
    this.sheetKind = 'all';
    this.sheetOpen = true;
  }

  /** 「+」面板选择：直接 toggle（已反应则移除，与官方语义一致；review F4 此前对他人已建组无响应） */
  private pick(content: string): void {
    this.sheetOpen = false;
    this.pickerOpen = false;
    this.toggle(content);
  }

  /** 当前打开用户列表的反应组（@Builder 内不允许局部 const，用方法返回） */
  private usersGroup(): ReactionGroup | null {
    return findReactionGroup(this.mirror, this.sheetContent);
  }

  @Builder
  sheetPanel() {
    Column({ space: 12 }) {
      if (this.sheetKind === 'users') {
        Text(this.stringOf($r('app.string.reaction_users_title')))
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .width('100%')
        if (this.usersGroup() !== null) {
          Scroll() {
            Column() {
              ForEach(this.usersGroup()?.users ?? [], (u: ReactionUser) => {
                Row({ space: 10 }) {
                  if (u.avatarUrl !== '') {
                    Image(u.avatarUrl)
                      .width(28)
                      .height(28)
                      .borderRadius(12)
                      .backgroundColor($r('app.color.heat_empty'))
                  } else {
                    Circle().width(28).height(28).fill($r('app.color.heat_empty'))
                  }
                  Text(u.login)
                    .fontSize($r('app.float.body_font_size'))
                    .fontWeight(FontWeight.Medium)
                    .fontColor($r('app.color.text_primary'))
                }
                .width('100%')
                .padding(6)
              }, (u: ReactionUser) => u.login)
            }
            .width('100%')
          }
          .width('100%')
          .height(220)
          .scrollBar(BarState.Off)
        }
      } else {
        Text(this.stringOf($r('app.string.reaction_panel_title')))
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .width('100%')
        // 8 个 44vp emoji 超出窄屏宽度：包横向 Scroll，内层行 minWidth 撑满、超宽可滑
        Scroll() {
          Row({ space: 8 }) {
            ForEach(REACTION_META, (m: ReactionMeta) => {
              Text(m.emoji)
                .fontSize(24)
                .width(44)
                .height(44)
                .textAlign(TextAlign.Center)
                .borderRadius(6)
                .backgroundColor(findReactionGroup(this.mirror, m.content)?.viewerHasReacted === true
                  ? $r('app.color.chip_bg') : Color.Transparent)
                .onClick(() => this.pick(m.content))
            }, (m: ReactionMeta) => m.content)
          }
          .constraintSize({ minWidth: '100%' })
        }
        .scrollBar(BarState.Off)
        .width('100%')
      }
    }
    .padding({ left: 16, right: 16, top: 16, bottom: 20 })
    .width('100%')
    .backgroundColor($r('app.color.bg_page'))
  }

  /** 官方 release 六宫格选择面板（2×3 仅 6 种正向反应；自己已选的淡灰底，走查修正九轮） */
  @Builder
  releasePickerPanel() {
    Grid() {
      ForEach(RELEASE_REACTION_META, (m: ReactionMeta) => {
        GridItem() {
          Text(m.emoji)
            .fontSize(30)
            .width(72)
            .height(56)
            .textAlign(TextAlign.Center)
            .borderRadius(8)
            .backgroundColor(findReactionGroup(this.mirror, m.content)?.viewerHasReacted === true
              ? $r('app.color.chip_bg') : Color.Transparent)
            .onClick(() => this.pick(m.content))
        }
      }, (m: ReactionMeta) => m.content)
    }
    .columnsTemplate('1fr 1fr 1fr')
    .columnsGap(8)
    .rowsGap(8)
    .padding(16)
    .width(272)
    .height(152)
  }

  /** 观察者是否已有任一反应（笑脸高亮，Spec 056） */
  private viewerReacted(): boolean {
    return this.mirror.some((g: ReactionGroup): boolean => g.viewerHasReacted);
  }

  build() {
    if (this.smileyOnly) {
      // 精简态（Spec 056 信息流卡）：笑脸按钮，点击直达 8 reaction 选择面板
      Row() {
        OctIcon({
          res: $r('app.media.oct_smiley_16'),
          iconSize: 22,
          iconColor: this.viewerReacted() ? $r('app.color.link_blue') : $r('app.color.text_secondary')
        })
      }
      .width(36)
      .height(36)
      .borderRadius(18)
      .onClick(() => this.openAll())
    } else {
    // 芯片行可横向滚动：外层 Scroll 限宽防溢出容器，内层行 minWidth 撑满、超宽时可滑（不能 width('100%')，否则永不溢出）
    Scroll() {
      Row({ space: 6 }) {
        // 官方 release 触发钮：圆轮廓笑脸，点击弹居中六宫格（bindPopup $$ 双向，点外部自关）
        if (this.smileyTrigger) {          Stack() {
            OctIcon({ res: $r('app.media.oct_smiley_16'), iconSize: 20, iconColor: $r('app.color.text_secondary') })
          }
          .width(36)
          .height(36)
          .border({ width: 1, color: $r('app.color.divider'), radius: 18 })
          .responseRegion({ x: -4, y: -4, width: '128%', height: '128%' })
          .accessibilityDescription($r('app.string.a11y_reaction_add'))
          .bindPopup($$this.pickerOpen, {
            builder: this.releasePickerPanel(),
            placement: Placement.Bottom,
            popupColor: $r('app.color.card_background'),
            radius: 12,
            autoCancel: true
          })
          .onClick(() => {
            this.pickerOpen = !this.pickerOpen;
          })
        }
        // 只渲染计数 > 0 的组（官方语义：0 反应不显示；mirror 保留全量供选择器/翻转用）
        ForEach(this.mirror.filter((g: ReactionGroup) => g.count > 0), (g: ReactionGroup) => {
          // 官方语义：整个芯片可点=add/remove（自己已反应则 -1）；长按展开反应用户列表
          Row({ space: 2 }) {
            Text(reactionEmoji(g.content))
              .fontSize($r('app.float.chip_font_size'))
              .padding({ left: 6, top: 4, bottom: 4 })
            Text(`${g.count}`)
              .fontSize($r('app.float.caption_font_size'))
              .fontWeight(g.viewerHasReacted ? FontWeight.Medium : FontWeight.Regular)
              .fontColor(g.viewerHasReacted ? $r('app.color.link_blue') : $r('app.color.text_secondary'))
              .padding({ left: 2, right: 6, top: 5, bottom: 5 })
          }
          .borderRadius(12)
          .backgroundColor(g.viewerHasReacted ? $r('app.color.chip_active_bg') : $r('app.color.chip_bg'))
          .border({ width: g.viewerHasReacted ? 1 : 0, color: $r('app.color.link_blue') })
          .margin({ right: 2 })
          .onClick(() => this.toggle(g.content))
          .gesture(LongPressGesture({ repeat: false })
            .onAction(() => this.onChipLongPress(g.content)))
        }, (g: ReactionGroup) => g.content + '_' + g.count + (g.viewerHasReacted ? '_r' : ''))
        if (!this.smileyTrigger && this.mirror.length < REACTION_META.length) {
          Text('+')
            .fontSize(16)
            .fontColor($r('app.color.text_secondary'))
            .width(28)
            .height(28)
            .responseRegion({ x: -8, y: -8, width: '160%', height: '160%' })
            .textAlign(TextAlign.Center)
            .borderRadius(12)
            .backgroundColor($r('app.color.chip_bg'))
            .accessibilityDescription($r('app.string.a11y_reaction_add'))
            .onClick(() => this.openAll())
        }
      }
      .constraintSize({ minWidth: '100%' })
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .width('100%')
    .bindSheet($$this.sheetOpen, this.sheetPanel(), {
      height: 300,
      showClose: false,
      backgroundColor: $r('app.color.bg_page'),
      dragBar: false,
      onDisappear: () => {
        this.sheetKind = '';
      }
    })
    }
  }
}
