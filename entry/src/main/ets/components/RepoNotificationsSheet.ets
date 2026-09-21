/**
 * RepoDetail Bell 的 Notifications 面板（Spec 045，官方实机同构）：自绘抓取条 + 头行（✕ + 标题）+
 * 三行单选（标题 + 官方说明文案 + 行尾单选圆钮）+ 分隔线 + Custom 段（展开列出四个只读事件行）。
 *
 * 选中态刷新：每行是独立组件（@Param current），与 SortBySheet/FilterDropdownChip 同口径——
 * 面板内容在 bindSheet 内会被复用，「@Builder 值参数」读不回新状态，圆钮会卡旧值（表现为点不动）。
 * 订阅态与错误文案由调用方传入，选择经 onPick 上抛；本组件不调服务。
 */
import { OctIcon } from './OctIcon';

/** 面板单选行：标题 + 说明文案 + 行尾单选圆钮（选中态经 @Param 刷新） */
@ComponentV2
struct NotifyOptionRow {
  @Param state: string = '';
  @Param label: Resource = $r('app.string.repo_watch_participating');
  @Param desc: Resource = $r('app.string.repo_watch_participating_desc');
  /** 当前订阅态：与 state 相等即选中 */
  @Param current: string = '';
  @Event onPick: (state: string) => void = (state: string): void => { };

  build() {
    Row({ space: 12 }) {
      Column({ space: 4 }) {
        Text(this.label)
          .fontSize($r('app.float.body_font_size'))
          .fontWeight(600)
          .fontColor($r('app.color.text_primary'))
        Text(this.desc)
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_secondary'))
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      // 单选圆钮：未选 = 灰描边空心圆，选中 = 主题蓝描边 + 蓝色实心点（官方口径，同 SortBySheet）
      Stack() {
        Circle()
          .width(22)
          .height(22)
          .fill(Color.Transparent)
          .stroke(this.current === this.state ? $r('app.color.link_blue') : $r('app.color.text_tertiary'))
          .strokeWidth(2)
        if (this.current === this.state) {
          Circle()
            .width(10)
            .height(10)
            .fill($r('app.color.link_blue'))
        }
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .alignItems(VerticalAlign.Center)
    .onClick((): void => this.onPick(this.state))
  }
}

/** Custom 段事件行：官方为复选框；自定义事件无公开 API 可读写，按灰态空心方框只读展示不模拟勾选 */
@ComponentV2
struct NotifyEventRow {
  @Param label: Resource = $r('app.string.repo_watch_custom_issues');

  build() {
    Row() {
      Text(this.label)
        .fontSize($r('app.float.body_font_size'))
        .fontColor($r('app.color.text_primary'))
      Blank()
      OctIcon({ res: $r('app.media.oct_square_16'), iconSize: 20, iconColor: $r('app.color.text_tertiary') })
    }
    .width('100%')
    .height(52)
    .padding({ left: 16, right: 16 })
  }
}

@ComponentV2
export struct RepoNotificationsSheet {
  /** 当前账号订阅态（UNSUBSCRIBED/SUBSCRIBED/IGNORED/PROTECTED）：驱动行尾单选圆钮 */
  @Param viewerSubscription: string = '';
  /** 写入失败文案（'' = 无错误）：近全屏弹层会挡住 toast，失败原因在面板内可见 */
  @Param errorText: string = '';
  @Event onPick: (state: string) => void = (state: string): void => { };
  @Event onClose: () => void = (): void => { };
  /** Custom 段展开态：面板每次拉起都是新实例，天然回到官方默认收起态 */
  @Local customOpen: boolean = false;

  /** Custom 段头行：标题 + 官方说明 + 展开箭头；点击只切换展开，不写订阅态 */
  @Builder
  customHeader() {
    Row({ space: 12 }) {
      Column({ space: 4 }) {
        Text($r('app.string.repo_watch_custom'))
          .fontSize($r('app.float.body_font_size'))
          .fontWeight(600)
          .fontColor($r('app.color.text_primary'))
        Text($r('app.string.repo_watch_custom_desc'))
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_secondary'))
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      OctIcon({
        res: this.customOpen ? $r('app.media.oct_chevron_up_16') : $r('app.media.oct_chevron_down_16'),
        iconSize: 16,
        iconColor: $r('app.color.text_secondary')
      })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .alignItems(VerticalAlign.Center)
    .onClick((): void => {
      this.customOpen = !this.customOpen;
    })
  }

  build() {
    Column() {
      // 自绘抓取条：SheetSize.LARGE 档框架不渲染 dragBar（Spec 070 同口径 36×5）
      Row() {
        Row()
          .width(36)
          .height(5)
          .borderRadius(2.5)
          .backgroundColor($r('app.color.text_tertiary'))
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .padding({ top: 8, bottom: 6 })

      Row() {
        Stack() {
          OctIcon({ res: $r('app.media.oct_x_16'), iconSize: 18, iconColor: $r('app.color.text_primary') })
        }
        .width(44)
        .height(44)
        .onClick((): void => this.onClose())

        Text($r('app.string.repo_watch_sheet_title'))
          .fontSize($r('app.float.title_font_size'))
          .fontWeight(600)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
      }
      .width('100%')
      .height(56)
      .padding({ left: 8, right: 16 })

      Divider()
        .color($r('app.color.divider'))
        .strokeWidth(1)
        .width('100%')

      Scroll() {
        Column() {
          NotifyOptionRow({
            state: 'UNSUBSCRIBED',
            label: $r('app.string.repo_watch_participating'),
            desc: $r('app.string.repo_watch_participating_desc'),
            current: this.viewerSubscription,
            onPick: (state: string): void => this.onPick(state)
          })
          NotifyOptionRow({
            state: 'SUBSCRIBED',
            label: $r('app.string.repo_watch_all'),
            desc: $r('app.string.repo_watch_all_desc'),
            current: this.viewerSubscription,
            onPick: (state: string): void => this.onPick(state)
          })
          NotifyOptionRow({
            state: 'IGNORED',
            label: $r('app.string.repo_watch_ignore'),
            desc: $r('app.string.repo_watch_ignore_desc'),
            current: this.viewerSubscription,
            onPick: (state: string): void => this.onPick(state)
          })

          Divider()
            .color($r('app.color.divider'))
            .strokeWidth(1)
            .width('100%')
            .margin({ top: 8 })

          this.customHeader()
          if (this.customOpen) {
            NotifyEventRow({ label: $r('app.string.repo_watch_custom_issues') })
            NotifyEventRow({ label: $r('app.string.repo_watch_custom_pulls') })
            NotifyEventRow({ label: $r('app.string.repo_watch_custom_releases') })
            NotifyEventRow({ label: $r('app.string.repo_watch_custom_security') })

            Text($r('app.string.repo_watch_custom_readonly'))
              .fontSize($r('app.float.caption_font_size'))
              .fontColor($r('app.color.text_secondary'))
              .width('100%')
              .padding({ left: 16, right: 16, top: 4, bottom: 8 })
          }

          // 写入失败原因（toast 会被近全屏弹层遮挡，故在面板内落一行可见反馈）
          if (this.errorText !== '') {
            Text(this.errorText)
              .fontSize($r('app.float.caption_font_size'))
              .fontColor($r('app.color.danger_text'))
              .width('100%')
              .padding({ left: 16, right: 16, top: 8 })
          }
        }
        .width('100%')
        .padding({ bottom: 24 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      // 内容不足一屏时顶对齐：Scroll 默认居中会把首行推离头部（同 SortBySheet）
      .align(Alignment.Top)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.card_background'))
  }
}
