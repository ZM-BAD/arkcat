/**
 * New repository 弹层 General 步（Spec 070 元素 2-6）：
 * ✕ + 两行标题 + NEXT 顶栏、Owner 静态行、仓库名/描述输入（含计数与空名行内错误）。
 * 字号对齐建 Issue 表单先例（Spec 043）：头部小灰行 caption、区块标签 body、输入 menu、
 * 计数/错误 caption、NEXT=body 600（FilterActivity SAVE 同款）。
 * NEXT 官方截图中恒为可点蓝字（空名亦然）→ 空名时行内 danger 文案，不置灰不跳转（§七 推断）。
 */
import { OctIcon } from './OctIcon';
import { Avatar } from './Avatar';
import { REPO_NAME_MAX, REPO_DESC_MAX } from '../models/RepoCreateModels';

@ComponentV2
export struct NewRepositoryGeneral {
  @Require @Param ownerLogin: string;
  @Require @Param ownerAvatar: string;
  @Param name: string = '';
  @Param description: string = '';
  /** 空名行内错误提示开关 */
  @Param nameError: boolean = false;
  /** ✕ 关闭整个流程（壳外关 Home 弹层） */
  @Event onClose: () => void = (): void => { };
  @Event onNext: () => void = (): void => { };
  @Event onNameChange: (v: string) => void = (v: string): void => { };
  @Event onDescChange: (v: string) => void = (v: string): void => { };

  build() {
    Column() {
      // 顶栏：✕ + 两行标题 + NEXT
      Row() {
        Stack() {
          OctIcon({ res: $r('app.media.oct_x_16'), iconSize: 16, iconColor: $r('app.color.text_primary') })
        }
        .width(44)
        .height(44)
        .onClick((): void => this.onClose())
        Column({ space: 2 }) {
          Text($r('app.string.create_new_repo'))
            .fontSize($r('app.float.caption_font_size'))
            .fontColor($r('app.color.text_secondary'))
          Text($r('app.string.repo_create_general'))
            .fontSize($r('app.float.title_font_size'))
            .fontWeight(600)
            .fontColor($r('app.color.text_primary'))
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        .margin({ left: 4 })
        Text($r('app.string.repo_create_next'))
          .fontSize($r('app.float.body_font_size'))
          .fontWeight(600)
          .fontColor($r('app.color.link_blue'))
          .textCase(TextCase.UpperCase)
          .padding({ left: 12, right: 8, top: 10, bottom: 10 })
          .onClick((): void => this.onNext())
      }
      .width('100%')
      .padding({ left: 8, right: 8, top: 4 })
      .alignItems(VerticalAlign.Center)

      // Owner 行（官方无组织时为静态行，§五）
      Row() {
        Text($r('app.string.repo_create_owner'))
          .fontSize($r('app.float.body_font_size'))
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
        Avatar({ url: this.ownerAvatar, diameter: 28 })
        Text(this.ownerLogin)
          .fontSize($r('app.float.body_font_size'))
          .fontWeight(600)
          .fontColor($r('app.color.text_primary'))
          .margin({ left: 8 })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .height(64)
      .padding({ left: 16, right: 16 })
      .alignItems(VerticalAlign.Center)

      Divider()
        .strokeWidth(1)
        .color($r('app.color.divider'))
        .width('100%')

      // Repository name 区
      Column({ space: 6 }) {
        Text($r('app.string.repo_create_name_label'))
          .fontSize($r('app.float.body_font_size'))
          .fontColor($r('app.color.text_secondary'))
        TextInput({ placeholder: $r('app.string.repo_create_name_placeholder'), text: this.name })
          .width('100%')
          .height(44)
          .fontSize($r('app.float.menu_font_size'))
          .fontColor($r('app.color.text_primary'))
          .placeholderFont({ size: $r('app.float.menu_font_size') })
          .placeholderColor($r('app.color.text_tertiary'))
          .caretColor($r('app.color.link_blue'))
          .maxLength(REPO_NAME_MAX)
          .backgroundColor(Color.Transparent)
          // 贴边输入光标被默认圆角裁成月牙，显式归零（坑 41）
          .borderRadius(0)
          .padding({ left: 0, right: 0 })
          .onChange((v: string): void => this.onNameChange(v))
        Text($r('app.string.repo_create_name_hint'))
          .fontSize($r('app.float.body_font_size'))
          .fontColor($r('app.color.text_secondary'))
        Text($r('app.string.repo_create_counter', this.name.length, REPO_NAME_MAX))
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_secondary'))
        if (this.nameError) {
          Text($r('app.string.repo_create_error_empty_name'))
            .fontSize($r('app.float.caption_font_size'))
            .fontColor($r('app.color.danger_text'))
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 16, right: 16, top: 16, bottom: 20 })

      Divider()
        .strokeWidth(1)
        .color($r('app.color.divider'))
        .width('100%')

      // Description 区
      Column({ space: 6 }) {
        Text($r('app.string.repo_create_desc_label'))
          .fontSize($r('app.float.body_font_size'))
          .fontColor($r('app.color.text_secondary'))
        TextArea({ placeholder: $r('app.string.repo_create_desc_placeholder'), text: this.description })
          .width('100%')
          .fontSize($r('app.float.menu_font_size'))
          .fontColor($r('app.color.text_primary'))
          .placeholderFont({ size: $r('app.float.menu_font_size') })
          .placeholderColor($r('app.color.text_tertiary'))
          .caretColor($r('app.color.link_blue'))
          .maxLength(REPO_DESC_MAX)
          .backgroundColor(Color.Transparent)
          .borderRadius(0)
          .padding({ left: 0, right: 0, top: 4, bottom: 4 })
          .onChange((v: string): void => this.onDescChange(v))
        Text($r('app.string.repo_create_counter', this.description.length, REPO_DESC_MAX))
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_secondary'))
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 16, right: 16, top: 16, bottom: 20 })
    }
    .width('100%')
    .height('100%')
  }
}
