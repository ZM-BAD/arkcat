/**
 * Spec 048 Workflow run 汇总页（Checks 页 Details 组头 SUMMARY 落点，官方截图 2026-09-20）：
 * 顶栏（share + ⋮ Refresh）+ 面包屑（App 图标 · owner/repo/workflow）+ 提交标题大字 +
 * workflow #run_number + 触发卡（event/actor/相对时长 + 短 sha + 分支胶囊）+
 * 四格统计（Status/Duration/Billable –/Artifacts）+ Jobs 区（计数 + job 行 → Check run 详情）
 * + 底部 RE-RUN ▾（run 级弹层：Enable Debug logging + RE-RUN ALL JOBS）。
 * 数据 REST /actions/runs/{id}(+/jobs+/artifacts)，GitHub 特有端点收敛 ChecksService。
 */
import { promptAction } from '@kit.ArkUI';
import { AppBar, AppBarAction } from '../components/AppBar';
import { PageShadowBar } from '../components/PageShadowBar';
import { StateView } from '../components/StateView';
import { OctIcon } from '../components/OctIcon';
import { JobDetail, RERUN_PERMS, conclusionKey, durationText } from '../models/ChecksModels';
import { RunSummaryData, fetchRunSummary, rerunRun } from '../services/ChecksService';
import { friendlyError } from '../services/GitHttpClient';
import { githubShortTime, timeParts } from '../utils/Format';
import { shareLink } from '../utils/Share';
import { resText } from '../utils/I18n';

@ComponentV2
export struct RunSummaryView {
  @Require @Param owner: string;
  @Require @Param name: string;
  @Require @Param runId: number;
  /** 仓库权限（路由透传，RE-RUN 权限门） */
  @Require @Param perm: string;
  /** Details 组头带来的 App 图标（面包屑） */
  @Param appLogo: string = '';
  @Require @Param token: string;
  @Param pathStack: NavPathStack | null = null;
  /** 返回刷新泵（job 详情重跑后 pop 回自增 → 静默重拉） */
  @Param refreshTick: number = 0;

  @Local run: RunSummaryData | null = null;
  @Local loading: boolean = true;
  @Local errorMsg: string = '';
  @Local sheetOpen: boolean = false;
  @Local debugLogging: boolean = false;
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
      this.run = await fetchRunSummary(this.token, this.owner, this.name, this.runId);
      this.loading = false;
    } catch (e) {
      this.errorMsg = friendlyError(this.getUIContext(), e as Error);
      this.loading = false;
    }
  }

  private canRerun(): boolean {
    return RERUN_PERMS.includes(this.perm) && this.run !== null;
  }

  /** 面包屑头像：login（owner）用户头像优先（官方口径，非 App 图标），REST 取失回落组头 App 图标 */
  private breadcrumbAvatar(): string {
    const r = this.run;
    if (r !== null && r.ownerAvatar !== '') {
      return r.ownerAvatar;
    }
    return this.appLogo;
  }

  /** 顶栏 share 标题：workflow 名 #run_number */
  private runTitle(): string {
    const r = this.run;
    return r !== null ? `${r.workflowName} #${r.runNumber}` : '';
  }

  /** 事件词：push→commit、pull_request→pull request，其余显示原词（走查校正） */
  private eventWord(event: string): string {
    if (event === 'push') {
      return resText(this.getUIContext(), $r('app.string.run_event_commit'));
    }
    if (event === 'pull_request') {
      return resText(this.getUIContext(), $r('app.string.run_event_pull_request'));
    }
    return event;
  }

  /** 相对时长（githubShortTime 短词 + pr_time_ago 后缀，全站同款「2d ago」/「2d前」） */
  private agoText(iso: string): string {
    const parts = timeParts(iso, Date.now());
    if (parts === null) {
      return '';
    }
    return `${githubShortTime(parts)}${resText(this.getUIContext(), $r('app.string.pr_time_ago'))}`;
  }

  /** 结论分档词（Status 统计格用） */
  private stateWord(state: string): string {
    const key = conclusionKey(state);
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

  /** job 行副标题：结论+时长（与 CheckRunRow 同口径：title 缺省走结论模板） */
  private jobSubtitle(job: JobDetail): string {
    const state = job.conclusion !== '' ? job.conclusion : job.status;
    const key = conclusionKey(state);
    const dur = durationText(job.startedAt, job.completedAt);
    if (key === 'success') {
      return dur !== '' ? resText(this.getUIContext(), $r('app.string.checks_sub_success'), dur)
        : resText(this.getUIContext(), $r('app.string.checks_word_success'));
    }
    if (key === 'failed') {
      return dur !== '' ? resText(this.getUIContext(), $r('app.string.checks_sub_failed'), dur)
        : resText(this.getUIContext(), $r('app.string.checks_word_failed'));
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

  /** Jobs 计数副标题（官方「1 passed」词式：按 conclusion 计数拼句） */
  private jobsCountText(): string {
    const r = this.run;
    if (r === null) {
      return '';
    }
    let passed = 0;
    let failed = 0;
    let running = 0;
    for (const j of r.jobs) {
      const key = conclusionKey(j.conclusion !== '' ? j.conclusion : j.status);
      if (key === 'success') {
        passed += 1;
      } else if (key === 'failed') {
        failed += 1;
      } else {
        running += 1;
      }
    }
    const parts: string[] = [];
    if (passed > 0) {
      parts.push(resText(this.getUIContext(), $r('app.string.checks_jobs_passed'), `${passed}`));
    }
    if (failed > 0) {
      parts.push(resText(this.getUIContext(), $r('app.string.checks_jobs_failed'), `${failed}`));
    }
    if (running > 0) {
      parts.push(resText(this.getUIContext(), $r('app.string.checks_jobs_running'), `${running}`));
    }
    return parts.join(', ');
  }

  /** job 行状态图标（绿实心圆勾 / 红底白叉 / 灰点，与步骤列表同口径） */
  private jobIcon(state: string): Resource {
    if (state === 'SUCCESS') {
      return $r('app.media.oct_check_circle_fill_16');
    }
    if (state === 'FAILURE' || state === 'TIMED_OUT' || state === 'STARTUP_FAILURE') {
      return $r('app.media.oct_x_circle_fill_16');
    }
    return $r('app.media.oct_dot_fill_16');
  }

  private jobColor(state: string): ResourceColor {
    if (state === 'SUCCESS') {
      return $r('app.color.success_text');
    }
    if (state === 'FAILURE' || state === 'TIMED_OUT' || state === 'STARTUP_FAILURE') {
      return $r('app.color.danger_text');
    }
    return $r('app.color.warning_text');
  }

  /** Jobs 行 → Check run 详情（全称现拼「workflow 名 / job 名 (event)」，官方 job 顶栏口径） */
  private openJob(job: JobDetail): void {
    const r = this.run;
    if (r === null) {
      return;
    }
    const displayName = `${r.workflowName} / ${job.name} (${this.eventWord(r.event)})`;
    this.pathStack?.pushPathByName('checkRunDetail',
      `${this.owner}|${this.name}|${job.id}|${this.perm}|${displayName}|${this.appLogo}|${job.htmlUrl}`);
  }

  private rerunAllJobs(): void {
    if (this.rerunSending) {
      return;
    }
    this.rerunSending = true;
    rerunRun(this.token, this.owner, this.name, this.runId, this.debugLogging)
      .then((): void => {
        this.rerunSending = false;
        this.sheetOpen = false;
        promptAction.showToast({ message: $r('app.string.checks_rerun_started') });
        this.reload(true);
      })
      .catch((e: Error): void => {
        this.rerunSending = false;
        promptAction.showToast({ message: friendlyError(this.getUIContext(), e) });
      });
  }

  /** ⋮ 菜单：Refresh 纯文字项（原生 bindMenu，同 Check run 详情页），静默重拉 */
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

  /** 四格统计列（标签 + 值，竖线分格由相邻 Divider 提供） */
  @Builder
  statCell(label: Resource, value: string) {
    Column({ space: 3 }) {
      Text(label)
        .fontSize($r('app.float.caption_font_size'))
        .fontColor($r('app.color.text_secondary'))
        .maxLines(1)
      Text(value)
        .fontSize($r('app.float.body_font_size'))
        .fontColor($r('app.color.text_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .alignItems(HorizontalAlign.Start)
    .layoutWeight(1)
    .padding({ left: 14, right: 6 })
  }

  /** Jobs 行：状态圆图标 · job 名 · 结论时长 */
  @Builder
  jobRow(job: JobDetail) {
    Column() {
      Row({ space: 12 }) {
        OctIcon({
          res: this.jobIcon(job.conclusion !== '' ? job.conclusion : job.status),
          iconSize: 20,
          iconColor: this.jobColor(job.conclusion !== '' ? job.conclusion : job.status)
        })
        Column({ space: 2 }) {
          Text(job.name)
            .fontSize($r('app.float.sub_text_font_size'))
            .fontColor($r('app.color.text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
          Text(this.jobSubtitle(job))
            .fontSize($r('app.float.body_font_size'))
            .fontColor($r('app.color.text_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .onClick((): void => {
        this.openJob(job);
      })

      Divider().color($r('app.color.divider'))
    }
    .width('100%')
  }

  build() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Column() {
        AppBar({
          showBack: true,
          title: '',
          onBack: (): void => {
            this.pathStack?.pop();
          },
          actions: [
            new AppBarAction($r('app.media.oct_share_android_16'), (): void => {
              const r = this.run;
              if (r !== null && r.htmlUrl !== '') {
                shareLink(this.getUIContext(), r.htmlUrl, this.runTitle());
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

        if (this.loading || this.errorMsg !== '') {
          StateView({
            loading: this.loading,
            error: this.errorMsg,
            onRetry: (): void => {
              this.reload(false);
            }
          })
        } else if (this.run !== null) {
          Scroll() {
            Column() {
              // 白底头部块：面包屑 + 提交标题 + run 号 + 触发卡 + 四格统计
              Column() {
                Row({ space: 8 }) {
                  // login 头像，与正文行高一致（官方面包屑口径 20）
                  if (this.breadcrumbAvatar() !== '') {
                    Image(this.breadcrumbAvatar())
                      .width(20)
                      .height(20)
                      .borderRadius(4)
                      .backgroundColor($r('app.color.heat_empty'))
                  }
                  Text(`${this.owner} / ${this.name} / ${this.run.workflowName}`)
                    .fontSize($r('app.float.body_font_size'))
                    .fontColor($r('app.color.text_secondary'))
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .layoutWeight(1)
                }
                .width('100%')
                .padding({ left: 16, right: 16, top: 8, bottom: 4 })

                Text(this.run.displayTitle)
                  .fontSize($r('app.float.title_font_size'))
                  .fontWeight(600)
                  .fontColor($r('app.color.text_primary'))
                  .maxLines(4)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .width('100%')
                  .padding({ left: 16, right: 16, top: 4 })

                Text(this.runTitle())
                  .fontSize($r('app.float.body_font_size'))
                  .fontColor($r('app.color.text_secondary'))
                  .width('100%')
                  .padding({ left: 16, right: 16, top: 4, bottom: 12 })

                // 触发 + 四格统计合并为一框（中间横线分割）；外层 padding 使框距屏缘 16
                // （框上直接 width('100%')+margin 会超出右缘，规范用包裹层内缩）
                Column() {
                  Column() {
                    // 上半：触发区 event/actor/相对时长 + 短 sha（等宽）+ 分支胶囊
                    Column({ space: 10 }) {
                      Text() {
                        Span(resText(this.getUIContext(), $r('app.string.checks_run_via'),
                          this.eventWord(this.run.event)))
                        Span(resText(this.getUIContext(), $r('app.string.checks_run_by')))
                        Span(this.run.actorLogin)
                          .fontWeight(600)
                          .fontColor($r('app.color.text_primary'))
                        if (this.agoText(this.run.createdAt) !== '') {
                          Span(` ${this.agoText(this.run.createdAt)}`)
                        }
                      }
                      .fontSize($r('app.float.body_font_size'))
                      .fontColor($r('app.color.text_secondary'))
                      .width('100%')

                      Row({ space: 8 }) {
                        OctIcon({ res: $r('app.media.oct_git_commit_16'), iconSize: 14,
                          iconColor: $r('app.color.text_secondary') })
                        Text(this.run.headSha !== '' ? this.run.headSha.slice(0, 7) : '')
                          .fontSize($r('app.float.body_font_size'))
                          .fontColor($r('app.color.text_primary'))
                          .fontFamily('monospace')
                        if (this.run.headBranch !== '') {
                          Row({ space: 4 }) {
                            OctIcon({ res: $r('app.media.oct_git_branch_16'), iconSize: 12,
                              iconColor: $r('app.color.text_secondary') })
                            Text(this.run.headBranch)
                              .fontSize($r('app.float.caption_font_size'))
                              .fontColor($r('app.color.text_secondary'))
                              .maxLines(1)
                              .textOverflow({ overflow: TextOverflow.Ellipsis })
                          }
                          .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                          .borderRadius(12)
                          .border({ width: 1, color: $r('app.color.divider') })
                        }
                      }
                      .width('100%')
                    }
                    .alignItems(HorizontalAlign.Start)
                    .width('100%')
                    .padding(14)

                    Divider().color($r('app.color.divider'))

                    // 下半：四格统计 Status / Duration / Billable time（恒 –）/ Artifacts
                    Row() {
                      this.statCell($r('app.string.run_stats_status'),
                        this.stateWord(this.run.conclusion !== '' ? this.run.conclusion : this.run.status))
                      Divider().vertical(true).height(30).color($r('app.color.divider'))
                      this.statCell($r('app.string.run_stats_duration'),
                        durationText(this.run.startedAt, this.run.completedAt) !== ''
                          ? durationText(this.run.startedAt, this.run.completedAt) : '–')
                      Divider().vertical(true).height(30).color($r('app.color.divider'))
                      this.statCell($r('app.string.run_stats_billable'), '–')
                      Divider().vertical(true).height(30).color($r('app.color.divider'))
                      this.statCell($r('app.string.run_stats_artifacts'),
                        this.run.artifacts > 0 ? `${this.run.artifacts}` : '–')
                    }
                    .width('100%')
                    .padding({ top: 10, bottom: 10 })
                  }
                  .width('100%')
                  .borderRadius(8)
                  .border({ width: 1, color: $r('app.color.divider') })
                }
                .width('100%')
                .padding({ left: 16, right: 16 })
                .margin({ bottom: 16 })
              }
              .width('100%')
              .backgroundColor($r('app.color.card_background'))

              // Jobs 区（官方「Jobs / 1 passed」+ 白底 job 行）
              Column() {
                Row({ space: 8 }) {
                  Text($r('app.string.checks_jobs_title'))
                    .fontSize($r('app.float.sub_text_font_size'))
                    .fontWeight(600)
                    .fontColor($r('app.color.text_primary'))
                }
                .width('100%')
                .padding({ left: 16, right: 16, top: 12, bottom: 2 })

                Text(this.jobsCountText())
                  .fontSize($r('app.float.body_font_size'))
                  .fontColor($r('app.color.text_secondary'))
                  .width('100%')
                  .padding({ left: 16, right: 16, bottom: 4 })

                ForEach(this.run.jobs, (job: JobDetail) => {
                  this.jobRow(job)
                }, (job: JobDetail) => `${job.id}`)
              }
              .width('100%')
              .backgroundColor($r('app.color.card_background'))

              // 底部留白（RE-RUN 浮钮区，bg_page 灰底同官方）
              Row().height(96).width('100%')
            }
            .width('100%')
          }
          .width('100%')
          .align(Alignment.Top)
          .scrollBar(BarState.Off)
          .layoutWeight(1)
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.bg_page'))

      // 底部吸底 RE-RUN 黑浮钮（同 Check run 详情页权限门）
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
          this.debugLogging = false;
          this.sheetOpen = true;
        })
        .bindSheet($$this.sheetOpen, (): void => {
          this.runSheet()
        }, {
          height: 280,
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
  }

  /** 重跑弹层（run 级）：Enable Debug logging + RE-RUN ALL JOBS */
  @Builder
  runSheet() {
    Column() {
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

      Row() {
        Text($r('app.string.checks_rerun_all_jobs'))
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
        this.rerunAllJobs();
      })

      Blank()
    }
    .width('100%')
    .height('100%')
  }
}
