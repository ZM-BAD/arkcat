/**
 * 新建/编辑 Pull Request 表单页（Spec 043；头部语言与 Create Issue 官方截图对齐 2026-09-19）：
 * 新建 = 两行头部（`owner/name` 灰字 + 粗体 New Pull Request + 纸飞机发送）+ base/head 分支选择
 * （head 仅限现有分支，官方移动端同口径，Spec 043 §五）+ Title/Body + 聚焦时键盘上方工具条；
 * 编辑 = 同头部（Edit Pull Request）回填走 updatePullRequest，无分支行。
 * 本页仓库上下文恒存在（入口仅仓库详情/仓库内 PR 列表；Home 不提供 New pull request）。
 */
import { promptAction } from '@kit.ArkUI';
import { OctIcon } from '../components/OctIcon';
import { MarkdownToolbar } from '../components/MarkdownToolbar';
import { FilterOptionSheet } from '../components/FilterOptionSheet';
import { FilterDropdownOption } from '../components/FilterDropdownChip';
import { RepoSubService } from '../services/RepoSubService';
import { friendlyError } from '../services/GitHttpClient';
import { RepoFormPage, EditableContent } from '../models/RepoSubModels';
import { MarkdownEdit, MarkdownToolKind } from '../utils/MarkdownEdit';
import { canSubmitIssue, defaultBaseBranch, filterBranches, validatePrHeads } from '../utils/IssueFormRules';
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
  @Local submitting: boolean = false;
  @Local errorMsg: string = '';
  /** 正文聚焦时显示键盘上方 Markdown 工具条（对齐 Create Issue 官方口径） */
  @Local bodyFocused: boolean = false;
  @Local selStart: number = 0;
  @Local selEnd: number = 0;
  /** 分支数据（base 默认 = defaultBranchRef；head 仅在现有分支中选择） */
  @Local repoId: string = '';
  @Local branches: string[] = [];
  @Local base: string = '';
  @Local head: string = '';
  /** 编辑模式回填的 PR 节点 id */
  @Local editId: string = '';
  /** 单 bindSheet + sheetKind（坑 2）：'base'/'head' */
  @Local sheetOpen: boolean = false;
  @Local sheetKind: string = 'base';
  @Local sheetSearch: string = '';
  @Local sheetSearchShow: boolean = false;
  /** 已按该参数初始化（防 aboutToAppear 与 @Monitor 双触发） */
  private loadedFor: string = '';
  private textController: TextAreaController = new TextAreaController();

  aboutToAppear(): void {
    this.applyRoute();
    // 聚焦标题（官方交互）：动态插入后须下一帧再获焦
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
    this.title = '';
    this.body = '';
    this.editId = '';
    this.repoId = '';
    this.branches = [];
    this.base = '';
    this.head = '';
    this.errorMsg = '';
    this.bodyFocused = false;
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
      ? $r('app.string.form_edit_pr_title')
      : $r('app.string.form_new_pr_title');
  }

  /** 编辑模式回填（id/title/body；失败保留空表单可手填） */
  private loadEditContent(): void {
    if (this.fOwner === '' || this.fName === '') {
      return;
    }
    RepoSubService.fetchPrEdit(this.token, this.fOwner, this.fName, this.fEditNumber)
      .then((c: EditableContent) => {
        this.editId = c.id;
        this.title = c.title;
        this.body = c.body;
      })
      .catch((e: Error) => {
        this.errorMsg = friendlyError(this.getUIContext(), e);
      });
  }

  /** 仓库元数据（分支列表；base 默认落 defaultBranchRef，Spec 043 测试4） */
  private loadRepoMeta(): void {
    RepoSubService.fetchRepoForm(this.token, this.fOwner, this.fName)
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

  private openBranchSheet(kind: string): void {
    this.sheetKind = kind;
    this.sheetSearch = '';
    this.sheetSearchShow = false;
    this.sheetOpen = true;
  }

  private pickBranch(kind: string, key: string): void {
    if (kind === 'base') {
      this.base = key;
    } else {
      this.head = key;
    }
    this.sheetOpen = false;
  }

  private branchOptions(): FilterDropdownOption[] {
    const options: FilterDropdownOption[] = [];
    for (const b of filterBranches(this.branches, this.sheetSearch)) {
      options.push({ key: b, label: b });
    }
    return options;
  }

  private onTool(kind: string): void {
    const ins = MarkdownEdit.apply(this.body, this.selStart, this.selEnd, kind as MarkdownToolKind);
    this.body = ins.text;
    this.textController.setTextSelection(ins.selStart, ins.selEnd);
  }

  private submit(): void {
    if (this.submitting) {
      return;
    }
    if (!canSubmitIssue(this.title)) {
      promptAction.showToast({
        message: this.title.trim() === ''
          ? $r('app.string.form_title_required') : $r('app.string.form_title_too_long')
      });
      return;
    }
    if (this.fMode === 'new' && this.repoId === '') {
      promptAction.showToast({ message: $r('app.string.form_repo_required') });
      return;
    }
    const headError = validatePrHeads(this.base, this.head);
    if (this.fMode === 'new' && headError !== '') {
      promptAction.showToast({
        message: headError === 'head_required'
          ? $r('app.string.form_head_required') : $r('app.string.form_head_equals_base')
      });
      return;
    }
    this.submitting = true;
    this.errorMsg = '';
    if (this.fMode === 'edit') {
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
    RepoSubService.createPullRequest(this.token, this.repoId, this.base, this.head, this.title.trim(), this.body)
      .then((number: number) => {
        this.submitting = false;
        // 详情压栈并自移除：返回键回来源列表（repoPrs 已有 onShown tick 自刷）
        this.pathStack.pushPathByName('prDetail', `${this.fOwner}/${this.fName}/${number}`);
        this.pathStack.removeByName('prForm');
      })
      .catch((e: Error) => {
        // 4xx（head 不存在/无权限等）保留草稿内容（Spec 043 测试9）
        this.submitting = false;
        this.errorMsg = friendlyError(this.getUIContext(), e);
      });
  }

  /** 两行头部（对齐 Create Issue 官方）：← + `owner/name` 灰字/粗体标题 + 右上纸飞机发送 */
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
        Text(`${this.fOwner}/${this.fName}`)
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

  /** base/head 选择行（官方口径 base:/head: 字面前缀；页底白，行用灰底突显） */
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
    .onClick((): void => this.openBranchSheet(kind))
  }

  build() {
    Column() {
      this.formHeader()

      Scroll() {
        Column() {
          if (this.fMode === 'new') {
            this.branchRow($r('app.string.form_base_label'), this.base,
              this.stringOf($r('app.string.form_branch_base_title')), 'base')
            this.branchRow($r('app.string.form_head_label'), this.head,
              this.stringOf($r('app.string.form_head_pick')), 'head')
          }

          Text($r('app.string.form_title_label'))
            .fontSize($r('app.float.body_font_size'))
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
            .padding({ top: 12 })
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

      // 正文聚焦时：键盘上方 Markdown 工具条（灰底）
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

  /** 弹层内容分派（单 bindSheet + sheetKind）：base 分支 / head 分支 */
  @Builder
  formSheet() {
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
