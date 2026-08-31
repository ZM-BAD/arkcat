# StarRaft — Pure HarmonyOS GitHub Client

> 🌐 English | [简体中文](README_zh.md)
> A GitHub client app built on HarmonyOS NEXT (Pure HarmonyOS)

---

## 📋 Project Overview

| Item | Description |
|------|-------------|
| **App Name** | StarRaft |
| **Bundle ID** | `me.zmbad.starraft` |
| **Target Platform** | HarmonyOS 7.0 (API 26.0.0) |
| **Min Compatibility** | HarmonyOS 5.0 (API 12) |
| **App Type** | GitHub Third-party Client |
| **Language** | ArkTS / ArkUI |
| **Build Tool** | hvigor (DevEco Studio built-in) |
| **Test Framework** | Hypium |

---

## 🎨 Design Philosophy — "Experience-Level Recreation"

> Goal: Become the third-party client closest to the official GitHub APP experience.

**Not pixel-level cloning, but experience-level recreation** — akin to the relationship between Ubuntu and macOS Settings menus:

- **Recreated**: Information architecture, page hierarchy, navigation patterns, feature partitioning, button placement, interaction feedback logic
- **Not recreated**: Platform-specific control styles (no iOS frosted glass / Material ripple), font/icon aesthetics

**Core Principle**: Users who've used the official GitHub APP will open StarRaft and immediately feel "this is a reskin", but underneath it's all native Pure HarmonyOS ArkUI components.

---

## 🏗 Technical Solution

### Confirmed
- Dev Tool: DevEco Studio 26.0.0+
- Target Platform: HarmonyOS 7.0 (API 26.0.0)
- **API Layer: GitHub GraphQL API v4** (GraphQL primary, REST fallback)
- Network: @kit.NetworkKit (wrapped GraphQL Client)
- UI Framework: ArkUI (native components)
- State Management: V2 (`@ComponentV2` / `@Local`, API 18+)
- **Architecture: Client-side direct connection to GitHub GraphQL API**, no BFF/backend
- Auth: GitHub Personal Access Token (user-generated, stored locally)
- GraphQL Client: Hand-rolled lightweight implementation

### To Be Confirmed
- Routing management solution

---

## 📊 Spec Breakdown Strategy: BFS (Breadth-First Search)

> Traverse all tabs and pages first to establish a complete IA overview, then drill down path by path by priority.
> Avoid getting stuck in the details of any single sub-page early on.

**BFS Level Planning:**
- **Level 0**: Bottom Tab structure (Home / Inbox / Explore / Copilot)
- **Level 1**: Each Tab's page element breakdown
- **Level 2**: GraphQL interface + feasibility annotation per element
- **Level 3**: Sub-pages (Repo detail, Issue detail, PR detail...)
- **Level 4**: Interaction elements within sub-pages

**Spec files are located in the `specs/` directory**, see [specs/README.md](specs/README.md) for details.

### Spec Progress

| Page | Spec File | Status |
|------|----------|--------|
| Home Tab | `specs/001-home-tab.md` | ✅ Done |
| Inbox Tab | `specs/002-inbox-tab.md` | ✅ Done |
| Explore Tab | `specs/003-explore-tab.md` | ✅ Done |
| Copilot Tab | `specs/004-copilot-tab.md` | ✅ Done |
| User Profile | `specs/005-user-profile.md` | ✅ Done |
| Repo Detail | `specs/006-repo-detail.md` | ✅ Done |
| Issues List | `specs/007-issues-list.md` | ✅ Done |
| PR List | `specs/008-pr-list.md` | ✅ Done |
| PR Detail | `specs/009-pr-detail.md` | ✅ Done |
| PR Diff | `specs/010-pr-diff.md` | ✅ Done |
| Code Viewer | `specs/011-code-viewer.md` | ✅ Done |

**Coverage: ~95% of core scenarios (weighted by user frequency)**

---

## 📁 Project Structure

```text
starraft/
├── AppScope/                 # App-level configuration
├── entry/                    # Main module
│   └── src/main/
│       ├── ets/              # ArkTS source code
│       │   ├── entryability/ # Main entry Ability
│       │   ├── pages/        # Pages
│       │   ├── components/   # Reusable components (TBD)
│       │   ├── services/     # Network / API layer (TBD)
│       │   ├── models/       # Data models (TBD)
│       │   └── utils/        # Utilities (TBD)
│       ├── resources/        # Resource files
│       └── module.json5      # Module config
├── specs/                    # Spec documentation
│   ├── _TEMPLATE.md          # Spec template
│   └── NNN-name.md           # Per-page specs
├── scripts/                  # Scripts
│   ├── check-spec.sh         # Spec compliance check
│   └── install-hooks.sh      # Install Git hooks
├── .githooks/                # Git hooks
│   ├── pre-commit            # Pre-commit checks
│   └── commit-msg            # Commit message validation
├── .github/workflows/        # CI configuration
│   └── ci.yml                # Main CI pipeline
├── hvigorfile.ts             # Build configuration
├── build-profile.json5       # Build profile
├── oh-package.json5          # Root dependencies
├── CONTRIBUTING.md           # Contribution guide
├── AGENTS.md                 # AI-assisted development guide
├── README_zh.md              # 中文自述
└── README.md                 # This file
```

---

## 🚀 Quick Start

### Requirements
- macOS 14+ (Apple Silicon / Intel)
- DevEco Studio 26.0.0+ (installed)
- HarmonyOS SDK 26.0.0 (installed)

### Development Steps

```bash
# 1. Clone the project
git clone https://github.com/zm_bad/starraft.git
cd starraft

# 2. Install Git hooks
bash scripts/install-hooks.sh

# 3. Open in DevEco Studio
#    File → Open → select starraft directory

# 4. Build & Run
#    DevEco Studio → Build → Build Project (Ctrl/Cmd + F9)
#    DevEco Studio → Run → Run 'entry' (Ctrl/Cmd + R)
```

---

## 📄 License

Apache-2.0
