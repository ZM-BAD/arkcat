/**
 * 应用根页面：Token 门禁 → Navigation 壳 + 底部四 Tab（Home/Inbox/Explore/Copilot）。
 * Inbox/Explore/Copilot 内容由 Spec 002/003/004 分支实现，当前为占位视图。
 */
import { TokenStore } from '../services/TokenStore';
import { TokenSetup } from './TokenSetup';
import { HomeView } from './Home';

@Entry
@Component
struct Index {
  @State token: string = '';
  @State checked: boolean = false;
  @State currentTab: number = 0;
  private pathStack: NavPathStack = new NavPathStack();

  aboutToAppear(): void {
    TokenStore.load().then((token: string) => {
      this.token = token;
      this.checked = true;
    });
  }

  @Builder
  tabPlaceholder(icon: string, label: string) {
    Column({ space: 12 }) {
      Text(icon)
        .fontSize(48)
      Text(`${label} · ${'待后续 Spec 实现'}`)
        .fontSize($r('app.float.body_font_size'))
        .fontColor($r('app.color.text_secondary'))
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor($r('app.color.bg_page'))
  }

  @Builder
  userProfileDestination() {
    NavDestination() {
      Column({ space: 12 }) {
        Text('👤')
          .fontSize(48)
        Text('User Profile · Spec 005 待实现')
          .fontSize($r('app.float.body_font_size'))
          .fontColor($r('app.color.text_secondary'))
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
    }
    .title('Profile')
  }

  @Builder
  destinationMap(name: string) {
    if (name === 'userProfile') {
      this.userProfileDestination()
    }
  }

  @Builder
  mainTabs() {
    Tabs({ barPosition: BarPosition.End }) {
      TabContent() {
        HomeView({ token: this.token, pathStack: this.pathStack })
      }
      .tabBar(this.tabItem('🏠', $r('app.string.tab_home'), 0))

      TabContent() {
        this.tabPlaceholder('🔔', 'Inbox')
      }
      .tabBar(this.tabItem('🔔', $r('app.string.tab_inbox'), 1))

      TabContent() {
        this.tabPlaceholder('🧭', 'Explore')
      }
      .tabBar(this.tabItem('🧭', $r('app.string.tab_explore'), 2))

      TabContent() {
        this.tabPlaceholder('🤖', 'Copilot')
      }
      .tabBar(this.tabItem('🤖', $r('app.string.tab_copilot'), 3))
    }
    .onChange((index: number) => {
      this.currentTab = index;
    })
    .barHeight(56)
    .width('100%')
    .height('100%')
  }

  @Builder
  tabItem(icon: string, labelRes: Resource, index: number) {
    Column({ space: 2 }) {
      Text(icon)
        .fontSize(20)
        .opacity(this.currentTab === index ? 1 : 0.5)
      Text(labelRes)
        .fontSize($r('app.float.caption_font_size'))
        .fontColor(this.currentTab === index ? $r('app.color.primary') : $r('app.color.text_secondary'))
    }
  }

  build() {
    Stack() {
      if (!this.checked) {
        // 避免启动瞬间闪现 Token 设置页
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor($r('app.color.start_window_background'))
      } else if (this.token === '') {
        TokenSetup({
          onSaved: (token: string): void => {
            this.token = token;
          }
        })
      } else {
        Navigation(this.pathStack) {
          this.mainTabs()
        }
        .mode(NavigationMode.Stack)
        .hideTitleBar(true)
        .navDestination(this.destinationMap)
      }
    }
    .width('100%')
    .height('100%')
  }
}
