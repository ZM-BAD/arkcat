/**
 * Copilot 聊天详情页（Spec 059 功能批）：
 * AppBar（标题 + Auto 副标 + 竖三点菜单）+ 真实消息气泡 + 底部输入栏。
 *
 * 发送链路：追加用户消息到 CopilotStore（本地持久化）→ POST /chat/completions
 * （模型=白名单常量，付费红线：仅 Copilot Free 免费额度）→ 成功追加助手消息，
 * 失败展示错误卡片 + 重试。会话数据源 = CopilotStore（主页/详情共享）。
 */
import { promptAction, KeyboardAvoidMode } from '@kit.ArkUI';
import { OctIcon } from '../components/OctIcon';
import { PageShadowBar } from '../components/PageShadowBar';
import { ChatMessage, ChatSession } from '../models/CopilotModels';
import { copilotChat, CopilotTurn } from '../services/CopilotService';
import { CopilotStore } from '../utils/CopilotStore';
import { resText } from '../utils/I18n';

/** bindPopup onStateChange 回调的类型（与 PrDiffCard/WorkFilterBar 同款自声明） */
interface PopupState {
  isVisible: boolean;
}

/** 错误文案映射：Copilot 域名 403/429 语义=权限/配额受限，与 GitHub 主 API 的 rate-limited 区分 */
interface ErrorText {
  text: Resource;
  args: Array<string | number>;
}

@ComponentV2
export struct CopilotChatView {
  @Param token: string = '';
  @Param sessionId: string = '';
  @Param pathStack: NavPathStack = new NavPathStack();
  /** 会话变更回调（发送/删除/切换）：Index 借此自增主页刷新泵 */
  @Param onChanged: () => void = () => {};
  @Local messages: ChatMessage[] = [];
  @Local currentSessionId: string = '';
  @Local currentTitle: string = '';
  /** 发送中：显示键入中占位 + 发送钮禁用 */
  @Local sending: boolean = false;
  /** 失败卡片文案（空=不显示） */
  @Local sendError: Resource | null = null;
  @Local draft: string = '';
  /** 竖三点菜单浮层 */
  @Local menuVisible: boolean = false;
  /** 滚动顶部阴影 */
  @Local scrollShadow: boolean = false;

  aboutToAppear(): void {
    // 键盘避让改压缩模式：底部输入栏贴键盘显示（058 元素 8 要求）；离开恢复默认上抬
    this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.RESIZE);
    this.currentSessionId = this.sessionId;
    const loadSession = (): void => {
      const session = CopilotStore.find(this.currentSessionId);
      if (session !== null) {
        this.currentTitle = session.title;
        this.messages = session.messages.slice();
      } else {
        this.pathStack.pop();
      }
    };
    // 内存单例优先（主页已 load/新建会话刚同步）；find 失败（冷启动直入详情）才读盘兜底
    if (CopilotStore.find(this.currentSessionId) !== null) {
      loadSession();
    } else {
      CopilotStore.load(this.getUIContext().getHostContext()).then(loadSession);
    }
  }

  aboutToDisappear(): void {
    this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.OFFSET);
  }

  private comingSoon(): void {
    promptAction.showToast({ message: $r('app.string.home_feature_coming') });
  }

  private openSettings(): void {
    this.menuVisible = false;
    this.pathStack.pushPathByName('copilotSettings', '');
  }

  /** 新建会话：本地创建 + 入栈新详情页（旧会话留在栈下，返回可回；落盘内建） */
  private newConversation(): void {
    this.menuVisible = false;
    const session = CopilotStore.createSession();
    this.pathStack.pushPathByName('copilotChat', session.id);
  }

  /** 菜单切换历史会话：重载对应会话消息（当前会话项置灰不可点） */
  private switchChat(sessionId: string): void {
    this.menuVisible = false;
    const session = CopilotStore.find(sessionId);
    if (session === null) {
      return;
    }
    this.currentSessionId = session.id;
    this.currentTitle = session.title;
    this.messages = session.messages.slice();
    this.sendError = null;
    this.onChanged();
  }

  /** View all conversations：详情页由主页进入，pop 即回主页会话列表 */
  private viewAll(): void {
    this.menuVisible = false;
    this.pathStack.pop();
  }

  /** Delete conversation：确认弹窗（仿 PrDetail DELETE BRANCH 模式）后真删本地会话 */
  private deleteConversation(): void {
    this.menuVisible = false;
    const ui = this.getUIContext();
    ui.getPromptAction().showDialog(
      {
        message: resText(ui, $r('app.string.copilot_delete_confirm')),
        buttons: [
          {
            text: resText(ui, $r('app.string.pr_delete_branch_cancel')),
            color: $r('app.color.link_blue')
          },
          {
            text: resText(ui, $r('app.string.copilot_delete_action')),
            color: $r('app.color.badge_red')
          }
        ]
      },
      (err, data) => {
        if (err) {
          return;
        }
        if (data.index === 1) {
          CopilotStore.delete(this.currentSessionId);
          this.onChanged();
          this.pathStack.pop();
        }
      }
    );
  }

  /** 错误文案映射（付费红线相关错误也走此分支，429/403 提示权限或限额） */
  private errorTextOf(e: Error): Resource {
    const found = /HTTP (\d{3})/.exec(e.message);
    const code = found !== null && found[1] !== undefined ? Number(found[1]) : 0;
    if (code === 401) {
      return $r('app.string.error_auth');
    }
    if (code === 403 || code === 429) {
      return $r('app.string.copilot_error_quota');
    }
    return $r('app.string.copilot_error_send');
  }

  /** 发送（空输入/发送中禁用）；发送前首条消息标题由 CopilotStore.appendMessage 接管 */
  private send(): void {
    const body = this.draft.trim();
    if (body === '' || this.sending) {
      return;
    }
    this.draft = '';
    this.sendError = null;
    CopilotStore.appendMessage(this.currentSessionId, true, body);
    const session = CopilotStore.find(this.currentSessionId);
    if (session !== null) {
      this.currentTitle = session.title;
      this.messages = session.messages.slice();
    }
    this.onChanged();
    this.requestReply();
  }

  /** 失败重试：用户消息已在本地，不重复追加，直接重发（阻断发送中） */
  private retry(): void {
    if (this.sending) {
      return;
    }
    this.sendError = null;
    this.requestReply();
  }

  /** 请求助手回复（turns 组装自本地消息；成功追加助手消息，失败显示错误卡片） */
  private async requestReply(): Promise<void> {
    const session = CopilotStore.find(this.currentSessionId);
    if (session === null) {
      return;
    }
    const turns: CopilotTurn[] = [];
    for (const msg of session.messages) {
      turns.push({ role: msg.isUser ? 'user' : 'assistant', content: msg.body });
    }
    this.sending = true;
    try {
      const reply = await copilotChat(this.token, turns);
      CopilotStore.appendMessage(this.currentSessionId, false, reply);
      const updated = CopilotStore.find(this.currentSessionId);
      if (updated !== null) {
        this.messages = updated.messages.slice();
      }
      this.onChanged();
    } catch (e) {
      this.sendError = this.errorTextOf(e as Error);
    } finally {
      this.sending = false;
    }
  }

  /** AppBar 标题：会话标题为空（新建未发言）时用 New conversation */
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

  /** 竖三点菜单浮层（bindPopup 下拉式，参考图 3；New conversation/历史切换/Delete 为真实动作） */
  @Builder
  menuCard() {
    Column() {
      this.menuItem($r('app.media.oct_plus_24'), $r('app.string.copilot_menu_new_conversation'),
        $r('app.color.link_blue'), () => this.newConversation())

      // 当前会话：置灰不可点（眼睛图标）
      this.menuItem($r('app.media.oct_eye_16'), this.titleText(), $r('app.color.text_secondary'),
        () => {
          this.menuVisible = false;
        })

      // 历史会话（当前之外）：点按切换
      ForEach(CopilotStore.instance.sessions, (session: ChatSession) => {
        if (session.id !== this.currentSessionId) {
          this.menuItem($r('app.media.oct_comment_16'),
            session.title === '' ? $r('app.string.copilot_menu_new_conversation') : session.title,
            $r('app.color.text_secondary'), (): void => this.switchChat(session.id))
        }
      }, (session: ChatSession) => session.id)

      Divider().strokeWidth(0.5).color($r('app.color.divider'))

      this.menuItem($r('app.media.oct_comment_discussion_16'), $r('app.string.copilot_menu_view_all'),
        $r('app.color.text_secondary'), () => this.viewAll())
      this.menuItem($r('app.media.oct_copilot_16'), $r('app.string.copilot_menu_settings'),
        $r('app.color.text_primary'), () => this.openSettings())
      Divider().strokeWidth(0.5).color($r('app.color.divider'))
      this.menuItem($r('app.media.oct_trash_16'), $r('app.string.copilot_menu_delete'),
        $r('app.color.danger_text'), () => this.deleteConversation())
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

  /** 键入中占位：助手侧圆钮 + spinning（发送后未响应时显示） */
  @Builder
  typingBubble() {
    Row() {
      Stack() {
        LoadingProgress()
          .width(18)
          .height(18)
          .color($r('app.color.link_blue'))
      }
      .width(36)
      .height(36)
      .borderRadius(18)
      .backgroundColor($r('app.color.card_background'))
      .border({ width: 1, color: $r('app.color.border') })
      .margin({ right: 40 })
    }
    .width('100%')
    .justifyContent(FlexAlign.Start)
    .padding({ left: 12, right: 12, top: 6, bottom: 6 })
  }

  /** 失败卡片：错误文案 + 重试（发送失败不重复追加用户气泡） */
  @Builder
  errorBubble() {
    Row() {
      Column({ space: 8 }) {
        Row({ space: 6 }) {
          OctIcon({ res: $r('app.media.oct_alert_16'), iconSize: 16, iconColor: $r('app.color.danger_text') })
          Text(this.sendError ?? '')
            .fontSize($r('app.float.body_font_size'))
            .fontColor($r('app.color.danger_text'))
            .layoutWeight(1)
        }
        .width('100%')

        Text($r('app.string.copilot_retry'))
          .fontSize($r('app.float.body_font_size'))
          .fontWeight(600)
          .fontColor($r('app.color.link_blue'))
          .alignSelf(ItemAlign.End)
          .onClick(() => this.retry())
      }
      .padding(12)
      .borderRadius(16)
      .backgroundColor($r('app.color.bg_page'))
      .border({ width: 1, color: $r('app.color.divider') })
      .margin({ right: 40 })
    }
    .width('100%')
    .justifyContent(FlexAlign.Start)
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
          offset: { x: 0, y: 8 },
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
          if (this.sending) {
            this.typingBubble()
          }
          if (this.sendError !== null) {
            this.errorBubble()
          }
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

      // 底部输入栏：圆角灰输入框 + 纸飞机发送钮（空输入/发送中禁用）
      Row({ space: 10 }) {
        TextInput({ text: this.draft, placeholder: $r('app.string.copilot_ask_input') })
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
        .backgroundColor(
          !this.sending && this.draft.trim() !== '' ? $r('app.color.link_blue') : $r('app.color.tab_active_bg'))
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
