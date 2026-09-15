/**
 * 语言色点：语言主色圆点（无色回退 repo_language_unknown 灰）。
 * 语言点+名称的横向组合用 LanguageDotRow；自定义文字样式的场景只取点本身。
 */
@ComponentV2
export struct LanguageDot {
  @Param colorHex: string = '';
  @Param dotSize: number = 10;

  build() {
    Circle()
      .width(this.dotSize)
      .height(this.dotSize)
      .fill(this.colorHex !== '' ? this.colorHex : $r('app.color.repo_language_unknown'))
  }
}

/**
 * 「色点 + 语言名」行（caption 灰字）：此前 RepoCard/SearchRows/StarredRepoRow 等逐处手写，
 * 且画法漂移（Circle vs '●' 字符、回退色不一），现统一为 Circle + 官方回退色。
 */
@ComponentV2
export struct LanguageDotRow {
  @Require @Param language: string;
  @Param colorHex: string = '';
  @Param dotSize: number = 10;
  @Param space: number = 4;

  build() {
    Row({ space: this.space }) {
      LanguageDot({ colorHex: this.colorHex, dotSize: this.dotSize })
      Text(this.language)
        .fontSize($r('app.float.caption_font_size'))
        .fontColor($r('app.color.text_secondary'))
    }
  }
}
