/**
 * Choose Branch / Choose head ref 分支选择页（Spec 043，官方截图驱动 2026-09-19）：
 * ✕ + 单行粗体标题（字面复刻官方大小写差异）+ 🔍 常驻内联搜索（客户端过滤）；
 * 行 = 浅蓝 mono 分支芯片 + 默认分支 Default 描边徽标 + 当前选中蓝底白勾；
 * 排序 = 默认分支优先 + 字母序。选中经 BranchPickResult 槽回传（NavDestination pop 无原生回传，
 * prCompare 页 onShown tick 读取后清空）。
 */
import { OctIcon } from '../components/OctIcon';
import { StateView } from '../components/StateView';
import { RepoSubService } from '../services/RepoSubService';
import { friendlyError } from '../services/GitHttpClient';
import { BranchRefs } from '../models/RepoSubModels';
import { filterBranches, orderBranches } from '../utils/IssueFormRules';

/** 分支选择结果回传槽：选择页写入 role/picked 后 pop，prCompare 页读取（读毕双清空） */
export class BranchPickResult {
  static role: string = '';
  static picked: string = '';
}

@ComponentV2
export struct BranchPickerView {
  @Param token: string = '';
  @Param pathStack: NavPathStack = new NavPathStack();
  /** 选择角色（'base' | 'head'）：决定页面标题与回传角色 */
  @Param pRole: string = 'head';
  @Param pOwner: string = '';
  @Param pName: string = '';
  /** 进入时的当前选中分支（''=未选；命中行显示蓝底白勾） */
  @Param pCurrent: string = '';

  @Local branches: string[] = [];
  @Local defaultBranch: string = '';
  @Local loading: boolean = true;
  @Local errorMsg: string = '';
  @Local search: string = '';
  /** 已按该参数初始化（防 aboutToAppear 与 @Monitor 双触发） */
  private loadedFor: string = '';

  aboutToAppear(): void {
    this.applyRoute();
  }

  // 路由参数晚于 aboutToAppear（坑：keyed 首拉必配 @Monitor）
  @Monitor('pOwner', 'pName', 'pRole', 'pCurrent')
  onRouteChanged(): void {
    this.applyRoute();
  }

  private applyRoute(): void {
    const key = `${this.pOwner}|${this.pName}|${this.pRole}|${this.pCurrent}`;
    if (key === this.loadedFor) {
      return;
    }
    this.loadedFor = key;
    this.search = '';
    this.load();
  }

  private load(): void {
    this.loading = true;
    this.errorMsg = '';
    RepoSubService.fetchBranches(this.token, this.pOwner, this.pName)
      .then((refs: BranchRefs) => {
        this.defaultBranch = refs.defaultBranch;
        this.branches = orderBranches(refs.names, refs.defaultBranch);
        this.loading = false;
      })
      .catch((e: Error) => {
        this.errorMsg = friendlyError(this.getUIContext(), e);
        this.loading = false;
      });
  }

  /** 选中回传 + 收页（prCompare 在 onShown 里消费）；repo 角色（Spec 071）行点击不落选择 */
  private pick(branch: string): void {
    if (this.pRole === 'repo') {
      return;
    }
    BranchPickResult.role = this.pRole;
    BranchPickResult.picked = branch;
    this.pathStack.pop();
  }

  private titleRes(): Resource {
    if (this.pRole === 'base') {
      return $r('app.string.picker_base_title');
    }
    if (this.pRole === 'repo') {
      // repo 角色来自仓库详情分支行（Spec 071）：标题 Choose Branch + 右上 CONTRIBUTE
      return $r('app.string.picker_repo_title');
    }
    return $r('app.string.picker_head_title');
  }

  /** 分支行：浅蓝 mono 芯片 + Default 描边徽标（默认分支）+ 蓝底白勾（当前选中）；
   *  徽标与勾相互独立（官方截图选中默认分支时两者并存） */
  @Builder
  branchRow(branch: string) {
    Row() {
      Text(branch)
        .fontFamily('monospace')
        .fontSize($r('app.float.sub_text_font_size'))
        .fontColor($r('app.color.link_blue'))
        .backgroundColor($r('app.color.chip_active_bg'))
        .borderRadius($r('app.float.button_radius'))
        .padding({ left: 8, right: 8, top: 4, bottom: 4 })
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Blank()
      if (branch === this.defaultBranch) {
        Text($r('app.string.picker_default_badge'))
          .fontSize($r('app.float.body_font_size'))
          .fontColor($r('app.color.text_secondary'))
          .border({ width: 1, color: $r('app.color.divider') })
          .borderRadius(14)
          .padding({ left: 12, right: 12, top: 3, bottom: 3 })
      }
      if (branch === this.pCurrent) {
        Stack() {
          Circle()
            .width(22)
            .height(22)
            .fill($r('app.color.link_blue'))
          OctIcon({ res: $r('app.media.oct_check_16'), iconSize: 14, iconColor: $r('app.color.text_on_fill') })
        }
        .width(22)
        .height(22)
        .margin({ left: branch === this.defaultBranch ? 10 : 0 })
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .onClick((): void => this.pick(branch))
  }

  build() {
    Column() {
      // 单行头部（官方截图：✕ + 粗体标题，无仓库小字行）
      Row({ space: 4 }) {
        Stack() {
          OctIcon({ res: $r('app.media.oct_x_24'), iconSize: 20, iconColor: $r('app.color.text_primary') })
        }
        .width(44)
        .height(44)
        .accessibilityDescription($r('app.string.a11y_close'))
        .focusable(true)
        .onClick((): void => {
          this.pathStack.pop();
        })
        Text(this.titleRes())
          .fontSize($r('app.float.title_font_size'))
          .fontWeight(600)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
          .margin({ left: 4 })
        if (this.pRole === 'repo') {
          // Spec 071：CONTRIBUTE 复用新建 PR 动线（与 RepoDetail 顶栏「New pull request」同参）
          Text($r('app.string.picker_contribute'))
            .fontSize($r('app.float.body_font_size'))
            .fontWeight(600)
            .fontColor($r('app.color.link_blue'))
            .textCase(TextCase.UpperCase)
            .padding({ left: 8, right: 12, top: 10, bottom: 10 })
            .onClick((): void => {
              this.pathStack.pushPathByName('prCompare', `${this.pOwner}|${this.pName}`);
            })
        }
      }
      .width('100%')
      .height(56)
      .padding({ left: 4, right: 4 })

      // 🔍 常驻内联搜索（官方截图形态：图标 + 占位齐平，无输入框边框）
      Row({ space: 8 }) {
        OctIcon({ res: $r('app.media.oct_search_24'), iconSize: 20, iconColor: $r('app.color.text_secondary') })
        TextInput({ placeholder: $r('app.string.picker_branch_search_hint'), text: this.search })
          .layoutWeight(1)
          .height(40)
          .fontSize($r('app.float.sub_text_font_size'))
          .fontColor($r('app.color.text_primary'))
          .placeholderColor($r('app.color.text_tertiary'))
          .caretColor($r('app.color.link_blue'))
          .backgroundColor(Color.Transparent)
          // ⚠️ 必须显式归零：组件默认圆角在水平 padding=0 时会把贴边光标裁成弧形（坑）
          .borderRadius(0)
          .padding({ left: 0, right: 0 })
          .onChange((v: string) => {
            this.search = v;
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16 })

      Scroll() {
        Column() {
          if (filterBranches(this.branches, this.search).length > 0) {
            ForEach(filterBranches(this.branches, this.search), (branch: string) => {
              this.branchRow(branch)
            }, (branch: string) => branch)
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
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.card_background'))
  }
}
