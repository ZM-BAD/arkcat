/**
 * Repo Detail 页（Spec 006）：About（描述/计数/License/Topics/README 摘要）
 * + Star/Fork 操作 + 文件列表 + 语言占比条。
 * 子 Tab 按边界裁剪：Packages/Settings 不展示，Actions 略，Issues 由 Spec 007 接管。
 */
import { promptAction } from '@kit.ArkUI';
import { RepoDetail, FileEntry, LanguageSlice } from '../models/RepoDetailModels';
import { RepoService } from '../services/RepoService';
import { StateView } from '../components/StateView';
import { resText } from '../utils/I18n';

@ComponentV2
export struct RepoDetailView {
  @Param owner: string = '';
  @Param name: string = '';
  @Param token: string = '';
  @Param pathStack: NavPathStack = new NavPathStack();
  @Local detail: RepoDetail | null = null;
  @Local loading: boolean = true;
  @Local errorMsg: string = '';
  @Local busy: boolean = false;

  aboutToAppear(): void {
    this.refresh();
  }

  private refresh(): void {
    if (this.owner === '' || this.name === '') {
      return;
    }
    this.loading = true;
    this.errorMsg = '';
    RepoService.fetchRepoDetail(this.token, this.owner, this.name)
      .then((detail: RepoDetail) => {
        this.detail = detail;
        this.loading = false;
      })
      .catch((e: Error) => {
        this.errorMsg = e.message;
        this.loading = false;
      });
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
          lastCommitMessage: detail.lastCommitMessage
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

  @Builder
  aboutCard() {
    Column({ space: 8 }) {
      if (this.detail !== null && this.detail.description !== '') {
        Text(this.detail?.description ?? '')
          .fontSize($r('app.float.body_font_size'))
          .fontColor($r('app.color.text_primary'))
          .width('100%')
      }
      Row({ space: 16 }) {
        Text(`⭐ ${this.detail?.stargazerCount ?? 0}`)
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_secondary'))
          .onClick(() => this.onStar())
        Text(`⑂ ${this.detail?.forkCount ?? 0}`)
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_secondary'))
          .onClick(() => this.onFork())
        Text(`👁 ${this.detail?.watcherCount ?? 0}`)
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_secondary'))
        if (this.detail?.viewerHasStarred ?? false) {
          Text($r('app.string.repo_starred_label'))
            .fontSize($r('app.float.caption_font_size'))
            .fontColor($r('app.color.primary'))
        }
      }
      .width('100%')

      if (this.detail !== null && this.detail.licenseName !== '') {
        Text(this.fmt($r('app.string.repo_license_fmt'), this.detail?.licenseName ?? ''))
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
      }

      if ((this.detail?.topics.length ?? 0) > 0) {
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(this.detail?.topics ?? [], (topic: string) => {
            Text(topic)
              .fontSize($r('app.float.caption_font_size'))
              .fontColor($r('app.color.link_blue'))
              .padding({ left: 10, right: 10, top: 4, bottom: 4 })
              .borderRadius(12)
              .backgroundColor('#DBEAFE')
              .margin({ right: 6, bottom: 6 })
          }, (topic: string) => topic)
        }
        .width('100%')
      }

      if (this.detail !== null && this.detail.lastCommitMessage !== '') {
        Text(this.fmt($r('app.string.repo_last_commit_fmt'), this.detail?.lastCommitMessage ?? ''))
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_secondary'))
          .maxLines(1)
          .width('100%')
      }
    }
    .padding($r('app.float.card_padding'))
    .borderRadius($r('app.float.card_radius'))
    .backgroundColor($r('app.color.card_background'))
    .width('100%')
  }

  @Builder
  readmeCard() {
    Column({ space: 8 }) {
      Text($r('app.string.repo_readme_title'))
        .fontSize($r('app.float.body_font_size'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
      Text(this.detail?.readmeText ?? '')
        .fontSize($r('app.float.caption_font_size'))
        .fontColor($r('app.color.text_secondary'))
        .maxLines(10)
        .lineHeight(18)
        .width('100%')
      Text($r('app.string.repo_code_viewer_coming'))
        .fontSize($r('app.float.caption_font_size'))
        .fontColor($r('app.color.link_blue'))
        .onClick(() => {
          promptAction.showToast({ message: $r('app.string.repo_code_viewer_toast') });
        })
    }
    .alignItems(HorizontalAlign.Start)
    .padding($r('app.float.card_padding'))
    .borderRadius($r('app.float.card_radius'))
    .backgroundColor($r('app.color.card_background'))
    .width('100%')
  }

  @Builder
  filesCard() {
    Column({ space: 4 }) {
      Text($r('app.string.repo_files_title'))
        .fontSize($r('app.float.body_font_size'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .margin({ bottom: 4 })
      ForEach(this.detail?.files ?? [], (file: FileEntry) => {
        Row({ space: 6 }) {
          Text(file.type === 'tree' ? '📁' : '📄').fontSize(14)
          Text(file.name)
            .fontSize($r('app.float.caption_font_size'))
            .fontColor($r('app.color.text_primary'))
            .maxLines(1)
          Blank()
        }
        .width('100%')
        .padding({ top: 6, bottom: 6 })
      }, (file: FileEntry) => file.name)
      Text($r('app.string.repo_browser_coming'))
        .fontSize($r('app.float.caption_font_size'))
        .fontColor($r('app.color.link_blue'))
        .margin({ top: 4 })
    }
    .alignItems(HorizontalAlign.Start)
    .padding($r('app.float.card_padding'))
    .borderRadius($r('app.float.card_radius'))
    .backgroundColor($r('app.color.card_background'))
    .width('100%')
  }

  @Builder
  languagesCard() {
    Column({ space: 8 }) {
      Text($r('app.string.repo_languages_title'))
        .fontSize($r('app.float.body_font_size'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
      Row() {
        ForEach(this.detail?.languages ?? [], (lang: LanguageSlice) => {
          Column()
            .layoutWeight(lang.percent > 0 ? lang.percent : 1)
            .height(8)
            .backgroundColor(lang.color !== '' ? lang.color : $r('app.color.repo_language_blue'))
        }, (lang: LanguageSlice) => lang.name)
      }
      .width('100%')
      .borderRadius(4)
      .clip(true)

      Row({ space: 12 }) {
        ForEach(this.detail?.languages ?? [], (lang: LanguageSlice) => {
          Text(`${lang.name} ${lang.percent}%`)
            .fontSize($r('app.float.caption_font_size'))
            .fontColor($r('app.color.text_secondary'))
        }, (lang: LanguageSlice) => `legend-${lang.name}`)
      }
      .width('100%')
    }
    .alignItems(HorizontalAlign.Start)
    .padding($r('app.float.card_padding'))
    .borderRadius($r('app.float.card_radius'))
    .backgroundColor($r('app.color.card_background'))
    .width('100%')
  }

  build() {
    Column() {
      Row({ space: 8 }) {
        Text('←')
          .fontSize(20)
          .onClick(() => {
            this.pathStack.pop();
          })
        Text(this.detail?.nameWithOwner ?? `${this.owner}/${this.name}`)
          .fontSize($r('app.float.title_font_size'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .layoutWeight(1)
        Text($r('app.string.repo_issues_link'))
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.link_blue'))
          .onClick(() => this.openIssues())
      }
      .width('100%')
      .height(48)
      .padding({ left: 16, right: 16 })

      Scroll() {
        Column({ space: 12 }) {
          if (this.detail !== null) {
            this.aboutCard()
            if (this.detail.readmeText !== '') {
              this.readmeCard()
            }
            if (this.detail.files.length > 0) {
              this.filesCard()
            }
            if (this.detail.languages.length > 0) {
              this.languagesCard()
            }
          } else {
            StateView({
              loading: this.loading,
              error: this.errorMsg,
              onRetry: () => this.refresh()
            })
          }
        }
        .padding($r('app.float.page_padding'))
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
