/**
 * 成就徽章详情页（Spec 052）：全屏蓝紫渐变底，Swiper 在已解锁徽章间左右滑翻页；
 * 中部大徽章/名称/描述 + 奖杯解锁日期 + 触发事件；底部圆点 + Share（ShareKit 分享徽章页）。
 * 数据：AchievementsService（tab=achievements 抓 slug 列表 + 详情懒加载片段）。
 */
import { common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { AchievementDetail, AchievementEvent } from '../models/AchievementModels';
import { achievementTheme } from '../models/AchievementThemeColors';
import { AchievementsService } from '../services/AchievementsService';
import { StateView } from '../components/StateView';
import { OctIcon } from '../components/OctIcon';
import { resText } from '../utils/I18n';
import { shareLink, userPageUrl } from '../utils/Share';
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
  /** 滑动渐变过渡层：目标页横幅 URL + 淡入进度（0~1，onGestureSwipe 逐帧驱动） */
  @Local fadeUrl: string = '';
  @Local fadeT: number = 0;
  /** 过渡期间基底层钉住的来源页横幅（onChange 后基底层仍显示来源页，动画完成才切目标页） */
  @Local fadeFromUrl: string = '';
  /** 窗口宽度（vp；aboutToAppear 缓存）——中部信息组与事件文案的确定性 maxWidth 依赖它 */
  @Local pageWidthVp: number = 360;

  aboutToAppear(): void {
    window.getLastWindow(this.getUIContext().getHostContext() as common.Context)
      .then((w: window.Window) => {
        this.pageWidthVp = this.getUIContext().px2vp(w.getWindowProperties().windowRect.width);
      })
      .catch(() => {
      });
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
            detailBgUrl: '',
            unlockedAt: '',
            events: []
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

  /** 当前页主题横幅 URL（根布局背景用）；未加载/越界时返回空串 → 不画图走渐变兜底。
   *  过渡期间（fadeUrl 非空）基底层钉在来源页，避免 onChange 后基底层先跳到目标页破坏渐变。 */
  private currentBgUrl(): string {
    if (this.fadeUrl !== '' && this.fadeFromUrl !== '') {
      return this.fadeFromUrl;
    }
    const item = this.items[this.current];
    return item ? item.detailBgUrl : '';
  }

  /** 渐变兜底顶/底色：官方横幅不可用时优先用本地全量色表（官方横幅逐像素采样），
   *  未收录徽章再退通用蓝紫渐变 token */
  private bgTopColor(): ResourceColor {
    if (this.currentBgUrl() === '') {
      const item = this.items[this.current];
      const theme = item ? achievementTheme(item.slug) : null;
      if (theme !== null) {
        return theme.top;
      }
    }
    return $r('app.color.achievement_bg_top');
  }

  private bgBottomColor(): ResourceColor {
    if (this.currentBgUrl() === '') {
      const item = this.items[this.current];
      const theme = item ? achievementTheme(item.slug) : null;
      if (theme !== null) {
        return theme.bottom;
      }
    }
    return $r('app.color.achievement_bg_bottom');
  }

  /** 事件区底部淡出带颜色对逻辑已随事件列表移入 AchievementEventList */


  /** 单条事件文案逻辑已随事件列表移入 AchievementEventList */

  /** 分享该徽章页面 URL（系统分享面板；图片资源分享为边界外） */
  private shareDetail(item: AchievementDetail): void {
    const url = `${userPageUrl(this.login)}?achievement=${item.slug}&tab=achievements`;
    shareLink(this.getUIContext(), url, item.name !== '' ? item.name : item.slug);
  }

  /** 单页内容：徽章 + 名称/描述 + 解锁行 + 事件行（整页主题背景由根布局按当前页绘制） */
  @Builder
  badgePage(item: AchievementDetail) {
    Column({ space: 12 }) {
      Image(item.badgeImageUrl)
        .width(260)
        .height(260)
        // 不裁圆：徽章图多为圆形但存在异形（如 Arctic Code Vault），borderRadius 会截断官方图
        .margin({ top: 20, bottom: 12 })
        Text(item.name)
          .fontSize($r('app.float.title_font_size'))
          .fontWeight(600)
          .fontColor(Color.White)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (item.description !== '') {
          Text(item.description)
            .fontSize($r('app.float.chip_font_size'))
            .fontColor(Color.White)
            .opacity(0.85)
            .textAlign(TextAlign.Center)
            .maxLines(3)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            // 居中且最左不越过奖杯（奖杯左缘 24、中轴 36）：左右各留 36 使文本框对称居中，
            // 长文案在框内换行
            .padding({ left: 36, right: 36 })
        }
        if (item.unlockedAt !== '' || item.events.length > 0) {
          // 解锁信息 + 事件合成一组：组宽撑满、左缘固定距屏幕左边一个奖杯宽度（24），
          // 保证每个徽章页 trophy 与 dot-fill 距左边缘位置一致；组内左对齐，
          // Unlocked 文案与事件文案左缘一致，事件文案左缘（24+24+10=58）在奖杯中轴（24+12=36）右侧
          Column() {
            if (item.unlockedAt !== '') {
              Row({ space: 24 }) {
                Stack() {
                  // 圆形阴影背景：半透明阴影色圆垫底（无实底/无描边），衬白色奖杯图标
                  Circle()
                    .width(24)
                    .height(24)
                    .fill($r('app.color.achievement_icon_shadow'))
                  OctIcon({ res: $r('app.media.oct_trophy_16'), iconSize: 12, iconColor: Color.White })
                }
                .width(24)
                .height(24)
                Text(resText(this.getUIContext(), $r('app.string.achievement_unlocked_fmt'),
                  unlockDateText(item.unlockedAt)))
                  .fontSize($r('app.float.chip_font_size'))
                  .fontWeight(600)
                  .fontColor(Color.White)
                  .maxLines(1)
              }
              .alignItems(VerticalAlign.Center)
              .padding({ top: 14 })
            }
            if (item.events.length > 0) {
              AchievementEventList({
                events: item.events,
                slug: item.slug,
                pageWidthVp: this.pageWidthVp
              })
            }
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          .padding({ left: 24, right: 40 })
        }
      }
      .width('100%')
      .height('100%')
      // 顶部锚定：徽章位置统一固定（Pair Extraordinaire 基准——其事件区最长、
      // 整组几乎填满 Swiper，即徽章贴 Swiper 顶 + margin 20），名称/描述/Unlocked/
      // dot-fill 与徽章相对间距不变、依次向下排列；内容短的徽章在圆点区上方自然留白。
      // Share 按钮与翻页圆点在 Swiper 外，位置不受影响
      .justifyContent(FlexAlign.Start)
  }

  build() {
    Stack() {
      // 背景基底层：本地色表渐变（兜底）+ 当前页官方主题横幅（随 current 切换）
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          direction: GradientDirection.Bottom,
          colors: [[this.bgTopColor(), 0], [this.bgBottomColor(), 1]]
        })
        .backgroundImage(this.currentBgUrl())
        // Fill 拉伸铺满（横幅按整宽渐变条设计）：Cover 会裁掉左右约 79%，
        // Starstruck 这类多向渐变只剩中段色，与官方资产明显不符
        .backgroundImageSize(ImageSize.FILL)
      // 滑动渐变过渡层：目标页横幅按滑动进度淡入（onGestureSwipe 逐帧驱动，落定后清除）
      if (this.fadeUrl !== '') {
        Image(this.fadeUrl)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .opacity(this.fadeT)
          .draggable(false)
      }
      // 内容层
      Column() {
        Row() {
          Blank()
          Stack() {
            // 圆形阴影背景：半透明阴影色圆垫底（无实底/无描边），与 trophy 圆钮同款
            Circle()
              .width(36)
              .height(36)
              .fill($r('app.color.achievement_icon_shadow'))
            OctIcon({ res: $r('app.media.oct_x_16'), iconSize: 16, iconColor: Color.White })
          }
          .width(36)
          .height(36)
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
            const prev = this.current;
            this.current = index;
            if (this.fadeUrl === '') {
              return;
            }
            // 松手后的翻页补间动画不再逐帧回调 onGestureSwipe，过渡层会冻在中途——
            // 用显式动画推到终态再清除：翻页成功淡入到 1、取消滑动淡出回 0，消除突变；
            // 基底层经 currentBgUrl() 钉在来源页，动画完成后才切目标页（同一张图，无跳变）
            const ui = this.getUIContext();
            ui.animateTo(
              {
                duration: 150,
                curve: Curve.Linear,
                onFinish: () => {
                  this.fadeUrl = '';
                  this.fadeFromUrl = '';
                  this.fadeT = 0;
                }
              },
              () => {
                this.fadeT = index !== prev ? 1 : 0;
              }
            );
          })
          .onGestureSwipe((index: number, extraInfo: SwiperAnimationEvent) => {
            // 滑动过程中按进度交叉淡入目标页横幅：背景随手指渐变而非翻完才切换
            const width = this.pageWidthVp;
            const offset = extraInfo.currentOffset;
            if (width <= 0 || offset === 0) {
              return;
            }
          const t: number = Math.min(1, Math.abs(offset) / width);
          const target: number = index + (offset < 0 ? 1 : -1);
          if (target < 0 || target >= this.items.length || this.items[target] === undefined) {
            return;
          }
          const src = this.items[index];
          const to = this.items[target];
          if (src === undefined || to.detailBgUrl === '') {
            return;
          }
          this.fadeFromUrl = src.detailBgUrl;
          this.fadeUrl = to.detailBgUrl;
          this.fadeT = t;
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
            // 与 Home 页 outlineButton（ADD FAVORITES/GET STARTED）同风格：透明底 + 1vp 描边 + 6vp 圆角；
            // 主题彩底上文字/描边用白（描边 token 半透明白），位置低不刺眼
            Button(this.stringOf($r('app.string.achievement_share')))
              .type(ButtonType.Normal)
              .width('100%')
              .height(44)
              .fontSize($r('app.float.caption_font_size'))
              .fontWeight(FontWeight.Bold) // typography-exempt 走查定案：Share 钮 Bold
              .fontColor(Color.White)
              .backgroundColor(Color.Transparent)
              .borderRadius($r('app.float.button_radius'))
              .border({ width: 1, color: $r('app.color.achievement_share_border') })
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
    }
    .width('100%')
    .height('100%')
  }
}

/**
 * 成就事件列表（Spec 052）：与 Unlocked 行同构左对齐——图标列固定距左 24，
 * trophy 与所有 dot-fill 严格同列（同一竖线），文案左缘一致。
 * 行数超出受限高度时内滚（无滚动条，类似滑动）；仅内容溢出需要滚动时才显示
 * 底部渐变淡出带（与翻页圆点交界处），不溢出无遮挡即无渐变。
 * 独立组件：Swiper 多页各自的溢出测量互不串扰（共享状态会串页）。
 * 此前曾因 Scroll 无界测量致长文案折行丢字而移除，现子 Column 显式 width('100%')
 * + Text 显式 maxWidth，测量有界不复发。
 */
@ComponentV2
struct AchievementEventList {
  @Param events: AchievementEvent[] = [];
  @Param slug: string = '';
  @Param pageWidthVp: number = 360;
  /** 内容高度超过受限高度（需要滚动）时才显示底部淡出带 */
  @Local overflow: boolean = false;

  /** 单条事件文案：引用+标签 → 「引用 · 标签」；仅引用（Arctic Vault 仓库列表）→ 仅引用；
   *  仅标签 / 引用不可见（私有仓库）→ 仅标签 */
  private eventText(ev: AchievementEvent): string {
    if (ev.ref === '') {
      return ev.label;
    }
    return ev.label === '' ? ev.ref : `${ev.ref} · ${ev.label}`;
  }

  /** 底部淡出带颜色对 [透明端, 实色端]：取当前徽章色表底部色（横幅即该色系，
   *  与页面背景同源）；未收录徽章退蓝紫 token（配对透明 token） */
  private fadeColors(): ResourceColor[] {
    const theme = achievementTheme(this.slug);
    if (theme !== null) {
      // '#RRGGBB' → '#00RRGGBB'（全透）
      const top = '#00' + theme.bottom.slice(1);
      return [top, theme.bottom];
    }
    return [$r('app.color.achievement_bg_bottom_fade'), $r('app.color.achievement_bg_bottom')];
  }

  build() {
    Stack() {
      Scroll() {
        Column({ space: 10 }) {
          ForEach(this.events, (ev: AchievementEvent, index: number) => {
            // 图标列与文案间距 = 一个奖杯宽度（24），与 Unlocked 行一致（文案左缘仍对齐）
            Row({ space: 24 }) {
              // dot-fill 容器与奖杯同宽 24，文案左缘与「Unlocked」对齐；
              // 高度取 12fp 首行行高并与行顶对齐，点与首行文字垂直居中（多行事件不跑位）
              Stack() {
                OctIcon({ res: $r('app.media.oct_dot_fill_16'), iconSize: 10, iconColor: Color.White })
              }
              .width(24)
              .height(16)
              .opacity(0.7)
              Text(this.eventText(ev))
                .fontSize($r('app.float.caption_font_size'))
                .fontColor(Color.White)
                .opacity(0.85)
                // 确定性 maxWidth（可用宽 = 组宽 - 图标列 24 - 间距 24 - 组左 24 - 组右 40）：
                // Text 处于自适应宽度嵌套链时，折行测量与最终裁剪宽度可能不一致
                //（长文案会整段丢字），显式给定上限让两轮测量取同一确定值
                .constraintSize({ maxWidth: this.pageWidthVp - 112 })
            }
            .alignItems(VerticalAlign.Top)
          }, (ev: AchievementEvent, index: number) => `${this.slug}_${index}`)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        // 底部留白 > 淡出带高度（32）：多行末行也能完全滚出渐变带（14 时末行永远压在渐变里）
        .padding({ bottom: 36 })
        .onAreaChange((_oldArea: Area, newArea: Area) => {
          // 内容总高（含留白）超过受限高度 → 需要滚动，才显示淡出带
          this.overflow = Number(newArea.height) > 160;
        })
      }
      .scrollBar(BarState.Off)
      .width('100%')
      // 事件区与翻页圆点交界处的渐变淡出带：颜色取当前徽章主题底部色（与页面背景同源，
      // 透明→实色），只压视觉不拦截滚动手势
      if (this.overflow) {
        Row()
          .width('100%')
          .height(32)
          .linearGradient({
            direction: GradientDirection.Bottom,
            colors: [[this.fadeColors()[0], 0], [this.fadeColors()[1], 1]]
          })
          .hitTestBehavior(HitTestMode.None)
      }
    }
    .width('100%')
    .alignContent(Alignment.Bottom)
    .constraintSize({ maxHeight: 160 })
    .padding({ top: 4 })
  }
}
