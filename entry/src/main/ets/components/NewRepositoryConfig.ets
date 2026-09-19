/**
 * New repository 弹层 Configuration 步（Spec 070 元素 7-13）：
 * ← + 两行标题 + CREATE 顶栏、可见性开关（标题值联动）、模板行与初始内容行。
 * 字号对齐建 Issue 表单先例（Spec 043）：头部小灰行 caption、行标签 body、
 * 说明/hint caption、行尾动作钮 body 600（FilterActivity SAVE 同款）。
 * 模板选中后初始内容三行隐藏（语义互斥，§五）；行尾值回显（SELECT→选中名，§七 推断）。
 * 行主体与 Switch 兄弟拆分，防点击冒泡双触发（坑 10）。
 */
import { OctIcon } from './OctIcon';

@ComponentV2
export struct NewRepositoryConfig {
  @Param isPrivate: boolean = true;
  @Param addReadme: boolean = false;
  /** 选中回显（空=显示 SELECT）；templateName 非空时初始内容三行隐藏 */
  @Param gitignoreName: string = '';
  @Param licenseName: string = '';
  @Param templateName: string = '';
  @Event onBack: () => void = (): void => { };
  @Event onCreate: () => void = (): void => { };
  @Event onPrivateChange: (v: boolean) => void = (v: boolean): void => { };
  @Event onReadmeChange: (v: boolean) => void = (v: boolean): void => { };
  @Event onPickTemplate: () => void = (): void => { };
  @Event onPickGitignore: () => void = (): void => { };
  @Event onPickLicense: () => void = (): void => { };

  build() {
    Column() {
      // 顶栏：← + 两行标题 + CREATE
      Row() {
        Stack() {
          OctIcon({ res: $r('app.media.oct_arrow_left_24'), iconSize: 20, iconColor: $r('app.color.text_primary') })
        }
        .width(44)
        .height(44)
        .onClick((): void => this.onBack())
        Column({ space: 2 }) {
          Text($r('app.string.create_new_repo'))
            .fontSize($r('app.float.caption_font_size'))
            .fontColor($r('app.color.text_secondary'))
          Text($r('app.string.repo_create_configuration'))
            .fontSize($r('app.float.title_font_size'))
            .fontWeight(600)
            .fontColor($r('app.color.text_primary'))
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        .margin({ left: 4 })
        Text($r('app.string.repo_create_create'))
          .fontSize($r('app.float.body_font_size'))
          .fontWeight(600)
          .fontColor($r('app.color.link_blue'))
          .textCase(TextCase.UpperCase)
          .padding({ left: 12, right: 8, top: 10, bottom: 10 })
          .onClick((): void => this.onCreate())
      }
      .width('100%')
      .padding({ left: 8, right: 8, top: 4 })
      .alignItems(VerticalAlign.Center)

      // Visibility 区（值随开关实时切换）
      Column({ space: 4 }) {
        Text() {
          Span($r('app.string.repo_create_visibility_label'))
          Span(this.isPrivate ? $r('app.string.repo_create_visibility_private')
            : $r('app.string.repo_create_visibility_public'))
            .fontWeight(600)
        }
        .fontSize($r('app.float.menu_font_size'))
        .fontColor($r('app.color.text_primary'))
        Text($r('app.string.repo_create_visibility_desc'))
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_secondary'))
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 16, right: 16, top: 16, bottom: 8 })

      // Private repository 行（行主体与 Switch 兄弟拆分，坑 10）
      Row() {
        Text($r('app.string.repo_create_private_repo'))
          .fontSize($r('app.float.body_font_size'))
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
          .onClick((): void => this.onPrivateChange(!this.isPrivate))
        Toggle({ type: ToggleType.Switch, isOn: this.isPrivate })
          .selectedColor($r('app.color.link_blue'))
          .onChange((on: boolean): void => this.onPrivateChange(on))
      }
      .width('100%')
      .height(64)
      .padding({ left: 16, right: 16 })
      .alignItems(VerticalAlign.Center)

      Divider()
        .strokeWidth(1)
        .color($r('app.color.divider'))
        .width('100%')

      // Start with a template 行（行尾回显模板名）
      Row() {
        Text($r('app.string.repo_create_start_template'))
          .fontSize($r('app.float.body_font_size'))
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
          .maxLines(1)
        if (this.templateName === '') {
          Text($r('app.string.repo_create_select'))
            .fontSize($r('app.float.body_font_size'))
            .fontWeight(600)
            .fontColor($r('app.color.link_blue'))
            .textCase(TextCase.UpperCase)
        } else {
          Text(this.templateName)
            .fontSize($r('app.float.body_font_size'))
            .fontColor($r('app.color.text_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .width('100%')
      .height(64)
      .padding({ left: 16, right: 16 })
      .alignItems(VerticalAlign.Center)
      .onClick((): void => this.onPickTemplate())

      Divider()
        .strokeWidth(1)
        .color($r('app.color.divider'))
        .width('100%')

      if (this.templateName === '') {
        // Add README（行主体与 Switch 兄弟拆分）
        Row() {
          Column({ space: 2 }) {
            Text($r('app.string.repo_create_add_readme'))
              .fontSize($r('app.float.body_font_size'))
              .fontColor($r('app.color.text_primary'))
            Text($r('app.string.repo_create_readme_hint'))
              .fontSize($r('app.float.caption_font_size'))
              .fontColor($r('app.color.text_secondary'))
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          .onClick((): void => this.onReadmeChange(!this.addReadme))
          Toggle({ type: ToggleType.Switch, isOn: this.addReadme })
            .selectedColor($r('app.color.link_blue'))
            .onChange((on: boolean): void => this.onReadmeChange(on))
        }
        .width('100%')
        .height(76)
        .padding({ left: 16, right: 16 })
        .alignItems(VerticalAlign.Center)

        // Add .gitignore（整行可点，行尾回显模板名）
        Row() {
          Column({ space: 2 }) {
            Text($r('app.string.repo_create_add_gitignore'))
              .fontSize($r('app.float.body_font_size'))
              .fontColor($r('app.color.text_primary'))
            Text($r('app.string.repo_create_gitignore_hint'))
              .fontSize($r('app.float.caption_font_size'))
              .fontColor($r('app.color.text_secondary'))
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          if (this.gitignoreName === '') {
            Text($r('app.string.repo_create_select'))
              .fontSize($r('app.float.body_font_size'))
              .fontWeight(600)
              .fontColor($r('app.color.link_blue'))
              .textCase(TextCase.UpperCase)
          } else {
            Text(this.gitignoreName)
              .fontSize($r('app.float.body_font_size'))
              .fontColor($r('app.color.text_secondary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
        }
        .width('100%')
        .height(76)
        .padding({ left: 16, right: 16 })
        .alignItems(VerticalAlign.Center)
        .onClick((): void => this.onPickGitignore())

        // Add license（整行可点，行尾回显 spdx）
        Row() {
          Column({ space: 2 }) {
            Text($r('app.string.repo_create_add_license'))
              .fontSize($r('app.float.body_font_size'))
              .fontColor($r('app.color.text_primary'))
            Text($r('app.string.repo_create_license_hint'))
              .fontSize($r('app.float.caption_font_size'))
              .fontColor($r('app.color.text_secondary'))
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          if (this.licenseName === '') {
            Text($r('app.string.repo_create_select'))
              .fontSize($r('app.float.body_font_size'))
              .fontWeight(600)
              .fontColor($r('app.color.link_blue'))
              .textCase(TextCase.UpperCase)
          } else {
            Text(this.licenseName)
              .fontSize($r('app.float.body_font_size'))
              .fontColor($r('app.color.text_secondary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
        }
        .width('100%')
        .height(76)
        .padding({ left: 16, right: 16 })
        .alignItems(VerticalAlign.Center)
        .onClick((): void => this.onPickLicense())
      }
    }
    .width('100%')
    .height('100%')
  }
}
