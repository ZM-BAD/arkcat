/**
 * Copilot settings 页（Spec 059）：Subscription / Usage / About 三分组。
 * login 来自当前账号（Index 透传 currentLogin，账号存储为 Spec 049a 的 AccountStore）；
 * Usage 环=服务端真实用量（copilot_internal/user 的 quota_snapshots，实测 200），
 * 端点不可用时降级为本地记账近似；套餐名保持静态文案（无公开套餐 API）。
 */
import { promptAction } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { OctIcon } from '../components/OctIcon';
import { PageShadowBar } from '../components/PageShadowBar';
import { HomeService } from '../services/HomeService';
import { CopilotQuota, fetchCopilotQuota } from '../services/CopilotService';
import { CopilotStore } from '../utils/CopilotStore';
import { resText } from '../utils/I18n';

/** 本地估算回退用的 Copilot Free 月度上限（057 实测：chat 200 / completions 2000） */
const FREE_CHAT_LIMIT = 200;

@ComponentV2
export struct CopilotSettingsView {
  @Param token: string = '';
  /** 当前账号 login（Index 的 currentLogin；v1 迁移 viewer 失败时为空串占位） */
  @Param login: string = '';
  @Param pathStack: NavPathStack = new NavPathStack();
  /** 滚动顶部阴影 */
  @Local scrollShadow: boolean = false;
  /** 渲染用登录名：@Param 快照 + 占位为空时的兜底拉取结果 */
  @Local displayLogin: string = '';
  /** 服务端真实用量；null=未取到（网络失败/端点变更）→ Usage 行回退本地估算 */
  @Local quota: CopilotQuota | null = null;
  /** 套餐名：无公开 API 可查（见 059 边界），保持静态 */
  private readonly planName: string = 'Copilot Free';

  aboutToAppear(): void {
    this.resolveLogin();
    this.loadQuota();
  }

  @Monitor('login')
  onLoginChanged(): void {
    this.resolveLogin();
  }

  /**
   * 登录名解析：账号 login 正常则直接显示；仅占位为空（049a 迁移时 viewer 查询失败）
   * 才兜底拉取 viewer 供本页展示——不回写账号存储（login 的事实源在 AccountStore）。
   */
  private resolveLogin(): void {
    if (this.login !== '') {
      this.displayLogin = this.login;
      return;
    }
    if (this.token !== '') {
      HomeService.fetchViewerBasic(this.token)
        .then((viewer) => {
          this.displayLogin = viewer.login;
        })
        .catch((e: Error) => {
          hilog.warn(0xFF00, '[CopilotSettings]', 'viewer fetch failed: %{public}s', `${e}`);
        });
    }
  }

  /** 服务端真实用量（失败静默：quota 保持 null，Usage 行自动降级本地估算） */
  private loadQuota(): void {
    fetchCopilotQuota(this.token).then((quota: CopilotQuota | null) => {
      if (quota !== null) {
        this.quota = quota;
      }
    });
  }

  /** 本地累计用户消息数 → chat 配额近似使用率（0-100；仅服务端用量不可用时使用） */
  private localChatPercent(): number {
    let count = 0;
    for (const session of CopilotStore.instance.sessions) {
      for (const msg of session.messages) {
        if (msg.isUser) {
          count += 1;
        }
      }
    }
    const percent = Math.round(count * 100 / FREE_CHAT_LIMIT);
    return percent > 100 ? 100 : percent;
  }

  private comingSoon(): void {
    promptAction.showToast({ message: $r('app.string.home_feature_coming') });
  }

  /** Usage 统计行：名称 + N% used + 蓝色环形进度 */
  @Builder
  usageRow(label: ResourceStr, percent: number) {
    Row({ space: 12 }) {
      Text(label)
        .fontSize(17)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
      Text(resText(this.getUIContext(), $r('app.string.copilot_settings_used'),
        `${percent}%`))
        .fontSize(17)
        .fontColor($r('app.color.text_primary'))
      Progress({ value: percent, total: 100, type: ProgressType.Ring })
        .width(18)
        .height(18)
        .color($r('app.color.link_blue'))
        .style({ strokeWidth: 2.5 })
    }
    .width('100%')
    .padding({ top: 14, bottom: 14 })
  }

  /** About 可点行（点按 toast 占位） */
  @Builder
  aboutRow(label: ResourceStr) {
    Text(label)
      .fontSize(17)
      .fontColor($r('app.color.text_primary'))
      .width('100%')
      .padding({ top: 16, bottom: 16 })
      .onClick(() => this.comingSoon())
  }

  /** 页脚：灰底说明 + 蓝色链接文本（Span 多色） */
  @Builder
  footerNote() {
    Text() {
      Span($r('app.string.copilot_settings_footer_a'))
        .fontColor($r('app.color.text_secondary'))
      Span($r('app.string.copilot_settings_footer_link_match'))
        .fontColor($r('app.color.link_blue'))
        .decoration({ type: TextDecorationType.Underline, color: $r('app.color.link_blue') })
      Span($r('app.string.copilot_settings_footer_b'))
        .fontColor($r('app.color.text_secondary'))
      Span($r('app.string.copilot_settings_footer_link_settings'))
        .fontColor($r('app.color.link_blue'))
        .decoration({ type: TextDecorationType.Underline, color: $r('app.color.link_blue') })
      Span($r('app.string.copilot_settings_footer_c'))
        .fontColor($r('app.color.text_secondary'))
    }
    .fontSize($r('app.float.body_font_size'))
    .lineHeight(22)
    .width('100%')
    .padding({ top: 8, bottom: 4 })
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

        Text($r('app.string.tab_copilot'))
          .fontSize($r('app.float.title_font_size'))
          .fontWeight(600)
          .fontColor($r('app.color.text_primary'))
      }
      .width('100%')
      .height(52)
      .padding({ left: 4, right: 4 })

      PageShadowBar({ show: this.scrollShadow })

      Scroll() {
        // 三个分组各为一张白卡，卡间 8vp 露出灰底画布（区域感/分隔带）
        Column({ space: 8 }) {
          // Subscription 分组
          Column() {
            Text($r('app.string.copilot_settings_subscription'))
              .fontSize($r('app.float.body_font_size'))
              .fontColor($r('app.color.text_secondary'))
              .width('100%')
              .margin({ bottom: 4 })

            Text(this.planName)
              .fontSize(28)
              .fontWeight(600)
              .fontColor($r('app.color.text_primary'))
              .width('100%')

            if (this.displayLogin !== '') {
              Text(resText(this.getUIContext(), $r('app.string.copilot_settings_active_for'), this.displayLogin))
                .fontSize($r('app.float.body_font_size'))
                .fontColor($r('app.color.text_secondary'))
                .width('100%')
            } else {
              Text($r('app.string.copilot_settings_plan_unknown'))
                .fontSize($r('app.float.body_font_size'))
                .fontColor($r('app.color.text_secondary'))
                .width('100%')
            }
          }
          .width('100%')
          .padding($r('app.float.card_padding'))
          .backgroundColor($r('app.color.card_background'))
          .borderRadius($r('app.float.card_radius'))

          // Usage 分组
          Column() {
            Text($r('app.string.copilot_settings_usage'))
              .fontSize($r('app.float.body_font_size'))
              .fontColor($r('app.color.text_secondary'))
              .width('100%')
              .margin({ bottom: 4 })

            this.usageRow($r('app.string.copilot_settings_code_completions'),
              this.quota !== null ? this.quota.completionsUsedPercent : 0)
            this.usageRow($r('app.string.copilot_settings_chat_messages'),
              this.quota !== null ? this.quota.chatUsedPercent : this.localChatPercent())

            if (this.quota === null) {
              // 服务端用量未取到（离线/端点变更）：明示此行数据为本地估算
              Text($r('app.string.copilot_usage_local_hint'))
                .fontSize($r('app.float.caption_font_size'))
                .fontColor($r('app.color.text_secondary'))
                .width('100%')
            }

            Button($r('app.string.copilot_settings_upgrade_plan'))
              .fontSize($r('app.float.body_font_size'))
              .fontWeight(600)
              .fontColor($r('app.color.link_blue'))
              .backgroundColor($r('app.color.tab_active_bg'))
              .width('100%')
              .height(44)
              .borderRadius(6)
              .margin({ top: 10 })
              .onClick(() => this.comingSoon())

            Text($r('app.string.copilot_settings_upgrade_desc'))
              .fontSize($r('app.float.body_font_size'))
              .fontColor($r('app.color.text_secondary'))
              .lineHeight(22)
              .width('100%')
              .margin({ top: 10 })
          }
          .width('100%')
          .padding($r('app.float.card_padding'))
          .backgroundColor($r('app.color.card_background'))
          .borderRadius($r('app.float.card_radius'))

          // About 分组
          Column() {
            Text($r('app.string.copilot_settings_about'))
              .fontSize($r('app.float.body_font_size'))
              .fontColor($r('app.color.text_secondary'))
              .width('100%')
              .padding({ top: 4, bottom: 2 })

            this.aboutRow($r('app.string.settings_copilot_free'))
            Divider().strokeWidth(0.5).color($r('app.color.divider'))
            this.aboutRow($r('app.string.copilot_settings_copilot'))
            Divider().strokeWidth(0.5).color($r('app.color.divider'))
            this.aboutRow($r('app.string.copilot_settings_privacy_policy'))
            Divider().strokeWidth(0.5).color($r('app.color.divider'))
            this.aboutRow($r('app.string.copilot_settings_terms'))
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 8, bottom: 0 })
          .backgroundColor($r('app.color.card_background'))
          .borderRadius($r('app.float.card_radius'))

          // 页脚说明随内容滚动（不常驻底部，避免遮挡 About 区）
          this.footerNote()
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 8, bottom: 16 })
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
    .backgroundColor($r('app.color.bg_page'))
  }
}
