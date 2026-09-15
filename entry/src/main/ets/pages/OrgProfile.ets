/**
 * 组织主页（Spec 036）：头部/信息行/FOLLOW 真实切换/README 官方 HTML 渲染/Pinned/Repositories 入口。
 * 邮箱走 REST 兜底；README 源 = 组织 .github 仓库（取不到隐藏区块）。
 */
import { promptAction } from '@kit.ArkUI';
import { AppBar, AppBarAction, AppBarActionCfg } from '../components/AppBar';
import { OctIcon } from '../components/OctIcon';
import { MarkdownView } from '../components/MarkdownView';
import { PageShadowBar } from '../components/PageShadowBar';
import { OrgProfile } from '../models/ProfileModels';
import { ProfileListService } from '../services/ProfileListService';
import { MarkdownService, MarkdownFetchResult } from '../services/MarkdownService';
import { RepoCard } from '../components/RepoCard';
import { StateView } from '../components/StateView';
import { RepoSummary } from '../models/GitHubModels';
import { resText } from '../utils/I18n';
import { shareLink, userPageUrl } from '../utils/Share';

@ComponentV2
export struct OrgProfileView {
  @Param login: string = '';
  @Param token: string = '';
  @Param pathStack: NavPathStack = new NavPathStack();
  @Local org: OrgProfile | null = null;
  /** README 官方 HTML（REST html+json；读不到时 readmeText 纯文本降级） */
  @Local readmeResult: MarkdownFetchResult | null = null;
  @Local loading: boolean = true;
  @Local errorMsg: string = '';
  /** 滚动顶部阴影（滚动中显示、回顶消失） */
  @Local scrollShadow: boolean = false;
  @Local isRefreshing: boolean = false;

  aboutToAppear(): void {
    this.refresh();
  }

  private refresh(): void {
    if (this.login === '') {
      return;
    }
    this.loading = true;
    this.errorMsg = '';
    this.readmeResult = null;
    ProfileListService.fetchOrgProfile(this.token, this.login)
      .then((org: OrgProfile) => {
        this.org = org;
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

  /** README 官方渲染（Spec 040）：先 .github/profile/README.md 再 .github/readme */
  private loadReadme(): void {
    MarkdownService.fetchOrgProfileReadme(this.token, this.login)
      .then((res: MarkdownFetchResult) => {
        this.readmeResult = res;
        this.isRefreshing = false;
      })
      .catch(() => {
        this.readmeResult = { status: 'error', html: '' };
        this.isRefreshing = false;
      });
  }

  private navigateLink(name: string, param: string): void {
    this.pathStack.pushPathByName(name, param);
  }

  /** FOLLOW 真实切换：REST put/delete；失败（如无 user:follow scope）toast */
  private stringOf(res: Resource): string {
    return resText(this.getUIContext(), res);
  }

  @Builder
  metaRow(iconRes: Resource, text: string) {
    if (text !== '') {
      Row({ space: 8 }) {
        OctIcon({ res: iconRes, iconSize: 14, iconColor: $r('app.color.text_secondary') })
        Text(text)
          .fontSize($r('app.float.body_font_size'))
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
      }
      .width('100%')
    }
  }

  /** 主体内容（org 非空时进入） */
  @Builder
  orgContent(org: OrgProfile) {
    Scroll() {
      Column() {
        // 头部：logo + 名称 + login
        Row({ space: 12 }) {
          Image(org.avatarUrl)
            .width(64)
            .height(64)
            .borderRadius(12)
            .backgroundColor($r('app.color.heat_empty'))
          Column({ space: 3 }) {
            Text(org.name !== '' ? org.name : org.login)
              .fontSize($r('app.float.title_font_size'))
              .fontWeight(600)
              .fontColor($r('app.color.text_primary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(org.login)
              .fontSize($r('app.float.body_font_size'))
              .fontColor($r('app.color.text_secondary'))
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .width('100%')

        if (org.description !== '') {
          Text(org.description)
            .fontSize($r('app.float.body_font_size'))
            .fontColor($r('app.color.text_primary'))
            .lineHeight(22)
            .width('100%')
            .margin({ top: 6 })
        }

        Column({ space: 8 }) {
          this.metaRow($r('app.media.oct_link_16'), org.websiteUrl)
          this.metaRow($r('app.media.oct_mail_16'), org.email)
          if (org.twitterUsername !== '') {
            Row({ space: 6 }) {
              Text('𝕏')
                .fontSize($r('app.float.body_font_size'))
                .fontColor($r('app.color.text_secondary'))
              Text(`@${org.twitterUsername}`)
                .fontSize($r('app.float.caption_font_size'))
                .fontColor($r('app.color.text_secondary'))
            }
          }
        }
        .margin({ top: 10 })
        .width('100%')
        .alignItems(HorizontalAlign.Start)

        // [+ FOLLOW] 通栏描边按钮（GitHub 无组织关注 API，review D1：保留入口占位，点击提示）
        Row() {
          Text(this.stringOf(this.followLabel(org)))
            .fontSize($r('app.float.body_font_size'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
        }
        .width('100%')
        .height(46)
        .justifyContent(FlexAlign.Center)
        .borderRadius(9999)
        .borderWidth(1)
        .borderColor($r('app.color.divider'))
        .margin({ top: 14 })
        .onClick(() => {
          promptAction.showToast({ message: this.stringOf($r('app.string.org_follow_unsupported')) });
        })

        // README 区块
        if (org.readmeText !== '') {
          Column() {
            Row({ space: 8 }) {
              Text(`${org.login}/README.md`)
                .fontSize($r('app.float.body_font_size'))
                .fontColor($r('app.color.text_primary'))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .layoutWeight(1)
              // 右侧滚动指示条（截图中 README 滚动条示意）
              Row()
                .width(5)
                .height(64)
                .borderRadius(3)
                .backgroundColor($r('app.color.divider'))
            }
            .width('100%')
            .padding({ bottom: 8 })

            if (this.readmeResult !== null) {
              if (this.readmeResult.status === 'ok') {
                MarkdownView({
                  html: this.readmeResult.html,
                  fallbackText: org.readmeText,
                  onNavigate: (name: string, param: string) => this.navigateLink(name, param)
                })
              } else if (org.readmeText !== '') {
                MarkdownView({
                  html: '',
                  fallbackText: org.readmeText,
                  showRetry: true,
                  onRetry: () => this.loadReadme()
                })
              }
            }
          }
          .padding($r('app.float.card_padding'))
          .borderRadius($r('app.float.card_radius'))
          .backgroundColor($r('app.color.card_background'))
          .width('100%')
          .margin({ top: 14 })
        }

        // Pinned 横滑卡片（与 Profile 同区对齐：oct_pin_16 图标，review D13 弃 emoji）
        Row({ space: 6 }) {
          OctIcon({ res: $r('app.media.oct_pin_16'), iconSize: 16, iconColor: $r('app.color.text_primary') })
          Text(this.stringOf($r('app.string.home_pinned_section')))
            .fontSize($r('app.float.title_font_size'))
            .fontWeight(600)
            .fontColor($r('app.color.text_primary'))
        }
        .width('100%')
        .margin({ top: 14 })
        Scroll() {
          Row({ space: 8 }) {
            ForEach(org.pinned, (repo: RepoSummary) => {
              RepoCard({
                repo: repo,
                onOpen: (): void => {
                  this.pathStack.pushPathByName('repoDetail', repo.nameWithOwner);
                }
              })
                .width(200)
            }, (repo: RepoSummary) => repo.id !== '' ? repo.id : repo.nameWithOwner)
          }
          .alignItems(VerticalAlign.Top)
        }
        .scrollable(ScrollDirection.Horizontal)
        .width('100%')
        .scrollBar(BarState.Off)

        // Repositories 入口行
        Row({ space: 12 }) {
          Stack() {
            OctIcon({ res: $r('app.media.oct_repo_16'), iconSize: 16, iconColor: Color.White })
          }
          .width(44)
          .height(44)
          .borderRadius(6)
          .backgroundColor($r('app.color.work_dark_bg'))
          Text($r('app.string.org_repositories_row'))
            .fontSize($r('app.float.body_font_size'))
            .fontColor($r('app.color.text_primary'))
            .layoutWeight(1)
          Text(`${org.repositoriesCount}`)
            .fontSize($r('app.float.body_font_size'))
            .fontColor($r('app.color.text_secondary'))
          OctIcon({ res: $r('app.media.oct_chevron_right_16'), iconSize: 14, iconColor: $r('app.color.text_secondary') })
            .margin({ left: 4 })
        }
        .width('100%')
        .padding(12)
        .borderRadius(12)
        .backgroundColor($r('app.color.card_background'))
        .margin({ top: 6 })
        .onClick(() => {
          this.pathStack.pushPathByName('repositoriesList', `${org.login}|org`);
        })

        Row()
          .height(24)
      }
      .padding({ left: 16, right: 16 })
      .width('100%')
    }
    .scrollBar(BarState.Off)
    .align(Alignment.Top)
    .onScroll((_x: number, y: number): void => { this.scrollShadow = y > 0.001; })
  }

  /** FOLLOW 按钮文案资源（未关注 +FOLLOW / 已关注 FOLLOWING） */
  private followLabel(org: OrgProfile): Resource {
    return org.viewerIsFollowing ? $r('app.string.org_following') : $r('app.string.org_follow');
  }

  build() {
    Column() {
      AppBar({
        showBack: true,
        onBack: (): void => {
          this.pathStack.pop();
        },
        actions: [
          new AppBarAction($r('app.media.oct_share_android_16'), (): void => {
            shareLink(this.getUIContext(), userPageUrl(this.login), this.login);
          }, { iconColor: $r('app.color.link_blue'), a11y: $r('app.string.a11y_share') }),
          new AppBarAction($r('app.media.oct_kebab_horizontal_16'), (): void => {
            promptAction.showToast({ message: $r('app.string.home_feature_coming') });
          }, { rotate90: true, iconColor: $r('app.color.link_blue'), a11y: $r('app.string.a11y_more') })
        ]
      })

      PageShadowBar({ show: this.scrollShadow })

      Refresh({ refreshing: $$this.isRefreshing }) {
        if (this.org === null) {
          StateView({
            loading: this.loading,
            error: this.errorMsg,
            onRetry: () => this.refresh()
          })
        } else {
          this.orgContent(this.org)
        }
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
