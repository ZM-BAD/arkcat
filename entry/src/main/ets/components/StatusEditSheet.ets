/**
 * Edit status 弹层（Spec 076）：emoji 选择框 + 状态文案输入（80 上限 + 剩余计数）+ Busy 开关
 * + Clear after... 行 + CLEAR STATUS。两个子弹层（Select an emoji / Select Expiration）复用
 * 同一个嵌套 bindSheet 按 sheetKind 分派（同组件多 bindSheet 只有最后一个生效，坑 2），
 * 内容槽一律直传单层构建函数（2026-09-22 事故口径）。弹层关闭即销毁，重开按当前状态回填。
 */
import { promptAction } from '@kit.ArkUI';
import { friendlyError } from '../services/GitHttpClient';
import { ProfileService } from '../services/ProfileService';
import { resText } from '../utils/I18n';
import { OctIcon } from './OctIcon';
import { StatusEmojiSheet } from './StatusEmojiSheet';
import {
  STATUS_EXPIRY_KEYS, STATUS_MESSAGE_MAX, UserStatus, expiryIsoOf, expiryKeyOf, statusRemainingCount
} from '../models/ProfileModels';

/** 子弹层 kind（sheetKind 分派） */
const SHEET_EMOJI = 'emoji';
const SHEET_EXPIRY = 'expiration';

/** 单选圆钮参数（按引用传递，勾选态随状态刷新） */
interface RadioState {
  selected: boolean;
}

@ComponentV2
export struct StatusEditSheet {
  @Param token: string = '';
  /** 打开时的当前状态（null = 未设置）：初值来源 */
  @Param status: UserStatus | null = null;
  /** 写入成功：壳外关弹层并重取主页 */
  @Event onSaved: () => void = (): void => { };
  /** ✕：关闭弹层并丢弃改动 */
  @Event onDismiss: () => void = (): void => { };

  @Local message: string = '';
  /** 提交值（原生字形 / `:shortcode:` 原样回传，未改动时保留用户既有形态） */
  @Local emoji: string = '';
  /** 选择框预览：Unicode 字形 / 自定义 emoji 图 */
  @Local emojiGlyph: string = '';
  @Local emojiImage: string = '';
  @Local busy: boolean = false;
  @Local expiryKey: string = 'never';
  /** 用户是否动过 Clear after 档位：没动过就原样回传既有到期时刻
   *  （changeUserStatus 省略 expiresAt 即清空，无法用「省略」表达「保持不变」） */
  @Local expiryTouched: boolean = false;
  @Local sheetKind: string = '';
  @Local saving: boolean = false;
  /** 文字钮点按态（灰底一闪；stateStyles+@Styles 在 V2 编译期被静默丢弃，2026-09-22 实测，改用 onTouch 显式切换） */
  @Local savePressed: boolean = false;
  @Local clearPressed: boolean = false;
  /** 打开瞬间的时刻：到期档回显与「有无改动」判定同源（避免秒级漂移） */
  private openedAt: number = 0;
  /** 打开时的原始到期时刻（未改动档位时原样回传，避免把外部设定的到期时间截断/顺延） */
  private originalExpiresAt: string = '';

  aboutToAppear(): void {
    this.openedAt = Date.now();
    const current = this.status;
    if (current === null) {
      return;
    }
    this.message = current.message;
    this.emoji = current.emojiRaw;
    this.emojiGlyph = current.emoji.text;
    this.emojiImage = current.emoji.image;
    this.busy = current.busy;
    this.originalExpiresAt = current.expiresAt;
    this.expiryKey = expiryKeyOf(current.expiresAt, this.openedAt);
  }

  /** N characters remaining（剩 1 走单数文案） */
  private counterText(): string {
    const remaining = statusRemainingCount(this.message);
    return resText(this.getUIContext(),
      remaining === 1 ? $r('app.string.status_character_remaining') : $r('app.string.status_characters_remaining'),
      `${remaining}`);
  }

  /** 档位 key → 文案资源（顺序取模型 STATUS_EXPIRY_KEYS） */
  private expiryLabel(key: string): Resource {
    if (key === 'in30m') {
      return $r('app.string.status_expiry_in30m');
    }
    if (key === 'in1h') {
      return $r('app.string.status_expiry_in1h');
    }
    if (key === 'in4h') {
      return $r('app.string.status_expiry_in4h');
    }
    if (key === 'today') {
      return $r('app.string.status_expiry_today');
    }
    if (key === 'thisweek') {
      return $r('app.string.status_expiry_thisweek');
    }
    return $r('app.string.status_expiry_never');
  }

  /** 与打开时状态相比是否有改动：SAVE 未改动时置灰不可点（官方截图 SAVE 为禁用灰） */
  private dirty(): boolean {
    // 与 submit 实际发送的值同源（发送前 trim）：否则纯空白草稿会被判成「有改动」，
    // 点 SAVE 却发出空 message（= 清空语义）或在无状态时空写，用户看到「已保存」却什么都没发生
    const message = this.message.trim();
    // 到期只在「用户真的动过档位、且动后与原档不同」时才算改动
    const expiryChanged = this.expiryTouched
      && this.expiryKey !== expiryKeyOf(this.originalExpiresAt, this.openedAt);
    const current = this.status;
    if (current === null) {
      return message !== '' || this.emoji !== '' || this.busy || expiryChanged;
    }
    return message !== current.message || this.emoji !== current.emojiRaw
      || this.busy !== current.busy || expiryChanged;
  }

  /** 既有状态的组织归属：写入时回传，省略即被 GitHub 视为公开（组织限定状态会被改公开） */
  private organizationIdOf(): string {
    const current = this.status;
    return current !== null ? current.organizationId : '';
  }

  /** 是否有既有状态（决定 CLEAR STATUS 可点与置灰） */
  private hasStatus(): boolean {
    return this.status !== null;
  }

  // —— 提交 ——

  /** 统一收尾：成功关弹层回页刷新；失败保留弹层与已填内容，仅提示原因（070/075 同口径） */
  private commit(write: Promise<void>): void {
    this.saving = true;
    write.then((): void => {
      this.saving = false;
      this.onSaved();
    }).catch((e: Error): void => {
      this.saving = false;
      promptAction.showToast({ message: friendlyError(this.getUIContext(), e) });
    });
  }

  /** SAVE：空文案即清空（官方语义），到期档 Never 走省略字段 */
  private submit(): void {
    if (this.saving || !this.dirty()) {
      return;
    }
    // 档位没动过就原样回传既有到期时刻：重算会把它截断到最近档位或重新计时（顺延）
    const expiry = this.expiryTouched
      ? expiryIsoOf(this.expiryKey, Date.now())
      : this.originalExpiresAt;
    this.commit(ProfileService.setStatus(this.token, this.message.trim(), this.emoji, this.busy,
      expiry, this.organizationIdOf()));
  }

  /** CLEAR STATUS：空 message 提交即清空（GraphQL 无独立 clear mutation，见 Spec 076 §七） */
  private clear(): void {
    if (this.saving || !this.hasStatus()) {
      return;
    }
    this.commit(ProfileService.clearStatus(this.token, this.organizationIdOf()));
  }

  private pickEmoji(emoji: string): void {
    this.emoji = emoji;
    this.emojiGlyph = emoji;
    this.emojiImage = '';
    this.sheetKind = '';
  }

  private pickExpiry(key: string): void {
    this.expiryKey = key;
    this.expiryTouched = true;
    this.sheetKind = '';
  }

  // —— 结构 ——

  /** 自绘抓取条（近全屏档框架不渲染 dragBar，Spec 070 口径） */
  @Builder
  gripBar() {
    Row() {
      Row()
        .width(36)
        .height(5)
        .borderRadius(2.5)
        .backgroundColor($r('app.color.text_tertiary'))
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .padding({ top: 8, bottom: 6 })
  }

  /** 顶栏：✕ + Edit status + SAVE（未改动置灰） */
  @Builder
  header() {
    Row() {
      Stack() {
        OctIcon({ res: $r('app.media.oct_x_16'), iconSize: 20, iconColor: $r('app.color.text_primary') })
      }
      .width(44)
      .height(44)
      .accessibilityDescription($r('app.string.a11y_close'))
      .focusable(true)
      .onClick((): void => this.onDismiss())
      Text($r('app.string.status_edit_title'))
        .fontSize($r('app.float.title_font_size'))
        .fontWeight(600)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
      Text($r('app.string.status_save'))
        .fontSize($r('app.float.sub_text_font_size'))
        .fontWeight(FontWeight.Medium)
        .fontColor(this.dirty() ? $r('app.color.link_blue') : $r('app.color.text_tertiary'))
        .padding({ left: 6, right: 16, top: 6, bottom: 6 })
        .borderRadius(6)
        .backgroundColor(this.savePressed ? $r('app.color.chip_bg') : Color.Transparent)
        .onTouch((e: TouchEvent): void => {
          if (e.type === TouchType.Down) {
            this.savePressed = true;
          } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
            this.savePressed = false;
          }
        })
        .responseRegion({ x: -6, y: -7, width: '130%', height: '147%' })
        .onClick((): void => this.submit())
    }
    .width('100%')
    .height(48)
    .padding({ left: 4, right: 4 })
  }

  /** 输入行：emoji 选择框（点开子弹层）+ 状态文案输入 */
  @Builder
  inputRow() {
    Row({ space: 12 }) {
      Stack() {
        if (this.emojiGlyph !== '') {
          Text(this.emojiGlyph)
            .fontSize($r('app.float.title_font_size'))
        } else if (this.emojiImage !== '') {
          Image(this.emojiImage)
            .width(24)
            .height(24)
        } else {
          // 无 emoji：占位 smiley（与 Profile 空态行同字形，2026-09-22 走查用户指出）
          OctIcon({ res: $r('app.media.oct_smiley_16'), iconSize: 20, iconColor: $r('app.color.text_secondary') })
        }
      }
      .width(44)
      .height(44)
      .borderRadius(6)
      .backgroundColor($r('app.color.input_bg'))
      .border({ width: 1, color: $r('app.color.divider') })
      .accessibilityDescription($r('app.string.status_emoji_title'))
      .focusable(true)
      .onClick((): void => {
        this.sheetKind = SHEET_EMOJI;
      })

      TextInput({ placeholder: $r('app.string.status_message_placeholder'), text: this.message })
        .height(44)
        .fontSize($r('app.float.menu_font_size'))
        .fontColor($r('app.color.text_primary'))
        .placeholderFont({ size: $r('app.float.menu_font_size') })
        .placeholderColor($r('app.color.text_tertiary'))
        .caretColor($r('app.color.link_blue'))
        .maxLength(STATUS_MESSAGE_MAX)
        .backgroundColor(Color.Transparent)
        // 贴边输入光标被默认圆角裁成月牙，显式归零（坑 41）
        .borderRadius(0)
        .padding({ left: 0, right: 0 })
        .layoutWeight(1)
        .onChange((value: string): void => {
          this.message = value;
        })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 10, bottom: 10 })
    .backgroundColor($r('app.color.card_background'))
  }

  @Builder
  counterRow() {
    Text(this.counterText())
      .fontSize($r('app.float.caption_font_size'))
      .fontColor($r('app.color.text_secondary'))
      .width('100%')
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })
  }

  /** Busy 行：开关控制 limitedAvailability */
  @Builder
  busyRow() {
    Row() {
      Text($r('app.string.status_busy'))
        .fontSize($r('app.float.body_font_size'))
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: this.busy })
        .selectedColor($r('app.color.link_blue'))
        .onChange((isOn: boolean): void => {
          this.busy = isOn;
        })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .backgroundColor($r('app.color.card_background'))
  }

  @Builder
  busyHintRow() {
    Text($r('app.string.status_busy_hint'))
      .fontSize($r('app.float.caption_font_size'))
      .fontColor($r('app.color.text_secondary'))
      .width('100%')
      .padding({ left: 16, right: 16, top: 10, bottom: 10 })
  }

  /** Clear after... 行：右侧当前档位（大写蓝字），点开 Select Expiration */
  @Builder
  expiryRow() {
    Row() {
      Text($r('app.string.status_clear_after'))
        .fontSize($r('app.float.body_font_size'))
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
      Text(this.expiryLabel(this.expiryKey))
        .fontSize($r('app.float.body_font_size'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.link_blue'))
        .textCase(TextCase.UpperCase)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .backgroundColor($r('app.color.card_background'))
    .onClick((): void => {
      this.sheetKind = SHEET_EXPIRY;
    })
  }

  /** CLEAR STATUS：恒为 danger 红字（2026-09-22 走查用户指出）；无既有状态时点按为空操作 */
  @Builder
  clearRow() {
    Row() {
      Text($r('app.string.status_clear_action'))
        .fontSize($r('app.float.body_font_size'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.danger_text'))
        .textCase(TextCase.UpperCase)
    }
    .width('100%')
    .height($r('app.float.button_height'))
    .justifyContent(FlexAlign.Center)
    .borderRadius(6)
    .backgroundColor(this.clearPressed ? $r('app.color.chip_bg') : Color.Transparent)
    .onTouch((e: TouchEvent): void => {
      if (e.type === TouchType.Down) {
        this.clearPressed = true;
      } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.clearPressed = false;
      }
    })
    .onClick((): void => this.clear())
  }

  /** 单选圆钮（与筛选弹层同款：外圈描边 + 选中实心） */
  @Builder
  radioCircle($$: RadioState) {
    Stack() {
      Circle()
        .width(20)
        .height(20)
        .fill(Color.Transparent)
        .stroke($$.selected ? $r('app.color.link_blue') : $r('app.color.text_tertiary'))
        .strokeWidth(2)
      if ($$.selected) {
        Circle()
          .width(10)
          .height(10)
          .fill($r('app.color.link_blue'))
      }
    }
  }

  /** Select Expiration 子弹层：六档单选，点即生效关闭 */
  @Builder
  expirySheet() {
    Column() {
      this.gripBar()
      Row() {
        Stack() {
          OctIcon({ res: $r('app.media.oct_x_16'), iconSize: 20, iconColor: $r('app.color.text_primary') })
        }
        .width(44)
        .height(44)
        .onClick((): void => {
          this.sheetKind = '';
        })
        Text($r('app.string.status_expiry_title'))
          .fontSize($r('app.float.title_font_size'))
          .fontWeight(600)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 8, right: 8 })

      List() {
        ForEach(STATUS_EXPIRY_KEYS, (key: string) => {
          ListItem() {
            Row() {
              Text(this.expiryLabel(key))
                .fontSize($r('app.float.sub_text_font_size'))
                .fontColor($r('app.color.text_primary'))
                .layoutWeight(1)
              this.radioCircle({ selected: this.expiryKey === key })
            }
            .width('100%')
            .height(56)
            .padding({ left: 16, right: 16 })
            .onClick((): void => this.pickExpiry(key))
          }
        }, (key: string) => key)
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.card_background'))
  }

  /** 子弹层分派：单 bindSheet 内切换内容（规避同组件多 bindSheet 失效） */
  @Builder
  overlaySheet() {
    if (this.sheetKind === SHEET_EMOJI) {
      StatusEmojiSheet({
        selected: this.emojiGlyph,
        onPick: (emoji: string): void => this.pickEmoji(emoji),
        onClose: (): void => {
          this.sheetKind = '';
        }
      })
    } else {
      this.expirySheet()
    }
  }

  build() {
    Column() {
      // 白块：抓取条 + 顶栏 + 分隔线 + 输入行
      Column() {
        this.gripBar()
        this.header()
        Divider()
          .color($r('app.color.divider'))
          .width('100%')
        this.inputRow()
      }
      .width('100%')
      .backgroundColor($r('app.color.card_background'))

      this.counterRow()
      this.busyRow()
      this.busyHintRow()
      this.expiryRow()
      this.clearRow()
      Blank()
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_page'))
    .bindSheet(this.sheetKind !== '', this.overlaySheet(), {
      height: 540,
      showClose: false,
      dragBar: false,
      backgroundColor: $r('app.color.card_background'),
      onDisappear: (): void => {
        this.sheetKind = '';
      }
    })
  }
}
