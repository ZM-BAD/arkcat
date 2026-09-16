/**
 * PR 文件变更页（Spec 010 + 042）：Files Changed 视图。
 * GraphQL 列表/计数 + REST patch 兜底；文件卡折叠/展开、Find file 过滤、底部 Add a comment（GraphQL addComment）、
 * 点击 diff 行弹行内评论（addPullRequestReviewThread）。
 * 入口：PrDetail Changes 卡「N files changed」行。
 */
import { promptAction } from '@kit.ArkUI';
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { OctIcon } from '../components/OctIcon';
import { StateView } from '../components/StateView';
import { PageShadowBar } from '../components/PageShadowBar';
import { PrDiffCard } from '../components/PrDiffCard';
import { PrFileItem, PrFilesPage } from '../models/PrDiffModels';
import { DiffLine } from '../utils/Diff';
import { RepoSubService } from '../services/RepoSubService';
import { resText } from '../utils/I18n';

const PREFS_NAME = 'arkcat_settings';
const KEY_LINE_NUMBERS = 'code_line_numbers';

@ComponentV2
export struct PrFilesView {
  @Param owner: string = '';
  @Param name: string = '';
  @Param number: number = 0;
  @Param token: string = '';
  @Param pathStack: NavPathStack = new NavPathStack();
  /** 路由 onShown 递增：从 Code Options 返回时重读设置 */
  @Param refreshTick: number = 0;
  @Local page: PrFilesPage | null = null;
  @Local files: PrFileItem[] = [];
  /** 展开文件路径集合（独立于数据，父状态变化 → 子组件 @Param 重新求值） */
  @Local expandedPaths: string[] = [];
  @Local loading: boolean = true;
  @Local errorMsg: string = '';
  /** 滚动顶部阴影（滚动中显示、回顶消失） */
  @Local scrollShadow: boolean = false;
  @Local isRefreshing: boolean = false;
  @Local commentText: string = '';
  @Local sending: boolean = false;
  /** 行内评论面板（Spec 042 元素1：diff 行 → review thread） */
  @Local threadSheetOpen: boolean = false;
  @Local threadPath: string = '';
  @Local threadLine: number = 0;
  @Local threadSide: string = 'RIGHT';
  @Local threadBody: string = '';
  @Local threadSending: boolean = false;
  /** Code Options「展示行号」开关 */
  @Local showLineNumbers: boolean = true;

  aboutToAppear(): void {
    this.loadLineSetting();
    this.refresh();
  }

  /** 设置页返回（onShown tick）→ 重读本页设置 */
  @Monitor('refreshTick')
  onTick(): void {
    this.loadLineSetting();
  }

  private loadLineSetting(): void {
    const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    if (ctx === undefined) {
      return;
    }
    preferences.getPreferences(ctx, PREFS_NAME)
      .then((pref: preferences.Preferences) => {
        this.showLineNumbers = pref.getSync(KEY_LINE_NUMBERS, true) as boolean;
      })
      .catch(() => {
      });
  }

  private stringOf(res: Resource): string {
    return resText(this.getUIContext(), res);
  }

  private refresh(): void {
    this.loading = true;
    this.errorMsg = '';
    RepoSubService.fetchPrFiles(this.token, this.owner, this.name, this.number)
      .then((page: PrFilesPage) => {
        this.page = page;
        this.files = page.files;
        this.loading = false;
        this.isRefreshing = false;
      })
      .catch((e: Error) => {
        this.errorMsg = e.message;
        this.loading = false;
        this.isRefreshing = false;
      });
  }

  /** 展开/收起：维护路径集合（数组重建触发 @Local 刷新；真实展开态由子卡 @Param 计算） */
  private togglePath(path: string): void {
    const idx = this.expandedPaths.indexOf(path);
    this.expandedPaths = idx >= 0
      ? this.expandedPaths.filter((p: string): boolean => p !== path)
      : this.expandedPaths.concat(path);
  }

  /** 强制设置文件展开/收起（勾选框 reviewed 切换用） */
  private setExpanded(path: string, expanded: boolean): void {
    const idx = this.expandedPaths.indexOf(path);
    if (expanded && idx < 0) {
      this.expandedPaths = this.expandedPaths.concat(path);
    } else if (!expanded && idx >= 0) {
      this.expandedPaths = this.expandedPaths.filter((p: string): boolean => p !== path);
    }
  }

  /** 👁 查看完整文件：复用 038 代码查看器（owner|name|path 路由参数） */
  private openFile(item: PrFileItem): void {
    this.pathStack.pushPathByName('codeViewer', `${this.owner}|${this.name}|${item.path}`);
  }

  /** 底部 Add a comment：GraphQL addComment（041 统一输入面板前的最小实现） */
  private sendComment(): void {
    const body = this.commentText.trim();
    if (body === '' || this.sending || this.page === null || this.page.pullRequestId === '') {
      return;
    }
    this.sending = true;
    RepoSubService.addComment(this.token, this.page.pullRequestId, body)
      .then(() => {
        this.commentText = '';
        this.sending = false;
        promptAction.showToast({ message: $r('app.string.pr_comment_sent') });
      })
      .catch(() => {
        this.sending = false;
        promptAction.showToast({ message: $r('app.string.pr_comment_failed') });
      });
  }

  /** diff 行点击 → 换算 thread 定位（del=LEFT+旧行号，其余 RIGHT+新行号；行号无效忽略）并弹输入 */
  private openThreadSheet(path: string, line: DiffLine): void {
    const lineNo = line.kind === 'del' ? line.oldLine : line.newLine;
    if (lineNo <= 0) {
      return;
    }
    this.threadPath = path;
    this.threadLine = lineNo;
    this.threadSide = line.kind === 'del' ? 'LEFT' : 'RIGHT';
    this.threadBody = '';
    this.threadSheetOpen = true;
  }

  private closeThreadSheet(): void {
    this.threadSheetOpen = false;
    this.threadBody = '';
  }

  /** 提交行内 thread（addPullRequestReviewThread；成功后回 PrDetail 会话区可见） */
  private sendThread(): void {
    const body = this.threadBody.trim();
    if (body === '' || this.threadSending || this.page === null || this.page.pullRequestId === '') {
      return;
    }
    this.threadSending = true;
    RepoSubService.addReviewThread(this.token, this.page.pullRequestId, body,
      this.threadPath, this.threadLine, this.threadSide)
      .then(() => {
        this.threadSending = false;
        this.closeThreadSheet();
        promptAction.showToast({ message: $r('app.string.pr_thread_created') });
      })
      .catch((e: Error) => {
        this.threadSending = false;
        promptAction.showToast({ message: e.message });
      });
  }

  build() {
    Column() {
      // 自绘头部：← 标题 + ···（Find file）
      Row() {
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
        Column({ space: 0 }) {
          Text(this.page !== null
            ? this.stringOf($r('app.string.pr_files_appbar'))
            : this.stringOf($r('app.string.pr_changes_title')))
            .fontSize($r('app.float.title_font_size'))
            .fontWeight(600)
            .fontColor($r('app.color.text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          if (this.page !== null) {
            Text() {
              Span(`+${this.page.additions}`)
                .fontColor($r('app.color.success_text'))
              Span(` -${this.page.deletions}`)
                .fontColor($r('app.color.danger_text'))
            }
            .fontSize($r('app.float.caption_font_size'))
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Stack() {
          OctIcon({ res: $r('app.media.oct_gear_16'), iconSize: 20, iconColor: $r('app.color.link_blue') })
        }
        .width(44)
        .height(44)
        .padding(6)
        .accessibilityDescription($r('app.string.a11y_settings'))
        .focusable(true)
        .onClick(() => {
          this.pathStack.pushPathByName('codeOptions', '');
        })
      }
      .width('100%')
      .height(48)
      .padding({ left: 4, right: 4 })

      PageShadowBar({ show: this.scrollShadow })

      Refresh({ refreshing: $$this.isRefreshing }) {
        Scroll() {
          Column() {
            if (this.loading || this.errorMsg !== '') {
              StateView({ loading: this.loading, error: this.errorMsg, onRetry: (): void => { this.refresh(); } })
            } else {
              if (this.files.length === 0) {
                Text($r('app.string.pr_files_empty'))
                  .fontSize($r('app.float.body_font_size'))
                  .fontColor($r('app.color.text_secondary'))
                  .width('100%')
                  .padding({ top: 48 })
                  .textAlign(TextAlign.Center)
              } else {
                Text($r('app.string.pr_changes_from_all_commits'))
                  .fontSize($r('app.float.caption_font_size'))
                  .fontColor($r('app.color.text_secondary'))
                  .width('100%')
                  .padding({ left: 16, top: 10, bottom: 8 })
                ForEach(this.files, (item: PrFileItem) => {
                  PrDiffCard({
                    item: item,
                    expanded: this.expandedPaths.indexOf(item.path) >= 0,
                    showLineNumbers: this.showLineNumbers,
                    onToggle: (): void => this.togglePath(item.path),
                    onSetExpanded: (expanded: boolean): void => this.setExpanded(item.path, expanded),
                    onOpenFile: (): void => this.openFile(item),
                    onLineTap: (line: DiffLine): void => this.openThreadSheet(item.path, line)
                  })
                }, (item: PrFileItem) => item.path)
              }
            }
          }
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 16 })
        }
        .scrollBar(BarState.Off)
        .align(Alignment.Top)
        .onScroll((_x: number, y: number): void => {
          this.scrollShadow = y > 0.001;
        })
      }
      .layoutWeight(1)
      .onRefreshing((): void => {
        this.isRefreshing = true;
        this.refresh();
      })

      // 底部 Add a comment（全局评论，写操作最小实现）
      Row({ space: 10 }) {
        TextInput({ text: this.commentText, placeholder: this.stringOf($r('app.string.pr_comment_hint')) })
          .fontSize($r('app.float.body_font_size'))
          .height(40)
          .borderRadius(6)
          .backgroundColor($r('app.color.input_bg'))
          .layoutWeight(1)
          .onChange((v: string) => {
            this.commentText = v;
          })
          .onSubmit(() => {
            this.sendComment();
          })
        Stack() {
          OctIcon({ res: $r('app.media.oct_paper_airplane_16'), iconSize: 18,
            iconColor: $r('app.color.link_blue') })
        }
        .width(40)
        .responseRegion({ x: -2, y: -2, width: '110%', height: '110%' })
        .height(40)
        .accessibilityDescription($r('app.string.a11y_send'))
        .focusable(true)
        .onClick(() => {
          this.sendComment();
        })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 8, bottom: 12 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_page'))
    .bindSheet($$this.threadSheetOpen, this.threadSheet(), {
      height: 420,
      showClose: false,
      backgroundColor: $r('app.color.bg_page'),
      dragBar: false,
      onDisappear: (): void => this.closeThreadSheet()
    })
  }

  /** 行内评论输入面板（Spec 042 元素1/2：path:line 上下文 + body → thread） */
  @Builder
  threadSheet() {
    Column({ space: 10 }) {
      Text(this.threadLine > 0 ? `${this.threadPath}:${this.threadLine}` : this.threadPath)
        .fontFamily('monospace')
        .fontSize($r('app.float.caption_font_size'))
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      TextArea({
        text: this.threadBody,
        placeholder: this.stringOf($r('app.string.pr_comment_hint'))
      })
        .fontSize($r('app.float.body_font_size'))
        .height(160)
        .borderRadius(6)
        .backgroundColor($r('app.color.input_bg'))
        .onChange((v: string): void => {
          this.threadBody = v;
        })
      Button($r('app.string.comment_button'))
        .type(ButtonType.Normal)
        .width('100%')
        .height(44)
        .borderRadius(6)
        .backgroundColor($r('app.color.link_blue'))
        .enabled(!this.threadSending && this.threadBody.trim() !== '')
        .onClick((): void => this.sendThread())
    }
    .width('100%')
    .height('100%')
    .padding({ left: 16, right: 16, top: 16, bottom: 16 })
  }
}
