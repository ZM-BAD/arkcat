/**
 * Spec 048 Checks 全量页（PrDetail Status 卡「View all」落点）：
 * 按结论三档分组（失败 → 进行中 → 成功）区块头计数 + Check run 富行。
 * Details Tab 官方素材未覆盖，本期不渲染（spec 048 §五）；进页一次查询，重跑返回经 onShown tick 静默重拉。
 */
import { AppBar, AppBarAction } from '../components/AppBar';
import { PageShadowBar } from '../components/PageShadowBar';
import { StateView } from '../components/StateView';
import { CheckRunRow } from '../components/CheckRunRow';
import { StatusCheckItem } from '../models/RepoSubModels';
import { CheckGroup, groupChecks, checkGroupKey } from '../models/ChecksModels';
import { fetchPrChecks } from '../services/ChecksService';
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

  @Local items: StatusCheckItem[] = [];
  @Local loading: boolean = true;
  @Local errorMsg: string = '';
  @Local isRefreshing: boolean = false;
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
      this.items = await fetchPrChecks(this.token, this.owner, this.name, this.number);
      this.loading = false;
    } catch (e) {
      this.errorMsg = friendlyError(this.getUIContext(), e as Error);
      this.loading = false;
    } finally {
      this.isRefreshing = false;
    }
  }

  /** 分档区块头计数文案（官方「19 successful checks」词式） */
  private groupText(group: CheckGroup): string {
    if (group.key === 'success') {
      return resText(this.getUIContext(), $r('app.string.checks_count_success', group.count));
    }
    if (group.key === 'failed') {
      return resText(this.getUIContext(), $r('app.string.checks_count_failed', group.count));
    }
    return resText(this.getUIContext(), $r('app.string.checks_count_progress', group.count));
  }

  private openDetail(item: StatusCheckItem): void {
    // 路由参数：owner|name|checkRunId|perm|jobName|appLogo（'|' 分段；名称/URL 不含该分隔符）
    this.pathStack?.pushPathByName('checkRunDetail',
      `${this.owner}|${this.name}|${item.checkRunId}|${this.perm}|${item.name}|${item.appLogo}`);
  }

  @Builder
  checkGroupSection(group: CheckGroup) {
    Column() {
      // 灰底分组区块头（官方「19 successful checks」整条灰带）
      Row() {
        Text(this.groupText(group))
          .fontSize($r('app.float.sub_text_font_size'))
          .fontWeight(600)
          .fontColor($r('app.color.text_primary'))
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 10, bottom: 10 })
      .backgroundColor($r('app.color.bg_page'))

      ForEach(this.items, (item: StatusCheckItem) => {
        if (checkGroupKey(item.state) === group.key) {
          Column() {
            CheckRunRow({
              item: item,
              onOpen: (opened: StatusCheckItem): void => {
                this.openDetail(opened);
              }
            })
            Divider().color($r('app.color.divider')).margin({ left: 16 })
          }
        }
      }, (item: StatusCheckItem) => `${group.key}-${item.key}`)
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
        },
        actions: [
          new AppBarAction($r('app.media.oct_sync_16'), (): void => {
            this.reload(false);
          }, { a11y: $r('app.string.a11y_refresh') })
        ]
      })

      PageShadowBar({ show: false })

      Refresh({ refreshing: $$this.isRefreshing }) {
        Scroll() {
          Column() {
            if (this.loading || this.errorMsg !== '' || this.items.length === 0) {
              StateView({
                loading: this.loading,
                error: this.errorMsg,
                empty: !this.loading && this.errorMsg === '' && this.items.length === 0,
                emptyText: $r('app.string.checks_empty'),
                onRetry: (): void => {
                  this.reload(false);
                }
              })
            } else {
              ForEach(groupChecks(this.items.map((item: StatusCheckItem): string => item.state)),
                (group: CheckGroup) => {
                  this.checkGroupSection(group)
                }, (group: CheckGroup) => group.key)
            }
          }
          .width('100%')
        }
        .width('100%')
        .align(Alignment.Top)
        .scrollBar(BarState.Off)
        .layoutWeight(1)
      }
      .onRefreshing((): void => {
        this.reload(true);
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.card_background'))
  }
}
