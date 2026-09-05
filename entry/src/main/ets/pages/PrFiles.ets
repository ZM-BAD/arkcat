/**
 * PR 文件变更页（Spec 010）：Files Changed 视图。
 * GraphQL 列表/计数 + REST patch 兜底；文件卡折叠/展开、Find file 过滤、底部 Add a comment（GraphQL addComment）。
 * 入口：PrDetail Changes 卡「N files changed」行；行内评论/图片 diff 属 042/后续批。
 */
import { promptAction } from '@kit.ArkUI';
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { OctIcon } from '../components/OctIcon';
import { StateView } from '../components/StateView';
import { PageShadowBar } from '../components/PageShadowBar';
import { PrDiffCard } from '../components/PrDiffCard';
import { PrFileItem, PrFilesPage } from '../models/PrDiffModels';
import { RepoSubService } from '../services/RepoSubService';
import { resText } from '../utils/I18n';

const PREFS_NAME = 'starraft_settings';
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
  @Local finderOpen: boolean = false;
  @Local finderQuery: string = '';
  @Local commentText: string = '';
  @Local sending: boolean = false;
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
      })
      .catch((e: Error) => {
        this.errorMsg = e.message;
        this.loading = false;
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

  /** Find file 过滤（大小写不敏感子串） */
  private filteredFiles(): PrFileItem[] {
    if (this.finderQuery === '') {
      return this.files;
    }
    const q = this.finderQuery.toUpperCase();
    return this.files.filter((f: PrFileItem): boolean => f.path.toUpperCase().indexOf(q) >= 0);
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

  /** Find file 弹层：搜索框 + 匹配文件列表（点击=展开该文件并关闭） */
  @Builder
  finderSheet() {
    Column() {
      Row({ space: 8 }) {
        Text(this.stringOf($r('app.string.pr_find_file')))
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
        Text('✕')
          .fontSize(18)
          .fontColor($r('app.color.text_secondary'))
          .padding(8)
          .accessibilityDescription($r('app.string.a11y_close'))
          .focusable(true)
          .onClick(() => {
            this.finderOpen = false;
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 10, bottom: 6 })

      TextInput({ text: this.finderQuery, placeholder: this.stringOf($r('app.string.search_placeholder')) })
        .fontSize($r('app.float.body_font_size'))
        .height(40)
        .borderRadius(6)
        .backgroundColor($r('app.color.input_bg'))
        .margin({ left: 16, right: 16, bottom: 6 })
        .onChange((v: string) => {
          this.finderQuery = v;
        })

      List() {
        ForEach(this.filteredFiles(), (item: PrFileItem) => {
          ListItem() {
            Row({ space: 8 }) {
              OctIcon({ res: $r('app.media.oct_file_16'), iconSize: 14, iconColor: $r('app.color.text_secondary') })
              Text(item.path)
                .fontFamily('monospace')
                .fontSize(12)
                .fontColor($r('app.color.text_primary'))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .layoutWeight(1)
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 10, bottom: 10 })
            .onClick(() => {
              this.finderOpen = false;
              this.togglePath(item.path);
            })
          }
        }, (item: PrFileItem) => item.path)
      }
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_page'))
  }

  build() {
    Column() {
      // 自绘头部：← 标题 + ···（Find file）
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
        Column({ space: 0 }) {
          Text(this.page !== null
            ? this.stringOf($r('app.string.pr_files_appbar'))
            : this.stringOf($r('app.string.pr_changes_title')))
            .fontSize($r('app.float.title_font_size'))
            .fontWeight(FontWeight.Bold)
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
          OctIcon({ res: $r('app.media.oct_gear_16'), iconSize: 18, iconColor: $r('app.color.link_blue') })
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
      .padding({ left: 0, right: 0 })

      PageShadowBar({ show: this.scrollShadow })

      if (this.loading || this.errorMsg !== '') {
        StateView({ loading: this.loading, error: this.errorMsg, onRetry: (): void => { this.refresh(); } })
          .layoutWeight(1)
      } else {
        Scroll() {
          Column() {
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
                  onOpenFile: (): void => this.openFile(item)
                })
              }, (item: PrFileItem) => item.path)
            }
          }
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 16 })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .align(Alignment.Top)
        .onScroll((_x: number, y: number): void => {
          this.scrollShadow = y > 0.001;
        })
      }

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
    .bindSheet(this.finderOpen, this.finderSheet(), { showClose: false })
  }
}
