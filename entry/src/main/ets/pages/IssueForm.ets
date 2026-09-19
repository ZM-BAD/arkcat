/**
 * 新建/编辑 Issue 表单页（Spec 043，官方截图驱动 2026-09-19 推倒重写）：
 * 新建 = 两行头部（`owner/name` 灰字 + 粗体 Create Issue + 右上纸飞机发送）+ Title/Body 原生占位
 * + 底部属性芯片行（Assignee/Label/Milestone/Project，创建即选）+ 正文聚焦时键盘上方 Markdown 工具条；
 * Home 入口先经 Choose a repository 整页选仓库（RepoPicker），本页仓库上下文恒存在。
 * 编辑 = 同头部（Edit Issue）回填标题/正文走 updateIssue，无芯片行。
 * 官方创建表单无 Write/Preview 页签 → 不做预览（spec 043 §七）。
 */
import { promptAction } from '@kit.ArkUI';
import { OctIcon } from '../components/OctIcon';
import { MarkdownToolbar } from '../components/MarkdownToolbar';
import { FilterOptionSheet } from '../components/FilterOptionSheet';
import { FilterDropdownOption } from '../components/FilterDropdownChip';
import { RepoSubService } from '../services/RepoSubService';
import { friendlyError } from '../services/GitHttpClient';
import {
  IssueTemplateItem, TriageUser, TriageLabel, TriageMilestone, TriageProject,
  RepoFormPage, EditableContent, IssueCreated
} from '../models/RepoSubModels';
import { MarkdownEdit, MarkdownToolKind } from '../utils/MarkdownEdit';
import { canSubmitIssue, ISSUE_TITLE_MAX } from '../utils/IssueFormRules';
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
  @Local submitting: boolean = false;
  @Local errorMsg: string = '';
  /** 正文聚焦时显示键盘上方 Markdown 工具条（官方口径） */
  @Local bodyFocused: boolean = false;
  @Local selStart: number = 0;
  @Local selEnd: number = 0;
  /** 生效仓库（路由/选仓库页带入，本页恒存在） */
  @Local curOwner: string = '';
  @Local curName: string = '';
  @Local repoId: string = '';
  @Local templates: IssueTemplateItem[] = [];
  /** 编辑模式回填的 Issue 节点 id */
  @Local editId: string = '';
  /** 创建即选属性（芯片行，单选简化：再点同项=清除） */
  @Local selAssignee: TriageUser | null = null;
  @Local selLabel: TriageLabel | null = null;
  @Local selMilestone: TriageMilestone | null = null;
  @Local selProject: TriageProject | null = null;
  /** 候选池（对应芯片懒加载） */
  @Local users: TriageUser[] = [];
  @Local labels: TriageLabel[] = [];
  @Local milestones: TriageMilestone[] = [];
  @Local projects: TriageProject[] = [];
  /** 单 bindSheet + sheetKind（坑 2）：template/assignee/label/milestone/project */
  @Local sheetOpen: boolean = false;
  @Local sheetKind: string = 'assignee';
  /** 已按该参数初始化（防 aboutToAppear 与 @Monitor 双触发） */
  private loadedFor: string = '';
  private textController: TextAreaController = new TextAreaController();

  aboutToAppear(): void {
    this.applyRoute();
    // 聚焦标题（官方交互）：动态插入后须下一帧再获焦
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
    this.errorMsg = '';
    this.bodyFocused = false;
    this.selAssignee = null;
    this.selLabel = null;
    this.selMilestone = null;
    this.selProject = null;
    if (this.fMode === 'edit') {
      this.loadEditContent();
    } else {
      this.loadRepoMeta();
    }
  }

  private stringOf(res: Resource): string {
    return resText(this.getUIContext(), res);
  }

  private headerTitle(): Resource {
    return this.fMode === 'edit'
      ? $r('app.string.form_edit_issue_title')
      : $r('app.string.create_new_issue');
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

  /** 打开芯片/模板选择面板（候选懒加载，失败 toast 不阻断） */
  private openSheet(kind: string): void {
    this.sheetKind = kind;
    this.sheetOpen = true;
    if (kind === 'assignee' && this.users.length === 0) {
      RepoSubService.fetchTriageAssignees(this.token, this.curOwner, this.curName)
        .then((list: TriageUser[]) => {
          this.users = list;
        })
        .catch((e: Error) => {
          promptAction.showToast({ message: friendlyError(this.getUIContext(), e) });
        });
    } else if (kind === 'label' && this.labels.length === 0) {
      RepoSubService.fetchTriageLabels(this.token, this.curOwner, this.curName)
        .then((list: TriageLabel[]) => {
          this.labels = list;
        })
        .catch((e: Error) => {
          promptAction.showToast({ message: friendlyError(this.getUIContext(), e) });
        });
    } else if (kind === 'milestone' && this.milestones.length === 0) {
      RepoSubService.fetchTriageMilestones(this.token, this.curOwner, this.curName)
        .then((list: TriageMilestone[]) => {
          this.milestones = list;
        })
        .catch((e: Error) => {
          promptAction.showToast({ message: friendlyError(this.getUIContext(), e) });
        });
    } else if (kind === 'project' && this.projects.length === 0) {
      RepoSubService.fetchTriageProjects(this.token, this.curOwner, this.curName, 'RECENT')
        .then((list: TriageProject[]) => {
          this.projects = list;
        })
        .catch((e: Error) => {
          promptAction.showToast({ message: friendlyError(this.getUIContext(), e) });
        });
    }
  }

  /** 单选通用：再点同项=清除 */
  private pickById(kind: string, key: string): void {
    if (kind === 'assignee') {
      this.selAssignee = this.selAssignee?.id === key ? null : this.users.find((u: TriageUser): boolean => u.id === key) ?? null;
    } else if (kind === 'label') {
      this.selLabel = this.selLabel?.id === key ? null : this.labels.find((l: TriageLabel): boolean => l.id === key) ?? null;
    } else if (kind === 'milestone') {
      this.selMilestone = this.selMilestone?.id === key
        ? null : this.milestones.find((m: TriageMilestone): boolean => m.id === key) ?? null;
    } else if (kind === 'project') {
      this.selProject = this.selProject?.id === key
        ? null : this.projects.find((p: TriageProject): boolean => p.id === key) ?? null;
    }
    this.sheetOpen = false;
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

  /** 官方口径：模板只填充正文（标题不动） */
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

  private plainOptions(keys: string[], values: string[]): FilterDropdownOption[] {
    const options: FilterDropdownOption[] = [];
    for (let i = 0; i < keys.length; i++) {
      options.push({ key: keys[i], label: values[i] });
    }
    return options;
  }

  private labelColorOf(key: string): string {
    const hit = this.labels.find((l: TriageLabel): boolean => l.id === key);
    return hit !== undefined ? hit.color : '';
  }

  private onTool(kind: string): void {
    const ins = MarkdownEdit.apply(this.body, 0, 0, kind as MarkdownToolKind);
    this.body = ins.text;
    this.textController.setTextSelection(ins.selStart, ins.selEnd);
  }

  private submit(): void {
    if (this.submitting) {
      return;
    }
    if (!canSubmitIssue(this.title)) {
      // 官方表单无行内错误 UI：客户端静默拦截 + toast
      promptAction.showToast({
        message: this.title.trim() === ''
          ? $r('app.string.form_title_required') : $r('app.string.form_title_too_long')
      });
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
      promptAction.showToast({ message: $r('app.string.form_repo_required') });
      return;
    }
    this.submitting = true;
    this.errorMsg = '';
    RepoSubService.createIssue(this.token, this.repoId, this.title.trim(), this.body,
      this.selAssignee !== null ? [this.selAssignee.id] : [],
      this.selLabel !== null ? [this.selLabel.id] : [],
      this.selMilestone !== null ? this.selMilestone.id : '')
      .then((created: IssueCreated) => {
        // Project 在创建后单独挂（createIssue 无 projectIds 入参走 044 通道；失败不影响建 Issue）
        if (this.selProject !== null && created.id !== '') {
          RepoSubService.addPrToProject(this.token, created.id, this.selProject.id).catch((): void => {
          });
        }
        this.submitting = false;
        // 详情压栈并自移除（连同选仓库页）：返回键回 Home
        this.pathStack.pushPathByName('issueDetail', `${this.curOwner}/${this.curName}/${created.number}`);
        this.pathStack.removeByName('issueForm');
        this.pathStack.removeByName('repoPicker');
      })
      .catch((e: Error) => {
        // 4xx 错误保留草稿内容（Spec 043 测试9）
        this.submitting = false;
        this.errorMsg = friendlyError(this.getUIContext(), e);
      });
  }

  /** 两行头部（官方）：← + `owner/name` 灰字/粗体标题 + 右上纸飞机发送 */
  @Builder
  formHeader() {
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
      Column({ space: 2 }) {
        Text(`${this.curOwner}/${this.curName}`)
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_secondary'))
        Text(this.headerTitle())
          .fontSize($r('app.float.title_font_size'))
          .fontWeight(600)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ left: 4 })

      Stack() {
        OctIcon({
          res: $r('app.media.oct_paper_airplane_16'), iconSize: 22,
          iconColor: this.submitting ? $r('app.color.text_tertiary') : $r('app.color.link_blue')
        })
      }
      .width(44)
      .height(44)
      .accessibilityDescription($r('app.string.form_send'))
      .focusable(true)
      .onClick((): void => this.submit())
    }
    .width('100%')
    .height(56)
    .padding({ left: 4, right: 4 })
  }

  /** 模板行（新建模式且有官方模板时显示，Spec 043 元素2） */
  @Builder
  templateRow() {
    Row({ space: 6 }) {
      OctIcon({ res: $r('app.media.oct_file_16'), iconSize: 14, iconColor: $r('app.color.link_blue') })
      Text($r('app.string.form_template_add'))
        .fontSize($r('app.float.sub_text_font_size'))
        .fontColor($r('app.color.link_blue'))
    }
    .width('100%')
    .height(32)
    .margin({ bottom: 8 })
    .onClick((): void => this.openSheet('template'))
  }

  /** 底部属性芯片（官方：Assignee/Label/Milestone/Project，横向可滑）；灰底描边阴影小胶囊，选中后显示所选项 */
  @Builder
  attrChip(iconRes: Resource, label: Resource, kind: string, selected: string) {
    Row({ space: 5 }) {
      OctIcon({ res: iconRes, iconSize: 14, iconColor: $r('app.color.text_primary') })
      Text(selected !== '' ? selected : label)
        .fontSize($r('app.float.caption_font_size'))
        .fontWeight(selected !== '' ? FontWeight.Medium : FontWeight.Normal)
        .fontColor($r('app.color.text_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .height(30)
    .borderRadius(15)
    .border({ width: 1, color: $r('app.color.divider') })
    .backgroundColor($r('app.color.bg_page'))
    .shadow({ radius: 6, color: $r('app.color.shadow_floating'), offsetY: 2 })
    .padding({ left: 12, right: 12 })
    .onClick((): void => this.openSheet(kind))
  }

  build() {
    Column() {
      this.formHeader()

      Scroll() {
        Column() {
          if (this.fMode === 'new' && this.templates.length > 0) {
            this.templateRow()
          }

          Text($r('app.string.form_title_label'))
            .fontSize($r('app.float.body_font_size'))
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
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
            .padding({ left: 0, right: 0, top: 4 })
            .onChange((v: string) => {
              this.title = v;
            })

          Text($r('app.string.form_body_label'))
            .fontSize($r('app.float.body_font_size'))
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
            .padding({ top: 20 })
          TextArea({
            text: this.body,
            placeholder: this.stringOf($r('app.string.form_body_placeholder')),
            controller: this.textController
          })
            .fontSize($r('app.float.menu_font_size'))
            .fontColor($r('app.color.text_primary'))
            .placeholderFont({ size: $r('app.float.menu_font_size') })
            .placeholderColor($r('app.color.text_tertiary'))
            .caretColor($r('app.color.link_blue'))
            .backgroundColor(Color.Transparent)
            .width('100%')
            .constraintSize({ minHeight: 240 })
            .padding({ left: 0, right: 0, top: 4 })
            .onChange((v: string) => {
              this.body = v;
            })
            .onFocus((): void => {
              this.bodyFocused = true;
            })
            .onBlur((): void => {
              this.bodyFocused = false;
            })
            .onTextSelectionChange((start: number, end: number) => {
              this.selStart = start;
              this.selEnd = end;
            })

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

      // 底部属性芯片行（新建模式，官方创建即选）
      if (this.fMode === 'new') {
        Scroll() {
          Row({ space: 8 }) {
            this.attrChip($r('app.media.oct_person_add_16'), $r('app.string.chip_assignee'), 'assignee',
              this.selAssignee !== null ? this.selAssignee.login : '')
            this.attrChip($r('app.media.oct_tag_16'), $r('app.string.chip_label'), 'label',
              this.selLabel !== null ? this.selLabel.name : '')
            this.attrChip($r('app.media.oct_milestone_16'), $r('app.string.chip_milestone'), 'milestone',
              this.selMilestone !== null ? this.selMilestone.title : '')
            this.attrChip($r('app.media.oct_table_16'), $r('app.string.chip_project'), 'project',
              this.selProject !== null ? this.selProject.title : '')
          }
          .padding({ left: 16, right: 16 })
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .width('100%')
        .padding({ top: 8, bottom: 10 })
      }

      // 正文聚焦时：键盘上方 Markdown 工具条（灰底，官方口径）
      if (this.bodyFocused) {
        MarkdownToolbar({ showReply: false, onTool: (kind: string): void => this.onTool(kind) })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.card_background'))
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

  /** 弹层内容分派（单 bindSheet + sheetKind）：模板/负责人/标签/里程碑/项目 */
  @Builder
  formSheet() {
    if (this.sheetKind === 'template') {
      FilterOptionSheet({
        title: $r('app.string.form_template_title'),
        searchPlaceholder: $r('app.string.meta_editor_search'),
        options: this.templateOptions(),
        selectedKey: '',
        onPick: (key: string): void => this.pickTemplate(key),
        onClose: (): void => {
          this.sheetOpen = false;
        }
      })
    } else if (this.sheetKind === 'assignee') {
      FilterOptionSheet({
        title: $r('app.string.meta_editor_select_assignees'),
        searchPlaceholder: $r('app.string.meta_editor_search'),
        options: this.plainOptions(this.users.map((u: TriageUser): string => u.id),
          this.users.map((u: TriageUser): string => u.login)),
        selectedKey: this.selAssignee !== null ? this.selAssignee.id : '',
        onPick: (key: string): void => this.pickById('assignee', key),
        onClose: (): void => {
          this.sheetOpen = false;
        }
      })
    } else if (this.sheetKind === 'label') {
      FilterOptionSheet({
        title: $r('app.string.meta_editor_select_labels'),
        searchPlaceholder: $r('app.string.meta_editor_search'),
        options: this.plainOptions(this.labels.map((l: TriageLabel): string => l.id),
          this.labels.map((l: TriageLabel): string => l.name)),
        selectedKey: this.selLabel !== null ? this.selLabel.id : '',
        rowKind: 'label',
        labelColorOf: (key: string): string => this.labelColorOf(key),
        onPick: (key: string): void => this.pickById('label', key),
        onClose: (): void => {
          this.sheetOpen = false;
        }
      })
    } else if (this.sheetKind === 'milestone') {
      FilterOptionSheet({
        title: $r('app.string.meta_editor_select_milestone'),
        searchPlaceholder: $r('app.string.meta_editor_search'),
        options: this.plainOptions(this.milestones.map((m: TriageMilestone): string => m.id),
          this.milestones.map((m: TriageMilestone): string => m.title)),
        selectedKey: this.selMilestone !== null ? this.selMilestone.id : '',
        onPick: (key: string): void => this.pickById('milestone', key),
        onClose: (): void => {
          this.sheetOpen = false;
        }
      })
    } else {
      FilterOptionSheet({
        title: $r('app.string.meta_editor_select_projects'),
        searchPlaceholder: $r('app.string.meta_editor_search'),
        options: this.plainOptions(this.projects.map((p: TriageProject): string => p.id),
          this.projects.map((p: TriageProject): string => p.title)),
        selectedKey: this.selProject !== null ? this.selProject.id : '',
        onPick: (key: string): void => this.pickById('project', key),
        onClose: (): void => {
          this.sheetOpen = false;
        }
      })
    }
  }
}
