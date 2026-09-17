/**
 * 关于页（Spec 069）：Settings → More Options → About。
 * 头部展示 App 图标/名称/版本号；Star 引导文案 + 仓库行（star 钮点击跳转本仓库详情页，行内不加星）；
 * 底部备案号（死值直出）+ 版权行。下拉刷新重拉 star 态，其余零网络请求。
 */
import { bundleManager } from '@kit.AbilityKit';
import { AppBar } from '../components/AppBar';
import { PageShadowBar } from '../components/PageShadowBar';
import { OctIcon } from '../components/OctIcon';
import { RepoStarState } from '../models/RepoDetailModels';
import { RepoService } from '../services/RepoService';

/** 本应用自身仓库（仓库行跳转目标；Spec 065 Share Feedback 同一仓库） */
const ABOUT_REPO_OWNER = 'ZM-BAD';
const ABOUT_REPO_NAME = 'arkcat';

@ComponentV2
export struct SettingsAboutView {
  @Param pathStack: NavPathStack = new NavPathStack();
  @Param token: string = '';
  /** 回页刷新信号：Index onShown 时自增（首显跳过），@Monitor 触发 star 态静默重拉 */
  @Param tick: number = 0;
  @Local scrollShadow: boolean = false;
  /** 版本号：运行时读 bundle 清单（取不到时回退静态串）；文案口径 Version x.y.z（用户 2026-09-17 定案） */
  @Local versionText: ResourceStr = $r('app.string.about_version');
  /** Star 态：null=查询中/失败（计数留空，按钮仍显示、仍可点跳转） */
  @Local star: RepoStarState | null = null;
  /** 首拉占位：true=首次查询未返回（钮面转圈，避免已加星用户的假描边闪变） */
  @Local starLoading: boolean = true;
  /** 下拉刷新圈（系统 Refresh） */
  @Local isRefreshing: boolean = false;

  aboutToAppear(): void {
    this.loadVersion();
    this.loadStarState();
  }

  /** 从详情页返回可见（tick 自增）→ 静默重拉；starLoading 不动，旧态原位更新 */
  @Monitor('tick')
  onTickChanged(): void {
    this.loadStarState();
  }

  private loadVersion(): void {
    try {
      const info = bundleManager.getBundleInfoForSelfSync(bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT);
      this.versionText = `Version ${info.versionName}`;
    } catch (e) {
      // 保持回退串
    }
  }

  /** onDone=刷新圈收起时机（下拉刷新传入；首载/回页重拉不传） */
  private loadStarState(onDone?: () => void): void {
    if (this.token === '') {
      this.starLoading = false;
      onDone?.();
      return;
    }
    RepoService.fetchRepoStarState(this.token, ABOUT_REPO_OWNER, ABOUT_REPO_NAME)
      .then((state: RepoStarState): void => {
        this.star = state;
        this.starLoading = false;
        onDone?.();
      })
      .catch((_e: Error): void => {
        // 查询失败静默：行保留、计数留空
        this.starLoading = false;
        onDone?.();
      });
  }

  /** star 钮唯一动作：跳转仓库详情页，加星在详情页完成（行内不加星，用户 2026-09-17 定案） */
  private openRepo(): void {
    this.pathStack.pushPathByName('repoDetail', `${ABOUT_REPO_OWNER}/${ABOUT_REPO_NAME}`);
  }

  /** 头部：App 图标 + 名称 + 版本号（居中） */
  @Builder
  headerBlock() {
    Column({ space: 8 }) {
      Image($r('app.media.foreground'))
        .width(64)
        .height(64)
        .borderRadius(14)
      Text('ArkCat')
        .fontSize($r('app.float.title_font_size'))
        .fontWeight(600)
        .fontColor($r('app.color.text_primary'))
      Text(this.versionText)
        .fontSize($r('app.float.caption_font_size'))
        .fontColor($r('app.color.text_secondary'))
    }
    .width('100%')
    .padding({ top: 16, bottom: 8 })
    .alignItems(HorizontalAlign.Center)
  }

  /** 仓库行：左仓库名，右 star 钮（钮面=实际加星数，金星=已加星）；仅 star 钮可点，点击跳转详情页 */
  @Builder
  starRow() {
    Row({ space: 8 }) {
      Text(`${ABOUT_REPO_OWNER}/${ABOUT_REPO_NAME}`)
        .fontSize($r('app.float.body_font_size'))
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      if (this.star !== null && this.star.viewerHasStarred) {
        Row({ space: 6 }) {
          OctIcon({ res: $r('app.media.oct_star_fill_16'), iconSize: 14, iconColor: $r('app.color.star_gold') })
          Text(`${this.star.stargazerCount}`)
            .fontSize($r('app.float.caption_font_size'))
            .fontColor($r('app.color.text_primary'))
        }
        .height(28)
        .padding({ left: 10, right: 10 })
        .borderRadius(6)
        .backgroundColor($r('app.color.chip_bg'))
        .border({ width: 1, color: $r('app.color.border') })
        .onClick((): void => this.openRepo())
      } else {
        Row({ space: 6 }) {
          // 首拉中：钮面转圈占位，查询返回后直接渲染真实态（不闪假描边）
          if (this.starLoading) {
            LoadingProgress()
              .width(14)
              .height(14)
              .color($r('app.color.text_secondary'))
          } else {
            OctIcon({ res: $r('app.media.oct_star_16'), iconSize: 14, iconColor: $r('app.color.text_primary') })
            // 查询失败无数字：只显示星形图标，仍可点跳转
            if (this.star !== null) {
              Text(`${this.star.stargazerCount}`)
                .fontSize($r('app.float.caption_font_size'))
                .fontColor($r('app.color.text_primary'))
            }
          }
        }
        .height(28)
        .padding({ left: 10, right: 10 })
        .borderRadius(6)
        .backgroundColor($r('app.color.card_background'))
        .border({ width: 1, color: $r('app.color.border') })
        .onClick((): void => this.openRepo())
      }
    }
    .width('100%')
    .height(46)
    .padding({ left: 16, right: 16 })
    .backgroundColor($r('app.color.card_background'))
    .borderRadius(12)
    .margin({ top: 12 })
  }

  build() {
    Column() {
      AppBar({
        showBack: true,
        title: $r('app.string.settings_about'),
        onBack: (): void => {
          this.pathStack.pop();
        }
      })

      PageShadowBar({ show: this.scrollShadow })

      Refresh({ refreshing: $$this.isRefreshing }) {
        Scroll() {
          Column() {
            this.headerBlock()

            // Star 引导文案：纯展示不跳转（用户 2026-09-17 定案）；行内金星用字形 Span——
            // ImageSpan 不支持 fillColor（编译器实测），oct_* 资源又禁裸 Image，限制记录 Spec 069 §七
            Text() {
              Span('如果觉得好用，请您给个')
              Span('★')
                .fontColor($r('app.color.star_gold'))
            }
            .fontSize($r('app.float.body_font_size'))
            .fontColor($r('app.color.text_primary'))
            .textAlign(TextAlign.Center)
            .width('100%')
            .margin({ top: 8 })

            // 仓库行：star 钮是唯一可点区域，点击跳转详情页
            this.starRow()

            // 备案号死值直出（不走 i18n，用户 2026-09-17 定案）；纯文本居中，置版权行上方
            Text('ICP备案号：浙ICP备2026075163号-1A')
              .fontSize($r('app.float.caption_font_size'))
              .fontColor($r('app.color.text_secondary'))
              .width('100%')
              .textAlign(TextAlign.Center)
              .margin({ top: 24 })

            Text($r('app.string.about_copyright'))
              .fontSize($r('app.float.caption_font_size'))
              .fontColor($r('app.color.text_secondary'))
              .width('100%')
              .textAlign(TextAlign.Center)
              .margin({ top: 6, bottom: 24 })
          }
          .padding({ left: 16, right: 16 })
          .width('100%')
        }
        .scrollBar(BarState.Off)
        .align(Alignment.Top)
        .onScroll((_x: number, y: number): void => {
          this.scrollShadow = y > 0.001;
        })
        .width('100%')
        .height('100%')
      }
      .layoutWeight(1)
      .onRefreshing((): void => {
        this.isRefreshing = true;
        this.loadStarState((): void => {
          this.isRefreshing = false;
        });
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_page'))
  }
}
