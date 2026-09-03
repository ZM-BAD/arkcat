/**
 * 成就徽章详情页（Spec 052）：全屏蓝紫渐变底，Swiper 在已解锁徽章间左右滑翻页；
 * 中部大徽章/名称/描述 + 奖杯解锁日期 + 触发事件；底部圆点 + Share（ShareKit 分享徽章页）。
 * 数据：AchievementsService（tab=achievements 抓 slug 列表 + 详情懒加载片段）。
 */
import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { systemShare } from '@kit.ShareKit';
import { uniformTypeDescriptor as utd } from '@kit.ArkData';
import { AchievementDetail } from '../models/AchievementModels';
import { AchievementsService } from '../services/AchievementsService';
import { StateView } from '../components/StateView';
import { OctIcon } from '../components/OctIcon';
import { resText } from '../utils/I18n';
import { unlockDateText } from '../utils/Format';

@ComponentV2
export struct AchievementDetailView {
  @Param login: string = '';
  /** 双击进入时定位到第 N 枚徽章（Profile 勋章行下标） */
  @Param startIndex: number = 0;
  @Param pathStack: NavPathStack = new NavPathStack();
  @Local items: AchievementDetail[] = [];
  @Local loading: boolean = true;
  @Local errorMsg: string = '';
  /** Swiper 当前页（圆点指示） */
  @Local current: number = 0;

  aboutToAppear(): void {
    this.load();
  }

  private load(): void {
    this.loading = true;
    this.errorMsg = '';
    AchievementsService.fetchSlugs(this.login)
      .then(async (slugs: string[]) => {
        const items: AchievementDetail[] = [];
        for (const slug of slugs) {
          try {
            items.push(await AchievementsService.fetchDetail(this.login, slug));
          } catch (e) {
            // 单枚详情失败：降级为基础条目（图 + slug 名），不中断整页
            items.push({
              slug: slug,
              name: slug,
              description: '',
              badgeImageUrl: AchievementsService.cdnUrl(slug),
              unlockedAt: '',
              eventRef: '',
              eventLabel: ''
            });
          }
        }
        if (items.length === 0) {
          this.errorMsg = this.stringOf($r('app.string.achievement_load_failed'));
          this.loading = false;
          return;
        }
        this.items = items;
        this.current = Math.min(Math.max(this.startIndex, 0), items.length - 1);
        this.loading = false;
      })
      .catch(() => {
        this.errorMsg = this.stringOf($r('app.string.achievement_load_failed'));
        this.loading = false;
      });
  }

  private stringOf(res: Resource): string {
    return resText(this.getUIContext(), res);
  }

  /** 解锁/事件行文案：事件引用可解析 → 「引用 · 标签」；不可见 → 仅标签 */
  private eventLine(item: AchievementDetail): string {
    return item.eventRef === '' ? item.eventLabel : `${item.eventRef} · ${item.eventLabel}`;
  }

  /** 分享该徽章页面 URL（官方 ShareKit 系统分享面板；图片资源分享为边界外） */
  private shareDetail(item: AchievementDetail): void {
    const url = `https://github.com/${this.login}?achievement=${item.slug}&tab=achievements`;
    try {
      const data = new systemShare.SharedData({
        utd: utd.UniformDataType.HYPERLINK,
        content: url,
        title: item.name !== '' ? item.name : item.slug
      });
      const controller = new systemShare.ShareController(data);
      controller.show(this.getUIContext().getHostContext() as common.UIAbilityContext, {
        previewMode: systemShare.SharePreviewMode.DEFAULT,
        selectionMode: systemShare.SelectionMode.SINGLE
      });
    } catch (e) {
      promptAction.showToast({ message: this.stringOf($r('app.string.achievement_share_failed')) });
    }
  }

  /** 单页内容：徽章 + 名称/描述 + 解锁行 + 事件行 */
  @Builder
  badgePage(item: AchievementDetail) {
    Column({ space: 12 }) {
      Image(item.badgeImageUrl)
        .width(260)
        .height(260)
        .borderRadius(130)
        .backgroundColor($r('app.color.achievement_close_bg'))
        .margin({ top: 20, bottom: 12 })
      Text(item.name)
        .fontSize(26)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      if (item.description !== '') {
        Text(item.description)
          .fontSize(15)
          .fontColor(Color.White)
          .opacity(0.85)
          .textAlign(TextAlign.Center)
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      if (item.unlockedAt !== '') {
        Row({ space: 10 }) {
          Stack() {
            OctIcon({ res: $r('app.media.oct_trophy_16'), iconSize: 12, iconColor: Color.White })
          }
          .width(24)
          .height(24)
          .borderRadius(12)
          .backgroundColor($r('app.color.achievement_close_bg'))
          Text(resText(this.getUIContext(), $r('app.string.achievement_unlocked_fmt'),
            unlockDateText(item.unlockedAt)))
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .maxLines(1)
        }
        .width('100%')
        .padding({ left: 40, right: 40, top: 14 })
        .justifyContent(FlexAlign.Start)
      }
      if (this.eventLine(item) !== '') {
        Row({ space: 10 }) {
          Circle()
            .width(5)
            .height(5)
            .fill(Color.White)
            .opacity(0.7)
          Text(this.eventLine(item))
            .fontSize(13)
            .fontColor(Color.White)
            .opacity(0.85)
            .layoutWeight(1)
        }
        .width('100%')
        .padding({ left: 40, right: 40, top: 4 })
        .alignItems(VerticalAlign.Top)
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  build() {
    Column() {
      Row() {
        Blank()
        Stack() {
          OctIcon({ res: $r('app.media.oct_x_16'), iconSize: 16, iconColor: Color.White })
        }
        .width(36)
        .height(36)
        .borderRadius(18)
        .backgroundColor($r('app.color.achievement_close_bg'))
        .accessibilityDescription($r('app.string.achievement_close'))
        .focusable(true)
        .onClick(() => {
          this.pathStack.pop();
        })
      }
      .width('100%')
      .height(56)
      .padding({ right: 16 })

      if (this.items.length > 0) {
        Swiper() {
          ForEach(this.items, (item: AchievementDetail) => {
            this.badgePage(item)
          }, (item: AchievementDetail) => item.slug)
        }
        .index(this.current)
        .onChange((index: number) => {
          this.current = index;
        })
        .indicator(false)
        .loop(false)
        .layoutWeight(1)

        Row({ space: 8 }) {
          ForEach(this.items, (item: AchievementDetail, index: number) => {
            Circle()
              .width(7)
              .height(7)
              .fill(Color.White)
              .opacity(index === this.current ? 1 : 0.3)
          }, (item: AchievementDetail) => item.slug)
        }
        .padding({ top: 4, bottom: 18 })

        Column() {
          Text(this.stringOf($r('app.string.achievement_share')))
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor(Color.White)
            .textAlign(TextAlign.Center)
            .height(48)
            .width('100%')
            .borderRadius(24)
            .backgroundColor($r('app.color.achievement_share_bg'))
            .onClick(() => {
              this.shareDetail(this.items[this.current]);
            })
        }
        .width('100%')
        .padding({ left: 20, right: 20, bottom: 28 })
      } else {
        StateView({
          loading: this.loading,
          error: this.errorMsg,
          onRetry: () => this.load()
        })
      }
    }
    .width('100%')
    .height('100%')
    .linearGradient({
      direction: GradientDirection.Bottom,
      colors: [[$r('app.color.achievement_bg_top'), 0], [$r('app.color.achievement_bg_bottom'), 1]]
    })
  }
}
