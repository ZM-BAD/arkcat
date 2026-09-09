# ArkCat Logo 源文件

Logo 的**唯一可编辑主稿**放在这里；应用实际读取的是 `resources/` 下的 PNG，由主稿导出。

| 源文件 | 导出产物 | 目标路径 |
| ------ | -------- | -------- |
| `arkcat-logo.svg` | —（母版，透明底，紧裁 viewBox） | 设计源，不直接进应用 |
| `arkcat-logo-foreground.svg` | `foreground.png` 1024×1024（透明底） | `AppScope/resources/base/media/`、`entry/src/main/resources/base/media/` |
| `arkcat-logo-background.svg` | `background.png` 1024×1024 | 同上 |
| `arkcat-logo-appicon.svg`（合成 = 背景层 + 前景层） | `startIcon.png` 144×144 | `entry/src/main/resources/base/media/`、`entry/src/ohosTest/resources/base/media/` |

6 个 PNG 均为本批导出（2026-09-10 定稿）；`layered_image.json` 与 `app.json5` / `module.json5` 里的 `$media:` 引用不需要改动。

## 设计规格

- **图形**：线条风「猫头 + 船 + 海浪」。猫头有两只立耳、闭眼弧、小圆鼻；船有烟囱箱体、四扇舷窗；船下两条海浪。海浪在**下层**（船身压住浪头）。
- **配色**：船与猫 = `#022D5A`（navy），海浪 = `#4FBBAB`（teal），背景层 = `#FFFFFF`；前景层背景透明。
- **合成稿** `arkcat-logo-appicon.svg` 的底色是**圆角矩形**（`rx="224"`，≈22% 画布），供启动页与 README 顶部使用——白底启动页上圆角不可见，深色背景下则呈现为 App 图标形状。仓库根 README / README_zh.md 顶部引用此文件（`width="160"`）。
- **描边**：全图统一描边宽度（源图实测 ≈ 39px / 1619px 画布）；路径是 potrace 描摹出的填充轮廓，不使用 `stroke` 属性。
- **构图**：前景内容占 1024 画布宽 **69.9%**（≈716px）、高 59.4%，水平垂直居中——沿用源图原始比例（源图 1619 画布、图形宽 1131）。系统遮罩（圆角方形）下四角无裁切，45px 仍可辨识。
- **几何来源**：`arkcat-logo.svg` 由 1619×1619 参考位图描摹而来（分色掩膜 → potrace → 烘焙成源图像素坐标的绝对路径），与原图逐像素差 0.25%（全部落在抗锯齿边缘）。路径坐标仍是源图像素空间，故把 `viewBox` 改成 `0 0 1619 1619` 即可还原源图的原始画布构图。

## 设计约束

- 画布 1024×1024，前景层背景透明；四周留安全边距（系统遮罩会裁圆角/圆形）。
- 三条品牌红线：不能像 Octocat、不能像 Docker 鲸鱼、不带华为官方标识元素。

## 导出（Inkscape CLI）

```bash
# 前景层 → 两处 foreground.png（透明底）
inkscape assets/logo/arkcat-logo-foreground.svg --export-type=png --export-width=1024 \
  --export-background-opacity=0 --export-filename=AppScope/resources/base/media/foreground.png
cp AppScope/resources/base/media/foreground.png entry/src/main/resources/base/media/foreground.png

# 背景层 → 两处 background.png
inkscape assets/logo/arkcat-logo-background.svg --export-type=png --export-width=1024 \
  --export-filename=AppScope/resources/base/media/background.png
cp AppScope/resources/base/media/background.png entry/src/main/resources/base/media/background.png

# 启动页图标 → 两处 startIcon.png（144×144，背景层 + 前景层合成）
inkscape assets/logo/arkcat-logo-appicon.svg --export-type=png --export-width=144 \
  --export-filename=entry/src/main/resources/base/media/startIcon.png
cp entry/src/main/resources/base/media/startIcon.png entry/src/ohosTest/resources/base/media/startIcon.png
```

另：`npx svgo <file>.svg` 可压缩路径数据（进 HarmonyOS resources 的图标尤其有用）——**它会删掉 `role` / `<g id>` / title·desc 的 id，源主稿别跑，只对打包副本跑**。
