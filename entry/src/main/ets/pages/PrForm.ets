/**
 * Start pull request / 编辑 Pull Request 表单页（Spec 043，官方截图驱动 2026-09-19 重做）：
 * 新建 = Compare changes 页选定 base/head 后的第二跳（✕ 两行头部 + Start pull request +
 * Title/Description 原生占位 + 页底绿色 CREATE PULL REQUEST 主按钮；base/head 由路由带入，
 * 分支行不再显示）；编辑 = 同头部（Edit Pull Request）回填走 updatePullRequest，← 返回 + 纸飞机发送。
 * 本页仓库上下文恒存在（入口仅 Compare changes 页/PR 详情编辑）。
 */
import { promptAction } from '@kit.ArkUI';
import { OctIcon } from '../components/OctIcon';
import { MarkdownToolbar } from '../components/MarkdownToolbar';
import { RepoSubService } from '../services/RepoSubService';
import { friendlyError } from '../services/GitHttpClient';
import { EditableContent, RepoFormPage } from '../models/RepoSubModels';
import { MarkdownEdit, MarkdownToolKind } from '../utils/MarkdownEdit';
import { canSubmitIssue, validatePrHeads } from '../utils/IssueFormRules';
import { resText } from '../utils/I18n';

@ComponentV2
export struct PrFormView {
  @Param token: string = '';
  @Param pathStack: NavPathStack = new NavPathStack();
  @Param fOwner: string = '';
  @Param fName: string = '';
  @Param fMode: string = 'new';
  @Param fEditNumber: number = 0;
  /** Compare changes 页选定的分支（mode=new；提交前校验非空且 head≠base） */
  @Param fBase: string = '';
  @Param fHead: string = '';

  @Local title: string = '';
  @Local body: string = '';
  @Local submitting: boolean = false;
  @Local errorMsg: string = '';
  /** 正文聚焦时显示键盘上方 Markdown 工具条（对齐 Create Issue 官方口径） */
  @Local bodyFocused: boolean = false;
  @Local selStart: number = 0;
  @Local selEnd: number = 0;
  /** 仓库节点 id（createPullRequest 入参） */
  @Local repoId: string = '';
  /** 编辑模式回填的 PR 节点 id */
  @Local editId: string = '';
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
  @Monitor('fOwner', 'fName', 'fMode', 'fEditNumber', 'fBase', 'fHead')
  onRouteChanged(): void {
    this.applyRoute();
  }

  private applyRoute(): void {
    const key = `${this.fOwner}|${this.fName}|${this.fMode}|${this.fEditNumber}|${this.fBase}|${this.fHead}`;
    if (key === this.loadedFor) {
      return;
    }
    this.loadedFor = key;
    this.title = '';
    this.body = '';
    this.editId = '';
    this.repoId = '';
    this.errorMsg = '';
    this.bodyFocused = false;
    if (this.fMode === 'edit') {
      this.loadEditContent();
    } else {
      this.loadRepoId();
    }
  }

  private stringOf(res: Resource): string {
    return resText(this.getUIContext(), res);
  }

  private headerTitle(): Resource {
    return this.fMode === 'edit'
      ? $r('app.string.form_edit_pr_title')
      : $r('app.string.start_pr_title');
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

  /** 仓库节点 id（创建 PR 用；分支已在 Compare changes 页选定，不再拉分支列表） */
  private loadRepoId(): void {
    RepoSubService.fetchRepoForm(this.token, this.fOwner, this.fName)
      .then((page: RepoFormPage) => {
        this.repoId = page.repoId;
      })
      .catch((e: Error) => {
        this.repoId = '';
        this.errorMsg = friendlyError(this.getUIContext(), e);
      });
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
    if (this.fMode === 'new') {
      if (this.repoId === '') {
        promptAction.showToast({ message: $r('app.string.form_repo_required') });
        return;
      }
      const headError = validatePrHeads(this.fBase, this.fHead);
      if (headError !== '') {
        promptAction.showToast({
          message: headError === 'head_required'
            ? $r('app.string.form_head_required') : $r('app.string.form_head_equals_base')
        });
        return;
      }
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
    RepoSubService.createPullRequest(this.token, this.repoId, this.fBase, this.fHead, this.title.trim(), this.body)
      .then((number: number) => {
        this.submitting = false;
        // 详情压栈并自移除表单与 Compare 页：返回键回来源列表（repoPrs 已有 onShown tick 自刷）
        this.pathStack.pushPathByName('prDetail', `${this.fOwner}/${this.fName}/${number}`);
        this.pathStack.removeByName('prForm');
        this.pathStack.removeByName('prCompare');
      })
      .catch((e: Error) => {
        // 4xx（head 无差异/无权限等）保留表单内容（Spec 043 测试9）
        this.submitting = false;
        this.errorMsg = friendlyError(this.getUIContext(), e);
      });
  }

  /** 两行头部：新建 = ✕ + `owner/name` 灰字/粗体 Start pull request（无右上发送钮，页底主按钮）；
   *  编辑 = ← + 粗体 Edit Pull Request + 右上纸飞机发送 */
  @Builder
  formHeader() {
    Row({ space: 4 }) {
      Stack() {
        OctIcon({
          res: this.fMode === 'edit'
            ? $r('app.media.oct_arrow_left_24') : $r('app.media.oct_x_24'),
          iconSize: 20, iconColor: $r('app.color.text_primary')
        })
      }
      .width(44)
      .height(44)
      .accessibilityDescription(this.fMode === 'edit'
        ? $r('app.string.a11y_back') : $r('app.string.a11y_close'))
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

      if (this.fMode === 'edit') {
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
    }
    .width('100%')
    .height(56)
    .padding({ left: 4, right: 4 })
  }

  build() {
    Column() {
      this.formHeader()

      Scroll() {
        Column() {
          if (this.fMode === 'edit') {
            Text($r('app.string.form_title_label'))
              .fontSize($r('app.float.body_font_size'))
              .fontColor($r('app.color.text_secondary'))
              .width('100%')
              .padding({ top: 12 })
          }
          TextInput({
            // 官方 Start pull request 形态：无字段标签，粗体占位 Title
            placeholder: this.fMode === 'edit'
              ? this.stringOf($r('app.string.form_title_placeholder'))
              : this.stringOf($r('app.string.start_pr_title_placeholder')),
            text: this.title
          })
            .id('pr_form_title')
            .fontSize($r('app.float.menu_font_size'))
            .fontColor($r('app.color.text_primary'))
            .placeholderColor($r('app.color.text_tertiary'))
            .placeholderFont({ size: $r('app.float.menu_font_size') })
            .caretColor($r('app.color.link_blue'))
            .backgroundColor(Color.Transparent)
            // ⚠️ 必须显式归零：组件默认圆角在水平 padding=0 时会把贴边光标裁成弧形（坑）
            .borderRadius(0)
            .padding({ left: 0, right: 0, top: 4 })
            .onChange((v: string) => {
              this.title = v;
            })

          if (this.fMode === 'edit') {
            Text($r('app.string.form_body_label'))
              .fontSize($r('app.float.body_font_size'))
              .fontColor($r('app.color.text_secondary'))
              .width('100%')
              .padding({ top: 20 })
          }
          TextArea({
            text: this.body,
            placeholder: this.fMode === 'edit'
              ? this.stringOf($r('app.string.form_body_placeholder'))
              : this.stringOf($r('app.string.start_pr_desc_placeholder')),
            controller: this.textController
          })
            .fontSize($r('app.float.menu_font_size'))
            .fontColor($r('app.color.text_primary'))
            .placeholderFont({ size: $r('app.float.menu_font_size') })
            .placeholderColor($r('app.color.text_tertiary'))
            .caretColor($r('app.color.link_blue'))
            .backgroundColor(Color.Transparent)
            // ⚠️ 必须显式归零：组件默认圆角在水平 padding=0 时会把贴边光标裁成弧形（坑）
            .borderRadius(0)
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

      // 新建：页底绿色创建主按钮（官方 Compare changes 按钮形态延续）
      if (this.fMode === 'new') {
        Column() {
          Button($r('app.string.compare_create_btn'))
            .width('100%')
            .height($r('app.float.button_height'))
            .backgroundColor($r('app.color.success_btn_bg'))
            .fontSize($r('app.float.sub_text_font_size'))
            .opacity(this.submitting ? 0.6 : 1)
            .onClick((): void => this.submit())
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 8, bottom: 16 })
        .backgroundColor($r('app.color.card_background'))
      }

      // 正文聚焦时：键盘上方 Markdown 工具条（灰底）
      if (this.bodyFocused) {
        MarkdownToolbar({ showReply: false, onTool: (kind: string): void => this.onTool(kind) })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.card_background'))
  }
}
