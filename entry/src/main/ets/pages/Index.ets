/**
 * 应用根页面：Token 门禁 → Navigation 壳 + 底部四 Tab（Home/Inbox/Explore/Copilot）。
 * Inbox/Explore/Copilot 内容由 Spec 002/003/004 分支实现，当前为占位视图。
 */
import { TokenStore } from '../services/TokenStore';
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { applyThemeMode } from '../utils/ThemeMode';
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
import { OctIcon } from '../components/OctIcon';
import { EditMyWorkView } from './EditMyWork';
import { WorkIssuesView } from './WorkIssues';
import { WorkPrsView } from './WorkPrs';
import { DiscussionsView } from './Discussions';
import { ProjectsView } from './Projects';
import { TopRepositoriesView } from './TopRepositories';
import { OrganizationsView } from './Organizations';
import { StarredRepositoriesView } from './StarredRepositories';
import { RepoPrsView } from './RepoPrs';
import { RepoCommitsView } from './RepoCommits';
import { RepoReleasesView } from './RepoReleases';
import { IssueDetailView } from './IssueDetail';
import { PrDetailView } from './PrDetail';

@Entry
@Component
struct Index {
  @State token: string = '';
  @State checked: boolean = false;
  @State currentTab: number = 0;
  @State profileLogin: string = '';
  @State repoOwner: string = '';
  @State repoName: string = '';
  @State detailNumber: number = 0;
  @State inboxHasUnread: boolean = false;
  /** My Work 配置变更计数器：Edit My Work SAVE 后递增，泵到 HomeView 触发重渲染 */
  @State homeWorkVersion: number = 0;
  private pathStack: NavPathStack = new NavPathStack();

  aboutToAppear(): void {
    // 启动恢复主题（Spec 026 三态：system/light/dark）
    preferences.getPreferences(this.getUIContext().getHostContext() as common.UIAbilityContext, 'starraft_settings')
      .then((pref: preferences.Preferences) => {
        const mode = pref.getSync('theme_mode', 'system') as string;
        applyThemeMode(this.getUIContext().getHostContext() as common.UIAbilityContext | undefined, mode);
      })
      .catch(() => {
      });
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
  editMyWorkDestination() {
    NavDestination() {
      EditMyWorkView({
        pathStack: this.pathStack,
        onSaved: (): void => {
          this.homeWorkVersion += 1;
        }
      })
    }
    .title($r('app.string.nav_edit_work_title'))
  }

  @Builder
  workIssuesDestination() {
    NavDestination() {
      WorkIssuesView({
        token: this.token,
        pathStack: this.pathStack
      })
    }
    .title($r('app.string.nav_issues_title'))
  }

  @Builder
  workPrsDestination() {
    NavDestination() {
      WorkPrsView({
        token: this.token,
        pathStack: this.pathStack
      })
    }
    .title($r('app.string.home_work_pull_requests'))
  }

  @Builder
  discussionsDestination() {
    NavDestination() {
      DiscussionsView({
        token: this.token,
        pathStack: this.pathStack
      })
    }
    .title($r('app.string.nav_discussions_title'))
  }

  @Builder
  projectsDestination() {
    NavDestination() {
      ProjectsView({
        token: this.token,
        pathStack: this.pathStack
      })
    }
    .title($r('app.string.nav_projects_title'))
  }

  @Builder
  topReposDestination() {
    NavDestination() {
      TopRepositoriesView({
        token: this.token,
        pathStack: this.pathStack
      })
    }
    .title($r('app.string.nav_top_repos_title'))
  }

  @Builder
  organizationsDestination() {
    NavDestination() {
      OrganizationsView({
        token: this.token,
        pathStack: this.pathStack
      })
    }
    .title($r('app.string.nav_organizations_title'))
  }

  @Builder
  starredDestination() {
    NavDestination() {
      StarredRepositoriesView({
        token: this.token,
        pathStack: this.pathStack
      })
    }
    .title($r('app.string.nav_starred_title'))
  }

  /** 路由参数解析：owner/name[/number] */
  private parseRouteParam(param: string): void {
    const parts = param.split('/');
    if (parts.length >= 2) {
      this.repoOwner = parts[0];
      this.repoName = parts[1];
    }
    if (parts.length >= 3) {
      this.detailNumber = Number(parts[2]);
    }
  }

  @Builder
  repoPrsDestination() {
    NavDestination() {
      RepoPrsView({
        owner: this.repoOwner,
        name: this.repoName,
        token: this.token,
        pathStack: this.pathStack
      })
    }
    .onReady((context: NavDestinationContext) => {
      this.parseRouteParam(context.pathInfo.param as string);
    })
    .title($r('app.string.home_work_pull_requests'))
  }

  @Builder
  repoCommitsDestination() {
    NavDestination() {
      RepoCommitsView({
        owner: this.repoOwner,
        name: this.repoName,
        token: this.token,
        pathStack: this.pathStack
      })
    }
    .onReady((context: NavDestinationContext) => {
      this.parseRouteParam(context.pathInfo.param as string);
    })
    .title($r('app.string.repo_commits_title'))
  }

  @Builder
  repoReleasesDestination() {
    NavDestination() {
      RepoReleasesView({
        owner: this.repoOwner,
        name: this.repoName,
        token: this.token,
        pathStack: this.pathStack
      })
    }
    .onReady((context: NavDestinationContext) => {
      this.parseRouteParam(context.pathInfo.param as string);
    })
    .title($r('app.string.repo_releases_title'))
  }

  @Builder
  issueDetailDestination() {
    NavDestination() {
      IssueDetailView({
        owner: this.repoOwner,
        name: this.repoName,
        number: this.detailNumber,
        token: this.token,
        pathStack: this.pathStack
      })
    }
    .onReady((context: NavDestinationContext) => {
      this.parseRouteParam(context.pathInfo.param as string);
    })
    .title($r('app.string.nav_issues_title'))
  }

  @Builder
  prDetailDestination() {
    NavDestination() {
      PrDetailView({
        owner: this.repoOwner,
        name: this.repoName,
        number: this.detailNumber,
        token: this.token,
        pathStack: this.pathStack
      })
    }
    .onReady((context: NavDestinationContext) => {
      this.parseRouteParam(context.pathInfo.param as string);
    })
    .title($r('app.string.home_work_pull_requests'))
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
    } else if (name === 'editMyWork') {
      this.editMyWorkDestination()
    } else if (name === 'workIssues') {
      this.workIssuesDestination()
    } else if (name === 'workPrs') {
      this.workPrsDestination()
    } else if (name === 'discussions') {
      this.discussionsDestination()
    } else if (name === 'projects') {
      this.projectsDestination()
    } else if (name === 'topRepos') {
      this.topReposDestination()
    } else if (name === 'organizations') {
      this.organizationsDestination()
    } else if (name === 'starred') {
      this.starredDestination()
    } else if (name === 'repoPrs') {
      this.repoPrsDestination()
    } else if (name === 'repoCommits') {
      this.repoCommitsDestination()
    } else if (name === 'repoReleases') {
      this.repoReleasesDestination()
    } else if (name === 'issueDetail') {
      this.issueDetailDestination()
    } else if (name === 'prDetail') {
      this.prDetailDestination()
    }
  }

  @Builder
  mainTabs() {
    Tabs({ barPosition: BarPosition.End }) {
      TabContent() {
        HomeView({ token: this.token, pathStack: this.pathStack, workVersion: this.homeWorkVersion })
      }
      .tabBar(this.tabItem($r('app.media.oct_home_16'), $r('app.string.tab_home'), 0))

      TabContent() {
        InboxView({ token: this.token })
      }
      .tabBar(this.tabItem($r('app.media.oct_inbox_16'), $r('app.string.tab_inbox'), 1))

      TabContent() {
        ExploreView({ token: this.token, pathStack: this.pathStack })
      }
      .tabBar(this.tabItem($r('app.media.oct_telescope_16'), $r('app.string.tab_explore'), 2))

      TabContent() {
        CopilotView()
      }
      .tabBar(this.tabItem($r('app.media.oct_copilot_16'), $r('app.string.tab_copilot'), 3))
    }
    .onChange((index: number) => {
      this.currentTab = index;
    })
    .barHeight(56)
    .width('100%')
    .height('100%')
  }

  @Builder
  tabItem(iconRes: Resource, labelRes: Resource, index: number) {
    Column({ space: 2 }) {
      Stack({ alignContent: Alignment.TopEnd }) {
        OctIcon({
          res: iconRes,
          iconSize: 20,
          iconColor: this.currentTab === index ? $r('app.color.primary') : $r('app.color.text_secondary')
        })
        // 未读蓝点：Inbox Tab 图标右上角（Spec 013，官方 App 样式）
        if (index === 1 && this.inboxHasUnread) {
          Circle()
            .width(8)
            .height(8)
            .fill($r('app.color.link_blue'))
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
