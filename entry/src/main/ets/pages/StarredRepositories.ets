/**
 * Starred Repositories 页（Spec 023/035）：viewer 星标仓库（默认）；传入 login 展示目标用户星标。
 * My lists 区（+ NEW 预留，v1 恒显空态卡）+ Starred 分组（头像/名称/描述/星数/语言）。
 */
import { promptAction } from '@kit.ArkUI';
import { OctIcon } from '../components/OctIcon';
import { WorkStarredPage, WorkStarredRepoItem, WorkUserList } from '../models/WorkModels';
import { WorkService } from '../services/WorkService';
import { StateView } from '../components/StateView';
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
  /** 建议列表单选（Future ideas / My stack / Inspiration；-1=未选） */
  @Local suggestionSel: number = -1;
  @Local cursor: string = '';
  @Local hasNextPage: boolean = false;
  @Local inSearch: boolean = false;
  @Local searchQuery: string = '';
  @Local loading: boolean = true;
  @Local errorMsg: string = '';

  @Monitor('listsTick')
  onListTickChanged(): void {
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
    WorkService.fetchStarred(this.token, this.cursor, this.login)
      .then((page: WorkStarredPage) => {
        this.repos = this.repos.concat(page.repos);
        this.cursor = page.endCursor;
        this.hasNextPage = page.hasNextPage;
        this.loading = false;
      })
      .catch((e: Error) => {
        this.errorMsg = e.message;
        this.loading = false;
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

  /** 当前 sheet 仓库是否已在列表内 */
  private repoInList(list: WorkUserList): boolean {
    return this.sheetRepoId !== '' && list.repoIds.includes(this.sheetRepoId);
  }

  /** 切换仓库与某列表的成员关系：乐观更新（点击即翻转圆钮/计数），失败重取回滚 */
  private toggleListMember(list: WorkUserList): void {
    const targetMember = this.repoInList(list);
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
        repoIds: ids
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

  /** 建议列表（官方 Suggestions 三件套 + Create list 入口） */
  private static readonly LIST_SUGGESTIONS: Resource[] = [
    $r('app.string.starred_suggestion_future_ideas'),
    $r('app.string.starred_suggestion_my_stack'),
    $r('app.string.starred_suggestion_inspiration')
  ];

  @Builder
  listSheet() {
    Column() {
      if (this.lists.length > 0) {
        // 已建列表：行 = 名称 + 成员圆钮（点击整行切换），官方样式
        ForEach(this.lists, (list: WorkUserList) => {
          Row({ space: 14 }) {
            Text(list.name)
              .fontSize($r('app.float.body_font_size'))
              .fontColor($r('app.color.text_primary'))
              .layoutWeight(1)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Stack() {
              Circle()
                .width(22)
                .height(22)
                .fill(this.repoInList(list) ? $r('app.color.link_blue') : Color.Transparent)
                // Shape 外轮廓须用 stroke：通用 .border() 在 Shape 上按组件矩形外框绘制
                .stroke(this.repoInList(list) ? $r('app.color.link_blue') : $r('app.color.border'))
                .strokeWidth(1.5)
              if (this.repoInList(list)) {
                OctIcon({ res: $r('app.media.oct_check_16'), iconSize: 12, iconColor: Color.White })
              }
            }
          }
          .width('100%')
          .height(52)
          .padding({ left: 20, right: 20 })
          .onClick((): void => {
            this.toggleListMember(list);
          })
        // key 含 itemCount/成员集合：数据变更强制重建行（同 key 复用 => 闭包陈旧不刷新）
        }, (list: WorkUserList) => `${list.id}_${list.itemCount}_${list.repoIds.join(',')}`)
      } else {
        // 无列表：官方 Suggestions 三件套（已建列表后由列表行替代）
        Text($r('app.string.starred_suggestions_title'))
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
          .padding({ left: 20, top: 16, bottom: 12 })

        ForEach(StarredRepositoriesView.LIST_SUGGESTIONS, (item: Resource, index: number) => {
          Row({ space: 14 }) {
            Text(this.suggestionEmoji(index))
              .fontSize(20)
            Text(this.stringOf(item))
              .fontSize($r('app.float.body_font_size'))
              .fontColor($r('app.color.text_primary'))
              .layoutWeight(1)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Stack() {
              Circle()
                .width(22)
                .height(22)
                .fill(this.suggestionSel === index ? $r('app.color.link_blue') : Color.Transparent)
                // Shape 外轮廓须用 stroke：通用 .border() 在 Shape 上按组件矩形外框绘制
                .stroke(this.suggestionSel === index ? $r('app.color.link_blue') : $r('app.color.border'))
                .strokeWidth(1.5)
              if (this.suggestionSel === index) {
                OctIcon({ res: $r('app.media.oct_check_16'), iconSize: 12, iconColor: Color.White })
              }
            }
          }
          .width('100%')
          .height(52)
          .padding({ left: 20, right: 20 })
          .onClick((): void => {
            this.suggestionSel = this.suggestionSel === index ? -1 : index;
          })
        }, (item: Resource, index: number) => `s_${index}`)
      }

      Row({ space: 12 }) {
        OctIcon({ res: $r('app.media.oct_plus_24'), iconSize: 18, iconColor: $r('app.color.link_blue') })
        Text($r('app.string.starred_create_list'))
          .fontSize($r('app.float.body_font_size'))
          .fontColor($r('app.color.link_blue'))
      }
      .width('100%')
      .height(52)
      .padding({ left: 20, right: 20 })
      .onClick((): void => {
        // 先收 sheet 再推页，避免弹窗盖在新页面上
        this.listSheetOpen = false;
        this.pathStack.pushPathByName('createList', '');
      })
    }
    .width('100%')
  }

  /** 建议行 emoji（官方三件套） */
  private suggestionEmoji(index: number): string {
    if (index === 0) {
      return '🔮';
    }
    if (index === 1) {
      return '🪄';
    }
    return '✨';
  }

  private comingSoon(): void {
    promptAction.showToast({ message: $r('app.string.home_feature_coming') });
  }

  @Builder
  repoRow(repo: WorkStarredRepoItem) {
    Column({ space: 6 }) {
      Row({ space: 8 }) {
        if (repo.ownerAvatar !== '') {
          Image(repo.ownerAvatar)
            .width(18)
            .height(18)
            .borderRadius(9)
            .backgroundColor($r('app.color.heat_empty'))
        }
        Text(repo.ownerLogin)
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        // 图标贴触点框右上、行内容顶对齐：顶部留白与下方 star 行一致（card_padding 12）
        Stack({ alignContent: Alignment.TopEnd }) {
          OctIcon({
            res: $r('app.media.oct_kebab_horizontal_16'),
            iconSize: 15,
            iconColor: $r('app.color.text_secondary')
          })
        }
        .width(32)
        .height(32)
        .accessibilityDescription($r('app.string.a11y_more'))
        .focusable(true)
        .onClick((): void => {
          this.sheetRepoId = repo.id;
          this.fetchLists();
          this.listSheetOpen = true;
        })
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      Text(repo.name)
        .fontSize($r('app.float.body_font_size'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')

      if (repo.description !== '') {
        Text(repo.description)
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_secondary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }

      Row({ space: 8 }) {
        OctIcon({ res: $r('app.media.oct_star_fill_16'), iconSize: 12, iconColor: $r('app.color.star_gold') })
        Text(compactCount(repo.stargazerCount))
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_primary'))
        if (repo.language !== '') {
          Text('●')
            .fontSize(12)
            .fontColor(repo.languageColor !== '' ? repo.languageColor : $r('app.color.text_secondary'))
          Text(repo.language)
            .fontSize($r('app.float.caption_font_size'))
            .fontColor($r('app.color.text_secondary'))
        }
      }
      .width('100%')
    }
    .padding($r('app.float.card_padding'))
    .borderRadius($r('app.float.card_radius'))
    .backgroundColor($r('app.color.card_background'))
    .width('100%')
    .margin({ bottom: 8 })
    .onClick(() => {
      this.pathStack.pushPathByName('repoDetail', `${repo.ownerLogin}/${repo.name}`);
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
              .fontWeight(FontWeight.Bold)
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
                .fontWeight(FontWeight.Bold)
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
              this.repoRow(repo)
            }, (repo: WorkStarredRepoItem) => repo.id)
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
    // !! 双向绑定：拖拽/遮罩/回退关闭时框架回写 false，否则再点 ⋯ 无法重新打开
    .bindSheet(this.listSheetOpen!!, this.listSheet(), {
      height: 300,
      backgroundColor: $r('app.color.bg_page'),
      // 关闭钮/标题均自绘；外点自动关闭
      showClose: false
    })
  }
}
