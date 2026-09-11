/**
 * Token 设置页：首次启动或未配置 Token 时展示。
 * Spec 057：OAuth Device Flow 主路径 + PAT 粘贴兼容路径（两路径均在本 Spec 范围内）。
 * 登录方式二选一：GitHub 登录（浏览器授权，无手动 token）/ PAT 粘贴（兼容保留）。
 */
import { common } from '@kit.AbilityKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { OctIcon } from '../components/OctIcon';
import { AccountStore, AddAccountResult } from '../services/AccountStore';
import { HomeService } from '../services/HomeService';
import { friendlyError } from '../services/GitHttpClient';
import { OAuthDeviceInfo, OAuthPollState, OAuthPollResult, requestDeviceCode, pollToken } from '../services/OAuthService';
import { resText } from '../utils/I18n';

@ComponentV2
export struct TokenSetup {
  /** onSaved(token, login)：登录成功后上抛（登录落地页/添加账号双场景共用） */
  @Event onSaved: (token: string, login: string) => void = (token: string, login: string) => {};
  /** 视图态：'choice'=登录方式二选一 / 'pat'=PAT 表单 / 'oauth'=浏览器授权等待页 */
  /** 作为 NavDestination（添加账号场景）嵌入时：pageBar 返回走 onEmbeddedPop；落地页时内部视图切换 */
  @Param embedded: boolean = false;
  @Event onEmbeddedPop: () => void = () => {};
  @Local view: string = 'choice';
  // ---- PAT（兼容路径，行为零改动）----
  @Local token: string = '';
  @Local error: string = '';
  @Local saving: boolean = false;
  // ---- OAuth（Spec 057）----
  @Local oauthInfo: OAuthDeviceInfo | null = null;
  @Local oauthError: string = '';
  @Local polling: boolean = false;
  private pollTimer: number = -1;

  aboutToDisappear(): void {
    this.clearPolling();
  }

  build() {
    Column() {
      if (this.view === 'choice') {
        this.choiceView()
      } else if (this.view === 'pat') {
        this.patView()
      } else {
        this.oauthView()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_page'))
  }

  /** 登录方式二选一：OAuth 主按钮（蓝底）+ PAT 文字次入口 */
  @Builder
  choiceView() {
    Column({ space: 16 }) {
      Blank().height(80)

      Text('🐙')
        .fontSize(40)

      Text($r('app.string.login_choice_title'))
        .fontSize($r('app.float.page_text_font_size'))
        .fontWeight(600)
        .fontColor($r('app.color.text_primary'))

      Text($r('app.string.login_choice_desc'))
        .fontSize($r('app.float.body_font_size'))
        .fontColor($r('app.color.text_secondary'))
        .textAlign(TextAlign.Center)
        .padding({ left: 24, right: 24 })

      Button($r('app.string.login_oauth_button'))
        .width('86%')
        .height($r('app.float.button_height'))
        .backgroundColor($r('app.color.link_blue'))
        .fontColor(Color.White)
        .onClick(() => {
          this.startOAuth();
        })

      Text($r('app.string.login_oauth_hint'))
        .fontSize($r('app.float.caption_font_size'))
        .fontColor($r('app.color.text_secondary'))

      Text($r('app.string.login_pat_button'))
        .fontSize($r('app.float.body_font_size'))
        .fontColor($r('app.color.link_blue'))
        .padding({ left: 16, right: 16, top: 10, bottom: 10 })
        .onClick(() => {
          this.view = 'pat';
        })

      if (this.oauthError !== '') {
        Text(this.oauthError)
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.badge_red'))
          .padding({ left: 24, right: 24 })
      }
    }
    .width('100%')
  }

  /** PAT 折叠表单：兼容路径，行为原样保留（输入 + 保存前实测 + 错误文案） */
  @Builder
  patView() {
    Column({ space: 16 }) {
      this.pageBar($r('app.string.token_setup_title'), () => {
        if (this.embedded) {
          this.onEmbeddedPop();
        } else {
          this.view = 'choice';
        }
      })

      Blank().height(40)

      Text($r('app.string.token_setup_desc'))
        .fontSize($r('app.float.body_font_size'))
        .fontColor($r('app.color.text_secondary'))
        .textAlign(TextAlign.Center)
        .padding({ left: 24, right: 24 })

      TextInput({ placeholder: $r('app.string.token_input_placeholder'), text: this.token })
        .type(InputType.Password)
        .width('86%')
        .height($r('app.float.button_height'))
        .onChange((value: string) => {
          this.token = value;
          this.error = '';
        })

      if (this.error !== '') {
        Text(this.error)
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.badge_red'))
      }

      Button($r('app.string.token_save'))
        .width('86%')
        .height($r('app.float.button_height'))
        .backgroundColor($r('app.color.link_blue'))
        .enabled(this.token.trim() !== '' && !this.saving)
        .onClick(() => {
          this.saveToken();
        })
    }
    .width('100%')
  }

  /** OAuth 等待页：设备码展示 + 复制 + 拉起浏览器；轮询成功自动进主界面 */
  @Builder
  oauthView() {
    Column({ space: 16 }) {
      this.pageBar($r('app.string.oauth_wait_title'), () => {
        this.backToChoice();
      })

      Blank().height(40)

      Text($r('app.string.oauth_code_hint'))
        .fontSize($r('app.float.body_font_size'))
        .fontColor($r('app.color.text_secondary'))
        .textAlign(TextAlign.Center)
        .padding({ left: 24, right: 24 })

      Row({ space: 8 }) {
        Text(this.oauthInfo?.userCode ?? '')
          .fontSize(24)
          .fontFamily('monospace')
          .fontWeight(600)
          .fontColor($r('app.color.text_primary'))
          .letterSpacing(2)

        Text($r('app.string.oauth_code_copy'))
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.link_blue'))
          .padding({ left: 8, right: 8, top: 6, bottom: 6 })
          .onClick(() => {
            this.copyCode();
          })
      }

      Button($r('app.string.oauth_open_browser'))
        .width('86%')
        .height($r('app.float.button_height'))
        .backgroundColor($r('app.color.link_blue'))
        .fontColor(Color.White)
        .enabled(this.oauthInfo !== null)
        .onClick(() => {
          if (this.oauthInfo !== null) {
            this.openBrowser(this.oauthInfo.verificationUri);
          }
        })

      if (this.polling) {
        LoadingProgress()
          .width(32)
          .height(32)
          .color($r('app.color.link_blue'))
          .margin({ top: 12 })

        Text($r('app.string.oauth_waiting'))
          .fontSize($r('app.float.body_font_size'))
          .fontColor($r('app.color.text_primary'))

        Text($r('app.string.oauth_waiting_sub'))
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_secondary'))
      } else if (this.oauthError !== '') {
        Text(this.oauthError)
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.badge_red'))
          .textAlign(TextAlign.Center)
          .padding({ left: 24, right: 24 })
          .margin({ top: 12 })

        Text($r('app.string.oauth_retry'))
          .fontSize($r('app.float.body_font_size'))
          .fontColor($r('app.color.link_blue'))
          .padding({ left: 16, right: 16, top: 10, bottom: 10 })
          .onClick(() => {
            this.startOAuth();
          })
      }
    }
    .width('100%')
  }

  /** 自绘 AppBar（返回 + 标题）；TokenSetup 非 NavDestination，返回为视图切换 */
  @Builder
  pageBar(title: Resource, onBack: () => void) {
    Row() {
      Stack() {
        OctIcon({ res: $r('app.media.oct_arrow_left_24'), iconSize: 20, iconColor: $r('app.color.text_primary') })
      }
      .width(44)
      .height(44)
      .accessibilityDescription($r('app.string.a11y_back'))
      .focusable(true)
      .onClick(() => {
        onBack();
      })

      Text(title)
        .fontSize($r('app.float.title_font_size'))
        .fontWeight(600)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)

      // 右侧占位 44，保证标题水平居中
      Stack()
        .width(44)
        .height(44)
    }
    .width('100%')
    .height(56)
    .padding({ left: 4, right: 4 })
  }

  /** 发起 OAuth：申请设备码 → 自动拉起浏览器 → 按 interval 轮询 */
  private async startOAuth(): Promise<void> {
    this.oauthError = '';
    this.polling = true;
    try {
      const info = await requestDeviceCode();
      this.oauthInfo = info;
      this.view = 'oauth';
      this.openBrowser(info.verificationUri);
      this.startPolling(info);
    } catch (e) {
      // 申请失败停留选择页；网络失败友好文案（review A14）
      this.polling = false;
      this.oauthError = friendlyError(this.getUIContext(), e as Error);
    }
  }

  private startPolling(info: OAuthDeviceInfo): void {
    this.clearPolling();
    this.scheduleTick(info, info.interval);
  }

  private scheduleTick(info: OAuthDeviceInfo, interval: number): void {
    this.pollTimer = setTimeout(() => {
      this.runPollStep(info, interval);
    }, interval * 1000);
  }

  private async runPollStep(info: OAuthDeviceInfo, interval: number): Promise<void> {
    try {
      const result: OAuthPollResult = await pollToken(info.deviceCode, interval);
      if (result.state === OAuthPollState.PENDING || result.state === OAuthPollState.SLOW_DOWN) {
        this.scheduleTick(info, result.nextInterval);
        return;
      }
      if (result.state === OAuthPollState.SUCCESS) {
        this.stopPolling();
        await this.finishLogin(result.token);
        return;
      }
      // expired / denied / error：终止轮询，给出对应文案
      this.polling = false;
      this.oauthError = this.pollEndMessage(result.state);
    } catch (e) {
      this.polling = false;
      this.oauthError = friendlyError(this.getUIContext(), e as Error);
    }
  }

  /** token 落库前实测（与 PAT 保存口径一致）；通过后触发 onSaved 进主界面 */
  private async finishLogin(token: string): Promise<void> {
    try {
      const viewer = await HomeService.fetchViewerBasic(token);
      const result = await this.persistAccount(viewer.login, token, viewer.name);
      if (result === AddAccountResult.LIMIT) {
        this.oauthError = this.stringOf($r('app.string.accounts_limit_hint'));
        return;
      }
      if (result === AddAccountResult.DUPLICATE) {
        this.getUIContext().getPromptAction().showToast({ message: $r('app.string.accounts_duplicate_hint') });
      }
      this.onSaved(token, viewer.login);
    } catch (e) {
      this.oauthError = friendlyError(this.getUIContext(), e as Error);
    }
  }

  private pollEndMessage(state: OAuthPollState): string {
    if (state === OAuthPollState.EXPIRED) {
      return this.stringOf($r('app.string.oauth_error_expired'));
    }
    if (state === OAuthPollState.DENIED) {
      return this.stringOf($r('app.string.oauth_error_denied'));
    }
    return this.stringOf($r('app.string.oauth_error_failed'));
  }

  private backToChoice(): void {
    if (this.embedded) {
      // 添加账号场景：返回即关闭本页（NavDestination pop）
      this.stopPolling();
      this.polling = false;
      this.onEmbeddedPop();
      return;
    }
    // 返回即取消轮询；再次发起重新申请新 device_code（TDD 第 8 条）
    this.stopPolling();
    this.polling = false;
    this.oauthError = '';
    this.oauthInfo = null;
    this.view = 'choice';
  }

  private stopPolling(): void {
    this.clearPolling();
  }

  private clearPolling(): void {
    if (this.pollTimer >= 0) {
      clearTimeout(this.pollTimer);
      this.pollTimer = -1;
    }
  }

  /** 拉起系统浏览器（MarkdownView 同款 viewData want） */
  private openBrowser(url: string): void {
    const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    if (ctx === undefined) {
      return;
    }
    ctx.startAbility({
      action: 'ohos.want.action.viewData',
      entities: ['entity.system.browsable'],
      uri: url
    });
  }

  private copyCode(): void {
    if (this.oauthInfo === null) {
      return;
    }
    const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.oauthInfo.userCode);
    pasteboard.getSystemPasteboard().setDataSync(data);
    // getUIContext().getPromptAction() 为 API 18+ 推荐路径（promptAction 全局已弃用）
    this.getUIContext().getPromptAction().showToast({ message: $r('app.string.oauth_code_copied') });
  }

  private async saveToken(): Promise<void> {
    const trimmed = this.token.trim();
    if (trimmed === '') {
      this.error = this.stringOf($r('app.string.token_error_empty'));
      return;
    }
    this.saving = true;
    try {
      // 保存前实测 Token（review A13：无效 token 存下后四 Tab 全 401 且无引导）
      const viewer = await HomeService.fetchViewerBasic(trimmed);
      const result = await this.persistAccount(viewer.login, trimmed, viewer.name);
      if (result === AddAccountResult.LIMIT) {
        this.error = this.stringOf($r('app.string.accounts_limit_hint'));
        return;
      }
      if (result === AddAccountResult.DUPLICATE) {
        this.getUIContext().getPromptAction().showToast({ message: $r('app.string.accounts_duplicate_hint') });
      }
      this.onSaved(trimmed, viewer.login);
    } catch (e) {
      // 401/403 才是 token 无效；网络失败友好区分，不误导用户改 token（复核修正）
      this.error = friendlyError(this.getUIContext(), e as Error);
    } finally {
      this.saving = false;
    }
  }

  /** 写入账号存储（查重/上限反馈），供 PAT 与 OAuth 两条路径共用 */
  private async persistAccount(login: string, token: string, name: string): Promise<AddAccountResult> {
    const ctx = this.getUIContext().getHostContext() as common.Context | undefined;
    return AccountStore.addAccount(ctx, login, token, name);
  }

  /** 资源 → 当前语言的纯文案 */
  private stringOf(res: Resource): string {
    return resText(this.getUIContext(), res);
  }
}
