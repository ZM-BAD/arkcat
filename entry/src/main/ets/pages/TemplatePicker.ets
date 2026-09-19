/**
 * Choose Template 选模板页（Spec 043，官方截图驱动 2026-09-19）：
 * Choose a repository 选中「有官方模板」的仓库后先入本页——
 * 行 = 模板 name（黑）+ about（灰），行数随 issueTemplates 自适应；固定尾行 No template；
 * 仓库有安全政策时追加独立分组 Security 行（外链图标 → 应用内浏览器打开 securityPolicyUrl）。
 * 选模板 → 压栈 Create Issue 表单并由模板预填正文/标题、自动带 Assignee/Label（模板 YAML 无里程碑/项目）。
 */
import { OctIcon } from '../components/OctIcon';
import { PageShadowBar } from '../components/PageShadowBar';
import { StateView } from '../components/StateView';
import { RepoSubService } from '../services/RepoSubService';
import { friendlyError } from '../services/GitHttpClient';
import { IssueFormTemplate, IssueTemplateItem, IssueTemplateExtras, RepoFormPage, TemplateContactLink } from '../models/RepoSubModels';

@ComponentV2
export struct TemplatePickerView {
  @Param token: string = '';
  @Param pathStack: NavPathStack = new NavPathStack();
  @Param tpOwner: string = '';
  @Param tpName: string = '';
  @Local templates: IssueTemplateItem[] = [];
  /** issue forms（.yml 表单，GraphQL 不返回；移动端外链跳网页填写） */
  @Local forms: IssueFormTemplate[] = [];
  /** config.yml 联系链接（外链） */
  @Local contactLinks: TemplateContactLink[] = [];
  @Local securityUrl: string = '';
  @Local loading: boolean = true;
  @Local errorMsg: string = '';
  /** 滚动顶部阴影 */
  @Local scrollShadow: boolean = false;

  aboutToAppear(): void {
    this.load();
  }

  private load(): void {
    this.loading = true;
    this.errorMsg = '';
    RepoSubService.fetchRepoForm(this.token, this.tpOwner, this.tpName)
      .then((page: RepoFormPage) => {
        this.templates = page.templates;
        this.securityUrl = page.securityPolicyUrl;
        // 表单/联系链接走 REST contents（.github/ISSUE_TEMPLATE 目录），失败按空处理不阻断
        return RepoSubService.fetchIssueTemplateExtras(this.token, this.tpOwner, this.tpName);
      })
      .then((extras: IssueTemplateExtras) => {
        this.forms = extras.forms;
        this.contactLinks = extras.contactLinks;
        this.loading = false;
      })
      .catch((e: Error) => {
        this.errorMsg = friendlyError(this.getUIContext(), e);
        this.loading = false;
      });
  }

  /** 选模板进表单（模板名走路由第 5 段，表单自行拉元数据回填正文/标题/属性） */
  private openForm(templateName: string): void {
    this.pathStack.pushPathByName('issueForm', `${this.tpOwner}|${this.tpName}|new|0|${templateName}`);
  }

  /** 外链（联系链接 / issue form 网页填写）进应用内浏览器 */
  private openExternal(title: string, url: string): void {
    if (url !== '') {
      this.pathStack.pushPathByName('inAppBrowser', `${title}|${url}`);
    }
  }

  /** Security 行：应用内浏览器打开安全政策页 */
  private openSecurityPolicy(): void {
    if (this.securityUrl !== '') {
      this.pathStack.pushPathByName('inAppBrowser', `Security policy|${this.securityUrl}`);
    }
  }

  /** 模板行内容（name 黑 + about 灰；@Builder 不收函数参数，动作由各行内联） */
  @Builder
  rowContent(title: ResourceStr, desc: ResourceStr) {
    Column({ space: 4 }) {
      Text(title)
        .fontSize($r('app.float.body_font_size'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
      Text(desc)
        .fontSize($r('app.float.body_font_size'))
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  build() {
    Column() {
      // 两行头部（官方）：灰小字 owner/name + 粗体 Choose Template
      Row({ space: 4 }) {
        Stack() {
          OctIcon({ res: $r('app.media.oct_arrow_left_24'), iconSize: 20, iconColor: $r('app.color.text_primary') })
        }
        .width(44)
        .height(44)
        .accessibilityDescription($r('app.string.a11y_back'))
        .focusable(true)
        .onClick((): void => {
          this.pathStack.pop();
        })
        Column({ space: 2 }) {
          Text(`${this.tpOwner}/${this.tpName}`)
            .fontSize($r('app.float.caption_font_size'))
            .fontColor($r('app.color.text_secondary'))
          Text($r('app.string.template_picker_title'))
            .fontSize($r('app.float.title_font_size'))
            .fontWeight(600)
            .fontColor($r('app.color.text_primary'))
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        .margin({ left: 4 })
      }
      .width('100%')
      .height(56)
      .padding({ left: 4, right: 4 })

      PageShadowBar({ show: this.scrollShadow })

      Scroll() {
        Column() {
          if (this.loading || this.errorMsg !== '') {
            StateView({ loading: this.loading, error: this.errorMsg, onRetry: () => this.load() })
          } else {
            // 分组一（白卡）：模板行（随 issueTemplates 自适应）+ 固定 No template 行
            Column() {
              ForEach(this.templates, (t: IssueTemplateItem) => {
                Column() {
                  this.rowContent(t.name, t.about)
                }
                .width('100%')
                .padding({ left: 16, right: 16, top: 14, bottom: 14 })
                .onClick((): void => this.openForm(t.name))
              }, (t: IssueTemplateItem) => t.name)
              Column() {
                this.rowContent($r('app.string.template_none'), $r('app.string.template_none_desc'))
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 14, bottom: 14 })
              .onClick((): void => this.openForm(''))
            }
            .width('100%')
            .backgroundColor($r('app.color.card_background'))
            .padding({ top: 6, bottom: 6 })

            // 分组二（白卡，config.yml 有 contact_links 才显示）：联系链接行，右侧外链图标
            if (this.contactLinks.length > 0) {
              Column() {
                ForEach(this.contactLinks, (c: TemplateContactLink) => {
                  Row({ space: 12 }) {
                    // 行内容包一层 layoutWeight(1)：rowContent 内部是 width('100%')，否则图标被挤出屏外
                    Column() {
                      this.rowContent(c.name, c.about)
                    }
                    .layoutWeight(1)
                    .alignItems(HorizontalAlign.Start)
                    OctIcon({
                      res: $r('app.media.oct_link_external_16'), iconSize: 20,
                      iconColor: $r('app.color.text_secondary')
                    })
                  }
                  .width('100%')
                  .padding({ left: 16, right: 16, top: 14, bottom: 14 })
                  .alignItems(VerticalAlign.Top)
                  .onClick((): void => this.openExternal(c.name, c.url))
                }, (c: TemplateContactLink) => c.name)
              }
              .width('100%')
              .backgroundColor($r('app.color.card_background'))
              .padding({ top: 6, bottom: 6 })
              .margin({ top: 8 })
            }

            // 分组三（白卡，issue forms 才显示）：.yml 表单移动端不能原生填 → 外链跳网页（官方同款）
            if (this.forms.length > 0) {
              Column() {
                ForEach(this.forms, (f: IssueFormTemplate) => {
                  Row({ space: 12 }) {
                    Column() {
                      this.rowContent(f.name, f.description)
                    }
                    .layoutWeight(1)
                    .alignItems(HorizontalAlign.Start)
                    OctIcon({
                      res: $r('app.media.oct_link_external_16'), iconSize: 20,
                      iconColor: $r('app.color.text_secondary')
                    })
                  }
                  .width('100%')
                  .padding({ left: 16, right: 16, top: 14, bottom: 14 })
                  .alignItems(VerticalAlign.Top)
                  .onClick((): void => this.openExternal(f.name,
                    `https://github.com/${this.tpOwner}/${this.tpName}/issues/new?template=${f.filename}`))
                }, (f: IssueFormTemplate) => f.filename)
              }
              .width('100%')
              .backgroundColor($r('app.color.card_background'))
              .padding({ top: 6, bottom: 6 })
              .margin({ top: 8 })
            }

            // 分组四（白卡，有安全政策才显示）：Security 行 + 右侧外链图标
            if (this.securityUrl !== '') {
              Row() {
                Column({ space: 4 }) {
                  Text($r('app.string.template_security'))
                    .fontSize($r('app.float.body_font_size'))
                    .fontWeight(FontWeight.Medium)
                    .fontColor($r('app.color.text_primary'))
                  Text($r('app.string.template_security_desc'))
                    .fontSize($r('app.float.body_font_size'))
                    .fontColor($r('app.color.text_secondary'))
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)

                OctIcon({
                  res: $r('app.media.oct_link_external_16'), iconSize: 20,
                  iconColor: $r('app.color.text_secondary')
                })
              }
              .width('100%')
              .backgroundColor($r('app.color.card_background'))
              .padding({ left: 16, right: 16, top: 14, bottom: 14 })
              .margin({ top: 8 })
              .alignItems(VerticalAlign.Top)
              .onClick((): void => this.openSecurityPolicy())
            }
          }
        }
        .width('100%')
        .padding({ top: 8, bottom: 24 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
      .onScroll((_x: number, y: number): void => {
        this.scrollShadow = y > 0.001;
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_page'))
  }
}
