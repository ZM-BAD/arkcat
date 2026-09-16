/**
 * PR 文件变更页（Spec 010 + 042）：Files Changed 视图。
 * GraphQL 列表/计数 + REST patch 兜底；文件卡折叠/展开、Find file 过滤、
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
import { friendlyError } from '../services/GitHttpClient';
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
  /** 单 bindSheet 分派（坑 2）：'thread'=行内评论 / 'review'=完成审阅 / 'jump'=跳转文件 */
  @Local sheetKind: string = '';
  @Local threadPath: string = '';
  @Local threadLine: number = 0;
  @Local threadSide: string = 'RIGHT';
  @Local threadBody: string = '';
  @Local threadSending: boolean = false;
  /** Code Options「展示行号」开关 */
  @Local showLineNumbers: boolean = true;
  /** 完成审阅面板（官方 Files changed 绿钮 → 图3 流） */
  @Local reviewEvent: string = 'COMMENT';
  @Local reviewBody: string = '';
  @Local reviewSending: boolean = false;
  private scroller: Scroller = new Scroller();

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
    this.sheetKind = 'thread';
  }

  private closeThreadSheet(): void {
    this.sheetKind = '';
    this.threadBody = '';
  }

  /** 完成审阅（官方 Files changed 绿钮）：三态 + 总结 → submitReview，回详情页看结果 */
  private submitReviewFromFiles(): void {
    if (this.page === null || this.reviewSending || this.page.pullRequestId === '') {
      return;
    }
    // COMMENT 态必须有总结 body（与详情页 reviewSheet 同口径；服务端同样拒空）
    if (this.reviewEvent === 'COMMENT' && this.reviewBody.trim() === '') {
      promptAction.showToast({ message: $r('app.string.pr_review_need_body') });
      return;
    }
    this.reviewSending = true;
    RepoSubService.submitReview(this.token, this.page.pullRequestId, this.reviewEvent, this.reviewBody.trim())
      .then(() => {
        this.reviewSending = false;
        this.sheetKind = '';
        promptAction.showToast({ message: $r('app.string.pr_review_submitted') });
        this.pathStack.pop();
      })
      .catch((e: Error) => {
        this.reviewSending = false;
        promptAction.showToast({ message: friendlyError(this.getUIContext(), e) });
      });
  }

  /** 跳转到文件（图4）：只展开目标文件，滚动定位到其卡片顶部 */
  private jumpToFile(path: string): void {
    this.expandedPaths = [path];
    this.sheetKind = '';
    setTimeout((): void => {
      try {
        const ui = this.getUIContext();
        const target = ui.getComponentUtils().getRectangleById(`file_${path}`);
        const area = ui.getComponentUtils().getRectangleById('pr_files_scroll');
        const y = this.scroller.currentOffset().yOffset + target.windowOffset.y - area.windowOffset.y - 8;
        this.scroller.scrollTo({ xOffset: 0, yOffset: Math.max(0, y) });
      } catch (e) {
        // 度量失败静默：展开目标文件本身已提供定位
      }
    }, 150);
  }

  /** 文件名（去目录前缀） */
  private fileBase(path: string): string {
    const slash = path.lastIndexOf('/');
    return slash >= 0 ? path.substring(slash + 1) : path;
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
        promptAction.showToast({ message: friendlyError(this.getUIContext(), e) });
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
        Scroll(this.scroller) {
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
                    .id(`file_${item.path}`)
                }, (item: PrFileItem) => item.path)
              }
            }
          }
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 16 })
        }
        .id('pr_files_scroll')
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

      // 右下悬浮操作钮（官方 Files changed 图3：绿 FINISH YOUR REVIEW + 黑跳转文件）
      Row({ space: 10 }) {
        Blank()
        Row({ space: 6 }) {
          OctIcon({ res: $r('app.media.oct_code_review_16'), iconSize: 16, iconColor: Color.White })
          Text($r('app.string.pr_files_finish_review'))
            .fontSize($r('app.float.body_font_size'))
            .fontWeight(FontWeight.Medium)
            .fontColor(Color.White)
            .textCase(TextCase.UpperCase)
          OctIcon({ res: $r('app.media.oct_chevron_down_16'), iconSize: 14, iconColor: Color.White })
        }
        .height(46)
        .padding({ left: 18, right: 12 })
        .borderRadius(10)
        .backgroundColor($r('app.color.success_btn_bg'))
        .shadow({ radius: 12, color: $r('app.color.shadow_floating'), offsetY: 4 })
        .onClick((): void => {
          this.reviewEvent = 'COMMENT';
          this.reviewBody = '';
          this.sheetKind = 'review';
        })
        Stack() {
          OctIcon({ res: $r('app.media.oct_file_symlink_file_16'), iconSize: 18, iconColor: Color.White })
        }
        .width(46)
        .height(46)
        .borderRadius(10)
        .backgroundColor($r('app.color.floating_btn_bg'))
        .shadow({ radius: 12, color: $r('app.color.shadow_floating'), offsetY: 4 })
        .accessibilityDescription($r('app.string.pr_files_jump'))
        .onClick((): void => {
          this.sheetKind = 'jump';
        })
      }
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 12 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_page'))
    .bindSheet(this.sheetKind !== '', this.filesSheet(), {
      height: this.sheetKind === 'jump' ? 520 : (this.sheetKind === 'review' ? 480 : 420),
      detents: [this.sheetKind === 'jump' ? 520 : (this.sheetKind === 'review' ? 480 : 420), SheetSize.LARGE],
      showClose: false,
      backgroundColor: $r('app.color.bg_page'),
      dragBar: true,
      onDisappear: (): void => this.closeThreadSheet()
    })
  }

  /** 弹层分派（坑 2：单 bindSheet + sheetKind） */
  @Builder
  filesSheet() {
    if (this.sheetKind === 'thread') {
      this.threadSheet()
    } else if (this.sheetKind === 'review') {
      this.reviewSheetFiles()
    } else if (this.sheetKind === 'jump') {
      this.jumpSheet()
    }
  }

  /** 三态单选行（与 PrDetail 审阅面板同款） */
  @Builder
  reviewOption(labelRes: Resource, value: string, colorFg: ResourceColor) {
    Row({ space: 10 }) {
      Stack() {
        Circle()
          .width(18)
          .height(18)
          .fill(Color.Transparent)
          .stroke(this.reviewEvent === value ? $r('app.color.link_blue') : $r('app.color.border'))
          .strokeWidth(1.5)
        if (this.reviewEvent === value) {
          Circle()
            .width(10)
            .height(10)
            .fill($r('app.color.link_blue'))
        }
      }
      Text(labelRes)
        .fontSize($r('app.float.body_font_size'))
        .fontColor(this.reviewEvent === value ? $r('app.color.text_primary') : colorFg)
    }
    .width('100%')
    .height(44)
    .onClick((): void => {
      this.reviewEvent = value;
    })
  }

  /** 完成审阅面板（官方 Files changed 绿钮 → 三态 + 总结 → submitReview） */
  @Builder
  reviewSheetFiles() {
    Column({ space: 10 }) {
      Text($r('app.string.pr_review_changes'))
        .fontSize($r('app.float.sub_text_font_size'))
        .fontWeight(600)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
      this.reviewOption($r('app.string.pr_review_type_comment'), 'COMMENT', $r('app.color.text_primary'))
      this.reviewOption($r('app.string.pr_review_type_approve'), 'APPROVE', $r('app.color.success_text'))
      this.reviewOption($r('app.string.pr_review_type_request'), 'REQUEST_CHANGES', $r('app.color.danger_text'))
      Divider().color($r('app.color.divider'))
      TextArea({
        text: this.reviewBody,
        placeholder: this.stringOf($r('app.string.pr_review_summary_hint'))
      })
        .fontSize($r('app.float.body_font_size'))
        .height(120)
        .borderRadius(6)
        .backgroundColor($r('app.color.input_bg'))
        .onChange((v: string): void => {
          this.reviewBody = v;
        })
      Button($r('app.string.pr_review_submit'))
        .type(ButtonType.Normal)
        .width('100%')
        .height(44)
        .fontSize($r('app.float.body_font_size'))
        .fontColor(Color.White)
        .backgroundColor($r('app.color.link_blue'))
        .enabled(!this.reviewSending && (this.reviewEvent !== 'COMMENT' || this.reviewBody.trim() !== ''))
        .onClick((): void => this.submitReviewFromFiles())
    }
    .width('100%')
  }

  /** 跳转到文件面板（图4：X + 标题；行=类型图标+文件名+路径+增删行数） */
  @Builder
  jumpSheet() {
    Column() {
      Row({ space: 10 }) {
        Stack() {
          OctIcon({ res: $r('app.media.oct_x_16'), iconSize: 20, iconColor: $r('app.color.text_secondary') })
        }
        .width(44)
        .height(44)
        .padding(6)
        .accessibilityDescription($r('app.string.a11y_close'))
        .focusable(true)
        .onClick((): void => {
          this.sheetKind = '';
        })
        Text($r('app.string.pr_files_jump'))
          .fontSize($r('app.float.title_font_size'))
          .fontWeight(600)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
      }
      .width('100%')
      Scroll() {
        Column() {
          ForEach(this.files, (item: PrFileItem) => {
            Row({ space: 10 }) {
              OctIcon({ res: $r('app.media.oct_file_code_16'), iconSize: 18, iconColor: $r('app.color.warning_text') })
              Column({ space: 2 }) {
                Text(this.fileBase(item.path))
                  .fontSize($r('app.float.body_font_size'))
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.text_primary'))
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .width('100%')
                Text(item.path)
                  .fontSize($r('app.float.caption_font_size'))
                  .fontColor($r('app.color.text_secondary'))
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .width('100%')
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              Text() {
                Span(`+${item.additions}`).fontColor($r('app.color.success_text'))
                Span(` -${item.deletions}`).fontColor($r('app.color.danger_text'))
              }
              .fontSize($r('app.float.caption_font_size'))
            }
            .width('100%')
            .padding({ left: 12, right: 16, top: 10, bottom: 10 })
            .onClick((): void => this.jumpToFile(item.path))
          }, (item: PrFileItem) => item.path)
        }
        .width('100%')
      }
      .scrollBar(BarState.Off)
      .layoutWeight(1)
      .align(Alignment.Top)
    }
    .width('100%')
    .height('100%')
    .padding({ left: 4, right: 4 })
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
