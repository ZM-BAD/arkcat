/**
 * 搜索结果行组件集（Spec 046 结果页批 / 官方聚合页版式）：
 * - RepoSearchRow：扁平行（头像/灰 owner/黑 repo/描述/★缩写+语言 dot）
 * - IssuePrSearchRow：绿圆环/绿分支 + 元信息行 + 相对时间 + 黑粗标题 + 徽章行（label/Checks/Reviews/💬/⊙）
 * - PersonSearchRow / OrgSearchRow：大头像 + 黑粗显示名 + 灰 login（无 @）+ 黑 bio（无 followers）
 * 聚合页 compact=true（无徽章行）；单类页 compact=false。
 */
import { OctIcon } from './OctIcon';
import { LabelPill } from './LabelPill';
import { compactCount, timeParts, githubShortTime } from '../utils/Format';
import { SearchResultItem, SearchLabel } from '../services/SearchService';
import { resText } from '../utils/I18n';

function shortTime(iso: string): string {
  const parts = timeParts(iso, Date.now());
  return parts === null ? '' : githubShortTime(parts);
}

/** owner/repo 拆分（title = nameWithOwner，owner 缺省同 repo） */
function splitRepo(title: string): string[] {
  const idx = title.indexOf('/');
  if (idx < 0) {
    return [title, title];
  }
  return [title.substring(0, idx), title.substring(idx + 1)];
}

@ComponentV2
export struct RepoSearchRow {
  @Param item: SearchResultItem | null = null;
  @Event onOpen: () => void = () => {};

  build() {
    Row({ space: 12 }) {
      Image(this.item?.avatarUrl ?? '')
        .width(40)
        .height(40)
        .borderRadius(20)
        .backgroundColor($r('app.color.text_tertiary'))
      Column({ space: 4 }) {
        Text(splitRepo(this.item?.title ?? '')[0])
          .fontSize($r('app.float.chip_font_size'))
          .fontColor($r('app.color.text_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Text(splitRepo(this.item?.title ?? '')[1])
          .fontSize($r('app.float.menu_font_size'))
          .fontWeight(600)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        if (this.item !== null && this.item.subtitle !== '') {
          Text(this.item.subtitle)
            .fontSize($r('app.float.body_font_size'))
            .fontColor($r('app.color.text_secondary'))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }
        Row({ space: 12 }) {
          Row({ space: 4 }) {
            OctIcon({ res: $r('app.media.oct_star_fill_16'), iconSize: 14, iconColor: $r('app.color.star_gold') })
            Text(compactCount(this.item?.stars ?? 0))
              .fontSize($r('app.float.caption_font_size'))
              .fontColor($r('app.color.text_secondary'))
          }
          if (this.item !== null && this.item.language !== '') {
            Row({ space: 4 }) {
              Circle()
                .width(9)
                .height(9)
                .fill(this.item.languageColor !== '' ? this.item.languageColor : $r('app.color.repo_language_unknown'))
              Text(this.item.language)
                .fontSize($r('app.float.caption_font_size'))
                .fontColor($r('app.color.text_secondary'))
            }
          }
        }
        .width('100%')
      }
      .layoutWeight(1)
    }
    .width('100%')
    .padding({ top: 14, bottom: 14 })
    .onClick(() => this.onOpen())
  }
}

@ComponentV2
export struct IssuePrSearchRow {
  @Param item: SearchResultItem | null = null;
  /** compact：聚合页（仅图标/元信息/标题）；false：单类页（附加徽章行） */
  @Param compact: boolean = true;
  @Event onOpen: () => void = () => {};

  private isPr(): boolean {
    return this.item?.kind === 'pr';
  }

  /** 状态图标/色（DESIGN.md §10.1 官方映射；搜索结果无 stateReason/draft 数据，按三态处理） */
  private stateIcon(): Resource {
    if (this.isPr()) {
      if (this.item?.state === 'MERGED') {
        return $r('app.media.oct_git_merge_16');
      }
      return this.item?.state === 'CLOSED' ? $r('app.media.oct_git_pull_request_closed_16')
        : $r('app.media.oct_git_pull_request_16');
    }
    return this.item?.state === 'CLOSED' ? $r('app.media.oct_issue_closed_16') : $r('app.media.oct_issue_opened_16');
  }

  private stateColor(): ResourceColor {
    if (this.isPr()) {
      if (this.item?.state === 'MERGED') {
        return $r('app.color.shortcut_purple_fg');
      }
      return this.item?.state === 'CLOSED' ? $r('app.color.danger_text') : $r('app.color.success_text');
    }
    return this.item?.state === 'CLOSED' ? $r('app.color.shortcut_purple_fg') : $r('app.color.success_text');
  }

  /** label 胶囊：统一走 LabelPill（官方 IssueLabel 口径，DESIGN.md §10.2） */
  @Builder
  labelPill(label: SearchLabel) {
    LabelPill({ labelName: label.name, colorHex: label.color })
  }

  @Builder
  outlinePill(iconRes: Resource, iconColor: ResourceColor, text: string) {
    Row({ space: 5 }) {
      OctIcon({ res: iconRes, iconSize: 16, iconColor: iconColor })
      Text(text)
        .fontSize($r('app.float.caption_font_size'))
        .fontColor($r('app.color.text_primary'))
    }
    .padding({ left: 10, right: 10, top: 4, bottom: 4 })
    .borderRadius(12)
    .border({ width: 1, color: $r('app.color.divider') })
    .backgroundColor($r('app.color.card_background'))
  }

  /** 徽章行：labels + Checks/Reviews + 💬N + ⊙N（单类页） */
  @Builder
  badges() {
    Row({ space: 6 }) {
      if (this.item !== null) {
        ForEach(this.item.labels.slice(0, 2), (label: SearchLabel) => {
          this.labelPill(label)
        }, (label: SearchLabel) => `${label.name}-${label.color}`)
        if (this.item.checkState !== '') {
          this.outlinePill(
            this.item.checkState === 'SUCCESS' ? $r('app.media.oct_check_16') : $r('app.media.oct_alert_16'),
            this.item.checkState === 'SUCCESS' ? $r('app.color.success_text') : $r('app.color.danger_text'),
            resText(this.getUIContext(), $r('app.string.search_checks_badge'))
          )
        } else if (this.item.reviewDecision !== '') {
          this.outlinePill($r('app.media.oct_check_16'), $r('app.color.success_text'),
            resText(this.getUIContext(), $r('app.string.search_reviews_badge')))
        }
        if (this.item.commentCount > 0) {
          this.outlinePill($r('app.media.oct_comment_16'), $r('app.color.text_primary'), `${this.item.commentCount}`)
        }
        if (this.item.reactionCount > 0) {
          this.outlinePill($r('app.media.oct_check_circle_16'), $r('app.color.text_primary'), `${this.item.reactionCount}`)
        }
      }
    }
    .width('100%')
  }

  build() {
    Row({ space: 12 }) {
      OctIcon({
        res: this.stateIcon(),
        iconSize: 24,
        iconColor: this.stateColor()
      })
      Column({ space: 5 }) {
        Row({ space: 8 }) {
          Text(`${this.item?.repoFullName ?? ''} #${this.item?.number ?? 0}`)
            .fontSize($r('app.float.chip_font_size'))
            .fontColor($r('app.color.text_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          Text(shortTime(this.item?.createdAt ?? ''))
            .fontSize($r('app.float.caption_font_size'))
            .fontColor($r('app.color.text_secondary'))
        }
        .width('100%')
        Text(this.item?.title ?? '')
          .fontSize($r('app.float.menu_font_size'))
          .fontWeight(600)
          .fontColor($r('app.color.text_primary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        if (!this.compact) {
          this.badges()
        }
      }
      .layoutWeight(1)
    }
    .width('100%')
    .padding({ top: 14, bottom: 14 })
    .onClick(() => this.onOpen())
  }
}

@ComponentV2
export struct PersonSearchRow {
  @Param item: SearchResultItem | null = null;
  @Event onOpen: () => void = () => {};

  build() {
    Row({ space: 12 }) {
      Image(this.item?.avatarUrl ?? '')
        .width(48)
        .height(48)
        .borderRadius(24)
        .backgroundColor($r('app.color.text_tertiary'))
      Column({ space: 3 }) {
        Text(this.item?.subtitle !== '' ? (this.item?.subtitle ?? '') : (this.item?.title ?? ''))
          .fontSize($r('app.float.menu_font_size'))
          .fontWeight(600)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Text(this.item?.title ?? '')
          .fontSize($r('app.float.chip_font_size'))
          .fontColor($r('app.color.text_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        if (this.item !== null && this.item.bio !== '') {
          Text(this.item.bio)
            .fontSize($r('app.float.body_font_size'))
            .fontColor($r('app.color.text_primary'))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }
      }
      .layoutWeight(1)
    }
    .width('100%')
    .padding({ top: 14, bottom: 14 })
    .onClick(() => this.onOpen())
  }
}

@ComponentV2
export struct OrgSearchRow {
  @Param item: SearchResultItem | null = null;
  @Event onOpen: () => void = () => {};

  build() {
    Row({ space: 12 }) {
      Image(this.item?.avatarUrl ?? '')
        .width(48)
        .height(48)
        .borderRadius(24)
        .backgroundColor($r('app.color.text_tertiary'))
      Column({ space: 3 }) {
        Text(this.item?.subtitle !== '' ? (this.item?.subtitle ?? '') : (this.item?.title ?? ''))
          .fontSize($r('app.float.menu_font_size'))
          .fontWeight(600)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Text(this.item?.title ?? '')
          .fontSize($r('app.float.chip_font_size'))
          .fontColor($r('app.color.text_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        if (this.item !== null && this.item.bio !== '') {
          Text(this.item.bio)
            .fontSize($r('app.float.body_font_size'))
            .fontColor($r('app.color.text_primary'))
            .maxLines(3)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }
      }
      .layoutWeight(1)
    }
    .width('100%')
    .padding({ top: 14, bottom: 14 })
    .onClick(() => this.onOpen())
  }
}
