# Spec 066: App Lock（设备凭据锁定）

> BFS Level: 3
> 关联截图: 官方 Settings → General → App Lock 子页（单 Toggle「Use device credentials to unlock the app」）
> 上游 Spec: 014（Settings）、049（占位行来源；规划简称「049b」，因 CI 编号连续性约束独立编号为 066）
> 状态: implemented

---

## 一、页面/功能概述

Settings → General → App Lock 行压栈打开 App Lock 子页。子页仅一个开关：**使用设备凭据解锁应用**——开启后，App 退到后台再回前台（以及冷启动）必须通过设备锁屏凭据（人脸/指纹/锁屏密码）验证才能进入内容。凭据完全复用系统锁屏凭据，App 内不自设密码；官方行为对位（GitHub Changelog 2024-08-06 App lock via Face ID or biometrics）。

鸿蒙实现走 userIAM userAuth Kit：`getAvailableStatus` 探测可用凭据类型，`getUserAuthInstance` 拉起系统统一认证界面（`authType` 传 `[FACE, FINGERPRINT, PIN]` 数组，系统自动挑选可用项并兜底），`AuthTrustLevel.ATL1`。认证 UI 为系统统一弹窗，样式不可定制（与官方「用系统凭据」语义同构，属平台惯例非样式偏离）。

---

## 二、整体 UI 结构

1. 顶部：自绘 App Bar（返回 + 标题 App Lock）
2. 内容区：
   - 区块一：Toggle 行——左文案「使用设备凭据解锁应用」（可换行两行，同官方），右 Toggle 开关
3. 其余留白（页面内容极简，与官方一致）

---

## 三、元素清单

| # | 位置 | 元素 | 功能 | 可行性 | 接口 | 备注 |
| --- | ------ | ------ | ------ | -------- | ------------- | ------ |
| 1 | App Bar | 返回钮 | pop 回 Settings | ✅ 纯 UI | — | 同 014 模式 |
| 2 | Toggle 行 | 开关（OFF→ON） | 先探测设备凭据可用性；可用则**弹一次系统认证**确认本人，通过才落开关并持久化 | ✅ | `userAuth.getUserAuthInstance` | 取消/失败不落开关 |
| 3 | Toggle 行 | 开关（ON→OFF） | 直接关闭并持久化，不要求认证 | ✅ | — | 与官方一致 |
| 4 | Toggle 行 | 凭据不可用兜底 | `getAvailableStatus` 全类型失败（设备未设锁屏凭据）→ 点击开关 Toast 提示先去系统设置锁屏密码，开关不落 | ✅ | `userAuth.getAvailableStatus` | ATL1 |
| 5 | 全局 | 锁定触发 | 开关 ON 期间 UIAbility `onBackground` 置锁；`onForeground` 恢复时进入锁定态 | ✅ | UIAbility 生命周期 | App 级，跨账号 |
| 6 | 全局 | 锁定态界面 | 全屏遮罩（logo + 文案 + 解锁按钮），进入时**自动弹**系统认证；取消/失败停留在遮罩可重试 | ✅ | Index 根条件渲染 | 遮罩须覆盖底栏 |
| 7 | 全局 | 冷启动锁定 | EntryAbility `onCreate` 读偏好，ON → 启动即锁定态 | ✅ | preferences | 键 `app_lock_enabled` |
| 8 | 全局 | 系统认证弹窗 | 系统统一 UI（userAuth widget），自定义标题 | ✅ | WidgetParam.title | 样式不可定制 |

> 可行性图例：✅ 可直接实现 ｜ ⚠️ 部分可行/降级 ｜ ❌ 不可实现
> 硬件受限：模拟器无生物识别、能否设置锁屏密码待探测——开发期以锁屏密码 PIN 验证为主，FACE/FINGERPRINT 列真机（Pura 90 Pro）验收清单。

---

## 四、核心接口

- 探测：`userAuth.getAvailableStatus(type, AuthTrustLevel.ATL1)`，type ∈ FACE/FINGERPRINT/PIN，任一成功即可用（12500000 = 可用；失败抛 BusinessError）
- 认证：`userAuth.getUserAuthInstance({challenge: new Uint8Array(0), authType: [FACE, FINGERPRINT, PIN], authTrustLevel: ATL1}, {title})` → `on('result', cb)` + `start()`；结果 `ResultCode.SUCCESS` 解锁，`cancel()`/用户取消停在锁定态
- 权限：`ohos.permission.ACCESS_BIOMETRIC`（normal 级）写入 `entry/src/main/module.json5` 的 `requestPermissions`，无需动态申请
- 存储：偏好 `arkcat_settings` 新键 `app_lock_enabled`（'1'/'0'）；`EntryAbility.onCreate` 与 Settings/AppLock 页读取
- 生命周期桥：Index 根新增锁定态渲染（`@StorageProp` 或 AppStorage 泵），UIAbility 前后台事件经 AppStorage 通知

---

## 五、边界 / 不可行项

> ArkCat 处理：以上 ❌/⚠️ 项均为**有意不做或平台受限**——❌ 项保持不实现（官方亦无），⚠️ 模拟器受限项降级为真机验收，不影响 8/8 元素可行性（元素表全部 ✅，受限项集中在边界章而非元素）。

- ❌ 自设 PIN/图案：官方无此功能（纯设备凭据），且违反「官方没有的，我们不加」
- ❌ 解锁延时选项（如「5 分钟内免验证」）：官方单开关，无此功能
- ❌ 系统认证弹窗样式定制：系统统一 UI，平台惯例
- ⚠️ 模拟器生物识别：不可用；锁屏密码能否设置待探测——不行则锁定链路真机验收
- 边沿情况：系统权限弹窗、分享面板、应用内浏览器跳转等正常离场均按官方语义处理（回前台即要求验证）；不设白名单
- 多账号：开关 App 级（跨账号生效），与 049a 的账号数据无耦合

---

## 六、TDD 验收标准

- [ ] 测试 1：App Lock 子页渲染（Toggle 行 + App Bar），默认 OFF（偏好未落时）
- [ ] 测试 2：开关 ON→系统认证通过→开关 ON + `app_lock_enabled` 落盘；重进子页回显 ON
- [ ] 测试 3：认证取消/失败→开关保持 OFF，偏好不落盘
- [ ] 测试 4：ON 状态切后台→回前台出现锁定遮罩并自动弹认证；通过后进内容
- [ ] 测试 5：OFF 状态切后台→回前台不锁
- [ ] 测试 6：冷启动 ON→首帧即锁定态；解锁后正常进入
- [ ] 测试 7：设备凭据全不可用→点击开关 Toast 提示、开关不落（模拟器探测路径）
- [x] 测试 8：宿主单测——偏好键读写纯函数（app_lock_enabled 归一化：缺省/非法值回 OFF）（82/82 绿，含 @kit.UserAuthenticationKit 桩）
- [ ] （真机补验）FACE/FINGERPRINT 认证通过与回落链路
- [ ] 走查：暗黑双态 + i18n 双语（子页标题/行文案/遮罩文案/Toast）

---

## 七、备注

- 官方依据：GitHub Changelog「App lock via Face ID or biometrics」（2024-08-06）；官方 Android 走系统 BiometricPrompt（设备凭据模式），ArkCat 用 userAuth 系统认证弹窗为**平台等价物**，不算偏离
- 入口位置：Settings → **General** 组 App Lock 行（官方同组，用户 2026-09-12 确认）
- 「049b」为 049 规划时的拆分简称；因 CI spec 编号连续性校验（`structure-check` 要求文件名前导数字严格递增），独立 spec 编号 066，049 的对应挂账转指向本文件
- 官方无「点开后消失」之类的辅助行为（App Lock 为常驻行）；此前 Get Help 行的消失行为属官方 bug 的结论不适用于本行
- 实测坑（模拟器，2026-09-12）：① `AuthParam.challenge` 传空 `Uint8Array(0)` 会被参数校验以 401 拒绝（getUserAuthInstance/start 抛错）——必须传非空挑战值（实现取 16 字节随机数；挑战仅防重放，App 只用认证结论不用 token）；② 认证弹窗为安全窗口，snapshot_display/uitest screenCap 截图全黑属正常（与键盘态全黑同坑），验证弹窗改用 uitest dumpLayout --all-windows 看布局树
- 模拟器实测链路：系统设置可设 6 位锁屏密码；getAvailableStatus 仅 PIN 可用（FACE/FINGERPRINT 无硬件被跳过，类型过滤生效），认证弹窗正常拉起（标题「解锁 ArkCat」+ 数字键盘）；生物识别补验仍需真机
