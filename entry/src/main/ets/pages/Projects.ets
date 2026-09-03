/**
 * 工作区 Projects 列表页（Spec 020）：跨仓库 ProjectsV2（viewer.projectsV2）。
 * 范围（All projects / Owned by me）+ 状态（Open/Closed）+ 排序标签；过滤/排序均在客户端。
 */
import { promptAction } from '@kit.ArkUI';
import { OctIcon } from '../components/OctIcon';
import { FilterDropdownChip, FilterDropdownOption } from '../components/FilterDropdownChip';
import { WorkProjectItem, WorkProjectsPage, filterWorkProjects, sortWorkProjects } from '../models/WorkModels';
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
  /** 'open' | 'closed' | 'template' */
  @Local stateFilter: string = 'open';
  /** 'most_viewed' | 'least_viewed' | 'updated_newest' | 'updated_oldest' | 'created_newest' | 'created_oldest' | 'title_az' | 'title_za' */
  @Local sortKey: string = 'most_viewed';
  @Local allProjects: WorkProjectItem[] = [];
  @Local filtered: WorkProjectItem[] = [];
  @Local viewedAt: Record<string, number> = {};
  @Local viewerLogin: string = '';
  @Local cursor: string = '';
  @Local hasNextPage: boolean = false;
  @Local inSearch: boolean = false;
  @Local searchQuery: string = '';
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

  /** 客户端范围+三态过滤（纯函数在 WorkModels，便于单测） */
  private applyFilters(): void {
    this.filtered = filterWorkProjects(this.allProjects, this.ownedOnly, this.viewerLogin, this.stateFilter);
  }

  /** 客户端排序（Most/Least viewed 以本会话浏览记录为准） */
  /** 就地搜索：按项目标题过滤已加载列表（大小写不敏感） */
  private searchFilteredProjects(): WorkProjectItem[] {
    const q = this.searchQuery.trim().toLowerCase();
    if (q === '') {
      return this.filtered;
    }
    return this.filtered.filter((pr: WorkProjectItem) => pr.title.toLowerCase().includes(q));
  }

  /** 就地搜索默认不作用于服务端；visibleProjects 保持现有排序 */
  private visibleProjects(): WorkProjectItem[] {
    return sortWorkProjects(this.searchFilteredProjects(), this.sortKey, this.viewedAt);
  }

  private enterSearch(): void {
    this.inSearch = true;
    this.searchQuery = '';
    // 下一帧获焦，自动弹起软键盘
    setTimeout((): void => {
      this.getUIContext().getFocusController().requestFocus('work_projects_search');
    }, 60);
  }

  private exitSearch(): void {
    this.inSearch = false;
    this.searchQuery = '';
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
    if (this.stateFilter === 'closed') {
      return this.stringOf($r('app.string.issues_state_closed'));
    }
    if (this.stateFilter === 'template') {
      return this.stringOf($r('app.string.projects_filter_template'));
    }
    return this.stringOf($r('app.string.issues_state_open'));
  }

  private rangeOptions(): FilterDropdownOption[] {
    return [
      { key: 'all', label: this.stringOf($r('app.string.work_project_filter_all')) },
      { key: 'mine', label: this.stringOf($r('app.string.work_project_filter_mine')) }
    ];
  }

  /** 状态三态：open/closed/template（官方图 2；GraphQL ProjectV2State 一致） */
  private statusOptions(): FilterDropdownOption[] {
    return [
      { key: 'open', label: this.stringOf($r('app.string.issues_state_open')) },
      { key: 'closed', label: this.stringOf($r('app.string.issues_state_closed')) },
      { key: 'template', label: this.stringOf($r('app.string.projects_filter_template')) }
    ];
  }

  /** 排序 8 项（官方图 3，四组、组间细线分隔）；label 为值时，chip 由 sortLabel 加前缀 */
  private sortOptions(): FilterDropdownOption[] {
    return [
      { key: 'most_viewed', label: this.stringOf($r('app.string.work_projects_sort_visited')) },
      { key: 'least_viewed', label: this.stringOf($r('app.string.projects_sort_least_viewed')) },
      { key: 'updated_newest', label: this.stringOf($r('app.string.projects_sort_updated_newest')), isGroupStart: true },
      { key: 'updated_oldest', label: this.stringOf($r('app.string.projects_sort_updated_oldest')) },
      { key: 'created_newest', label: this.stringOf($r('app.string.projects_sort_created_newest')), isGroupStart: true },
      { key: 'created_oldest', label: this.stringOf($r('app.string.projects_sort_created_oldest')) },
      { key: 'title_az', label: this.stringOf($r('app.string.projects_sort_title_az')), isGroupStart: true },
      { key: 'title_za', label: this.stringOf($r('app.string.projects_sort_title_za')) }
    ];
  }

  private sortLabelCore(): string {
    for (const opt of this.sortOptions()) {
      if (opt.key === this.sortKey) {
        return opt.label;
      }
    }
    return this.stringOf($r('app.string.work_projects_sort_visited'));
  }

  /** 排序 chip 标签：Sort: + 当前值（官方图 3） */
  private sortLabel(): string {
    return resText(this.getUIContext(), $r('app.string.work_projects_sort_label'), this.sortLabelCore());
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
          Text(project.template
            ? this.stringOf($r('app.string.projects_filter_template'))
            : project.closed
              ? this.stringOf($r('app.string.issues_state_closed'))
              : this.stringOf($r('app.string.issues_state_open')))
            .fontSize($r('app.float.caption_font_size'))
            .fontColor(project.template || project.closed
              ? $r('app.color.text_tertiary')
              : $r('app.color.success_text'))
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
        if (this.inSearch) {
          TextInput({
            placeholder: this.stringOf($r('app.string.page_search_projects')),
            text: this.searchQuery
          })
            .id('work_projects_search')
            .layoutWeight(1)
            .height(44)
            .fontSize($r('app.float.title_font_size'))
            .fontColor($r('app.color.text_primary'))
            .caretColor($r('app.color.link_blue'))
            .backgroundColor(Color.Transparent)
            .onChange((v: string) => {
              this.searchQuery = v;
            })
        } else {
          Text($r('app.string.nav_projects_title'))
            .fontSize($r('app.float.title_font_size'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .layoutWeight(1)
        }
        if (this.inSearch) {
          Stack() {
            OctIcon({ res: $r('app.media.oct_x_16'), iconSize: 18, iconColor: $r('app.color.text_secondary') })
          }
          .width(44)
          .height(44)
          .padding(6)
          .accessibilityDescription($r('app.string.a11y_close'))
          .focusable(true)
          .onClick((): void => this.exitSearch())
        } else {
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
.onClick((): void => this.enterSearch())
          .padding(6)
        }
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
          .padding(6)
      }
      .width('100%')
      .height(48)
      .padding({ left: 0, right: 0 })

      Scroll() {
        Column() {
          Scroll() {
          Row() {
            FilterDropdownChip({
              label: this.rangeLabel(),
              active: this.ownedOnly,
              options: this.rangeOptions(),
              selectedKey: this.ownedOnly ? 'mine' : 'all',
              onPick: (key: string): void => {
                this.ownedOnly = key === 'mine';
                this.applyFilters();
              }
            })

            FilterDropdownChip({
              label: this.statusLabel(),
              active: this.stateFilter !== 'open',
              options: this.statusOptions(),
              selectedKey: this.stateFilter,
              onPick: (key: string): void => {
                this.stateFilter = key;
                this.applyFilters();
              }
            })

            FilterDropdownChip({
              label: this.sortLabel(),
              active: this.sortKey !== 'most_viewed',
              options: this.sortOptions(),
              selectedKey: this.sortKey,
              onPick: (key: string): void => {
                this.sortKey = key;
                this.applyFilters();
              }
            })
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
