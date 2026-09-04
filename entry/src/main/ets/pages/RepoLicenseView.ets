/**
 * License 正文页（Spec 055）：仓库名灰小字 + License 黑粗体大字（层级与列表页相反，对照截图），
 * 正文 = licenseInfo.body 全文（首行许可证名已剥离）；无许可证 → 空态。
 */
import { OctIcon } from '../components/OctIcon';
import { LicenseInfo, stripLicenseTitle } from '../models/RepoLicenseModels';
import { RepoService } from '../services/RepoService';
import { StateView } from '../components/StateView';
import { resText } from '../utils/I18n';

@ComponentV2
export struct RepoLicenseView {
  @Param owner: string = '';
  @Param name: string = '';
  @Param token: string = '';
  @Param pathStack: NavPathStack = new NavPathStack();
  @Local license: LicenseInfo | null = null;
  @Local loading: boolean = true;
  @Local errorMsg: string = '';

  aboutToAppear(): void {
    this.refresh();
  }

  private refresh(): void {
    if (this.owner === '' || this.name === '') {
      return;
    }
    this.loading = true;
    this.errorMsg = '';
    RepoService.fetchLicense(this.token, this.owner, this.name)
      .then((info: LicenseInfo | null) => {
        this.license = info;
        this.loading = false;
      })
      .catch((e: Error) => {
        this.errorMsg = e.message;
        this.loading = false;
      });
  }

  private stringOf(res: Resource): string {
    return resText(this.getUIContext(), res);
  }

  build() {
    Column() {
      // 自绘头部：返回 + 仓库名（灰小字·上）+ License（黑粗体大字·下）
      Row({ space: 8 }) {
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
          Text(this.name)
            .fontSize($r('app.float.body_font_size'))
            .fontColor($r('app.color.text_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.stringOf($r('app.string.repo_license')))
            .fontSize($r('app.float.title_font_size'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Blank()
      }
      .width('100%')
      .height(60)
      .padding({ left: 0, right: 0 })

      if (this.license !== null) {
        Scroll() {
          Text(stripLicenseTitle(this.license.name, this.license.body))
            .fontSize($r('app.float.body_font_size'))
            .fontColor($r('app.color.text_primary'))
            .lineHeight(25)
            .width('100%')
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .align(Alignment.Top)
        .padding({ left: 16, right: 16 })
      } else {
        StateView({
          loading: this.loading,
          error: this.errorMsg,
          onRetry: () => this.refresh()
        })
        if (!this.loading && this.errorMsg === '') {
          Column() {
            Text(this.stringOf($r('app.string.repo_license_none')))
              .fontSize($r('app.float.body_font_size'))
              .fontColor($r('app.color.text_secondary'))
          }
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_page'))
  }
}
