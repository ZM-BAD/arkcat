/**
 * Copilot 聊天详情页（Spec 058）：自绘 AppBar（标题 + Auto 副标 + 竖三点菜单）+ mock 消息气泡 + 底部输入栏。
 * 纯 UI 架子：消息/会话皆为 mock，发送/删除等动作 toast 占位，菜单仅「Copilot settings」真实跳转。
 */
import { promptAction } from '@kit.ArkUI';
import { OctIcon } from '../components/OctIcon';
import { PageShadowBar } from '../components/PageShadowBar';
import { ChatMessage, ChatSession, mockChatMessages, mockChatSessions } from '../models/CopilotModels';
import { resText } from '../utils/I18n';

/** bindPopup onStateChange 回调的类型（与 PrDiffCard/WorkFilterBar 同款自声明） */
interface PopupState {
  isVisible: boolean;
}

@ComponentV2
export struct CopilotChatView {
  @Param title: string = '';
  @Param pathStack: NavPathStack = new NavPathStack();
  @Local messages: ChatMessage[] = mockChatMessages();
  @Local sessions: ChatSession[] = mockChatSessions();
  /** 当前会话标题（菜单可切换历史会话，@Param 不可变故本地副本） */
  @Local currentTitle: string = '';
  @Local draft: string = '';
  /** 竖三点菜单浮层 */
  @Local menuVisible: boolean = false;
  /** 滚动顶部阴影 */
  @Local scrollShadow: boolean = false;

  aboutToAppear(): void {
    this.currentTitle = this.title;
  }

  private comingSoon(): void {
    promptAction.showToast({ message: $r('app.string.home_feature_coming') });
  }

  private openSettings(): void {
    this.menuVisible = false;
    this.pathStack.pushPathByName('copilotSettings', '');
  }

  private switchChat(title: string): void {
    this.menuVisible = false;
    this.currentTitle = title;
  }

  private send(): void {
    this.draft = '';
    this.comingSoon();
  }

  /** AppBar 标题：会话标题为空（FAB 新建）时用「New conversation」 */
  private titleText(): string {
    if (this.currentTitle !== '') {
      return this.currentTitle;
    }
    return resText(this.getUIContext(), $r('app.string.copilot_menu_new_conversation'));
  }

  /** 菜单条目 */
  @Builder
  menuItem(iconRes: Resource, label: ResourceStr, color: ResourceColor, action: () => void) {
    Row({ space: 12 }) {
      OctIcon({ res: iconRes, iconSize: 16, iconColor: color })
      Text(label)
        .fontSize($r('app.float.body_font_size'))
        .fontColor(color)
        .layoutWeight(1)
    }
    .width('100%')
    .padding({ top: 14, bottom: 14 })
    .onClick(action)
  }

  /** 竖三点菜单浮层（bindPopup 下拉式，参考图 3） */
  @Builder
  menuCard() {
    Column() {
      this.menuItem($r('app.media.oct_plus_24'), $r('app.string.copilot_menu_new_conversation'),
        $r('app.color.link_blue'), () => this.comingSoon())

      // 当前会话：置灰不可点（眼睛图标）
      this.menuItem($r('app.media.oct_eye_16'), this.titleText(), $r('app.color.text_secondary'),
        () => {
          this.menuVisible = false;
        })

      // 历史会话（当前之外）：点按切换
      ForEach(this.sessions, (session: ChatSession) => {
        if (session.title !== this.currentTitle) {
          this.menuItem($r('app.media.oct_comment_16'), session.title, $r('app.color.text_secondary'),
            (): void => this.switchChat(session.title))
        }
      }, (session: ChatSession) => session.id)

      Divider().strokeWidth(0.5).color($r('app.color.divider'))

      this.menuItem($r('app.media.oct_comment_discussion_16'), $r('app.string.copilot_menu_view_all'),
        $r('app.color.text_secondary'), () => this.comingSoon())
      this.menuItem($r('app.media.oct_copilot_16'), $r('app.string.copilot_menu_settings'),
        $r('app.color.text_primary'), () => this.openSettings())
      Divider().strokeWidth(0.5).color($r('app.color.divider'))
      this.menuItem($r('app.media.oct_trash_16'), $r('app.string.copilot_menu_delete'),
        $r('app.color.danger_text'), () => this.comingSoon())
    }
    .padding({ left: 16, right: 16, top: 4, bottom: 4 })
    .width(272)
    .borderRadius(8)
    .backgroundColor($r('app.color.card_background'))
    .shadow({ radius: 12, color: $r('app.color.shadow_floating'), offsetX: 0, offsetY: 4 })
  }

  /** 消息气泡：助手左灰卡、用户右浅蓝卡 */
  @Builder
  messageBubble(msg: ChatMessage) {
    Row() {
      if (!msg.isUser) {
        Text(msg.body)
          .fontSize($r('app.float.body_font_size'))
          .fontColor($r('app.color.text_primary'))
          .padding(12)
          .borderRadius(16)
          .backgroundColor($r('app.color.card_background'))
          .margin({ right: 40 })
      } else {
        Text(msg.body)
          .fontSize($r('app.float.body_font_size'))
          .fontColor($r('app.color.text_primary'))
          .padding(12)
          .borderRadius(16)
          .backgroundColor($r('app.color.tab_active_bg'))
          .margin({ left: 40 })
      }
    }
    .width('100%')
    .justifyContent(msg.isUser ? FlexAlign.End : FlexAlign.Start)
    .padding({ left: 12, right: 12, top: 6, bottom: 6 })
  }

  build() {
    Column() {
      Row({ space: 4 }) {
        Stack() {
          OctIcon({ res: $r('app.media.oct_arrow_left_24'), iconSize: 20, iconColor: $r('app.color.text_primary') })
        }
        .width(44)
        .height(44)
        .accessibilityDescription($r('app.string.a11y_back'))
        .focusable(true)
        .onClick(() => {
          this.pathStack.pop();
        })

        Column({ space: 2 }) {
          Text(this.titleText())
            .fontSize($r('app.float.title_font_size'))
            .fontWeight(600)
            .fontColor($r('app.color.text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text($r('app.string.copilot_mode_auto'))
            .fontSize($r('app.float.caption_font_size'))
            .fontColor($r('app.color.text_secondary'))
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Stack() {
          OctIcon({ res: $r('app.media.oct_kebab_horizontal_16'), iconSize: 18, iconColor: $r('app.color.link_blue') })
            .rotate({ angle: 90 })
        }
        .width(44)
        .height(44)
        .accessibilityDescription($r('app.string.a11y_more'))
        .focusable(true)
        .onClick(() => {
          this.menuVisible = true;
        })
        .bindPopup(this.menuVisible, {
          builder: (): void => this.menuCard(),
          placement: Placement.Bottom,
          enableArrow: false,
          mask: true,
          offset: { x: -228, y: 8 },
          onStateChange: (e: PopupState): void => {
            if (!e.isVisible) {
              this.menuVisible = false;
            }
          }
        })
      }
      .width('100%')
      .height(52)
      .padding({ left: 4, right: 4 })

      PageShadowBar({ show: this.scrollShadow })

      Scroll() {
        Column() {
          ForEach(this.messages, (msg: ChatMessage) => {
            this.messageBubble(msg)
          }, (msg: ChatMessage) => msg.id)
        }
        .padding({ top: 8, bottom: 16 })
        .width('100%')
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
      .onScroll((_x: number, y: number): void => {
        this.scrollShadow = y > 0.001;
      })

      // 底部输入栏：圆角灰输入框 + 纸飞机发送钮（空输入禁用）
      Row({ space: 10 }) {
        TextInput({ placeholder: $r('app.string.copilot_ask_input') })
          .layoutWeight(1)
          .height(40)
          .borderRadius(20)
          .backgroundColor($r('app.color.card_background'))
          .fontSize($r('app.float.body_font_size'))
          .onChange((value: string) => {
            this.draft = value;
          })

        Stack() {
          OctIcon({ res: $r('app.media.oct_paper_airplane_16'), iconSize: 18, iconColor: Color.White })
        }
        .width(36)
        .height(36)
        .borderRadius(18)
        .backgroundColor(this.draft.trim() !== '' ? $r('app.color.link_blue') : $r('app.color.tab_active_bg'))
        .onClick(() => this.send())
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })
      .backgroundColor($r('app.color.card_background'))
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_page'))
  }
}
