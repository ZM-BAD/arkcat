/**
 * Choose a repository 选仓库页（Spec 043，官方截图驱动 2026-09-19）：
 * Home「+」→ Create Issue 的第一跳——整页仓库候选（owner 头像 + login 灰字 + 仓库名两行行），
 * 右上 🔍 进入顶栏内联搜索（客户端过滤 owner/name）。选中仓库 → 压栈 Create Issue 表单。
 */
import { promptAction } from '@kit.ArkUI';
import { OctIcon } from '../components/OctIcon';
import { PageShadowBar } from '../components/PageShadowBar';
import { StateView } from '../components/StateView';
import { RepoSubService } from '../services/RepoSubService';
import { friendlyError } from '../services/GitHttpClient';
import { PickerRepo, RepoFormPage, IssueTemplateExtras, pickerRepoFullName } from '../models/RepoSubModels';
import { resText } from '../utils/I18n';

@ComponentV2
export struct RepoPickerView {
  @Param token: string = '';
  @Param pathStack: NavPathStack = new NavPathStack();
  @Local repos: PickerRepo[] = [];
  @Local loading: boolean = true;
  @Local errorMsg: string = '';
  /** 顶栏内联搜索（同 WorkIssues 范式：🔍 进入、✕ 清空）；搜索为服务端全网仓库检索 */
  @Local inSearch: boolean = false;
  @Local searchQuery: string = '';
  @Local searchResults: PickerRepo[] = [];
  private searchSeq: number = 0;
  /** 滚动顶部阴影 */
  @Local scrollShadow: boolean = false;
  /** 行点击中（查模板元数据期间防连点） */
  @Local tapping: string = '';

  aboutToAppear(): void {
    this.load();
  }

  private load(): void {
    this.loading = true;
    this.errorMsg = '';
    RepoSubService.fetchPickerRepos(this.token)
      .then((list: PickerRepo[]) => {
        this.repos = list;
        this.loading = false;
      })
      .catch((e: Error) => {
        this.errorMsg = friendlyError(this.getUIContext(), e);
        this.loading = false;
      });
  }

  /** 列表数据源：搜索态（有关键字）= 服务端结果；否则 = 全量候选 */
  private listSource(): PickerRepo[] {
    if (this.inSearch && this.searchQuery.trim() !== '') {
      return this.searchResults;
    }
    return this.repos;
  }

  /** 服务端仓库搜索（公开仓库亦可检索，竞态按代际丢弃） */
  private runSearch(): void {
    const q = this.searchQuery.trim();
    const seq = ++this.searchSeq;
    if (q === '') {
      this.searchResults = [];
      return;
    }
    RepoSubService.searchPickerRepos(this.token, q)
      .then((list: PickerRepo[]) => {
        if (seq === this.searchSeq) {
          this.searchResults = list;
        }
      })
      .catch((e: Error) => {
        if (seq === this.searchSeq) {
          this.searchResults = [];
          promptAction.showToast({ message: friendlyError(this.getUIContext(), e) });
        }
      });
  }

  private enterSearch(): void {
    this.inSearch = true;
  }

  /**
   * 选中仓库：查该仓库模板元数据——经典模板/issue forms/联系链接任一存在即入 Choose Template 页
   * （官方动线，Spec 043）；全无/查询失败直接进 Create Issue 表单
   */
  private openRepo(repo: PickerRepo): void {
    if (this.tapping !== '') {
      return;
    }
    this.tapping = pickerRepoFullName(repo);
    let showTemplatePage = false;
    RepoSubService.fetchRepoForm(this.token, repo.ownerLogin, repo.name)
      .then((page: RepoFormPage) => {
        showTemplatePage = page.templates.length > 0;
        // forms/联系链接在 .github/ISSUE_TEMPLATE（REST contents）；失败按空处理不阻断
        return RepoSubService.fetchIssueTemplateExtras(this.token, repo.ownerLogin, repo.name)
          .then((extras: IssueTemplateExtras): void => {
            if (extras.forms.length > 0 || extras.contactLinks.length > 0) {
              showTemplatePage = true;
            }
          })
          .catch((): void => {
          });
      })
      .then((): void => {
        this.tapping = '';
        if (showTemplatePage) {
          this.pathStack.pushPathByName('templatePicker', `${repo.ownerLogin}|${repo.name}`);
        } else {
          this.pathStack.pushPathByName('issueForm', `${repo.ownerLogin}|${repo.name}|new|0|`);
        }
      })
      .catch((e: Error) => {
        this.tapping = '';
        promptAction.showToast({ message: friendlyError(this.getUIContext(), e) });
      });
  }

  private stringOf(res: Resource): string {
    return resText(this.getUIContext(), res);
  }

  build() {
    Column() {
      // 两行头部（官方）：灰小字 Create Issue + 粗体 Choose a repository；搜索态整列换输入框
      Row({ space: 4 }) {
        Stack() {
          OctIcon({ res: $r('app.media.oct_arrow_left_24'), iconSize: 20, iconColor: $r('app.color.text_primary') })
        }
        .width(44)
        .height(44)
        .accessibilityDescription($r('app.string.a11y_back'))
        .focusable(true)
        .onClick((): void => {
          this.pathStack.pop();
        })
        if (this.inSearch) {
          TextInput({
            placeholder: this.stringOf($r('app.string.picker_search_hint')),
            text: this.searchQuery
          })
            .id('repo_picker_search')
            .layoutWeight(1)
            .height(44)
            .fontSize($r('app.float.title_font_size'))
            .fontColor($r('app.color.text_primary'))
            .placeholderColor($r('app.color.text_tertiary'))
            .caretColor($r('app.color.link_blue'))
            .backgroundColor(Color.Transparent)
            .onChange((v: string) => {
              this.searchQuery = v;
              this.runSearch();
            })
          // ✕ 仅在有输入内容时出现（官方口径）；点击=清空输入，搜索态保持
          if (this.searchQuery.trim() !== '') {
            Stack() {
              OctIcon({ res: $r('app.media.oct_x_16'), iconSize: 20, iconColor: $r('app.color.text_secondary') })
            }
            .width(44)
            .height(44)
            .padding(6)
            .accessibilityDescription($r('app.string.a11y_close'))
            .focusable(true)
            .onClick((): void => {
              this.searchQuery = '';
            })
          }
        } else {
          Column({ space: 2 }) {
            Text($r('app.string.create_new_issue'))
              .fontSize($r('app.float.caption_font_size'))
              .fontColor($r('app.color.text_secondary'))
            Text($r('app.string.repo_picker_title'))
              .fontSize($r('app.float.title_font_size'))
              .fontWeight(600)
              .fontColor($r('app.color.text_primary'))
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          .margin({ left: 4 })

          Stack() {
            OctIcon({ res: $r('app.media.oct_search_24'), iconSize: 20, iconColor: $r('app.color.link_blue') })
          }
          .width(44)
          .height(44)
          .padding(6)
          .accessibilityDescription($r('app.string.a11y_search'))
          .focusable(true)
          .onClick((): void => this.enterSearch())
        }
      }
      .width('100%')
      .height(56)
      .padding({ left: 4, right: 4 })

      PageShadowBar({ show: this.scrollShadow })

      Scroll() {
        Column() {
          if (this.listSource().length > 0) {
            ForEach(this.listSource(), (repo: PickerRepo) => {
              Row({ space: 14 }) {
                if (repo.ownerAvatar !== '') {
                  Image(repo.ownerAvatar)
                    .width(40)
                    .height(40)
                    .borderRadius(20)
                    .backgroundColor($r('app.color.heat_empty'))
                } else {
                  Circle()
                    .width(40)
                    .height(40)
                    .fill($r('app.color.heat_empty'))
                }
                Column({ space: 2 }) {
                  Text(repo.ownerLogin)
                    .fontSize($r('app.float.body_font_size'))
                    .fontColor($r('app.color.text_secondary'))
                  Text(repo.name)
                    .fontSize($r('app.float.body_font_size'))
                    .fontWeight(FontWeight.Medium)
                    .fontColor($r('app.color.text_primary'))
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 12, bottom: 12 })
              .opacity(this.tapping !== '' && this.tapping !== pickerRepoFullName(repo) ? 0.5 : 1)
              .onClick((): void => this.openRepo(repo))
            }, (repo: PickerRepo) => pickerRepoFullName(repo))
          } else if (this.loading || this.errorMsg !== '') {
            StateView({ loading: this.loading, error: this.errorMsg, onRetry: () => this.load() })
          } else {
            StateView({ empty: true, emptyText: $r('app.string.search_no_results') })
          }
        }
        .width('100%')
        .padding({ top: 4, bottom: 16 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
      .onScroll((_x: number, y: number): void => {
        this.scrollShadow = y > 0.001;
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_page'))
  }
}
