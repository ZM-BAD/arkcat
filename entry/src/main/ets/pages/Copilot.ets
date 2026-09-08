/**
 * Copilot Tab 主页（Spec 059）：Agent Sessions 宣传卡 + Chats 真实会话列表 + 右下 FAB。
 * 数据源 = CopilotStore（本地持久化单例）。
 *
 * 刷新模型：不依赖 @Trace 自动刷新（静态单例 @Trace 在本版 SDK 不可靠，实测「数据已
 * 加载但 UI 仍空态」），走 index.ets 发出的 refreshTick 泵 —— @Monitor 监听 @Param
 * 变化后显式重读单例并赋值给 @Local 渲染副本（模式同 EditMyWork onSaved → Home workVersion）。
 */
import { promptAction } from '@kit.ArkUI';
import { OctIcon } from '../components/OctIcon';
import { PageShadowBar } from '../components/PageShadowBar';
import { ChatSession } from '../models/CopilotModels';
import { CopilotStore } from '../utils/CopilotStore';
import { githubShortTime, timeParts } from '../utils/Format';
import { resText } from '../utils/I18n';

@ComponentV2
export struct CopilotView {
  @Param token: string = '';
  @Param pathStack: NavPathStack = new NavPathStack();
  /** 列表刷新泵（Index 在详情页变更后自增，@Monitor 触发重读） */
  @Param refreshTick: number = 0;
  /** 渲染副本：显式从单例拷贝（不走 @Trace） */
  @Local sessions: ChatSession[] = [];
  /** 滚动顶部阴影（滚动中显示、回顶消失） */
  @Local scrollShadow: boolean = false;

  aboutToAppear(): void {
    this.reload();
  }

  @Monitor('refreshTick')
  onRefreshTickChanged(): void {
    this.reload();
  }

  /** 重读单例 → 渲染副本（App 启动/详情页变更/切回本 Tab 都会走到） */
  private reload(): void {
    CopilotStore.load(this.getUIContext().getHostContext()).then(() => {
      this.sessions = CopilotStore.instance.sessions.slice();
    });
  }

  private comingSoon(): void {
    promptAction.showToast({ message: $r('app.string.home_feature_coming') });
  }

  /** 会话行点击 → 详情页（路由参数=会话 id） */
  private openChat(sessionId: string): void {
    this.pathStack.pushPathByName('copilotChat', sessionId);
  }

  /** FAB / NEW CHAT：本地新建会话并进详情（返回后列表由刷新泵更新；落盘由 store 内建） */
  private newChat(): void {
    const session = CopilotStore.createSession();
    this.openChat(session.id);
  }

  /** 会话标题：空标题（尚无首条用户消息）显示 New conversation */
  private titleText(session: ChatSession): string {
    if (session.title !== '') {
      return session.title;
    }
    return resText(this.getUIContext(), $r('app.string.copilot_menu_new_conversation'));
  }

  private timeText(session: ChatSession): string {
    const parts = timeParts(session.updatedAt, Date.now());
    return parts !== null ? githubShortTime(parts) : '';
  }

  /** Agent Sessions 宣传卡：三个装饰圆钮 + 标题 + 说明 + UPGRADE 按钮（红线：保持 toast 占位） */
  @Builder
  agentSessionsCard() {
    Column({ space: 10 }) {
      Row({ space: 10 }) {
        Stack() {
          OctIcon({ res: $r('app.media.oct_agent_16'), iconSize: 22, iconColor: $r('app.color.text_secondary') })
        }
        .width(56)
        .height(56)
        .borderRadius(28)
        .backgroundColor($r('app.color.card_background'))
        .border({ width: 1, color: $r('app.color.border') })

        Stack() {
          OctIcon({ res: $r('app.media.oct_issue_opened_16'), iconSize: 22, iconColor: $r('app.color.link_blue') })
        }
        .width(56)
        .height(56)
        .borderRadius(28)
        .backgroundColor($r('app.color.tab_active_bg'))
        .border({ width: 1, color: $r('app.color.border') })

        Stack() {
          OctIcon({ res: $r('app.media.oct_git_pull_request_16'), iconSize: 22, iconColor: $r('app.color.shortcut_green_fg') })
        }
        .width(56)
        .height(56)
        .borderRadius(28)
        .backgroundColor($r('app.color.shortcut_green_bg'))
        .border({ width: 1, color: $r('app.color.border') })
      }
      .margin({ top: 4, bottom: 2 })

      Text($r('app.string.copilot_agent_delegate'))
        .fontSize(18)
        .fontWeight(600)
        .fontColor($r('app.color.text_primary'))
        .textAlign(TextAlign.Center)
        .width('88%')

      Text($r('app.string.copilot_agent_desc'))
        .fontSize($r('app.float.body_font_size'))
        .fontColor($r('app.color.text_secondary'))
        .textAlign(TextAlign.Center)
        .width('90%')

      Button($r('app.string.copilot_upgrade_pro'))
        .fontSize($r('app.float.body_font_size'))
        .fontWeight(600)
        .fontColor($r('app.color.link_blue'))
        .backgroundColor(Color.Transparent)
        .width('100%')
        .height(40)
        .borderRadius(6)
        .border({ width: 1, color: $r('app.color.border') })
        .margin({ top: 6 })
        .onClick(() => this.comingSoon())
    }
    .padding($r('app.float.card_padding'))
    .borderRadius($r('app.float.card_radius'))
    .backgroundColor($r('app.color.card_background'))
    .width('100%')
  }

  /** Chats 会话行：标题单行 + 右侧相对时间，细分隔线（对齐参考图 2） */
  @Builder
  sessionRow(session: ChatSession) {
    Row({ space: 10 }) {
      Text(this.titleText(session))
        .fontSize(17)
        .fontColor($r('app.color.text_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
      Text(this.timeText(session))
        .fontSize($r('app.float.caption_font_size'))
        .fontColor($r('app.color.text_secondary'))
    }
    .width('100%')
    .padding({ top: 16, bottom: 16 })
    .onClick(() => this.openChat(session.id))
  }

  /** Chats 空态卡：No chats yet（对齐参考图 1） */
  @Builder
  emptyChatsCard() {
    Column({ space: 10 }) {
      Stack() {
        OctIcon({ res: $r('app.media.oct_copilot_fill_16'), iconSize: 30, iconColor: $r('app.color.text_secondary') })
      }
      .width(64)
      .height(64)
      .borderRadius(32)
      .backgroundColor($r('app.color.tab_active_bg'))
      .margin({ top: 8, bottom: 6 })

      Text($r('app.string.copilot_no_chats'))
        .fontSize(20)
        .fontWeight(600)
        .fontColor($r('app.color.text_primary'))

      Text($r('app.string.copilot_no_chats_hint'))
        .fontSize($r('app.float.body_font_size'))
        .fontColor($r('app.color.text_secondary'))
        .textAlign(TextAlign.Center)
        .width('80%')

      Text($r('app.string.copilot_new_chat'))
        .fontSize($r('app.float.body_font_size'))
        .fontWeight(600)
        .fontColor($r('app.color.link_blue'))
        .padding({ top: 10, bottom: 10 })
        .onClick(() => this.newChat())
    }
    .padding({ top: 24, bottom: 24 })
    .borderRadius($r('app.float.card_radius'))
    .backgroundColor($r('app.color.card_background'))
    .width('100%')
  }

  /** 右下 FAB（底栏之上的悬浮新建钮） */
  @Builder
  fabButton() {
    Stack() {
      OctIcon({ res: $r('app.media.oct_plus_24'), iconSize: 24, iconColor: Color.White })
    }
    .width(52)
    .height(52)
    .borderRadius(14)
    .backgroundColor($r('app.color.link_blue'))
    .shadow({ radius: 8, color: $r('app.color.shadow_floating'), offsetX: 0, offsetY: 4 })
    .margin({ right: 16, bottom: 16 })
    .onClick(() => this.newChat())
  }

  build() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Column() {
        Row() {
          Text($r('app.string.tab_copilot'))
            .fontSize($r('app.float.title_font_size'))
            .fontWeight(600)
            .fontColor($r('app.color.text_primary'))
            .layoutWeight(1)
          Stack() {
            OctIcon({ res: $r('app.media.oct_kebab_horizontal_16'), iconSize: 18, iconColor: $r('app.color.link_blue') })
              .rotate({ angle: 90 })
          }
          .width(44)
          .height(44)
          .accessibilityDescription($r('app.string.a11y_more'))
          .focusable(true)
          .bindMenu([
            {
              value: $r('app.string.copilot_menu_refresh'),
              action: (): void => this.reload()
            }
          ])
        }
        .width('100%')
        .padding($r('app.float.page_padding'))

        PageShadowBar({ show: this.scrollShadow })

        Scroll() {
          Column() {
            Text($r('app.string.copilot_agent_sessions'))
              .fontSize($r('app.float.title_font_size'))
              .fontWeight(600)
              .fontColor($r('app.color.text_primary'))
              .width('100%')
              .margin({ top: 8, bottom: 8 })

            this.agentSessionsCard()

            Text($r('app.string.copilot_chats'))
              .fontSize($r('app.float.title_font_size'))
              .fontWeight(600)
              .fontColor($r('app.color.text_primary'))
              .width('100%')
              .margin({ top: 20, bottom: 4 })

            if (this.sessions.length > 0) {
              ForEach(this.sessions, (session: ChatSession) => {
                this.sessionRow(session)
                Divider()
                  .strokeWidth(0.5)
                  .color($r('app.color.divider'))
                  .width('100%')
              }, (session: ChatSession) => session.id)
            } else {
              this.emptyChatsCard()
            }
          }
          .padding({ left: 16, right: 16, bottom: 96 })
          .width('100%')
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .align(Alignment.Top)
        .onScroll((_x: number, y: number): void => {
          this.scrollShadow = y > 0.001;
        })
      }
      .width('100%')
      .height('100%')

      this.fabButton()
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_page'))
  }
}
