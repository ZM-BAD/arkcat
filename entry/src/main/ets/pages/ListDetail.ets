/**
 * 列表详情页（Spec 023）：返回 + 竖三点（Edit/Delete）+ 归属人/名称/描述/计数 + 成员仓库卡片。
 * Edit 复用 CreateList 编辑模式（editListId）；Delete 走确认弹窗 + deleteUserList。
 */
import { promptAction } from '@kit.ArkUI';
import { OctIcon } from '../components/OctIcon';
import { PageShadowBar } from '../components/PageShadowBar';
import { WorkListDetail, WorkStarredRepoItem } from '../models/WorkModels';
import { WorkService } from '../services/WorkService';
import { StateView } from '../components/StateView';
import { compactCount } from '../utils/Format';
import { resText } from '../utils/I18n';

@ComponentV2
export struct ListDetailView {
  @Param token: string = '';
  @Param pathStack: NavPathStack = new NavPathStack();
  @Param listId: string = '';
  /** 回页刷新信号（Edit 页 pop 回时自增，@Monitor 触发重取） */
  @Param listTick: number = 0;
  @Local detail: WorkListDetail | null = null;
  @Local loading: boolean = true;
  @Local errorMsg: string = '';
  /** 滚动顶部阴影（滚动中显示、回顶消失） */
  @Local scrollShadow: boolean = false;

  @Monitor('listTick')
  onTickChanged(): void {
    this.refresh();
  }

  /** listId 晚于 aboutToAppear 到达（onReady）→ 变化即首载（review A6：不再依赖首显 tick） */
  @Monitor('listId')
  onListIdChanged(): void {
    this.refresh();
  }

  aboutToAppear(): void {
    this.refresh();
  }

  private stringOf(res: Resource): string {
    return resText(this.getUIContext(), res);
  }

  private refresh(): void {
    if (this.listId === '') {
      return;
    }
    this.loading = true;
    this.errorMsg = '';
    WorkService.fetchListDetail(this.token, this.listId)
      .then((d: WorkListDetail) => {
        this.detail = d;
        this.loading = false;
      })
      .catch((e: Error) => {
        this.errorMsg = e.message;
        this.loading = false;
      });
  }

  /** 删除确认（官方：Delete list? + 仓库保持星标说明 + CANCEL/OK） */
  private confirmDelete(): void {
    this.getUIContext().showAlertDialog({
      title: this.stringOf($r('app.string.list_detail_delete_title')),
      message: this.stringOf($r('app.string.list_detail_delete_message')),
      autoCancel: true,
      buttons: [
        {
          value: this.stringOf($r('app.string.list_detail_cancel')),
          action: (): void => {
          }
        },
        {
          style: DialogButtonStyle.HIGHLIGHT,
          value: this.stringOf($r('app.string.list_detail_ok')),
          action: (): void => {
            WorkService.deleteUserList(this.token, this.listId)
              .then(() => {
                promptAction.showToast({ message: $r('app.string.list_deleted_toast') });
                this.pathStack.pop();
              })
              .catch((e: Error) => {
                promptAction.showToast({ message: e.message });
              });
          }
        }
      ]
    });
  }

  /** 明细仓库行（与 Starred 卡片一致，无 ⋯：列表内卡片不提供取消勾选入口） */
  @Builder
  repoRow(repo: WorkStarredRepoItem) {
    Column({ space: 6 }) {
      Row({ space: 8 }) {
        if (repo.ownerAvatar !== '') {
          Image(repo.ownerAvatar)
            .width(18)
            .height(18)
            .borderRadius(9)
            .backgroundColor($r('app.color.heat_empty'))
        }
        Text(repo.ownerLogin)
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
      }
      .width('100%')

      Text(repo.name)
        .fontSize($r('app.float.body_font_size'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')

      if (repo.description !== '') {
        Text(repo.description)
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_secondary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }

      Row({ space: 8 }) {
        OctIcon({ res: $r('app.media.oct_star_fill_16'), iconSize: 12, iconColor: $r('app.color.star_gold') })
        Text(compactCount(repo.stargazerCount))
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_primary'))
        if (repo.language !== '') {
          Text('●')
            .fontSize(12)
            .fontColor(repo.languageColor !== '' ? repo.languageColor : $r('app.color.text_secondary'))
          Text(repo.language)
            .fontSize($r('app.float.caption_font_size'))
            .fontColor($r('app.color.text_secondary'))
        }
      }
      .width('100%')
    }
    .padding($r('app.float.card_padding'))
    .borderRadius($r('app.float.card_radius'))
    .backgroundColor($r('app.color.card_background'))
    .width('100%')
    .margin({ bottom: 8 })
    .onClick(() => {
      this.pathStack.pushPathByName('repoDetail', `${repo.ownerLogin}/${repo.name}`);
    })
  }

  build() {
    Column() {
      Row() {
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
        Blank()
        // 竖三点：Edit / Delete（官方 kebab-vertical = kebab_horizontal rotate90）
        Stack() {
          OctIcon({
            res: $r('app.media.oct_kebab_horizontal_16'),
            iconSize: 18,
            iconColor: $r('app.color.link_blue')
          })
            .rotate({ angle: 90 })
        }
        .width(44)
        .height(44)
        .accessibilityDescription($r('app.string.a11y_more'))
        .focusable(true)
        .bindMenu([
          {
            value: $r('app.string.list_detail_edit'),
            action: (): void => this.pathStack.pushPathByName('createList', this.listId)
          },
          {
            value: $r('app.string.list_detail_delete'),
            action: (): void => this.confirmDelete()
          }
        ])
        .padding(6)
      }
      .width('100%')
      .height(56)
      .padding({ left: 0, right: 0 })

      PageShadowBar({ show: this.scrollShadow })

      Scroll() {
        Column({ space: 8 }) {
          if (this.detail !== null) {
            // 归属人 + 大标题 + 描述 + 仓库计数（官方布局）
            Row({ space: 8 }) {
              Image(this.detail.viewerAvatar)
                .width(18)
                .height(18)
                .borderRadius(9)
                .backgroundColor($r('app.color.heat_empty'))
              Text(this.detail.viewerLogin)
                .fontSize($r('app.float.caption_font_size'))
                .fontColor($r('app.color.text_secondary'))
              Blank()
            }
            .width('100%')

            Text(this.detail.name)
              .fontSize($r('app.float.title_font_size'))
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')

            if (this.detail.description !== '') {
              Text(this.detail.description)
                .fontSize($r('app.float.caption_font_size'))
                .fontColor($r('app.color.text_primary'))
                .width('100%')
            }

            Row({ space: 8 }) {
              OctIcon({ res: $r('app.media.oct_repo_16'), iconSize: 14, iconColor: $r('app.color.text_secondary') })
              Text(`${this.detail.itemCount}`)
                .fontSize($r('app.float.caption_font_size'))
                .fontColor($r('app.color.text_secondary'))
            }
            .width('100%')
            .margin({ top: 4, bottom: 8 })

            ForEach(this.detail.repos, (repo: WorkStarredRepoItem) => {
              this.repoRow(repo)
            }, (repo: WorkStarredRepoItem) => repo.id)
          } else {
            StateView({
              loading: this.loading,
              error: this.errorMsg,
              onRetry: () => this.refresh()
            })
          }
        }
        .padding({ left: 16, right: 16, bottom: 16 })
        .width('100%')
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
      .onScroll((_x: number, y: number): void => { this.scrollShadow = y > 0.001; })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_page'))
  }
}
