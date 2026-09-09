<p align="center">
  <img src="assets/logo/arkcat-logo-appicon.svg" width="160" alt="ArkCat logo">
</p>

# ArkCat — Pure HarmonyOS GitHub Client

> 🌐 English | [简体中文](README_zh.md)
> A GitHub client app built on HarmonyOS NEXT (Pure HarmonyOS)

---

## 📋 Project Overview

| Item | Description |
| ------ | ------------- |
| **App Name** | ArkCat |
| **Bundle ID** | `me.zmbad.arkcat` |
| **Target Platform** | HarmonyOS 7.0 (API 26.0.0) |
| **Min Compatibility** | HarmonyOS 5.0 (API 12) |
| **App Type** | GitHub Third-party Client |
| **Language** | ArkTS / ArkUI |
| **Build Tool** | hvigor (DevEco Studio built-in) |
| **Test Framework** | Hypium + node:test (host unit tests) |

---

## 🎨 Design Philosophy — "Experience-Level Recreation"

> Goal: Become the third-party client closest to the official GitHub APP experience.

**Not pixel-level cloning, but experience-level recreation** — akin to the relationship between Ubuntu and macOS Settings menus:

- **Recreated**: Information architecture, page hierarchy, navigation patterns, feature partitioning, button placement, interaction feedback logic
- **Not recreated**: Platform-specific control styles (no iOS frosted glass / Material ripple), font/icon aesthetics

**Core Principle**: Users who've used the official GitHub APP will open ArkCat and immediately feel "this is a reskin", but underneath it's all native Pure HarmonyOS ArkUI components.

---

## 🏗 Technical Solution

### Confirmed
- Dev Tool: DevEco Studio 26.0.0+
- Target Platform: HarmonyOS 7.0 (API 26.0.0)
- **API Layer: GitHub GraphQL API v4** (GraphQL primary, REST fallback)
- Network: @kit.NetworkKit (wrapped GraphQL Client)
- UI Framework: ArkUI (native components)
- Design System: **GitHub Primer** (official tokens & rules, see [DESIGN.md](DESIGN.md))
- State Management: V2 (`@ComponentV2` / `@Local`, API 18+)
- **Architecture: Client-side direct connection to GitHub GraphQL API**, no BFF/backend
- Auth: **GitHub OAuth Device Flow** (primary login) with PAT compatibility (stored locally)
- Routing: **Navigation** (`NavPathStack` + `navDestination`; secondary pages use self-drawn AppBar)
- GraphQL Client: Hand-rolled lightweight implementation

---

## ✨ Features

- **Home**: My Work workspace (Issues / PRs / Discussions / Projects / Top Repos / Organizations / Starred — editable order & visibility)
- **Inbox**: notification inbox (type / repository / view filters, read state, merged-PR detection)
- **Explore**: Trending / Awesome (language, date window, spoken-language filters)
- **Copilot**: AI assistant (OAuth Device Flow authorization, sessions & chat UI)
- **Repositories**: detail, PR / Commits / Releases lists, Contributors / Watchers / License, README & Markdown rendering, Stargazers / Forks, achievement badges
- **Pull Requests**: detail, Files Changed (diff hunks, line numbers toggle, reviewed checkboxes, file comments), commits, Checks / Reviews
- **Issues**: detail, comments, reactions (emoji panel / Reactees), label filters
- **Search**: six result types (Code / Repos / Issues / PRs / People / Orgs), qualifier chips, recent searches
- **Global**: three-state dark mode, English & Simplified Chinese, GitHub Primer design, pull-to-refresh & infinite scroll, GitHub relative timestamps

> Detailed design & progress for each feature live in [`specs/`](specs/) (full index: [specs/README.md](specs/README.md)).

---

## 🚀 Quick Start

### Requirements
- macOS 14+ (Apple Silicon / Intel)
- DevEco Studio 26.0.0+ (installed)
- HarmonyOS SDK 26.0.0 (installed)

### Development Steps

```bash
# 1. Clone the project
git clone https://github.com/ZM-BAD/arkcat.git
cd arkcat

# 2. Install Node dependencies (required by the pre-commit host unit test gate)
npm install

# 3. Install Git hooks
bash scripts/install-hooks.sh

# 4. Open in DevEco Studio
#    File → Open → select arkcat directory

# 5. Build & Run
#    DevEco Studio → Build → Build Project (Ctrl/Cmd + F9)
#    DevEco Studio → Run → Run 'entry' (Ctrl/Cmd + R)
```

### Optional CLI commands (macOS)

```bash
bash scripts/run-local-tests.sh   # host unit tests (node:test, needs npm install)
bash scripts/run-local-test.sh    # official Local Test + coverage report (needs DevEco Studio)
bash scripts/check-graphql.sh     # GraphQL contract check (needs `gh` login)
devecocli build                   # build debug HAP
```

---

## 📄 License

**ArkCat is a free, open-source, non-commercial HarmonyOS client for GitHub. It is not affiliated with, endorsed by, or sponsored by GitHub, Inc. GitHub and the GitHub logo are trademarks of GitHub, Inc. ArkCat contains no official GitHub assets or artwork.**

- Project code: [GPL-3.0](./LICENSE)
- Icons (Octicons, under [`assets/octicons/`](assets/octicons/README.md)): MIT License — see [`assets/octicons/LICENSE`](assets/octicons/LICENSE)
