/**
 * Search 页（Spec 015 v2）：
 * - 空态「Find your stuff.」（无输入且无历史）
 * - Recent searches 历史（CLEAR 清空；仅清空输入后且存在历史时替代空态）
 * - qualifier chips（输入框聚焦键盘弹起时底部横排：repo/user/org/path/symbol）
 * - 六类建议入口 + Jump to "q"；点击入口行 → SearchResults 结果页
 */
import { common } from '@kit.AbilityKit';
import { promptAction, KeyboardAvoidMode } from '@kit.ArkUI';
import { OctIcon } from '../components/OctIcon';
import { PageShadowBar } from '../components/PageShadowBar';
import {
  SearchService, QUALIFIER_CHIPS, pushSearchHistory, SearchHistoryStore,
  buildQualifierInsert, JUMP_TO_NO_MATCH
} from '../services/SearchService';
import { friendlyError, ApiError } from '../services/GitHttpClient';
import { resText } from '../utils/I18n';

@ComponentV2
export struct SearchView {
  @Param token: string = '';
  /** Spec 049a：搜索历史按账号分区（`recent_{login}`） */
  @Param login: string = '';
  @Param pathStack: NavPathStack = new NavPathStack();
  @Local keyword: string = '';
  @Local focused: boolean = false;
  @Local history: string[] = [];
  @Local historyReady: boolean = false;
  /** 滚动顶部阴影（滚动中显示、回顶消失） */
  @Local scrollShadow: boolean = false;

  aboutToAppear(): void {
    // 键盘避让改压缩模式：快捷词汇行贴键盘显示（官方行为）；离开恢复默认上抬
    this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.RESIZE);
    this.loadHistory();
  }

  aboutToDisappear(): void {
    this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.OFFSET);
  }

  private ctx(): common.Context | undefined {
    return this.getUIContext().getHostContext() as common.Context;
  }

  private loadHistory(): void {
    SearchHistoryStore.load(this.ctx(), this.login).then((h: string[]) => {
      // 会话内新词置顶合并，防 load 晚到覆盖本轮输入（review E12）
      const fresh = this.history.filter((x: string) => !h.includes(x));
      this.history = fresh.concat(h);
      this.historyReady = true;
    });
  }

  private onSearchInput(v: string): void {
    this.keyword = v;
  }

  private clearKeyword(): void {
    this.keyword = '';
  }

  /** qualifier chip：把「repo:」等前缀插入当前输入（保持键盘） */
  private insertQualifier(chip: string): void {
    this.keyword = buildQualifierInsert(this.keyword, chip);
  }

  /** 记录历史：去重置顶、上限 10（同步内存 + 异步持久化） */
  private rememberKeyword(kw: string): void {
    this.history = pushSearchHistory(this.history, kw);
    SearchHistoryStore.save(this.ctx(), this.login, this.history);
  }

  private clearHistory(): void {
    this.history = [];
    SearchHistoryStore.save(this.ctx(), this.login, []);
  }

  /** 建议入口（六类）→ 结果页 */
  private openResults(kind: string): void {
    const kw = this.keyword.trim();
    if (kw === '') {
      return;
    }
    this.rememberKeyword(kw);
    this.pathStack.pushPathByName('searchResults', `${kind}|${kw}`);
  }

  /** 回车 → 聚合结果页（官方行为：直进全部类型结果） */
  private openOverview(): void {
    const kw = this.keyword.trim();
    if (kw === '') {
      return;
    }
    this.rememberKeyword(kw);
    this.pathStack.pushPathByName('searchOverview', kw);
  }

  /** Jump to：J1 首个匹配仓库 → 详情页；无匹配 toast */
  private jumpTo(): void {
    const kw = this.keyword.trim();
    if (kw === '') {
      return;
    }
    SearchService.fetchJumpToRepo(this.token, kw)
      .then((full: string) => {
        this.rememberKeyword(kw);
        this.pathStack.pushPathByName('repoDetail', full);
      })
      .catch((e: Error) => {
        // 无匹配与网络/权限失败分开：前者给专用文案，后者不再伪装成「无结果」（review E16）
        const message = e instanceof ApiError && e.code === JUMP_TO_NO_MATCH
          ? resText(this.getUIContext(), $r('app.string.search_jump_no_match'))
          : friendlyError(this.getUIContext(), e);
        promptAction.showToast({ message: message });
      });
  }

  /** 历史行回填关键词（回到建议列表） */
  private useHistory(kw: string): void {
    this.keyword = kw;
  }

  private stringOf(res: Resource): string {
    return resText(this.getUIContext(), res);
  }

  /** 建议行文案（Spec 015：Code/Repos/Issues/PRs/People/Orgs with "q"） */
  private suggestionLabel(type: string): string {
    const ui = this.getUIContext();
    const kw = this.keyword.trim();
    switch (type) {
      case 'code':
        return resText(ui, $r('app.string.search_suggestion_code'), kw);
      case 'repositories':
        return resText(ui, $r('app.string.search_suggestion_repositories'), kw);
      case 'issues':
        return resText(ui, $r('app.string.search_suggestion_issues'), kw);
      case 'prs':
        return resText(ui, $r('app.string.search_suggestion_prs'), kw);
      case 'people':
        return resText(ui, $r('app.string.search_suggestion_people'), kw);
      case 'orgs':
        return resText(ui, $r('app.string.search_suggestion_orgs'), kw);
      default:
        return type;
    }
  }

  private suggestionIcon(type: string): Resource {
    switch (type) {
      case 'code':
        return $r('app.media.oct_code_16');
      case 'repositories':
        return $r('app.media.oct_repo_16');
      case 'issues':
        return $r('app.media.oct_issue_opened_16');
      case 'prs':
        return $r('app.media.oct_git_pull_request_16');
      case 'people':
        return $r('app.media.oct_person_16');
      case 'orgs':
        return $r('app.media.oct_organization_16');
      default:
        return $r('app.media.oct_search_24');
    }
  }

  @Builder
  suggestionRow(iconRes: Resource, type: string, onClick: () => void) {
    Row({ space: 14 }) {
      OctIcon({ res: iconRes, iconSize: 18, iconColor: $r('app.color.text_primary') })
        .width(28)
        .align(Alignment.Center)
      Text(this.suggestionLabel(type))
        .fontSize($r('app.float.menu_font_size'))
        .fontColor($r('app.color.text_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .height(54)
    .padding({ left: 16, right: 16 })
    .onClick(onClick)
  }

  /** 空态：Find your stuff. + 五类说明（无输入且无历史时） */
  @Builder
  emptyState() {
    Column({ space: 10 }) {
      Text($r('app.string.search_empty_title'))
        .fontSize($r('app.float.title_font_size'))
        .fontWeight(600)
        .fontColor($r('app.color.text_primary'))
      Text($r('app.string.search_empty_text'))
        .fontSize($r('app.float.menu_font_size'))
        .fontColor($r('app.color.text_secondary'))
        .textAlign(TextAlign.Center)
        .lineHeight(24)
    }
    .width('100%')
    .padding({ left: 40, right: 40 })
    .alignItems(HorizontalAlign.Center)
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
  }

  /** 历史区：Recent searches + CLEAR + 词行（点击回填，↖ 灰图标） */
  @Builder
  historyPanel() {
    Scroll() {
      Column() {
        Row() {
          Text($r('app.string.search_recent_searches'))
            .fontSize($r('app.float.menu_font_size'))
            .fontWeight(600)
            .fontColor($r('app.color.text_primary'))
          Blank()
          Text($r('app.string.search_clear_all'))
            .fontSize($r('app.float.menu_font_size'))
            .fontColor($r('app.color.link_blue'))
            .responseRegion({ x: -6, y: -7, width: '130%', height: '147%' })
            .onClick(() => this.clearHistory())
        }
        .width('100%')
        .height(52)
        .padding({ left: 16, right: 16 })

        ForEach(this.history, (kw: string) => {
          Row({ space: 12 }) {
            Text(kw)
              .fontSize($r('app.float.menu_font_size'))
              .fontColor($r('app.color.text_primary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
            OctIcon({ res: $r('app.media.oct_arrow_up_left_16'), iconSize: 16, iconColor: $r('app.color.text_secondary') })
              .width(28)
          }
          .width('100%')
          .height(54)
          .padding({ left: 16, right: 16 })
          .onClick(() => this.useHistory(kw))
        }, (kw: string) => kw)
      }
      .width('100%')
    }
    .layoutWeight(1)
    .scrollBar(BarState.Off)
    .align(Alignment.Top)
    .onScroll((_x: number, y: number): void => { this.scrollShadow = y > 0.001; })
  }

  /** 快捷词汇行（贴键盘底部显示）：行底色浅灰、词汇矩形深灰、可左右滑动 */
  @Builder
  qualifierChips() {
    Scroll() {
      Row({ space: 8 }) {
        ForEach(QUALIFIER_CHIPS, (chip: string) => {
          Text(chip)
            .fontSize($r('app.float.chip_font_size'))
            .fontColor($r('app.color.text_primary'))
            .height(36)
            .responseRegion({ x: 0, y: -4, width: '100%', height: '122%' })
            .padding({ left: 12, right: 12 })
            .borderRadius(6)
            .backgroundColor($r('app.color.search_chip_bg'))
            .onClick(() => this.insertQualifier(chip))
        }, (chip: string) => chip)
      }
      .height(52)
      .padding({ left: 16, right: 16 })
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .backgroundColor($r('app.color.search_chips_row_bg'))
    .align(Alignment.Start)
  }

  build() {
    Column() {
      // 搜索栏（← / 输入框 / ✕ / ⋮ 竖三点蓝）
      Column() {
        Row() {
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

          TextInput({
            placeholder: this.stringOf($r('app.string.search_placeholder')),
            text: this.keyword
          })
            .layoutWeight(1)
            .height(44)
            .fontSize($r('app.float.title_font_size'))
            .fontColor($r('app.color.text_primary'))
            .caretColor($r('app.color.link_blue'))
            .backgroundColor(Color.Transparent)
            .onChange((v: string) => this.onSearchInput(v))
            .onSubmit(() => this.openOverview())
            .onFocus(() => {
              this.focused = true;
            })
            .onBlur(() => {
              this.focused = false;
            })

          if (this.keyword !== '') {
            Stack() {
              OctIcon({ res: $r('app.media.oct_x_16'), iconSize: 18, iconColor: $r('app.color.text_secondary') })
            }
            .width(44)
            .height(44)
            .accessibilityDescription($r('app.string.a11y_close'))
            .focusable(true)
            .onClick((): void => {
              this.clearKeyword();
            })
          }
          Stack() {
            OctIcon({ res: $r('app.media.oct_kebab_horizontal_16'), iconSize: 18, iconColor: $r('app.color.link_blue') })
              .rotate({ angle: 90 })
          }
          .width(44)
          .height(44)
          .accessibilityDescription($r('app.string.a11y_more'))
          .focusable(true)
          .bindMenu([
            {
              value: $r('app.string.search_menu_refresh'),
              action: (): void => this.loadHistory()
            }
          ])
        }
        .width('100%')
        .height(48)
        .padding({ left: 4, right: 4 })

      // 输入下划线（聚焦或已有输入时显示，官方样式）
      if (this.focused || this.keyword.trim() !== '') {
        Divider().strokeWidth(1).color($r('app.color.divider'))
      }
    }

    PageShadowBar({ show: this.scrollShadow })

    if (this.keyword.trim() === '') {
        if (this.historyReady && this.history.length > 0) {
          this.historyPanel()
        } else {
          this.emptyState()
        }
      } else {
        // 建议列表：六类入口 + Jump to
        Scroll() {
          Column() {
            ForEach(['code', 'repositories', 'issues', 'prs', 'people', 'orgs'], (type: string) => {
              this.suggestionRow(this.suggestionIcon(type), type,
                (): void => this.openResults(type))
            }, (type: string) => type)

            Row({ space: 14 }) {
              OctIcon({ res: $r('app.media.oct_arrow_right_16'), iconSize: 18, iconColor: $r('app.color.text_primary') })
                .width(28)
                .align(Alignment.Center)
              Text(resText(this.getUIContext(), $r('app.string.search_jump_to'), this.keyword.trim()))
                .fontSize($r('app.float.menu_font_size'))
                .fontColor($r('app.color.text_primary'))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .width('100%')
            .height(54)
            .padding({ left: 16, right: 16 })
            .onClick(() => this.jumpTo())
          }
          .width('100%')
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .align(Alignment.Top)
        .onScroll((_x: number, y: number): void => { this.scrollShadow = y > 0.001; })
      }

      // 快捷词汇行：压缩模式下置于页面底部，紧贴键盘上沿
      if (this.focused) {
        this.qualifierChips()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_page'))
  }
}
