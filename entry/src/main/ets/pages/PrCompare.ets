/**
 * Compare changes 页（Spec 043，官方截图驱动 2026-09-19 推倒重做）：
 * New PR 第一跳——✕ + `owner/name` 灰字 + 粗体 Compare changes 两行头部；
 * Choose branches 区块（base 默认 defaultBranchRef 芯片 / compare 未选 SELECT BRANCH）；
 * 未选 compare 展示绿圈空态卡；选定后 Changes 汇总（REST compare 分页累加 + GraphQL tip 时间）
 * + 页底 CREATE PULL REQUEST 主按钮 → Start pull request 表单（prForm）。
 */
import { OctIcon } from '../components/OctIcon';
import { StateView } from '../components/StateView';
import { RepoSubService } from '../services/RepoSubService';
import { friendlyError } from '../services/GitHttpClient';
import { BranchPickResult } from './BranchPicker';
import { RepoFormPage, CompareSummary } from '../models/RepoSubModels';
import { timeParts, TimeParts, groupDigits } from '../utils/Format';
import { resText } from '../utils/I18n';

@ComponentV2
export struct PrCompareView {
  @Param token: string = '';
  @Param pathStack: NavPathStack = new NavPathStack();
  @Param fOwner: string = '';
  @Param fName: string = '';
  /** 分支选择页 pop 回信号（Index prCompareDestination onShown tick 自增） */
  @Param refreshTick: number = 0;

  @Local repoId: string = '';
  @Local base: string = '';
  @Local head: string = '';
  @Local metaError: string = '';
  @Local changesLoading: boolean = false;
  @Local changesError: string = '';
  @Local summary: CompareSummary | null = null;
  /** head tip 提交时间（ISO，Changes 行右侧相对时间） */
  @Local tipIso: string = '';
  /** Changes 拉取代际（base/head 连续切换时丢弃过期响应） */
  private changesSeq: number = 0;
  /** 已按该参数初始化（防 aboutToAppear 与 @Monitor 双触发） */
  private loadedFor: string = '';

  aboutToAppear(): void {
    this.applyRoute();
  }

  // 路由参数晚于 aboutToAppear（坑：keyed 首拉必配 @Monitor）
  @Monitor('fOwner', 'fName')
  onRouteChanged(): void {
    this.applyRoute();
  }

  private applyRoute(): void {
    const key = `${this.fOwner}|${this.fName}`;
    if (key === this.loadedFor) {
      return;
    }
    this.loadedFor = key;
    this.base = '';
    this.head = '';
    this.repoId = '';
    this.metaError = '';
    this.resetChanges();
    this.loadMeta();
  }

  /** 分支选择页返回：消费回传槽（onShown 首显也会触发一次，槽空即忽略） */
  @Monitor('refreshTick')
  onShownTick(): void {
    if (BranchPickResult.picked === '') {
      return;
    }
    if (BranchPickResult.role === 'base') {
      this.base = BranchPickResult.picked;
    } else {
      this.head = BranchPickResult.picked;
    }
    BranchPickResult.role = '';
    BranchPickResult.picked = '';
    // base 变化同样影响 diff，统一按 head 就绪与否重拉
    this.resetChanges();
    if (this.head !== '') {
      this.loadChanges();
    }
  }

  private resetChanges(): void {
    this.changesSeq += 1;
    this.changesLoading = false;
    this.changesError = '';
    this.summary = null;
    this.tipIso = '';
  }

  /** 仓库元数据：repoId（创建用）+ 默认分支（base 初值） */
  private loadMeta(): void {
    if (this.fOwner === '' || this.fName === '') {
      return;
    }
    RepoSubService.fetchRepoForm(this.token, this.fOwner, this.fName)
      .then((page: RepoFormPage) => {
        this.repoId = page.repoId;
        this.base = page.defaultBranch;
      })
      .catch((e: Error) => {
        this.metaError = friendlyError(this.getUIContext(), e);
      });
  }

  /** Changes 汇总：REST compare 分页累加 + tip 时间（tip 失败不阻断汇总行） */
  private loadChanges(): void {
    const seq = ++this.changesSeq;
    this.changesLoading = true;
    this.changesError = '';
    this.summary = null;
    RepoSubService.fetchCompareSummary(this.token, this.fOwner, this.fName, this.base, this.head)
      .then((s: CompareSummary) => {
        if (seq !== this.changesSeq) {
          return;
        }
        this.summary = s;
        this.changesLoading = false;
      })
      .catch((e: Error) => {
        if (seq !== this.changesSeq) {
          return;
        }
        this.changesError = friendlyError(this.getUIContext(), e);
        this.changesLoading = false;
      });
    RepoSubService.fetchRefTipDate(this.token, this.fOwner, this.fName, this.head)
      .then((iso: string) => {
        if (seq === this.changesSeq) {
          this.tipIso = iso;
        }
      })
      .catch((_e: Error) => {
        // tip 时间缺失仅省略右侧相对时间
      });
  }

  private openPicker(role: string): void {
    const current = role === 'base' ? this.base : this.head;
    this.pathStack.pushPathByName('branchPicker', `${role}|${this.fOwner}|${this.fName}|${current}`);
  }

  private openStartForm(): void {
    if (this.head === '') {
      return;
    }
    this.pathStack.pushPathByName('prForm', `${this.fOwner}|${this.fName}|new|0||${this.base}|${this.head}`);
  }

  private stringOf(res: Resource): string {
    return resText(this.getUIContext(), res);
  }

  /** Changes 行右侧相对时间（官方「2 days ago」完整词形态，单复数分档） */
  private agoText(): string {
    const parts: TimeParts | null = timeParts(this.tipIso, Date.now());
    if (parts === null) {
      return '';
    }
    switch (parts.unit) {
      case 'just_now':
        return this.stringOf($r('app.string.ago_just_now'));
      case 'minute':
        return parts.value === 1
          ? this.stringOf($r('app.string.ago_min_one'))
          : this.stringOf($r('app.string.ago_min_many', parts.value));
      case 'hour':
        return parts.value === 1
          ? this.stringOf($r('app.string.ago_hour_one'))
          : this.stringOf($r('app.string.ago_hour_many', parts.value));
      case 'day':
        return parts.value === 1
          ? this.stringOf($r('app.string.ago_day_one'))
          : this.stringOf($r('app.string.ago_day_many', parts.value));
      case 'month':
        return parts.value === 1
          ? this.stringOf($r('app.string.ago_month_one'))
          : this.stringOf($r('app.string.ago_month_many', parts.value));
      case 'year':
        return parts.value === 1
          ? this.stringOf($r('app.string.ago_year_one'))
          : this.stringOf($r('app.string.ago_year_many', parts.value));
    }
    return '';
  }

  /** 两行头部：✕ + `owner/name` 灰字 + 粗体 Compare changes */
  @Builder
  pageHeader() {
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
      Column({ space: 2 }) {
        Text(`${this.fOwner}/${this.fName}`)
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_secondary'))
        Text($r('app.string.compare_title'))
          .fontSize($r('app.float.title_font_size'))
          .fontWeight(600)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ left: 4 })
    }
    .width('100%')
    .height(56)
    .padding({ left: 4, right: 4 })
  }

  /** base/compare 分支芯片（浅蓝 mono + chevron；官方截图形态）。
   *  ⚠️ 分支名必须在 Builder 内直读状态（@Builder 按值参数不刷新，坑 12） */
  @Builder
  branchChip(kind: string) {
    Row({ space: 4 }) {
      Text(kind === 'base' ? this.base : this.head)
        .fontFamily('monospace')
        .fontSize($r('app.float.sub_text_font_size'))
        .fontColor($r('app.color.link_blue'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      OctIcon({ res: $r('app.media.oct_chevron_down_16'), iconSize: 14, iconColor: $r('app.color.link_blue') })
    }
    .backgroundColor($r('app.color.chip_active_bg'))
    .borderRadius($r('app.float.button_radius'))
    .padding({ left: 8, right: 6, top: 4, bottom: 4 })
    .margin({ top: 8 })
    .onClick((): void => this.openPicker(kind))
  }

  /** 区块小标题（灰 semibold：Choose branches / Changes） */
  @Builder
  sectionTitle(res: Resource) {
    Text(res)
      .fontSize($r('app.float.body_font_size'))
      .fontWeight(600)
      .fontColor($r('app.color.text_secondary'))
  }

  /** Changes 两行汇总（files changed +A -D / commits + 相对时间） */
  @Builder
  changesRows(summary: CompareSummary) {
    Row({ space: 10 }) {
      OctIcon({ res: $r('app.media.oct_file_diff_16'), iconSize: 16, iconColor: $r('app.color.text_secondary') })
      Text(summary.files === 1
        ? this.stringOf($r('app.string.compare_files_one'))
        : this.stringOf($r('app.string.compare_files_many', groupDigits(summary.files))))
        .fontSize($r('app.float.sub_text_font_size'))
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(`+${groupDigits(summary.additions)}`)
        .fontSize($r('app.float.sub_text_font_size'))
        .fontColor($r('app.color.diff_add_fg'))
      Text(`-${groupDigits(summary.deletions)}`)
        .fontSize($r('app.float.sub_text_font_size'))
        .fontColor($r('app.color.diff_del_fg'))
        .margin({ left: 8 })
    }
    .width('100%')
    .padding({ top: 10, bottom: 10 })

    Row({ space: 10 }) {
      OctIcon({ res: $r('app.media.oct_git_commit_16'), iconSize: 16, iconColor: $r('app.color.text_secondary') })
      Text(summary.commits === 1
        ? this.stringOf($r('app.string.compare_commits_one'))
        : this.stringOf($r('app.string.compare_commits_many', groupDigits(summary.commits))))
        .fontSize($r('app.float.sub_text_font_size'))
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
      Text(this.agoText())
        .fontSize($r('app.float.sub_text_font_size'))
        .fontColor($r('app.color.text_secondary'))
    }
    .width('100%')
    .padding({ top: 10, bottom: 10 })
  }

  build() {
    Column() {
      this.pageHeader()

      Scroll() {
        Column() {
          // Choose branches 区块
          Column() {
            this.sectionTitle($r('app.string.compare_choose_branches'))
            if (this.metaError !== '') {
              Text(this.metaError)
                .fontSize($r('app.float.caption_font_size'))
                .fontColor($r('app.color.danger_text'))
                .margin({ top: 12 })
            }
            Text($r('app.string.form_base_label'))
              .fontSize($r('app.float.sub_text_font_size'))
              .fontColor($r('app.color.text_primary'))
              .margin({ top: 20 })
            this.branchChip('base')
            Text($r('app.string.compare_head_label'))
              .fontSize($r('app.float.sub_text_font_size'))
              .fontColor($r('app.color.text_primary'))
              .margin({ top: 20 })
            if (this.head === '') {
              Text($r('app.string.compare_select_branch'))
                .fontSize($r('app.float.sub_text_font_size'))
                .fontColor($r('app.color.link_blue'))
                .margin({ top: 14 })
                .onClick((): void => this.openPicker('head'))
            } else {
              this.branchChip('head')
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding(16)

          Divider()
            .strokeWidth(1)
            .color($r('app.color.divider'))

          if (this.head === '') {
            // 未选 compare 的空态卡（绿圈 git-pull-request；点击同样进选择器）
            Column({ space: 12 }) {
              Stack() {
                Circle()
                  .width(44)
                  .height(44)
                  .fill($r('app.color.success_subtle_bg'))
                OctIcon({
                  res: $r('app.media.oct_git_pull_request_16'), iconSize: 20,
                  iconColor: $r('app.color.success_text')
                })
              }
              .width(44)
              .height(44)
              Text($r('app.string.compare_empty_hint'))
                .fontSize($r('app.float.sub_text_font_size'))
                .fontWeight(600)
                .fontColor($r('app.color.text_primary'))
                .textAlign(TextAlign.Center)
                .maxLines(2)
            }
            .width('100%')
            .alignItems(HorizontalAlign.Center)
            .backgroundColor($r('app.color.bg_page'))
            .borderRadius($r('app.float.card_radius'))
            .padding({ left: 16, right: 16, top: 24, bottom: 24 })
            .margin(16)
            .onClick((): void => this.openPicker('head'))
          } else {
            // Changes 汇总区块
            Column() {
              this.sectionTitle($r('app.string.compare_changes_title'))
              if (this.changesLoading) {
                LoadingProgress()
                  .width(24)
                  .height(24)
                  .color($r('app.color.link_blue'))
                  .margin({ top: 20 })
              } else if (this.changesError !== '') {
                StateView({ error: this.changesError, onRetry: () => this.loadChanges() })
              } else if (this.summary !== null) {
                this.changesRows(this.summary)
              }
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .padding(16)

            Divider()
              .strokeWidth(1)
              .color($r('app.color.divider'))

            // 创建按钮 + 说明行（官方截图：仅选定 compare 后出现）
            Column() {
              Button($r('app.string.compare_create_btn'))
                .width('100%')
                .height($r('app.float.button_height'))
                .backgroundColor($r('app.color.success_btn_bg'))
                .fontSize($r('app.float.sub_text_font_size'))
                .onClick((): void => this.openStartForm())
              Text($r('app.string.compare_footer'))
                .fontSize($r('app.float.caption_font_size'))
                .fontColor($r('app.color.text_secondary'))
                .textAlign(TextAlign.Center)
                .width('90%')
                .margin({ top: 12 })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Center)
            .padding(16)
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
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
