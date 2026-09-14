/**
 * Issue 标签胶囊（DESIGN.md §10.2 / §1.2，官方 IssueLabel 复刻）：
 * 全圆角胶囊 + 标签数据色渲染。造型=primer/css labels-base（12fp 半粗体；
 * small=总高 20+内距 7（列表行内）、large=总高 24+内距 10（筛选面板行），1px 透明描边占位）。
 * 颜色规则=primer/react IssueLabelToken：亮色原色实底 + 黑白文字（感知光感 0.6 阈值）、
 * 近白发丝描边；暗色 18% 透明底 + 同色相提亮文字 + 30% 描边。公式见 utils/DataColors.ets。
 * 主题切换实时跟随（MediaQuery 监听 dark-mode）。
 */
import { mediaquery } from '@kit.ArkUI';
import { labelTextColor, labelBackground, labelBorder, DataColorMode } from '../utils/DataColors';
import { RADIUS_FULL } from '../utils/PrimerTokens';

@ComponentV2
export struct LabelPill {
  /** 标签名 */
  @Param labelName: string = '';
  /** 标签色（'RRGGBB' 或 '#RRGGBB'；''=无色回退灰底白字，即旧 labelChip 行为） */
  @Param colorHex: string = '';
  /** large=筛选面板行（行高 22/内距 10）；small=列表行内（行高 18/内距 7） */
  @Param large: boolean = false;
  @Local isDark: boolean = false;
  private listener: mediaquery.MediaQueryListener | null = null;

  aboutToAppear(): void {
    this.listener = this.getUIContext().getMediaQuery().matchMediaSync('(dark-mode: true)');
    this.isDark = this.listener.matches === true;
    this.listener.on('change', (res: mediaquery.MediaQueryResult): void => {
      this.isDark = res.matches === true;
    });
  }

  aboutToDisappear(): void {
    this.listener?.off('change');
  }

  private mode(): DataColorMode {
    return this.isDark ? 'dark' : 'light';
  }

  build() {
    // 固定高度 + Row 默认垂直居中（ArkUI 的 lineHeight 行框会把字形顶偏，勿用 lineHeight 撑高）
    Row() {
      Text(this.labelName)
        .fontSize(12)
        // 官方 semibold≈600（PrimerTokens.FONT_WEIGHT_SEMIBOLD；ArkUI 无 Semibold 枚举，用数值）
        .fontWeight(600)
        .maxLines(1)
        .fontColor(this.colorHex === '' ? '#FFFFFF' : labelTextColor(this.colorHex, this.mode()))
    }
    .height(this.large ? 24 : 20)
    .padding({
      left: this.large ? 10 : 7,
      right: this.large ? 10 : 7
    })
    .borderRadius(RADIUS_FULL)
    // 无色标签回退：灰底白字（沿用旧 labelChip 口径，DESIGN.md §1.2 数据色仅约束有色标签）
    .backgroundColor(this.colorHex === '' ? $r('app.color.text_secondary') : labelBackground(this.colorHex, this.mode()))
    .border({
      width: 1,
      color: this.colorHex === '' ? Color.Transparent : (labelBorder(this.colorHex, this.mode()) === ''
        ? Color.Transparent : labelBorder(this.colorHex, this.mode()))
    })
  }
}
