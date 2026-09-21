/**
 * Profile 导航入口组（Spec 035 + Spec 073 增补）：单卡片容器，一行一行展示
 * （Repositories/Organizations/Starred + Sponsoring/Projects——后两行 tap 为占位 toast，详情页后续立项）。
 *
 * 行做成独立组件（@Param count）而非共用 @Builder：V2 里 @Builder 按值传的参数不参与依赖收集，
 * 计数值被复制成局部变量后就没有重算路径——数字冻结在首帧（Repositories 计数实测不刷新，2026-09-22）。
 * 组件化后计数的读取发生在子组件自身渲染闭包内（@Param），才有刷新链路（同 045 Bell 面板单选行的定案）。
 */
import { promptAction } from '@kit.ArkUI';
import { OctIcon } from './OctIcon';

/** 导航入口行（Spec 035）：彩块图标 + 标签 + 计数 */
@ComponentV2
struct ProfileNavRow {
  @Require @Param iconRes: Resource;
  @Param tintColor: ResourceColor = '';
  @Require @Param labelRes: Resource;
  @Param count: number = 0;
  @Event onTap: () => void = (): void => { };

  build() {
    Row({ space: 12 }) {
      Stack() {
        OctIcon({ res: this.iconRes, iconSize: 16, iconColor: Color.White })
      }
      .width(44)
      .height(44)
      .backgroundColor(this.tintColor)
      .borderRadius(6)
      Text(this.labelRes)
        .fontSize($r('app.float.body_font_size'))
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
      Text(`${this.count}`)
        .fontSize($r('app.float.body_font_size'))
        .fontColor($r('app.color.text_secondary'))
    }
    .width('100%')
    .padding({ left: 10, right: 10, top: 6, bottom: 6 })
    .onClick((): void => this.onTap())
  }
}

@ComponentV2
export struct ProfileNavRows {
  @Param login: string = '';
  @Param repositoriesCount: number = 0;
  @Param orgCount: number = 0;
  @Param starredCount: number = 0;
  /** Sponsoring 行计数（Spec 073）：sponsorshipsAsSponsor.totalCount */
  @Param sponsoringCount: number = 0;
  /** Projects 行计数（Spec 073）：projectsV2.totalCount */
  @Param projectsCount: number = 0;
  @Param pathStack: NavPathStack = new NavPathStack();

  @Builder
  navRowsSection() {
    Column() {
      ProfileNavRow({
        iconRes: $r('app.media.oct_repo_16'),
        tintColor: $r('app.color.text_secondary'),
        labelRes: $r('app.string.profile_repositories'),
        count: this.repositoriesCount,
        onTap: (): void => this.pathStack.pushPathByName('repositoriesList', `${this.login}|user`)
      })
      ProfileNavRow({
        iconRes: $r('app.media.oct_organization_16'),
        tintColor: $r('app.color.shortcut_orange_fg'),
        labelRes: $r('app.string.profile_organizations'),
        count: this.orgCount,
        onTap: (): void => this.pathStack.pushPathByName('orgList', this.login)
      })
      ProfileNavRow({
        iconRes: $r('app.media.oct_star_16'),
        tintColor: $r('app.color.star_gold'),
        labelRes: $r('app.string.profile_starred'),
        count: this.starredCount,
        onTap: (): void => this.pathStack.pushPathByName('starred', this.login)
      })
      // Spec 073：Sponsoring（粉块心形）/ Projects（灰块表格）——计数为 0 整行隐藏（走查定案）；
      // 详情页后续立项，tap 占位
      if (this.sponsoringCount > 0) {
        ProfileNavRow({
          iconRes: $r('app.media.oct_heart_16'),
          tintColor: $r('app.color.shortcut_pink_fg'),
          labelRes: $r('app.string.profile_sponsoring'),
          count: this.sponsoringCount,
          onTap: (): void => promptAction.showToast({ message: $r('app.string.home_feature_coming') })
        })
      }
      if (this.projectsCount > 0) {
        ProfileNavRow({
          iconRes: $r('app.media.oct_project_16'),
          tintColor: $r('app.color.text_tertiary'),
          labelRes: $r('app.string.home_work_projects'),
          count: this.projectsCount,
          onTap: (): void => promptAction.showToast({ message: $r('app.string.home_feature_coming') })
        })
      }
    }
    .padding({ top: 4, bottom: 4 })
    .borderRadius($r('app.float.card_radius'))
    .backgroundColor($r('app.color.card_background'))
    .width('100%')
  }

  build() {
    this.navRowsSection()
  }
}
