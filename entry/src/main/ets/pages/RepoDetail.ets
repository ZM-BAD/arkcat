/**
 * Repo Detail 页（Spec 006）：官方布局对齐。
 * 头部（业主/描述/stars/forks）+ 操作区（STAR+fork/🔔）+ 计数入口（Issues/PR/Actions/Releases）
 * + More 折叠区（分支/Code/Commits/README·EDIT）+ README 简化富文本。
 * Packages/Settings 按边界不展示；文件列表/语言占比收进 More（查询保留）。
 */
import { promptAction } from '@kit.ArkUI';
import { RepoDetail, FileEntry, LanguageSlice } from '../models/RepoDetailModels';
import { RepoService } from '../services/RepoService';
import { MarkdownService, MarkdownFetchResult } from '../services/MarkdownService';
import { StateView } from '../components/StateView';
import { AppBar, AppBarAction, AppBarActionCfg } from '../components/AppBar';
import { OctIcon } from '../components/OctIcon';
import { PageShadowBar } from '../components/PageShadowBar';
import { MarkdownView } from '../components/MarkdownView';
import { resText } from '../utils/I18n';
import { githubShortTime, timeParts, TimeParts } from '../utils/Format';

@ComponentV2
export struct RepoDetailView {
  @Param owner: string = '';
  @Param name: string = '';
  @Param token: string = '';
  @Param pathStack: NavPathStack = new NavPathStack();
  @Local detail: RepoDetail | null = null;
  @Local loading: boolean = true;
  @Local errorMsg: string = '';
  /** 滚动顶部阴影（滚动中显示、回顶消失） */
  @Local scrollShadow: boolean = false;
  @Local isRefreshing: boolean = false;
  @Local busy: boolean = false;
  @Local moreExpanded: boolean = false;
  /** README 官方 HTML（REST /readme html+json；null=未加载） */
  @Local readmeResult: MarkdownFetchResult | null = null;

  aboutToAppear(): void {
    this.refresh();
  }

  private refresh(): void {
    if (this.owner === '' || this.name === '') {
      return;
    }
    this.loading = true;
    this.errorMsg = '';
    this.readmeResult = null;
    RepoService.fetchRepoDetail(this.token, this.owner, this.name)
      .then((detail: RepoDetail) => {
        this.detail = detail;
        this.loading = false;
        this.isRefreshing = false;
        this.loadReadme();
      })
      .catch((e: Error) => {
        this.errorMsg = e.message;
        this.loading = false;
        this.isRefreshing = false;
      });
  }

  /** README 走官方渲染管线（Spec 040：REST html+json；GraphQL readmeText 仅作降级） */
  private loadReadme(): void {
    MarkdownService.fetchReadmeHtml(this.token, this.owner, this.name)
      .then((res: MarkdownFetchResult) => {
        this.readmeResult = res;
        this.isRefreshing = false;
      })
      .catch(() => {
        this.readmeResult = { status: 'error', html: '' };
        this.isRefreshing = false;
      });
  }

  /** stargazers 入口可见性：仅本人仓库（Spec 053；他人仓库点击无反应，对齐官方 App） */
  private get canViewStargazers(): boolean {
    const detail = this.detail;
    return detail !== null && detail.viewerLogin !== '' && detail.ownerLogin === detail.viewerLogin;
  }

  private navigateLink(name: string, param: string): void {
    this.pathStack.pushPathByName(name, param);
  }

  private onStar(): void {
    const detail = this.detail;
    if (detail === null || detail.repoId === '' || this.busy) {
      return;
    }
    this.busy = true;
    RepoService.toggleStar(this.token, detail.repoId, detail.viewerHasStarred)
      .then((starred: boolean) => {
        const updated: RepoDetail = {
          repoId: detail.repoId,
          name: detail.name,
          nameWithOwner: detail.nameWithOwner,
          description: detail.description,
          stargazerCount: detail.stargazerCount + (starred ? 1 : -1),
          forkCount: detail.forkCount,
          watcherCount: detail.watcherCount,
          viewerHasStarred: starred,
          licenseName: detail.licenseName,
          topics: detail.topics,
          readmeText: detail.readmeText,
          files: detail.files,
          languages: detail.languages,
          lastCommitMessage: detail.lastCommitMessage,
          ownerAvatarUrl: detail.ownerAvatarUrl,
          ownerLogin: detail.ownerLogin,
          viewerLogin: detail.viewerLogin,
          issueCount: detail.issueCount,
          prCount: detail.prCount,
          hasDiscussions: detail.hasDiscussions,
          discussionCount: detail.discussionCount,
          releaseCount: detail.releaseCount,
          defaultBranchRefName: detail.defaultBranchRefName
        };
        this.detail = updated;
        const ui = this.getUIContext();
        promptAction.showToast({
          message: starred
            ? resText(ui, $r('app.string.repo_starred_toast'))
            : resText(ui, $r('app.string.repo_unstarred_toast'))
        });
      })
      .catch((e: Error) => {
        promptAction.showToast({ message: this.fmt($r('app.string.repo_star_failed'), e.message) });
      })
      .finally(() => {
        this.busy = false;
      });
  }

  /** 带 %1$s 格式化：资源模板 + 参数 → 当前语言文案 */
  private fmt(res: Resource, arg: string): string {
    return resText(this.getUIContext(), res, arg);
  }

  /** 资源 → 当前语言的纯文案 */
  private stringOf(res: Resource): string {
    return resText(this.getUIContext(), res);
  }

  private onFork(): void {
    const detail = this.detail;
    if (detail === null || detail.repoId === '' || this.busy) {
      return;
    }
    this.busy = true;
    RepoService.createFork(this.token, detail.repoId)
      .then(() => {
        promptAction.showToast({ message: $r('app.string.repo_fork_created_toast') });
      })
      .catch((e: Error) => {
        promptAction.showToast({ message: this.fmt($r('app.string.repo_fork_failed'), e.message) });
      })
      .finally(() => {
        this.busy = false;
      });
  }

  private openIssues(): void {
    // Spec 007 注册 issuesList 路由后接入
    this.pathStack.pushPathByName('issuesList', `${this.owner}/${this.name}`);
  }

  private openPrs(): void {
    this.pathStack.pushPathByName('repoPrs', `${this.owner}/${this.name}`);
  }

  private openDiscussions(): void {
    this.pathStack.pushPathByName('repoDiscussions', `${this.owner}/${this.name}`);
  }

  private openReleases(): void {
    this.pathStack.pushPathByName('repoReleases', `${this.owner}/${this.name}`);
  }

  private openCommits(): void {
    this.pathStack.pushPathByName('repoCommits', `${this.owner}/${this.name}`);
  }

  /** Spec 038：More → 文件 → 仓库文件树 */
  private openFiles(): void {
    this.pathStack.pushPathByName('repoFiles', `${this.owner}|${this.name}|`);
  }

  private comingSoon(): void {
    promptAction.showToast({ message: $r('app.string.home_feature_coming') });
  }

  /** 相对时间结构化数据 → 当前语言文案（%1$d 位置占位） */
  private timeText(parts: TimeParts | null): string {
    return parts !== null ? githubShortTime(parts) : '';
  }

  @Builder
  headerBox() {
    Column({ space: 8 }) {
      Row({ space: 6 }) {
        Image(this.detail?.ownerAvatarUrl ?? '')
          .width(20)
          .height(20)
          .borderRadius(12)
          .backgroundColor($r('app.color.heat_empty'))
        Text(this.detail?.ownerLogin ?? '')
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_primary'))
      }
      .width('100%')

      Text(this.detail?.name ?? '')
        .fontSize($r('app.float.title_font_size'))
        .fontWeight(600)
        .fontColor($r('app.color.text_primary'))
        .width('100%')

      if (this.detail !== null && this.detail.description !== '') {
        Text(this.detail.description)
          .fontSize($r('app.float.body_font_size'))
          .fontColor($r('app.color.text_primary'))
          .width('100%')
      }

      Row({ space: 5 }) {
        Row({ space: 5 }) {
          OctIcon({ res: $r('app.media.oct_star_16'), iconSize: 14, iconColor: $r('app.color.text_secondary') })
          Text(`${this.detail?.stargazerCount ?? 0}`)
            .fontSize($r('app.float.caption_font_size'))
            .fontColor($r('app.color.text_secondary'))
          Text($r('app.string.repo_stars_label'))
            .fontSize($r('app.float.caption_font_size'))
            .fontColor($r('app.color.text_secondary'))
        }
        .responseRegion({ x: 0, y: -12, width: '100%', height: '220%' })
        .onClick(() => {
          // stargazers 名单仅本人仓库可见（Spec 053）：他人仓库点击无任何反应
          if (!this.canViewStargazers) {
            return;
          }
          this.pathStack.pushPathByName('stargazers', `${this.owner}/${this.name}`);
        })
        Text('·')
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_tertiary'))
          .margin({ left: 2, right: 2 })
        Row({ space: 5 }) {
          OctIcon({ res: $r('app.media.oct_repo_forked_16'), iconSize: 14, iconColor: $r('app.color.text_secondary') })
          Text(`${this.detail?.forkCount ?? 0}`)
            .fontSize($r('app.float.caption_font_size'))
            .fontColor($r('app.color.text_secondary'))
          Text($r('app.string.repo_forks_label'))
            .fontSize($r('app.float.caption_font_size'))
            .fontColor($r('app.color.text_secondary'))
        }
        .responseRegion({ x: 0, y: -12, width: '100%', height: '220%' })
        .onClick(() => {
          this.pathStack.pushPathByName('forks', `${this.owner}/${this.name}`);
        })
      }
      .width('100%')
    }
    .padding({ left: 16, right: 16, top: 8, bottom: 8 })
    .width('100%')
  }

  /** 操作区：STAR 大按钮 + fork/🔔 两个圆钮 */
  @Builder
  actionBar() {
    Row({ space: 8 }) {
      Row({ space: 6 }) {
        OctIcon({ res: $r('app.media.oct_star_16'), iconSize: 16, iconColor: $r('app.color.text_primary') })
        Text(this.detail?.viewerHasStarred ?? false
          ? this.stringOf($r('app.string.explore_unstar'))
          : this.stringOf($r('app.string.explore_star')))
          .fontSize($r('app.float.body_font_size'))
          .fontColor($r('app.color.text_primary'))
      }
      .layoutWeight(1)
      .height(44)
      .justifyContent(FlexAlign.Center)
      .borderRadius(6)
      .border({ width: 1, color: $r('app.color.border') })
      .onClick(() => this.onStar())
      Stack() {
        OctIcon({ res: $r('app.media.oct_repo_forked_16'), iconSize: 18, iconColor: $r('app.color.text_primary') })
      }
      .width(44)
      .height(44)
      .borderRadius(6)
      .border({ width: 1, color: $r('app.color.border') })
      .onClick(() => this.onFork())
      Stack() {
        OctIcon({ res: $r('app.media.oct_bell_16'), iconSize: 18, iconColor: $r('app.color.text_primary') })
      }
      .width(44)
      .height(44)
      .borderRadius(6)
        .border({ width: 1, color: $r('app.color.border') })
        .onClick(() => this.comingSoon())
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 8 })
  }

  /** 计数入口：彩块图标 + 标签 + 计数 */
  @Builder
  countRow(iconRes: Resource, color: ResourceColor, labelRes: Resource, count: number, onClick: () => void) {
    Row({ space: 12 }) {
      Stack() {
        OctIcon({ res: iconRes, iconSize: 16, iconColor: Color.White })
      }
      .width(32)
      .height(32)
      .backgroundColor(color)
      .borderRadius(6)
      Text(labelRes)
        .fontSize($r('app.float.body_font_size'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
      if (count >= 0) {
        Text(`${count}`)
          .fontSize($r('app.float.body_font_size'))
          .fontColor($r('app.color.text_secondary'))
      }
    }
    .width('100%')
    .height(48)
    .padding({ left: 16, right: 16 })
    .onClick(onClick)
  }

  /** More 折叠区：分支/Code/Commits/README·EDIT */
  @Builder
  moreSection() {
    Column() {
      if (!this.moreExpanded) {
      Row({ space: 12 }) {
        Stack() {
          OctIcon({ res: $r('app.media.oct_kebab_horizontal_16'), iconSize: 14, iconColor: $r('app.color.text_primary') })
        }
        .width(32)
        .height(32)
        .backgroundColor($r('app.color.bg_page'))
        .borderRadius(6)
        Text($r('app.string.repo_more'))
          .fontSize($r('app.float.body_font_size'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
        Blank()
        OctIcon({ res: $r('app.media.oct_chevron_down_16'), iconSize: 14, iconColor: $r('app.color.text_secondary') })
      }
      .width('100%')
      .height(48)
      .padding({ left: 16, right: 16 })
      .onClick(() => {
        this.moreExpanded = true;
      })
      }

      if (this.moreExpanded) {
        Row({ space: 12 }) {
          Stack() {
            OctIcon({ res: $r('app.media.oct_people_16'), iconSize: 16, iconColor: Color.White })
          }
          .width(32)
          .height(32)
          .backgroundColor($r('app.color.badge_red'))
          .borderRadius(6)
          Text($r('app.string.repo_contributors'))
            .fontSize($r('app.float.body_font_size'))
            .fontColor($r('app.color.text_primary'))
        }
        .width('100%')
        .height(48)
        .padding({ left: 16, right: 16 })
        .onClick(() => this.navigateLink('contributors', `${this.owner}/${this.name}`))

        Row({ space: 12 }) {
          Stack() {
            OctIcon({ res: $r('app.media.oct_eye_16'), iconSize: 16, iconColor: Color.White })
          }
          .width(32)
          .height(32)
          .backgroundColor($r('app.color.attention_bg'))
          .borderRadius(6)
          Text($r('app.string.repo_watchers'))
            .fontSize($r('app.float.body_font_size'))
            .fontColor($r('app.color.text_primary'))
        }
        .width('100%')
        .height(48)
        .padding({ left: 16, right: 16 })
        .onClick(() => this.navigateLink('watchers', `${this.owner}/${this.name}`))

        Row({ space: 12 }) {
          Stack() {
            OctIcon({ res: $r('app.media.oct_law_16'), iconSize: 16, iconColor: Color.White })
          }
          .width(32)
          .height(32)
          .backgroundColor($r('app.color.badge_red'))
          .borderRadius(6)
          Text($r('app.string.repo_license'))
            .fontSize($r('app.float.body_font_size'))
            .fontColor($r('app.color.text_primary'))
        }
        .width('100%')
        .height(48)
        .padding({ left: 16, right: 16 })
        .onClick(() => this.navigateLink('license', `${this.owner}/${this.name}`))
      }
    }
    .width('100%')
    .backgroundColor($r('app.color.card_background'))
    .borderRadius(12)
  }

  /** 分支区（独立于 More）：Current branch/main 垂排 + Code/Commits */
  @Builder
  branchSection() {
    Column() {
      // 结构：git-branch 图标最左，右侧为 Current branch 文字 + main ✓ 上下排布
      Row({ space: 12 }) {
        Stack() {
          OctIcon({ res: $r('app.media.oct_git_branch_16'), iconSize: 16, iconColor: $r('app.color.text_secondary') })
        }
        .width(32)
        .height(32)
        .borderRadius(6)
        Column({ space: 2 }) {
          Text($r('app.string.repo_current_branch'))
            .fontSize($r('app.float.caption_font_size'))
            .fontColor($r('app.color.text_secondary'))
          Row({ space: 6 }) {
            Text(this.detail?.defaultBranchRefName ?? 'main')
              .fontSize($r('app.float.body_font_size'))
              .fontColor($r('app.color.text_primary'))
            OctIcon({ res: $r('app.media.oct_check_16'), iconSize: 14, iconColor: $r('app.color.success_text') })
          }
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Text($r('app.string.repo_change'))
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.link_blue'))
          .onClick(() => this.comingSoon())
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 10, bottom: 10 })

      Divider().color($r('app.color.divider')).margin({ left: 16, right: 16 })

      Row({ space: 12 }) {
        Stack() {
          OctIcon({ res: $r('app.media.oct_file_code_16'), iconSize: 16, iconColor: $r('app.color.text_primary') })
        }
        .width(32)
        .height(32)
        .backgroundColor($r('app.color.heat_empty'))
        .borderRadius(6)
        Text($r('app.string.repo_code'))
          .fontSize($r('app.float.body_font_size'))
          .fontColor($r('app.color.text_primary'))
      }
      .width('100%')
      .height(48)
      .padding({ left: 16, right: 16 })
      .onClick(() => this.openFiles())

      Divider().color($r('app.color.divider')).margin({ left: 72 })

      Row({ space: 12 }) {
        Stack() {
          OctIcon({ res: $r('app.media.oct_git_commit_16'), iconSize: 16, iconColor: $r('app.color.text_primary') })
        }
        .width(32)
        .height(32)
        .backgroundColor($r('app.color.heat_empty'))
        .borderRadius(6)
        Text($r('app.string.repo_commits'))
          .fontSize($r('app.float.body_font_size'))
          .fontColor($r('app.color.text_primary'))
      }
      .width('100%')
      .height(48)
      .padding({ left: 16, right: 16 })
      .onClick(() => this.openCommits())
    }
    .width('100%')
    .backgroundColor($r('app.color.card_background'))
    .borderRadius(12)
  }

  /** README 卡片：官方 HTML 渲染（Spec 040）；404 → no README 占位；异常 → 纯文本降级 */
  @Builder
  readmeCard() {
    Column() {
      if (this.readmeResult !== null) {
        if (this.readmeResult.status === 'ok') {
          MarkdownView({
            html: this.readmeResult.html,
            fallbackText: this.detail?.readmeText ?? '',
            collapse: false,
            imgBase: `https://raw.githubusercontent.com/${this.owner}/${this.name}/${this.detail?.defaultBranchRefName ?? 'main'}/`,
            linkBase: `https://github.com/${this.owner}/${this.name}/blob/${this.detail?.defaultBranchRefName ?? 'main'}/`,
            onNavigate: (name: string, param: string) => this.navigateLink(name, param)
          })
        } else if (this.readmeResult.status === 'notFound') {
          Text(resText(this.getUIContext(), $r('app.string.md_no_readme')))
            .fontSize($r('app.float.body_font_size'))
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
        } else if ((this.detail?.readmeText ?? '') !== '') {
          MarkdownView({
            html: '',
            fallbackText: this.detail?.readmeText ?? '',
            showRetry: true,
            onRetry: () => this.loadReadme()
          })
        }
      }
    }
    .alignItems(HorizontalAlign.Start)
    .padding($r('app.float.card_padding'))
    .borderRadius($r('app.float.card_radius'))
    .backgroundColor($r('app.color.card_background'))
    .width('100%')
  }

  build() {
    Column() {
      AppBar({
        showBack: true,
        onBack: (): void => {
          this.pathStack.pop();
        },
        actions: [
          new AppBarAction($r('app.media.oct_plus_circle_24'), (): void => this.comingSoon(),
            { iconColor: $r('app.color.link_blue'), a11y: $r('app.string.a11y_new') }),
          new AppBarAction($r('app.media.oct_kebab_horizontal_16'), (): void => this.comingSoon(),
            { rotate90: true, iconColor: $r('app.color.link_blue'), a11y: $r('app.string.a11y_more') })
        ]
      })

      PageShadowBar({ show: this.scrollShadow })

      Refresh({ refreshing: $$this.isRefreshing }) {
        Scroll() {
          Column({ space: 10 }) {
            if (this.detail !== null) {
              this.headerBox()
              this.actionBar()

              Column() {
                this.countRow($r('app.media.oct_issue_opened_16'), $r('app.color.success_text'), $r('app.string.repo_issues_link'), this.detail.issueCount, () => this.openIssues())
                Divider().color($r('app.color.divider')).margin({ left: 72 })
                this.countRow($r('app.media.oct_git_pull_request_16'), $r('app.color.link_blue'), $r('app.string.repo_pr_link'), this.detail.prCount, () => this.openPrs())
                Divider().color($r('app.color.divider')).margin({ left: 72 })
                if (this.detail.hasDiscussions) {
                  // 仓库开启 Discussions 才显示（icon 与 Home 页 Discussions 同款，官方顺序在 PRs 与 Actions 之间）
                  this.countRow($r('app.media.oct_comment_discussion_16'), $r('app.color.shortcut_purple_fg'), $r('app.string.repo_discussions'), this.detail.discussionCount, () => this.openDiscussions())
                  Divider().color($r('app.color.divider')).margin({ left: 72 })
                }
                // Actions 无对应 API：行内不显示数字（countRow 负数哨兵=无计数）
                this.countRow($r('app.media.oct_play_16'), $r('app.color.star_gold'), $r('app.string.repo_actions'), -1, () => this.comingSoon())
                Divider().color($r('app.color.divider')).margin({ left: 72 })
                this.countRow($r('app.media.oct_tag_16'), $r('app.color.work_dark_bg'), $r('app.string.repo_releases'), this.detail.releaseCount, () => this.openReleases())
              }
              .width('100%')
              .backgroundColor($r('app.color.card_background'))
              .borderRadius(12)

              this.moreSection()

              this.branchSection()

              if (this.readmeResult !== null) {
                this.readmeCard()
              }
            } else {
              StateView({
                loading: this.loading,
                error: this.errorMsg,
                onRetry: () => this.refresh()
              })
            }
          }
          .padding({ left: 16, right: 16 })
          .width('100%')
        }
        .scrollBar(BarState.Off)
        .align(Alignment.Top)
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
  }
}
