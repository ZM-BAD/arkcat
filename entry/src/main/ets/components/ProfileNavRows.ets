/**
 * Profile 导航入口组（Spec 035 + Spec 073 增补）：单卡片容器，一行一行展示
 * （Repositories/Organizations/Starred + Sponsoring/Projects——后两行 tap 为占位 toast，详情页后续立项）。
 */
import { promptAction } from '@kit.ArkUI';
import { OctIcon } from './OctIcon';

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

  /** 导航入口行（Spec 035）：彩块图标 + 标签 + 计数（行容器由 navRowsSection 提供） */
  @Builder
  navRow(iconRes: Resource, color: ResourceColor, labelRes: Resource, count: number, onClick: () => void) {
    Row({ space: 12 }) {
      Stack() {
        OctIcon({ res: iconRes, iconSize: 16, iconColor: Color.White })
      }
      .width(44)
      .height(44)
      .backgroundColor(color)
      .borderRadius(6)
      Text(labelRes)
        .fontSize($r('app.float.body_font_size'))
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
      Text(`${count}`)
        .fontSize($r('app.float.body_font_size'))
        .fontColor($r('app.color.text_secondary'))
    }
    .width('100%')
    .padding({ left: 10, right: 10, top: 6, bottom: 6 })
    .onClick(onClick)
  }

  @Builder
  navRowsSection() {
    Column() {
      this.navRow($r('app.media.oct_repo_16'), $r('app.color.text_secondary'), $r('app.string.profile_repositories'), this.repositoriesCount,
        () => this.pathStack.pushPathByName('repositoriesList', `${this.login}|user`))
      this.navRow($r('app.media.oct_organization_16'), $r('app.color.shortcut_orange_fg'), $r('app.string.profile_organizations'), this.orgCount,
        () => this.pathStack.pushPathByName('orgList', this.login))
      this.navRow($r('app.media.oct_star_16'), $r('app.color.star_gold'), $r('app.string.profile_starred'), this.starredCount,
        () => this.pathStack.pushPathByName('starred', this.login))
      // Spec 073：Sponsoring（粉块心形）/ Projects（灰块表格）——计数为 0 整行隐藏（走查定案）；
      // 详情页后续立项，tap 占位
      if (this.sponsoringCount > 0) {
        this.navRow($r('app.media.oct_heart_16'), $r('app.color.shortcut_pink_fg'), $r('app.string.profile_sponsoring'), this.sponsoringCount,
          () => promptAction.showToast({ message: $r('app.string.home_feature_coming') }))
      }
      if (this.projectsCount > 0) {
        this.navRow($r('app.media.oct_project_16'), $r('app.color.text_tertiary'), $r('app.string.home_work_projects'), this.projectsCount,
          () => promptAction.showToast({ message: $r('app.string.home_feature_coming') }))
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
