/**
 * 工作区 Projects 列表页（Spec 020）：跨仓库 ProjectsV2（viewer.projectsV2）。
 * 范围（All projects / Owned by me）+ 状态（Open/Closed）+ 排序标签；过滤/排序均在客户端。
 */
import { promptAction } from '@kit.ArkUI';
import { OctIcon } from '../components/OctIcon';
import { WorkProjectItem, WorkProjectsPage, filterWorkProjects } from '../models/WorkModels';
import { WorkService } from '../services/WorkService';
import { StateView } from '../components/StateView';
import { WorkEmptyView } from '../components/WorkEmptyView';
import { githubShortTime, timeParts, TimeParts } from '../utils/Format';
import { resText } from '../utils/I18n';

@ComponentV2
export struct ProjectsView {
  @Param token: string = '';
  @Param pathStack: NavPathStack = new NavPathStack();
  @Local ownedOnly: boolean = false;
  @Local closedOnly: boolean = false;
  @Local allProjects: WorkProjectItem[] = [];
  @Local filtered: WorkProjectItem[] = [];
  @Local sortViewed: boolean = true;
  @Local viewedAt: Record<string, number> = {};
  @Local viewerLogin: string = '';
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
    WorkService.fetchProjects(this.token, '')
      .then((page: WorkProjectsPage) => {
        this.allProjects = page.projects;
        this.viewerLogin = page.viewerLogin;
        this.cursor = page.endCursor;
        this.hasNextPage = page.hasNextPage;
        this.applyFilters();
        this.loading = false;
      })
      .catch((e: Error) => {
        // Token scope 不足时给出可操作提示（GraphQL scopes 错误）而非裸接口错误
        const hint = e.message.indexOf('scopes') >= 0
          ? resText(this.getUIContext(), $r('app.string.work_scope_hint'), this.scopeName())
          : e.message;
        this.errorMsg = hint;
        this.loading = false;
      });
  }

  private loadMore(): void {
    if (!this.hasNextPage || this.loading) {
      return;
    }
    this.loading = true;
    WorkService.fetchProjects(this.token, this.cursor)
      .then((page: WorkProjectsPage) => {
        this.allProjects = this.allProjects.concat(page.projects);
        this.cursor = page.endCursor;
        this.hasNextPage = page.hasNextPage;
        this.applyFilters();
        this.loading = false;
      })
      .catch((e: Error) => {
        // Token scope 不足时给出可操作提示（GraphQL scopes 错误）而非裸接口错误
        const hint = e.message.indexOf('scopes') >= 0
          ? resText(this.getUIContext(), $r('app.string.work_scope_hint'), this.scopeName())
          : e.message;
        this.errorMsg = hint;
        this.loading = false;
      });
  }

  /** 客户端过滤 + 排序（纯函数在 WorkModels，便于单测） */
  private applyFilters(): void {
    this.filtered = filterWorkProjects(this.allProjects, this.ownedOnly, this.viewerLogin, this.closedOnly);
  }

  private scopeName(): string {
    return 'read:project';
  }

  private stringOf(res: Resource): string {
    return resText(this.getUIContext(), res);
  }

  private timeText(parts: TimeParts | null): string {
    return parts !== null ? githubShortTime(parts) : '';
  }

  private rangeLabel(): string {
    return this.ownedOnly
      ? this.stringOf($r('app.string.work_project_filter_mine'))
      : this.stringOf($r('app.string.work_project_filter_all'));
  }

  private statusLabel(): string {
    return this.closedOnly
      ? this.stringOf($r('app.string.issues_state_closed'))
      : this.stringOf($r('app.string.issues_state_open'));
  }

  @Builder
  filterChip(label: string, menu: MenuElement[], active: boolean) {
    Row() {
      Text(label)
        .fontSize($r('app.float.caption_font_size'))
        .fontColor(active ? $r('app.color.link_blue') : $r('app.color.text_primary'))
      OctIcon({
        res: $r('app.media.oct_chevron_down_16'),
        iconSize: 12,
        iconColor: active ? $r('app.color.link_blue') : $r('app.color.text_secondary')
      })
        .margin({ left: 4 })
    }
    .height(30)
    .padding({ left: 12, right: 10 })
    .borderRadius(12)
    .backgroundColor(active ? $r('app.color.chip_active_bg') : $r('app.color.card_background'))
    .margin({ right: 8 })
    .border({ width: 1, color: active ? $r('app.color.chip_active_border') : $r('app.color.border') })
    .bindMenu(menu)
  }

  /** 排序标签：Most recently viewed（本会话浏览记录兜底）/ Most recently updated */
  private sortLabel(): string {
    return resText(this.getUIContext(), $r('app.string.work_projects_sort_label'),
      this.stringOf(this.sortViewed ? $r('app.string.work_projects_sort_visited') : $r('app.string.work_sort_updated')));
  }

  /** Most recently viewed：按本会话点击浏览时间降序（无浏览记录视为 0）；updated 按 updatedAt 降序 */
  private visibleProjects(): WorkProjectItem[] {
    const sorted: WorkProjectItem[] = [...this.filtered];
    if (this.sortViewed) {
      sorted.sort((a: WorkProjectItem, b: WorkProjectItem) => {
        return (this.viewedAt[b.id] ?? 0) - (this.viewedAt[a.id] ?? 0);
      });
    } else {
      sorted.sort((a: WorkProjectItem, b: WorkProjectItem) => b.updatedAt.localeCompare(a.updatedAt));
    }
    return sorted;
  }

  @Builder
  projectRow(project: WorkProjectItem) {
    Row({ space: 12 }) {
      Stack() {
          OctIcon({ res: $r('app.media.oct_table_16'), iconSize: 18, iconColor: Color.White })
      }
      .width(44)
      .height(44)
      .backgroundColor($r('app.color.text_secondary'))
      .borderRadius(6)
      Column({ space: 4 }) {
        Text(project.title)
          .fontSize($r('app.float.body_font_size'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Row({ space: 6 }) {
          Text(`#${project.number}`)
            .fontSize($r('app.float.caption_font_size'))
            .fontColor($r('app.color.text_secondary'))
          Text(project.closed
            ? this.stringOf($r('app.string.issues_state_closed'))
            : this.stringOf($r('app.string.issues_state_open')))
            .fontSize($r('app.float.caption_font_size'))
            .fontColor(project.closed ? $r('app.color.text_tertiary') : $r('app.color.success_text'))
          Text(this.timeText(timeParts(project.updatedAt, Date.now())))
            .fontSize($r('app.float.caption_font_size'))
            .fontColor($r('app.color.text_secondary'))
        }
        .width('100%')
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height(64)
    .padding({ left: 12, right: 12 })
    .onClick(() => {
      this.viewedAt[project.id] = Date.now();
      promptAction.showToast({ message: $r('app.string.home_feature_coming') });
    })
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
        Text($r('app.string.nav_projects_title'))
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
        .accessibilityDescription($r('app.string.a11y_search'))
        .focusable(true)
.onClick((): void => {
            this.pathStack.pushPathByName('search', '');
          })
          .padding(6)
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
        .accessibilityDescription($r('app.string.a11y_more'))
        .focusable(true)
.onClick((): void => {
            promptAction.showToast({ message: $r('app.string.home_feature_coming') });
          })
          .padding(6)
      }
      .width('100%')
      .height(48)
      .padding({ left: 16, right: 12 })

      Scroll() {
        Column() {
          Scroll() {
          Row() {
            this.filterChip(this.rangeLabel(), [
              {
                value: this.stringOf($r('app.string.work_project_filter_all')),
                action: (): void => { this.ownedOnly = false; this.applyFilters(); }
              },
              {
                value: this.stringOf($r('app.string.work_project_filter_mine')),
                action: (): void => { this.ownedOnly = true; this.applyFilters(); }
              }
            ], this.ownedOnly)

            this.filterChip(this.statusLabel(), [
              {
                value: this.stringOf($r('app.string.issues_state_open')),
                action: (): void => { this.closedOnly = false; this.applyFilters(); }
              },
              {
                value: this.stringOf($r('app.string.issues_state_closed')),
                action: (): void => { this.closedOnly = true; this.applyFilters(); }
              }
            ], this.closedOnly)

            this.filterChip(this.sortLabel(), [
              {
                value: this.stringOf($r('app.string.work_projects_sort_visited')),
                action: (): void => { this.sortViewed = true; }
              },
              {
                value: this.stringOf($r('app.string.work_sort_updated')),
                action: (): void => { this.sortViewed = false; }
              }
            ], !this.sortViewed)
          }
          .width('100%')
          }
          .scrollable(ScrollDirection.Horizontal)
          .scrollBar(BarState.Off)
          .margin({ bottom: 12 })

          if (this.visibleProjects().length > 0) {
            ForEach(this.visibleProjects(), (project: WorkProjectItem) => {
              this.projectRow(project)
            }, (project: WorkProjectItem) => `${project.title}_${project.number}_${project.ownerLogin}`)
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
              title: $r('app.string.work_projects_empty')
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
