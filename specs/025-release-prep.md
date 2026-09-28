# Spec 025: 发布与开源准备（License / 品牌声明 / 上架清单，横向规范）

> BFS Level: 4
> 关联决策: 用户 2026-08-31「零盈利、图技术口碑名声、钱一分不碰」；上游 Spec 012/024（横向基建）
> 上游 Spec: 012 / 024
> 状态: ✅ implemented（2026-08-31，文档落地 + 校验通过）

---

## 一、页面/功能概述

发布工程的横向规范：① 项目采取 **GPL-3.0** 开源许可（防换皮上架 + 最利于社区名声，不采用 NC 类条款——NC 被视作伪开源，与「图名声」目标相悖）；② README 双语固化「免费 / 开源 / 非商业 / 非官方」声明（第三方客户端品牌风险抗辩姿势）；③ 第三方资产许可注明（Octicons 走自带 MIT LICENSE）；④ 华为 AppGallery 上架清单固化为 `docs/app-store-checklist.md`（含零盈利条目）。本 Spec 不改变任何功能代码。

---

## 二、整体 UI 结构

```text
arkcat/
├── LICENSE                        # GPL-3.0 全文（唯一许可文本）
├── README.md                      # 英文：声明段 + License 段（GPL-3.0 + Octicons MIT 例外）
├── README_zh.md                   # 中文：同上
├── assets/octicons/LICENSE        # MIT（Octicons 上游自带，已归档，保留）
├── docs/
│   └── app-store-checklist.md     # 华为上架清单（可勾选）
└── specs/
    └── 025-release-prep.md        # 本规范
```

无页面 UI；上架素材（图标/截图/隐私政策等）属于后续独立发布批次。

---

## 三、元素清单

| # | 位置 | 元素 | 功能 | 可行性 | 接口 | 备注 |
| --- | ------ | ------ | ------ | -------- | ------ | ------ |
| 1 | 仓库根 | `LICENSE`（GPL-3.0 全文） | 项目许可 | ✅ | — | GNU GPL v3 官方文本 |
| 2 | `assets/octicons/` | `LICENSE`（MIT） | 第三方资产许可 | ✅ | — | 上游自带，保留不改 |
| 3 | README.md | 「非官方 / 非商业」声明段（英文） | 品牌风险抗辩 | ✅ | — | 措辞见 Spec 规范文本 |
| 4 | README_zh.md | 同款声明段（中文） | 同上 | ✅ | — | 与英文一致 |
| 5 | README 双文 | License 段：GPL-3.0 + Octicons MIT 例外 + 版权声明行 | 许可说明 | ✅ | — | 替换原 Apache-2.0；版权行 `Copyright © 2026 周铭`（GPL-3.0 要求随附版权声明，此前全仓缺失） |
| 6 | `docs/` | `app-store-checklist.md` | 上架准备清单 | ✅ | — | 含零盈利条目 |
| 7 | specs | 025 本文件 | 规范固化 | ✅ | — | — |
| 8 | 全仓库 | 品牌红线：不得引入 GitHub logo / Octocat / 官方插画素材 | 商标合规 | ✅ | — | 红线入 CONTRIBUTING 建议 |

> 可行性比例声明：8/8 可行。

---

## 四、核心 GraphQL 片段

无（纯文档/许可工程）。

---

## 五、边界 / 不可行项

| 项 | 原因 | ArkCat 处理方式 |
| ---- | ------ | ------------------- |
| NC（非商业）类许可 | 社区视作伪开源，损害技术名声 | 不采用；零盈利作为 README/商店声明而非许可约束 |
| 官方插画 / 品牌素材 | 版权与商标归属 GitHub | 红线禁止引入仓库与商店素材（含后续自研插画不得临摹官方猫插画） |
| AppGallery 资质（备案 / 软著 / 发布签名） | 需账号与流程，非本批次范围 | 清单登记 + 指引章节；办理过程后续批次 |
| 图标 / 截图 / 隐私政策页 | 需产品自研素材 | 清单登记，后续批次执行 |

---

## 六、TDD 验收标准

- [x] 测试 1：仓库根存在 `LICENSE` 且首行为 GPL-3.0 声明
- [x] 测试 2：README 双文均含「not affiliated / 非官方」与「non-commercial / 非商业」措辞（grep 双文比对）
- [x] 测试 3：README 双文 License 段为 GPL-3.0、注明 Octicons 为 MIT（`assets/octicons/LICENSE`），并含项目版权声明行 `Copyright © 2026 周铭`（双文各一处）
- [x] 测试 4：`bash scripts/check-spec.sh` 通过（含 025 编号连续）
- [x] 测试 5：pre-commit markdownlint / gitleaks 通过
- [x] 测试 6：CI structure-check 所需文件不受影响（仅新增 docs/）

---

## 七、备注

- 零盈利定位（用户 2026-08-31）：「完全不做任何盈利性目的……最多图一个技术口碑和名声，钱一分不碰。」→ 商店侧免费应用 + 无 IAP → 免支付/增值资质；隐私问卷更简。
- GPL-3.0 选择理由：与 Apache-2.0 相比，传染条款要求衍生品开源——截断「fork 换皮上架」路径；与不可商用条款相比，仍保持标准开源协议，利于社区与名声。
- 「非官方声明」应出现在 README、应用内「关于」页（后续）、商店描述三处。
- 后期待办（登记于 checklist）：应用图标设计、特色图、真机截图、应用内隐私说明页 + 线上隐私政策 URL、AGC 账号/包名确认、发布证书与 Profile、工信部 App 备案、审核测试说明（PAT 配置步骤）。
- 2026-09-29：仓库已转 public。`docs/app-store-checklist.md` 含内部运维口径（签名红线、备案备注等），作为本地台账移出仓库（.gitignore 排除、原路径保留本地维护）；§一④/§二/§三 所述清单不再随库分发，GPL-3.0/README 声明等对外交付物不变。
