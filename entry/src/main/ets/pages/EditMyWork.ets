/**
 * Edit My Work 页（Spec 016）：Home My Work 条目编辑。
 * 复选框控制显示/隐藏，长按整行拖拽排序；SAVE 持久化（Preferences）后 Home 立即反映。
 */
import { promptAction } from '@kit.ArkUI';
import { OctIcon } from '../components/OctIcon';
import { PageShadowBar } from '../components/PageShadowBar';
import { WorkSection, WorkConfigStore, defaultWorkSections } from '../utils/WorkConfig';
import { resText } from '../utils/I18n';

/** 条目元信息（图标/色/文案/路由 与 Home 013/024 保持一致） */
interface WorkEntryMeta {
  iconRes: Resource;
  color: ResourceColor;
  label: Resource;
}

@ComponentV2
export struct EditMyWorkView {
  @Param pathStack: NavPathStack = new NavPathStack();
  @Param onSaved: () => void = () => {};
  /** 编辑快照：返回不保存；SAVE 时写回 store */
  @Local snapshot: WorkSection[] = defaultWorkSections();
  /** 持久化配置加载完成前不渲染列表（review D5：Checkbox select 仅创建时生效，早渲染会显示错误的默认勾选态） */
  @Local configLoaded: boolean = false;
  private dragFrom: number = -1;
  /** 滚动顶部阴影（滚动中显示、回顶消失） */
  @Local scrollShadow: boolean = false;

  aboutToAppear(): void {
    WorkConfigStore.load(this.getUIContext().getHostContext())
      .then(() => {
        this.snapshot = WorkConfigStore.instance.sections.slice();
        this.configLoaded = true;
      })
      .catch(() => {
        // 读取失败按默认配置渲染，避免页面空白
        this.configLoaded = true;
      });
  }

  private stringOf(res: Resource): string {
    return resText(this.getUIContext(), res);
  }

  private meta(id: string): WorkEntryMeta {
    switch (id) {
      case 'prs':
        return { iconRes: $r('app.media.oct_git_pull_request_16'), color: $r('app.color.link_blue'), label: $r('app.string.home_work_pull_requests') };
      case 'discussions':
        return { iconRes: $r('app.media.oct_comment_discussion_16'), color: $r('app.color.shortcut_purple_fg'), label: $r('app.string.home_work_discussions') };
      case 'projects':
        return { iconRes: $r('app.media.oct_table_16'), color: $r('app.color.text_secondary'), label: $r('app.string.home_work_projects') };
      case 'topRepos':
        // 与 Home 同一入口保持同色（白图标需深底；浅底上不可见）
        return { iconRes: $r('app.media.oct_repo_16'), color: $r('app.color.work_dark_bg'), label: $r('app.string.home_work_top_repos') };
      case 'orgs':
        return { iconRes: $r('app.media.oct_organization_16'), color: $r('app.color.shortcut_orange_fg'), label: $r('app.string.home_work_organizations') };
      case 'starred':
        return { iconRes: $r('app.media.oct_star_fill_16'), color: $r('app.color.star_gold'), label: $r('app.string.home_work_starred') };
      default:
        return { iconRes: $r('app.media.oct_issue_opened_16'), color: $r('app.color.success_text'), label: $r('app.string.home_work_issues') };
    }
  }

  private setVisible(index: number, isOn: boolean): void {
    const next: WorkSection[] = [];
    for (let i = 0; i < this.snapshot.length; i++) {
      const item = this.snapshot[i];
      next.push({ id: item.id, visible: i === index ? isOn : item.visible });
    }
    this.snapshot = next;
  }

  /** 拖拽排序：oldIndex 移到 newIndex */
  private move(from: number, to: number): void {
    if (from < 0 || from >= this.snapshot.length || to < 0 || to >= this.snapshot.length || from === to) {
      return;
    }
    const next = this.snapshot.slice();
    const moved = next[from];
    next.splice(from, 1);
    next.splice(to, 0, moved);
    this.snapshot = next;
  }

  private save(): void {
    WorkConfigStore.instance.sections = this.snapshot.slice();
    WorkConfigStore.save(this.getUIContext().getHostContext());
    this.onSaved();
    this.pathStack.pop();
  }

  @Builder
  workRow(item: WorkSection) {
    Row() {
      // 官方 App 为方形勾选框：Checkbox 走 ROUNDED_SQUARE 形状（Toggle 默认圆形）
      Checkbox()
        .shape(CheckBoxShape.ROUNDED_SQUARE)
        .selectedColor($r('app.color.link_blue'))
        .select(item.visible)
        .width(22)
        .height(22)
        .onChange((isOn: boolean) => {
          // ForEach 按 key 复用组件，item 引用可能是旧数组对象 → 按 id 定位
          const index = this.snapshot.findIndex((s: WorkSection): boolean => s.id === item.id);
          if (index >= 0) {
            this.setVisible(index, isOn);
          }
        })
      Stack() {
          OctIcon({ res: this.meta(item.id).iconRes, iconSize: 18, iconColor: Color.White })
      }
      .width(44)
      .height(44)
      .backgroundColor(this.meta(item.id).color)
      .borderRadius(6)
      .margin({ left: 12 })
      Text(this.meta(item.id).label)
        .fontSize($r('app.float.body_font_size'))
        .fontColor($r('app.color.text_primary'))
        .margin({ left: 12 })
        .layoutWeight(1)
      OctIcon({
        res: $r('app.media.oct_grabber_16'),
        iconSize: 18,
        iconColor: $r('app.color.text_secondary')
      })
        .padding({ left: 8, right: 8 })
    }
    .width('100%')
    .height(56)
    .alignItems(VerticalAlign.Center)
    .padding({ left: 12, right: 8 })
  }

  @Builder
  dragRow(index: number) {
    this.workRow(this.snapshot[index])
  }

  build() {
    Column() {
      Row({ space: 8 }) {
        Stack() {
  OctIcon({
          res: $r('app.media.oct_arrow_left_24'),
          iconSize: 20,
          iconColor: $r('app.color.text_primary')
  })
}
        .width(44)
        .height(44)
        .accessibilityDescription($r('app.string.a11y_back'))
        .focusable(true)
.onClick((): void => {
            this.pathStack.pop();
          })
        Text($r('app.string.edit_work_title'))
          .fontSize($r('app.float.title_font_size'))
          .fontWeight(600)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
        Text($r('app.string.edit_work_save'))
          .fontSize($r('app.float.body_font_size'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.link_blue'))
          .padding(6)
          .responseRegion({ x: -6, y: -7, width: '130%', height: '147%' })
          .onClick(() => this.save())
        Stack() {
  OctIcon({
          res: $r('app.media.oct_kebab_horizontal_16'),
          iconSize: 18,
          iconColor: $r('app.color.text_secondary')
  })
}
        .width(44)
        .height(44)
        .accessibilityDescription($r('app.string.a11y_more'))
        .focusable(true)
.onClick((): void => {
            promptAction.showToast({ message: $r('app.string.home_feature_coming') });
          })
          .padding(6)
      }
      .width('100%')
      .height(48)
      .padding({ left: 0, right: 0 })

      PageShadowBar({ show: this.scrollShadow })

      // 配置加载完成前不渲染（review D5），防止勾选框以默认态创建
      if (this.configLoaded) {
        List() {
          ForEach(this.snapshot, (item: WorkSection, index: number) => {
            ListItem() {
              this.workRow(item)
            }
            .borderRadius(6)
            .backgroundColor($r('app.color.card_background'))
            .margin({ bottom: 4 })
          }, (item: WorkSection) => `${item.id}-${item.visible ? 1 : 0}`)
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 16, right: 16, top: 8 })
        .scrollBar(BarState.Off)
        .onItemDragStart((event: ItemDragInfo, itemIndex: number) => {
          this.dragFrom = itemIndex;
          return this.dragRow(itemIndex);
        })
        .onItemDrop((event: ItemDragInfo, targetIndex: number) => {
          this.move(this.dragFrom, targetIndex);
          this.dragFrom = -1;
        })
        .onScroll((scrollOffset: number, _state: number): void => { this.scrollShadow = scrollOffset > 0.001; })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_page'))
  }
}
