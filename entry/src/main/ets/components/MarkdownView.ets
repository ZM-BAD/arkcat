/**
 * Markdown 渲染组件（Spec 040）：ArkWeb + 官方 HTML（bodyHTML / readme html / /markdown 渲染结果）。
 * 交互：站内链接 → onNavigate 路由回调；外链 → 系统浏览器；代码块复制（native 桥）；
 * 超长折叠（>foldThreshold 默认 4000 字符）；暗黑自适应（body class 双主题 CSS 变量）。
 * 降级：html 为空时展示 fallbackText 纯文本。
 */
import { webview } from '@kit.ArkWeb';
import { common } from '@kit.AbilityKit';
import { mediaquery, promptAction } from '@kit.ArkUI';
import { preferences } from '@kit.ArkData';
import { pasteboard } from '@kit.BasicServicesKit';
import { resText } from '../utils/I18n';
import { MarkdownRoute, MarkdownService } from '../services/MarkdownService';
import { buildCopyJs, buildMarkdownDoc, buildMeasureJs, buildSetOverflowJs, buildSetThemeJs } from '../utils/MarkdownHtml';

const PREFS_NAME = 'starraft_settings';
const KEY_THEME = 'theme_mode';
const COLLAPSE_HEIGHT = 640;

/** 复制 toast 文案（模块级：javaScriptProxy 对象只允许方法，不允许字段） */
let copyToastLabel = 'Copied';

/** javaScriptProxy 桥：仅暴露 copyCode（方法，无字段） */
class MarkdownBridge {
  copyCode(code: string): void {
    const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, code);
    pasteboard.getSystemPasteboard().setDataSync(data);
    promptAction.showToast({ message: copyToastLabel });
  }
}

@ComponentV2
export struct MarkdownView {
  /** 官方 HTML（bodyHTML / REST html），变化时自动重载 */
  @Require @Param html: string = '';
  /** 降级纯文本（bodyText / readme 原文），html 为空时展示 */
  @Param fallbackText: string = '';
  /** 超长折叠阈值（字符数；>0 生效） */
  @Param foldThreshold: number = 4000;
  /** 降级态是否显示重试（调用方数据拉取失败时置 true，配 onRetry 重新拉取） */
  @Param showRetry: boolean = false;
  /** 站内链接点击：name/param 对应 Index.ets destinationMap */
  @Event onNavigate: (name: string, param: string) => void = (name: string, param: string): void => { };
  /** 降级态重试按钮回调 */
  @Event onRetry: () => void = (): void => { };
  @Local dark: boolean = false;
  @Local loading: boolean = true;
  @Local collapsed: boolean = true;
  @Local webHeight: number = COLLAPSE_HEIGHT;
  @Local contentHeight: number = 0;

  private controller: webview.WebviewController = new webview.WebviewController();
  private bridge: MarkdownBridge = new MarkdownBridge();
  private attached: boolean = false;

  aboutToAppear(): void {
    const ui = this.getUIContext();
    this.resolveDark();
    copyToastLabel = resText(ui, $r('app.string.md_copied'));
    this.collapsed = MarkdownService.shouldCollapse(this.html.length, this.foldThreshold);
    if (this.html === '') {
      this.loading = false;
    }
  }

  /** @Param html 更新（异步数据后到）→ 重载文档 */
  @Monitor('html')
  onHtmlChanged(): void {
    this.collapsed = MarkdownService.shouldCollapse(this.html.length, this.foldThreshold);
    if (this.attached) {
      this.reload();
    }
  }

  private reload(): void {
    if (!this.attached || this.html === '') {
      this.loading = this.html !== '';
      return;
    }
    this.loading = true;
    try {
      this.controller.loadData(buildMarkdownDoc(this.html, this.dark), 'text/html', 'UTF-8', 'https://github.com/');
    } catch (e) {
      this.loading = false;
    }
  }

  /** onPageEnd：注入复制按钮、校准主题 class、测量内容高度（折叠/展开决策） */
  private decorate(): void {
    const ui = this.getUIContext();
    this.controller.runJavaScript(buildCopyJs(resText(ui, $r('app.string.md_copy'))))
      .catch(() => {
      });
    this.controller.runJavaScript(buildSetThemeJs(this.dark))
      .catch(() => {
      });
    this.controller.runJavaScript(buildSetOverflowJs(this.collapsed))
      .catch(() => {
      });
    this.controller.runJavaScript(buildMeasureJs())
      .then((v: string) => {
        const px = Number(v);
        if (Number.isNaN(px)) {
          return;
        }
        const vp = Math.max(this.getUIContext().px2vp(px), 1);
        this.contentHeight = vp;
        if (vp <= COLLAPSE_HEIGHT) {
          this.collapsed = false;
        }
        this.webHeight = this.collapsed ? COLLAPSE_HEIGHT : vp;
        this.controller.runJavaScript(buildSetOverflowJs(this.collapsed))
          .catch(() => {
          });
      })
      .catch(() => {
      });
  }

  /** 链接导航拦截：站内 → 路由；外链 http(s) → 系统浏览器；其余放行 */
  private handleIntercept(event: OnLoadInterceptEvent): boolean {
    if (!event.data.isMainFrame()) {
      return false;
    }
    const url = event.data.getRequestUrl();
    if (url === '' || url === 'about:blank') {
      return false;
    }
    const route: MarkdownRoute | null = MarkdownService.routeOf(url);
    if (route !== null) {
      this.onNavigate(route.name, route.param);
      return true;
    }
    if (url.startsWith('http://') || url.startsWith('https://')) {
      this.openExternal(url);
      return true;
    }
    return false;
  }

  private openExternal(url: string): void {
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

  /** 主题判定：偏好 dark/light 优先；system 跟随系统深色（进组件后异步刷新 @Local dark） */
  private resolveDark(): void {
    const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    if (ctx === undefined) {
      return;
    }
    preferences.getPreferences(ctx, PREFS_NAME)
      .then((pref: preferences.Preferences) => {
        const mode = pref.getSync(KEY_THEME, 'system') as string;
        if (mode === 'dark') {
          this.dark = true;
        } else if (mode === 'light') {
          this.dark = false;
        } else {
          this.dark = MarkdownView.systemDark();
        }
      })
      .catch(() => {
        this.dark = MarkdownView.systemDark();
      });
  }

  private static systemDark(): boolean {
    try {
      const mq = mediaquery.matchMediaSync('(prefers-color-scheme: dark)');
      return mq.matches;
    } catch (e) {
      return false;
    }
  }

  @Builder
  fallbackBlock() {
    Column({ space: 10 }) {
      if (this.fallbackText !== '') {
        Text(this.fallbackText)
          .fontSize($r('app.float.body_font_size'))
          .fontColor($r('app.color.text_secondary'))
          .lineHeight(20)
          .width('100%')
      }
      if (this.showRetry) {
        Text(resText(this.getUIContext(), $r('app.string.state_retry')))
          .fontSize($r('app.float.body_font_size'))
          .fontColor($r('app.color.link_blue'))
          .padding({ top: 8, bottom: 8, left: 12, right: 12 })
          .onClick(() => this.onRetry())
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  expandOverlay() {
    Column({ space: 8 }) {
      Blank()
      Row() {
        Text(resText(this.getUIContext(), $r('app.string.md_expand_all')))
          .fontSize($r('app.float.body_font_size'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
      }
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })
      .borderRadius(12)
      .backgroundColor($r('app.color.card_background'))
      .borderWidth(1)
      .borderColor($r('app.color.divider'))
      .shadow({ radius: 8, color: $r('app.color.shadow_floating'), offsetY: 2 })
      .onClick(() => {
        this.collapsed = false;
        this.webHeight = this.contentHeight;
      })
    }
    .width('100%')
    .height(this.webHeight)
    .alignItems(HorizontalAlign.Center)
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      if (this.html === '') {
        this.fallbackBlock()
      } else {
        Web({ src: 'about:blank', controller: this.controller })
          .width('100%')
          .height(this.webHeight)
          .darkMode(WebDarkMode.Off)
          .javaScriptProxy({
            object: this.bridge,
            name: 'starraftBridge',
            methodList: ['copyCode'],
            controller: this.controller
          })
          .onControllerAttached(() => {
            // 引擎就绪前立即 loadData 会被丢弃（实测需延迟）；html 更新走 @Monitor 直 reload
            this.attached = true;
            setTimeout(() => {
              this.reload();
            }, 300);
          })
          .onPageBegin(() => {
            this.loading = true;
          })
          .onPageEnd(() => {
            this.loading = false;
            this.decorate();
          })
          .onLoadIntercept((event: OnLoadInterceptEvent) => this.handleIntercept(event))
        if (this.collapsed && this.contentHeight > COLLAPSE_HEIGHT) {
          this.expandOverlay()
        }
      }
      if (this.loading && this.html !== '') {
        Column() {
          LoadingProgress()
            .width(28)
            .height(28)
            .color($r('app.color.link_blue'))
        }
        .width('100%')
        .height(this.webHeight)
        .justifyContent(FlexAlign.Center)
      }
    }
    .width('100%')
  }
}
