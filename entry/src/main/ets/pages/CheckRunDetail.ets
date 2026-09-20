/**
 * Spec 048 Check run 详情页（官方 job 视图）：
 * 顶栏全称（「workflow 名 / job 名 (event)」列表行同款）+ 结论文案；⋮ 菜单 Refresh / Open in GitHub；
 * 步骤列表（等宽字体 + 时长）；底部 RE-RUN 黑浮钮 → 重跑弹层
 * （Enable Debug logging 开关 / RE-RUN THIS JOB / View workflow summary）。
 * 非 Actions 产出的 check run（REST 404）降级：无步骤空态 + 隐藏 RE-RUN，浏览器兜底。
 */
import { promptAction } from '@kit.ArkUI';
import { AppBar, AppBarAction } from '../components/AppBar';
import { PageShadowBar } from '../components/PageShadowBar';
import { StateView } from '../components/StateView';
import { OctIcon } from '../components/OctIcon';
import { JobDetail, JobStep, RunInfo, RERUN_PERMS, conclusionKey, durationText } from '../models/ChecksModels';
import { fetchJob, fetchRunInfo, rerunJob, rerunRun } from '../services/ChecksService';
import { ApiError, friendlyError } from '../services/GitHttpClient';
import { shareLink } from '../utils/Share';
import { resText } from '../utils/I18n';

@ComponentV2
export struct CheckRunDetailView {
  @Require @Param owner: string;
  @Require @Param name: string;
  @Require @Param checkRunId: number;
  /** 仓库权限（路由透传，来源 031 主查询 viewerPermission） */
  @Require @Param perm: string;
  /** 列表行带来的即时标题（加载中/404 兜底）与 App 图标、官方详情链接 */
  @Param jobName: string = '';
  @Param appLogo: string = '';
  @Param detailsUrl: string = '';
  @Require @Param token: string;
  @Param pathStack: NavPathStack | null = null;
  /** 返回刷新泵（应用内浏览器关回来自增 → 静默重拉 job 状态） */
  @Param refreshTick: number = 0;

  @Local job: JobDetail | null = null;
  @Local notFound: boolean = false;
  @Local loading: boolean = true;
  @Local errorMsg: string = '';
  @Local sheetOpen: boolean = false;
  @Local debugLogging: boolean = false;
  @Local run: RunInfo | null = null;
  @Local runFailed: boolean = false;
  @Local rerunSending: boolean = false;
  /** 首个 onShown tick 不重拉（aboutToAppear 已拉过） */
  private shownOnce: boolean = false;

  @Monitor('refreshTick')
  onRefreshTick(): void {
    if (this.shownOnce) {
      this.reload(true);
    }
    this.shownOnce = true;
  }

  aboutToAppear(): void {
    this.reload(false);
  }

  private async reload(silent: boolean): Promise<void> {
    if (!silent) {
      this.loading = true;
      this.errorMsg = '';
    }
    try {
      this.job = await fetchJob(this.token, this.owner, this.name, this.checkRunId);
      this.notFound = false;
      this.loading = false;
    } catch (e) {
      if (e instanceof ApiError && e.code === 404) {
        // 外部 App 的 check run：无对应 Actions job（spec 048 §五 → 空态 + 浏览器兜底）
        this.notFound = true;
        this.loading = false;
      } else if (!silent || this.job === null) {
        this.errorMsg = friendlyError(this.getUIContext(), e as Error);
        this.loading = false;
      }
    }
  }

  private canRerun(): boolean {
    return RERUN_PERMS.includes(this.perm) && this.job !== null;
  }

  /** 顶栏/分享标题：列表行带来的全称（「workflow 名 / job 名 (event)」）优先；
   *  REST job.name 是裸 job 名（pylint），不能回填顶栏（官方顶栏即全称） */
  private displayTitle(): string {
    if (this.jobName !== '') {
      return this.jobName;
    }
    return this.job !== null ? this.job.name : '';
  }

  /** 顶栏副标题：结论文案（带时长），与列表行同口径 */
  private subtitle(): string {
    const j = this.job;
    if (j === null) {
      return '';
    }
    const state = j.conclusion !== '' ? j.conclusion : j.status;
    const key = conclusionKey(state);
    const dur = durationText(j.startedAt, j.completedAt);
    if (key === 'success' && dur !== '') {
      return resText(this.getUIContext(), $r('app.string.checks_sub_success'), dur);
    }
    if (key === 'failed' && dur !== '') {
      return resText(this.getUIContext(), $r('app.string.checks_sub_failed'), dur);
    }
    if (key === 'success') {
      return resText(this.getUIContext(), $r('app.string.checks_word_success'));
    }
    if (key === 'failed') {
      return resText(this.getUIContext(), $r('app.string.checks_word_failed'));
    }
    if (key === 'cancelled') {
      return resText(this.getUIContext(), $r('app.string.checks_word_cancelled'));
    }
    if (key === 'waiting') {
      return resText(this.getUIContext(), $r('app.string.checks_word_waiting'));
    }
    if (key === 'action') {
      return resText(this.getUIContext(), $r('app.string.checks_word_action'));
    }
    return resText(this.getUIContext(), $r('app.string.checks_word_progress'));
  }

  /** 步骤图标：绿实心圆勾 / 红底白叉圆 / 其余灰点（官方步骤列表口径） */
  private stepIcon(stepState: string): Resource {
    if (stepState === 'SUCCESS') {
      return $r('app.media.oct_check_circle_fill_16');
    }
    if (stepState === 'FAILURE' || stepState === 'TIMED_OUT' || stepState === 'STARTUP_FAILURE') {
      return $r('app.media.oct_x_circle_fill_16');
    }
    return $r('app.media.oct_dot_fill_16');
  }

  private stepColor(stepState: string): ResourceColor {
    if (stepState === 'SUCCESS') {
      return $r('app.color.success_text');
    }
    if (stepState === 'FAILURE' || stepState === 'TIMED_OUT' || stepState === 'STARTUP_FAILURE') {
      return $r('app.color.danger_text');
    }
    return $r('app.color.warning_text');
  }

  /** 官方 job 页链接（REST html_url；404 降级时回落列表行 detailsUrl） */
  private pageUrl(): string {
    if (this.job !== null && this.job.htmlUrl !== '') {
      return this.job.htmlUrl;
    }
    return this.detailsUrl;
  }

  /** ⋮ 菜单：Refresh 纯文字项（官方无图标、无 Open in GitHub），点击静默重拉 job 状态。
   *  原生 bindMenu 弹层（MenuElement[]，FileTree/CodeViewer 同款通道）：宽度随内容自适应 */
  private menuItems(): MenuElement[] {
    return [
      {
        value: resText(this.getUIContext(), $r('app.string.checks_menu_refresh')),
        action: (): void => {
          this.reload(true);
        }
      }
    ];
  }

  /** 打开重跑弹层：懒取 workflow run 概要（头部 `workflow 名 #run_number`），失败隐藏该行 */
  private openRerunSheet(): void {
    this.debugLogging = false;
    this.run = null;
    this.runFailed = false;
    this.sheetOpen = true;
    const j = this.job;
    if (j === null || j.runId <= 0) {
      return;
    }
    fetchRunInfo(this.token, this.owner, this.name, j.runId)
      .then((info: RunInfo): void => {
        this.run = info;
      })
      .catch((): void => {
        this.runFailed = true;
      });
  }

  private afterRerun(): void {
    this.rerunSending = false;
    this.sheetOpen = false;
    promptAction.showToast({ message: $r('app.string.checks_rerun_started') });
  }

  /** RE-RUN THIS JOB：单 job 重跑（job 级 API 无 debug 参数，spec 048 §五）→ 回列表看排队态 */
  private rerunThisJob(): void {
    const j = this.job;
    if (j === null || this.rerunSending) {
      return;
    }
    this.rerunSending = true;
    rerunJob(this.token, this.owner, this.name, j.id)
      .then((): void => {
        this.afterRerun();
        this.pathStack?.pop();
      })
      .catch((e: Error): void => {
        this.rerunSending = false;
        promptAction.showToast({ message: friendlyError(this.getUIContext(), e) });
      });
  }

  /** View workflow summary：全部 jobs 重跑（带开关）+ 应用内浏览器看工作流页（官方副标题字面） */
  private rerunAllJobs(): void {
    const j = this.job;
    if (j === null || j.runId <= 0 || this.rerunSending) {
      return;
    }
    this.rerunSending = true;
    rerunRun(this.token, this.owner, this.name, j.runId, this.debugLogging)
      .then((): void => {
        this.afterRerun();
        this.pathStack?.pushPathByName('inAppBrowser',
          `${j.name}|https://github.com/${this.owner}/${this.name}/actions/runs/${j.runId}`);
      })
      .catch((e: Error): void => {
        this.rerunSending = false;
        promptAction.showToast({ message: friendlyError(this.getUIContext(), e) });
      });
  }

  /** 步骤行（等宽步骤名 + 灰色时长小字，行分隔线） */
  @Builder
  stepRow(stepState: string, stepName: string, stepDuration: string) {
    Column() {
      Row({ space: 10 }) {
        OctIcon({ res: this.stepIcon(stepState), iconSize: 16, iconColor: this.stepColor(stepState) })
        Column({ space: 2 }) {
          Text(stepName)
            .fontSize($r('app.float.body_font_size'))
            .fontColor($r('app.color.text_primary'))
            .fontFamily('monospace')
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
          if (stepDuration !== '') {
            Text(stepDuration)
              .fontSize($r('app.float.caption_font_size'))
              .fontColor($r('app.color.text_secondary'))
              .width('100%')
          }
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .padding({ left: 16, right: 16, top: 14, bottom: 14 })

      Divider().color($r('app.color.divider')).margin({ left: 16 })
    }
  }

  /** 重跑弹层（官方：抓取条 + workflow/job 头部 + debug 开关 + 两级重跑入口） */
  @Builder
  rerunSheet() {
    Column() {
      Row({ space: 12 }) {
        if (this.appLogo !== '') {
          Image(this.appLogo)
            .width(28)
            .height(28)
            .borderRadius(6)
            .backgroundColor($r('app.color.heat_empty'))
        }
        Column({ space: 1 }) {
          if (this.run !== null) {
            Text(`${this.run.name} #${this.run.runNumber}`)
              .fontSize($r('app.float.caption_font_size'))
              .fontColor($r('app.color.text_secondary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')
          }
          Text(this.job !== null ? this.job.name : this.jobName)
            .fontSize($r('app.float.body_font_size'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .padding({ left: 16, right: 16, top: 8, bottom: 12 })

      Divider().color($r('app.color.divider'))

      // Enable Debug logging（run 级重跑传参；单 job 重跑忽略，spec 048 §五）
      Row({ space: 8 }) {
        Text($r('app.string.checks_debug_logging'))
          .fontSize($r('app.float.body_font_size'))
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
        Toggle({ type: ToggleType.Switch, isOn: this.debugLogging })
          .onChange((isOn: boolean): void => {
            this.debugLogging = isOn;
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 6, bottom: 6 })

      // RE-RUN THIS JOB：浅蓝底蓝字全宽（官方 accent subtle 形态）
      Row() {
        Text($r('app.string.checks_rerun_this_job'))
          .fontSize($r('app.float.body_font_size'))
          .fontColor($r('app.color.link_blue'))
          .textCase(TextCase.UpperCase)
          .fontWeight(FontWeight.Medium)
      }
      .width('100%')
      .height(44)
      .justifyContent(FlexAlign.Center)
      .borderRadius(6)
      .backgroundColor($r('app.color.shortcut_blue_bg'))
      .margin({ left: 16, right: 16, top: 8 })
      .opacity(this.rerunSending ? 0.5 : 1)
      .onClick((): void => {
        this.rerunThisJob();
      })

      // View workflow summary（官方副标题字面：重跑全部 + 看工作流详情）
      Column({ space: 2 }) {
        Text($r('app.string.checks_workflow_summary'))
          .fontSize($r('app.float.sub_text_font_size'))
          .fontColor($r('app.color.text_primary'))
          .width('100%')
        Text($r('app.string.checks_workflow_summary_sub'))
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
      .padding({ left: 16, right: 16, top: 16, bottom: 16 })
      .margin({ top: 8 })
      .onClick((): void => {
        this.rerunAllJobs();
      })

      Blank()
    }
    .width('100%')
    .height('100%')
  }

  build() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Column() {
        AppBar({
          showBack: true,
          title: this.displayTitle(),
          subtitle: this.subtitle(),
          onBack: (): void => {
            this.pathStack?.pop();
          },
          actions: [
            new AppBarAction($r('app.media.oct_share_android_16'), (): void => {
              const url = this.pageUrl();
              if (url !== '') {
                shareLink(this.getUIContext(), url, this.displayTitle());
              }
            }, { a11y: $r('app.string.a11y_share') }),
            new AppBarAction($r('app.media.oct_kebab_horizontal_16'), (): void => {
            }, {
              rotate90: true, a11y: $r('app.string.a11y_more'),
              menu: this.menuItems()
            })
          ]
        })

        PageShadowBar({ show: false })

        if (this.loading || this.errorMsg !== '' || this.notFound) {
          StateView({
            loading: this.loading,
            error: this.errorMsg,
            empty: this.notFound && this.errorMsg === '' && !this.loading,
            emptyText: $r('app.string.checks_steps_empty'),
            onRetry: (): void => {
              this.reload(false);
            }
          })
        } else if (this.job !== null) {
          Scroll() {
            Column() {
              ForEach(this.job.steps, (step: JobStep) => {
                this.stepRow(step.conclusion !== '' ? step.conclusion : step.status,
                  step.name, durationText(step.startedAt, step.completedAt))
              }, (step: JobStep) => `${step.number}`)
            }
            .width('100%')
          }
          .width('100%')
          .align(Alignment.Top)
          .scrollBar(BarState.Off)
          .layoutWeight(1)
        } else {
          Blank()
        }
      }
      .width('100%')
      .height('100%')

      // 底部吸底 RE-RUN 黑浮钮（官方；权限门 READ/NONE 隐藏）
      if (this.canRerun()) {
        Row({ space: 6 }) {
          OctIcon({ res: $r('app.media.oct_sync_16'), iconSize: 14, iconColor: Color.White })
          Text($r('app.string.checks_rerun'))
            .fontSize($r('app.float.body_font_size'))
            .fontColor(Color.White)
            .textCase(TextCase.UpperCase)
            .fontWeight(FontWeight.Medium)
          OctIcon({ res: $r('app.media.oct_chevron_down_16'), iconSize: 12, iconColor: Color.White })
        }
        .height(40)
        .padding({ left: 14, right: 10 })
        .borderRadius(6)
        .backgroundColor($r('app.color.floating_btn_bg'))
        .margin({ right: 16, bottom: 24 })
        .onClick((): void => {
          this.openRerunSheet();
        })
        .bindSheet($$this.sheetOpen, (): void => {
          this.rerunSheet()
        }, {
          height: 400,
          showClose: false,
          dragBar: true,
          backgroundColor: $r('app.color.card_background'),
          onDisappear: (): void => {
            this.sheetOpen = false;
          }
        })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.card_background'))
  }
}
