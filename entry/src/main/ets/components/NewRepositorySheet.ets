/**
 * New repository 主弹层壳（Spec 070）：两步状态机（General↔Configuration 横向步进）+
 * 三个子弹层的嵌套 bindSheet（单 bindSheet + sheetKind 分派，坑 2）+ CREATE 提交。
 * 弹层内容关闭即销毁重建：重开自动回 General 步、表单清空（官方丢弃语义）。
 * Owner 信息优先取 Home 已拉的 viewer 基础信息，缺省时弹层内兜底自取。
 */
import { promptAction } from '@kit.ArkUI';
import { ApiError, friendlyError } from '../services/GitHttpClient';
import { HomeService } from '../services/HomeService';
import { RepoCreateService } from '../services/RepoCreateService';
import { resText } from '../utils/I18n';
import { NewRepositoryGeneral } from './NewRepositoryGeneral';
import { NewRepositoryConfig } from './NewRepositoryConfig';
import { NewRepositoryPicker } from './NewRepositoryPicker';
import { ViewerBasic } from '../models/GitHubModels';
import {
  CreatedRepo, NewRepoForm, PickerItem, TemplateRepoSource, isValidRepoName
} from '../models/RepoCreateModels';

const STEP_GENERAL = 1;
const STEP_CONFIG = 2;
/** 子弹层 kind（sheetKind 分派，坑 2：同组件多 bindSheet 只有最后一个生效） */
const PICKER_TEMPLATE = 'templateRepo';
const PICKER_GITIGNORE = 'gitignore';
const PICKER_LICENSE = 'license';

@ComponentV2
export struct NewRepositorySheet {
  @Require @Param token: string;
  /** Home 已拉的 viewer 基础信息（空=弹层内兜底自取） */
  @Param ownerLoginHint: string = '';
  @Param ownerAvatarHint: string = '';
  /** 创建成功：壳外关弹层并跳转新仓库详情 */
  @Event onCreated: (owner: string, name: string) => void = (owner: string, name: string): void => { };
  /** General ✕：关闭整个流程 */
  @Event onDismiss: () => void = (): void => { };

  @Local ownerLogin: string = '';
  @Local ownerAvatar: string = '';
  @Local step: number = STEP_GENERAL;
  @Local name: string = '';
  @Local description: string = '';
  @Local isPrivate: boolean = true;
  @Local addReadme: boolean = false;
  @Local nameError: boolean = false;
  @Local creating: boolean = false;
  // 选中回显（null=未选）
  @Local gitignoreItem: PickerItem | null = null;
  @Local licenseItem: PickerItem | null = null;
  @Local templateItem: PickerItem | null = null;
  @Local templateOwnerId: string = '';
  // 子弹层状态（单 bindSheet + sheetKind 分派）
  @Local pickerOpen: boolean = false;
  @Local pickerKind: string = '';
  @Local pickerLoading: boolean = false;
  @Local pickerError: string = '';
  @Local gitignoreOptions: PickerItem[] = [];
  @Local licenseOptions: PickerItem[] = [];
  @Local templateOptions: PickerItem[] = [];

  aboutToAppear(): void {
    if (this.ownerLoginHint !== '') {
      this.ownerLogin = this.ownerLoginHint;
      this.ownerAvatar = this.ownerAvatarHint;
      return;
    }
    // Home viewer 未就绪（离线进页等）时兜底自取；失败静默（Avatar 组件自带占位兜底）
    HomeService.fetchViewerBasic(this.token)
      .then((viewer: ViewerBasic): void => {
        this.ownerLogin = viewer.login;
        this.ownerAvatar = viewer.avatarUrl;
      })
      .catch((_e: Error): void => { });
  }

  // —— 步进 ——

  /** NEXT：空名=行内错误（官方恒可点，§七）；合法进 Configuration */
  private goNext(): void {
    if (!isValidRepoName(this.name)) {
      this.nameError = true;
      return;
    }
    this.nameError = false;
    this.step = STEP_CONFIG;
  }

  private goBack(): void {
    this.step = STEP_GENERAL;
  }

  // —— 子弹层 ——

  private openPicker(kind: string): void {
    this.pickerKind = kind;
    this.pickerOpen = true;
    this.loadPicker(kind);
  }

  private loadPicker(kind: string): void {
    this.pickerLoading = true;
    this.pickerError = '';
    if (kind === PICKER_GITIGNORE) {
      RepoCreateService.fetchGitignoreTemplates(this.token)
        .then((items: PickerItem[]): void => {
          this.gitignoreOptions = items;
          this.pickerLoading = false;
        })
        .catch((e: Error): void => this.pickerFailed(e));
    } else if (kind === PICKER_LICENSE) {
      RepoCreateService.fetchLicenses(this.token)
        .then((items: PickerItem[]): void => {
          this.licenseOptions = items;
          this.pickerLoading = false;
        })
        .catch((e: Error): void => this.pickerFailed(e));
    } else {
      RepoCreateService.fetchTemplateRepos(this.token)
        .then((source: TemplateRepoSource): void => {
          this.templateOptions = source.items;
          this.templateOwnerId = source.ownerId;
          this.pickerLoading = false;
        })
        .catch((e: Error): void => this.pickerFailed(e));
    }
  }

  private pickerFailed(e: Error): void {
    this.pickerError = friendlyError(this.getUIContext(), e);
    this.pickerLoading = false;
  }

  /** SAVE：提交待定选择（空 key=清空语义） */
  private commitPicker(kind: string, key: string): void {
    if (kind === PICKER_GITIGNORE) {
      this.gitignoreItem = this.pickOf(this.gitignoreOptions, key);
    } else if (kind === PICKER_LICENSE) {
      this.licenseItem = this.pickOf(this.licenseOptions, key);
    } else {
      this.templateItem = this.pickOf(this.templateOptions, key);
    }
    this.pickerOpen = false;
  }

  private pickOf(options: PickerItem[], key: string): PickerItem | null {
    const found = options.find((it: PickerItem): boolean => it.key === key);
    return found !== undefined ? found : null;
  }

  // —— CREATE ——

  /** CREATE：创建仓库（方法名避让框架保留名 create） */
  private submitCreate(): void {
    if (this.creating) {
      return;
    }
    if (!isValidRepoName(this.name)) {
      this.nameError = true;
      this.step = STEP_GENERAL;
      return;
    }
    this.creating = true;
    const form: NewRepoForm = {
      name: this.name.trim(),
      description: this.description.trim(),
      isPrivate: this.isPrivate,
      addReadme: this.addReadme,
      ownerId: this.templateOwnerId,
      gitignoreTemplate: this.gitignoreItem !== null ? this.gitignoreItem.key : '',
      licenseTemplate: this.licenseItem !== null ? this.licenseItem.key : '',
      templateRepoId: this.templateItem !== null ? this.templateItem.key : ''
    };
    RepoCreateService.createRepository(this.token, form)
      .then((repo: CreatedRepo): void => {
        this.creating = false;
        this.onCreated(repo.owner, repo.name);
      })
      .catch((e: Error): void => {
        this.creating = false;
        if (e instanceof ApiError && e.code === 422) {
          // 重名/非法名：专属文案，弹层与已填内容保留（§五）
          promptAction.showToast({
            message: resText(this.getUIContext(), $r('app.string.repo_create_error_invalid_name'))
          });
          return;
        }
        promptAction.showToast({ message: friendlyError(this.getUIContext(), e) });
      });
  }

  @Builder
  pickerContent() {
    if (this.pickerKind === PICKER_GITIGNORE) {
      // 官方 .gitignore 层标题同为 Choose a template，副标题复用 Add .gitignore 文案
      NewRepositoryPicker({
        title: $r('app.string.repo_create_choose_template'),
        subtitle: $r('app.string.repo_create_add_gitignore'),
        searchPlaceholder: $r('app.string.repo_create_search_gitignore'),
        options: this.gitignoreOptions,
        loading: this.pickerLoading,
        errorMsg: this.pickerError,
        initialKey: this.gitignoreItem !== null ? this.gitignoreItem.key : '',
        onSave: (key: string): void => this.commitPicker(PICKER_GITIGNORE, key),
        onClose: (): void => {
          this.pickerOpen = false;
        },
        onRetry: (): void => this.loadPicker(PICKER_GITIGNORE)
      })
    } else if (this.pickerKind === PICKER_LICENSE) {
      NewRepositoryPicker({
        title: $r('app.string.repo_create_choose_license'),
        searchPlaceholder: $r('app.string.repo_create_search_licenses'),
        options: this.licenseOptions,
        loading: this.pickerLoading,
        errorMsg: this.pickerError,
        initialKey: this.licenseItem !== null ? this.licenseItem.key : '',
        onSave: (key: string): void => this.commitPicker(PICKER_LICENSE, key),
        onClose: (): void => {
          this.pickerOpen = false;
        },
        onRetry: (): void => this.loadPicker(PICKER_LICENSE)
      })
    } else {
      NewRepositoryPicker({
        title: $r('app.string.repo_create_choose_template'),
        subtitle: $r('app.string.repo_create_subtitle_template_repo'),
        searchPlaceholder: $r('app.string.repo_create_search_template_repos'),
        options: this.templateOptions,
        loading: this.pickerLoading,
        errorMsg: this.pickerError,
        initialKey: this.templateItem !== null ? this.templateItem.key : '',
        onSave: (key: string): void => this.commitPicker(PICKER_TEMPLATE, key),
        onClose: (): void => {
          this.pickerOpen = false;
        },
        onRetry: (): void => this.loadPicker(PICKER_TEMPLATE)
      })
    }
  }

  build() {
    Column() {
      // 自绘抓取条（官方口径）：框架 dragBar 在 LARGE 档不渲染，options 里已关
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

      Stack() {
        if (this.step === STEP_GENERAL) {
          NewRepositoryGeneral({
            ownerLogin: this.ownerLogin,
            ownerAvatar: this.ownerAvatar,
            name: this.name,
            description: this.description,
            nameError: this.nameError,
            onClose: (): void => this.onDismiss(),
            onNext: (): void => this.goNext(),
            onNameChange: (v: string): void => {
              this.name = v;
              this.nameError = false;
            },
            onDescChange: (v: string): void => {
              this.description = v;
            }
          })
            .transition(TransitionEffect.translate({ x: '-30%' })
              .animation({ duration: 280, curve: Curve.Ease }))
        } else {
          NewRepositoryConfig({
            isPrivate: this.isPrivate,
            addReadme: this.addReadme,
            gitignoreName: this.gitignoreItem !== null ? this.gitignoreItem.label : '',
            licenseName: this.licenseItem !== null ? this.licenseItem.key : '',
            templateName: this.templateItem !== null ? this.templateItem.label : '',
            onBack: (): void => this.goBack(),
            onCreate: (): void => this.submitCreate(),
            onPrivateChange: (v: boolean): void => {
              this.isPrivate = v;
            },
            onReadmeChange: (v: boolean): void => {
              this.addReadme = v;
            },
            onPickTemplate: (): void => this.openPicker(PICKER_TEMPLATE),
            onPickGitignore: (): void => this.openPicker(PICKER_GITIGNORE),
            onPickLicense: (): void => this.openPicker(PICKER_LICENSE)
          })
            .transition(TransitionEffect.translate({ x: '100%' })
              .animation({ duration: 280, curve: Curve.Ease }))
        }
      }
      .width('100%')
      .layoutWeight(1)

      // 底部两圆点分页指示（官方口径）
      Row({ space: 8 }) {
        Row()
          .width(8)
          .height(8)
          .borderRadius(4)
          .backgroundColor(this.step === STEP_GENERAL ? $r('app.color.text_primary') : $r('app.color.text_tertiary'))
        Row()
          .width(8)
          .height(8)
          .borderRadius(4)
          .backgroundColor(this.step === STEP_CONFIG ? $r('app.color.text_primary') : $r('app.color.text_tertiary'))
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .padding({ top: 8, bottom: 10 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.card_background'))
    .bindSheet(this.pickerOpen!!, this.pickerContent(), {
      height: SheetSize.LARGE,
      showClose: false,
      // LARGE 档框架不渲染 dragBar，抓取条在内容里自绘
      dragBar: false,
      backgroundColor: $r('app.color.card_background'),
      onDisappear: (): void => {
        this.pickerOpen = false;
      }
    })
  }
}
