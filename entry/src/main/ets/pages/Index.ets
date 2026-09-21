/**
 * 应用根页面：Token 门禁 → Navigation 壳 + 底部四 Tab（Home/Inbox/Explore/我的主页）。
 * tab4 图标为当前账号头像（Spec 060）；他人个人主页仍走 userProfile 压栈路由。
 */
import { AccountStore, AccountInfo } from '../services/AccountStore';
import { window, uiObserver } from '@kit.ArkUI';
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { applyThemeMode } from '../utils/ThemeMode';
import { HomeService } from '../services/HomeService';
import { TokenSetup } from './TokenSetup';
import { HomeView } from './Home';
import { InboxView } from './Inbox';
import { ExploreView } from './Explore';
import { ProfileView } from './Profile';
import { RepoDetailView } from './RepoDetail';
import { IssuesListView } from './IssuesList';
import { SettingsView } from './Settings';
import { SearchView } from './Search';
import { SearchOverviewView } from './SearchOverview';
import { SearchResultsView } from './SearchResults';
import { OctIcon } from '../components/OctIcon';
import { EditMyWorkView } from './EditMyWork';
import { FavoritesEditView } from './FavoritesEdit';
import { ShortcutsView } from './Shortcuts';
import { ShortcutCreateView } from './ShortcutCreate';
import { WorkIssuesView } from './WorkIssues';
import { WorkPrsView } from './WorkPrs';
import { DiscussionsView } from './Discussions';
import { ProjectsView } from './Projects';
import { TopRepositoriesView } from './TopRepositories';
import { OrganizationsView } from './Organizations';
import { StarredRepositoriesView } from './StarredRepositories';
import { CreateListView } from './CreateList';
import { ListDetailView } from './ListDetail';
import { RepoPrsView } from './RepoPrs';
import { RepoCommitsView } from './RepoCommits';
import { RepoReleasesView } from './RepoReleases';
import { ReleaseDetailView } from './ReleaseDetail';
import { ReactionUsersView } from './ReactionUsers';
import { IssueDetailView } from './IssueDetail';
import { PrDetailView } from './PrDetail';
import { PrFilesView } from './PrFiles';
import { PrChecksView } from './PrChecks';
import { CheckRunDetailView } from './CheckRunDetail';
import { RunSummaryView } from './RunSummary';
import { CommitDetailView } from './CommitDetail';import { NotificationSettingsView } from './NotificationSettings';
import { CodeOptionsView } from './CodeOptions';
import { OpenSourceLibrariesView } from './OpenSourceLibraries';
import { SettingsAboutView } from './SettingsAbout';
import { IssueFormView } from './IssueForm';
import { PrFormView } from './PrForm';
import { PrCompareView } from './PrCompare';
import { BranchPickerView } from './BranchPicker';
import { RepoPickerView } from './RepoPicker';
import { TemplatePickerView } from './TemplatePicker';
import { UserListView } from './UserList';
import { StargazersView } from './Stargazers';
import { ForksView } from './Forks';
import { AchievementDetailView } from './AchievementDetail';
import { RepoPeopleView } from './RepoPeopleView';
import { RepoLicenseView } from './RepoLicenseView';
import { OrgListView } from './OrgList';
import { OrgProfileView } from './OrgProfile';
import { RepositoriesListView } from './RepositoriesList';
import { FileTreeView } from './FileTree';
import { CodeViewerView } from './CodeViewer';
import { ExploreRepoListView } from './ExploreRepoList';
import { FilterActivityView } from './FilterActivity';
import { AccountsView } from './Accounts';
import { InAppBrowserView } from './InAppBrowser';
import { AppLockOverlay, AppLockSettingsView } from './AppLock';

/** 隐藏底部 Tab 栏的路由：Settings 及其下级页面（走查 09-08 定案）+ 模态全屏页（052 徽章详情）
 *  + 应用内浏览器（用户 09-08 定案：该子页也不显示底栏） */
const TAB_BAR_HIDDEN_ROUTES: string[] = [
  'settings', 'notificationSettings', 'codeOptions', 'accounts', 'tokenSetup', 'achievementDetail',
  'openSourceLibraries', 'settingsAbout', 'inAppBrowser', 'repoDiscussions', 'appLock',
  'issueForm', 'prForm', 'prCompare', 'branchPicker', 'repoPicker', 'templatePicker', 'favoritesEdit'
];

@Entry
@Component
struct Index {
  @State token: string = '';
  @State checked: boolean = false;
  /** 开屏 logo 动效（淡入 + 轻微放大；最短停留 1.5s——常用 App 开屏 1~3s，取中偏短） */
  @State splashOpacity: number = 0;
  @State splashScale: number = 0.92;
  @State splashMinElapsed: boolean = false;
  /** Spec 049a：账号列表与当前账号（切号时更新；各 Tab 经 @Param token 感知并重取数据） */
  @State accounts: AccountInfo[] = [];
  @State currentLogin: string = '';
  /** Spec 060：底栏 tab4 头像（由 HomeView 的 viewer 探针上报，不另发查询；空串=占位圆） */
  @State viewerAvatarUrl: string = '';
  /** Spec 060：tab4「我的主页」刷新泵（切回该 Tab / 从其二级页返回时自增 → 静默重取） */
  @State profileTick: number = 0;
  /** Explore 类型筛选页返回信号（Spec 056）：回到 Explore tab 时重读六类勾选、必要时重载动态流 */
  @State exploreTick: number = 0;
  @State currentTab: number = 0;
  /** 软键盘弹出时隐藏底栏（搜索输入态；窗口 keyboardHeightChange 监听） */
  @State keyboardOn: boolean = false;
  /** 徽章详情等全屏沉浸页：隐藏底部 Tab 栏（页内 onShown/onHidden 切换） */
  @State hideTabBar: boolean = false;
  @State profileLogin: string = '';
  @State repoOwner: string = '';
  @State repoName: string = '';
  @State detailNumber: number = 0;
  @State releaseTag: string = '';
  /** Spec 047：Reactees 页参数（encodeURIComponent(subjectId)|content） */
  @State reactionSubjectId: string = '';
  @State reactionContent: string = '';
  @State inboxHasUnread: boolean = false;
  /** Inbox 标记已读后经 AppStorage 通知重算未读角标（review A4） */
  @StorageProp('inboxUnreadTick') @Watch('onInboxUnreadTick') inboxUnreadTick: number = 0;
  /** Spec 066：App Lock 锁定态（EntryAbility 冷启动/退后台置位，AppLockOverlay 解锁清除） */
  @StorageLink('appLockLocked') appLockLocked: boolean = false;
  @State listLogin: string = '';
  /** Discussions 单仓库模式（Share Feedback）：'owner/name'，空串=全局 */
  @State repoForDiscussions: string = '';
  @State listKind: string = 'followers';
  /** Spec 052：成就详情参数（login|startIndex） */
  @State achLogin: string = '';
  @State achStart: number = 0;
  /** 应用内浏览器（About / 页脚外链）路由参数：标题 + URL（Spec 060：页面保留，唯一入口 CopilotSettings 已移除） */
  @State browserTitle: string = '';
  @State browserUrl: string = '';
  @State orgLogin: string = '';
  @State reposOwner: string = '';
  @State reposMode: string = 'org';
  @State starredLogin: string = '';
  /** Starred 页回显信号：子页 pop 回时自增，驱动 Starred 页重取列表 */
  @State starredListsTick: number = 0;
  /** 列表详情参数（listId，可带 `|0` 他人标记）与回显信号（Edit 页 pop 回时自增） */
  @State listDetailId: string = '';
  /** 列表详情归属：false=他人列表（只读，隐藏 Edit/Delete） */
  @State listDetailOwn: boolean = true;
  @State listDetailTick: number = 0;
  /** Create list 页编辑模式参数（''=新建；否则为被编辑列表 id） */
  @State createListEditId: string = '';
  /** Spec 043 表单路由参数（owner|name|mode|editNumber|templateName|base|head 拆段；owner/name 空=Home 入口先选仓库） */
  @State formOwner: string = '';
  @State formName: string = '';
  @State formMode: string = 'new';
  @State formEditNumber: number = 0;
  @State formTemplate: string = '';
  /** Start pull request 带入的 base/head（Compare changes 页选定） */
  @State formBase: string = '';
  @State formHead: string = '';
  /** 分支选择页路由参数（role|owner|name|current 拆段） */
  @State pickerRole: string = '';
  @State pickerOwner: string = '';
  @State pickerName: string = '';
  @State pickerCurrent: string = '';
  /** 文件路由参数（Spec 038/011 共用，格式 owner|name|path） */
  @State fileOwner: string = '';
  @State fileRepo: string = '';
  @State filePath: string = '';
  @State searchKind: string = '';
  @State searchKeyword: string = '';
  /** My Work 配置变更计数器：Edit My Work SAVE 后递增，泵到 HomeView 触发重渲染 */
  @State homeWorkVersion: number = 0;
  /** Spec 050：Favorites 编辑页 SAVE 后递增，泵到 HomeView 触发重渲染 */
  @State homeFavoritesVersion: number = 0;
  /** Spec 074：Shortcuts 管理页/创建页 SAVE 后递增，泵到 HomeView 与管理页（store 单例为真源） */
  @State homeShortcutsVersion: number = 0;
  /** Spec 074：创建页预填参数（Work 漏斗携筛选 JSON；onReady 晚于子组件 aboutToAppear，经 @Monitor 应用） */
  @State shortcutPrefill: string = '';
  /** Spec 074：选仓库页 pop 回 tick，ShortcutCreate 消费 RepoPickResult 回传槽（onPop 不触发，坑库定案） */
  @State shortcutRepoTick: number = 0;
  /** PrFiles 回页刷新计数器：Code Options 返回后递增，重读行号等设置 */
  @State prFilesTick: number = 0;
  /** prCompare 返回 tick：分支选择页（branchPicker）pop 回后消费回传槽（Spec 043） */
  @State prCompareTick: number = 0;
  /** prFiles 返回 tick：PrDetail 重拉 reviewThreads（Spec 042 行内评论落点在会话区） */
  @State prDetailTick: number = 0;
  /** issueDetail 返回 tick：编辑表单（issueForm）pop 回后重拉标题/正文（Spec 043） */
  @State issueDetailTick: number = 0;
  /** Code Options 返回 tick：CodeViewer/CommitDetail 重读设置（review C3，同 prFilesTick 模式） */
  @State codeOptionsTick: number = 0;
  /** About 页回显信号：从详情页返回可见时自增，重拉 star 态（Spec 069） */
  @State settingsAboutTick: number = 0;
  /** 首显守卫（review A6/D17）：onShown 首次触发时 aboutToAppear 已拉取，不重复请求 */
  @State starredShownOnce: boolean = false;
  @State listDetailShownOnce: boolean = false;
  @State repoPrsShownOnce: boolean = false;
  @State settingsAboutShownOnce: boolean = false;
  @State issuesListShownOnce: boolean = false;
  @State workPrsShownOnce: boolean = false;
  @State workIssuesShownOnce: boolean = false;
  /** 列表页返回刷新 tick（review B13）：详情改动后返回计数/状态不过期 */
  @State repoPrsTick: number = 0;
  @State issuesListTick: number = 0;
  @State workPrsTick: number = 0;
  @State workIssuesTick: number = 0;
  /** Commit 详情路由参数（owner/name/oid 第三段） */
  @State commitOid: string = '';
  /** Spec 048：Checks 页返回刷新泵与首显守卫（详情页重跑后 pop 回静默重拉） */
  @State prChecksTick: number = 0;
  @State prChecksShownOnce: boolean = false;
  /** Spec 048：Check run 详情路由参数（owner|name|checkRunId|perm|jobName|appLogo|detailsUrl 拆段） */
  @State checkRunId: number = 0;
  @State checkPerm: string = '';
  @State checkJobName: string = '';
  @State checkAppLogo: string = '';
  @State checkDetailsUrl: string = '';
  /** Spec 048：Check run 详情返回刷新泵（应用内浏览器关回来自增 → 静默重拉 job） */
  @State checkRunTick: number = 0;
  /** Spec 048：run 汇总页路由参数与返回刷新泵（job 详情重跑后 pop 回静默重拉） */
  @State runSummaryId: number = 0;
  @State runSummaryTick: number = 0;
  @State runSummaryShownOnce: boolean = false;
  @State checkRunShownOnce: boolean = false;
  /** Spec 056：Explore Trending/Awesome 列表页 kind 参数 */
  @State exploreListKind: string = 'trending';
  private tabController: TabsController = new TabsController();
  private pathStack: NavPathStack = new NavPathStack();

  aboutToAppear(): void {
    // 开屏动效：logo 淡入 + 放大到位（350ms ease-out）；最短停留 1.5s（token 探针完成也不提前切）
    this.getUIContext().animateTo({ duration: 350, curve: Curve.EaseOut }, () => {
      this.splashOpacity = 1;
      this.splashScale = 1;
    });
    setTimeout((): void => {
      this.splashMinElapsed = true;
    }, 1500);
    // 软键盘高度监听：弹起时隐藏底部 tab 栏（官方 App 键盘态行为）
    window.getLastWindow(this.getUIContext().getHostContext() as common.Context)
      .then((w: window.Window) => {
        w.on('keyboardHeightChange', (height: number) => {
          this.keyboardOn = height > 0;
        });
      })
      .catch(() => {
      });
    // 启动恢复主题（Spec 026 三态：system/light/dark）；同步读避免晚于首帧闪切（review A18）
    try {
      const pref = preferences.getPreferencesSync(
        this.getUIContext().getHostContext() as common.UIAbilityContext, { name: 'arkcat_settings' });
      const mode = pref.getSync('theme_mode', 'system') as string;
      applyThemeMode(this.getUIContext().getHostContext() as common.UIAbilityContext | undefined, mode);
    } catch (e) {
      // 读取失败按系统主题
    }
    // Spec 049a：多账号加载（含 v1 单 token 迁移）；无账号时 token='' 走 TokenSetup 落地页
    this.applyCurrentAccount();
    // 底栏显隐：仅 Settings 及其下级页面隐藏（走查 09-08 定案）；全局监听页面切换，取切换后的目标页
    uiObserver.on('navDestinationSwitch', this.getUIContext(), (info: uiObserver.NavDestinationSwitchInfo) => {
      // 回到根页时 to 为 'navBar'（读不到 name）→ 视为根页显示底栏
      const dest = info.to as uiObserver.NavDestinationInfo;
      const routeName: string = dest.name !== undefined ? dest.name as string : '';
      this.hideTabBar = TAB_BAR_HIDDEN_ROUTES.includes(routeName);
      // Spec 060：从二级页返回根页且当前停在 tab4 → 静默重取「我的主页」（本页内 star/关注等改动可见）
      if (routeName === '' && this.currentTab === 3) {
        this.profileTick += 1;
      }
      // Spec 056：离开 Filter Activity 页（SAVE 或返回）→ 通知 Explore 重读六类勾选（角标/动态流刷新）
      const fromDest = info.from as uiObserver.NavDestinationInfo;
      const fromName: string = fromDest.name !== undefined ? fromDest.name as string : '';
      if (fromName === 'exploreActivityFilter') {
        this.exploreTick += 1;
      }
    });
  }

  aboutToDisappear(): void {
    uiObserver.off('navDestinationSwitch', this.getUIContext());
  }

  /** 加载当前账号（含 v1 迁移/active 回退）；无账号时 token='' 走落地页 */
  private async applyCurrentAccount(): Promise<void> {
    const ctx = this.getUIContext().getHostContext() as common.Context | undefined;
    const acc = await AccountStore.getCurrentAccount(ctx);
    if (acc === null) {
      this.accounts = [];
      this.currentLogin = '';
      this.token = '';
      this.checked = true;
      // 无账号回落地页：清空二级页栈，避免再次登录后残留页面
      this.pathStack.clear();
      return;
    }
    this.accounts = await AccountStore.loadAccounts(ctx);
    this.currentLogin = acc.login;
    this.token = acc.token;
    this.checked = true;
    this.refreshInboxUnread(acc.token);
    // 切号先清旧头像，等 HomeView 的 viewer 探针回填（防底栏短暂显示上一个账号）
    this.viewerAvatarUrl = '';
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

  /** Inbox 页标记已读/首次配 token 后触发角标重算（review A4：原先仅冷启动算一次） */
  private onInboxUnreadTick(): void {
    if (this.token !== '') {
      this.refreshInboxUnread(this.token);
    }
  }

  @Builder
  userProfileDestination() {
    NavDestination() {
      ProfileView({
        login: this.profileLogin,
        token: this.token,
        pathStack: this.pathStack,
        accounts: this.accounts,
        currentLogin: this.currentLogin,
        onSwitchAccount: (login: string): void => {
          this.switchAccount(login);
        },
        onAddAccount: (): void => {
          this.pathStack.pushPathByName('tokenSetup', '');
        }
      })
    }
    .onReady((context: NavDestinationContext) => {
      const login = context.pathInfo.param as string;
      if (login !== undefined && login !== null && login !== '') {
        this.profileLogin = login;
      }
    })
    .hideTitleBar(true)
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
    .hideTitleBar(true)
  }

  @Builder
  issuesListDestination() {
    NavDestination() {
      IssuesListView({
        owner: this.repoOwner,
        name: this.repoName,
        token: this.token,
        pathStack: this.pathStack,
        returnTick: this.issuesListTick
      })
    }
    .onReady((context: NavDestinationContext) => {
      const full = context.pathInfo.param as string;
      const parts: string[] = full.split('/');
      if (parts.length >= 2) {
        this.repoOwner = parts[0];
        this.repoName = parts[1];
      }
      this.issuesListShownOnce = false;
    })
    // 返回刷新（review B13），首显跳过防双请求
    .onShown(() => {
      if (this.issuesListShownOnce) {
        this.issuesListTick += 1;
      }
      this.issuesListShownOnce = true;
    })
    .hideTitleBar(true)
  }

  @Builder
  settingsDestination() {
    NavDestination() {
      SettingsView({
        pathStack: this.pathStack,
        currentLogin: this.currentLogin,
        // Sign Out = 移除当前账号（官方语义）：Settings 已删除该账号，此处重载剩余账号
        onSignedOut: (): void => {
          this.pathStack.clear();
          this.applyCurrentAccount();
        }
      })
    }
    .hideTitleBar(true)
  }

  /** Spec 049a：Accounts 账号管理页（官方样式：浏览态/EDIT 态/ADD ACCOUNT/红色登出/全部登出） */
  @Builder
  accountsDestination() {
    NavDestination() {
      AccountsView({
        pathStack: this.pathStack,
        accounts: this.accounts,
        currentLogin: this.currentLogin,
        onAddAccount: (): void => {
          this.pathStack.pushPathByName('tokenSetup', '');
        },
        onSwitchAccount: (login: string): void => {
          this.switchAccount(login);
        },
        onAccountChanged: (): void => {
          // 移除/全部登出等结构变更：重载当前账号（被移则自动切第一个；无账号则回落地页）
          this.applyCurrentAccount();
        }
      })
    }
    .hideTitleBar(true)
  }

  /** Spec 049a：添加账号复用 TokenSetup（等价官方 Sign In 页);保存后 pop 回 Accounts */
  @Builder
  tokenSetupDestination() {
    NavDestination() {
      TokenSetup({
        embedded: true,
        onEmbeddedPop: (): void => {
          this.pathStack.pop();
        },
        onSaved: (token: string, login: string): void => {
          this.token = token;
          this.currentLogin = login;
          this.refreshInboxUnread(token);
          this.viewerAvatarUrl = '';
          AppStorage.setOrCreate('accountSwitchTick', Date.now());
          this.reloadAccounts();
          this.pathStack.pop();
        }
      })
    }
    .hideTitleBar(true)
  }

  /** 切换账号：写 active、换 token、重算未读、广播各常驻页刷新 */
  private async switchAccount(login: string): Promise<void> {
    const ctx = this.getUIContext().getHostContext() as common.Context | undefined;
    const token = await AccountStore.switchAccount(ctx, login);
    if (token === '') {
      return;
    }
    this.currentLogin = login;
    this.token = token;
    this.refreshInboxUnread(token);
    this.viewerAvatarUrl = '';
    AppStorage.setOrCreate('accountSwitchTick', Date.now());
    this.reloadAccounts();
  }

  /** 账号增删/改名后同步 Index 层账号列表 */
  private async reloadAccounts(): Promise<void> {
    const ctx = this.getUIContext().getHostContext() as common.Context | undefined;
    this.accounts = await AccountStore.loadAccounts(ctx);
  }

  /** Spec 032：Settings → Notification Options 二级页（自绘头部，不设 .title() 防双标题） */
  @Builder
  notificationSettingsDestination() {
    NavDestination() {
      NotificationSettingsView({
        pathStack: this.pathStack
      })
    }
    .hideTitleBar(true)
  }

  /** Spec 033：Settings → Code Options 二级页（自绘头部，不设 .title() 防双标题） */
  @Builder
  codeOptionsDestination() {
    NavDestination() {
      CodeOptionsView({
        pathStack: this.pathStack
      })
    }
    .hideTitleBar(true)
  }

  /** Spec 064：Settings → Open Source Libraries 开源披露页（静态，自绘头部） */
  @Builder
  openSourceLibrariesDestination() {
    NavDestination() {
      OpenSourceLibrariesView({
        pathStack: this.pathStack
      })
    }
    .hideTitleBar(true)
  }

  /** Spec 069：关于页（Settings → About；Star 引导 + 仓库行 + 备案信息） */
  @Builder
  settingsAboutDestination() {
    NavDestination() {
      SettingsAboutView({
        pathStack: this.pathStack,
        token: this.token,
        tick: this.settingsAboutTick
      })
    }
    // 从详情页返回可见时静默重拉 star 态；首显跳过（aboutToAppear 已拉取，review A6/D17 同款）
    .onShown(() => {
      if (this.settingsAboutShownOnce) {
        this.settingsAboutTick += 1;
      }
      this.settingsAboutShownOnce = true;
    })
    .hideTitleBar(true)
  }

  /** Spec 066：App Lock 设置子页（单 Toggle；Settings 级页面，底栏隐藏） */
  @Builder
  appLockDestination() {
    NavDestination() {
      AppLockSettingsView({
        pathStack: this.pathStack
      })
    }
    .hideTitleBar(true)
  }

  /** Spec 034：用户列表页（login|followers|following 参数） */
  @Builder
  userListDestination() {
    NavDestination() {
      UserListView({
        login: this.listLogin,
        kind: this.listKind,
        token: this.token,
        pathStack: this.pathStack
      })
    }
    .onReady((context: NavDestinationContext) => {
      const full = context.pathInfo.param as string;
      const idx = full.indexOf('|');
      this.listLogin = idx >= 0 ? full.substring(0, idx) : full;
      this.listKind = idx >= 0 ? full.substring(idx + 1) : 'followers';
    })
    .hideTitleBar(true)
  }

  /** Spec 053：Stargazers 列表页（路由参数：owner/name） */
  @Builder
  stargazersDestination() {
    NavDestination() {
      StargazersView({
        owner: this.repoOwner,
        name: this.repoName,
        token: this.token,
        pathStack: this.pathStack
      })
    }
    .onReady((context: NavDestinationContext) => {
      this.parseRouteParam(context.pathInfo.param as string);
    })
    .hideTitleBar(true)
  }

  /** Spec 053：Forks 列表页（路由参数：owner/name） */
  @Builder
  forksDestination() {
    NavDestination() {
      ForksView({
        owner: this.repoOwner,
        name: this.repoName,
        token: this.token,
        pathStack: this.pathStack
      })
    }
    .onReady((context: NavDestinationContext) => {
      this.parseRouteParam(context.pathInfo.param as string);
    })
    .hideTitleBar(true)
  }

  /** Spec 054：Contributors 列表页（路由参数：owner/name；kind 在页内固定） */
  @Builder
  contributorsDestination() {
    NavDestination() {
      RepoPeopleView({
        owner: this.repoOwner,
        name: this.repoName,
        kind: 'contributors',
        token: this.token,
        pathStack: this.pathStack
      })
    }
    .onReady((context: NavDestinationContext) => {
      this.parseRouteParam(context.pathInfo.param as string);
    })
    .hideTitleBar(true)
  }

  /** Spec 054：Watchers 列表页（路由参数：owner/name） */
  @Builder
  watchersDestination() {
    NavDestination() {
      RepoPeopleView({
        owner: this.repoOwner,
        name: this.repoName,
        kind: 'watchers',
        token: this.token,
        pathStack: this.pathStack
      })
    }
    .onReady((context: NavDestinationContext) => {
      this.parseRouteParam(context.pathInfo.param as string);
    })
    .hideTitleBar(true)
  }

  /** Spec 055：License 正文页（路由参数：owner/name） */
  @Builder
  licenseDestination() {
    NavDestination() {
      RepoLicenseView({
        owner: this.repoOwner,
        name: this.repoName,
        token: this.token,
        pathStack: this.pathStack
      })
    }
    .onReady((context: NavDestinationContext) => {
      this.parseRouteParam(context.pathInfo.param as string);
    })
    .hideTitleBar(true)
  }

  /** Spec 052：成就徽章详情页（路由参数：login|startIndex） */
  @Builder
  achievementDetailDestination() {
    NavDestination() {
      AchievementDetailView({
        login: this.achLogin,
        startIndex: this.achStart,
        pathStack: this.pathStack
      })
    }
    .onReady((context: NavDestinationContext) => {
      const full = context.pathInfo.param as string;
      const idx = full.indexOf('|');
      this.achLogin = idx >= 0 ? full.substring(0, idx) : full;
      this.achStart = idx >= 0 ? Number(full.substring(idx + 1)) : 0;
    })
    .hideTitleBar(true)
  }

  /** Spec 035：组织列表页 */
  @Builder
  orgListDestination() {
    NavDestination() {
      OrgListView({
        login: this.orgLogin,
        token: this.token,
        pathStack: this.pathStack
      })
    }
    .onReady((context: NavDestinationContext) => {
      this.orgLogin = context.pathInfo.param as string;
    })
    .hideTitleBar(true)
  }

  /** Spec 036：组织主页 */
  @Builder
  orgProfileDestination() {
    NavDestination() {
      OrgProfileView({
        login: this.orgLogin,
        token: this.token,
        pathStack: this.pathStack
      })
    }
    .onReady((context: NavDestinationContext) => {
      this.orgLogin = context.pathInfo.param as string;
    })
    .hideTitleBar(true)
  }

  /** Spec 037：通用仓库列表页（owner|org|user 参数） */
  @Builder
  repositoriesListDestination() {
    NavDestination() {
      RepositoriesListView({
        owner: this.reposOwner,
        mode: this.reposMode,
        token: this.token,
        pathStack: this.pathStack
      })
    }
    .onReady((context: NavDestinationContext) => {
      const full = context.pathInfo.param as string;
      const idx = full.indexOf('|');
      this.reposOwner = idx >= 0 ? full.substring(0, idx) : full;
      this.reposMode = idx >= 0 ? full.substring(idx + 1) : 'org';
    })
    .hideTitleBar(true)
  }

  @Builder
  searchDestination() {
    NavDestination() {
      SearchView({
        token: this.token,
        login: this.currentLogin,
        pathStack: this.pathStack
      })
    }
    .hideTitleBar(true)
  }

  /** Spec 015 v2：搜索结果页（路由参数：kind|keyword） */
  @Builder
  searchResultsDestination() {
    NavDestination() {
      SearchResultsView({
        kind: this.searchKind,
        keyword: this.searchKeyword,
        token: this.token,
        login: this.currentLogin,
        pathStack: this.pathStack
      })
    }
    .onReady((context: NavDestinationContext) => {
      const full = context.pathInfo.param as string;
      const idx = full.indexOf('|');
      this.searchKind = idx >= 0 ? full.substring(0, idx) : 'repositories';
      this.searchKeyword = idx >= 0 ? full.substring(idx + 1) : full;
    })
    .hideTitleBar(true)
  }

  /** Spec 046：搜索聚合结果页（路由参数：keyword，回车直进） */
  @Builder
  searchOverviewDestination() {
    NavDestination() {
      SearchOverviewView({
        keyword: this.searchKeyword,
        token: this.token,
        login: this.currentLogin,
        pathStack: this.pathStack
      })
    }
    .onReady((context: NavDestinationContext) => {
      this.searchKeyword = context.pathInfo.param as string;
    })
    .hideTitleBar(true)
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
    .hideTitleBar(true)
  }

  @Builder
  favoritesEditDestination() {
    NavDestination() {
      FavoritesEditView({
        token: this.token,
        pathStack: this.pathStack,
        onSaved: (): void => {
          this.homeFavoritesVersion += 1;
        }
      })
    }
    .hideTitleBar(true)
  }

  /** Spec 074：Shortcuts 管理页（官方两截图均带底部 Tab，不进 TAB_BAR_HIDDEN_ROUTES） */
  @Builder
  shortcutsDestination() {
    NavDestination() {
      ShortcutsView({
        token: this.token,
        pathStack: this.pathStack,
        onSaved: (): void => {
          this.homeShortcutsVersion += 1;
        }
      })
    }
    .hideTitleBar(true)
  }

  /** Spec 074：Create Shortcut 编辑页（路由参数 = 预填 JSON，空串为默认态） */
  @Builder
  shortcutCreateDestination() {
    NavDestination() {
      ShortcutCreateView({
        token: this.token,
        pathStack: this.pathStack,
        prefill: this.shortcutPrefill,
        repoTick: this.shortcutRepoTick,
        onSaved: (): void => {
          this.homeShortcutsVersion += 1;
        }
      })
    }
    .onReady((context: NavDestinationContext) => {
      this.shortcutPrefill = context.pathInfo.param as string;
    })
    .onShown(() => {
      // 选仓库页（shortcutRepoPicker）pop 回时触发；首显也触发，回传槽为空则视图内忽略
      this.shortcutRepoTick += 1;
    })
    .hideTitleBar(true)
  }

  /** Spec 074：Choose a repository 选仓库页（创建页 Scope 菜单 → Choose Repository；
   *  官方截图带底部 Tab，不进 TAB_BAR_HIDDEN_ROUTES，与 issue 动线 repoPicker 分路由） */
  @Builder
  shortcutRepoPickerDestination() {
    NavDestination() {
      RepoPickerView({
        token: this.token,
        pathStack: this.pathStack,
        pRole: 'shortcut'
      })
    }
    .hideTitleBar(true)
  }

  @Builder
  workIssuesDestination() {
    NavDestination() {
      WorkIssuesView({
        token: this.token,
        pathStack: this.pathStack,
        returnTick: this.workIssuesTick
      })
    }
    .onReady(() => {
      this.workIssuesShownOnce = false;
    })
    // 返回刷新（review B13），首显跳过防双请求
    .onShown(() => {
      if (this.workIssuesShownOnce) {
        this.workIssuesTick += 1;
      }
      this.workIssuesShownOnce = true;
    })
    .hideTitleBar(true)
  }

  @Builder
  workPrsDestination() {
    NavDestination() {
      WorkPrsView({
        token: this.token,
        pathStack: this.pathStack,
        returnTick: this.workPrsTick
      })
    }
    .onReady(() => {
      this.workPrsShownOnce = false;
    })
    // 返回刷新（review B13），首显跳过防双请求
    .onShown(() => {
      if (this.workPrsShownOnce) {
        this.workPrsTick += 1;
      }
      this.workPrsShownOnce = true;
    })
    .hideTitleBar(true)
  }

  @Builder
  discussionsDestination() {
    NavDestination() {
      DiscussionsView({
        token: this.token,
        pathStack: this.pathStack,
        repo: this.repoForDiscussions
      })
    }
    .onReady((context: NavDestinationContext) => {
      // 参数=单仓库 'owner/name'（Share Feedback 入口）；空参=全局工作区语义
      this.repoForDiscussions = (context.pathInfo.param as string) ?? '';
    })
    .hideTitleBar(true)
  }

  @Builder
  projectsDestination() {
    NavDestination() {
      ProjectsView({
        token: this.token,
        pathStack: this.pathStack
      })
    }
    .hideTitleBar(true)
  }

  @Builder
  topReposDestination() {
    NavDestination() {
      TopRepositoriesView({
        token: this.token,
        pathStack: this.pathStack
      })
    }
    .hideTitleBar(true)
  }

  @Builder
  organizationsDestination() {
    NavDestination() {
      OrganizationsView({
        token: this.token,
        pathStack: this.pathStack
      })
    }
    .hideTitleBar(true)
  }

  @Builder
  starredDestination() {
    NavDestination() {
      StarredRepositoriesView({
        token: this.token,
        login: this.starredLogin,
        pathStack: this.pathStack,
        listsTick: this.starredListsTick
      })
    }
    .onReady((context: NavDestinationContext) => {
      this.starredLogin = context.pathInfo.param as string;
      this.starredShownOnce = false;
    })
    // 子页（Create list）pop 回时重取 My lists；首显跳过（aboutToAppear 已拉取，review A6/D17）
    .onShown(() => {
      if (this.starredShownOnce) {
        this.starredListsTick += 1;
      }
      this.starredShownOnce = true;
    })
    .hideTitleBar(true)
  }

  @Builder
  createListDestination() {
    NavDestination() {
      CreateListView({
        token: this.token,
        pathStack: this.pathStack,
        editListId: this.createListEditId
      })
    }
    .onReady((context: NavDestinationContext) => {
      this.createListEditId = context.pathInfo.param as string;
    })
    .hideTitleBar(true)
  }

  @Builder
  listDetailDestination() {
    NavDestination() {
      ListDetailView({
        token: this.token,
        pathStack: this.pathStack,
        listId: this.listDetailId,
        isOwn: this.listDetailOwn,
        listTick: this.listDetailTick
      })
    }
    .onReady((context: NavDestinationContext) => {
      // `|0` 后缀 = 他人列表（Starred 他人页入口，只读）；无标记默认本人列表
      const raw = context.pathInfo.param as string;
      const sep = raw.lastIndexOf('|');
      if (sep >= 0) {
        this.listDetailId = raw.substring(0, sep);
        this.listDetailOwn = raw.substring(sep + 1) !== '0';
      } else {
        this.listDetailId = raw;
        this.listDetailOwn = true;
      }
      this.listDetailShownOnce = false;
    })
    // Edit 页 pop 回时重取列表详情；首显跳过（listId 变化已触发首载，review A6/D17）
    .onShown(() => {
      if (this.listDetailShownOnce) {
        this.listDetailTick += 1;
      }
      this.listDetailShownOnce = true;
    })
    .hideTitleBar(true)
  }

  /** 路由参数解析：owner/name[/number] */
  private parseRouteParam(param: string): void {
    const parts = param.split('/');
    if (parts.length >= 2) {
      this.repoOwner = parts[0];
      this.repoName = parts[1];
    }
    if (parts.length >= 3) {
      // 第 3 段起整体还原（release tag 可能含 /）
      const rest = parts.slice(2).join('/');
      this.detailNumber = Number(rest);
      this.releaseTag = rest;
    } else {
      // 不足 3 段时显式重置，避免残留上一次路由的 detailNumber（如 2 段路由走了 PR 分支）
      this.detailNumber = 0;
      this.releaseTag = '';
    }
  }

  /** Spec 043 表单路由参数解析：owner|name|mode|editNumber|templateName|base|head（owner/name 可空=Home 入口先选仓库） */
  private parseFormParam(param: string): void {
    const parts = param.split('|');
    this.formOwner = parts.length > 0 ? parts[0] : '';
    this.formName = parts.length > 1 ? parts[1] : '';
    this.formMode = parts.length > 2 && parts[2] !== '' ? parts[2] : 'new';
    const n = parts.length > 3 ? Number(parts[3]) : 0;
    this.formEditNumber = isNaN(n) ? 0 : n;
    this.formTemplate = parts.length > 4 ? parts[4] : '';
    this.formBase = parts.length > 5 ? parts[5] : '';
    this.formHead = parts.length > 6 ? parts[6] : '';
  }

  /** Spec 043 分支选择页路由参数解析：role|owner|name|current */
  private parsePickerParam(param: string): void {
    const parts = param.split('|');
    this.pickerRole = parts.length > 0 ? parts[0] : '';
    this.pickerOwner = parts.length > 1 ? parts[1] : '';
    this.pickerName = parts.length > 2 ? parts[2] : '';
    this.pickerCurrent = parts.length > 3 ? parts[3] : '';
  }

  @Builder
  repoPrsDestination() {
    NavDestination() {
      RepoPrsView({
        owner: this.repoOwner,
        name: this.repoName,
        token: this.token,
        pathStack: this.pathStack,
        returnTick: this.repoPrsTick
      })
    }
    .onReady((context: NavDestinationContext) => {
      this.parseRouteParam(context.pathInfo.param as string);
      this.repoPrsShownOnce = false;
    })
    // 返回刷新（review B13），首显跳过防双请求
    .onShown(() => {
      if (this.repoPrsShownOnce) {
        this.repoPrsTick += 1;
      }
      this.repoPrsShownOnce = true;
    })
    .hideTitleBar(true)
  }

  @Builder
  repoCommitsDestination() {
    NavDestination() {
      RepoCommitsView({
        owner: this.repoOwner,
        name: this.repoName,
        prNumber: this.detailNumber,
        token: this.token,
        pathStack: this.pathStack
      })
    }
    .onReady((context: NavDestinationContext) => {
      this.parseRouteParam(context.pathInfo.param as string);
    })
    .hideTitleBar(true)
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
    .hideTitleBar(true)
  }

  /** Spec 047：Release 详情（参数 owner/name/tag，tag 可含 /） */
  @Builder
  releaseDetailDestination() {
    NavDestination() {
      ReleaseDetailView({
        owner: this.repoOwner,
        name: this.repoName,
        tag: this.releaseTag,
        token: this.token,
        pathStack: this.pathStack
      })
    }
    .onReady((context: NavDestinationContext) => {
      this.parseRouteParam(context.pathInfo.param as string);
    })
    .hideTitleBar(true)
  }

  /** Reactees 页参数：首段=编码后的 subjectId（base64 可能含 /，编码后安全），次段=content */
  private parseReactionUsersParam(param: string): void {
    const parts: string[] = param.split('/');
    this.reactionSubjectId = parts.length > 0 ? decodeURIComponent(parts[0]) : '';
    this.reactionContent = parts.length > 1 ? parts[1] : '';
  }

  /** Spec 047：release 反应用户整页（emoji + Reactees 两行头） */
  @Builder
  reactionUsersDestination() {
    NavDestination() {
      ReactionUsersView({
        subjectId: this.reactionSubjectId,
        content: this.reactionContent,
        token: this.token,
        pathStack: this.pathStack
      })
    }
    .onReady((context: NavDestinationContext) => {
      this.parseReactionUsersParam(context.pathInfo.param as string);
    })
    .hideTitleBar(true)
  }

  /** 文件路由参数解析：owner|name|path（path 可为空 = 根目录） */
  private parseFileParam(param: string): void {
    const parts: string[] = param.split('|');
    this.fileOwner = parts.length > 0 ? parts[0] : '';
    this.fileRepo = parts.length > 1 ? parts[1] : '';
    this.filePath = parts.length > 2 ? parts[2] : '';
  }

  /** Spec 038：仓库文件树（自绘头部，不设 .title() 防双标题） */
  @Builder
  repoFilesDestination() {
    NavDestination() {
      FileTreeView({
        owner: this.fileOwner,
        name: this.fileRepo,
        dirPath: this.filePath,
        token: this.token,
        pathStack: this.pathStack
      })
    }
    .onReady((context: NavDestinationContext) => {
      this.parseFileParam(context.pathInfo.param as string);
    })
    .hideTitleBar(true)
  }

  /** Spec 011：代码查看器（自绘头部，不设 .title() 防双标题） */
  @Builder
  codeViewerDestination() {
    NavDestination() {
      CodeViewerView({
        owner: this.fileOwner,
        name: this.fileRepo,
        filePath: this.filePath,
        token: this.token,
        pathStack: this.pathStack,
        codeOptionsTick: this.codeOptionsTick
      })
    }
    .onReady((context: NavDestinationContext) => {
      this.parseFileParam(context.pathInfo.param as string);
    })
    .onShown(() => {
      this.codeOptionsTick += 1;
    })
    .hideTitleBar(true)
  }

  @Builder
  issueDetailDestination() {
    NavDestination() {
      IssueDetailView({
        owner: this.repoOwner,
        name: this.repoName,
        number: this.detailNumber,
        token: this.token,
        pathStack: this.pathStack,
        refreshTick: this.issueDetailTick
      })
    }
    .onReady((context: NavDestinationContext) => {
      this.parseRouteParam(context.pathInfo.param as string);
    })
    // 返回刷新（编辑表单 pop 回后重拉标题/正文，Spec 043）；首显由页内 skipFirstTick 跳过
    .onShown(() => {
      this.issueDetailTick += 1;
    })
    .hideTitleBar(true)
  }

  /** Spec 043：新建/编辑 Issue 表单（参数 owner|name|mode|editNumber|templateName） */
  @Builder
  issueFormDestination() {
    NavDestination() {
      IssueFormView({
        token: this.token,
        pathStack: this.pathStack,
        fOwner: this.formOwner,
        fName: this.formName,
        fMode: this.formMode,
        fEditNumber: this.formEditNumber,
        fTemplate: this.formTemplate
      })
    }
    .onReady((context: NavDestinationContext) => {
      this.parseFormParam(context.pathInfo.param as string);
    })
    .hideTitleBar(true)
  }

  /** Spec 043：Choose Template 选模板页（参数 owner|name；有官方模板的仓库才入此页） */
  @Builder
  templatePickerDestination() {
    NavDestination() {
      TemplatePickerView({
        token: this.token,
        pathStack: this.pathStack,
        tpOwner: this.formOwner,
        tpName: this.formName
      })
    }
    .onReady((context: NavDestinationContext) => {
      this.parseFormParam(context.pathInfo.param as string);
    })
    .hideTitleBar(true)
  }

  /** Spec 043：Choose a repository 选仓库页（Home「+」→ Create Issue 第一跳） */
  @Builder
  repoPickerDestination() {
    NavDestination() {
      RepoPickerView({
        token: this.token,
        pathStack: this.pathStack
      })
    }
    .hideTitleBar(true)
  }

  /** Spec 043：Compare changes 页（参数 owner|name；New PR 动线第一跳） */
  @Builder
  prCompareDestination() {
    NavDestination() {
      PrCompareView({
        token: this.token,
        pathStack: this.pathStack,
        fOwner: this.formOwner,
        fName: this.formName,
        refreshTick: this.prCompareTick
      })
    }
    .onReady((context: NavDestinationContext) => {
      this.parseFormParam(context.pathInfo.param as string);
    })
    .onShown(() => {
      // 分支选择页 pop 回时触发；首显也触发一次，回传槽为空则视图内忽略
      this.prCompareTick += 1;
    })
    .hideTitleBar(true)
  }

  /** Spec 043：Choose Branch / Choose head ref 分支选择页（参数 role|owner|name|current） */
  @Builder
  branchPickerDestination() {
    NavDestination() {
      BranchPickerView({
        token: this.token,
        pathStack: this.pathStack,
        pRole: this.pickerRole,
        pOwner: this.pickerOwner,
        pName: this.pickerName,
        pCurrent: this.pickerCurrent
      })
    }
    .onReady((context: NavDestinationContext) => {
      this.parsePickerParam(context.pathInfo.param as string);
    })
    .hideTitleBar(true)
  }

  /** Spec 043：Start pull request / 编辑 PR 表单（参数 owner|name|mode|editNumber||base|head） */
  @Builder
  prFormDestination() {
    NavDestination() {
      PrFormView({
        token: this.token,
        pathStack: this.pathStack,
        fOwner: this.formOwner,
        fName: this.formName,
        fMode: this.formMode,
        fEditNumber: this.formEditNumber,
        fBase: this.formBase,
        fHead: this.formHead
      })
    }
    .onReady((context: NavDestinationContext) => {
      this.parseFormParam(context.pathInfo.param as string);
    })
    .hideTitleBar(true)
  }

  @Builder
  prDetailDestination() {
    NavDestination() {
      PrDetailView({
        owner: this.repoOwner,
        name: this.repoName,
        number: this.detailNumber,
        token: this.token,
        pathStack: this.pathStack,
        refreshTick: this.prDetailTick
      })
    }
    .onReady((context: NavDestinationContext) => {
      this.parseRouteParam(context.pathInfo.param as string);
    })
    .onShown(() => {
      this.prDetailTick += 1;
    })
    .hideTitleBar(true)
  }

  /** Spec 010：PR 文件变更页（路由参数：owner/name/number） */
  @Builder
  prFilesDestination() {
    NavDestination() {
      PrFilesView({
        owner: this.repoOwner,
        name: this.repoName,
        number: this.detailNumber,
        token: this.token,
        pathStack: this.pathStack,
        refreshTick: this.prFilesTick
      })
    }
    .onReady((context: NavDestinationContext) => {
      this.parseRouteParam(context.pathInfo.param as string);
    })
    .onShown(() => {
      this.prFilesTick += 1;
    })
    .hideTitleBar(true)
  }

  /** Spec 048：Checks 全量页（路由参数：owner/name/number|perm，perm=重跑权限门透传详情页） */
  @Builder
  prChecksDestination() {
    NavDestination() {
      PrChecksView({
        owner: this.repoOwner,
        name: this.repoName,
        number: this.detailNumber,
        token: this.token,
        perm: this.checkPerm,
        pathStack: this.pathStack,
        refreshTick: this.prChecksTick
      })
    }
    .onReady((context: NavDestinationContext) => {
      // 参数格式 owner/name/number|perm：parseRouteParam 按 '/' 分段后再拆 perm
      const full = context.pathInfo.param as string;
      const parts: string[] = full.split('/');
      if (parts.length >= 2) {
        this.repoOwner = parts[0];
        this.repoName = parts[1];
      }
      const tail: string[] = parts.length >= 3 ? parts[2].split('|') : [];
      this.detailNumber = tail.length > 0 && tail[0] !== '' ? Number(tail[0]) : 0;
      this.checkPerm = tail.length > 1 ? tail[1] : '';
      this.prChecksShownOnce = false;
    })
    .onShown(() => {
      if (this.prChecksShownOnce) {
        this.prChecksTick += 1;
      }
      this.prChecksShownOnce = true;
    })
    .hideTitleBar(true)
  }

  /** Spec 048：run 汇总页（路由参数 owner/name/runId|perm|appLogo；appLogo 为 URL 含 '/'，尾段须先拼回再拆 '|'） */
  @Builder
  runSummaryDestination() {
    NavDestination() {
      RunSummaryView({
        owner: this.repoOwner,
        name: this.repoName,
        runId: this.runSummaryId,
        perm: this.checkPerm,
        appLogo: this.checkAppLogo,
        token: this.token,
        pathStack: this.pathStack,
        refreshTick: this.runSummaryTick
      })
    }
    .onReady((context: NavDestinationContext) => {
      const parts = (context.pathInfo.param as string).split('/');
      this.repoOwner = parts.length > 0 ? parts[0] : '';
      this.repoName = parts.length > 1 ? parts[1] : '';
      const tail: string[] = parts.length >= 3 ? parts.slice(2).join('/').split('|') : [];
      this.runSummaryId = tail.length > 0 && tail[0] !== '' ? Number(tail[0]) : 0;
      this.checkPerm = tail.length > 1 ? tail[1] : '';
      this.checkAppLogo = tail.length > 2 ? tail[2] : '';
      this.runSummaryShownOnce = false;
    })
    .onShown(() => {
      if (this.runSummaryShownOnce) {
        this.runSummaryTick += 1;
      }
      this.runSummaryShownOnce = true;
    })
    .hideTitleBar(true)
  }

  /** Spec 048：Check run 详情页（路由参数：owner|name|checkRunId|perm|jobName|appLogo|detailsUrl） */
  @Builder
  checkRunDetailDestination() {
    NavDestination() {
      CheckRunDetailView({
        owner: this.repoOwner,
        name: this.repoName,
        checkRunId: this.checkRunId,
        perm: this.checkPerm,
        jobName: this.checkJobName,
        appLogo: this.checkAppLogo,
        detailsUrl: this.checkDetailsUrl,
        token: this.token,
        pathStack: this.pathStack,
        refreshTick: this.checkRunTick
      })
    }
    .onReady((context: NavDestinationContext) => {
      const parts = (context.pathInfo.param as string).split('|');
      this.repoOwner = parts.length > 0 ? parts[0] : '';
      this.repoName = parts.length > 1 ? parts[1] : '';
      this.checkRunId = parts.length > 2 ? Number(parts[2]) : 0;
      this.checkPerm = parts.length > 3 ? parts[3] : '';
      this.checkJobName = parts.length > 4 ? parts[4] : '';
      this.checkAppLogo = parts.length > 5 ? parts[5] : '';
      this.checkDetailsUrl = parts.length > 6 ? parts[6] : '';
      this.checkRunShownOnce = false;
    })
    .onShown(() => {
      if (this.checkRunShownOnce) {
        this.checkRunTick += 1;
      }
      this.checkRunShownOnce = true;
    })
    .hideTitleBar(true)
  }

  /** Commit 详情页（路由参数：owner/name/oid） */
  @Builder
  commitDetailDestination() {
    NavDestination() {
      CommitDetailView({
        owner: this.repoOwner,
        name: this.repoName,
        oid: this.commitOid,
        token: this.token,
        pathStack: this.pathStack,
        codeOptionsTick: this.codeOptionsTick
      })
    }
    .onReady((context: NavDestinationContext) => {
      const parts = (context.pathInfo.param as string).split('/');
      this.repoOwner = parts[0];
      this.repoName = parts[1];
      this.commitOid = parts.length >= 3 ? parts[2] : '';
    })
    .onShown(() => {
      this.codeOptionsTick += 1;
    })
    .hideTitleBar(true)
  }

  /** Spec 056：Explore Trending/Awesome 列表页（路由参数：kind） */
  @Builder
  exploreRepoListDestination() {
    NavDestination() {
      ExploreRepoListView({
        kind: this.exploreListKind,
        token: this.token,
        pathStack: this.pathStack
      })
    }
    .onReady((context: NavDestinationContext) => {
      const kind = context.pathInfo.param as string;
      this.exploreListKind = kind === 'awesome' ? 'awesome' : 'trending';
    })
    .hideTitleBar(true)
  }

  /** Spec 056 收口：Explore Activity 类型筛选页（Filter Activity，六类勾选 + SAVE） */
  @Builder
  exploreActivityFilterDestination() {
    NavDestination() {
      FilterActivityView({
        token: this.token,
        pathStack: this.pathStack
      })
    }
    .hideTitleBar(true)
  }

  /** 应用内浏览器页（路由参数=标题|URL；标题来源见调用方） */
  @Builder
  inAppBrowserDestination() {
    NavDestination() {
      InAppBrowserView({
        title: this.browserTitle,
        url: this.browserUrl,
        pathStack: this.pathStack
      })
    }
    .onReady((context: NavDestinationContext) => {
      const raw = context.pathInfo.param as string;
      const idx = raw.indexOf('|');
      this.browserTitle = idx >= 0 ? raw.substring(0, idx) : raw;
      this.browserUrl = idx >= 0 ? raw.substring(idx + 1) : '';
    })
    .hideTitleBar(true)
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
    } else if (name === 'accounts') {
      this.accountsDestination()
    } else if (name === 'tokenSetup') {
      this.tokenSetupDestination()
    } else if (name === 'notificationSettings') {
      this.notificationSettingsDestination()
    } else if (name === 'codeOptions') {
      this.codeOptionsDestination()
    } else if (name === 'openSourceLibraries') {
      this.openSourceLibrariesDestination()
    } else if (name === 'settingsAbout') {
      this.settingsAboutDestination()
    } else if (name === 'appLock') {
      this.appLockDestination()
    } else if (name === 'userList') {
      this.userListDestination()
    } else if (name === 'orgList') {
      this.orgListDestination()
    } else if (name === 'orgProfile') {
      this.orgProfileDestination()
    } else if (name === 'repositoriesList') {
      this.repositoriesListDestination()
    } else if (name === 'search') {
      this.searchDestination()
    } else if (name === 'searchOverview') {
      this.searchOverviewDestination()
    } else if (name === 'searchResults') {
      this.searchResultsDestination()
    } else if (name === 'editMyWork') {
      this.editMyWorkDestination()
    } else if (name === 'favoritesEdit') {
      this.favoritesEditDestination()
    } else if (name === 'shortcuts') {
      this.shortcutsDestination()
    } else if (name === 'shortcutCreate') {
      this.shortcutCreateDestination()
    } else if (name === 'workIssues') {
      this.workIssuesDestination()
    } else if (name === 'workPrs') {
      this.workPrsDestination()
    } else if (name === 'discussions') {
      this.discussionsDestination()
    } else if (name === 'repoDiscussions') {
      // Spec 065：Settings → Share feedback 专用名（底栏隐藏列表只挂它，不影响 My Work 的全局 discussions）
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
    } else if (name === 'releaseDetail') {
      this.releaseDetailDestination()
    } else if (name === 'reactionUsers') {
      this.reactionUsersDestination()
    } else if (name === 'issueDetail') {
      this.issueDetailDestination()
    } else if (name === 'issueForm') {
      this.issueFormDestination()
    } else if (name === 'templatePicker') {
      this.templatePickerDestination()
    } else if (name === 'repoPicker') {
      this.repoPickerDestination()
    } else if (name === 'shortcutRepoPicker') {
      this.shortcutRepoPickerDestination()
    } else if (name === 'prCompare') {
      this.prCompareDestination()
    } else if (name === 'branchPicker') {
      this.branchPickerDestination()
    } else if (name === 'prForm') {
      this.prFormDestination()
    } else if (name === 'prDetail') {
      this.prDetailDestination()
    } else if (name === 'repoFiles') {
      this.repoFilesDestination()
    } else if (name === 'codeViewer') {
      this.codeViewerDestination()
    } else if (name === 'createList') {
      this.createListDestination()
    } else if (name === 'listDetail') {
      this.listDetailDestination()
    } else if (name === 'stargazers') {
      this.stargazersDestination()
    } else if (name === 'forks') {
      this.forksDestination()
    } else if (name === 'contributors') {
      this.contributorsDestination()
    } else if (name === 'watchers') {
      this.watchersDestination()
    } else if (name === 'license') {
      this.licenseDestination()
    } else if (name === 'achievementDetail') {
      this.achievementDetailDestination()
    } else if (name === 'prFiles') {
      this.prFilesDestination()
    } else if (name === 'prChecks') {
      this.prChecksDestination()
    } else if (name === 'checkRunDetail') {
      this.checkRunDetailDestination()
    } else if (name === 'runSummary') {
      this.runSummaryDestination()
    } else if (name === 'commitDetail') {
      this.commitDetailDestination()
    } else if (name === 'exploreRepoList') {
      this.exploreRepoListDestination()
    } else if (name === 'exploreActivityFilter') {
      this.exploreActivityFilterDestination()
    } else if (name === 'inAppBrowser') {
      this.inAppBrowserDestination()
    }
  }

  @Builder
  mainTabs() {
    Tabs({ barPosition: BarPosition.End, controller: this.tabController }) {
      TabContent() {
        HomeView({
          token: this.token,
          pathStack: this.pathStack,
          workVersion: this.homeWorkVersion,
          favoritesVersion: this.homeFavoritesVersion,
          shortcutsVersion: this.homeShortcutsVersion,
          onViewer: (avatarUrl: string): void => {
            // Spec 060：底栏 tab4 头像复用 Home 的 viewer 探针结果（全应用只发一次 viewer 查询）
            this.viewerAvatarUrl = avatarUrl;
          }
        })
      }

      TabContent() {
        InboxView({ token: this.token })
      }

      TabContent() {
        ExploreView({ token: this.token, pathStack: this.pathStack, exploreTick: this.exploreTick })
      }

      // Spec 060：tab4 = 当前账号个人主页（头像即 Tab 图标，与三 Tab 同为真 Tab）。
      // 他人主页仍走 userProfile 压栈路由，两者语义分开：底栏进「我的」，列表进「他的」。
      TabContent() {
        ProfileView({
          login: this.currentLogin,
          token: this.token,
          pathStack: this.pathStack,
          accounts: this.accounts,
          currentLogin: this.currentLogin,
          showBack: false,
          refreshTick: this.profileTick,
          onSwitchAccount: (login: string): void => {
            this.switchAccount(login);
          },
          onAddAccount: (): void => {
            this.pathStack.pushPathByName('tokenSetup', '');
          }
        })
      }
    }
    .onChange((index: number) => {
      this.currentTab = index;
      // Spec 060：切回 tab4「我的主页」时静默重取（别处 star/关注后回到本页不是旧数据）
      if (index === 3) {
        this.profileTick += 1;
      }
    })
    .barHeight(0)
    .width('100%')
    .height('100%')
  }

  @Builder
  tabItem(iconRes: Resource, iconResSelected: Resource, labelRes: Resource, index: number) {
    Column({ space: 2 }) {
      Stack({ alignContent: Alignment.Center }) {
        if (this.currentTab === index) {
          // 选中态胶囊底（官方浅蓝）
          Column()
            .width(56)
            .height(32)
            .borderRadius(16)
            .backgroundColor($r('app.color.tab_active_bg'))
        }
        Stack({ alignContent: Alignment.TopEnd }) {
          OctIcon({
            res: this.currentTab === index ? iconResSelected : iconRes,
            iconSize: 20,
            iconColor: this.currentTab === index ? $r('app.color.link_blue') : $r('app.color.text_secondary')
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
      }
      .width('100%')
      .height(32)
      Text(labelRes)
        .fontSize($r('app.float.caption_font_size'))
        .fontColor(this.currentTab === index ? $r('app.color.link_blue') : $r('app.color.text_secondary'))
    }
    .width('25%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      // 先立即点亮选中态（currentTab 若等 onChange 会延迟到切换动画结束后）
      this.currentTab = index;
      // 底栏全局常驻：切 tab 时清空二级页栈回根（官方 App 点 tab 回首个页面）
      this.pathStack.clear();
      this.tabController.changeIndex(index);
    })
  }

  /** Spec 060：底栏 tab4 = 当前账号个人主页 Tab——头像即图标，与三 Tab 同胶囊选中态。
   *  尺寸对齐兄弟图标（iconSize 20）；头像未拉到/失败时走 heat_empty 占位圆。 */
  @Builder
  avatarTabItem() {
    Column({ space: 2 }) {
      Stack({ alignContent: Alignment.Center }) {
        if (this.currentTab === 3) {
          // 选中态胶囊底（官方浅蓝，与三 Tab 同一容器尺寸）
          Column()
            .width(56)
            .height(32)
            .borderRadius(16)
            .backgroundColor($r('app.color.tab_active_bg'))
        }
        Image(this.viewerAvatarUrl)
          .width(20)
          .height(20)
          .borderRadius(10)
          .backgroundColor($r('app.color.heat_empty'))
      }
      .width('100%')
      .height(32)
      Text($r('app.string.tab_me'))
        .fontSize($r('app.float.caption_font_size'))
        .fontColor(this.currentTab === 3 ? $r('app.color.link_blue') : $r('app.color.text_secondary'))
    }
    .width('25%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .accessibilityDescription($r('app.string.tab_me'))
    .onClick(() => {
      this.currentTab = 3;
      this.pathStack.clear();
      this.tabController.changeIndex(3);
    })
  }

  build() {
    Stack() {
      if (!this.checked || !this.splashMinElapsed) {
        // 开屏品牌页：大 logo 居中（系统 startWindow 只出纯色底，logo 由首帧自绘放大呈现；
        // 背景色与 bg_page 一致，系统开屏→本页无缝衔接）
        Column() {
          Image($r('app.media.foreground'))
            .width(220)
            .height(220)
            .opacity(this.splashOpacity)
            .scale({ x: this.splashScale, y: this.splashScale })
        }
        .justifyContent(FlexAlign.Center)
        .width('100%')
        .height('100%')
        .backgroundColor($r('app.color.start_window_background'))
      } else if (this.token === '') {
        TokenSetup({
          onSaved: (token: string, login: string): void => {
            this.token = token;
            this.currentLogin = login;
            // 首次配置 token 后立即拉取未读角标，不等重启（review A4）
            this.refreshInboxUnread(token);
            this.viewerAvatarUrl = '';
            AppStorage.setOrCreate('accountSwitchTick', Date.now());
            this.reloadAccounts();
          }
        })
      } else {
        // 全局壳：Navigation（三 Tab 内容 + 二级页栈）+ 常驻自绘底栏（官方浮层样式）
        Column() {
          Navigation(this.pathStack) {
            this.mainTabs()
          }
          .mode(NavigationMode.Stack)
          .hideTitleBar(true)
          .navDestination(this.destinationMap)
          .width('100%')
          .layoutWeight(1)

          // 自绘底栏：白底 + 上投影 + 选中胶囊；选中态图标用官方 fill 变体
          // （tab4「我的主页」同规则：胶囊底 + 蓝色标签，图标为当前账号头像，见 Spec 060）
          // 键盘弹起（搜索输入）时隐藏——键盘上方不显示 tab（用户 09-04 要求）；
          // Settings 及其下级页面 + 模态全屏页隐藏（hideTabBar，navDestinationSwitch 驱动）
          if (!this.keyboardOn && !this.hideTabBar) {
            Row() {
              this.tabItem($r('app.media.oct_home_16'), $r('app.media.oct_home_fill_16'), $r('app.string.tab_home'), 0)
              this.tabItem($r('app.media.oct_inbox_16'), $r('app.media.oct_inbox_fill_16'), $r('app.string.tab_inbox'), 1)
              this.tabItem($r('app.media.oct_telescope_16'), $r('app.media.oct_telescope_fill_16'), $r('app.string.tab_explore'), 2)
              this.avatarTabItem()
            }
            .width('100%')
            .height(56)
            .backgroundColor($r('app.color.card_background'))
            .border({ width: { top: 1 }, color: $r('app.color.divider') })
          }
        }
        .width('100%')
        .height('100%')
      }

      // Spec 066：App Lock 锁定遮罩——Stack 顶层，盖住 Navigation 与底栏；
      // 仅登录后生效（登录页/开屏无需锁，锁定在 EntryAbility 冷启动/退后台时置位）
      if (this.token !== '' && this.appLockLocked) {
        AppLockOverlay()
      }
    }
    .width('100%')
    .height('100%')
  }
}
