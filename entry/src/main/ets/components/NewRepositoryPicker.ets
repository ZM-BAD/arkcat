/**
 * 建仓子弹层共用骨架（Spec 070 元素 14）：✕ + 标题/副标题 + SAVE + 常驻搜索行 + 单选列表。
 * 三个子弹层（模板仓库 / .gitignore / License）共用；SAVE 前选择为待定态（✕ 丢弃），
 * 行选中态走 key 带选中标记（坑 29）。
 * 空态对齐官方截图：灰底画布 + 居中粗体「Nothing to see here」（不用 StateView 的图标空态）。
 */
import { OctIcon } from './OctIcon';
import { StateView } from './StateView';
import { PickerItem, filterPickerItems } from '../models/RepoCreateModels';

@ComponentV2
export struct NewRepositoryPicker {
  @Require @Param title: Resource;
  /** 副标题（Add .gitignore / Repository template）；null 不渲染 */
  @Param subtitle: Resource | null = null;
  @Require @Param searchPlaceholder: Resource;
  @Require @Param options: PickerItem[] = [];
  @Param loading: boolean = false;
  @Param errorMsg: string = '';
  /** 打开时的已选 key（回显蓝勾），未选=空串 */
  @Param initialKey: string = '';
  /** SAVE：提交待定选择（无选择=清空语义，调用方落 null） */
  @Event onSave: (key: string) => void = (key: string): void => { };
  @Event onClose: () => void = (): void => { };
  @Event onRetry: () => void = (): void => { };

  @Local searchText: string = '';
  @Local pendingKey: string = '';

  aboutToAppear(): void {
    this.pendingKey = this.initialKey;
  }

  /** 候选过滤（@Builder/条件渲染区禁局部变量，抽私有方法，坑 9） */
  private filtered(): PickerItem[] {
    return filterPickerItems(this.options, this.searchText);
  }

  build() {
    Column() {
      // 自绘抓取条（官方口径）：框架 dragBar 在 LARGE 档不渲染
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

      // 头部：✕ + 标题块 + SAVE
      Row() {
        Stack() {
          OctIcon({ res: $r('app.media.oct_x_16'), iconSize: 16, iconColor: $r('app.color.text_primary') })
        }
        .width(44)
        .height(44)
        .onClick((): void => this.onClose())
        Column({ space: 2 }) {
          Text(this.title)
            .fontSize($r('app.float.title_font_size'))
            .fontWeight(600)
            .fontColor($r('app.color.text_primary'))
          if (this.subtitle !== null) {
            Text(this.subtitle)
              .fontSize($r('app.float.body_font_size'))
              .fontColor($r('app.color.text_secondary'))
          }
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        .margin({ left: 4 })
        Text($r('app.string.repo_create_save'))
          .fontSize($r('app.float.body_font_size'))
          .fontWeight(600)
          .fontColor($r('app.color.link_blue'))
          .textCase(TextCase.UpperCase)
          .padding({ left: 12, right: 8, top: 10, bottom: 10 })
          .onClick((): void => this.onSave(this.pendingKey))
      }
      .width('100%')
      .padding({ left: 8, right: 8 })
      .alignItems(VerticalAlign.Center)

      // 搜索行（常驻，官方口径；贴边光标防裁配 borderRadius(0)，坑 41）
      Row() {
        OctIcon({ res: $r('app.media.oct_search_16'), iconSize: 18, iconColor: $r('app.color.text_secondary') })
        TextInput({ placeholder: this.searchPlaceholder, text: this.searchText })
          .layoutWeight(1)
          .height(44)
          .fontSize($r('app.float.menu_font_size'))
          .placeholderFont({ size: $r('app.float.menu_font_size') })
          .placeholderColor($r('app.color.text_tertiary'))
          .backgroundColor(Color.Transparent)
          .borderRadius(0)
          .padding({ left: 12, right: 0 })
          .onChange((v: string): void => {
            this.searchText = v;
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16 })
      .alignItems(VerticalAlign.Center)

      Divider()
        .strokeWidth(1)
        .color($r('app.color.divider'))
        .width('100%')

      if (this.loading || this.errorMsg !== '') {
        StateView({
          loading: this.loading,
          error: this.errorMsg,
          onRetry: (): void => this.onRetry()
        })
      } else if (this.filtered().length === 0) {
        // 官方空态：灰底画布 + 居中粗体（元素 15；模板仓库为空/搜索无结果同款）
        Column() {
          Text($r('app.string.work_filter_nothing'))
            .fontSize($r('app.float.title_font_size'))
            .fontWeight(600)
            .fontColor($r('app.color.text_primary'))
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .backgroundColor($r('app.color.bg_page'))
      } else {
        Scroll() {
          Column() {
            ForEach(this.filtered(), (item: PickerItem) => {
              Row() {
                Column({ space: 2 }) {
                  Text(item.label)
                    .fontSize($r('app.float.body_font_size'))
                    .fontColor($r('app.color.text_primary'))
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  if (item.sublabel !== '') {
                    Text(item.sublabel)
                      .fontSize($r('app.float.caption_font_size'))
                      .fontColor($r('app.color.text_secondary'))
                  }
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                if (this.pendingKey === item.key) {
                  OctIcon({ res: $r('app.media.oct_check_16'), iconSize: 16, iconColor: $r('app.color.link_blue') })
                    .margin({ left: 8 })
                }
              }
              .width('100%')
              .height(56)
              .padding({ left: 20, right: 16 })
              .alignItems(VerticalAlign.Center)
              .onClick((): void => {
                this.pendingKey = item.key;
              })
            }, (item: PickerItem) => `${item.key}_${this.pendingKey === item.key ? 'on' : 'off'}`)
          }
          .width('100%')
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .align(Alignment.Top)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.card_background'))
  }
}
