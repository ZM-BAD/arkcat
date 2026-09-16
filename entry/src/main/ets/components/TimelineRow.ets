/**
 * 会话时间轴事件行（Spec 031 重设计）：左侧竖线 + 事件图标 + 官方口径文案。
 * 竖线由父级 Timeline 容器统一绘制（贯穿整轴，白卡自然遮断）；本行只负责图标（带页面底色，压线处形成「断口」）与文案。
 * 文案走 i18n 模板 + `phraseSegments` 拆段：人物/对象主色加粗，其余弱化灰（与官方一致）。
 */
import { OctIcon } from './OctIcon';
import { PhraseSeg, TimelineNode, actorDisplayLogin, phraseSegments } from '../models/RepoSubModels';
import { resText } from '../utils/I18n';

@ComponentV2
export struct TimelineRow {
  @Require @Param node: TimelineNode = {} as TimelineNode;
  /** commit 行点击 → 进提交详情 */
  @Event onOpenCommit: (oid: string) => void = (oid: string): void => { };
  /** 文案段（node 变化时重算；重渲染由 @Param 变更驱动） */
  private segs: PhraseSeg[] = [];

  aboutToAppear(): void {
    this.segs = this.buildSegs();
  }

  @Monitor('node')
  onNodeChanged(): void {
    this.segs = this.buildSegs();
  }

  private stringOf(res: Resource): string {
    return resText(this.getUIContext(), res);
  }

  /** 事件行文案：模板按 kind 取，实参顺序与官方句子一致 */
  private buildSegs(): PhraseSeg[] {
    const actor = actorDisplayLogin(this.node.actorLogin, this.node.actorIsBot);
    const target = actorDisplayLogin(this.node.targetLogin, this.node.targetIsBot);
    switch (this.node.kind) {
      case 'labeled':
        return phraseSegments(this.stringOf($r('app.string.tl_added_label')), [actor, this.node.labelName]);
      case 'unlabeled':
        return phraseSegments(this.stringOf($r('app.string.tl_removed_label')), [actor, this.node.labelName]);
      case 'assigned':
        return phraseSegments(this.stringOf($r('app.string.tl_assigned')), [actor, target]);
      case 'unassigned':
        return phraseSegments(this.stringOf($r('app.string.tl_unassigned')), [actor, target]);
      case 'review_requested':
        return phraseSegments(this.stringOf($r('app.string.tl_review_requested')), [actor, target]);
      case 'review_request_removed':
        return phraseSegments(this.stringOf($r('app.string.tl_review_request_removed')), [actor, target]);
      case 'merged':
        return phraseSegments(this.stringOf($r('app.string.tl_merged')),
          [actor, this.node.mergeAbbrev, this.node.mergeRefName]);
      case 'closed':
        return phraseSegments(this.stringOf($r('app.string.tl_closed')), [actor]);
      case 'reopened':
        return phraseSegments(this.stringOf($r('app.string.tl_reopened')), [actor]);
      case 'draft':
        return phraseSegments(this.stringOf($r('app.string.tl_draft')), [actor]);
      case 'ready':
        return phraseSegments(this.stringOf($r('app.string.tl_ready')), [actor]);
    }
    return [];
  }

  /** 事件图标（官方口径：合并紫 / 关闭红 / 重开绿 / 草稿灰） */
  private iconRes(): Resource {
    switch (this.node.kind) {
      case 'commit':
        return $r('app.media.oct_git_commit_16');
      case 'labeled':
      case 'unlabeled':
        return $r('app.media.oct_tag_16');
      case 'assigned':
      case 'unassigned':
      case 'review_requested':
      case 'review_request_removed':
        return $r('app.media.oct_person_16');
      case 'merged':
        return $r('app.media.oct_git_merge_16');
      case 'closed':
        return $r('app.media.oct_git_pull_request_closed_16');
      case 'reopened':
        return $r('app.media.oct_issue_reopened_16');
      case 'draft':
        return $r('app.media.oct_git_pull_request_draft_16');
      case 'ready':
        return $r('app.media.oct_git_pull_request_16');
    }
    return $r('app.media.oct_git_commit_16');
  }

  private iconColor(): Resource {
    switch (this.node.kind) {
      case 'merged':
        return $r('app.color.merged_badge_bg');
      case 'closed':
        return $r('app.color.danger_text');
      case 'reopened':
      case 'ready':
        return $r('app.color.success_text');
    }
    return $r('app.color.text_secondary');
  }

  private segText(index: number): string {
    return index < this.segs.length ? this.segs[index].text : '';
  }

  private segColor(index: number): ResourceColor {
    return this.segEmphasis(index) ? $r('app.color.text_primary') : $r('app.color.text_secondary');
  }

  private segWeight(index: number): FontWeight {
    return this.segEmphasis(index) ? FontWeight.Medium : FontWeight.Regular;
  }

  private segEmphasis(index: number): boolean {
    return index < this.segs.length && this.segs[index].emphasis;
  }

  build() {
    Row({ space: 10 }) {
      // 图标列：32vp 宽（中心落在容器的竖线上），底色与页面一致 → 压线处形成断口
      Stack() {
        OctIcon({ res: this.iconRes(), iconSize: 16, iconColor: this.iconColor() })
      }
      .width(32)
      .height(20)
      .backgroundColor($r('app.color.bg_page'))

      if (this.node.kind === 'commit') {
        // 提交行（官方）：作者头像 + 等宽消息，整行可点进提交详情
        Row({ space: 8 }) {
          if (this.node.commitAuthorAvatar !== '') {
            Image(this.node.commitAuthorAvatar)
              .width(20)
              .height(20)
              .borderRadius(10)
              .backgroundColor($r('app.color.heat_empty'))
          }
          Text(this.node.commitMessage)
            .fontFamily('monospace')
            .fontSize($r('app.float.body_font_size'))
            .fontColor($r('app.color.text_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
        }
        .layoutWeight(1)
        .height(20)
        .accessibilityDescription($r('app.string.a11y_open_commit'))
        .onClick((): void => this.onOpenCommit(this.node.commitOid))
      } else if (this.segs.length > 0) {
        // 段数上限 6（最长模板 = merged 三占位共 5 段）；超界的 Span 文本为空不占位
        Text() {
          Span(this.segText(0)).fontColor(this.segColor(0)).fontWeight(this.segWeight(0))
          Span(this.segText(1)).fontColor(this.segColor(1)).fontWeight(this.segWeight(1))
          Span(this.segText(2)).fontColor(this.segColor(2)).fontWeight(this.segWeight(2))
          Span(this.segText(3)).fontColor(this.segColor(3)).fontWeight(this.segWeight(3))
          Span(this.segText(4)).fontColor(this.segColor(4)).fontWeight(this.segWeight(4))
          Span(this.segText(5)).fontColor(this.segColor(5)).fontWeight(this.segWeight(5))
        }
        .fontSize($r('app.float.body_font_size'))
        .layoutWeight(1)
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .padding({ top: 6, bottom: 6 })
  }
}
