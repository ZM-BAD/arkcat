/**
 * Starred Repositories 页（Spec 023/035）：viewer 星标仓库（默认）；传入 login 展示目标用户星标。
 * My lists 区（+ NEW 预留，v1 恒显空态卡）+ Starred 分组（头像/名称/描述/星数/语言）。
 * 仓库行组件化于 StarredRepoRow、列表成员 sheet 组件化于 StarredListSheet，
 * 本页保留拉取/分页/成员切换（乐观更新）逻辑。
 */
import { promptAction } from '@kit.ArkUI';
import { OctIcon } from '../components/OctIcon';
import { PageShadowBar } from '../components/PageShadowBar';
import { WorkStarredPage, WorkStarredRepoItem, WorkUserList } from '../models/WorkModels';
import { WorkService } from '../services/WorkService';
import { StateView } from '../components/StateView';
import { ListLoadingFooter } from '../components/ListLoadingFooter';
import { StarredRepoRow } from '../components/StarredRepoRow';
import { StarredListSheet, STARRED_SUGGESTIONS } from '../components/StarredListSheet';
import { compactCount } from '../utils/Format';
import { resText } from '../utils/I18n';

@ComponentV2
export struct StarredRepositoriesView {
  @Param token: string = '';
  @Param login: string = '';
  @Param pathStack: NavPathStack = new NavPathStack();
  /** 回页刷新信号：Index onShown 时自增，@Monitor 触发列表重取 */
  @Param listsTick: number = 0;
  @Local lists: WorkUserList[] = [];
  /** 当前打开 sheet 的仓库（membership 判断/切换用） */
  @Local sheetRepoId: string = '';
  /** 成员切换进行中（乐观更新期间防连点） */
  @Local toggling: boolean = false;
  @Local repos: WorkStarredRepoItem[] = [];
  @Local viewerLogin: string = '';
  @Local listSheetOpen: boolean = false;
  @Local searchQuery: string = '';
  @Local cursor: string = '';
  @Local hasNextPage: boolean = false;
  @Local inSearch: boolean = false;
  @Local loading: boolean = true;
  @Local errorMsg: string = '';
  /** 滚动顶部阴影（滚动中显示、回顶消失） */
  @Local scrollShadow: boolean = false;
  @Local isRefreshing: boolean = false;
  /** 触底加载更多（底部转圈指示） */
  @Local loadingMore: boolean = false;

  @Monitor('listsTick')
  onListTickChanged(): void {
    // 回页同时刷新仓库列表（review D10：详情取消星标后返回仍显示旧数据）
    this.refresh();
    this.fetchLists();
  }

  aboutToAppear(): void {
    this.refresh();
    this.fetchLists();
  }

  private refresh(): void {
    this.loading = true;
    this.errorMsg = '';
    WorkService.fetchStarred(this.token, '', this.login)
      .then((page: WorkStarredPage) => {
        // 排序后续再定：当前直接展示服务端返回顺序
        this.repos = page.repos;
        this.viewerLogin = page.viewerLogin;
        this.cursor = page.endCursor;
        this.hasNextPage = page.hasNextPage;
        this.loading = false;
        this.isRefreshing = false;
        this.loadingMore = false;
      })
      .catch((e: Error) => {
        this.errorMsg = e.message;
        this.loading = false;
        this.isRefreshing = false;
        this.loadingMore = false;
      });
  }

  private loadMore(): void {
    if (!this.hasNextPage || this.loading || this.loadingMore) {
      return;
    }
    this.loading = true;
    this.loadingMore = true;
    WorkService.fetchStarred(this.token, this.cursor, this.login)
      .then((page: WorkStarredPage) => {
        this.repos = this.repos.concat(page.repos);
        this.cursor = page.endCursor;
        this.hasNextPage = page.hasNextPage;
        this.loading = false;
        this.loadingMore = false;
      })
      .catch((e: Error) => {
        this.errorMsg = e.message;
        this.loading = false;
        this.loadingMore = false;
      });
  }

  /** 拉取 viewer 星标列表（My lists 展示 + sheet 成员状态） */
  private fetchLists(): void {
    WorkService.fetchUserLists(this.token)
      .then((lists: WorkUserList[]) => {
        this.lists = lists;
      })
      .catch(() => {
        // 列表拉取失败不影响仓库列表；sheet 内保留旧数据
      });
  }

  /** 切换仓库与某列表的成员关系：乐观更新（点击即翻转圆钮/计数），失败重取回滚 */
  private toggleListMember(list: WorkUserList): void {
    // 与原 repoInList 语义一致：sheetRepoId 为空时不视为成员（review R1-1）
    const targetMember = this.sheetRepoId !== '' && list.repoIds.includes(this.sheetRepoId);
    if (this.sheetRepoId === '' || this.toggling) {
      return;
    }
    // 本地翻转目标列表成员态与计数，UI 即时反馈
    const nextLists = this.lists.map((l: WorkUserList): WorkUserList => {
      if (l.id !== list.id) {
        return l;
      }
      const ids = l.repoIds.slice();
      const idx = ids.indexOf(this.sheetRepoId);
      if (targetMember) {
        if (idx >= 0) {
          ids.splice(idx, 1);
        }
      } else {
        ids.push(this.sheetRepoId);
      }
      return {
        id: l.id,
        name: l.name,
        description: l.description,
        itemCount: targetMember ? l.itemCount - 1 : l.itemCount + 1,
        repoIds: ids,
        repoHasNext: l.repoHasNext,
        repoCursor: l.repoCursor
      };
    });
    this.lists = nextLists;
    // mutation 全量 listIds：翻转后按新成员集发送
    const sendIds: string[] = [];
    for (const l of nextLists) {
      if (l.repoIds.includes(this.sheetRepoId)) {
        sendIds.push(l.id);
      }
    }
    this.toggling = true;
    WorkService.updateUserListsForItem(this.token, this.sheetRepoId, sendIds)
      .then(() => {
        this.toggling = false;
        this.fetchLists();
      })
      .catch((e: Error) => {
        this.toggling = false;
        promptAction.showToast({ message: e.message });
        this.fetchLists();
      });
  }

  private stringOf(res: Resource): string {
    return resText(this.getUIContext(), res);
  }

  /** 就地搜索：按仓库名过滤已加载列表（大小写不敏感） */
  private shownRepos(): WorkStarredRepoItem[] {
    const q = this.searchQuery.trim().toLowerCase();
    if (q === '') {
      return this.repos;
    }
    return this.repos.filter((r: WorkStarredRepoItem) => r.name.toLowerCase().includes(q));
  }

  private enterSearch(): void {
    this.inSearch = true;
    this.searchQuery = '';
    // 下一帧获焦，自动弹起软键盘
    setTimeout((): void => {
      this.getUIContext().getFocusController().requestFocus('work_starred_search');
    }, 60);
  }

  private exitSearch(): void {
    this.inSearch = false;
    this.searchQuery = '';
  }

  /** 官方语义：点 Suggestions 直接创建同名列表，成功后刷新（review D8） */
  private createListFromSuggestion(index: number): void {
    const name = this.stringOf(STARRED_SUGGESTIONS[index]);
    WorkService.createList(this.token, name, '')
      .then((): void => {
        this.fetchLists();
      })
      .catch((e: Error) => {
        promptAction.showToast({ message: e.message });
      });
  }

  /** 弹层（单个 bindSheet 引用，避免多 bindSheet 失效） */
  @Builder
  listSheet() {
    StarredListSheet({
      lists: this.lists,
      sheetRepoId: this.sheetRepoId,
      onToggleMember: (list: WorkUserList): void => this.toggleListMember(list),
      onCreateSuggestion: (index: number): void => this.createListFromSuggestion(index),
      onCreateList: (): void => {
        // 先收 sheet 再推页，避免弹窗盖在新页面上
        this.listSheetOpen = false;
        this.pathStack.pushPathByName('createList', '');
      }
    })
  }

  build() {
    Column() {
      // 副标题（viewer login）+ 主标题 + 操作
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
          Column() {
            TextInput({
              placeholder: this.stringOf($r('app.string.page_search_starred')),
              text: this.searchQuery
            })
              .id('work_starred_search')
              .fontSize($r('app.float.title_font_size'))
              .fontColor($r('app.color.text_primary'))
              .caretColor($r('app.color.link_blue'))
              .backgroundColor(Color.Transparent)
              .onChange((v: string) => {
                this.searchQuery = v;
              })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          .justifyContent(FlexAlign.Center)
        } else {
          Column({ space: 2 }) {
            Text(this.viewerLogin)
              .fontSize($r('app.float.caption_font_size'))
              .fontColor($r('app.color.text_secondary'))
            Text($r('app.string.nav_starred_title'))
              .fontSize($r('app.float.title_font_size'))
              .fontWeight(600)
              .fontColor($r('app.color.text_primary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
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
        .bindMenu([
          {
            value: $r('app.string.inbox_menu_refresh'),
            action: (): void => this.refresh()
          }
        ])
        .padding(6)
      }
      .width('100%')
      .height(56)
      .padding({ left: 0, right: 0 })

      PageShadowBar({ show: this.scrollShadow })

      Refresh({ refreshing: $$this.isRefreshing }) {
      Scroll() {
        Column() {
          // My lists 行（列表 API 后续 Spec，v1 展示行 + 空态卡）
          Row() {
            OctIcon({ res: $r('app.media.oct_three_bars_16'), iconSize: 16, iconColor: $r('app.color.text_secondary') })
            Text($r('app.string.work_starred_my_lists'))
              .fontSize($r('app.float.body_font_size'))
              .fontColor($r('app.color.text_primary'))
              .margin({ left: 10 })
            Blank()
            Text($r('app.string.work_starred_new'))
              .fontSize($r('app.float.body_font_size'))
              .fontColor($r('app.color.link_blue'))
              .responseRegion({ x: -6, y: -7, width: '130%', height: '147%' })
              .onClick(() => this.pathStack.pushPathByName('createList', ''))
          }
          .width('100%')
          .height(44)

          if (this.lists.length > 0) {
            // 已建列表：名称 + 数量（点击进列表详情）
            ForEach(this.lists, (list: WorkUserList) => {
              Row() {
                Text(list.name)
                  .fontSize($r('app.float.body_font_size'))
                  .fontColor($r('app.color.text_primary'))
                  .layoutWeight(1)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                Text(compactCount(list.itemCount))
                  .fontSize($r('app.float.caption_font_size'))
                  .fontColor($r('app.color.text_secondary'))
              }
              .width('100%')
              .height(48)
              .onClick((): void => {
                this.pathStack.pushPathByName('listDetail', list.id);
              })
              // key 含 itemCount：切换后计数重新渲染（同 key 复用 => 显示陈旧数量）
            }, (list: WorkUserList) => `${list.id}_${list.itemCount}`)
          } else {
            // Create your first list 空态卡
            Column({ space: 12 }) {
              Text($r('app.string.work_starred_first_list_title'))
                .fontSize(20)
                .fontWeight(600)
                .fontColor($r('app.color.text_primary'))
                .textAlign(TextAlign.Center)
                .width('100%')
              Text($r('app.string.work_starred_first_list_desc'))
                .fontSize($r('app.float.body_font_size'))
                .fontColor($r('app.color.text_secondary'))
                .textAlign(TextAlign.Center)
                .width('100%')
              Button($r('app.string.work_starred_create_list'))
                .width('100%')
                .height(44)
                .fontSize($r('app.float.caption_font_size'))
                .fontColor($r('app.color.link_blue'))
                .backgroundColor(Color.Transparent)
                .borderRadius(6)
                .border({ width: 1, color: $r('app.color.border') })
                .onClick(() => this.pathStack.pushPathByName('createList', ''))
            }
            .padding(24)
            .width('100%')
          }

          Divider()
            .color($r('app.color.divider'))
            .margin({ top: 8, bottom: 8 })

          // Starred 分组头
          Row() {
            OctIcon({ res: $r('app.media.oct_star_16'), iconSize: 18, iconColor: $r('app.color.text_secondary') })
            Text($r('app.string.home_work_starred'))
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary'))
              .margin({ left: 10 })
          }
          .width('100%')
          .height(40)

          if (this.shownRepos().length > 0) {
            ForEach(this.shownRepos(), (repo: WorkStarredRepoItem) => {
              StarredRepoRow({
                repo: repo,
                onOpenDetail: (): void => {
                  this.pathStack.pushPathByName('repoDetail', `${repo.ownerLogin}/${repo.name}`);
                },
                onOpenList: (): void => {
                  this.sheetRepoId = repo.id;
                  this.fetchLists();
                  this.listSheetOpen = true;
                }
              })
            }, (repo: WorkStarredRepoItem) => repo.id)
            if (this.hasNextPage) {
              ListLoadingFooter({ show: this.loadingMore })
            }
          } else if (this.loading || this.errorMsg !== '') {
            StateView({
              loading: this.loading,
              error: this.errorMsg,
              onRetry: () => this.refresh()
            })
          } else {
            // 空态补齐（review D9）：零星标与搜索无匹配区分文案
            StateView({
              loading: false,
              error: '',
              empty: true,
              emptyText: this.searchQuery.trim() === ''
                ? $r('app.string.starred_empty')
                : $r('app.string.search_no_results')
            })
          }
        }
        .padding({ left: 16, right: 16, bottom: 16 })
        .width('100%')
      }
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
      .onReachEnd((): void => {
        this.loadMore();
      })
      .onScroll((_x: number, y: number): void => {
        this.scrollShadow = y > 0.001;
      })
      }
      .layoutWeight(1)
      .onRefreshing((): void => {
        this.isRefreshing = true;
        this.refresh();
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_page'))
    // !! 双向绑定：拖拽/遮罩/回退关闭时框架回写 false，否则再点 ⋯ 无法重新打开
    .bindSheet(this.listSheetOpen!!, this.listSheet(), {
      height: 300,
      backgroundColor: $r('app.color.bg_page'),
      // 关闭钮/标题均自绘；外点自动关闭
      showClose: false
    })
  }
}
