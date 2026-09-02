/**
 * 工作区 PR 列表页（Spec 018）：跨仓库 Pull Requests（search type: PR）。
 * 筛选行由 WorkFilterBar（Spec 017/018 共用）承载：状态 5 项（Open/Merged/Closed/Queued/All）、
 * 归属 5 项（含 Review requested）；本页只负责列表、Checks 胶囊与查询。
 */
import { promptAction } from '@kit.ArkUI';
import { OctIcon } from '../components/OctIcon';
import { WorkFilterBar, WorkFilterOption, WorkFilterState, defaultWorkFilter } from '../components/WorkFilterBar';
import { WorkPrItem, WorkPrsPage } from '../models/WorkModels';
import { WorkService } from '../services/WorkService';
import { StateView } from '../components/StateView';
import { WorkEmptyView } from '../components/WorkEmptyView';
import { githubShortTime, timeParts, TimeParts } from '../utils/Format';
import { resText } from '../utils/I18n';

@ComponentV2
export struct WorkPrsView {
  @Param token: string = '';
  @Param pathStack: NavPathStack = new NavPathStack();
  @Local filterState: WorkFilterState = defaultWorkFilter();
  @Local prs: WorkPrItem[] = [];
  @Local cursor: string = '';
  @Local hasNextPage: boolean = false;
  @Local loading: boolean = true;
  @Local errorMsg: string = '';

  aboutToAppear(): void {
    this.refresh();
  }

  private refresh(): void {
    this.loading = true;
    this.errorMsg = '';
    WorkService.fetchPrs(this.token,
      this.filterState.state, this.filterState.scope, this.filterState.visibility,
      this.filterState.sortKey, this.filterState.orgs, this.filterState.repos, '')
      .then((page: WorkPrsPage) => {
        this.prs = page.prs;
        this.cursor = page.endCursor;
        this.hasNextPage = page.hasNextPage;
        this.loading = false;
      })
      .catch((e: Error) => {
        this.errorMsg = e.message;
        this.loading = false;
      });
  }

  private loadMore(): void {
    if (!this.hasNextPage || this.loading) {
      return;
    }
    this.loading = true;
    WorkService.fetchPrs(this.token,
      this.filterState.state, this.filterState.scope, this.filterState.visibility,
      this.filterState.sortKey, this.filterState.orgs, this.filterState.repos, this.cursor)
      .then((page: WorkPrsPage) => {
        this.prs = this.prs.concat(page.prs);
        this.cursor = page.endCursor;
        this.hasNextPage = page.hasNextPage;
        this.loading = false;
      })
      .catch((e: Error) => {
        this.errorMsg = e.message;
        this.loading = false;
      });
  }

  private onQueryChange(s: WorkFilterState): void {
    this.filterState = s;
    this.refresh();
  }

  private stringOf(res: Resource): string {
    return resText(this.getUIContext(), res);
  }

  /** 相对时间结构化数据 → 当前语言文案 */
  private timeText(parts: TimeParts | null): string {
    return parts !== null ? githubShortTime(parts) : '';
  }

  private stateOptions(): WorkFilterOption[] {
    return [
      { key: 'open', label: this.stringOf($r('app.string.issues_state_open')) },
      { key: 'merged', label: this.stringOf($r('app.string.pr_state_merged')) },
      { key: 'closed', label: this.stringOf($r('app.string.issues_state_closed')) },
      { key: 'queued', label: this.stringOf($r('app.string.pr_filter_queued')) },
      { key: 'all', label: this.stringOf($r('app.string.work_filter_all')) }
    ];
  }

  private scopeOptions(): WorkFilterOption[] {
    return [
      { key: 'created', label: this.stringOf($r('app.string.issues_filter_scope_created')) },
      { key: 'assigned', label: this.stringOf($r('app.string.issues_filter_scope_assigned')) },
      { key: 'mentioned', label: this.stringOf($r('app.string.issues_filter_scope_mentioned')) },
      { key: 'review_requested', label: this.stringOf($r('app.string.pr_filter_scope_review_requested')) },
      { key: 'involved', label: this.stringOf($r('app.string.issues_filter_scope_involved')) }
    ];
  }

  /** PR 状态图标（Spec 024：merged 紫 / open 绿 / closed 灰） */
  private prIcon(item: WorkPrItem): Resource {
    if (item.iconKey === 'merged') {
      return $r('app.media.oct_check_circle_fill_16');
    }
    return item.iconKey === 'open' ? $r('app.media.oct_git_pull_request_16') : $r('app.media.oct_x_circle_16');
  }

  private prColor(item: WorkPrItem): ResourceColor {
    if (item.iconKey === 'merged') {
      return $r('app.color.shortcut_purple_fg');
    }
    return item.iconKey === 'open' ? $r('app.color.success_text') : $r('app.color.text_tertiary');
  }

  /** Checks 胶囊文案（SUCCESS/FAILURE/PENDING；未知静默，图标由 checksIcon 提供） */
  private checksLabel(state: string): string {
    if (state === 'SUCCESS') {
      return this.stringOf($r('app.string.work_pr_checks'));
    }
    if (state === 'FAILURE' || state === 'ERROR') {
      return this.stringOf($r('app.string.work_pr_checks_failed'));
    }
    if (state === 'PENDING') {
      return this.stringOf($r('app.string.work_pr_checks_pending'));
    }
    return '';
  }

  private checksIcon(state: string): Resource {
    if (state === 'SUCCESS') {
      return $r('app.media.oct_check_16');
    }
    return $r('app.media.oct_x_16');
  }

  private checksColor(state: string): ResourceColor {
    if (state === 'SUCCESS') {
      return $r('app.color.success_text');
    }
    if (state === 'FAILURE' || state === 'ERROR') {
      return $r('app.color.danger_text');
    }
    return $r('app.color.warning_text');
  }

  private checksBg(state: string): ResourceColor {
    if (state === 'SUCCESS') {
      return $r('app.color.checks_success_bg');
    }
    if (state === 'FAILURE' || state === 'ERROR') {
      return $r('app.color.checks_failure_bg');
    }
    return $r('app.color.checks_pending_bg');
  }

  @Builder
  prCard(item: WorkPrItem) {
    Column({ space: 6 }) {
      Row() {
        OctIcon({ res: this.prIcon(item), iconSize: 18, iconColor: this.prColor(item) })
        Text(`${item.repoFullName} #${item.number}`)
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_secondary'))
          .margin({ left: 12 })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        Text(this.timeText(timeParts(item.createdAt, Date.now())))
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_secondary'))
      }
      .width('100%')

      Text(item.title)
        .fontSize($r('app.float.body_font_size'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')

      Row({ space: 8 }) {
        if (item.checksState !== '') {
          Row({ space: 4 }) {
            OctIcon({
              res: this.checksIcon(item.checksState),
              iconSize: 12,
              iconColor: this.checksColor(item.checksState)
            })
            Text(this.checksLabel(item.checksState))
              .fontSize($r('app.float.caption_font_size'))
              .fontColor(this.checksColor(item.checksState))
          }
          .padding({ left: 8, right: 8, top: 2, bottom: 2 })
          .borderRadius(12)
          .backgroundColor(this.checksBg(item.checksState))
        }
        if (item.commentCount > 0) {
          Row({ space: 4 }) {
            OctIcon({ res: $r('app.media.oct_comment_16'), iconSize: 12, iconColor: $r('app.color.text_secondary') })
            Text(`${item.commentCount}`)
              .fontSize($r('app.float.caption_font_size'))
              .fontColor($r('app.color.text_secondary'))
          }
          .padding({ left: 8, right: 8, top: 2, bottom: 2 })
          .borderRadius(12)
          .backgroundColor($r('app.color.chip_bg'))
        }
        if (item.reviewCount > 0) {
          Row({ space: 4 }) {
            OctIcon({ res: $r('app.media.oct_eye_16'), iconSize: 12, iconColor: $r('app.color.text_secondary') })
            Text(`${item.reviewCount}`)
              .fontSize($r('app.float.caption_font_size'))
              .fontColor($r('app.color.text_secondary'))
          }
          .padding({ left: 8, right: 8, top: 2, bottom: 2 })
          .borderRadius(12)
          .backgroundColor($r('app.color.chip_bg'))
        }
      }
      .width('100%')
    }
    .padding($r('app.float.card_padding'))
    .borderRadius($r('app.float.card_radius'))
    .backgroundColor($r('app.color.card_background'))
    .width('100%')
    .margin({ bottom: 8 })
  }

  build() {
    Column() {
      Row({ space: 8 }) {
        Stack() {
          OctIcon({
            res: $r('app.media.oct_arrow_left_24'),
            iconSize: 20,
            iconColor: $r('app.color.text_primary')
          })
        }
        .width(44)
        .height(44)
        .accessibilityDescription($r('app.string.a11y_back'))
        .focusable(true)
        .onClick((): void => {
          this.pathStack.pop();
        })
        Text($r('app.string.home_work_pull_requests'))
          .fontSize($r('app.float.title_font_size'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
        Stack() {
          OctIcon({
            res: $r('app.media.oct_search_24'),
            iconSize: 20,
            iconColor: $r('app.color.link_blue')
          })
        }
        .width(44)
        .height(44)
        .padding(6)
        .accessibilityDescription($r('app.string.a11y_search'))
        .focusable(true)
        .onClick((): void => {
          this.pathStack.pushPathByName('search', '');
        })
        Stack() {
          OctIcon({
            res: $r('app.media.oct_kebab_horizontal_16'),
            iconSize: 18,
            iconColor: $r('app.color.link_blue')
          })
          .rotate({ angle: 90 })
        }
        .width(44)
        .height(44)
        .padding(6)
        .accessibilityDescription($r('app.string.a11y_more'))
        .focusable(true)
        .onClick((): void => {
          promptAction.showToast({ message: $r('app.string.home_feature_coming') });
        })
      }
      .width('100%')
      .height(48)
      .padding({ left: 16, right: 12 })

      Scroll() {
        Column() {
          WorkFilterBar({
            token: this.token,
            stateOptions: this.stateOptions(),
            scopeOptions: this.scopeOptions(),
            onQueryChange: (s: WorkFilterState): void => this.onQueryChange(s)
          })

          if (this.prs.length > 0) {
            ForEach(this.prs, (item: WorkPrItem) => {
              this.prCard(item)
            }, (item: WorkPrItem) => item.id)
            if (this.hasNextPage) {
              Text($r('app.string.issues_load_more'))
                .fontSize($r('app.float.body_font_size'))
                .fontColor($r('app.color.link_blue'))
                .padding(12)
                .onClick(() => this.loadMore())
            }
          } else if (this.loading || this.errorMsg !== '') {
            StateView({
              loading: this.loading,
              error: this.errorMsg,
              onRetry: () => this.refresh()
            })
          } else {
            WorkEmptyView({
              iconText: '🐱',
              title: $r('app.string.work_prs_empty'),
              subtitle: $r('app.string.work_use_fewer_filters')
            })
          }
        }
        .padding({ left: 16, right: 16, bottom: 16 })
        .width('100%')
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_page'))
  }
}
