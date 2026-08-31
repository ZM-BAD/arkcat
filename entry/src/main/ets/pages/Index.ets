/**
 * 应用根页面：Token 门禁 → Navigation 壳 + 底部四 Tab（Home/Inbox/Explore/Copilot）。
 * Inbox/Explore/Copilot 内容由 Spec 002/003/004 分支实现，当前为占位视图。
 */
import { TokenStore } from '../services/TokenStore';
import { HomeService } from '../services/HomeService';
import { TokenSetup } from './TokenSetup';
import { HomeView } from './Home';
import { InboxView } from './Inbox';
import { ExploreView } from './Explore';
import { CopilotView } from './Copilot';
import { ProfileView } from './Profile';
import { RepoDetailView } from './RepoDetail';
import { IssuesListView } from './IssuesList';
import { SettingsView } from './Settings';
import { SearchView } from './Search';

@Entry
@Component
struct Index {
  @State token: string = '';
  @State checked: boolean = false;
  @State currentTab: number = 0;
  @State profileLogin: string = '';
  @State repoOwner: string = '';
  @State repoName: string = '';
  @State inboxHasUnread: boolean = false;
  private pathStack: NavPathStack = new NavPathStack();

  aboutToAppear(): void {
    TokenStore.load().then((token: string) => {
      this.token = token;
      this.checked = true;
      this.refreshInboxUnread(token);
    });
  }

  /** 未读角标：REST 兜底，Inbox Tab 显示蓝点（Spec 013） */
  private refreshInboxUnread(token: string): void {
    if (token === '') {
      return;
    }
    HomeService.hasUnreadNotifications(token)
      .then((hasUnread: boolean) => {
        this.inboxHasUnread = hasUnread;
      })
      .catch(() => {
        this.inboxHasUnread = false;
      });
  }

  @Builder
  userProfileDestination() {
    NavDestination() {
      ProfileView({
        login: this.profileLogin,
        token: this.token,
        pathStack: this.pathStack
      })
    }
    .onReady((context: NavDestinationContext) => {
      const login = context.pathInfo.param as string;
      if (login !== undefined && login !== null && login !== '') {
        this.profileLogin = login;
      }
    })
    .title($r('app.string.nav_profile_title'))
  }

  @Builder
  repoDetailDestination() {
    NavDestination() {
      RepoDetailView({
        owner: this.repoOwner,
        name: this.repoName,
        token: this.token,
        pathStack: this.pathStack
      })
    }
    .onReady((context: NavDestinationContext) => {
      // 路由参数格式：owner/name
      const full = context.pathInfo.param as string;
      const parts: string[] = full.split('/');
      if (parts.length >= 2) {
        this.repoOwner = parts[0];
        this.repoName = parts[1];
      }
    })
    .title($r('app.string.nav_repo_title'))
  }

  @Builder
  issuesListDestination() {
    NavDestination() {
      IssuesListView({
        owner: this.repoOwner,
        name: this.repoName,
        token: this.token,
        pathStack: this.pathStack
      })
    }
    .onReady((context: NavDestinationContext) => {
      const full = context.pathInfo.param as string;
      const parts: string[] = full.split('/');
      if (parts.length >= 2) {
        this.repoOwner = parts[0];
        this.repoName = parts[1];
      }
    })
    .title($r('app.string.nav_issues_title'))
  }

  @Builder
  settingsDestination() {
    NavDestination() {
      SettingsView({
        pathStack: this.pathStack
      })
    }
    .title($r('app.string.profile_settings'))
  }

  @Builder
  searchDestination() {
    NavDestination() {
      SearchView({
        token: this.token,
        pathStack: this.pathStack
      })
    }
    .title('')
  }

  @Builder
  destinationMap(name: string) {
    if (name === 'userProfile') {
      this.userProfileDestination()
    } else if (name === 'repoDetail') {
      this.repoDetailDestination()
    } else if (name === 'issuesList') {
      this.issuesListDestination()
    } else if (name === 'settings') {
      this.settingsDestination()
    } else if (name === 'search') {
      this.searchDestination()
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
        InboxView({ token: this.token })
      }
      .tabBar(this.tabItem('🔔', $r('app.string.tab_inbox'), 1))

      TabContent() {
        ExploreView({ token: this.token, pathStack: this.pathStack })
      }
      .tabBar(this.tabItem('🧭', $r('app.string.tab_explore'), 2))

      TabContent() {
        CopilotView()
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
      Stack({ alignContent: Alignment.TopEnd }) {
        Text(icon)
          .fontSize(20)
          .opacity(this.currentTab === index ? 1 : 0.5)
        // 未读蓝点：Inbox Tab 图标右上角（Spec 013，官方 App 样式）
        if (index === 1 && this.inboxHasUnread) {
          Circle()
            .width(8)
            .height(8)
            .fill('#0969DA')
            .margin({ top: -2, right: -2 })
        }
      }
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
