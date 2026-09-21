/**
 * New fork 弹层（Spec 075）：官方「点 fork 先出 New fork 页、再点 CREATE 才真 fork」流程。
 * 自绘抓取条 + 顶栏（✕ + 两行标题 owner/name · New fork + CREATE）+ 三段内容：
 * Repository name（默认=上游名、N/100 计数、空名行内错误）、Repository description（上游描述只读）、
 * Additional settings（Copy the <默认分支> branch only 开关 + 贡献说明 + Learn more）。
 * 提交走 REST POST /repos/{owner}/{repo}/forks（GraphQL Mutation 无 fork 字段，Spec 006 §五）；
 * 上游元数据由详情页随参数传入，零额外请求。弹层关闭即销毁，重开回到默认值。
 */
import { friendlyError } from '../services/GitHttpClient';
import { RepoService } from '../services/RepoService';
import { isValidRepoName, REPO_NAME_MAX } from '../models/RepoCreateModels';
import { resText } from '../utils/I18n';
import { OctIcon } from './OctIcon';

/** Learn more 落地页：GitHub 官方 fork 文档（官方实际目标页未能核对，Spec 075 §五） */
const FORK_DOCS_URL = 'https://docs.github.com/en/get-started/quickstart/fork-a-repo';

@ComponentV2
export struct RepoForkSheet {
  @Require @Param token: string;
  /** 上游 owner/name：标题行、默认名与贡献说明文案共用 */
  @Require @Param owner: string;
  @Require @Param name: string;
  /** 上游描述与默认分支（详情查询同批带回，分支名随仓库，禁止写死） */
  @Param description: string = '';
  @Param defaultBranch: string = 'main';
  @Param pathStack: NavPathStack = new NavPathStack();
  /** 创建成功：壳外关弹层 + toast */
  @Event onCreated: () => void = (): void => { };
  /** ✕：关弹层 */
  @Event onDismiss: () => void = (): void => { };

  @Local forkName: string = '';
  @Local branchOnly: boolean = true;
  @Local nameError: boolean = false;
  @Local creating: boolean = false;
  @Local errorMsg: string = '';

  aboutToAppear(): void {
    // 默认与上游同名（官方口径）
    this.forkName = this.name;
  }

  /** 提交：空名行内拦截（同 070，CREATE 恒可点不置灰）；其余失败经 ApiError → friendlyError */
  private submit(): void {
    if (this.creating) {
      return;
    }
    if (!isValidRepoName(this.forkName)) {
      this.nameError = true;
      return;
    }
    this.nameError = false;
    this.errorMsg = '';
    this.creating = true;
    RepoService.createFork(this.token, this.owner, this.name, this.forkName.trim(), this.branchOnly)
      .then((): void => this.onCreated())
      .catch((e: Error): void => {
        this.errorMsg = resText(this.getUIContext(), $r('app.string.repo_fork_failed'),
          friendlyError(this.getUIContext(), e));
        this.creating = false;
      });
  }

  private stringOf(res: Resource): string {
    return resText(this.getUIContext(), res);
  }

  private openDocs(): void {
    this.pathStack.pushPathByName('inAppBrowser',
      `${this.stringOf($r('app.string.repo_fork_docs_title'))}|${FORK_DOCS_URL}`);
  }

  build() {
    Column() {
      // 自绘抓取条：SheetSize.LARGE 档框架不渲染 dragBar（Spec 070 同口径 36×5）
      Row() {
        Row()
          .width(36)
          .height(5)
          .borderRadius(2.5)
          .backgroundColor($r('app.color.text_tertiary'))
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .padding({ top: 8, bottom: 6 })

      // 顶栏：✕ + 两行标题（owner/name · New fork）+ CREATE（形态同建仓弹层）
      Row() {
        Stack() {
          OctIcon({ res: $r('app.media.oct_x_16'), iconSize: 16, iconColor: $r('app.color.text_primary') })
        }
        .width(44)
        .height(44)
        .accessibilityDescription($r('app.string.a11y_close'))
        .onClick((): void => this.onDismiss())

        Column({ space: 2 }) {
          Text(`${this.owner}/${this.name}`)
            .fontSize($r('app.float.caption_font_size'))
            .fontColor($r('app.color.text_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text($r('app.string.repo_fork_new_title'))
            .fontSize($r('app.float.title_font_size'))
            .fontWeight(600)
            .fontColor($r('app.color.text_primary'))
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        .margin({ left: 4 })

        Text($r('app.string.repo_create_create'))
          .fontSize($r('app.float.body_font_size'))
          .fontWeight(600)
          .fontColor($r('app.color.link_blue'))
          .textCase(TextCase.UpperCase)
          .padding({ left: 12, right: 8, top: 10, bottom: 10 })
          .onClick((): void => this.submit())
      }
      .width('100%')
      .padding({ left: 8, right: 8, top: 4 })
      .alignItems(VerticalAlign.Center)

      // 副标题：fork 落到个人账号（组织 fork 见 Spec 075 §五）
      Text($r('app.string.repo_fork_scope_hint'))
        .fontSize($r('app.float.body_font_size'))
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 16 })

      Divider()
        .strokeWidth(1)
        .color($r('app.color.divider'))
        .width('100%')

      // Repository name 区
      Column({ space: 6 }) {
        Text($r('app.string.repo_fork_name_label'))
          .fontSize($r('app.float.body_font_size'))
          .fontColor($r('app.color.text_secondary'))
        TextInput({ text: this.forkName })
          .width('100%')
          .height(44)
          .fontSize($r('app.float.menu_font_size'))
          .fontColor($r('app.color.text_primary'))
          .caretColor($r('app.color.link_blue'))
          .maxLength(REPO_NAME_MAX)
          .backgroundColor(Color.Transparent)
          // 贴边输入光标被默认圆角裁成月牙，显式归零（坑 41）
          .borderRadius(0)
          .padding({ left: 0, right: 0 })
          .onChange((v: string): void => {
            this.forkName = v;
            this.nameError = false;
          })
        Text($r('app.string.repo_fork_name_hint'))
          .fontSize($r('app.float.body_font_size'))
          .fontColor($r('app.color.text_secondary'))
        Text($r('app.string.repo_create_counter', this.forkName.length, REPO_NAME_MAX))
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_secondary'))
        if (this.nameError) {
          Text($r('app.string.repo_create_error_empty_name'))
            .fontSize($r('app.float.caption_font_size'))
            .fontColor($r('app.color.danger_text'))
        }
        if (this.errorMsg !== '') {
          Text(this.errorMsg)
            .fontSize($r('app.float.caption_font_size'))
            .fontColor($r('app.color.danger_text'))
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 16, right: 16, top: 16, bottom: 20 })

      // Repository description 区（上游无描述则整区隐藏；值继承上游，只读）
      if (this.description !== '') {
        Divider()
          .strokeWidth(1)
          .color($r('app.color.divider'))
          .width('100%')
        Column({ space: 6 }) {
          Text($r('app.string.repo_fork_desc_label'))
            .fontSize($r('app.float.body_font_size'))
            .fontColor($r('app.color.text_secondary'))
          Text(this.description)
            .fontSize($r('app.float.body_font_size'))
            .fontColor($r('app.color.text_secondary'))
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 16, right: 16, top: 16, bottom: 20 })
      }

      Divider()
        .strokeWidth(1)
        .color($r('app.color.divider'))
        .width('100%')

      // Additional settings 区
      Column({ space: 10 }) {
        Text($r('app.string.repo_fork_settings_label'))
          .fontSize($r('app.float.body_font_size'))
          .fontColor($r('app.color.text_secondary'))

        // Copy the <默认分支> branch only（行主体与 Switch 兄弟拆分防冒泡，分支名=仓库真实默认分支）
        Row() {
          Row() {
            Text($r('app.string.repo_fork_branch_only_pre'))
              .fontSize($r('app.float.body_font_size'))
              .fontColor($r('app.color.text_primary'))
            Text(this.defaultBranch)
              .fontSize($r('app.float.body_font_size'))
              .fontFamily('monospace')
              .fontColor($r('app.color.text_primary'))
              .backgroundColor($r('app.color.heat_empty'))
              .borderRadius(4)
              .padding({ left: 5, right: 5, top: 1, bottom: 1 })
              .margin({ left: 2, right: 2 })
            Text($r('app.string.repo_fork_branch_only_post'))
              .fontSize($r('app.float.body_font_size'))
              .fontColor($r('app.color.text_primary'))
          }
          .layoutWeight(1)
          .onClick((): void => {
            this.branchOnly = !this.branchOnly;
          })

          Toggle({ type: ToggleType.Switch, isOn: this.branchOnly })
            .selectedColor($r('app.color.link_blue'))
            .onChange((on: boolean): void => {
              this.branchOnly = on;
            })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Column({ space: 4 }) {
          Text(resText(this.getUIContext(), $r('app.string.repo_fork_contribute_fmt'), `${this.owner}/${this.name}`))
            .fontSize($r('app.float.body_font_size'))
            .fontColor($r('app.color.text_secondary'))
          Text($r('app.string.repo_fork_learn_more'))
            .fontSize($r('app.float.body_font_size'))
            .fontColor($r('app.color.link_blue'))
            .onClick((): void => this.openDocs())
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 16, right: 16, top: 16, bottom: 20 })
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('app.color.card_background'))
  }
}
