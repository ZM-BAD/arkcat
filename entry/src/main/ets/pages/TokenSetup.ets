/**
 * Token 设置页：首次启动或未配置 Token 时展示。
 * Spec 001 前置条件——应用直连 GitHub API，必须有 PAT 才能拉取数据。
 */
import { TokenStore } from '../services/TokenStore';
import { resText } from '../utils/I18n';

@ComponentV2
export struct TokenSetup {
  @Event onSaved: (token: string) => void = (token: string) => {};
  @Local token: string = '';
  @Local error: string = '';
  @Local saving: boolean = false;

  build() {
    Column({ space: 16 }) {
      Blank().height(80)

      Text('🐙')
        .fontSize(56)

      Text($r('app.string.token_setup_title'))
        .fontSize($r('app.float.page_text_font_size'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))

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
    .height('100%')
    .backgroundColor($r('app.color.bg_page'))
  }

  private async saveToken(): Promise<void> {
    const trimmed = this.token.trim();
    if (trimmed === '') {
      this.error = this.stringOf($r('app.string.token_error_empty'));
      return;
    }
    this.saving = true;
    try {
      await TokenStore.save(trimmed);
      this.onSaved(trimmed);
    } catch (e) {
      this.error = this.stringOf($r('app.string.token_error_save'));
    } finally {
      this.saving = false;
    }
  }

  /** 资源 → 当前语言的纯文案 */
  private stringOf(res: Resource): string {
    return resText(this.getUIContext(), res);
  }
}
