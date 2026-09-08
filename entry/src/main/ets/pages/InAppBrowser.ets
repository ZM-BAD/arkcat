/**
 * 应用内浏览器页（Spec 059）：About / 页脚外链（GitHub Docs、GitHub 设置）在 App 内打开。
 * ArkWeb 加载外部页面，手机宽度即移动端版式（docs.github.com 响应式）；
 * 自绘 AppBar（返回 + 标题，标题由调用方给：About 行=行文案、页脚链接=Copilot）、
 * 加载中顶部细进度条、滚动出顶部阴影。
 */
import { webview } from '@kit.ArkWeb';
import { OctIcon } from '../components/OctIcon';
import { PageShadowBar } from '../components/PageShadowBar';

@ComponentV2
export struct InAppBrowserView {
  @Param title: string = '';
  @Param url: string = '';
  @Param pathStack: NavPathStack = new NavPathStack();
  @Local loading: boolean = true;
  @Local progress: number = 0;
  @Local scrollShadow: boolean = false;
  private controller: webview.WebviewController = new webview.WebviewController();

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

        Text(this.title)
          .fontSize($r('app.float.title_font_size'))
          .fontWeight(600)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
      }
      .width('100%')
      .height(52)
      .padding({ left: 4, right: 16 })

      if (this.loading) {
        // 加载中：顶部细进度条（替代阴影条，避免两条同时出现）
        Progress({ value: this.progress, total: 100, type: ProgressType.Linear })
          .width('100%')
          .height(2)
          .color($r('app.color.link_blue'))
      } else {
        PageShadowBar({ show: this.scrollShadow })
      }

      Web({ src: this.url, controller: this.controller })
        .width('100%')
        .layoutWeight(1)
        .darkMode(WebDarkMode.Auto)
        .onPageBegin(() => {
          this.loading = true;
          this.progress = 0;
        })
        .onProgressChange((event: OnProgressChangeEvent) => {
          this.progress = event.newProgress;
        })
        .onPageEnd(() => {
          this.loading = false;
        })
        .onScroll((event: OnScrollEvent) => {
          this.scrollShadow = event.yOffset > 1;
        })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_page'))
  }
}
