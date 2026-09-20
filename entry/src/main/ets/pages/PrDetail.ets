/**
 * PR 详情页（Spec 031 + 041 + 042）：页头卡（作者行 + 标题 + 状态胶囊/分支）+ 正文卡 + Changes 卡片 +
 * Status 卡片 + Conversation + 审阅列表 + ReviewThreads + 评论输入面板 + Review changes 三态审阅面板。
 */
import { promptAction } from '@kit.ArkUI';
import { RequestSequencer } from 'graphql';
import { AppBar, AppBarAction, AppBarActionCfg, AppBarMenuItem } from '../components/AppBar';
import { OctIcon } from '../components/OctIcon';
import { MarkdownView } from '../components/MarkdownView';
import { PageShadowBar } from '../components/PageShadowBar';
import { CommentCard } from '../components/CommentCard';
import { CommentComposer } from '../components/CommentComposer';
import { PrStatusCard } from '../components/PrStatusCard';
import { ReactionBar } from '../components/ReactionBar';
import { TimelineRow } from '../components/TimelineRow';
import { ReviewThreadsCard } from '../components/ReviewThreadsCard';
import { RepoComment, PrDetailPage, PrReview, TimelineNode, reviewStateKey, MetaLabel, MetaUser,
  TriageUser, TriageLabel, TriageMilestone, TriageLinkedItem, TriageProject, EditorRow, StatusCheckItem,
  filterTriageByKeyword, diffSelection, singlePickId, resolveMergeMethod, actorDisplayLogin } from '../models/RepoSubModels';
import { RepoSubService } from '../services/RepoSubService';
import { friendlyError } from '../services/GitHttpClient';
import { StateView } from '../components/StateView';
import { ListLoadingFooter } from '../components/ListLoadingFooter';
import { githubShortTime, timeParts, TimeParts } from '../utils/Format';
import { resText } from '../utils/I18n';
import { pullPageUrl, shareLink } from '../utils/Share';
import { labelTextColor, labelBackground } from '../utils/DataColors';
import { LabelPill } from '../components/LabelPill';

/** bindPopup onStateChange 回调类型（与 CommentCard 同款自声明） */
interface PopupState {
  isVisible: boolean;
}

@ComponentV2
export struct PrDetailView {
  @Param owner: string = '';
  @Param name: string = '';
  @Param number: number = 0;
  @Param token: string = '';
  @Param pathStack: NavPathStack = new NavPathStack();
  /** 路由 onShown 递增：从 prFiles（行内评论）返回时重拉 threads */
  @Param refreshTick: number = 0;
  @Local detail: PrDetailPage | null = null;
  @Local loading: boolean = true;
  @Local errorMsg: string = '';
  /** 滚动顶部阴影（滚动中显示、回顶消失） */
  @Local scrollShadow: boolean = false;
  @Local isRefreshing: boolean = false;
  /** 正文卡行内菜单开合（作者头三横点：Share / Quote reply） */
  @Local bodyMenuOpen: boolean = false;
  // ── Spec 044 元数据编辑器（info 五段 → EDIT 进入）──
  /** '' = info 列表；assignees/labels/milestone/linked/projects = 对应编辑器 */
  @Local metaEditor: string = '';
  @Local edSearch: string = '';
  @Local edSaving: boolean = false;
  /** 项目编辑器的分页签：recent=仓库项目 / user=我的项目 */
  @Local edProjectTab: string = 'recent';
  /** 候选（按编辑器懒加载） */
  @Local edUsers: TriageUser[] = [];
  @Local edLabels: TriageLabel[] = [];
  @Local edMilestones: TriageMilestone[] = [];
  @Local edLinked: TriageLinkedItem[] = [];
  @Local edProjects: TriageProject[] = [];
  /** 已选行（Selected 段唯一数据源；打开时以 PR 当前元数据为初值） */
  @Local selRows: EditorRow[] = [];
  /** 打开时的初值 ids（判脏 + 标签差异推送） */
  private selInitialIds: string[] = [];
  /**
   * 评论/审阅共用弹层（坑 2：同组件多 bindSheet 只有最后一个生效 → 单 sheet + sheetKind 分派）。
   * sheetKind：'composer'=评论输入（041），'review'=审阅三态/编辑（042）。
   */
  @Local sheetOpen: boolean = false;
  @Local sheetKind: string = 'composer';
  @Local draft: string = '';
  @Local editingId: string = '';
  @Local editingInitial: string = '';
  /** 时间轴分页（>30 条 Load more） */
  @Local timelineCursor: string = '';
  @Local timelineHasNext: boolean = false;
  /** 时间轴内容实测高度（vp）：竖线按此撑高（Percent 会被外层 Stack 反向撑长） */
  @Local timelineContentH: number = 0;
  @Local loadingMore: boolean = false;
  /** Review changes 面板（Spec 042 元素5）：三态审阅 + 总结 body */
  @Local reviewEvent: string = 'COMMENT';
  @Local reviewBody: string = '';
  @Local reviewSending: boolean = false;
  /** 审阅编辑模式（元素6：复用面板，仅 body 可改） */
  @Local editingReviewId: string = '';
  /** 合并方式：'' = 用户未选（取服务端默认 viewerDefaultMergeMethod，故不用固定初值） */
  @Local mergeMethod: string = '';
  @Local mergeHeadline: string = '';
  @Local mergeBody: string = '';
  @Local mergeEditing: boolean = false;
  @Local mergeSending: boolean = false;
  /** 首个 onShown tick 不重拉（aboutToAppear 已拉过） */
  private skipFirstTick: boolean = true;
  /** 详情请求竞态守卫：旧 refresh 响应按序号丢弃（库原语） */
  private detailReqSeq: RequestSequencer = new RequestSequencer();
  /** 时间轴代际：refresh 发起即递增，使在途续拉结果作废（防旧游标页拼到新时间轴） */
  private timelineGen: number = 0;

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
    const seq: number = this.detailReqSeq.begin();
    // 代际递增：refresh 会整页替换时间轴，在途续拉（旧游标 + 旧节点）随之作废
    this.timelineGen++;
    this.loading = true;
    this.errorMsg = '';
    RepoSubService.fetchPrDetail(this.token, this.owner, this.name, this.number, '')
      .then((page: PrDetailPage) => {
        if (!this.detailReqSeq.isCurrent(seq)) {
          return;
        }
        this.detail = page;
        this.timelineHasNext = page.timelineHasNext;
        this.timelineCursor = page.timelineCursor;
        this.loading = false;
        this.isRefreshing = false;
        this.loadingMore = false;
      })
      .catch((e: Error) => {
        if (!this.detailReqSeq.isCurrent(seq)) {
          return;
        }
        this.errorMsg = e.message;
        this.loading = false;
        this.isRefreshing = false;
        this.loadingMore = false;
      });
  }

  /** 追加下一段时间轴（只拼接不整页替换） */
  private loadMoreTimeline(): void {
    if (!this.timelineHasNext || this.loadingMore || this.detail === null) {
      return;
    }
    const gen: number = this.timelineGen;
    const cursor: string = this.timelineCursor;
    this.loadingMore = true;
    RepoSubService.fetchPrDetail(this.token, this.owner, this.name, this.number, cursor)
      .then((page: PrDetailPage) => {
        if (gen !== this.timelineGen) {
          // 期间发生过 refresh：本页游标与当前时间轴不再连续，丢弃（loadingMore 由 refresh 归位）
          return;
        }
        const prev = this.detail;
        if (prev !== null) {
          // 合并进新页对象后整体重赋值，触发 UI 刷新（同 B4 模式）
          page.timeline = prev.timeline.concat(page.timeline);
          this.detail = page;
        }
        this.timelineHasNext = page.timelineHasNext;
        this.timelineCursor = page.timelineCursor;
        this.loadingMore = false;
      })
      .catch((e: Error) => {
        if (gen !== this.timelineGen) {
          return;
        }
        this.loadingMore = false;
        promptAction.showToast({ message: friendlyError(this.getUIContext(), e) });
      });
  }

  /** 时间轴提交行 → 提交详情（路由参数 owner/name/oid） */
  private openCommit(oid: string): void {
    this.pathStack.pushPathByName('commitDetail', `${this.owner}/${this.name}/${oid}`);
  }

  /** 非空取用（时间轴节点已按 kind 判定，此处仅做类型收窄） */
  private commentOf(item: TimelineNode): RepoComment {
    return item.comment ?? ({} as RepoComment);
  }

  private reviewOf(item: TimelineNode): PrReview {
    return item.review ?? ({} as PrReview);
  }

  private stringOf(res: Resource): string {
    return resText(this.getUIContext(), res);
  }

  private timeText(parts: TimeParts | null): string {
    return parts !== null ? githubShortTime(parts) : '';
  }

  @Builder
  sectionTitle(text: string) {
    Text(text)
      .fontSize($r('app.float.sub_text_font_size'))
      .fontWeight(600)
      .fontColor($r('app.color.text_primary'))
      .width('100%')
  }

  /** MarkdownView 站内链接路由（正文/评论点击 GitHub 内部链接 → 对应页面） */
  private navigateLink(name: string, param: string): void {
    this.pathStack.pushPathByName(name, param);
  }

  /** 时间轴内审阅整卡（Spec 042 元素4/6：状态徽章 + 总结 body；仅本人可编辑） */
  @Builder
  reviewCard(review: PrReview) {
    Column({ space: 6 }) {
      Row({ space: 6 }) {
        if (review.authorAvatar !== '') {
          Image(review.authorAvatar)
            .width(22)
            .height(22)
            .borderRadius(11)
            .backgroundColor($r('app.color.heat_empty'))
        }
        Text(actorDisplayLogin(review.authorLogin, review.authorIsBot))
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_primary'))
        Text(this.reviewStateText(review.state))
          .fontSize($r('app.float.caption_font_size'))
          .fontColor(this.reviewStateColor(review.state))
          .padding({ left: 6, right: 6, top: 1, bottom: 1 })
          .borderRadius(4)
          .backgroundColor($r('app.color.heat_empty'))
        Blank()
        if (review.viewerDidAuthor && !this.detail?.merged) {
          Text($r('app.string.pr_review_edit'))
            .fontSize($r('app.float.caption_font_size'))
            .fontColor($r('app.color.link_blue'))
            .onClick((): void => this.openReviewEdit(review))
        }
      }
      .width('100%')
      if (review.body !== '' || review.bodyHTML !== '') {
        MarkdownView({
          html: review.bodyHTML,
          fallbackText: review.body,
          onNavigate: (name: string, param: string) => this.navigateLink(name, param)
        })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding($r('app.float.card_padding'))
    .borderRadius($r('app.float.card_radius'))
    .backgroundColor($r('app.color.card_background'))
    .margin({ bottom: 8 })
  }

  /** COMMENT 按钮（打开输入面板；PR 不限状态可评论） */
  private openComposer(): void {
    if (this.detail === null) {
      return;
    }
    this.editingId = '';
    this.editingInitial = '';
    this.sheetKind = 'composer';
    this.sheetOpen = true;
  }

  /** 关闭面板：清编辑态；新评论草稿保留在 @Local（重开时预填） */
  private closeComposer(): void {
    this.sheetOpen = false;
    this.editingId = '';
    this.editingInitial = '';
  }

  /** 弹层消失（拖拽/遮罩/关闭回调统一入口）：复位两种模式的临时编辑态 */
  private onSheetDismissed(): void {
    this.metaEditor = '';
    this.edSearch = '';
    this.editingId = '';
    this.editingInitial = '';
    this.editingReviewId = '';
    this.reviewBody = '';
  }

  /** 发布/编辑成功：清草稿并重拉（评论数 +1、新评论可见，服务端为权威） */
  private afterCommentSaved(): void {
    this.draft = '';
    this.refresh();
  }

  /** 打开 Review changes 面板（三态审阅；默认 COMMENT） */
  private openReviewSheet(): void {
    this.editingReviewId = '';
    this.reviewEvent = 'COMMENT';
    this.reviewBody = '';
    this.sheetKind = 'review';
    this.sheetOpen = true;
  }

  /** 打开审阅编辑（元素6：仅本人审阅；只改总结 body） */
  private openReviewEdit(review: PrReview): void {
    this.editingReviewId = review.id;
    this.reviewBody = review.body;
    this.sheetKind = 'review';
    this.sheetOpen = true;
  }

  private closeReviewSheet(): void {
    this.sheetOpen = false;
    this.editingReviewId = '';
    this.reviewBody = '';
  }

  /** 打开元数据底部整页（info 钮）：只切 kind 不置 sheetOpen 会导致点击无反应 */
  private openMetaSheet(): void {
    this.metaEditor = '';
    this.sheetKind = 'meta';
    this.sheetOpen = true;
  }

  // ─────────────── Spec 044 元数据编辑器 ───────────────

  /** 进编辑器：选择态以 PR 当前元数据为初值，候选懒加载 */
  private openMetaEditor(kind: string): void {
    if (this.detail === null) {
      return;
    }
    this.metaEditor = kind;
    this.edSearch = '';
    this.edProjectTab = 'recent';
    this.edUsers = [];
    this.edLabels = [];
    this.edMilestones = [];
    this.edLinked = [];
    this.edProjects = [];
    const rows: EditorRow[] = [];
    if (kind === 'assignees') {
      for (const a of this.detail.assigneeItems) {
        rows.push({ id: a.id, title: a.login, avatarUrl: a.avatarUrl });
      }
    } else if (kind === 'labels') {
      for (const l of this.detail.labelItems) {
        rows.push({ id: l.id, title: l.name, labelColor: l.color });
      }
    } else if (kind === 'milestone' && this.detail.milestoneItem !== null) {
      rows.push({ id: this.detail.milestoneItem.id, title: this.detail.milestoneItem.title });
    }
    this.selRows = rows;
    this.selInitialIds = this.idsOf(this.selRows);
    this.loadEditorCandidates(kind);
  }

  /** 编辑器 ← 返回 info 列表 */
  private closeMetaEditor(): void {
    this.metaEditor = '';
    this.edSearch = '';
  }

  private loadEditorCandidates(kind: string): void {
    if (kind === 'assignees') {
      RepoSubService.fetchTriageAssignees(this.token, this.owner, this.name)
        .then((r: TriageUser[]): void => {
          this.edUsers = r;
        })
        .catch((e: Error): void => {
          promptAction.showToast({ message: friendlyError(this.getUIContext(), e) });
        });
    } else if (kind === 'labels') {
      RepoSubService.fetchTriageLabels(this.token, this.owner, this.name)
        .then((r: TriageLabel[]): void => {
          this.edLabels = r;
        })
        .catch((e: Error): void => {
          promptAction.showToast({ message: friendlyError(this.getUIContext(), e) });
        });
    } else if (kind === 'milestone') {
      RepoSubService.fetchTriageMilestones(this.token, this.owner, this.name)
        .then((r: TriageMilestone[]): void => {
          this.edMilestones = r;
        })
        .catch((e: Error): void => {
          promptAction.showToast({ message: friendlyError(this.getUIContext(), e) });
        });
    } else if (kind === 'linked') {
      const selfId = this.detail !== null ? this.detail.subjectId : '';
      RepoSubService.fetchTriageLinked(this.token, this.owner, this.name, selfId)
        .then((r: TriageLinkedItem[]): void => {
          this.edLinked = r;
        })
        .catch((e: Error): void => {
          promptAction.showToast({ message: friendlyError(this.getUIContext(), e) });
        });
    } else if (kind === 'projects') {
      this.loadProjects(this.edProjectTab);
    }
  }

  private loadProjects(scope: string): void {
    RepoSubService.fetchTriageProjects(this.token, this.owner, this.name, scope)
      .then((r: TriageProject[]): void => {
        this.edProjects = r;
      })
      .catch((e: Error): void => {
        promptAction.showToast({ message: friendlyError(this.getUIContext(), e) });
      });
  }

  private idsOf(rows: EditorRow[]): string[] {
    const ids: string[] = [];
    for (const r of rows) {
      ids.push(r.id);
    }
    return ids;
  }

  private indexOfRow(rows: EditorRow[], id: string): number {
    for (let i = 0; i < rows.length; i++) {
      if (rows[i].id === id) {
        return i;
      }
    }
    return -1;
  }

  private editorTitle(): string {
    switch (this.metaEditor) {
      case 'assignees':
        return this.stringOf($r('app.string.pr_meta_assignees'));
      case 'labels':
        return this.stringOf($r('app.string.pr_meta_labels'));
      case 'milestone':
        return this.stringOf($r('app.string.pr_meta_milestone'));
      case 'linked':
        return this.stringOf($r('app.string.pr_meta_linked'));
      default:
        return this.stringOf($r('app.string.pr_meta_projects'));
    }
  }

  /** 候选段标题（官方文案：Select Labels / Select a Milestone / Suggestions / Select Projects） */
  private editorCandidateLabel(): string {
    switch (this.metaEditor) {
      case 'assignees':
        return this.stringOf($r('app.string.meta_editor_select_assignees'));
      case 'labels':
        return this.stringOf($r('app.string.meta_editor_select_labels'));
      case 'milestone':
        return this.stringOf($r('app.string.meta_editor_select_milestone'));
      case 'linked':
        return this.stringOf($r('app.string.meta_editor_select_linked'));
      default:
        return this.stringOf($r('app.string.meta_editor_select_projects'));
    }
  }

  /** 候选行（搜索关键字客户端过滤） */
  private candidateRows(): EditorRow[] {
    const out: EditorRow[] = [];
    const kw = this.edSearch;
    if (this.metaEditor === 'assignees') {
      const names: string[] = [];
      for (const u of this.edUsers) {
        names.push(u.login);
      }
      for (const i of filterTriageByKeyword(names, kw)) {
        const u = this.edUsers[i];
        out.push({ id: u.id, title: u.login, avatarUrl: u.avatarUrl });
      }
    } else if (this.metaEditor === 'labels') {
      const names: string[] = [];
      for (const l of this.edLabels) {
        names.push(l.name);
      }
      for (const i of filterTriageByKeyword(names, kw)) {
        const l = this.edLabels[i];
        out.push({ id: l.id, title: l.name, labelColor: l.color });
      }
    } else if (this.metaEditor === 'milestone') {
      const names: string[] = [];
      for (const m of this.edMilestones) {
        names.push(m.title);
      }
      for (const i of filterTriageByKeyword(names, kw)) {
        const m = this.edMilestones[i];
        out.push({ id: m.id, title: m.title });
      }
    } else if (this.metaEditor === 'linked') {
      const names: string[] = [];
      for (const t of this.edLinked) {
        names.push(t.title);
      }
      for (const i of filterTriageByKeyword(names, kw)) {
        const t = this.edLinked[i];
        out.push({ id: t.id, title: `#${t.number} ${t.title}`, state: t.state });
      }
    } else if (this.metaEditor === 'projects') {
      const names: string[] = [];
      for (const p of this.edProjects) {
        names.push(p.title);
      }
      for (const i of filterTriageByKeyword(names, kw)) {
        out.push({ id: this.edProjects[i].id, title: this.edProjects[i].title });
      }
    }
    return out;
  }

  /** 候选行点击：已选则移除，未选则加入（milestone 为单选，选中即替换） */
  private toggleEditorRow(row: EditorRow): void {
    const idx = this.indexOfRow(this.selRows, row.id);
    if (this.metaEditor === 'milestone') {
      this.selRows = idx >= 0 ? [] : [{ id: row.id, title: row.title }];
      return;
    }
    if (idx >= 0) {
      const next: EditorRow[] = [];
      for (const r of this.selRows) {
        if (r.id !== row.id) {
          next.push(r);
        }
      }
      this.selRows = next;
      return;
    }
    this.selRows = this.selRows.concat([row]);
  }

  private removeSelectedRow(id: string): void {
    const next: EditorRow[] = [];
    for (const r of this.selRows) {
      if (r.id !== id) {
        next.push(r);
      }
    }
    this.selRows = next;
  }

  /**
   * SAVE 亮蓝/可点判据（官方口径：图 1/2/4/5/6 恒亮蓝，仅 Milestone 无可选里程碑时置灰）。
   * 无改动时点 SAVE 直接退回 info 列表，不发写请求（见 saveEditor）。
   */
  private saveEnabled(): boolean {
    if (this.metaEditor === 'milestone') {
      return this.edMilestones.length > 0;
    }
    return true;
  }

  /** 是否有待保存改动（决定是否真的发写请求） */
  private editorDirty(): boolean {
    if (this.metaEditor === 'projects' || this.metaEditor === 'linked') {
      return this.selRows.length > 0;
    }
    const now = this.idsOf(this.selRows);
    if (now.length !== this.selInitialIds.length) {
      return true;
    }
    for (const id of now) {
      if (this.selInitialIds.indexOf(id) < 0) {
        return true;
      }
    }
    return false;
  }

  /** SAVE：按编辑器分派写管道（Linked items 无公开 API → 提示仅网页端） */
  private saveEditor(): void {
    if (this.detail === null || this.edSaving) {
      return;
    }
    const kind = this.metaEditor;
    if (kind === 'linked') {
      promptAction.showToast({ message: $r('app.string.meta_editor_unsupported') });
      return;
    }
    if (!this.saveEnabled()) {
      return;
    }
    if (!this.editorDirty()) {
      this.closeMetaEditor();
      return;
    }
    this.edSaving = true;
    const prId = this.detail.subjectId;
    const ids = this.idsOf(this.selRows);
    if (kind === 'assignees') {
      RepoSubService.setPrAssignees(this.token, prId, ids)
        .then((): void => this.afterEditorSaved())
        .catch((e: Error): void => this.editorFailed(e));
      return;
    }
    if (kind === 'labels') {
      const diff = diffSelection(this.selInitialIds, ids);
      RepoSubService.setPrLabels(this.token, prId, diff.add, diff.remove)
        .then((): void => this.afterEditorSaved())
        .catch((e: Error): void => this.editorFailed(e));
      return;
    }
    if (kind === 'milestone') {
      RepoSubService.setPrMilestone(this.token, prId, singlePickId(ids))
        .then((): void => this.afterEditorSaved())
        .catch((e: Error): void => this.editorFailed(e));
      return;
    }
    const tasks: Promise<void>[] = [];
    for (const id of ids) {
      tasks.push(RepoSubService.addPrToProject(this.token, prId, id));
    }
    Promise.all(tasks)
      .then((): void => this.afterEditorSaved())
      .catch((e: Error): void => this.editorFailed(e));
  }

  /** 保存成功：回 info 列表 + 详情重拉（服务端为权威）+ toast */
  private afterEditorSaved(): void {
    this.edSaving = false;
    this.closeMetaEditor();
    promptAction.showToast({ message: $r('app.string.meta_editor_saved') });
    this.refresh();
  }

  private editorFailed(e: Error): void {
    this.edSaving = false;
    promptAction.showToast({ message: friendlyError(this.getUIContext(), e) });
  }

  private submitReview(): void {
    if (this.detail === null || this.reviewSending) {
      return;
    }
    const body = this.reviewBody.trim();
    if (this.editingReviewId !== '') {
      if (body === '') {
        return;
      }
      this.reviewSending = true;
      RepoSubService.updateReview(this.token, this.editingReviewId, body)
        .then(() => {
          this.reviewSending = false;
          this.closeReviewSheet();
          promptAction.showToast({ message: $r('app.string.pr_review_submitted') });
          this.refresh();
        })
        .catch((e: Error) => {
          this.reviewSending = false;
          promptAction.showToast({ message: friendlyError(this.getUIContext(), e) });
        });
      return;
    }
    if (this.reviewEvent === 'COMMENT' && body === '') {
      promptAction.showToast({ message: $r('app.string.pr_review_need_body') });
      return;
    }
    this.reviewSending = true;
    RepoSubService.submitReview(this.token, this.detail.subjectId, this.reviewEvent, body)
      .then(() => {
        this.reviewSending = false;
        this.closeReviewSheet();
        promptAction.showToast({ message: $r('app.string.pr_review_submitted') });
        this.refresh();
      })
      .catch((e: Error) => {
        this.reviewSending = false;
        promptAction.showToast({ message: friendlyError(this.getUIContext(), e) });
      });
  }

  /** 打开 Merge options 底部页（官方流：默认方式 = 仓库/账号默认，提交信息 EDIT 可改；页内无确认钮） */
  private openMergeOptions(): void {
    if (this.detail === null) {
      return;
    }
    this.mergeMethod = resolveMergeMethod(this.mergeMethod, this.detail.defaultMergeMethod);
    this.mergeHeadline = this.defaultHeadlineFor(this.mergeMethod);
    this.mergeBody = this.mergeMethod === this.detail.defaultMergeMethod ? this.detail.mergeBody : '';
    this.mergeEditing = false;
    this.sheetKind = 'mergeOptions';
    this.sheetOpen = true;
  }

  /** 主段 MERGE：官方确认对话框（不可逆操作先二次确认）→ 按当前方式合并 */
  private confirmMergeTap(): void {
    if (this.detail === null || this.mergeSending) {
      return;
    }
    this.getUIContext().showAlertDialog({
      title: this.stringOf($r('app.string.pr_merge_confirm_title')),
      message: this.stringOf($r('app.string.pr_merge_confirm_body')),
      autoCancel: true,
      buttons: [
        {
          value: this.stringOf($r('app.string.pr_delete_branch_cancel')),
          action: (): void => {
          }
        },
        {
          style: DialogButtonStyle.HIGHLIGHT,
          value: this.stringOf($r('app.string.pr_merge_button')),
          action: (): void => {
            this.confirmMerge();
          }
        }
      ]
    });
  }

  /** 方法标题（三态全集，官方文案） */
  private mergeMethodTitle(method: string): string {
    if (method === 'SQUASH') {
      return this.stringOf($r('app.string.pr_merge_squash'));
    }
    if (method === 'REBASE') {
      return this.stringOf($r('app.string.pr_merge_rebase'));
    }
    return this.stringOf($r('app.string.pr_merge_merge_commit'));
  }

  /** 方法说明（含 commit 数；官方单复数分档） */
  private mergeMethodDesc(method: string): string {
    const count = this.detail !== null ? this.detail.commitsCount : 0;
    if (method === 'MERGE') {
      return this.stringOf($r('app.string.pr_merge_desc_merge'));
    }
    if (method === 'REBASE') {
      return count === 1
        ? this.stringOf($r('app.string.pr_merge_desc_rebase_one'))
        : resText(this.getUIContext(), $r('app.string.pr_merge_desc_rebase_many'), count);
    }
    return count === 1
      ? this.stringOf($r('app.string.pr_merge_desc_squash_one'))
      : resText(this.getUIContext(), $r('app.string.pr_merge_desc_squash_many'), count);
  }

  /**
   * 默认提交信息标题：与「默认合并方式」一致时用服务端文本（viewerMergeHeadlineText 只按默认方式口径返回，
   * 无 mergeMethod 参数）；切到别的方式时按官方口径本地推导（squash/rebase 用 PR 标题，merge 用固定句式）。
   */
  private defaultHeadlineFor(method: string): string {
    if (this.detail === null) {
      return '';
    }
    if (method === this.detail.defaultMergeMethod && this.detail.mergeHeadline !== '') {
      return this.detail.mergeHeadline;
    }
    if (method === 'MERGE') {
      return `Merge pull request #${this.detail.number} from ${this.owner}/${this.detail.headRefName}`;
    }
    return this.detail.title;
  }

  /** 切换合并方式（未编辑态才重算默认提交信息，避免覆盖用户改动） */
  private pickMergeMethod(method: string): void {
    this.mergeMethod = method;
    if (this.mergeEditing || this.detail === null) {
      return;
    }
    this.mergeHeadline = this.defaultHeadlineFor(method);
    this.mergeBody = method === this.detail.defaultMergeMethod ? this.detail.mergeBody : '';
  }

  /** 执行合并（确认 sheet 的 MERGE；headline 空则走默认 message） */
  private confirmMerge(): void {
    if (this.detail === null || this.mergeSending) {
      return;
    }
    this.mergeSending = true;
    // 主段 MERGE 可未经 Merge options 页直接确认：方式同样取服务端默认（resolveMergeMethod）
    RepoSubService.mergePullRequest(this.token, this.detail.subjectId,
      resolveMergeMethod(this.mergeMethod, this.detail.defaultMergeMethod),
      this.mergeEditing ? this.mergeHeadline.trim() : '', this.mergeBody)
      .then(() => {
        this.mergeSending = false;
        this.sheetOpen = false;
        promptAction.showToast({ message: $r('app.string.pr_merge_merged') });
        this.refresh();
      })
      .catch((e: Error) => {
        this.mergeSending = false;
        promptAction.showToast({
          message: this.stringOf($r('app.string.pr_merge_failed')) + ': ' + friendlyError(this.getUIContext(), e)
        });
      });
  }

  /** 审阅状态徽章色：APPROVED 绿 / CHANGES_REQUESTED 红 / 其余灰 */
  private reviewStateColor(state: string): ResourceColor {
    if (state === 'APPROVED') {
      return $r('app.color.success_text');
    }
    if (state === 'CHANGES_REQUESTED') {
      return $r('app.color.danger_text');
    }
    return $r('app.color.text_secondary');
  }

  /** 审阅状态徽章文案键（pr_review_state_*，映射见 models.reviewStateKey） */
  private reviewStateText(state: string): string {
    switch (reviewStateKey(state)) {
      case 'approved':
        return this.stringOf($r('app.string.pr_review_state_approved'));
      case 'changes_requested':
        return this.stringOf($r('app.string.pr_review_state_changes_requested'));
      case 'dismissed':
        return this.stringOf($r('app.string.pr_review_state_dismissed'));
      case 'pending':
        return this.stringOf($r('app.string.pr_review_state_pending'));
      default:
        return this.stringOf($r('app.string.pr_review_state_commented'));
    }
  }

  /** 页头状态胶囊（官方 StateLabel 填充变体，字形/语义色映射见 DESIGN.md §10.1） */
  private statePillIcon(d: PrDetailPage): Resource {
    if (d.merged) {
      return $r('app.media.oct_git_merge_16');
    }
    if (d.isDraft) {
      return $r('app.media.oct_git_pull_request_draft_16');
    }
    return d.state === 'CLOSED'
      ? $r('app.media.oct_git_pull_request_closed_16') : $r('app.media.oct_git_pull_request_16');
  }

  private statePillBg(d: PrDetailPage): ResourceColor {
    if (d.merged) {
      return $r('app.color.merged_badge_bg');
    }
    if (d.isDraft) {
      return $r('app.color.text_secondary');
    }
    return d.state === 'CLOSED' ? $r('app.color.badge_red') : $r('app.color.success_btn_bg');
  }

  private statePillText(d: PrDetailPage): string {
    if (d.merged) {
      return this.stringOf($r('app.string.pr_merged_badge'));
    }
    if (d.isDraft) {
      return this.stringOf($r('app.string.release_draft_badge'));
    }
    return this.stringOf(d.state === 'CLOSED'
      ? $r('app.string.issues_state_closed') : $r('app.string.issues_state_open'));
  }

  /** 作者关联角色胶囊文案（AuthorAssociation 全集；NONE/未知返回 '' 不显示胶囊） */
  private authorRoleText(d: PrDetailPage): string {
    switch (d.authorAssociation) {
      case 'OWNER':
        return this.stringOf($r('app.string.author_assoc_owner'));
      case 'MEMBER':
        return this.stringOf($r('app.string.author_assoc_member'));
      case 'COLLABORATOR':
        return this.stringOf($r('app.string.author_assoc_collaborator'));
      case 'CONTRIBUTOR':
        return this.stringOf($r('app.string.author_assoc_contributor'));
      case 'FIRST_TIME_CONTRIBUTOR':
        return this.stringOf($r('app.string.author_assoc_first_time'));
      case 'FIRST_TIMER':
        return this.stringOf($r('app.string.author_assoc_first_timer'));
      default:
        return '';
    }
  }

  /** 正文卡 Quote reply（同评论卡口径）：`> 正文` 引用进草稿并打开输入面板 */
  private quotePrBody(): void {
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

  /** 正文卡菜单 Share：分享 PR 链接（与顶栏 share 同出口） */
  private sharePr(): void {
    shareLink(this.getUIContext(), pullPageUrl(this.owner, this.name, this.number),
      `${this.owner}/${this.name} #${this.number}`);
  }

  /** 占位型菜单项（官方有、端侧管道未接入：提示「即将上线」，勿静默失败） */
  private comingSoon(): void {
    promptAction.showToast({ message: $r('app.string.home_feature_coming') });
  }

  /** 编辑表单入口（⋯ 菜单/正文卡菜单，viewerCanUpdate 门控；Spec 043 元素8） */
  private openEditPrForm(): void {
    this.bodyMenuOpen = false;
    this.pathStack.pushPathByName('prForm', `${this.owner}|${this.name}|edit|${this.number}`);
  }

  /** draft ↔ ready 切换（OPEN 未合并；viewerCanUpdate 门控，Spec 043 元素10） */
  private toggleDraft(): void {
    if (this.detail === null) {
      return;
    }
    const prId = this.detail.subjectId;
    const toReady = this.detail.isDraft;
    const task = toReady
      ? RepoSubService.markPullRequestReadyForReview(this.token, prId)
      : RepoSubService.convertPullRequestToDraft(this.token, prId);
    task.then(() => {
      this.refresh();
    }).catch((e: Error) => {
      promptAction.showToast({ message: friendlyError(this.getUIContext(), e) });
    });
  }

  /** 关闭 PR（⋯ 菜单 danger 项；成功后重拉状态与时间轴） */
  private closePr(): void {
    if (this.detail === null) {
      return;
    }
    RepoSubService.closePullRequest(this.token, this.detail.subjectId)
      .then(() => {
        this.refresh();
      })
      .catch((e: Error) => {
        promptAction.showToast({ message: friendlyError(this.getUIContext(), e) });
      });
  }

  /** 重开 PR（仅 closed 未合并；成功后重拉） */
  private reopenPr(): void {
    if (this.detail === null) {
      return;
    }
    RepoSubService.reopenPullRequest(this.token, this.detail.subjectId)
      .then(() => {
        this.refresh();
      })
      .catch((e: Error) => {
        promptAction.showToast({ message: friendlyError(this.getUIContext(), e) });
      });
  }

  /**
   * 顶栏 ⋮ 菜单（官方五行为基底，Spec 043 接线编辑/关闭并加 draft 切换；
   * 编辑/关闭/draft 按 viewerCanUpdate 门控，Change base/Unsubscribe/Lock 仍占位）。
   */
  private prMenuItems(): AppBarMenuItem[] {
    const items: AppBarMenuItem[] = [];
    const pr = this.detail;
    if (pr !== null && pr.viewerCanUpdate) {
      items.push({
        icon: $r('app.media.oct_pencil_16'),
        label: $r('app.string.menu_edit'),
        onAction: (): void => this.openEditPrForm()
      });
      if (pr.state === 'OPEN' && !pr.merged) {
        items.push({
          icon: pr.isDraft
            ? $r('app.media.oct_git_pull_request_16')
            : $r('app.media.oct_git_pull_request_draft_16'),
          label: pr.isDraft
            ? $r('app.string.mark_ready')
            : $r('app.string.convert_to_draft'),
          onAction: (): void => this.toggleDraft()
        });
        items.push({
          icon: $r('app.media.oct_git_pull_request_closed_16'),
          label: $r('app.string.menu_close_pr'),
          onAction: (): void => this.closePr(),
          danger: true
        });
      } else if (pr.state === 'CLOSED' && !pr.merged) {
        items.push({
          icon: $r('app.media.oct_git_pull_request_16'),
          label: $r('app.string.reopen_pr'),
          onAction: (): void => this.reopenPr()
        });
      }
    }
    items.push({
      icon: $r('app.media.oct_git_branch_16'),
      label: $r('app.string.menu_change_base'),
      onAction: (): void => this.comingSoon()
    });
    items.push({
      icon: $r('app.media.oct_bell_slash_16'),
      label: $r('app.string.menu_unsubscribe'),
      onAction: (): void => this.comingSoon()
    });
    items.push({
      icon: $r('app.media.oct_lock_16'),
      label: $r('app.string.menu_lock_conversation'),
      onAction: (): void => this.comingSoon()
    });
    return items;
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
                promptAction.showToast({
                  message: this.stringOf($r('app.string.comment_error_delete')) + ': ' + friendlyError(this.getUIContext(), e)
                });
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
      previewContext: `${this.owner}/${this.name}`,
      quoteSource: this.detail !== null ? this.detail.body : '',
      onNavigate: (name: string, param: string): void => this.navigateLink(name, param),
      onClose: (): void => this.closeComposer(),
      onPublished: (): void => this.afterCommentSaved(),
      onDraftChange: (t: string): void => {
        if (this.editingId === '') {
          this.draft = t;
        }
      }
    })
  }

  /** 元数据段头（官方 info 页：16fp 标题 + 右侧蓝色大写 EDIT；编辑器随 044 接入，先占位） */
  @Builder
  metaHeader(title: ResourceStr, kind: string) {
    Row() {
      Text(title)
        .fontSize($r('app.float.sub_text_font_size'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
      Text($r('app.string.pr_meta_edit'))
        .fontSize($r('app.float.sub_text_font_size'))
        .fontColor($r('app.color.link_blue'))
        .textCase(TextCase.UpperCase)
        .onClick((): void => this.openMetaEditor(kind))
    }
    .width('100%')
  }

  /** 空态文案（官方灰色常规体，与段内内容同字号） */
  @Builder
  metaEmpty(text: Resource) {
    Text(text)
      .fontSize($r('app.float.sub_text_font_size'))
      .fontColor($r('app.color.text_secondary'))
      .width('100%')
  }

  /** 段间全幅 1px 分隔线（官方 info 页为通栏线，不是内缩短线） */
  @Builder
  metaDivider() {
    Divider()
      .color($r('app.color.divider'))
      .strokeWidth(1)
      .width('100%')
  }

  /** 段间灰带（官方编辑器：白段之间露出的整条灰底，非 1px 线） */
  @Builder
  editorGap() {
    Row()
      .width('100%')
      .height(8)
      .backgroundColor($r('app.color.bg_page'))
  }

  /** 段内标题（Selected / Select Labels…：灰色常规体） */
  @Builder
  editorSectionLabel(text: string) {
    Text(text)
      .fontSize($r('app.float.sub_text_font_size'))
      .fontColor($r('app.color.text_secondary'))
      .width('100%')
      .padding({ left: 16, right: 16, top: 16, bottom: 8 })
  }

  /** 行首视觉：头像 / 彩色标签胶囊 / issue 状态字形 / 无 */
  @Builder
  editorRowLead(row: EditorRow) {
    if (row.avatarUrl !== undefined && row.avatarUrl !== '') {
      Image(row.avatarUrl)
        .width(32)
        .height(32)
        .borderRadius(16)
        .backgroundColor($r('app.color.heat_empty'))
    } else if (row.labelColor !== undefined) {
      LabelPill({ labelName: row.title, colorHex: row.labelColor })
    } else if (row.state !== undefined) {
      OctIcon({
        res: row.state === 'CLOSED' ? $r('app.media.oct_issue_closed_16') : $r('app.media.oct_issue_opened_16'),
        iconSize: 16,
        iconColor: row.state === 'CLOSED' ? $r('app.color.shortcut_purple_fg') : $r('app.color.success_text')
      })
    }
  }

  /** 候选行（行尾蓝色 ⊕；标签行只显示胶囊本体） */
  @Builder
  editorCandidateRow(row: EditorRow) {
    Row({ space: 10 }) {
      this.editorRowLead(row)
      if (row.labelColor === undefined) {
        Text(row.title)
          .fontSize($r('app.float.sub_text_font_size'))
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
      } else {
        Blank()
      }
      Stack() {
        OctIcon({ res: $r('app.media.oct_plus_circle_16'), iconSize: 20, iconColor: $r('app.color.link_blue') })
      }
      .width(44)
      .height(44)
    }
    .width('100%')
    .padding({ left: 16, right: 8, top: 6, bottom: 6 })
    .onClick((): void => this.toggleEditorRow(row))
  }

  /** 已选行（行尾灰底 ✕ 移除；标签行只显示胶囊本体） */
  @Builder
  editorSelectedRow(row: EditorRow) {
    Row({ space: 10 }) {
      this.editorRowLead(row)
      if (row.labelColor === undefined) {
        Text(row.title)
          .fontSize($r('app.float.sub_text_font_size'))
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
      } else {
        Blank()
      }
      Stack() {
        Circle()
          .width(24)
          .height(24)
          .fill($r('app.color.text_secondary'))
        OctIcon({ res: $r('app.media.oct_x_16'), iconSize: 14, iconColor: Color.White })
      }
      .width(44)
      .height(44)
      .onClick((): void => this.removeSelectedRow(row.id))
    }
    .width('100%')
    .padding({ left: 16, right: 8, top: 6, bottom: 6 })
  }

  /** 编辑器页（官方：头 ✕/← + 标题 + SAVE；搜索行；Selected 段 + 候选段，白段夹灰带） */
  @Builder
  metaEditorSheet() {
    Column() {
      // 头块（白底）：标题行 + 搜索行（Milestone 无搜索）+ Projects 分页签
      Column() {
        Row({ space: 4 }) {
          Stack() {
            OctIcon({
              res: this.metaEditor === 'assignees' ? $r('app.media.oct_x_24')
                : $r('app.media.oct_arrow_left_24'),
              iconSize: 20,
              iconColor: $r('app.color.text_primary')
            })
          }
          .width(44)
          .height(44)
          .accessibilityDescription($r('app.string.a11y_back'))
          .onClick((): void => this.closeMetaEditor())
          Text(this.editorTitle())
            .fontSize($r('app.float.title_font_size'))
            .fontWeight(600)
            .fontColor($r('app.color.text_primary'))
            .layoutWeight(1)
          Text($r('app.string.meta_editor_save'))
            .fontSize($r('app.float.sub_text_font_size'))
            .fontColor(this.saveEnabled() ? $r('app.color.link_blue') : $r('app.color.text_tertiary'))
            .padding({ left: 8, right: 8 })
            .onClick((): void => this.saveEditor())
        }
        .width('100%')
        .padding({ left: 4, right: 8 })

        if (this.metaEditor !== 'milestone') {
          Row({ space: 10 }) {
            OctIcon({ res: $r('app.media.oct_search_16'), iconSize: 16, iconColor: $r('app.color.text_secondary') })
            TextInput({ text: this.edSearch, placeholder: this.stringOf($r('app.string.meta_editor_search')) })
              .placeholderColor($r('app.color.text_secondary'))
              .fontSize($r('app.float.sub_text_font_size'))
              .fontColor($r('app.color.text_primary'))
              .backgroundColor(Color.Transparent)
              .padding({ left: 0, right: 0 })
              .height(44)
              .layoutWeight(1)
              .onChange((v: string): void => {
                this.edSearch = v;
              })
          }
          .width('100%')
          .padding({ left: 16, right: 16 })
        }

        if (this.metaEditor === 'projects') {
          Row() {
            this.editorTab($r('app.string.meta_editor_tab_recent'), 'recent')
            this.editorTab($r('app.string.meta_editor_tab_user'), 'user')
          }
          .width('100%')
        }
      }
      .width('100%')
      .backgroundColor($r('app.color.card_background'))

      // 主体：白段 + 中间灰带；内容不足时余下区域露灰底
      Scroll() {
        Column({ space: 8 }) {
          Column() {
            this.editorSectionLabel(this.stringOf($r('app.string.meta_editor_selected')))
            if (this.selRows.length === 0) {
              this.editorEmpty(this.stringOf(this.editorSelectedEmpty()))
            } else {
              ForEach(this.selRows, (row: EditorRow) => {
                this.editorSelectedRow(row)
              }, (row: EditorRow) => `sel-${row.id}`)
            }
          }
          .width('100%')
          .backgroundColor($r('app.color.card_background'))

          Column() {
            this.editorSectionLabel(this.editorCandidateLabel())
            if (this.candidateRows().length === 0) {
              this.editorEmpty(this.stringOf($r('app.string.meta_editor_no_results')))
            } else {
              ForEach(this.candidateRows(), (row: EditorRow) => {
                this.editorCandidateRow(row)
              }, (row: EditorRow) => `cand-${row.id}`)
            }
          }
          .width('100%')
          .backgroundColor($r('app.color.card_background'))
        }
        .width('100%')
      }
      .layoutWeight(1)
      .align(Alignment.Top)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_page'))
  }

  /** 空态行（灰色常规体，段内左对齐） */
  @Builder
  editorEmpty(text: string) {
    Text(text)
      .fontSize($r('app.float.sub_text_font_size'))
      .fontColor($r('app.color.text_secondary'))
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 20 })
  }

  /** 已选段空态文案（与 info 列表同口径，projects/linked 用各自的 No …） */
  private editorSelectedEmpty(): Resource {
    if (this.metaEditor === 'milestone') {
      return $r('app.string.pr_meta_no_milestone');
    }
    if (this.metaEditor === 'linked') {
      return $r('app.string.pr_meta_no_linked');
    }
    if (this.metaEditor === 'projects') {
      return $r('app.string.pr_meta_no_projects');
    }
    if (this.metaEditor === 'labels') {
      return $r('app.string.pr_meta_no_labels');
    }
    return $r('app.string.pr_meta_no_assignees');
  }

  /** Projects 分页签（RECENT / USER：等分 + 选中蓝色下划线） */
  @Builder
  editorTab(label: ResourceStr, key: string) {
    Column() {
      Text(label)
        .fontSize($r('app.float.sub_text_font_size'))
        .fontColor($r('app.color.text_primary'))
        .textCase(TextCase.UpperCase)
      Row()
        .width('100%')
        .height(2)
        .backgroundColor(this.edProjectTab === key ? $r('app.color.link_blue') : Color.Transparent)
        .margin({ top: 10 })
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
    .padding({ top: 8 })
    .onClick((): void => {
      if (this.edProjectTab !== key) {
        this.edProjectTab = key;
        this.edProjects = [];
        this.loadProjects(key);
      }
    })
  }

  /** 元数据概览底部页（官方 info 钮：五段 + 每段蓝 EDIT，段间全幅分隔线） */
  @Builder
  metaSheet() {
    if (this.metaEditor !== '') {
      this.metaEditorSheet()
    } else {
      this.metaInfoList()
    }
  }

  /** info 列表本体（五段 + 每段 EDIT） */
  @Builder
  metaInfoList() {
    Scroll() {
      Column() {
        Column({ space: 12 }) {
          this.metaHeader($r('app.string.pr_meta_assignees'), 'assignees')
          if (this.detail !== null && this.detail.assigneeItems.length > 0) {
            ForEach(this.detail.assigneeItems, (a: MetaUser) => {
              Row({ space: 10 }) {
                Image(a.avatarUrl)
                  .width(32)
                  .height(32)
                  .borderRadius(16)
                  .backgroundColor($r('app.color.heat_empty'))
                Text(a.login)
                  .fontSize($r('app.float.sub_text_font_size'))
                  .fontColor($r('app.color.text_primary'))
              }
              .width('100%')
            }, (a: MetaUser) => a.id)
          } else {
            this.metaEmpty($r('app.string.pr_meta_no_assignees'))
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 16, right: 16, top: 16, bottom: 16 })
        this.metaDivider()
        Column({ space: 12 }) {
          this.metaHeader($r('app.string.pr_meta_labels'), 'labels')
          if (this.detail !== null && this.detail.labelItems.length > 0) {
            Flex({ wrap: FlexWrap.Wrap }) {
              ForEach(this.detail.labelItems, (l: MetaLabel) => {
                Text(l.name)
                  .fontSize($r('app.float.caption_font_size'))
                  .fontWeight(FontWeight.Medium)
                  .fontColor(l.color === '' ? $r('app.color.text_primary') : labelTextColor(l.color, 'light'))
                  .padding({ left: 7, right: 7, top: 2, bottom: 2 })
                  .borderRadius($r('app.float.button_radius'))
                  .backgroundColor(l.color === '' ? $r('app.color.text_secondary') : labelBackground(l.color, 'light'))
                  .margin({ right: 8, bottom: 4 })
              }, (l: MetaLabel) => l.id)
            }
            // 官方标签行相对段头有轻微缩进
            .width('100%')
            .padding({ left: 8 })
          } else {
            this.metaEmpty($r('app.string.pr_meta_no_labels'))
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 16, right: 16, top: 16, bottom: 16 })
        this.metaDivider()
        Column({ space: 12 }) {
          this.metaHeader($r('app.string.pr_meta_milestone'), 'milestone')
          if (this.detail !== null && this.detail.milestoneItem !== null) {
            Text(this.detail.milestoneItem.title)
              .fontSize($r('app.float.sub_text_font_size'))
              .fontColor($r('app.color.text_primary'))
              .width('100%')
          } else {
            this.metaEmpty($r('app.string.pr_meta_no_milestone'))
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 16, right: 16, top: 16, bottom: 16 })
        this.metaDivider()
        Column({ space: 12 }) {
          this.metaHeader($r('app.string.pr_meta_linked'), 'linked')
          this.metaEmpty($r('app.string.pr_meta_no_linked'))
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 16, right: 16, top: 16, bottom: 16 })
        this.metaDivider()
        Column({ space: 12 }) {
          this.metaHeader($r('app.string.pr_meta_projects'), 'projects')
          this.metaEmpty($r('app.string.pr_meta_no_projects'))
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 16, right: 16, top: 16, bottom: 16 })
      }
      .width('100%')
    }
    .align(Alignment.Top)
    .height('100%')
    .scrollBar(BarState.Off)
  }

  /** 三态单选行（Comment / Approve / Request changes；选中高亮 link_blue） */
  @Builder
  reviewOption(labelRes: Resource, value: string, colorFg: ResourceColor) {
    Row({ space: 10 }) {
      Stack() {
        Circle()
          .width(18)
          .height(18)
          .fill(Color.Transparent)
          .stroke(this.reviewEvent === value ? $r('app.color.link_blue') : $r('app.color.border'))
          .strokeWidth(1.5)
        if (this.reviewEvent === value) {
          Circle()
            .width(10)
            .height(10)
            .fill($r('app.color.link_blue'))
        }
      }
      Text(labelRes)
        .fontSize($r('app.float.body_font_size'))
        .fontColor(this.reviewEvent === value ? $r('app.color.text_primary') : colorFg)
    }
    .width('100%')
    .height(44)
    .onClick((): void => {
      this.reviewEvent = value;
    })
  }

  /** Review changes 面板（Spec 042 元素5/6）：编辑模式=仅总结；三态模式=单选+总结+提交 */
  @Builder
  reviewSheet() {
    Column({ space: 10 }) {
      Text(this.editingReviewId !== '' ? $r('app.string.pr_review_edit') : $r('app.string.pr_review_changes'))
        .fontSize($r('app.float.sub_text_font_size'))
        .fontWeight(600)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
      if (this.editingReviewId === '') {
        this.reviewOption($r('app.string.pr_review_type_comment'), 'COMMENT', $r('app.color.text_primary'))
        this.reviewOption($r('app.string.pr_review_type_approve'), 'APPROVE', $r('app.color.success_text'))
        this.reviewOption($r('app.string.pr_review_type_request'), 'REQUEST_CHANGES', $r('app.color.danger_text'))
        Divider().color($r('app.color.divider'))
      }
      TextArea({
        text: this.reviewBody,
        placeholder: this.stringOf($r('app.string.pr_review_summary_hint'))
      })
        .fontSize($r('app.float.body_font_size'))
        .height(120)
        .borderRadius(6)
        .backgroundColor($r('app.color.input_bg'))
        .onChange((v: string): void => {
          this.reviewBody = v;
        })
      Button(this.editingReviewId !== '' ? $r('app.string.pr_review_save') : $r('app.string.pr_review_submit'))
        .type(ButtonType.Normal)
        .width('100%')
        .height(44)
        .borderRadius(6)
        .backgroundColor($r('app.color.link_blue'))
        .enabled(!this.reviewSending && (this.editingReviewId !== '' || this.reviewEvent !== 'COMMENT'
          || this.reviewBody.trim() !== ''))
        .onClick((): void => this.submitReview())
    }
    .width('100%')
    .height('100%')
    .padding({ left: 16, right: 16, top: 16, bottom: 16 })
  }

  /** 正文卡行内菜单（作者头 ⋯，官方 OP 头部口径）：Share / Quote reply / Edit / 灰线 / Report / Block */
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
        this.sharePr();
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
        this.quotePrBody();
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
          this.openEditPrForm();
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
    Stack({ alignContent: Alignment.BottomEnd }) {
      Column() {
      AppBar({
        showBack: true,
        // 官方两行顶栏：上行 owner/name #N 小字灰色，下行标题（超长开头省略、结尾完整）
        title: this.detail !== null ? this.detail.title : '',
        subtitle: `${this.owner}/${this.name} #${this.number}`,
        subtitleAbove: true,
        titleHeadEllipsis: true,
        onBack: (): void => {
          this.pathStack.pop();
        },
        actions: [
          new AppBarAction($r('app.media.oct_share_android_16'), (): void => {
            shareLink(this.getUIContext(), pullPageUrl(this.owner, this.name, this.number),
              `${this.owner}/${this.name} #${this.number}`);
          }, { iconColor: $r('app.color.link_blue'), a11y: $r('app.string.a11y_share') }),
          new AppBarAction($r('app.media.oct_kebab_horizontal_16'), (): void => {
          }, {
            rotate90: true, iconColor: $r('app.color.link_blue'), a11y: $r('app.string.a11y_more'),
            menuItems: this.prMenuItems()
          })
        ]
      })

      PageShadowBar({ show: this.scrollShadow })

      Refresh({ refreshing: $$this.isRefreshing }) {
        Scroll() {
          Column() {
            if (this.detail !== null) {
            // 第一部分：页头卡（官方结构：作者行 → 标题 → 状态胶囊 + 分支行）
            Column({ space: 8 }) {
              // 作者行（官方为仓库上下文行）：owner 头像 + `owner / repoName #N`，仓库名与编号弱化
              Row({ space: 8 }) {
                if (this.detail.ownerAvatar !== '') {
                  Image(this.detail.ownerAvatar)
                    .width(20)
                    .height(20)
                    .borderRadius(10)
                    .backgroundColor($r('app.color.heat_empty'))
                }
                Text() {
                  Span(this.owner)
                    .fontWeight(FontWeight.Medium)
                    .fontColor($r('app.color.text_primary'))
                  Span(` / ${this.name}`)
                    .fontColor($r('app.color.text_secondary'))
                  Span(` #${this.number}`)
                    .fontColor($r('app.color.text_secondary'))
                }
                .fontSize($r('app.float.caption_font_size'))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .layoutWeight(1)
              }
              .width('100%')

              Text(this.detail.title)
                .fontSize($r('app.float.title_font_size'))
                .fontWeight(600)
                .fontColor($r('app.color.text_primary'))
                .width('100%')
                .lineHeight(28)
                .maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis })

              // 状态胶囊固定在行首，分支段（超长 dependabot 分支名）单独横向滚动
              Row({ space: 8 }) {
                Row({ space: 4 }) {
                  OctIcon({ res: this.statePillIcon(this.detail), iconSize: 12, iconColor: Color.White })
                  Text(this.statePillText(this.detail))
                    .fontSize($r('app.float.caption_font_size'))
                    .fontColor(Color.White)
                }
                .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                .borderRadius(12)
                .backgroundColor(this.statePillBg(this.detail))

                if (this.detail.headRefName !== '') {
                  Scroll() {
                    Row({ space: 8 }) {
                      Text(this.detail.headRefName)
                        .fontSize($r('app.float.caption_font_size'))
                        .fontColor($r('app.color.shortcut_blue_fg'))
                        .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                        .borderRadius(2)
                        .backgroundColor($r('app.color.shortcut_blue_bg'))
                      if (this.detail.baseRefName !== '') {
                        Text('→')
                          .fontSize($r('app.float.caption_font_size'))
                          .fontColor($r('app.color.text_primary'))
                        Text(this.detail.baseRefName)
                          .fontSize($r('app.float.caption_font_size'))
                          .fontColor($r('app.color.shortcut_blue_fg'))
                          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                          .borderRadius(2)
                          .backgroundColor($r('app.color.shortcut_blue_bg'))
                      }
                    }
                  }
                  .scrollable(ScrollDirection.Horizontal)
                  .scrollBar(BarState.Off)
                  .layoutWeight(1)
                }
              }
              .width('100%')
              .alignItems(VerticalAlign.Center)
            }
            .padding($r('app.float.card_padding'))
            .borderRadius($r('app.float.card_radius'))
            .backgroundColor($r('app.color.card_background'))
            .width('100%')
            .margin({ bottom: 12 })

            // 第二部分：正文卡（官方评论卡形态：作者头 + 正文）
            if (this.detail.body !== '' || this.detail.bodyHTML !== '') {
              Column({ space: 6 }) {
                Row({ space: 8 }) {
                  if (this.detail.authorAvatar !== '') {
                    Image(this.detail.authorAvatar)
                      .width(40)
                      .height(40)
                      .borderRadius(20)
                      .backgroundColor($r('app.color.heat_empty'))
                  } else {
                    Circle().width(40).height(40).fill($r('app.color.heat_empty'))
                  }
                  Column({ space: 3 }) {
                    // 行1：author name · 4d（名字黑体，时间弱化）
                    Text() {
                      Span(this.detail.authorLogin)
                        .fontWeight(FontWeight.Medium)
                        .fontColor($r('app.color.text_primary'))
                      Span(` · ${this.timeText(timeParts(this.detail.createdAt, Date.now()))}`)
                        .fontColor($r('app.color.text_secondary'))
                    }
                    .fontSize($r('app.float.body_font_size'))
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    // 行2：角色胶囊（白底描边全圆胶囊；NONE 不显示）
                    if (this.authorRoleText(this.detail) !== '') {
                      Text(this.authorRoleText(this.detail))
                        .fontSize($r('app.float.caption_font_size'))
                        .fontColor($r('app.color.text_primary'))
                        .padding({ left: 8, right: 8, top: 1, bottom: 1 })
                        .borderRadius(12)
                        .backgroundColor($r('app.color.card_background'))
                        .border({ width: 1, color: $r('app.color.divider') })
                    }
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)

                  // 右上灰三横点（官方 OP 头部：菜单 Share / Quote reply）
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
                .alignItems(VerticalAlign.Top)

                MarkdownView({
                  html: this.detail.bodyHTML,
                  fallbackText: this.detail.body,
                  onNavigate: (name: string, param: string) => this.navigateLink(name, param)
                })

                // 正文反应行（官方评论卡形态）：笑脸圆钮弹 8 种全集，芯片整颗可点翻转，长按进 Reactees 整页
                ReactionBar({
                  token: this.token,
                  subjectId: this.detail.subjectId,
                  reactions: this.detail.reactions,
                  smileyTrigger: true,
                  pickerFull: true,
                  onChanged: (): void => this.refresh(),
                  onOpenUsers: (subjectId: string, content: string): void => {
                    // id 经 encodeURIComponent（GraphQL id 为 base64，可能含 /）
                    this.pathStack.pushPathByName('reactionUsers',
                      `${encodeURIComponent(subjectId)}/${content}`);
                  }
                })
              }
              .padding($r('app.float.card_padding'))
              .borderRadius($r('app.float.card_radius'))
              .backgroundColor($r('app.color.card_background'))
              .width('100%')
              .margin({ bottom: 12 })
            }

            // Changes 卡片
            Column({ space: 8 }) {
              this.sectionTitle(this.stringOf($r('app.string.pr_changes_title')))
              Row({ space: 8 }) {
                OctIcon({ res: $r('app.media.oct_file_diff_16'), iconSize: 14, iconColor: $r('app.color.text_secondary') })
                Text(resText(this.getUIContext(), $r('app.string.pr_files_changed'), this.detail.filesCount))
                  .fontSize($r('app.float.body_font_size'))
                  .fontColor($r('app.color.text_primary'))
                Blank()
                Text(`+${this.detail.additions}`)
                  .fontSize($r('app.float.caption_font_size'))
                  .fontColor($r('app.color.success_text'))
                Text(`-${this.detail.deletions}`)
                  .fontSize($r('app.float.caption_font_size'))
                  .fontColor($r('app.color.danger_text'))
              }
              .width('100%')
              .onClick(() => {
                this.pathStack.pushPathByName('prFiles', `${this.owner}/${this.name}/${this.number}`);
              })
              Row({ space: 8 }) {
                OctIcon({ res: $r('app.media.oct_git_commit_16'), iconSize: 14, iconColor: $r('app.color.text_secondary') })
                Text(resText(this.getUIContext(), $r('app.string.pr_commits_count'), this.detail.commitsCount))
                  .fontSize($r('app.float.body_font_size'))
                  .fontColor($r('app.color.text_primary'))
                Blank()
                Text(`${this.timeText(timeParts(this.detail.createdAt, Date.now()))} ${this.stringOf($r('app.string.pr_time_ago'))}`)
                  .fontSize($r('app.float.caption_font_size'))
                  .fontColor($r('app.color.text_secondary'))
              }
              .width('100%')
              .onClick(() => {
                this.pathStack.pushPathByName('repoCommits', `${this.owner}/${this.name}/${this.number}`);
              })
            }
            .padding($r('app.float.card_padding'))
            .borderRadius($r('app.float.card_radius'))
            .backgroundColor($r('app.color.card_background'))
            .width('100%')
            .margin({ bottom: 12 })

            // Status 卡片（组件化，checks 展开态自持有；Merge 区块随 detail 刷新）
            PrStatusCard({
              detail: this.detail,
              merging: this.mergeSending,
              onMergeOpen: (): void => this.openMergeOptions(),
              onMergeConfirm: (): void => this.confirmMergeTap(),
              // Spec 048：check run 行 → 详情页（权限透传做重跑门）；View all → Checks 全量页
              onOpenCheck: (item: StatusCheckItem): void => {
                // 闭包内可空 @Local 收窄丢失（坑 44）：先落局部常量再门
                const d = this.detail;
                if (d === null) {
                  return;
                }
                this.pathStack.pushPathByName('checkRunDetail',
                  `${this.owner}|${this.name}|${item.checkRunId}|${d.repoViewerPermission}` +
                  `|${item.name}|${item.appLogo}|${item.detailsUrl}`);
              },
              onViewAllChecks: (): void => {
                const d = this.detail;
                if (d === null) {
                  return;
                }
                this.pathStack.pushPathByName('prChecks',
                  `${this.owner}/${this.name}/${this.number}|${d.repoViewerPermission}`);
              }
            })

            // Conversation = 官方时间轴：左侧竖直连线 + 事件行 + 评论/审阅整卡（时间序）
            Column({ space: 8 }) {
              this.sectionTitle(this.stringOf($r('app.string.pr_conversation_title')))
              if (this.detail.timeline.length === 0) {
                Text($r('app.string.issues_empty'))
                  .fontSize($r('app.float.caption_font_size'))
                  .fontColor($r('app.color.text_secondary'))
              }
              Stack({ alignContent: Alignment.TopStart }) {
                // 竖线贯穿整轴：高度取内容实测值（Percent 会与外层 Stack 互撑，导致线拖长）；顶端对齐首个节点图标中心；
                // zIndex 显式分层 → 不透明的评论/审阅卡在线之上，把线遮断（同官方观感）
                Column()
                  .width(1)
                  .height(this.timelineContentH)
                  .backgroundColor($r('app.color.divider'))
                  .margin({ left: 15.5, top: 16 })
                  .zIndex(0)
                Column() {
                  ForEach(this.detail.timeline, (item: TimelineNode) => {
                    if (item.kind === 'comment' && item.comment !== null) {
                      CommentCard({
                        comment: this.commentOf(item),
                        token: this.token,
                        onNavigate: (name: string, param: string) => this.navigateLink(name, param),
                        onEdit: (comment: RepoComment) => {
                          this.editingId = comment.id;
                          this.editingInitial = comment.body;
                          this.sheetKind = 'composer';
                          this.sheetOpen = true;
                        },
                        onDelete: (comment: RepoComment) => this.confirmDeleteComment(comment),
                        onShare: (comment: RepoComment): void => {
                          shareLink(this.getUIContext(), pullPageUrl(this.owner, this.name, this.number),
                            `${this.owner}/${this.name} #${this.number}`);
                        },
                        onQuoteReply: (comment: RepoComment): void => {
                          // 官方 Quote reply：`> 正文` 引用进草稿并打开输入面板
                          const quoted = comment.body.split('\n').map((line: string): string => `> ${line}`).join('\n');
                          this.draft = `${quoted}\n\n`;
                          this.editingId = '';
                          this.editingInitial = '';
                          this.sheetKind = 'composer';
                          this.sheetOpen = true;
                        },
                        onReactionChanged: (): void => this.refresh()
                      })
                    } else if (item.kind === 'review' && item.review !== null) {
                      this.reviewCard(this.reviewOf(item))
                    } else {
                      TimelineRow({
                        node: item,
                        onOpenCommit: (oid: string): void => this.openCommit(oid)
                      })
                    }
                  }, (item: TimelineNode) => `${item.kind}-${item.id}`)
                }
                .width('100%')
                .padding({ bottom: 20 })
                .zIndex(1)
                .onAreaChange((_oldArea: Area, newArea: Area) => {
                  this.timelineContentH = Number(newArea.height);
                })
              }
              .width('100%')
              if (this.timelineHasNext) {
                ListLoadingFooter({ show: this.loadingMore })
              }
              if (this.detail.merged) {
                Button($r('app.string.pr_delete_branch'))
                  .buttonStyle(ButtonStyleMode.NORMAL)
                  .width('100%')
                  .height(40)
                  .fontSize($r('app.float.caption_font_size'))
                  .fontColor($r('app.color.text_secondary'))
                  .backgroundColor($r('app.color.card_background'))
                  .borderRadius(6)
                  .border({ width: 1, color: $r('app.color.border') })
                  .onClick(() => {
                    const ui = this.getUIContext();
                    ui.getPromptAction().showDialog(
                      {
                        message: this.stringOf($r('app.string.pr_delete_branch_confirm')),
                        buttons: [
                          {
                            text: this.stringOf($r('app.string.pr_delete_branch_cancel')),
                            color: $r('app.color.link_blue')
                          },
                          {
                            text: this.stringOf($r('app.string.pr_delete_branch_confirm_delete')),
                            color: $r('app.color.badge_red')
                          }
                        ]
                      },
                      (err, data) => {
                        if (err) {
                          return;
                        }
                        if (data.index === 1) {
                          promptAction.showToast({ message: $r('app.string.home_feature_coming') });
                        }
                      }
                    );
                  })
              }
            }
            // 官方口径：会话区不套白卡（灰底时间轴 + 通栏白卡节点），时间轴节点自身成卡
            .width('100%')

            // ReviewThreads 卡（Spec 042：diff 行内评论集合；重拉后 Resolved 折叠）
            if (this.detail.threads.length > 0) {
              ReviewThreadsCard({
                threads: this.detail.threads,
                token: this.token,
                onRefresh: (): void => this.refresh(),
                onNavigate: (name: string, param: string): void => this.navigateLink(name, param)
              })
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
        this.loadMoreTimeline();
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
      // 右下悬浮操作钮（Android 官方形态：黑色 COMMENT 胶囊 + 圆形 Review changes 钮；已合并隐藏审阅钮）
      Row({ space: 10 }) {
        Blank()
        Row({ space: 6 }) {
          OctIcon({ res: $r('app.media.oct_comment_16'), iconSize: 14, iconColor: Color.White })
          Text($r('app.string.comment_button'))
            .fontSize($r('app.float.body_font_size'))
            .fontWeight(FontWeight.Medium)
            .fontColor(Color.White)
        }
        .height(46)
        .padding({ left: 18, right: 18 })
        .borderRadius(10)
        .backgroundColor($r('app.color.floating_btn_bg'))
        .shadow({ radius: 12, color: $r('app.color.shadow_floating'), offsetY: 4 })
        .onClick(() => this.openComposer())
        Stack() {
          OctIcon({ res: $r('app.media.oct_info_16'), iconSize: 16, iconColor: Color.White })
        }
        .width(46)
        .height(46)
        .borderRadius(10)
        .backgroundColor($r('app.color.floating_btn_bg'))
        .shadow({ radius: 12, color: $r('app.color.shadow_floating'), offsetY: 4 })
        .accessibilityDescription($r('app.string.a11y_info'))
        .onClick(() => this.openMetaSheet())
      }
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 16 })
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.bg_page'))
    .bindSheet($$this.sheetOpen, this.sheetBuilder(), this.sheetOptions())
  }

  /** 整页形态弹层（官方：拖拽条 + 白底 + 全高）：Merge options、info 元数据页 */
  private isPageSheet(): boolean {
    return this.sheetKind === 'mergeOptions' || this.sheetKind === 'meta'
      || this.sheetKind === 'composer';
  }

  /**
   * 弹层选项。整页形态必须给**多档 detents**：只设单档 SheetSize.LARGE 时控制条虽然画得出来，
   * 但按官方口径「detents 设置多个不同高度并生效时才支持跟手拖动」，表现就是拖不动、滑不回去。
   * 配 [LARGE, MEDIUM] 后可下滑收到半屏、继续下滑关闭；半屏弹层维持原有高度（本就可下滑收起）。
   */
  private sheetOptions(): SheetOptions {
    if (this.isPageSheet()) {
      return {
        height: SheetSize.LARGE,
        detents: [SheetSize.LARGE, SheetSize.MEDIUM],
        showClose: false,
        backgroundColor: $r('app.color.card_background'),
        dragBar: true,
        // 评论输入页：键盘弹起时缩面板（RESIZE_ONLY），让格式工具条停在键盘正上方。
        // 默认 TRANSLATE_AND_SCROLL 是先改高、满高后靠滚动避让，而输入页没有可滚容器 → 工具条会被键盘盖住。
        keyboardAvoidMode: this.sheetKind === 'composer'
          ? SheetKeyboardAvoidMode.RESIZE_ONLY : SheetKeyboardAvoidMode.TRANSLATE_AND_SCROLL,
        onDisappear: (): void => this.onSheetDismissed()
      };
    }
    return {
      height: 560,
      detents: [560, SheetSize.LARGE],
      showClose: false,
      backgroundColor: $r('app.color.bg_page'),
      dragBar: true,
      onDisappear: (): void => this.onSheetDismissed()
    };
  }

  /** 弹层内容分派（坑 2：单 bindSheet + sheetKind） */
  @Builder
  sheetBuilder() {    if (this.sheetKind === 'review') {
      this.reviewSheet()
    } else if (this.sheetKind === 'meta') {
      this.metaSheet()
    } else if (this.sheetKind === 'mergeOptions') {
      this.mergeOptionsSheet()
    } else {
      this.composerSheet()
    }
  }

  /** 合并方式单选行（左侧标题 + 说明，右侧官方圆形单选：选中=蓝环实心） */
  @Builder
  mergeMethodRow(method: string) {
    Row({ space: 12 }) {
      Column({ space: 4 }) {
        Text(this.mergeMethodTitle(method))
          .fontSize($r('app.float.sub_text_font_size'))
          .fontColor($r('app.color.text_primary'))
          .width('100%')
        Text(this.mergeMethodDesc(method))
          .fontSize($r('app.float.body_font_size'))
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Stack() {
        Circle()
          .width(20)
          .height(20)
          .fill(Color.Transparent)
          .stroke(this.mergeMethod === method ? $r('app.color.link_blue') : $r('app.color.border'))
          .strokeWidth(1.5)
        if (this.mergeMethod === method) {
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
    .padding({ top: 10, bottom: 10 })
    .onClick((): void => this.pickMergeMethod(method))
  }

  /** Merge options 底部页（官方：← 标题 / Merge method 单选 / 灰带 / 提交信息 + EDIT / MERGE） */
  @Builder
  mergeOptionsSheet() {
    Column() {
      // 头部：← 返回（官方为返回箭头，非 CANCEL 钮）
      Row({ space: 4 }) {
        Stack() {
          OctIcon({ res: $r('app.media.oct_arrow_left_24'), iconSize: 20, iconColor: $r('app.color.text_primary') })
        }
        .width(44)
        .height(44)
        .accessibilityDescription($r('app.string.a11y_back'))
        .onClick((): void => {
          this.sheetOpen = false;
        })
        Text($r('app.string.pr_merge_options_title'))
          .fontSize($r('app.float.title_font_size'))
          .fontWeight(600)
          .fontColor($r('app.color.text_primary'))
      }
      .width('100%')
      .padding({ left: 4, right: 16 })

      Scroll() {
        Column() {
          Column({ space: 2 }) {
            Text($r('app.string.pr_merge_method_label'))
              .fontSize($r('app.float.body_font_size'))
              .fontColor($r('app.color.text_secondary'))
              .width('100%')
              .margin({ top: 8, bottom: 4 })
            this.mergeMethodRow('MERGE')
            this.mergeMethodRow('SQUASH')
            this.mergeMethodRow('REBASE')
          }
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 12 })
          .alignItems(HorizontalAlign.Start)

          // 全幅灰带分组（官方为整条灰底，非 1px 分隔线）
          Row()
            .width('100%')
            .height(8)
            .backgroundColor($r('app.color.bg_page'))

          Column({ space: 12 }) {
            Row({ space: 8 }) {
              Text($r('app.string.pr_merge_commit_custom'))
                .fontSize($r('app.float.body_font_size'))
                .fontColor($r('app.color.text_secondary'))
                .layoutWeight(1)
              Text($r('app.string.pr_merge_edit'))
                .fontSize($r('app.float.body_font_size'))
                .fontColor($r('app.color.link_blue'))
                .onClick((): void => {
                  this.mergeEditing = !this.mergeEditing;
                })
            }
            .width('100%')

            if (this.mergeEditing) {
              TextInput({ text: this.mergeHeadline })
                .fontSize($r('app.float.body_font_size'))
                .height(44)
                .borderRadius(6)
                .backgroundColor($r('app.color.input_bg'))
                .onChange((v: string): void => {
                  this.mergeHeadline = v;
                })
              TextArea({ text: this.mergeBody })
                .fontSize($r('app.float.body_font_size'))
                .fontFamily('monospace')
                .height(120)
                .borderRadius(6)
                .backgroundColor($r('app.color.input_bg'))
                .onChange((v: string): void => {
                  this.mergeBody = v;
                })
            } else {
              Text(this.mergeHeadline)
                .fontSize($r('app.float.sub_text_font_size'))
                .fontWeight(600)
                .fontColor($r('app.color.text_primary'))
                .width('100%')
              if (this.mergeBody !== '') {
                Text(this.mergeBody)
                  .fontFamily('monospace')
                  .fontSize($r('app.float.body_font_size'))
                  .fontColor($r('app.color.text_primary'))
                  .width('100%')
              }
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding({ left: 16, right: 16, top: 16, bottom: 16 })
        }
        .width('100%')
      }
      .layoutWeight(1)
      .align(Alignment.Top)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
  }
}
