/**
 * License 正文页（Spec 055）：仓库名灰小字 + License 黑粗体大字（层级与列表页相反，对照截图），
 * 正文 = licenseInfo.body 全文（首行许可证名已剥离）；无许可证 → 空态。
 */
import { AppBar } from '../components/AppBar';
import { PageShadowBar } from '../components/PageShadowBar';
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
  /** 滚动顶部阴影（滚动中显示、回顶消失） */
  @Local scrollShadow: boolean = false;
  @Local isRefreshing: boolean = false;

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
        this.isRefreshing = false;
      })
      .catch((e: Error) => {
        this.errorMsg = e.message;
        this.loading = false;
        this.isRefreshing = false;
      });
  }

  private stringOf(res: Resource): string {
    return resText(this.getUIContext(), res);
  }

  build() {
    Column() {
      // 两行头部：仓库名（灰小字·上）+ License（黑粗体大字·下）→ subtitleAbove
      AppBar({
        showBack: true,
        title: this.stringOf($r('app.string.repo_license')),
        subtitle: this.name,
        subtitleAbove: true,
        onBack: (): void => {
          this.pathStack.pop();
        }
      })

      PageShadowBar({ show: this.scrollShadow })

      Refresh({ refreshing: $$this.isRefreshing }) {
        Scroll() {
          if (this.license !== null) {
            Text(stripLicenseTitle(this.license.name, this.license.body))
              .fontSize($r('app.float.body_font_size'))
              .fontColor($r('app.color.text_primary'))
              .lineHeight(25)
              .width('100%')
          } else {
            Column() {
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
                .width('100%')
                .padding({ top: 24 })
              }
            }
            .width('100%')
          }
        }
        .scrollBar(BarState.Off)
        .align(Alignment.Top)
        .padding({ left: 16, right: 16 })
        .onScroll((_x: number, y: number): void => { this.scrollShadow = y > 0.001; })
      }
      .layoutWeight(1)
      .onRefreshing((): void => {
        this.isRefreshing = true;
        this.refresh();
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_page'))
  }
}
