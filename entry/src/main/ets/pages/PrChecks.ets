/**
 * Spec 048 Checks 全量页（PrDetail Status 卡「View all」落点）：
 * 官方 Overview / Details 切换卡（左侧 Overview 蓝条激活，右侧 Details）。
 * Overview=按结论三档分组（失败→进行中→成功）区块头计数，行带 App 图标+全称；
 * Details=按 workflow run 分组（组头=App 图标·workflow 名·SUMMARY→run 汇总页），
 * 组内裸 job 名行（官方截图 2026-09-20），白底细分隔线列表。
 * Overview 行=白色整块 + 行间灰带（无细分隔线）。
 * 进页一次查询，重跑返回经 onShown tick 静默重拉。顶栏无刷新图标（官方 Checks 页没有，
 * 2026-09-20 走查定案）——页面刷新走下拉 / onShown tick / 空态错误重试。
 */
import { AppBar } from '../components/AppBar';
import { PageShadowBar } from '../components/PageShadowBar';
import { StateView } from '../components/StateView';
import { CheckRunRow } from '../components/CheckRunRow';
import { StatusCheckItem } from '../models/RepoSubModels';
import { CheckGroup, groupChecks, checkGroupKey } from '../models/ChecksModels';
import { CheckRunGroup, PrChecksData, fetchPrChecks } from '../services/ChecksService';
import { friendlyError } from '../services/GitHttpClient';
import { resText } from '../utils/I18n';

@ComponentV2
export struct PrChecksView {
  @Require @Param owner: string;
  @Require @Param name: string;
  @Require @Param number: number;
  @Require @Param token: string;
  @Require @Param perm: string;
  @Param pathStack: NavPathStack | null = null;
  /** 返回刷新泵（详情页重跑后 pop 回自增；Index 侧守卫首显） */
  @Param refreshTick: number = 0;

  @Local data: PrChecksData | null = null;
  @Local loading: boolean = true;
  @Local errorMsg: string = '';
  @Local isRefreshing: boolean = false;
  /** 切换卡（官方：左 Overview / 右 Details） */
  @Local activeTab: string = 'overview';
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

  /** silent=true 走后台重拉（保留旧数据，不闪加载态） */
  private async reload(silent: boolean): Promise<void> {
    if (!silent) {
      this.loading = true;
      this.errorMsg = '';
    }
    try {
      this.data = await fetchPrChecks(this.token, this.owner, this.name, this.number);
      this.loading = false;
    } catch (e) {
      this.errorMsg = friendlyError(this.getUIContext(), e as Error);
      this.loading = false;
    } finally {
      this.isRefreshing = false;
    }
  }

  private items(): StatusCheckItem[] {
    return this.data !== null ? this.data.checks : [];
  }

  /** Overview 分档区块头计数文案（官方「19 successful checks」词式） */
  private groupText(group: CheckGroup): string {
    const count = `${group.count}`;
    if (group.key === 'success') {
      return resText(this.getUIContext(), $r('app.string.checks_count_success'), count);
    }
    if (group.key === 'failed') {
      return resText(this.getUIContext(), $r('app.string.checks_count_failed'), count);
    }
    return resText(this.getUIContext(), $r('app.string.checks_count_progress'), count);
  }

  private openDetail(item: StatusCheckItem): void {
    // 路由参数：owner|name|checkRunId|perm|jobName|appLogo（'|' 分隔；名称/URL 不含该分隔符）
    this.pathStack?.pushPathByName('checkRunDetail',
      `${this.owner}|${this.name}|${item.checkRunId}|${this.perm}|${item.name}|${item.appLogo}`);
  }

  /** 组头 SUMMARY → workflow run 汇总页（参数 owner/name/runId|perm|appLogo；appLogo 是 URL 含 '/'，由目的页先拼回再拆） */
  private openRunSummary(group: CheckRunGroup): void {
    this.pathStack?.pushPathByName('runSummary',
      `${this.owner}/${this.name}/${group.runId}|${this.perm}|${group.appLogo}`);
  }

  /** 切换卡单元格（官方：等宽两格、文字深色、激活格 3vp 蓝条压在 1vp 灰底线上） */
  @Builder
  tabCell(key: string, title: Resource) {
    Column() {
      Text(title)
        .fontSize($r('app.float.sub_text_font_size'))
        .fontColor($r('app.color.text_primary'))
    }
    .layoutWeight(1)
    .height(48)
    .justifyContent(FlexAlign.Center)
    .border({
      width: { bottom: 3 },
      color: { bottom: this.activeTab === key ? $r('app.color.link_blue') : Color.Transparent }
    })
    .onClick((): void => {
      this.activeTab = key;
    })
  }

  /** Overview 分组区块：灰带计数头 + 白色整行块（行间灰带，无细分隔线） */
  @Builder
  checkGroupSection(group: CheckGroup) {
    Column() {
      Row() {
        Text(this.groupText(group))
          .fontSize($r('app.float.sub_text_font_size'))
          .fontWeight(600)
          .fontColor($r('app.color.text_primary'))
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })

      this.checkRows(group.key)
    }
    .width('100%')
  }

  /** 该分档下的行集合（白块整行 + 12vp 灰带间隔；副标题单行省略，官方 Checks 页口径） */
  @Builder
  checkRows(groupKey: string) {
    ForEach(this.items(), (item: StatusCheckItem) => {
      if (checkGroupKey(item.state) === groupKey) {
        Column() {
          CheckRunRow({
            item: item,
            subMaxLines: 1,
            inset: 16,
            onOpen: (opened: StatusCheckItem): void => {
              this.openDetail(opened);
            }
          })
        }
        .width('100%')
        .backgroundColor($r('app.color.card_background'))
        .margin({ bottom: 12 })
      }
    }, (item: StatusCheckItem) => `${groupKey}-${item.key}`)
  }

  /** Details 页签：按 workflow run 分组（官方截图 2026-09-20）——status 裸行 + 分组（组头+裸 job 名行），白底细线列表 */
  @Builder
  detailsSection() {
    Column() {
      ForEach(this.statusRows(), (item: StatusCheckItem) => {
        this.detailRow(item)
      }, (item: StatusCheckItem) => `st-${item.key}`)
      ForEach(this.groups(), (group: CheckRunGroup) => {
        this.groupHeader(group)
        ForEach(group.checks, (item: StatusCheckItem) => {
          this.detailRow(item)
        }, (item: StatusCheckItem) => item.key)
      }, (group: CheckRunGroup) => group.key)
    }
    .width('100%')
  }

  /** 经典 status 行（Details 裸行：无组头、无 App 图标列） */
  private statusRows(): StatusCheckItem[] {
    return this.items().filter((item: StatusCheckItem): boolean => item.checkRunId === 0);
  }

  private groups(): CheckRunGroup[] {
    return this.data !== null ? this.data.groups : [];
  }

  /** 组头：App 图标 · workflow 名（外部 App=App 名）· 右侧蓝字 SUMMARY（仅 Actions 组） */
  @Builder
  groupHeader(group: CheckRunGroup) {
    Column() {
      Row({ space: 12 }) {
        if (group.appLogo !== '') {
          Image(group.appLogo)
            .width(28)
            .height(28)
            .borderRadius(6)
            .backgroundColor($r('app.color.heat_empty'))
        } else {
          Row().width(28).height(28)
        }
        Text(group.title)
          .fontSize($r('app.float.sub_text_font_size'))
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        if (group.runId > 0) {
          Text($r('app.string.checks_details_summary'))
            .fontSize($r('app.float.caption_font_size'))
            .fontColor($r('app.color.link_blue'))
            .textCase(TextCase.UpperCase)
            .padding(8)
            .margin({ right: -8 })
            .onClick((): void => {
              this.openRunSummary(group);
            })
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .padding({ left: 16, right: 16, top: 10, bottom: 10 })

      Divider().color($r('app.color.divider'))
    }
    .width('100%')
  }

  /** Details 行：白底整行（无 App 图标列，组头已带）+ 行下细分隔线 */
  @Builder
  detailRow(item: StatusCheckItem) {
    Column() {
      CheckRunRow({
        item: item,
        subMaxLines: 1,
        inset: 16,
        showLogo: false,
        onOpen: (opened: StatusCheckItem): void => {
          this.openDetail(opened);
        }
      })
      Divider().color($r('app.color.divider'))
    }
    .width('100%')
  }

  build() {
    Column() {
      AppBar({
        showBack: true,
        title: $r('app.string.checks_appbar'),
        onBack: (): void => {
          this.pathStack?.pop();
        }
      })

      // 切换卡（官方 Overview / Details）：1vp 灰底线全宽铺底，激活格 3vp 蓝条覆盖
      Stack({ alignContent: Alignment.Bottom }) {
        Divider().color($r('app.color.divider'))
        Row() {
          this.tabCell('overview', $r('app.string.checks_tab_overview'))
          this.tabCell('details', $r('app.string.checks_tab_details'))
        }
        .width('100%')
        .height(48)
      }
      .width('100%')

      PageShadowBar({ show: false })

      // layoutWeight(1) 必须打在 Refresh 上（全库口径，Explore/CommitDetail 同款）：
      // 打在内层 Scroll 上时 Refresh 高度自适应失准，滚动视口不满剩余空间，末行被裁
      Refresh({ refreshing: $$this.isRefreshing }) {
        Scroll() {
          Column() {
            if (this.loading || this.errorMsg !== '' || this.items().length === 0) {
              StateView({
                loading: this.loading,
                error: this.errorMsg,
                empty: !this.loading && this.errorMsg === '' && this.items().length === 0,
                emptyText: $r('app.string.checks_empty'),
                onRetry: (): void => {
                  this.reload(false);
                }
              })
            } else if (this.activeTab === 'overview') {
              ForEach(groupChecks(this.items().map((item: StatusCheckItem): string => item.state)),
                (group: CheckGroup) => {
                  this.checkGroupSection(group)
                }, (group: CheckGroup) => group.key)
            } else {
              this.detailsSection()
            }
          }
          .width('100%')
        }
        .width('100%')
        .align(Alignment.Top)
        .scrollBar(BarState.Off)
      }
      .layoutWeight(1)
      .onRefreshing((): void => {
        this.reload(true);
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_page'))
  }
}
