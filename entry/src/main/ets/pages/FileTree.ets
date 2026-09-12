/**
 * 仓库文件列表页（Spec 038）：Repo Detail → More → 文件行。
 * 目录下钻 push 新路由实例（返回自然回上一级）；点文件进 Spec 011 代码查看器；
 * 搜索图标展开本地过滤（find a file）。头部对齐官方截图：← Files + 🔍 ⭮ ⋮。
 */
import { promptAction } from '@kit.ArkUI';
import { pasteboard } from '@kit.BasicServicesKit';
import { OctIcon } from '../components/OctIcon';
import { PageShadowBar } from '../components/PageShadowBar';
import { DirEntry, DirPage } from '../models/FileModels';
import { FileService } from '../services/FileService';
import { StateView } from '../components/StateView';
import { resText } from '../utils/I18n';
import { repoTreeUrl, shareLink } from '../utils/Share';

const DIR_ENTRY_LIMIT = 500;

@ComponentV2
export struct FileTreeView {
  @Param owner: string = '';
  @Param name: string = '';
  @Param token: string = '';
  @Param pathStack: NavPathStack = new NavPathStack();
  /** 当前目录路径（空 = 根目录），由路由参数 owner|name|path 解析 */
  @Param dirPath: string = '';
  @Local entries: DirEntry[] = [];
  @Local loading: boolean = true;
  @Local errorMsg: string = '';
  @Local filterOn: boolean = false;
  @Local filterText: string = '';
  @Local tooLarge: boolean = false;
  /** 滚动顶部阴影（滚动中显示、回顶消失） */
  @Local scrollShadow: boolean = false;
  @Local isRefreshing: boolean = false;

  aboutToAppear(): void {
    this.refresh();
  }

  private refresh(): void {
    this.loading = true;
    this.errorMsg = '';
    this.tooLarge = false;
    FileService.fetchDir(this.token, this.owner, this.name, this.dirPath)
      .then((page: DirPage) => {
        this.entries = page.entries;
        this.tooLarge = page.entries.length >= DIR_ENTRY_LIMIT;
        this.loading = false;
        this.isRefreshing = false;
        if (this.tooLarge) {
          // 事实性提示（review C14：列表并未截断，「目录过大」与行为不符）
          promptAction.showToast({ message: resText(this.getUIContext(), $r('app.string.file_dir_entry_count'), `${page.entries.length}`) });
        }
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

  /** 目录标题：根目录 = Files；子目录 = 末段目录名 */
  private titleText(): string {
    if (this.dirPath === '') {
      return this.stringOf($r('app.string.file_tree_title'));
    }
    const idx = this.dirPath.lastIndexOf('/');
    return idx >= 0 ? this.dirPath.substring(idx + 1) : this.dirPath;
  }

  private childPath(name: string): string {
    return this.dirPath === '' ? name : `${this.dirPath}/${name}`;
  }

  /** 本目录地址（根目录 = 仓库主页；子目录带 tree/HEAD 路径） */
  private findUrl(): string {
    return repoTreeUrl(this.owner, this.name, this.dirPath);
  }

  /** 复制文本到剪贴板 + toast */
  private copyText(text: string, okRes: Resource): void {
    const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
    pasteboard.getSystemPasteboard().setData(data)
      .then(() => {
        promptAction.showToast({ message: okRes });
      })
      .catch(() => {
        promptAction.showToast({ message: $r('app.string.file_copy_failed') });
      });
  }

  private onEntryClick(entry: DirEntry): void {
    if (entry.type === 'tree') {
      this.pathStack.pushPathByName('repoFiles', `${this.owner}|${this.name}|${this.childPath(entry.name)}`);
    } else if (entry.type === 'blob') {
      this.pathStack.pushPathByName('codeViewer', `${this.owner}|${this.name}|${this.childPath(entry.name)}`);
    } else {
      promptAction.showToast({ message: $r('app.string.file_link_unsupported') });
    }
  }

  /** 更多菜单：Copy link / Copy path |
   * GitHub App 对应「Copy link / Open in browser」（Open 后续评估） */
  private menuItems(): MenuElement[] {
    return [
      { value: this.stringOf($r('app.string.file_copy_link')), action: (): void => {
        this.copyText(this.findUrl(), $r('app.string.file_link_copied'));
      } },
      { value: this.stringOf($r('app.string.file_copy_path')), action: (): void => {
        this.copyText(this.dirPath === '' ? '/' : this.dirPath, $r('app.string.file_link_copied'));
      } }
    ];
  }

  /** 条目行：目录 = 蓝实心文件夹；文件 = 灰文件图标 */
  @Builder
  entryRow(entry: DirEntry) {
    Row({ space: 12 }) {
      OctIcon({
        res: entry.type === 'tree' ? $r('app.media.oct_file_directory_fill_16') : $r('app.media.oct_file_16'),
        iconSize: 20,
        iconColor: entry.type === 'tree' ? $r('app.color.link_blue') : $r('app.color.text_secondary')
      })
      Text(entry.name)
        .fontSize($r('app.float.body_font_size'))
        .fontColor($r('app.color.text_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
    }
    .width('100%')
    .height(48)
    .padding({ left: 16, right: 16 })
    .onClick(() => {
      this.onEntryClick(entry);
    })
  }

  build() {
    Column() {
      // 自绘头部：← 返回 + 标题（Files/目录名）+ 搜索/分享/更多
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
        Text(this.titleText())
          .fontSize($r('app.float.title_font_size'))
          .fontWeight(600)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        OctIcon({ res: $r('app.media.oct_search_24'), iconSize: 20, iconColor: $r('app.color.text_secondary') })
          .margin({ left: 12 })
        .responseRegion({ x: -12, y: -12, width: '220%', height: '220%' })
        .accessibilityDescription($r('app.string.a11y_search'))
        .focusable(true)
          .onClick(() => {
            this.filterOn = !this.filterOn;
            if (!this.filterOn) {
              this.filterText = '';
            }
          })
        OctIcon({ res: $r('app.media.oct_share_android_16'), iconSize: 20, iconColor: $r('app.color.link_blue') })
          .margin({ left: 12 })
        .responseRegion({ x: -12, y: -12, width: '220%', height: '220%' })
        .accessibilityDescription($r('app.string.a11y_share'))
        .focusable(true)
          .onClick(() => {
            const repo = `${this.owner}/${this.name}`;
            shareLink(this.getUIContext(), this.findUrl(),
              this.dirPath === '' ? repo : `${repo}/${this.dirPath}`);
          })
        OctIcon({ res: $r('app.media.oct_kebab_horizontal_16'), iconSize: 20, iconColor: $r('app.color.link_blue') })
          .rotate({ angle: 90 })
          .margin({ left: 12 })
          .responseRegion({ x: -12, y: -12, width: '220%', height: '220%' })
          .accessibilityDescription($r('app.string.a11y_more'))
          .focusable(true)
          .bindMenu(this.menuItems())
      }
      .width('100%')
      .height(60)
      .padding({ left: 0, right: 0 })

      PageShadowBar({ show: this.scrollShadow })

      // 本地过滤行（find a file）
      if (this.filterOn) {
        TextInput({ placeholder: this.stringOf($r('app.string.file_filter_hint')) })
          .height(40)
          .margin({ left: 16, right: 16, bottom: 8 })
          .onChange((value: string) => {
            this.filterText = value;
          })
      }

      Refresh({ refreshing: $$this.isRefreshing }) {
        if (this.loading || this.errorMsg !== '') {
          StateView({ loading: this.loading, error: this.errorMsg, onRetry: (): void => this.refresh() })
        } else if (this.entries.length === 0) {
          StateView({ loading: false, error: '', empty: true, emptyText: $r('app.string.file_empty_dir') })
        } else {
          List() {
            ForEach(this.entries.filter((e: DirEntry): boolean => {
              const q = this.filterText.toLowerCase();
              return q === '' || e.name.toLowerCase().indexOf(q) >= 0;
            }), (entry: DirEntry) => {
              ListItem() {
                this.entryRow(entry)
              }
            }, (entry: DirEntry) => entry.name)
          }
          .width('100%')
          .contentEndOffset(16)
          .onScroll((scrollOffset: number, _state: number): void => { this.scrollShadow = scrollOffset > 0.001; })
        }
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
