/**
 * 贡献日历热力图：横向滚动的周列 × 7 天网格。
 * Spec 001 元素 5；颜色优先取 API 返回值。
 */
import { ContributionCalendar as CalendarModel, ContributionDay } from '../models/GitHubModels';

@ComponentV2
export struct ContributionCalendar {
  @Param calendar: CalendarModel | null = null;

  @Builder
  cell(color: string) {
    Rect()
      .width($r('app.float.heat_cell_size'))
      .height($r('app.float.heat_cell_size'))
      .radius(2)
      .fill(color)
  }

  @Builder
  weekColumn(week: ContributionDay[]) {
    Column({ space: 2 }) {
      ForEach(week, (day: ContributionDay) => {
        this.cell(day.color)
      }, (day: ContributionDay) => day.date)
    }
  }

  build() {
    Column({ space: 8 }) {
      Text(`${this.calendar?.totalContributions ?? 0} 次贡献（过去一年）`)
        .fontSize($r('app.float.caption_font_size'))
        .fontColor($r('app.color.text_secondary'))

      Scroll() {
        Row({ space: 2 }) {
          ForEach(this.calendar?.weeks ?? [], (week: ContributionDay[]) => {
            this.weekColumn(week)
          }, (week: ContributionDay[], idx: number) => `week-${idx}-${week.length}`)
        }
        .alignItems(VerticalAlign.Top)
      }
      .scrollable(ScrollDirection.Horizontal)
      .width('100%')
    }
    .width('100%')
    .padding($r('app.float.card_padding'))
    .borderRadius($r('app.float.card_radius'))
    .backgroundColor($r('app.color.card_background'))
    .alignItems(HorizontalAlign.Start)
  }
}
