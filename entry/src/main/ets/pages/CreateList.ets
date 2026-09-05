/**
 * Create list 页（复刻官方创建/编辑列表页）：自绘头部（返回 + 标题 + 操作），
 * Name/Description 表单；新建走 createUserList，编辑（editListId 非空）走 updateUserList 并预填。
 */
import { promptAction } from '@kit.ArkUI';
import { OctIcon } from '../components/OctIcon';
import { WorkService } from '../services/WorkService';
import { WorkUserList } from '../models/WorkModels';
import { resText } from '../utils/I18n';

@ComponentV2
export struct CreateListView {
  @Param token: string = '';
  @Param pathStack: NavPathStack = new NavPathStack();
  /** 编辑模式：非空时为被编辑列表的 GraphQL id */
  @Param editListId: string = '';
  @Local name: string = '';
  @Local description: string = '';
  @Local submitting: boolean = false;
  /** 已预填的列表 id（防止 aboutToAppear 与 @Monitor 双触发重复拉取） */
  @Local prefilledFor: string = '';

  /** 编辑模式预填：按列表 id 拉取名称/描述（@Monitor 兜底参数晚到的时序） */
  private prefill(): void {
    if (this.editListId === '' || this.prefilledFor === this.editListId) {
      return;
    }
    this.prefilledFor = this.editListId;
    WorkService.fetchUserLists(this.token)
      .then((lists: WorkUserList[]) => {
        for (const l of lists) {
          if (l.id === this.editListId) {
            this.name = l.name;
            this.description = l.description;
            break;
          }
        }
      })
      .catch(() => {
        // 预填失败保持空白，用户可手动输入
      });
  }

  @Monitor('editListId')
  onEditListChanged(): void {
    this.prefill();
  }

  aboutToAppear(): void {
    this.prefill();
    // 进入页面自动聚焦 Name（官方交互）：动态插入后须下一帧再获焦
    setTimeout((): void => {
      this.getUIContext().getFocusController().requestFocus('create_list_name');
    }, 60);
  }

  private stringOf(res: Resource): string {
    return resText(this.getUIContext(), res);
  }

  /** 提交创建：空名客户端拦截，其余错误以 toast 呈现 */
  private submit(): void {
    if (this.submitting) {
      return;
    }
    const trimmedName = this.name.trim();
    if (trimmedName === '') {
      promptAction.showToast({ message: $r('app.string.create_list_name_required') });
      return;
    }
    this.submitting = true;
    if (this.editListId !== '') {
      WorkService.updateUserList(this.token, this.editListId, trimmedName, this.description.trim())
        .then(() => {
          promptAction.showToast({ message: $r('app.string.create_list_success') });
          this.pathStack.pop();
        })
        .catch((e: Error) => {
          promptAction.showToast({ message: e.message });
          this.submitting = false;
        });
      return;
    }
    WorkService.createList(this.token, trimmedName, this.description.trim())
      .then(() => {
        promptAction.showToast({ message: $r('app.string.create_list_success') });
        this.pathStack.pop();
      })
      .catch((e: Error) => {
        promptAction.showToast({ message: e.message });
        this.submitting = false;
      });
  }

  build() {
    Column() {
      // 自绘头部：返回 + 标题 + CREATE 操作（二级页规范，不设 .title()）
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
        Text(this.editListId !== ''
          ? $r('app.string.create_list_edit_title')
          : $r('app.string.create_list_title'))
          .fontSize($r('app.float.title_font_size'))
          .fontWeight(600)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
        Text(this.editListId !== ''
          ? $r('app.string.create_list_save_action')
          : $r('app.string.create_list_action'))
          .fontSize($r('app.float.sub_text_font_size'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.link_blue'))
          .padding(6)
          .responseRegion({ x: -6, y: -7, width: '130%', height: '147%' })
          .onClick(() => this.submit())
      }
      .width('100%')
      .height(56)

      Column({ space: 0 }) {
        Text($r('app.string.create_list_name_label'))
          .fontSize($r('app.float.sub_text_font_size'))
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
          .padding({ top: 12, bottom: 4 })
        TextInput({
          placeholder: this.stringOf($r('app.string.create_list_name_placeholder')),
          text: this.name
        })
          .id('create_list_name')
          .fontSize($r('app.float.menu_font_size'))
          .fontColor($r('app.color.text_primary'))
          .placeholderColor($r('app.color.text_secondary'))
          .caretColor($r('app.color.link_blue'))
          .backgroundColor(Color.Transparent)
          .onChange((v: string) => {
            this.name = v;
          })
        Text($r('app.string.create_list_desc_label'))
          .fontSize($r('app.float.sub_text_font_size'))
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
          .padding({ top: 24, bottom: 4 })
        TextInput({
          placeholder: this.stringOf($r('app.string.create_list_desc_placeholder')),
          text: this.description
        })
          .fontSize($r('app.float.menu_font_size'))
          .fontColor($r('app.color.text_primary'))
          .placeholderColor($r('app.color.text_secondary'))
          .caretColor($r('app.color.link_blue'))
          .backgroundColor(Color.Transparent)
          .onChange((v: string) => {
            this.description = v;
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_page'))
  }
}
