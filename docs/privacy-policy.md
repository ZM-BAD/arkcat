# ArkCat 隐私政策 / ArkCat Privacy Policy

> 适用应用：ArkCat（包名 `me.zmbad.arkcat`）
> 生效日期：2026-09-10 ｜ 最后更新：2026-09-10
> 本应用是开源的第三方客户端，**不是 GitHub 官方应用**，与 GitHub, Inc. 无隶属或合作关系。

---

## 中文

### 一、我们是谁

ArkCat 由个人开发者 **周铭** 开发与维护。如对本政策有疑问，可通过以下方式联系我们：

- 联系邮箱：<prozm.bad@gmail.com>
- 项目仓库：<https://github.com/ZM-BAD/arkcat>

### 二、我们收集和使用的信息

**本应用没有自建服务器，不会把你的任何信息上传到开发者控制的服务器。** 所有数据要么只保存在你的设备本地，要么由你的设备直接发送至你授权访问的 GitHub。

| 信息类型 | 具体内容 | 用途 | 存放位置 |
| --- | --- | --- | --- |
| GitHub 访问令牌 | 你自行创建的 Personal Access Token 或设备授权令牌 | 代表你调用 GitHub API | 设备本地，经系统 AssetStoreKit 加密存储 |
| 账号展示信息 | 登录名、头像、显示名 | 在界面展示当前账号 | 设备本地缓存 |
| 应用设置 | 主题、语言、工作区偏好 | 保持你的使用偏好 | 设备本地（应用私有目录） |

**我们不收集**：设备标识符、位置、通讯录、相册、麦克风、剪贴板内容；不进行用户画像；应用内不含任何广告、统计或行为分析。

### 三、权限说明

本应用仅申请一项系统权限：

| 权限 | 用途 |
| --- | --- |
| `ohos.permission.INTERNET`（网络访问） | 与 GitHub API 通信，获取你授权范围内的数据 |

本应用不申请位置、相机、麦克风、通讯录、日历、存储等敏感权限。

### 四、信息的对外传输与跨境

你的设备会直接访问以下域名，它们均由 GitHub, Inc. 运营，**服务器位于中华人民共和国境外**：

| 域名 | 用途 |
| --- | --- |
| `api.github.com`、`github.com` | 账号授权、仓库、议题、合并请求、通知等数据 |
| `github.githubassets.com`、`raw.githubusercontent.com`、`docs.github.com` | 图标、图片与文档资源 |
| `*.githubusercontent.com`（含 `avatars`/`camo`/`user-images`/`objects` 等子域） | 头像、正文内嵌图片、Release 资产下载资源 |

由于上述服务器位于境外，**使用本应用即表示你知悉并同意相关信息会被传输至境外**。若你不同意，请不要登录使用。

除 GitHub 外，本应用不与任何第三方共享、出售或转让你的信息。

### 五、第三方 SDK

本应用**未集成任何第三方 SDK**（无统计、无广告、无推送、无支付、无第三方登录 SDK）。

### 六、数据安全与保存期限

- 令牌使用 HarmonyOS 系统提供的 AssetStoreKit 加密存储；其他数据存放于应用私有目录，其他应用无法读取；
- 上述数据**仅保存在你的设备上，直至你主动删除**；
- 在「设置 → Sign Out」移除账号，即可删除对应的令牌；
- 卸载应用会清除全部本地数据；
- 开发者无法访问你设备上的任何数据。

### 七、你的权利

| 权利 | 如何行使 |
| --- | --- |
| 查看 / 删除本地数据 | 应用内「设置 → Sign Out」，或卸载应用 |
| 撤回授权 | 在 GitHub 网站 Settings → Applications 中撤销本应用的授权 |
| 注销账号 | 本应用不提供自有账号体系，无需注销 |
| 咨询与投诉 | 通过本政策第一条的联系方式 |

### 八、未成年人保护

本应用面向软件开发者，**不面向 14 周岁以下儿童**，也不会主动收集儿童个人信息。若你是未成年人，请在监护人陪同下阅读本政策并使用本应用。

### 九、政策更新

本政策可能随功能调整而更新。更新后我们会在本页面公布并更新「最后更新」日期；涉及你权利的重大变更，我们会在应用内以显著方式提示。

### 十、适用范围

本政策仅适用于 ArkCat 应用本身。你在使用过程中访问的 GitHub 平台内容，适用 GitHub 自己的隐私声明。

---

## English

### 1. Who we are

ArkCat is developed and maintained by an individual developer, **Zhou Ming**. For any question about this policy, contact us at:

- Email: <prozm.bad@gmail.com>
- Repository: <https://github.com/ZM-BAD/arkcat>

### 2. Information we collect and use

**ArkCat has no server of its own and never uploads your information to any server controlled by the developer.** All data either stays on your device or is sent directly from your device to GitHub, which you have authorised.

| Type | Details | Purpose | Where it lives |
| --- | --- | --- | --- |
| GitHub access token | The Personal Access Token you create yourself, or a device-flow token | To call the GitHub API on your behalf | On-device, encrypted with the system AssetStoreKit |
| Account display info | Login name, avatar, display name | To show the current account in the UI | Cached on-device |
| App settings | Theme, language, workspace preferences | To keep your preferences | On-device, app-private directory |

**We do not collect**: device identifiers, location, contacts, photos, microphone input or clipboard content. We do not profile users, and the app contains no advertising, analytics or behavioural tracking.

### 3. Permissions

ArkCat requests exactly one system permission:

| Permission | Purpose |
| --- | --- |
| `ohos.permission.INTERNET` | To communicate with the GitHub API and fetch the data you have authorised |

The app does not request location, camera, microphone, contacts, calendar or storage permissions.

### 4. Data transfer and cross-border transfer

Your device connects directly to the following domains, all operated by GitHub, Inc., whose **servers are located outside mainland China**:

| Domain | Purpose |
| --- | --- |
| `api.github.com`, `github.com` | Account authorisation, repositories, issues, pull requests, notifications |
| `github.githubassets.com`, `raw.githubusercontent.com`, `docs.github.com` | Icons, images and documentation assets |
| `*.githubusercontent.com` (including the `avatars`, `camo`, `user-images` and `objects` subdomains) | Avatars, inline images in rendered content, and Release asset downloads |

Because those servers are located outside mainland China, **by using ArkCat you acknowledge and agree that the relevant information will be transferred outside mainland China**. If you do not agree, please do not sign in.

Apart from GitHub, ArkCat does not share, sell or transfer your information to any third party.

### 5. Third-party SDKs

ArkCat **integrates no third-party SDKs** (no analytics, advertising, push, payment or third-party login SDK).

### 6. Security and retention

- Your token is encrypted with HarmonyOS AssetStoreKit; other data is stored in the app-private directory and is not readable by other apps;
- All of the above **remains only on your device until you delete it**;
- Removing an account in "Settings → Sign Out" deletes the corresponding token;
- Uninstalling the app clears all local data;
- The developer cannot access any data on your device.

### 7. Your rights

| Right | How to exercise it |
| --- | --- |
| Access / delete local data | "Settings → Sign Out" in the app, or uninstall the app |
| Revoke authorisation | Revoke ArkCat's access under Settings → Applications on GitHub |
| Account deletion | ArkCat has no account system of its own, so there is nothing to delete |
| Questions and complaints | Use the contact details in section 1 |

### 8. Children

ArkCat targets software developers and is **not directed at children under 14**. We do not knowingly collect personal information from children. If you are a minor, please read this policy with your guardian before using the app.

### 9. Changes to this policy

This policy may be updated as the app evolves. We will publish updates on this page and revise the "Last updated" date; material changes affecting your rights will be highlighted in the app.

### 10. Scope

This policy applies to the ArkCat app only. Content you access on GitHub is governed by GitHub's own privacy statement.
