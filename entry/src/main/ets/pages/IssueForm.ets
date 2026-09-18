/**
 * 新建/编辑 Issue 表单页（Spec 043）：
 * 新建 = 仓库上下文（Home「+」入口可先选仓库）+ 官方模板选择 + 标题/正文（041 工具栏 + 预览）+ createIssue；
 * 编辑 = 回填标题/正文 + updateIssue（入口在详情页标题行 pencil / 菜单，viewerCanUpdate 门控）。
 * 头部为文字动作头（取消 · 标题 · 创建/保存），骨架同 CreateList（文字动作头不进 AppBar 组件）。
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
import {
  IssueTemplateItem, PickerRepo, RepoFormPage, EditableContent, filterReposByKeyword
} from '../models/RepoSubModels';
import { MarkdownEdit, MarkdownToolKind } from '../utils/MarkdownEdit';
import { canSubmitIssue, issueTitleError, ISSUE_TITLE_MAX } from '../utils/IssueFormRules';
import { resText } from '../utils/I18n';

/** 模板面板「空白议题」哨兵 key（不填充任何内容） */
const BLANK_TEMPLATE_KEY: string = '__blank';

@ComponentV2
export struct IssueFormView {
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
  /** 标题行内错误：首次提交尝试后展示，输入中实时复检（Spec 043 元素12） */
  @Local submitAttempted: boolean = false;
  @Local previewHtml: string = '';
  @Local previewLoading: boolean = false;
  @Local selStart: number = 0;
  @Local selEnd: number = 0;
  /** 生效仓库（Home「+」入口为空，经仓库面板选定后落值） */
  @Local curOwner: string = '';
  @Local curName: string = '';
  @Local repoId: string = '';
  @Local templates: IssueTemplateItem[] = [];
  /** 编辑模式回填的 Issue 节点 id */
  @Local editId: string = '';
  /** 单 bindSheet + sheetKind（坑 2：同组件多 bindSheet 只有最后一个生效）：'repo'/'template' */
  @Local sheetOpen: boolean = false;
  @Local sheetKind: string = 'repo';
  @Local repos: PickerRepo[] = [];
  @Local repoSearch: string = '';
  @Local repoSearchShow: boolean = false;
  /** 已按该参数初始化（防 aboutToAppear 与 @Monitor 双触发） */
  private loadedFor: string = '';
  private textController: TextAreaController = new TextAreaController();

  aboutToAppear(): void {
    this.applyRoute();
    // 进入页面聚焦标题（官方交互）：动态插入后须下一帧再获焦
    setTimeout((): void => {
      this.getUIContext().getFocusController().requestFocus('issue_form_title');
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
    this.templates = [];
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
      ? $r('app.string.form_edit_issue_title')
      : $r('app.string.form_new_issue_title');
  }

  /** 编辑模式回填（id/title/body；失败保留空表单可手填） */
  private loadEditContent(): void {
    if (this.curOwner === '' || this.curName === '') {
      return;
    }
    RepoSubService.fetchIssueEdit(this.token, this.curOwner, this.curName, this.fEditNumber)
      .then((c: EditableContent) => {
        this.editId = c.id;
        this.title = c.title;
        this.body = c.body;
      })
      .catch((e: Error) => {
        this.errorMsg = friendlyError(this.getUIContext(), e);
      });
  }

  /** 仓库元数据（repositoryId + 官方模板；失败不阻断手填提交，服务端兜底校验） */
  private loadRepoMeta(): void {
    RepoSubService.fetchRepoForm(this.token, this.curOwner, this.curName)
      .then((page: RepoFormPage) => {
        this.repoId = page.repoId;
        this.templates = page.templates;
      })
      .catch((e: Error) => {
        this.repoId = '';
        this.templates = [];
        this.errorMsg = friendlyError(this.getUIContext(), e);
      });
  }

  private openRepoSheet(): void {
    this.sheetKind = 'repo';
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
    this.templates = [];
    this.loadRepoMeta();
  }

  private repoOptions(): FilterDropdownOption[] {
    const options: FilterDropdownOption[] = [];
    for (const r of filterReposByKeyword(this.repos, this.repoSearch)) {
      options.push({ key: r.nameWithOwner, label: r.nameWithOwner });
    }
    return options;
  }

  private templateOptions(): FilterDropdownOption[] {
    const options: FilterDropdownOption[] = [
      { key: BLANK_TEMPLATE_KEY, label: this.stringOf($r('app.string.form_template_blank')) }
    ];
    for (const t of this.templates) {
      options.push({ key: t.name, label: t.name });
    }
    return options;
  }

  /** 官方口径：模板只填充正文（Spec 043 元素2），标题不动 */
  private pickTemplate(key: string): void {
    if (key !== BLANK_TEMPLATE_KEY) {
      for (const t of this.templates) {
        if (t.name === key) {
          this.body = t.body;
          break;
        }
      }
    }
    this.sheetOpen = false;
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

  /** 标题行内错误：提交尝试过或已超长才展示（输入中不打扰） */
  private titleError(): string {
    if (!this.submitAttempted && this.title.length <= ISSUE_TITLE_MAX) {
      return '';
    }
    return issueTitleError(this.title);
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
      RepoSubService.updateIssue(this.token, this.editId, this.title.trim(), this.body)
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
    this.submitting = true;
    this.errorMsg = '';
    RepoSubService.createIssue(this.token, this.repoId, this.title.trim(), this.body)
      .then((number: number) => {
        this.submitting = false;
        // 详情压栈并自移除：返回键回到来源列表（列表页已有 onShown tick 自刷）
        this.pathStack.pushPathByName('issueDetail', `${this.curOwner}/${this.curName}/${number}`);
        this.pathStack.removeByName('issueForm');
      })
      .catch((e: Error) => {
        // 4xx 错误保留草稿内容（Spec 043 测试9）
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

  /** 模板行（新建模式且有官方模板时显示，Spec 043 元素2） */
  @Builder
  templateRow() {
    Row({ space: 8 }) {
      OctIcon({ res: $r('app.media.oct_file_16'), iconSize: 16, iconColor: $r('app.color.text_secondary') })
      Text($r('app.string.form_template_add'))
        .fontSize($r('app.float.sub_text_font_size'))
        .fontColor($r('app.color.link_blue'))
        .layoutWeight(1)
      OctIcon({ res: $r('app.media.oct_chevron_down_16'), iconSize: 16, iconColor: $r('app.color.text_secondary') })
    }
    .width('100%')
    .height(40)
    .margin({ bottom: 4 })
    .onClick((): void => {
      this.sheetKind = 'template';
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
            if (this.templates.length > 0) {
              this.templateRow()
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
            .id('issue_form_title')
            .fontSize($r('app.float.menu_font_size'))
            .fontColor($r('app.color.text_primary'))
            .placeholderColor($r('app.color.text_tertiary'))
            .caretColor($r('app.color.link_blue'))
            .backgroundColor(Color.Transparent)
            .padding({ left: 0, right: 0 })
            .onChange((v: string) => {
              this.title = v;
            })
          if (this.titleError() !== '') {
            Text(this.titleError() === 'required'
              ? $r('app.string.form_title_required') : $r('app.string.form_title_too_long'))
              .fontSize($r('app.float.caption_font_size'))
              .fontColor($r('app.color.danger_text'))
              .width('100%')
              .padding({ top: 4 })
          }
          if (this.title.length > ISSUE_TITLE_MAX - 55) {
            Text(`${this.title.length} / ${ISSUE_TITLE_MAX}`)
              .fontSize($r('app.float.caption_font_size'))
              .fontColor(this.title.length > ISSUE_TITLE_MAX
                ? $r('app.color.danger_text') : $r('app.color.text_tertiary'))
              .width('100%')
              .textAlign(TextAlign.End)
              .padding({ top: 2 })
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

  /** 弹层内容分派（单 bindSheet + sheetKind）：仓库候选 / Issue 模板 */
  @Builder
  formSheet() {
    if (this.sheetKind === 'repo') {
      FilterOptionSheet({
        title: $r('app.string.form_repo_pick'),
        searchPlaceholder: $r('app.string.form_repo_search'),
        options: this.repoOptions(),
        selectedKey: this.curOwner !== '' ? `${this.curOwner}/${this.curName}` : '',
        searchShow: this.repoSearchShow,
        searchText: this.repoSearch,
        onPick: (key: string): void => this.pickRepo(key),
        onClose: (): void => {
          this.sheetOpen = false;
        },
        onSearchToggle: (): void => {
          this.repoSearchShow = !this.repoSearchShow;
          this.repoSearch = '';
        },
        onSearchChange: (v: string): void => {
          this.repoSearch = v;
        }
      })
    } else {
      FilterOptionSheet({
        title: $r('app.string.form_template_title'),
        searchPlaceholder: $r('app.string.form_repo_search'),
        options: this.templateOptions(),
        selectedKey: '',
        onPick: (key: string): void => this.pickTemplate(key),
        onClose: (): void => {
          this.sheetOpen = false;
        }
      })
    }
  }
}
