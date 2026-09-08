/**
 * 账号管理页（Spec 049a，官方 2026-09 三图对齐）：
 * 浏览态 = 账号行（蓝勾当前账号）+ ADD ACCOUNT；
 * 编辑态（EDIT → DONE）= 当前勾变浅、行内红色登出图标 + 页尾 SIGN OUT ALL ACCOUNTS + ADD ACCOUNT 隐藏。
 * 行样式为官方平铺+分隔线（非项目圆角卡片行）。
 */
import { common } from '@kit.AbilityKit';
import { AccountInfo, AccountStore } from '../services/AccountStore';
import { OctIcon } from '../components/OctIcon';
import { resText } from '../utils/I18n';

@ComponentV2
export struct AccountsView {
  @Param pathStack: NavPathStack = new NavPathStack();
  @Param accounts: AccountInfo[] = [];
  @Param currentLogin: string = '';
  @Event onAddAccount: () => void = () => {};
  @Event onSwitchAccount: (login: string) => void = (login: string) => {};
  /** 移除/改名等结构变更后回调：Index 重新加载账号列表与当前账号 */
  @Event onAccountChanged: () => void = () => {};

  @Local editMode: boolean = false;

  build() {
    Column() {
      this.appBar()
      Scroll() {
        Column() {
          Column() {
            ForEach(this.accounts, (acc: AccountInfo) => {
              this.accountRow(acc)
            }, (acc: AccountInfo) => `${acc.login}_${acc.addedAt}`)
            if (!this.editMode) {
              this.addRow()
            }
          }
          .width('100%')
          .backgroundColor($r('app.color.card_background'))

          if (this.editMode) {
            this.signOutAllRow()
          }
        }
        .width('100%')
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_page'))
  }

  /** 自绘 AppBar：返回 + Accounts + 右上 EDIT/DONE 文字按钮（官方样式） */
  @Builder
  appBar() {
    Row() {
      Stack() {
        OctIcon({ res: $r('app.media.oct_arrow_left_24'), iconSize: 20, iconColor: $r('app.color.text_primary') })
      }
      .width(44)
      .height(44)
      .onClick(() => {
        this.pathStack.pop();
      })

      Text($r('app.string.settings_accounts'))
        .fontSize($r('app.float.title_font_size'))
        .fontWeight(600)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)

      Text(this.editMode ? $r('app.string.accounts_done') : $r('app.string.accounts_edit'))
        .fontSize(16)
        .fontWeight(500)
        .fontColor($r('app.color.link_blue'))
        .textAlign(TextAlign.End)
        .width(60)
        .height(44)
        .padding({ right: 4 })
        .onClick(() => {
          this.editMode = !this.editMode;
        })
    }
    .width('100%')
    .height(56)
    .padding({ left: 4, right: 4 })
  }

  /** 账号行：头像+login/name 双行+当前勾（编辑态置灰）/编辑态红色登出（官方平铺行+分隔线） */
  @Builder
  accountRow(acc: AccountInfo) {
    Column() {
      Row({ space: 12 }) {
        Image(`https://github.com/${acc.login}.png`)
          .width(48)
          .height(48)
          .borderRadius(24)
          .backgroundColor($r('app.color.heat_empty'))
        Column({ space: 2 }) {
          Text(acc.login !== '' ? acc.login : this.stringOf($r('app.string.accounts_unverified')))
            .fontSize($r('app.float.body_font_size'))
            .fontWeight(500)
            .fontColor($r('app.color.text_primary'))
          if (this.subtitle(acc) !== '') {
            Text(this.subtitle(acc))
              .fontSize($r('app.float.caption_font_size'))
              .fontColor($r('app.color.text_secondary'))
          }
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        if (this.editMode) {
          // 编辑态当前账号勾：置灰（半透明）且不可点，仅作标识（官方编辑态样式）
          if (acc.login === this.currentLogin) {
            OctIcon({ res: $r('app.media.oct_check_circle_fill_16'), iconSize: 22, iconColor: $r('app.color.link_blue') })
              .opacity(0.4)
          }
          Stack() {
            OctIcon({ res: $r('app.media.oct_sign_out_16'), iconSize: 16, iconColor: $r('app.color.badge_red') })
          }
          .width(44)
          .height(44)
          .onClick(() => {
            this.confirmRemove(acc);
          })
        } else if (acc.login === this.currentLogin) {
          OctIcon({ res: $r('app.media.oct_check_circle_fill_16'), iconSize: 22, iconColor: $r('app.color.link_blue') })
        }
      }
      .width('100%')
      .padding({ left: 16, right: 8 })
      .onClick(() => {
        // 浏览态点击非当前账号行 = 切换（官方行为）
        if (this.editMode || acc.login === this.currentLogin) {
          return;
        }
        this.onSwitchAccount(acc.login);
      })

      Divider()
        .strokeWidth(0.5)
        .color($r('app.color.divider'))
        .margin({ left: 16 })
    }
    .width('100%')
    .padding({ top: 10, bottom: 10 })
  }

  /** ADD ACCOUNT 行（浏览态）：蓝 + 图标 + 全大写蓝字（官方样式） */
  @Builder
  addRow() {
    Column() {
      Row({ space: 12 }) {
        OctIcon({ res: $r('app.media.oct_plus_24'), iconSize: 18, iconColor: $r('app.color.link_blue') })
        Text($r('app.string.accounts_add'))
          .fontSize(16)
          .fontWeight(500)
          .fontColor($r('app.color.link_blue'))
        Blank()
      }
      .width('100%')
      .height(48)
      .padding({ left: 16, right: 16 })
      .onClick(() => {
        this.onAddAccount();
      })
    }
    .width('100%')
  }

  /** SIGN OUT ALL ACCOUNTS 行（编辑态页尾，官方红色行） */
  @Builder
  signOutAllRow() {
    Column() {
      Row({ space: 12 }) {
        OctIcon({ res: $r('app.media.oct_sign_out_16'), iconSize: 16, iconColor: $r('app.color.badge_red') })
        Text($r('app.string.accounts_sign_out_all'))
          .fontSize(16)
          .fontWeight(600)
          .fontColor($r('app.color.badge_red'))
        Blank()
      }
      .width('100%')
      .height(48)
      .padding({ left: 16, right: 16 })
      .onClick(() => {
        this.confirmRemoveAll();
      })
    }
    .width('100%')
    .backgroundColor($r('app.color.card_background'))
    .margin({ top: 12 })
  }

  private subtitle(acc: AccountInfo): string {
    return acc.name;
  }

  /** 移除单账号确认（编辑态红色登出图标 → 官方 Sign Out = remove account 语义） */
  private confirmRemove(acc: AccountInfo): void {
    const ui = this.getUIContext();
    ui.getPromptAction().showDialog(
      {
        title: $r('app.string.accounts_remove_title'),
        message: resText(ui, $r('app.string.accounts_remove_message'), acc.login),
        buttons: [
          {
            text: resText(ui, $r('app.string.settings_cancel')),
            color: $r('app.color.text_secondary')
          },
          {
            text: resText(ui, $r('app.string.accounts_remove_confirm')),
            color: $r('app.color.badge_red')
          }
        ]
      },
      (err, data) => {
        if (err) {
          return;
        }
        if (data.index === 1) {
          this.removeAccount(acc.login);
        }
      });
  }

  private async removeAccount(login: string): Promise<void> {
    const ctx = this.getUIContext().getHostContext() as common.Context | undefined;
    await AccountStore.removeAccount(ctx, login);
    this.onAccountChanged();
  }

  /** 全部登出确认（官方 SIGN OUT ALL ACCOUNTS 红色行） */
  private confirmRemoveAll(): void {
    const ui = this.getUIContext();
    ui.getPromptAction().showDialog(
      {
        title: $r('app.string.accounts_sign_out_all'),
        message: $r('app.string.accounts_sign_out_all_message'),
        buttons: [
          {
            text: resText(ui, $r('app.string.settings_cancel')),
            color: $r('app.color.text_secondary')
          },
          {
            text: resText(ui, $r('app.string.accounts_remove_confirm')),
            color: $r('app.color.badge_red')
          }
        ]
      },
      (err, data) => {
        if (err) {
          return;
        }
        if (data.index === 1) {
          this.removeAll();
        }
      });
  }

  private async removeAll(): Promise<void> {
    const ctx = this.getUIContext().getHostContext() as common.Context | undefined;
    await AccountStore.removeAll(ctx);
    this.onAccountChanged();
  }

  /** 资源 → 当前语言纯文案 */
  private stringOf(res: Resource): string {
    return resText(this.getUIContext(), res);
  }
}
