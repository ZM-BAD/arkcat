/**
 * Issue 详情页（Spec 030 + 041）：标题 + 状态 + 正文（纯文本）+ 评论列表 + 底部 COMMENT 输入面板。
 */
import { promptAction } from '@kit.ArkUI';
import { OctIcon } from '../components/OctIcon';
import { AppBar, AppBarAction, AppBarActionCfg, AppBarMenuItem } from '../components/AppBar';
import { MarkdownView } from '../components/MarkdownView';
import { PageShadowBar } from '../components/PageShadowBar';
import { CommentCard } from '../components/CommentCard';
import { CommentComposer } from '../components/CommentComposer';
import { RepoComment, IssueDetailPage } from '../models/RepoSubModels';
import { RepoSubService } from '../services/RepoSubService';
import { friendlyError } from '../services/GitHttpClient';
import { StateView } from '../components/StateView';
import { ListLoadingFooter } from '../components/ListLoadingFooter';
import { githubShortTime, timeParts, TimeParts } from '../utils/Format';
import { resText } from '../utils/I18n';
import { issuePageUrl, shareLink } from '../utils/Share';

/** bindPopup onStateChange 回调类型（与 PrDetail/CommentCard 同款自声明） */
interface PopupState {
  isVisible: boolean;
}

@ComponentV2
export struct IssueDetailView {
  @Param owner: string = '';
  @Param name: string = '';
  @Param number: number = 0;
  @Param token: string = '';
  @Param pathStack: NavPathStack = new NavPathStack();
  /** 路由 onShown 递增：编辑表单（issueForm）pop 回后重拉标题/正文（Spec 043） */
  @Param refreshTick: number = 0;
  @Local detail: IssueDetailPage | null = null;
  @Local cursor: string = '';
  @Local hasNextPage: boolean = false;
  @Local loading: boolean = true;
  @Local errorMsg: string = '';
  /** 滚动顶部阴影（滚动中显示、回顶消失） */
  @Local scrollShadow: boolean = false;
  @Local isRefreshing: boolean = false;
  /** 触底加载更多（底部转圈指示） */
  @Local loadingMore: boolean = false;
  /**
   * 评论/关闭原因共用弹层（坑 2：同组件多 bindSheet 只有最后一个生效 → 单 sheet + sheetKind 分派）。
   * sheetKind：'composer'=评论输入（041），'closeReason'=关闭原因两档（043）。
   */
  @Local sheetOpen: boolean = false;
  @Local sheetKind: string = 'composer';
  @Local draft: string = '';
  @Local editingId: string = '';
  @Local editingInitial: string = '';
  /** 关闭原因（官方两档，默认 Completed） */
  @Local closeReason: string = 'COMPLETED';
  /** 正文卡 ⋯ 弹出菜单 */
  @Local bodyMenuOpen: boolean = false;
  /** 首个 onShown tick 不重拉（aboutToAppear 已拉过） */
  private skipFirstTick: boolean = true;

  aboutToAppear(): void {
    this.refresh();
  }

  @Monitor('refreshTick')
  onTick(): void {
    if (this.skipFirstTick) {
      this.skipFirstTick = false;
      return;
    }
    this.refresh();
  }

  private refresh(): void {
    this.loading = true;
    this.errorMsg = '';
    RepoSubService.fetchIssueDetail(this.token, this.owner, this.name, this.number, '')
      .then((page: IssueDetailPage) => {
        this.detail = page;
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
    if (!this.hasNextPage || this.loading || this.loadingMore || this.detail === null) {
      return;
    }
    this.loading = true;
    this.loadingMore = true;
    RepoSubService.fetchIssueDetail(this.token, this.owner, this.name, this.number, this.cursor)
      .then((page: IssueDetailPage) => {
        // 翻页只追加评论批次，整页替换会把前 20 条评论顶掉（review B4）
        const prev = this.detail;
        if (prev !== null) {
          page.comments = prev.comments.concat(page.comments);
        }
        this.detail = page;
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

  private timeText(parts: TimeParts | null): string {
    return parts !== null ? githubShortTime(parts) : '';
  }

  private stateIcon(): Resource {
    if (this.detail?.state === 'OPEN') {
      return $r('app.media.oct_issue_opened_16');
    }
    return this.detail?.stateReason === 'NOT_PLANNED'
      ? $r('app.media.oct_skip_16')
      : $r('app.media.oct_issue_closed_16');
  }

  private stateColor(): ResourceColor {
    if (this.detail?.state === 'OPEN') {
      return $r('app.color.success_text');
    }
    return this.detail?.stateReason === 'NOT_PLANNED' ? $r('app.color.text_secondary') : $r('app.color.shortcut_purple_fg');
  }

  /** MarkdownView 站内链接路由（正文/评论点击 GitHub 内部链接 → 对应页面） */
  private navigateLink(name: string, param: string): void {
    this.pathStack.pushPathByName(name, param);
  }

  private stringOf(res: Resource): string {
    return resText(this.getUIContext(), res);
  }

  /** COMMENT 按钮（打开输入面板；锁定/关闭由服务端校验兜底，与官方一致） */
  private openComposer(): void {
    if (this.detail === null) {
      return;
    }
    // GitHub 仅 locked 限制评论，closed 未锁定仍可评论（review B8：移除客户端拦截）
    this.editingId = '';
    this.editingInitial = '';
    this.sheetKind = 'composer';
    this.sheetOpen = true;
  }

  /** 弹层关闭（拖拽/遮罩/✕ 统一走 onDisappear）：清编辑态；新评论草稿保留在 @Local（重开时预填） */
  private onSheetDismissed(): void {
    this.sheetOpen = false;
    this.editingId = '';
    this.editingInitial = '';
  }

  /** 编辑表单入口（标题行 pencil / ⋯ 菜单 / 正文卡菜单，viewerCanUpdate 门控；Spec 043 元素8） */
  private openEditForm(): void {
    this.bodyMenuOpen = false;
    this.pathStack.pushPathByName('issueForm', `${this.owner}|${this.name}|edit|${this.number}`);
  }

  /** 打开关闭原因面板（官方两档：Completed / Not planned，Spec 043 元素9） */
  private openCloseSheet(): void {
    this.closeReason = 'COMPLETED';
    this.sheetKind = 'closeReason';
    this.sheetOpen = true;
  }

  /** 重开 Issue（作者或有写权限；成功后重拉状态与时间轴） */
  private reopenIssue(): void {
    if (this.detail === null) {
      return;
    }
    RepoSubService.reopenIssue(this.token, this.detail.subjectId)
      .then(() => {
        this.refresh();
      })
      .catch((e: Error) => {
        promptAction.showToast({ message: friendlyError(this.getUIContext(), e) });
      });
  }

  /** 按选中原因关闭 Issue（失败保留面板可重试） */
  private doCloseIssue(): void {
    if (this.detail === null) {
      return;
    }
    RepoSubService.closeIssue(this.token, this.detail.subjectId, this.closeReason)
      .then(() => {
        this.sheetOpen = false;
        this.refresh();
      })
      .catch((e: Error) => {
        promptAction.showToast({ message: friendlyError(this.getUIContext(), e) });
      });
  }

  /** 正文卡 Quote reply（同 PR 正文卡口径）：`> 正文` 引用进草稿并打开输入面板 */
  private quoteBody(): void {
    if (this.detail === null) {
      return;
    }
    const quoted = this.detail.body.split('\n').map((line: string): string => `> ${line}`).join('\n');
    this.draft = `${quoted}\n\n`;
    this.editingId = '';
    this.editingInitial = '';
    this.sheetKind = 'composer';
    this.sheetOpen = true;
  }

  /** 正文卡菜单 Share（与顶栏 share 同出口） */
  private shareBody(): void {
    const title = this.detail !== null ? this.detail.title : '';
    shareLink(this.getUIContext(), issuePageUrl(this.owner, this.name, this.number), title);
  }

  /** 占位型菜单项（官方有、端侧管道未接入：提示「即将上线」，勿静默失败） */
  private comingSoon(): void {
    promptAction.showToast({ message: $r('app.string.home_feature_coming') });
  }

  /** 顶栏 ⋮ 菜单（对齐 PR 顶栏口径：编辑 + 关闭/重开，viewerCanUpdate 门控） */
  private issueMenuItems(): AppBarMenuItem[] {
    const items: AppBarMenuItem[] = [];
    const d = this.detail;
    if (d !== null && d.viewerCanUpdate) {
      items.push({
        icon: $r('app.media.oct_pencil_16'),
        label: $r('app.string.menu_edit'),
        onAction: (): void => this.openEditForm()
      });
      if (d.state === 'OPEN') {
        items.push({
          icon: $r('app.media.oct_issue_closed_16'),
          label: $r('app.string.close_issue'),
          onAction: (): void => this.openCloseSheet(),
          danger: true
        });
      } else {
        items.push({
          icon: $r('app.media.oct_issue_reopened_16'),
          label: $r('app.string.reopen_issue'),
          onAction: (): void => this.reopenIssue()
        });
      }
    }
    return items;
  }

  /** 发布/编辑成功：清草稿并重拉（评论数 +1、新评论可见，服务端为权威） */
  private afterCommentSaved(): void {
    this.draft = '';
    this.refresh();
  }

  /** 删除确认（仅本人评论有入口）：二次确认 → deleteIssueComment → 刷新 */
  private confirmDeleteComment(item: RepoComment): void {
    this.getUIContext().showAlertDialog({
      title: this.stringOf($r('app.string.comment_delete_title')),
      message: this.stringOf($r('app.string.comment_delete_body')),
      autoCancel: true,
      buttons: [
        {
          value: this.stringOf($r('app.string.comment_delete_cancel')),
          action: (): void => {
          }
        },
        {
          style: DialogButtonStyle.HIGHLIGHT,
          value: this.stringOf($r('app.string.comment_delete_ok')),
          action: (): void => {
            RepoSubService.deleteComment(this.token, item.id)
              .then(() => {
                promptAction.showToast({ message: $r('app.string.comment_deleted') });
                this.refresh();
              })
              .catch((e: Error) => {
                promptAction.showToast({ message: this.stringOf($r('app.string.comment_error_delete')) + ': ' + e.message });
              });
          }
        }
      ]
    });
  }

  @Builder
  composerSheet() {
    CommentComposer({
      token: this.token,
      subjectId: this.detail?.subjectId ?? '',
      editingId: this.editingId,
      initial: this.editingId !== '' ? this.editingInitial : this.draft,
      quoteSource: this.detail !== null ? this.detail.body : '',
      previewContext: `${this.owner}/${this.name}`,
      onClose: (): void => {
        this.sheetOpen = false;
      },
      onPublished: (): void => this.afterCommentSaved(),
      onDraftChange: (t: string): void => {
        if (this.editingId === '') {
          this.draft = t;
        }
      }
    })
  }

  /** 关闭原因行（官方圆形单选，同 Merge options 行形态） */
  @Builder
  closeReasonRow(reason: string, iconRes: Resource, label: ResourceStr) {
    Row({ space: 12 }) {
      OctIcon({ res: iconRes, iconSize: 16, iconColor: $r('app.color.text_primary') })
      Text(label)
        .fontSize($r('app.float.sub_text_font_size'))
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
      Stack() {
        Circle()
          .width(20)
          .height(20)
          .fill(Color.Transparent)
          .stroke(this.closeReason === reason ? $r('app.color.link_blue') : $r('app.color.border'))
          .strokeWidth(1.5)
        if (this.closeReason === reason) {
          Circle()
            .width(10)
            .height(10)
            .fill($r('app.color.link_blue'))
        }
      }
      .width(44)
      .height(44)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding({ left: 16, right: 8, top: 4, bottom: 4 })
    .onClick((): void => {
      this.closeReason = reason;
    })
  }

  /** 关闭原因面板（官方两档 + 红色关闭钮） */
  @Builder
  closeReasonSheet() {
    Column() {
      Row({ space: 4 }) {
        Stack() {
          OctIcon({ res: $r('app.media.oct_x_24'), iconSize: 20, iconColor: $r('app.color.text_primary') })
        }
        .width(44)
        .height(44)
        .accessibilityDescription($r('app.string.a11y_back'))
        .onClick((): void => {
          this.sheetOpen = false;
        })
        Text($r('app.string.close_reason_title'))
          .fontSize($r('app.float.title_font_size'))
          .fontWeight(600)
          .fontColor($r('app.color.text_primary'))
      }
      .width('100%')
      .padding({ left: 4, right: 16 })

      this.closeReasonRow('COMPLETED', $r('app.media.oct_issue_closed_16'), $r('app.string.close_reason_completed'))
      this.closeReasonRow('NOT_PLANNED', $r('app.media.oct_skip_16'), $r('app.string.close_reason_not_planned'))

      Blank()
      Button($r('app.string.close_issue'))
        .type(ButtonType.Normal)
        .width('calc(100% - 32vp)')
        .height(44)
        .borderRadius(6)
        .backgroundColor($r('app.color.danger_text'))
        .margin({ bottom: 16 })
        .onClick((): void => this.doCloseIssue())
    }
    .width('100%')
    .height('100%')
    .padding({ top: 8 })
  }

  /** 弹层内容分派（坑 2：单 bindSheet + sheetKind） */
  @Builder
  sheetBuilder() {
    if (this.sheetKind === 'closeReason') {
      this.closeReasonSheet()
    } else {
      this.composerSheet()
    }
  }

  /** 弹层选项：composer 全页（键盘缩面板），closeReason 半页 */
  private sheetOptions(): SheetOptions {
    if (this.sheetKind === 'composer') {
      return {
        height: SheetSize.LARGE,
        detents: [SheetSize.LARGE, SheetSize.MEDIUM],
        showClose: false,
        backgroundColor: $r('app.color.card_background'),
        dragBar: true,
        // 键盘弹起缩面板：格式工具条停在键盘正上方（见 PrDetail 同名说明）
        keyboardAvoidMode: SheetKeyboardAvoidMode.RESIZE_ONLY,
        onDisappear: (): void => this.onSheetDismissed()
      };
    }
    return {
      height: 480,
      detents: [480, SheetSize.LARGE],
      showClose: false,
      backgroundColor: $r('app.color.card_background'),
      dragBar: true,
      onDisappear: (): void => this.onSheetDismissed()
    };
  }

  /** 正文卡行内菜单（对齐 PR 正文卡口径）：Share / Quote reply / Edit / 灰线 / Report / Block */
  @Builder
  bodyMenu() {
    Column() {
      Row({ space: 10 }) {
        OctIcon({ res: $r('app.media.oct_share_android_16'), iconSize: 16, iconColor: $r('app.color.text_primary') })
        Text($r('app.string.a11y_share'))
          .fontSize($r('app.float.body_font_size'))
          .fontColor($r('app.color.text_primary'))
      }
      .width('100%')
      .height(40)
      .responseRegion({ x: 0, y: -2, width: '100%', height: '110%' })
      .padding({ left: 14, right: 14 })
      .onClick((): void => {
        this.bodyMenuOpen = false;
        this.shareBody();
      })
      Row({ space: 10 }) {
        OctIcon({ res: $r('app.media.oct_comment_16'), iconSize: 16, iconColor: $r('app.color.text_primary') })
        Text($r('app.string.menu_quote_reply'))
          .fontSize($r('app.float.body_font_size'))
          .fontColor($r('app.color.text_primary'))
      }
      .width('100%')
      .height(40)
      .responseRegion({ x: 0, y: -2, width: '100%', height: '110%' })
      .padding({ left: 14, right: 14 })
      .onClick((): void => {
        this.bodyMenuOpen = false;
        this.quoteBody();
      })
      if (this.detail?.viewerCanUpdate) {
        Row({ space: 10 }) {
          OctIcon({ res: $r('app.media.oct_pencil_16'), iconSize: 16, iconColor: $r('app.color.text_primary') })
          Text($r('app.string.menu_edit'))
            .fontSize($r('app.float.body_font_size'))
            .fontColor($r('app.color.text_primary'))
        }
        .width('100%')
        .height(40)
        .responseRegion({ x: 0, y: -2, width: '100%', height: '110%' })
        .padding({ left: 14, right: 14 })
        .onClick((): void => {
          this.openEditForm();
        })
      }
      // 灰线分组：Edit（自己的内容）与 Report/Block（平台动作）分开
      // 弹层内 Divider 必须显式给 strokeWidth + 宽度，否则塌成 0 宽不显示
      Divider()
        .color($r('app.color.divider'))
        .strokeWidth(1)
        .width('100%')
        .margin({ top: 6, bottom: 6 })
      Row({ space: 10 }) {
        OctIcon({ res: $r('app.media.oct_alert_16'), iconSize: 16, iconColor: $r('app.color.danger_text') })
        Text($r('app.string.menu_report'))
          .fontSize($r('app.float.body_font_size'))
          .fontColor($r('app.color.danger_text'))
      }
      .width('100%')
      .height(40)
      .responseRegion({ x: 0, y: -2, width: '100%', height: '110%' })
      .padding({ left: 14, right: 14 })
      .onClick((): void => {
        this.bodyMenuOpen = false;
        this.comingSoon();
      })
      Row({ space: 10 }) {
        OctIcon({ res: $r('app.media.oct_circle_slash_16'), iconSize: 16, iconColor: $r('app.color.danger_text') })
        Text($r('app.string.menu_block'))
          .fontSize($r('app.float.body_font_size'))
          .fontColor($r('app.color.danger_text'))
      }
      .width('100%')
      .height(40)
      .responseRegion({ x: 0, y: -2, width: '100%', height: '110%' })
      .padding({ left: 14, right: 14 })
      .onClick((): void => {
        this.bodyMenuOpen = false;
        this.comingSoon();
      })
    }
    .width(190)
    .borderRadius(12)
    .backgroundColor($r('app.color.card_background'))
    .shadow({ radius: 24, color: $r('app.color.shadow_floating'), offsetY: 8 })
    .padding({ top: 6, bottom: 6 })
  }

  build() {
    Column() {
      AppBar({
        showBack: true,
        title: `${this.owner}/${this.name} #${this.number}`,
        onBack: (): void => {
          this.pathStack.pop();
        },
        actions: [
          new AppBarAction($r('app.media.oct_search_24'), (): void => {
            this.pathStack.pushPathByName('search', '');
          }, { iconColor: $r('app.color.text_primary'), a11y: $r('app.string.a11y_search') }),
          new AppBarAction($r('app.media.oct_share_android_16'), (): void => {
            const title = this.detail !== null ? this.detail.title : '';
            shareLink(this.getUIContext(), issuePageUrl(this.owner, this.name, this.number), title);
          }, { a11y: $r('app.string.a11y_share') }),
          new AppBarAction($r('app.media.oct_kebab_horizontal_16'), (): void => {
          }, { rotate90: true, a11y: $r('app.string.a11y_more'), menuItems: this.issueMenuItems() })
        ]
      })

      PageShadowBar({ show: this.scrollShadow })

      Refresh({ refreshing: $$this.isRefreshing }) {
        Scroll() {
          Column() {
            if (this.detail !== null) {
            Column({ space: 8 }) {
              // 标题行 + pencil 编辑（Spec 043 §二.5，viewerCanUpdate 门控）
              Row({ space: 8 }) {
                Text(this.detail.title)
                  .fontSize($r('app.float.title_font_size'))
                  .fontWeight(600)
                  .fontColor($r('app.color.text_primary'))
                  .layoutWeight(1)
                  .lineHeight(28)
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                if (this.detail.viewerCanUpdate) {
                  Stack() {
                    OctIcon({
                      res: $r('app.media.oct_pencil_16'), iconSize: 16,
                      iconColor: $r('app.color.text_secondary')
                    })
                  }
                  .width(28)
                  .height(28)
                  .responseRegion({ x: -8, y: -8, width: '160%', height: '160%' })
                  .accessibilityDescription($r('app.string.menu_edit'))
                  .onClick((): void => this.openEditForm())
                }
              }
              .width('100%')
              .alignItems(VerticalAlign.Top)

              Row({ space: 8 }) {
                OctIcon({ res: this.stateIcon(), iconSize: 16, iconColor: this.stateColor() })
                Text(this.detail.authorLogin)
                  .fontSize($r('app.float.caption_font_size'))
                  .fontColor($r('app.color.text_secondary'))
                Text(this.timeText(timeParts(this.detail.createdAt, Date.now())))
                  .fontSize($r('app.float.caption_font_size'))
                  .fontColor($r('app.color.text_secondary'))
                Blank()
                // 正文卡右上 ⋯（对齐 PR 正文卡：Share / Quote reply / Edit / Report / Block）
                Stack() {
                  OctIcon({ res: $r('app.media.oct_kebab_horizontal_16'), iconSize: 16,
                    iconColor: $r('app.color.text_secondary') })
                }
                .width(28)
                .height(28)
                .responseRegion({ x: -8, y: -8, width: '160%', height: '160%' })
                .accessibilityDescription($r('app.string.a11y_more'))
                .onClick((): void => {
                  this.bodyMenuOpen = !this.bodyMenuOpen;
                })
                .bindPopup(this.bodyMenuOpen, {
                  builder: (): void => this.bodyMenu(),
                  placement: Placement.BottomRight,
                  enableArrow: false,
                  mask: true,
                  onStateChange: (e: PopupState): void => {
                    if (!e.isVisible) {
                      this.bodyMenuOpen = false;
                    }
                  }
                })
              }
              .width('100%')

              if (this.detail.body !== '' || this.detail.bodyHTML !== '') {
                MarkdownView({
                  html: this.detail.bodyHTML,
                  fallbackText: this.detail.body,
                  onNavigate: (name: string, param: string) => this.navigateLink(name, param)
                })
              }
            }
            .padding($r('app.float.card_padding'))
            .borderRadius($r('app.float.card_radius'))
            .backgroundColor($r('app.color.card_background'))
            .width('100%')
            .margin({ bottom: 12 })

            Text(resText(this.getUIContext(), $r('app.string.issue_detail_comments'), this.detail.commentCount))
              .fontSize($r('app.float.sub_text_font_size'))
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary'))
              .width('100%')
              .padding({ bottom: 8 })

            ForEach(this.detail.comments, (item: RepoComment) => {
              CommentCard({
                comment: item,
                token: this.token,
                onNavigate: (name: string, param: string) => this.navigateLink(name, param),
                onEdit: (comment: RepoComment) => {
                  this.editingId = comment.id;
                  this.editingInitial = comment.body;
                  this.sheetKind = 'composer';
                  this.sheetOpen = true;
                },
                onDelete: (comment: RepoComment) => this.confirmDeleteComment(comment),
                onReactionChanged: (): void => this.refresh()
              })
            }, (item: RepoComment) => `${item.id}-${item.body.length}`)
            if (this.hasNextPage) {
              ListLoadingFooter({ show: this.loadingMore })
            }
          } else if (this.loading || this.errorMsg !== '') {
            StateView({ loading: this.loading, error: this.errorMsg, onRetry: () => this.refresh() })
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
      .onScroll((_x: number, y: number): void => { this.scrollShadow = y > 0.001; })
      }
      .layoutWeight(1)
      .onRefreshing((): void => {
        this.isRefreshing = true;
        this.refresh();
      })

      // 底部操作栏（COMMENT 展开输入面板 Spec 041 + 关闭/重开 Spec 043）
      Row({ space: 10 }) {
        Button($r('app.string.comment_button'))
          .buttonStyle(ButtonStyleMode.NORMAL)
          .layoutWeight(1)
          .height(44)
          .borderRadius(6)
          .onClick(() => this.openComposer())
        if (this.detail !== null && this.detail.viewerCanUpdate) {
          Button(this.detail.state === 'OPEN'
            ? $r('app.string.close_issue') : $r('app.string.reopen_issue'))
            .buttonStyle(ButtonStyleMode.NORMAL)
            .height(44)
            .borderRadius(6)
            .fontColor(this.detail.state === 'OPEN'
              ? $r('app.color.danger_text') : $r('app.color.success_text'))
            .onClick((): void => {
              if (this.detail?.state === 'OPEN') {
                this.openCloseSheet();
              } else {
                this.reopenIssue();
              }
            })
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 8, bottom: 12 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_page'))
    .bindSheet($$this.sheetOpen, this.sheetBuilder(), this.sheetOptions())
  }
}
