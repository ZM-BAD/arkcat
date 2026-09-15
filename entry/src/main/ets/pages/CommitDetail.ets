/**
 * Commit 详情页（官方 Commit 页）：CHANGES/DETAILS 双 tab。
 * CHANGES=作者行+标题+消息+统计灰卡+文件 diff（全展开）；DETAILS=Commit/Contributors/Associated PR/Parents 分段。
 * 入口：Commit 列表行（RepoCommits/PR commits）；数据=GraphQL+REST 混合（fetchCommitDetail）。
 */
import { promptAction } from '@kit.ArkUI';
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { AppBar, AppBarAction, AppBarActionCfg } from '../components/AppBar';
import { OctIcon } from '../components/OctIcon';
import { PageShadowBar } from '../components/PageShadowBar';
import { CommitDiffBlock } from '../components/CommitDiffBlock';
import { StateView } from '../components/StateView';
import { CommitDetailPage, CommitPullItem, CommitFileItem } from '../models/PrDiffModels';
import { RepoSubService } from '../services/RepoSubService';
import { githubShortTime, timeParts, TimeParts } from '../utils/Format';
import { resText } from '../utils/I18n';
import { commitPageUrl, shareLink } from '../utils/Share';

const PREFS_NAME = 'arkcat_settings';
const KEY_LINE_NUMBERS = 'code_line_numbers';

@ComponentV2
export struct CommitDetailView {
  @Param owner: string = '';
  @Param name: string = '';
  @Param oid: string = '';
  @Param token: string = '';
  @Param pathStack: NavPathStack = new NavPathStack();
  @Local detail: CommitDetailPage | null = null;
  @Local loading: boolean = true;
  @Local errorMsg: string = '';
  /** 0=CHANGES 1=DETAILS */
  @Local tab: number = 0;
  /** Code Options「展示行号」开关 */
  @Local showLineNumbers: boolean = true;
  /** Code Options 返回 tick → 重读设置（review C3） */
  @Param codeOptionsTick: number = 0;
  /** 滚动顶部阴影（滚动中显示、回顶消失） */
  @Local scrollShadow: boolean = false;
  @Local isRefreshing: boolean = false;

  aboutToAppear(): void {
    this.loadLineSetting();
    this.refresh();
  }

  /** Code Options 返回（onShown tick）→ 重读本页设置（review C3） */
  @Monitor('codeOptionsTick')
  onOptionsTick(): void {
    this.loadLineSetting();
  }

  private loadLineSetting(): void {
    const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    if (ctx === undefined) {
      return;
    }
    preferences.getPreferences(ctx, PREFS_NAME)
      .then((pref: preferences.Preferences) => {
        this.showLineNumbers = pref.getSync(KEY_LINE_NUMBERS, true) as boolean;
      })
      .catch(() => {
      });
  }

  private refresh(): void {
    this.loading = true;
    this.errorMsg = '';
    RepoSubService.fetchCommitDetail(this.token, this.owner, this.name, this.oid)
      .then((page: CommitDetailPage) => {
        this.detail = page;
        this.loading = false;
        this.isRefreshing = false;
      })
      .catch((e: Error) => {
        this.errorMsg = e.message;
        this.loading = false;
        this.isRefreshing = false;
      });
  }

  private stringOf(res: Resource): string {
    return resText(this.getUIContext(), res);
  }

  private shortOid(oid: string): string {
    return oid.length > 7 ? oid.substring(0, 7) : oid;
  }

  /** 标题文本：REST message 首行（headline），空则兜底短 oid（review C1：勿用全文防与正文重复） */
  private headlineText(): string {
    if (this.detail !== null && this.detail.headline !== '') {
      return this.detail.headline;
    }
    if (this.detail !== null && this.detail.message !== '') {
      const first = this.detail.message.split('\n')[0];
      return first !== '' ? first : this.shortOid(this.oid);
    }
    return this.shortOid(this.oid);
  }

  /** message 正文（去除首行标题后余下部分，trim 首空白） */
  private bodyText(): string {
    if (this.detail === null || this.detail.message === '') {
      return '';
    }
    const rest = this.detail.message.substring(this.detail.headline.length).replace(/^\s+/, '');
    return rest.length > 0 ? rest : '';
  }

  private timeText(parts: TimeParts | null): string {
    return parts !== null ? githubShortTime(parts) : '';
  }

  private copyOid(): void {
    if (this.detail === null) {
      return;
    }
    const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.detail.oid);
    pasteboard.getSystemPasteboard().setDataSync(data);
    promptAction.showToast({ message: $r('app.string.md_copied') });
  }

  /** CHANGES 作者行：头像 + login authored + 绿✓ + 相对时间 */
  @Builder
  authorRow() {
    Row({ space: 8 }) {
      if (this.detail !== null && this.detail.authorAvatar !== '') {
        Image(this.detail.authorAvatar)
          .width(22)
          .height(22)
          .borderRadius(11)
          .backgroundColor($r('app.color.heat_empty'))
      }
      Text() {
        Span(this.detail !== null ? this.detail.authorLogin : '')
          .fontColor($r('app.color.text_primary'))
        Span(` ${this.stringOf($r('app.string.repo_commits_authored'))}`)
          .fontColor($r('app.color.text_secondary'))
      }
      .fontSize($r('app.float.caption_font_size'))
      .layoutWeight(1)
      if (this.detail !== null && this.detail.checksState === 'SUCCESS') {
        OctIcon({ res: $r('app.media.oct_check_16'), iconSize: 14, iconColor: $r('app.color.success_text') })
      }
      if (this.detail !== null && this.detail.checksState === 'FAILURE') {
        OctIcon({ res: $r('app.media.oct_x_16'), iconSize: 14, iconColor: $r('app.color.danger_text') })
      }
      // ERROR 态与列表页对齐（review C12：详情页此前漏显）
      if (this.detail !== null && this.detail.checksState === 'ERROR') {
        OctIcon({ res: $r('app.media.oct_x_16'), iconSize: 14, iconColor: $r('app.color.danger_text') })
      }
      if (this.detail !== null && this.detail.checksState === 'PENDING') {
        OctIcon({ res: $r('app.media.oct_dot_fill_16'), iconSize: 14, iconColor: $r('app.color.warning_text') })
      }
      if (this.detail !== null && this.detail.committedDate !== '') {
        Text(this.timeText(timeParts(this.detail.committedDate, Date.now())))
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_secondary'))
      }
    }
    .width('100%')
  }

  /** 灰色段标题（Commit/Contributors/…）：灰小字 */
  @Builder
  sectionTitle(text: string) {
    Text(text)
      .fontSize($r('app.float.caption_font_size'))
      .fontColor($r('app.color.text_secondary'))
      .width('100%')
      .padding({ top: 14, bottom: 10 })
  }

  /** 灰色统计卡：N files changed + additions/deletions（靠左） */
  @Builder
  statsCard() {
    Column({ space: 4 }) {
      Text(resText(this.getUIContext(), $r('app.string.pr_files_changed'), this.detail !== null ? this.detail.files.length : 0))
        .fontSize($r('app.float.sub_text_font_size'))
        .fontWeight(600)
        .fontColor($r('app.color.text_primary'))
      Row({ space: 12 }) {
        Text(resText(this.getUIContext(), $r('app.string.commit_additions'), this.detail !== null ? this.detail.files.reduce((a: number, f) => a + f.additions, 0) : 0))
          .fontSize($r('app.float.body_font_size'))
          .fontColor($r('app.color.success_text'))
        Text(resText(this.getUIContext(), $r('app.string.commit_deletions'), this.detail !== null ? this.detail.files.reduce((a: number, f) => a + f.deletions, 0) : 0))
          .fontSize($r('app.float.body_font_size'))
          .fontColor($r('app.color.danger_text'))
      }
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 20, right: 20, top: 14, bottom: 14 })
    .borderRadius(6)
    .backgroundColor($r('app.color.diff_hunk_bg'))
  }

  /** DETAILS 分段行：icon + 内容 +（右侧操作） */
  @Builder
  detailsRow(iconRes: Resource, mainText: string, extraText: string, rightText: string, onTap: () => void) {
    Row({ space: 12 }) {
      OctIcon({ res: iconRes, iconSize: 16, iconColor: $r('app.color.text_secondary') })
      Text(mainText)
        .fontSize($r('app.float.body_font_size'))
        .fontColor($r('app.color.text_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
      if (extraText !== '') {
        Text(extraText)
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_secondary'))
      }
      if (rightText !== '') {
        Text(rightText)
          .fontSize($r('app.float.caption_font_size'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.link_blue'))
          .onClick((): void => onTap())
      }
    }
    .width('100%')
    .padding({ top: 10, bottom: 10 })
  }

  build() {
    Column() {
      AppBar({
        showBack: true,
        title: this.stringOf($r('app.string.commit_appbar')),
        onBack: (): void => {
          this.pathStack.pop();
        },
        actions: [
          new AppBarAction($r('app.media.oct_share_android_16'), (): void => {
            const headline = this.detail !== null ? this.detail.headline : '';
            shareLink(this.getUIContext(), commitPageUrl(this.owner, this.name, this.oid), headline);
          }, { a11y: $r('app.string.a11y_share') }),
          // gear 仅 CHANGES tab 显示（与原头部条件一致）
          ...(this.tab === 0 ? [new AppBarAction($r('app.media.oct_gear_16'), (): void => {
            this.pathStack.pushPathByName('codeOptions', '');
          }, { iconColor: $r('app.color.link_blue'), a11y: $r('app.string.a11y_settings') })] : [])
        ]
      })

      // 双 tab：选中黑粗+蓝下划线；未选灰
      Row() {
        Stack() {
          Text(this.stringOf($r('app.string.commit_tab_changes')))
            .fontSize($r('app.float.body_font_size'))
            .fontWeight(this.tab === 0 ? 600 : FontWeight.Regular)
            .fontColor(this.tab === 0 ? $r('app.color.text_primary') : $r('app.color.text_secondary'))
          if (this.tab === 0) {
            // 指示线与底部灰线重合（取一半变蓝）
            Row().width('100%').height(2).backgroundColor($r('app.color.link_blue')).position({ x: 0, y: 42 })
          }
        }
        .layoutWeight(1)
        .height(44)
        .onClick(() => {
          this.tab = 0;
        })
        Stack() {
          Text(this.stringOf($r('app.string.commit_tab_details')))
            .fontSize($r('app.float.body_font_size'))
            .fontWeight(this.tab === 1 ? 600 : FontWeight.Regular)
            .fontColor(this.tab === 1 ? $r('app.color.text_primary') : $r('app.color.text_secondary'))
          if (this.tab === 1) {
            Row().width('100%').height(2).backgroundColor($r('app.color.link_blue')).position({ x: 0, y: 42 })
          }
        }
        .layoutWeight(1)
        .height(44)
        .onClick(() => {
          this.tab = 1;
        })
      }
      .width('100%')
      .border({ width: { bottom: 1 }, color: $r('app.color.border') })

      PageShadowBar({ show: this.scrollShadow })

      Refresh({ refreshing: $$this.isRefreshing }) {
        Scroll() {
          if (this.loading || this.errorMsg !== '') {
            StateView({ loading: this.loading, error: this.errorMsg, onRetry: (): void => this.refresh() })
          } else if (this.detail !== null && this.tab === 0) {
          Column({ space: 0 }) {
            this.authorRow()
            // 标题行：与作者行同字号；正文：diff 等宽字体同字号
            Text(this.headlineText())
              .fontSize($r('app.float.caption_font_size'))
              .fontColor($r('app.color.text_primary'))
              .lineHeight(18)
              .width('100%')
              .padding({ top: 10, bottom: 4 })
            if (this.bodyText() !== '') {
              Text(this.bodyText())
                .fontSize($r('app.float.caption_font_size'))
                .fontFamily('monospace')
                .fontColor($r('app.color.text_primary'))
                .lineHeight(18)
                .width('100%')
                .padding({ bottom: 12 })
            }
            this.statsCard()
            ForEach(this.detail.files, (file: CommitFileItem) => {
              Column({ space: 0 }) {
                CommitDiffBlock({
                  file: file,
                  showLineNumbers: this.showLineNumbers
                })
                Divider().color($r('app.color.divider')).width('100%')
              }
            }, (file: CommitFileItem) => file.path + file.additions)
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 8, bottom: 16 })
          .alignItems(HorizontalAlign.Start)
        } else if (this.detail !== null && this.tab === 1) {
          Column() {
            this.sectionTitle(this.stringOf($r('app.string.commit_section_commit')))
            this.detailsRow($r('app.media.oct_git_commit_16'), this.shortOid(this.detail.oid), '', this.stringOf($r('app.string.commit_copy')),
              (): void => this.copyOid())
            Divider().color($r('app.color.divider')).width('100%')
            this.sectionTitle(this.stringOf($r('app.string.commit_section_contributors')))
            Row({ space: 12 }) {
              if (this.detail.authorAvatar !== '') {
                Image(this.detail.authorAvatar)
                  .width(44)
                  .height(44)
                  .borderRadius(22)
                  .backgroundColor($r('app.color.heat_empty'))
              }
              Text(this.detail.authorLogin)
                .fontSize($r('app.float.sub_text_font_size'))
                .fontColor($r('app.color.text_primary'))
            }
            .width('100%')
            .padding({ top: 4, bottom: 10 })
            if (this.detail.pullRequests.length > 0) {
              Divider().color($r('app.color.divider')).width('100%')
              this.sectionTitle(this.stringOf($r('app.string.commit_section_prs')))
              ForEach(this.detail.pullRequests, (pr: CommitPullItem) => {
                Row({ space: 12 }) {
                  OctIcon({
                    res: $r('app.media.oct_git_merge_16'),
                    iconSize: 16,
                    iconColor: $r('app.color.shortcut_purple_fg')
                  })
                  Text(pr.title)
                    .fontSize($r('app.float.body_font_size'))
                    .fontColor($r('app.color.text_primary'))
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .layoutWeight(1)
                }
                .width('100%')
                .padding({ top: 10, bottom: 10 })
              }, (pr: CommitPullItem) => `${pr.number}`)
            }
            if (this.detail.parents.length > 0) {
              Divider().color($r('app.color.divider')).width('100%')
              this.sectionTitle(this.stringOf($r('app.string.commit_section_parents')))
              ForEach(this.detail.parents, (parent: string) => {
                Row({ space: 12 }) {
                  OctIcon({ res: $r('app.media.oct_git_commit_16'), iconSize: 16, iconColor: $r('app.color.text_secondary') })
                  Text(this.shortOid(parent))
                    .fontSize($r('app.float.body_font_size'))
                    .fontColor($r('app.color.text_primary'))
                }
                .width('100%')
                .padding({ top: 10, bottom: 10 })
              }, (parent: string) => parent)
            }
          }
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 16 })
          .alignItems(HorizontalAlign.Start)
        }
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
