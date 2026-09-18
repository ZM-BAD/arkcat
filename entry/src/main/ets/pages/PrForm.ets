/**
 * 新建/编辑 Pull Request 表单页（Spec 043）：
 * 新建 = 仓库上下文（Home「+」入口可先选仓库）+ base/head 分支选择（head 仅限现有分支，
 * 官方移动端同口径，Spec 043 §五）+ 标题/正文（041 工具栏 + 预览）+ createPullRequest；
 * 编辑 = 回填标题/正文 + updatePullRequest（入口在详情页菜单/正文卡菜单，viewerCanUpdate 门控）。
 * 头部为文字动作头（取消 · 标题 · 创建/保存），骨架同 IssueForm/CreateList。
 */
import { promptAction } from '@kit.ArkUI';
import { OctIcon } from '../components/OctIcon';
import { MarkdownView } from '../components/MarkdownView';
import { MarkdownToolbar } from '../components/MarkdownToolbar';
import { FilterOptionSheet } from '../components/FilterOptionSheet';
import { FilterDropdownOption } from '../components/FilterDropdownChip';
import { RepoSubService } from '../services/RepoSubService';
import { MarkdownService } from '../services/MarkdownService';
import { friendlyError } from '../services/GitHttpClient';
import { PickerRepo, RepoFormPage, EditableContent, filterReposByKeyword } from '../models/RepoSubModels';
import { MarkdownEdit, MarkdownToolKind } from '../utils/MarkdownEdit';
import {
  canSubmitIssue, defaultBaseBranch, filterBranches, validatePrHeads
} from '../utils/IssueFormRules';
import { resText } from '../utils/I18n';

@ComponentV2
export struct PrFormView {
  @Param token: string = '';
  @Param pathStack: NavPathStack = new NavPathStack();
  @Param fOwner: string = '';
  @Param fName: string = '';
  @Param fMode: string = 'new';
  @Param fEditNumber: number = 0;

  @Local title: string = '';
  @Local body: string = '';
  @Local mode: string = 'write';
  @Local submitting: boolean = false;
  @Local errorMsg: string = '';
  /** 标题/分支行内错误：首次提交尝试后展示（Spec 043 元素12） */
  @Local submitAttempted: boolean = false;
  @Local previewHtml: string = '';
  @Local previewLoading: boolean = false;
  @Local selStart: number = 0;
  @Local selEnd: number = 0;
  /** 生效仓库（Home「+」入口为空，经仓库面板选定后落值） */
  @Local curOwner: string = '';
  @Local curName: string = '';
  @Local repoId: string = '';
  /** 分支数据（base 默认 = defaultBranchRef；head 仅在现有分支中选择） */
  @Local branches: string[] = [];
  @Local base: string = '';
  @Local head: string = '';
  /** 编辑模式回填的 PR 节点 id */
  @Local editId: string = '';
  /** 单 bindSheet + sheetKind（坑 2）：'repo'/'base'/'head' */
  @Local sheetOpen: boolean = false;
  @Local sheetKind: string = 'repo';
  @Local repos: PickerRepo[] = [];
  @Local sheetSearch: string = '';
  @Local sheetSearchShow: boolean = false;
  /** 已按该参数初始化（防 aboutToAppear 与 @Monitor 双触发） */
  private loadedFor: string = '';
  private textController: TextAreaController = new TextAreaController();

  aboutToAppear(): void {
    this.applyRoute();
    // 进入页面聚焦标题（官方交互）：动态插入后须下一帧再获焦
    setTimeout((): void => {
      this.getUIContext().getFocusController().requestFocus('pr_form_title');
    }, 60);
  }

  // 路由参数晚于 aboutToAppear（坑：keyed 首拉必配 @Monitor）
  @Monitor('fOwner', 'fName', 'fMode', 'fEditNumber')
  onRouteChanged(): void {
    this.applyRoute();
  }

  private applyRoute(): void {
    const key = `${this.fOwner}|${this.fName}|${this.fMode}|${this.fEditNumber}`;
    if (key === this.loadedFor) {
      return;
    }
    this.loadedFor = key;
    this.curOwner = this.fOwner;
    this.curName = this.fName;
    this.title = '';
    this.body = '';
    this.editId = '';
    this.repoId = '';
    this.branches = [];
    this.base = '';
    this.head = '';
    this.mode = 'write';
    this.previewHtml = '';
    this.errorMsg = '';
    this.submitAttempted = false;
    if (this.fMode === 'edit') {
      this.loadEditContent();
    } else if (this.fOwner !== '' && this.fName !== '') {
      this.loadRepoMeta();
    }
  }

  private stringOf(res: Resource): string {
    return resText(this.getUIContext(), res);
  }

  private headerTitle(): Resource {
    return this.fMode === 'edit'
      ? $r('app.string.form_edit_pr_title')
      : $r('app.string.form_new_pr_title');
  }

  /** 编辑模式回填（id/title/body；失败保留空表单可手填） */
  private loadEditContent(): void {
    if (this.curOwner === '' || this.curName === '') {
      return;
    }
    RepoSubService.fetchPrEdit(this.token, this.curOwner, this.curName, this.fEditNumber)
      .then((c: EditableContent) => {
        this.editId = c.id;
        this.title = c.title;
        this.body = c.body;
      })
      .catch((e: Error) => {
        this.errorMsg = friendlyError(this.getUIContext(), e);
      });
  }

  /** 仓库元数据（repositoryId + 分支列表；base 默认落 defaultBranchRef，Spec 043 测试4） */
  private loadRepoMeta(): void {
    RepoSubService.fetchRepoForm(this.token, this.curOwner, this.curName)
      .then((page: RepoFormPage) => {
        this.repoId = page.repoId;
        const names: string[] = [];
        for (const b of page.branches) {
          names.push(b.name);
        }
        this.branches = names;
        this.base = defaultBaseBranch(page.defaultBranch, names);
      })
      .catch((e: Error) => {
        this.repoId = '';
        this.branches = [];
        this.base = '';
        this.errorMsg = friendlyError(this.getUIContext(), e);
      });
  }

  private openRepoSheet(): void {
    this.sheetKind = 'repo';
    this.sheetSearch = '';
    this.sheetSearchShow = false;
    this.sheetOpen = true;
    if (this.repos.length === 0) {
      RepoSubService.fetchPickerRepos(this.token)
        .then((list: PickerRepo[]) => {
          this.repos = list;
        })
        .catch((e: Error) => {
          promptAction.showToast({ message: friendlyError(this.getUIContext(), e) });
        });
    }
  }

  private pickRepo(key: string): void {
    for (const r of this.repos) {
      if (r.nameWithOwner === key) {
        const idx = r.nameWithOwner.indexOf('/');
        this.curOwner = idx > 0 ? r.nameWithOwner.substring(0, idx) : r.nameWithOwner;
        this.curName = idx > 0 ? r.nameWithOwner.substring(idx + 1) : '';
        this.repoId = r.id;
        break;
      }
    }
    this.sheetOpen = false;
    this.base = '';
    this.head = '';
    this.branches = [];
    this.loadRepoMeta();
  }

  private pickBranch(kind: string, key: string): void {
    if (kind === 'base') {
      this.base = key;
    } else {
      this.head = key;
    }
    this.sheetOpen = false;
  }

  private repoOptions(): FilterDropdownOption[] {
    const options: FilterDropdownOption[] = [];
    for (const r of filterReposByKeyword(this.repos, this.sheetSearch)) {
      options.push({ key: r.nameWithOwner, label: r.nameWithOwner });
    }
    return options;
  }

  private branchOptions(): FilterDropdownOption[] {
    const options: FilterDropdownOption[] = [];
    for (const b of filterBranches(this.branches, this.sheetSearch)) {
      options.push({ key: b, label: b });
    }
    return options;
  }

  /** 分支选择错误键（提交尝试后才展示） */
  private headError(): string {
    if (!this.submitAttempted) {
      return '';
    }
    return validatePrHeads(this.base, this.head);
  }

  private onTool(kind: string): void {
    const ins = MarkdownEdit.apply(this.body, this.selStart, this.selEnd, kind as MarkdownToolKind);
    this.body = ins.text;
    this.textController.setTextSelection(ins.selStart, ins.selEnd);
  }

  private togglePreview(): void {
    if (this.mode === 'write') {
      this.mode = 'preview';
      this.loadPreview();
    } else {
      this.mode = 'write';
    }
  }

  private loadPreview(): void {
    if (this.body.trim() === '') {
      this.previewHtml = '';
      return;
    }
    this.previewLoading = true;
    MarkdownService.renderMarkdown(this.token, this.body, `${this.curOwner}/${this.curName}`)
      .then((html: string) => {
        this.previewHtml = html;
        this.previewLoading = false;
      })
      .catch((e: Error) => {
        this.previewHtml = '';
        this.previewLoading = false;
        this.errorMsg = friendlyError(this.getUIContext(), e);
      });
  }

  private submit(): void {
    if (this.submitting) {
      return;
    }
    this.submitAttempted = true;
    if (!canSubmitIssue(this.title)) {
      return;
    }
    if (this.fMode === 'edit') {
      if (this.editId === '') {
        return;
      }
      this.submitting = true;
      this.errorMsg = '';
      RepoSubService.updatePullRequest(this.token, this.editId, this.title.trim(), this.body)
        .then(() => {
          this.submitting = false;
          promptAction.showToast({ message: $r('app.string.form_saved') });
          this.pathStack.pop();
        })
        .catch((e: Error) => {
          this.submitting = false;
          this.errorMsg = friendlyError(this.getUIContext(), e);
        });
      return;
    }
    if (this.repoId === '') {
      this.errorMsg = this.stringOf($r('app.string.form_repo_required'));
      return;
    }
    if (validatePrHeads(this.base, this.head) !== '') {
      // 行内错误由 headError() 渲染，这里仅阻断提交
      return;
    }
    this.submitting = true;
    this.errorMsg = '';
    RepoSubService.createPullRequest(this.token, this.repoId, this.base, this.head, this.title.trim(), this.body)
      .then((number: number) => {
        this.submitting = false;
        // 详情压栈并自移除：返回键回到来源列表（repoPrs 已有 onShown tick 自刷）
        this.pathStack.pushPathByName('prDetail', `${this.curOwner}/${this.curName}/${number}`);
        this.pathStack.removeByName('prForm');
      })
      .catch((e: Error) => {
        // 4xx（head 不存在/无权限等）保留草稿内容（Spec 043 测试9）
        this.submitting = false;
        this.errorMsg = friendlyError(this.getUIContext(), e);
      });
  }

  @Builder
  formHeader() {
    Row({ space: 8 }) {
      Text($r('app.string.form_cancel'))
        .fontSize($r('app.float.sub_text_font_size'))
        .fontColor($r('app.color.link_blue'))
        .padding({ left: 12, right: 6, top: 6, bottom: 6 })
        .responseRegion({ x: -6, y: -7, width: '130%', height: '147%' })
        .onClick((): void => {
          this.pathStack.pop();
        })
      Text(this.headerTitle())
        .fontSize($r('app.float.title_font_size'))
        .fontWeight(600)
        .fontColor($r('app.color.text_primary'))
        .textAlign(TextAlign.Center)
        .maxLines(1)
        .layoutWeight(1)
      Text(this.fMode === 'edit' ? $r('app.string.form_save') : $r('app.string.form_create'))
        .fontSize($r('app.float.sub_text_font_size'))
        .fontWeight(FontWeight.Medium)
        .fontColor(this.submitting ? $r('app.color.text_tertiary') : $r('app.color.link_blue'))
        .padding({ left: 6, right: 12, top: 6, bottom: 6 })
        .responseRegion({ x: -6, y: -7, width: '130%', height: '147%' })
        .onClick((): void => this.submit())
    }
    .width('100%')
    .height(48)
  }

  /** 仓库行（新建模式）：已选显示仓库名，未选为蓝色引导文案 */
  @Builder
  repoRow() {
    Row({ space: 8 }) {
      OctIcon({ res: $r('app.media.oct_repo_16'), iconSize: 16, iconColor: $r('app.color.text_secondary') })
      Text(this.curOwner !== '' ? `${this.curOwner}/${this.curName}` : this.stringOf($r('app.string.form_repo_pick')))
        .fontSize($r('app.float.sub_text_font_size'))
        .fontColor(this.curOwner !== '' ? $r('app.color.text_primary') : $r('app.color.link_blue'))
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      OctIcon({ res: $r('app.media.oct_chevron_down_16'), iconSize: 16, iconColor: $r('app.color.text_secondary') })
    }
    .width('100%')
    .height(44)
    .borderRadius($r('app.float.card_radius'))
    .backgroundColor($r('app.color.bg_page'))
    .padding({ left: 12, right: 12 })
    .margin({ bottom: 4 })
    .onClick((): void => this.openRepoSheet())
  }

  /** base/head 选择行（新建模式；官方口径 base:/head: 字面前缀） */
  @Builder
  branchRow(label: Resource, value: string, placeholder: string, kind: string) {
    Row({ space: 8 }) {
      Text(label)
        .fontSize($r('app.float.sub_text_font_size'))
        .fontColor($r('app.color.text_secondary'))
      Text(value !== '' ? value : placeholder)
        .fontSize($r('app.float.sub_text_font_size'))
        .fontColor(value !== '' ? $r('app.color.text_primary') : $r('app.color.link_blue'))
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      OctIcon({ res: $r('app.media.oct_chevron_down_16'), iconSize: 16, iconColor: $r('app.color.text_secondary') })
    }
    .width('100%')
    .height(44)
    .borderRadius($r('app.float.card_radius'))
    .backgroundColor($r('app.color.bg_page'))
    .padding({ left: 12, right: 12 })
    .margin({ bottom: 4 })
    .onClick((): void => {
      this.sheetKind = kind;
      this.sheetSearch = '';
      this.sheetSearchShow = false;
      this.sheetOpen = true;
    })
  }

  /** Edit / Preview 页签（同 041 评论输入页：等分 + 选中蓝下划线） */
  @Builder
  editorTab(label: ResourceStr, key: string) {
    Column() {
      Text(label)
        .fontSize($r('app.float.sub_text_font_size'))
        .fontColor($r('app.color.text_primary'))
      Row()
        .width('100%')
        .height(2)
        .backgroundColor(this.mode === key ? $r('app.color.link_blue') : Color.Transparent)
        .margin({ top: 10 })
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
    .padding({ top: 8 })
    .onClick((): void => {
      if (this.mode !== key) {
        this.togglePreview();
      }
    })
  }

  build() {
    Column() {
      this.formHeader()
      Divider()
        .color($r('app.color.divider'))
        .strokeWidth(1)
        .width('100%')

      Scroll() {
        Column() {
          if (this.fMode === 'new') {
            this.repoRow()
            this.branchRow($r('app.string.form_base_label'), this.base,
              this.stringOf($r('app.string.form_repo_pick')), 'base')
            this.branchRow($r('app.string.form_head_label'), this.head,
              this.stringOf($r('app.string.form_head_pick')), 'head')
            if (this.headError() !== '') {
              Text(this.headError() === 'head_required'
                ? $r('app.string.form_head_required') : $r('app.string.form_head_equals_base'))
                .fontSize($r('app.float.caption_font_size'))
                .fontColor($r('app.color.danger_text'))
                .width('100%')
                .padding({ top: 4 })
            }
          }

          Text($r('app.string.form_title_label'))
            .fontSize($r('app.float.caption_font_size'))
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
            .padding({ top: 12, bottom: 4 })
          TextInput({
            placeholder: this.stringOf($r('app.string.form_title_placeholder')),
            text: this.title
          })
            .id('pr_form_title')
            .fontSize($r('app.float.menu_font_size'))
            .fontColor($r('app.color.text_primary'))
            .placeholderColor($r('app.color.text_tertiary'))
            .caretColor($r('app.color.link_blue'))
            .backgroundColor(Color.Transparent)
            .padding({ left: 0, right: 0 })
            .onChange((v: string) => {
              this.title = v;
            })
          if (canSubmitIssue(this.title) === false && this.submitAttempted) {
            Text(this.title.trim() === ''
              ? $r('app.string.form_title_required') : $r('app.string.form_title_too_long'))
              .fontSize($r('app.float.caption_font_size'))
              .fontColor($r('app.color.danger_text'))
              .width('100%')
              .padding({ top: 4 })
          }

          // Edit / Preview 页签 + 全幅细分隔线（同 041）
          Row() {
            this.editorTab($r('app.string.form_tab_write'), 'write')
            this.editorTab($r('app.string.form_tab_preview'), 'preview')
          }
          .width('100%')
          .margin({ top: 16 })
          Divider()
            .color($r('app.color.divider'))
            .strokeWidth(1)
            .width('100%')

          if (this.mode === 'write') {
            TextArea({
              text: this.body,
              placeholder: this.stringOf($r('app.string.form_body_placeholder')),
              controller: this.textController
            })
              .fontSize($r('app.float.sub_text_font_size'))
              .fontColor($r('app.color.text_primary'))
              .placeholderFont({ size: $r('app.float.sub_text_font_size') })
              .placeholderColor($r('app.color.text_tertiary'))
              .backgroundColor(Color.Transparent)
              .borderRadius(0)
              .width('100%')
              .constraintSize({ minHeight: 180 })
              .padding({ left: 0, right: 0, top: 12 })
              .onChange((v: string) => {
                this.body = v;
              })
              .onTextSelectionChange((start: number, end: number) => {
                this.selStart = start;
                this.selEnd = end;
              })
            MarkdownToolbar({ showReply: false, onTool: (kind: string): void => this.onTool(kind) })
          } else {
            Column() {
              if (this.previewLoading) {
                LoadingProgress()
                  .width(28)
                  .height(28)
                  .color($r('app.color.text_tertiary'))
                  .margin({ top: 24 })
              } else {
                MarkdownView({
                  html: this.previewHtml,
                  fallbackText: this.body,
                  collapse: false,
                  foldThreshold: 0
                })
              }
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .padding({ top: 12 })
          }

          if (this.errorMsg !== '') {
            Text(this.errorMsg)
              .fontSize($r('app.float.caption_font_size'))
              .fontColor($r('app.color.danger_text'))
              .width('100%')
              .padding({ top: 12 })
          }
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 8, bottom: 24 })
        .alignItems(HorizontalAlign.Start)
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_page'))
    .bindSheet($$this.sheetOpen, this.formSheet(), {
      height: 560,
      detents: [560, SheetSize.LARGE],
      showClose: false,
      dragBar: true,
      backgroundColor: $r('app.color.card_background'),
      onDisappear: (): void => {
        this.sheetOpen = false;
      }
    })
  }

  /** 弹层内容分派（单 bindSheet + sheetKind）：仓库候选 / base 分支 / head 分支 */
  @Builder
  formSheet() {
    if (this.sheetKind === 'repo') {
      FilterOptionSheet({
        title: $r('app.string.form_repo_pick'),
        searchPlaceholder: $r('app.string.form_repo_search'),
        options: this.repoOptions(),
        selectedKey: this.curOwner !== '' ? `${this.curOwner}/${this.curName}` : '',
        searchShow: this.sheetSearchShow,
        searchText: this.sheetSearch,
        onPick: (key: string): void => this.pickRepo(key),
        onClose: (): void => {
          this.sheetOpen = false;
        },
        onSearchToggle: (): void => {
          this.sheetSearchShow = !this.sheetSearchShow;
          this.sheetSearch = '';
        },
        onSearchChange: (v: string): void => {
          this.sheetSearch = v;
        }
      })
    } else {
      FilterOptionSheet({
        title: this.sheetKind === 'base'
          ? $r('app.string.form_branch_base_title')
          : $r('app.string.form_branch_head_title'),
        searchPlaceholder: $r('app.string.form_branch_search'),
        options: this.branchOptions(),
        selectedKey: this.sheetKind === 'base' ? this.base : this.head,
        searchShow: this.sheetSearchShow,
        searchText: this.sheetSearch,
        onPick: (key: string): void => this.pickBranch(this.sheetKind, key),
        onClose: (): void => {
          this.sheetOpen = false;
        },
        onSearchToggle: (): void => {
          this.sheetSearchShow = !this.sheetSearchShow;
          this.sheetSearch = '';
        },
        onSearchChange: (v: string): void => {
          this.sheetSearch = v;
        }
      })
    }
  }
}
