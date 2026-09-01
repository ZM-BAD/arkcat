/**
 * 组织主页（Spec 036）：头部/信息行/FOLLOW 真实切换/README Read more/Pinned/Repositories 入口。
 * 邮箱走 REST 兜底；README 源 = 组织 .github 仓库（取不到隐藏区块）。
 */
import { promptAction } from '@kit.ArkUI';
import { OctIcon } from '../components/OctIcon';
import { OrgProfile } from '../models/ProfileModels';
import { ProfileListService } from '../services/ProfileListService';
import { RepoCard } from '../components/RepoCard';
import { StateView } from '../components/StateView';
import { RepoSummary } from '../models/GitHubModels';
import { resText } from '../utils/I18n';

const README_COLLAPSED_LINES = 6;

@ComponentV2
export struct OrgProfileView {
  @Param login: string = '';
  @Param token: string = '';
  @Param pathStack: NavPathStack = new NavPathStack();
  @Local org: OrgProfile | null = null;
  @Local readmeExpanded: boolean = false;
  @Local loading: boolean = true;
  @Local errorMsg: string = '';

  aboutToAppear(): void {
    this.refresh();
  }

  private refresh(): void {
    if (this.login === '') {
      return;
    }
    this.loading = true;
    this.errorMsg = '';
    ProfileListService.fetchOrgProfile(this.token, this.login)
      .then((org: OrgProfile) => {
        this.org = org;
        this.loading = false;
      })
      .catch((e: Error) => {
        this.errorMsg = e.message;
        this.loading = false;
      });
  }

  /** FOLLOW 真实切换：REST put/delete；失败（如无 user:follow scope）toast */
  private toggleFollow(): void {
    const org = this.org;
    if (org === null) {
      return;
    }
    const next = !org.viewerIsFollowing;
    ProfileListService.setOrgFollowing(this.token, org.login, next)
      .then((following: boolean) => {
        const updated: OrgProfile = {
          login: org.login,
          name: org.name,
          avatarUrl: org.avatarUrl,
          description: org.description,
          websiteUrl: org.websiteUrl,
          twitterUsername: org.twitterUsername,
          email: org.email,
          pinned: org.pinned,
          repositoriesCount: org.repositoriesCount,
          readmeText: org.readmeText,
          viewerIsFollowing: following
        };
        this.org = updated;
        const ui = this.getUIContext();
        promptAction.showToast({
          message: following
            ? resText(ui, $r('app.string.profile_followed_toast'))
            : resText(ui, $r('app.string.profile_unfollowed_toast'))
        });
      })
      .catch((e: Error) => {
        promptAction.showToast({
          message: resText(this.getUIContext(), $r('app.string.profile_action_failed'), e.message)
        });
      });
  }

  private stringOf(res: Resource): string {
    return resText(this.getUIContext(), res);
  }

  /** README 行：剥离 markdown 标记的展示行 */
  private readmeLinesOf(org: OrgProfile): string[] {
    if (org.readmeText === '') {
      return [];
    }
    const lines: string[] = [];
    for (const raw of org.readmeText.split('\n')) {
      // 图片行（![alt](url)）显示 alt 文本；链接行保留文本
      let line = raw.replace(/!\[([^\]]*)\]\([^)]*\)/g, '$1');
      line = line.replace(/\[([^\]]*)\]\([^)]*\)/g, '$1');
      lines.push(line);
    }
    return lines;
  }

  private isHeading(line: string): boolean {
    return line.startsWith('#');
  }

  private headingText(line: string): string {
    const trimmed = line.replace(/^#+\s*/, '');
    return trimmed;
  }

  /** 折叠/展开后的可见行 */
  private readmeVisibleLinesOf(org: OrgProfile): string[] {
    const lines = this.readmeLinesOf(org);
    if (this.readmeExpanded || lines.length <= README_COLLAPSED_LINES) {
      return lines;
    }
    return lines.slice(0, README_COLLAPSED_LINES);
  }

  @Builder
  metaRow(icon: string, text: string) {
    if (text !== '') {
      Row({ space: 8 }) {
        Text(icon).fontSize(14)
        Text(text)
          .fontSize($r('app.float.body_font_size'))
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
      }
      .width('100%')
    }
  }

  @Builder
  readmeLine(line: string) {
    Text(this.isHeading(line) ? this.headingText(line) : line)
      .fontSize(this.isHeading(line) ? $r('app.float.title_font_size') : $r('app.float.body_font_size'))
      .fontWeight(this.isHeading(line) ? FontWeight.Bold : FontWeight.Normal)
      .fontColor($r('app.color.text_primary'))
      .lineHeight(22)
      .width('100%')
      .margin({ bottom: 4 })
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
              .fontWeight(FontWeight.Bold)
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
          this.metaRow('🔗', org.websiteUrl)
          this.metaRow('✉️', org.email)
          this.metaRow('𝕏', org.twitterUsername !== '' ? `@${org.twitterUsername}` : '')
        }
        .margin({ top: 10 })
        .width('100%')
        .alignItems(HorizontalAlign.Start)

        // [+ FOLLOW] 通栏描边按钮（真实关注切换）
        Row() {
          Text(this.stringOf(this.followLabel(org)))
            .fontSize($r('app.float.body_font_size'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
        }
        .width('100%')
        .height(46)
        .justifyContent(FlexAlign.Center)
        .borderRadius(23)
        .borderWidth(1)
        .borderColor($r('app.color.divider'))
        .margin({ top: 14 })
        .onClick(() => {
          this.toggleFollow();
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

            Stack() {
              Column() {
                ForEach(this.readmeVisibleLinesOf(org), (line: string, idx: number) => {
                  this.readmeLine(line)
                }, (line: string, idx: number) => idx + '-' + line)
              }
              .width('100%')

              if (!this.readmeExpanded && this.readmeLinesOf(org).length > README_COLLAPSED_LINES) {
                Row() {
                  Text($r('app.string.org_read_more'))
                    .fontSize($r('app.float.body_font_size'))
                    .fontWeight(FontWeight.Medium)
                    .fontColor($r('app.color.text_primary'))
                }
                .padding({ left: 14, right: 14, top: 8, bottom: 8 })
                .borderRadius(12)
                .backgroundColor($r('app.color.card_background'))
                .borderWidth(1)
                .borderColor($r('app.color.divider'))
                .shadow({ radius: 8, color: '#40000000', offsetY: 2 })
                .onClick(() => {
                  this.readmeExpanded = true;
                })
              } else if (this.readmeLinesOf(org).length > README_COLLAPSED_LINES) {
                Row() {
                  Text($r('app.string.org_read_less'))
                    .fontSize($r('app.float.caption_font_size'))
                    .fontColor($r('app.color.link_blue'))
                }
                .padding(8)
                .onClick(() => {
                  this.readmeExpanded = false;
                })
              }
            }
.width(44)
.height(44)
            .alignContent(Alignment.Bottom)
          }
          .padding($r('app.float.card_padding'))
          .borderRadius($r('app.float.card_radius'))
          .backgroundColor($r('app.color.card_background'))
          .width('100%')
          .margin({ top: 14 })
        }

        // Pinned 横滑卡片
        Text(`📌 ${this.stringOf($r('app.string.home_pinned_section'))}`)
          .fontSize($r('app.float.title_font_size'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
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
          Text('>')
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
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
    .layoutWeight(1)
    .scrollBar(BarState.Off)
    .align(Alignment.Top)
  }

  /** FOLLOW 按钮文案资源（未关注 +FOLLOW / 已关注 FOLLOWING） */
  private followLabel(org: OrgProfile): Resource {
    return org.viewerIsFollowing ? $r('app.string.org_following') : $r('app.string.org_follow');
  }

  build() {
    Column() {
      // 顶栏：返回 + 分享 + ⋯（无标题）
      Row({ space: 16 }) {
        Stack() {
          OctIcon({ res: $r('app.media.oct_arrow_left_24'), iconSize: 20, iconColor: $r('app.color.text_primary') })
        }
.width(44)
.height(44)
        .accessibilityDescription($r('app.string.a11y_back'))
        .focusable(true)
        .onClick(() => {
          this.pathStack.pop();
        })
        Blank()
        Stack() {
          OctIcon({ res: $r('app.media.oct_share_16'), iconSize: 18, iconColor: $r('app.color.text_secondary') })
        }
.width(44)
.height(44)
        .padding(6)
        .accessibilityDescription($r('app.string.a11y_share'))
        .focusable(true)
        .onClick(() => {
          promptAction.showToast({ message: $r('app.string.home_feature_coming') });
        })
        Stack() {
          OctIcon({ res: $r('app.media.oct_kebab_horizontal_16'), iconSize: 18, iconColor: $r('app.color.text_secondary') })
        }
.width(44)
.height(44)
        .padding(6)
        .accessibilityDescription($r('app.string.a11y_more'))
        .focusable(true)
        .onClick(() => {
          promptAction.showToast({ message: $r('app.string.home_feature_coming') });
        })
      }
      .width('100%')
      .height(48)
      .padding({ left: 16, right: 8 })

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
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_page'))
  }
}
