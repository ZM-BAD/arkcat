/**
 * Edit My Work 页（Spec 016）：Home My Work 条目编辑。
 * 复选框控制显示/隐藏，长按整行拖拽排序；SAVE 持久化（Preferences）后 Home 立即反映。
 */
import { promptAction } from '@kit.ArkUI';
import { OctIcon } from '../components/OctIcon';
import { WorkSection, WorkConfigStore, defaultWorkSections } from '../utils/WorkConfig';
import { resText } from '../utils/I18n';

/** 条目元信息（图标/色/文案/路由 与 Home 013/024 保持一致） */
interface WorkEntryMeta {
  iconRes: Resource;
  color: string;
  label: Resource;
}

@ComponentV2
export struct EditMyWorkView {
  @Param pathStack: NavPathStack = new NavPathStack();
  @Param onSaved: () => void = () => {};
  /** 编辑快照：返回不保存；SAVE 时写回 store */
  @Local snapshot: WorkSection[] = defaultWorkSections();
  private dragFrom: number = -1;

  aboutToAppear(): void {
    WorkConfigStore.load(this.getUIContext().getHostContext())
      .then(() => {
        this.snapshot = WorkConfigStore.instance.sections.slice();
      });
  }

  private stringOf(res: Resource): string {
    return resText(this.getUIContext(), res);
  }

  private meta(id: string): WorkEntryMeta {
    switch (id) {
      case 'prs':
        return { iconRes: $r('app.media.oct_git_pull_request_16'), color: '#3C78D8', label: $r('app.string.home_work_pull_requests') };
      case 'discussions':
        return { iconRes: $r('app.media.oct_comment_discussion_16'), color: '#8250DF', label: $r('app.string.home_work_discussions') };
      case 'projects':
        return { iconRes: $r('app.media.oct_project_16'), color: '#57606A', label: $r('app.string.home_work_projects') };
      case 'topRepos':
        return { iconRes: $r('app.media.oct_repo_16'), color: '#24292F', label: $r('app.string.home_work_top_repos') };
      case 'orgs':
        return { iconRes: $r('app.media.oct_organization_16'), color: '#E87B2E', label: $r('app.string.home_work_organizations') };
      case 'starred':
        return { iconRes: $r('app.media.oct_star_fill_16'), color: '#E3B341', label: $r('app.string.home_work_starred') };
      default:
        return { iconRes: $r('app.media.oct_issue_opened_16'), color: '#2DA44E', label: $r('app.string.home_work_issues') };
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
      Toggle({ type: ToggleType.Checkbox, isOn: item.visible })
        .selectedColor('#0969DA')
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
      .width(34)
      .height(34)
      .backgroundColor(this.meta(item.id).color)
      .borderRadius(8)
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
.onClick((): void => {
            this.pathStack.pop();
          })
        Text($r('app.string.edit_work_title'))
          .fontSize($r('app.float.title_font_size'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
        Text($r('app.string.edit_work_save'))
          .fontSize($r('app.float.body_font_size'))
          .fontWeight(FontWeight.Medium)
          .fontColor('#0969DA')
          .padding(6)
          .onClick(() => this.save())
        Stack() {
  OctIcon({
          res: $r('app.media.oct_kebab_horizontal_16'),
          iconSize: 18,
          iconColor: $r('app.color.text_secondary')
  })
}
.onClick((): void => {
            promptAction.showToast({ message: $r('app.string.home_feature_coming') });
          })
          .padding(6)
      }
      .width('100%')
      .height(48)
      .padding({ left: 16, right: 12 })

      List() {
        ForEach(this.snapshot, (item: WorkSection, index: number) => {
          ListItem() {
            this.workRow(item)
          }
          .borderRadius(8)
          .backgroundColor($r('app.color.card_background'))
          .margin({ bottom: 4 })
        }, (item: WorkSection) => item.id)
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
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_page'))
  }
}
