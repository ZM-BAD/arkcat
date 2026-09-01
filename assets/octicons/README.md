# Octicons 归档

- 来源：[github.com/primer/octicons](https://github.com/primer/octicons)（Primer 设计系统）
- 版本：v19.33.0（2026-08-04）
- 许可：MIT（`LICENSE`，Copyright (c) 2026 GitHub Inc.）
- 用途：StarRaft 图标资产（Spec 024）；生产资源副本位于 `entry/src/main/resources/base/media/oct_*.svg`，与 `icons/` 内原始文件完全一致（未改色，着色统一由 `OctIcon.fillColor` 完成）
- 下载命令示例：
  `curl -s -o icons/arrow-left-24.svg https://raw.githubusercontent.com/primer/octicons/v19.33.0/icons/arrow-left-24.svg`

- 说明：官方 Octicons 无竖三点图标（v19.33.0 与 main 均只有 kebab-horizontal）。应用内竖三点 = `oct_kebab_horizontal_16` 旋转 90°（ArkUI Image.rotate），不使用自绘 SVG。
