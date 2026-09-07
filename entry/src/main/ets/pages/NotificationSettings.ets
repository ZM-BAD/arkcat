/**
 * 通知设置页（Spec 032）：General / Push Notifications Types / Live notifications / Swipe Options。
 * 纯本地偏好存储；System Options 与 Android 专属说明文案按用户指令整行略过。
 */
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { OctIcon } from '../components/OctIcon';
import { PageShadowBar } from '../components/PageShadowBar';
import { resText } from '../utils/I18n';

const PREFS_NAME = 'arkcat_settings';
const SWIPE_DONE = 'done';
const SWIPE_UNSUBSCRIBE = 'unsubscribe';

@ComponentV2
export struct NotificationSettingsView {
  @Param pathStack: NavPathStack = new NavPathStack();
  @Local directMentions: boolean = true;
  @Local reviewRequested: boolean = false;
  @Local assigned: boolean = false;
  @Local deploymentReview: boolean = false;
  @Local pullRequestReview: boolean = false;
  @Local workflowRuns: boolean = false;
  @Local cloudAgent: boolean = true;
  @Local remoteSession: boolean = true;
  @Local leftSwipe: string = SWIPE_DONE;
  @Local rightSwipe: string = SWIPE_UNSUBSCRIBE;
  /** 偏好加载完成门控：Toggle/Slider 的 isOn/value 仅在创建时生效，须等加载后再渲染 */
  @Local loaded: boolean = false;
  /** 滚动顶部阴影（滚动中显示、回顶消失） */
  @Local scrollShadow: boolean = false;

  aboutToAppear(): void {
    this.loadSettings();
  }

  private loadSettings(): void {
    const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    if (ctx === undefined) {
      return;
    }
    preferences.getPreferences(ctx, PREFS_NAME)
      .then((pref: preferences.Preferences) => {
        this.directMentions = pref.getSync('notif_direct_mentions', true) as boolean;
        this.reviewRequested = pref.getSync('notif_review_requested', false) as boolean;
        this.assigned = pref.getSync('notif_assigned', false) as boolean;
        this.deploymentReview = pref.getSync('notif_deployment_review', false) as boolean;
        this.pullRequestReview = pref.getSync('notif_pull_request_review', false) as boolean;
        this.workflowRuns = pref.getSync('notif_workflow_runs', false) as boolean;
        this.cloudAgent = pref.getSync('notif_cloud_agent', true) as boolean;
        this.remoteSession = pref.getSync('notif_remote_session', true) as boolean;
        this.leftSwipe = pref.getSync('notif_left_swipe', SWIPE_DONE) as string;
        this.rightSwipe = pref.getSync('notif_right_swipe', SWIPE_UNSUBSCRIBE) as string;
        this.loaded = true;
      })
      .catch(() => {
        // 读取失败按默认值渲染，避免正文永久空白（review E7）
        this.loaded = true;
      });
  }

  private saveSetting(key: string, value: string | number | boolean): void {
    const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    if (ctx === undefined) {
      return;
    }
    preferences.getPreferences(ctx, PREFS_NAME)
      .then((pref: preferences.Preferences) => {
        pref.putSync(key, value);
        pref.flushSync();
      })
      .catch(() => {
      });
  }

  private stringOf(res: Resource): string {
    return resText(this.getUIContext(), res);
  }

  /** 滑动动作 → 本地化文案 */
  private swipeLabel(action: string): string {
    if (action === SWIPE_DONE) {
      return this.stringOf($r('app.string.settings_mark_as_done'));
    }
    return this.stringOf($r('app.string.settings_unsubscribe'));
  }

  private swipeAction(side: string): string {
    return side === 'left' ? this.leftSwipe : this.rightSwipe;
  }

  /** CHANGE：为该侧滑动动作弹出二选一菜单（Mark as done / Unsubscribe） */
  private pickSwipeAction(side: string): void {
    const ui = this.getUIContext();
    ui.getPromptAction().showActionMenu(
      {
        title: side === 'left' ? this.stringOf($r('app.string.settings_left_swipe')) : this.stringOf($r('app.string.settings_right_swipe')),
        buttons: [
          { text: this.stringOf($r('app.string.settings_mark_as_done')), color: $r('app.color.link_blue') },
          { text: this.stringOf($r('app.string.settings_unsubscribe')), color: $r('app.color.link_blue') }
        ]
      },
      (err, data) => {
        if (err) {
          return;
        }
        const action: string = data.index === 0 ? SWIPE_DONE : SWIPE_UNSUBSCRIBE;
        if (side === 'left') {
          this.leftSwipe = action;
          this.saveSetting('notif_left_swipe', action);
        } else {
          this.rightSwipe = action;
          this.saveSetting('notif_right_swipe', action);
        }
      });
  }

  /** 推送开关键 → 状态字段回写 + 持久化（避免重渲染时 Switch 回弹） */
  private applySwitch(key: string, checked: boolean): void {
    switch (key) {
      case 'notif_direct_mentions':
        this.directMentions = checked;
        break;
      case 'notif_review_requested':
        this.reviewRequested = checked;
        break;
      case 'notif_assigned':
        this.assigned = checked;
        break;
      case 'notif_deployment_review':
        this.deploymentReview = checked;
        break;
      case 'notif_pull_request_review':
        this.pullRequestReview = checked;
        break;
      case 'notif_workflow_runs':
        this.workflowRuns = checked;
        break;
      case 'notif_cloud_agent':
        this.cloudAgent = checked;
        break;
      case 'notif_remote_session':
        this.remoteSession = checked;
        break;
      default:
        break;
    }
    this.saveSetting(key, checked);
  }

  /** 分组标题 */
  @Builder
  sectionTitle(labelRes: Resource) {
    Text(labelRes)
      .fontSize($r('app.float.caption_font_size'))
      .fontColor($r('app.color.text_secondary'))
      .width('100%')
      .padding({ left: 4, bottom: 4 })
      .margin({ top: 12 })
  }

  /** 开关行（卡片 + 原生 Switch） */
  @Builder
  toggleRow(labelRes: Resource, isOn: boolean, key: string) {
    Row() {
      Text(labelRes)
        .fontSize($r('app.float.body_font_size'))
        .fontColor($r('app.color.text_primary'))
      Blank()
      Toggle({ type: ToggleType.Switch, isOn: isOn })
        .selectedColor($r('app.color.link_blue'))
        .onChange((checked: boolean) => {
          this.applySwitch(key, checked);
        })
    }
    .width('100%')
    .height(52)
    .padding({ left: 16, right: 16 })
    .backgroundColor($r('app.color.card_background'))
    .borderRadius(12)
    .margin({ bottom: 4 })
  }

  /** 滑动动作选择行：标签 + 当前值 + CHANGE */
  @Builder
  swipeRow(side: string) {
    Row() {
      Column({ space: 2 }) {
        Text(side === 'left' ? $r('app.string.settings_left_swipe') : $r('app.string.settings_right_swipe'))
          .fontSize($r('app.float.body_font_size'))
          .fontColor($r('app.color.text_primary'))
        Text(this.swipeLabel(this.swipeAction(side)))
          .fontSize($r('app.float.body_font_size'))
          .fontColor($r('app.color.text_secondary'))
      }
      .alignItems(HorizontalAlign.Start)
      Blank()
      Text($r('app.string.settings_change'))
        .fontSize($r('app.float.body_font_size'))
        .fontWeight(600)
        .fontColor($r('app.color.link_blue'))
        .responseRegion({ x: -6, y: -7, width: '130%', height: '147%' })
        .onClick(() => {
          this.pickSwipeAction(side);
        })
    }
    .width('100%')
    .height(64)
    .padding({ left: 16, right: 16 })
    .backgroundColor($r('app.color.card_background'))
    .borderRadius(12)
  }

  /** 骨架灰条 */
  @Builder
  previewBar(width: number, height: number) {
    Row()
      .width(width)
      .height(height)
      .borderRadius(height / 2)
      .backgroundColor($r('app.color.divider'))
  }

  /** 滑动动作块：绿勾（Mark as done）/ 灰铃铛（Unsubscribe） */
  @Builder
  actionBlock(side: string) {
    Stack() {
      if (this.swipeAction(side) === SWIPE_DONE) {
        OctIcon({ res: $r('app.media.oct_check_16'), iconSize: 20, iconColor: Color.White })
      } else {
        OctIcon({ res: $r('app.media.oct_bell_slash_16'), iconSize: 20, iconColor: Color.White })
      }
    }
    .width(44)
    .height(44)
    .borderRadius(6)
    .backgroundColor(this.swipeAction(side) === SWIPE_DONE ? $r('app.color.success_text') : $r('app.color.text_secondary'))
  }

  /** 滑动预览卡：骨架 + 动作块（左滑块在右，右滑块在左） */
  @Builder
  swipePreview(side: string) {
    Row() {
      if (side === 'right') {
        this.actionBlock(side)
      }
      Column({ space: 6 }) {
        Row({ space: 8 }) {
          this.previewBar(96, 8)
          Blank()
          this.previewBar(28, 8)
        }
        Row({ space: 8 }) {
          this.previewBar(150, 8)
          Blank()
          this.previewBar(48, 8)
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      if (side === 'left') {
        this.actionBlock(side)
      }
    }
    .width('100%')
    .height(64)
    .padding(12)
    .backgroundColor($r('app.color.card_background'))
    .borderRadius(12)
    .margin({ bottom: 4 })
  }

  build() {
    Column() {
      Row({ space: 8 }) {
        Stack() {
          OctIcon({ res: $r('app.media.oct_arrow_left_24'), iconSize: 20, iconColor: $r('app.color.text_primary') })
        }
.width(44)
.height(44)
        .accessibilityDescription($r('app.string.a11y_back'))
        .focusable(true)
        .onClick(() => {
          this.pathStack.pop();
        })
        Text($r('app.string.settings_notifications'))
          .fontSize($r('app.float.title_font_size'))
          .fontWeight(600)
          .fontColor($r('app.color.text_primary'))
        Blank()
      }
      .width('100%')
      .height(48)
      .padding({ left: 0, right: 0 })

      PageShadowBar({ show: this.scrollShadow })

      Scroll() {
        if (this.loaded) {
          Column() {
            this.sectionTitle($r('app.string.settings_general'))
          Row() {
            Text($r('app.string.settings_working_hours'))
              .fontSize($r('app.float.body_font_size'))
              .fontColor($r('app.color.text_primary'))
            Blank()
            Text($r('app.string.settings_off'))
              .fontSize($r('app.float.body_font_size'))
              .fontColor($r('app.color.text_secondary'))
          }
          .width('100%')
          .height(46)
          .padding({ left: 16, right: 16 })
          .backgroundColor($r('app.color.card_background'))
          .borderRadius(12)
          .margin({ bottom: 4 })

          this.sectionTitle($r('app.string.settings_push_notif_types'))
          this.toggleRow($r('app.string.settings_notif_direct_mentions'), this.directMentions, 'notif_direct_mentions')
          this.toggleRow($r('app.string.settings_notif_review_requested'), this.reviewRequested, 'notif_review_requested')
          this.toggleRow($r('app.string.settings_notif_assigned'), this.assigned, 'notif_assigned')
          this.toggleRow($r('app.string.settings_notif_deployment_review'), this.deploymentReview, 'notif_deployment_review')
          this.toggleRow($r('app.string.settings_notif_pull_request_review'), this.pullRequestReview, 'notif_pull_request_review')
          this.toggleRow($r('app.string.settings_notif_workflow_runs'), this.workflowRuns, 'notif_workflow_runs')

          this.sectionTitle($r('app.string.settings_live_notifications'))
          this.toggleRow($r('app.string.settings_cloud_agent_updates'), this.cloudAgent, 'notif_cloud_agent')
          this.toggleRow($r('app.string.settings_remote_session_updates'), this.remoteSession, 'notif_remote_session')

          this.sectionTitle($r('app.string.settings_swipe_options'))
          this.swipeRow('left')
          this.swipePreview('left')
          this.swipeRow('right')
          this.swipePreview('right')

          Row()
            .height(24)
          }
          .padding({ left: 16, right: 16 })
          .width('100%')
        }
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
