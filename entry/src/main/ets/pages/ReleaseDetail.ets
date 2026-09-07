/**
 * Release 详情页（Spec 047）：版本头卡（Draft/Prerelease 徽章）+ body（040 直渲）+
 * 资产列表（下载/进度/取消/保存/分享/复制链接）。数据走 repository.release(tagName)。
 */
import { promptAction } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { fileIo as fs, picker } from '@kit.CoreFileKit';
import { systemShare } from '@kit.ShareKit';
import { OctIcon } from '../components/OctIcon';
import { MarkdownView } from '../components/MarkdownView';
import { DownloadRow } from '../components/DownloadRow';
import { ReactionBar } from '../components/ReactionBar';
import { ReleaseAsset, ReleaseDetailPage, formatBytes, releaseAssetBrowserUrl, monthDayText } from '../models/RepoSubModels';
import { RepoSubService } from '../services/RepoSubService';
import { DownloadService, DownloadTask } from '../services/DownloadService';
import { MarkdownService } from '../services/MarkdownService';
import { StateView } from '../components/StateView';
import { resText } from '../utils/I18n';

/** 大文件阈值：超过仅提示浏览器打开（spec 边界） */
const MAX_DOWNLOAD_BYTES = 200 * 1024 * 1024;

/** 速率计算采样：id → 上次采样 { t, bytes } */
interface SpeedSample {
  t: number;
  bytes: number;
}

@ComponentV2
export struct ReleaseDetailView {
  @Param owner: string = '';
  @Param name: string = '';
  @Param tag: string = '';
  @Param token: string = '';
  @Param pathStack: NavPathStack = new NavPathStack();
  @Local detail: ReleaseDetailPage | null = null;
  @Local loading: boolean = true;
  @Local errorMsg: string = '';
  @Local isRefreshing: boolean = false;
  @Local tasks: DownloadTask[] = [];
  /** 正文渲染 HTML（Release 无 bodyHTML，走 /markdown 渲染） */
  @Local bodyHtml: string = '';
  /** 500ms 心跳：驱动速度与进度重渲染 */
  @Local tick: number = 0;

  private lastBytes: Map<string, SpeedSample> = new Map();
  private unbind: () => void = (): void => { };
  private timer: number = -1;

  aboutToAppear(): void {
    this.refresh();
    this.unbind = DownloadService.subscribe((t: DownloadTask) => {
      const idx = this.tasks.findIndex((x: DownloadTask) => x.id === t.id);
      if (idx >= 0) {
        this.tasks.splice(idx, 1);
      }
      this.tasks.push(this.taskClone(t));
      // @Local 数组原地变更不触发刷新：换引用
      this.tasks = this.tasks.slice();
    });
    this.timer = setInterval(() => {
      this.tick++;
    }, 500);
  }

  aboutToDisappear(): void {
    this.unbind();
    if (this.timer >= 0) {
      clearInterval(this.timer);
    }
  }

  /** 任务对象浅拷贝（subscribe 回调里直接替换引用规避原地变更） */
  private taskClone(t: DownloadTask): DownloadTask {
    return {
      id: t.id,
      name: t.name,
      total: t.total,
      received: t.received,
      state: t.state,
      path: t.path,
      error: t.error
    };
  }

  private refresh(): void {
    this.loading = true;
    this.errorMsg = '';
    RepoSubService.fetchReleaseDetail(this.token, this.owner, this.name, this.tag)
      .then((page: ReleaseDetailPage | null) => {
        if (page === null) {
          this.errorMsg = this.stringOf($r('app.string.state_retry'));
        } else {
          this.detail = page;
          MarkdownService.renderMarkdown(this.token, page.body, `${this.owner}/${this.name}`)
            .then((html: string) => {
              this.bodyHtml = html;
            })
            .catch(() => {
            });
        }
        this.loading = false;
        this.isRefreshing = false;
      })
      .catch((e: Error) => {
        this.errorMsg = e.message;
        this.loading = false;
        this.isRefreshing = false;
      });
  }

  private stringOf(res: Resource): string {
    return resText(this.getUIContext(), res);
  }

  /** 任务运行速度（字节/秒；采样不足返回 0） */
  private speedOf(id: string): number {
    const task = this.tasks.find((t: DownloadTask) => t.id === id);
    if (task === undefined || task.state !== 'running') {
      return 0;
    }
    const now = Date.now();
    const prev = this.lastBytes.get(id);
    let speed = 0;
    if (prev !== undefined && prev.t < now) {
      speed = Math.max(0, (task.received - prev.bytes) * 1000 / (now - prev.t));
    }
    this.lastBytes.set(id, { t: now, bytes: task.received });
    return speed;
  }

  /** 点击资产：大文件仅提示浏览器；否则入队下载 */
  private startDownload(asset: ReleaseAsset): void {
    if (asset.size > MAX_DOWNLOAD_BYTES) {
      promptAction.showToast({ message: $r('app.string.release_large_file') });
      this.openBrowser(releaseAssetBrowserUrl(this.owner, this.name, this.tag, asset.name));
      return;
    }
    const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    if (ctx === undefined) {
      return;
    }
    DownloadService.enqueue(this.token, asset.url, asset.id, asset.name, ctx);
  }

  private copyUrl(url: string): void {
    const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, url);
    pasteboard.getSystemPasteboard().setDataSync(data);
    promptAction.showToast({ message: $r('app.string.release_copy_done') });
  }

  private openBrowser(url: string): void {
    const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    if (ctx === undefined || url === '') {
      return;
    }
    ctx.startAbility({
      action: 'ohos.want.action.viewData',
      entities: ['entity.system.browsable'],
      uri: url
    });
  }

  /** 保存到用户可见位置：系统保存对话框（DocumentViewPicker）→ 拷贝缓存文件 */
  private saveFile(task: DownloadTask): void {
    const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    if (ctx === undefined || task.path === '') {
      return;
    }
    const docPicker = new picker.DocumentViewPicker(ctx);
    const options = new picker.DocumentSaveOptions();
    options.newFileNames = [task.name];
    docPicker.save(options)
      .then((uris: string[]) => {
        if (uris.length === 0) {
          return;
        }
        try {
          fs.copyFileSync(task.path, uris[0]);
          promptAction.showToast({ message: $r('app.string.release_saved') });
        } catch (e) {
          promptAction.showToast({ message: this.stringOf($r('app.string.release_saved')) + ': ' + task.path });
        }
      })
      .catch(() => {
        // 用户取消或失败：保持当前提示，可再次点击
      });
  }

  /** 分享缓存文件（系统分享面板；失败降级提示复制链接） */
  private shareFile(task: DownloadTask): void {
    const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    if (ctx === undefined || task.path === '') {
      return;
    }
    try {
      const data = new systemShare.SharedData({ utd: 'general.file', uri: `file://${task.path}` });
      const controller = new systemShare.ShareController(data);
      controller.show(ctx, {}).catch(() => {
        this.copyUrl(`file://${task.path}`);
      });
    } catch (e) {
      this.copyUrl(`file://${task.path}`);
    }
  }

  @Builder
  badgeRow() {
    Row({ space: 6 }) {
      if (this.detail !== null) {
        // Latest 徽章=绿字淡绿底细描边，与 RepoReleases 头卡同款（官方对齐，走查修正八轮）
        if (this.detail.isLatest) {
          Text($r('app.string.releases_latest'))
            .fontSize(12)
            .fontColor($r('app.color.success_text'))
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .borderRadius(6)
            .outline({ width: 0.5, color: $r('app.color.success_text'), radius: 6, style: OutlineStyle.SOLID })
            .backgroundColor($r('app.color.success_subtle_bg'))
        }
        if (this.detail.isDraft) {
          Text(this.stringOf($r('app.string.release_draft_badge')))
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
            .padding({ left: 8, right: 8, top: 3, bottom: 3 })
            .borderRadius(12)
            .backgroundColor($r('app.color.chip_bg'))
        }
        if (this.detail.isPrerelease) {
          Text(this.stringOf($r('app.string.release_prerelease_badge')))
            .fontSize(12)
            .fontColor($r('app.color.warning_text'))
            .padding({ left: 8, right: 8, top: 3, bottom: 3 })
            .borderRadius(12)
            .backgroundColor($r('app.color.attention_bg'))
        }
      }
    }
    .width('100%')
  }

  @Builder
  assetRow(asset: ReleaseAsset) {
    Row({ space: 4 }) {
      // 左侧点击区=下载（菜单按钮为兄弟节点防误触，同 PrDiffCard 文件行模式）
      Row({ space: 12 }) {
        OctIcon({ res: $r('app.media.oct_file_zip_16'), iconSize: 16, iconColor: $r('app.color.text_secondary') })
        Column({ space: 4 }) {
          Text(asset.name)
            .fontSize($r('app.float.body_font_size'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
          // 官方尺寸胶囊：zip 图标 + 大小（chip 底+细描边）
          Row({ space: 4 }) {
            OctIcon({ res: $r('app.media.oct_file_zip_16'), iconSize: 12, iconColor: $r('app.color.text_secondary') })
            Text(formatBytes(asset.size))
              .fontSize($r('app.float.caption_font_size'))
              .fontColor($r('app.color.text_secondary'))
          }
          .alignItems(VerticalAlign.Center)
          .padding({ left: 8, right: 8, top: 2, bottom: 2 })
          .borderRadius(10)
          .border({ width: 0.5, color: $r('app.color.divider') })
          .backgroundColor($r('app.color.chip_bg'))
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .layoutWeight(1)
      .alignItems(VerticalAlign.Center)
      .accessibilityDescription(asset.name)
      .onClick(() => this.startDownload(asset))
      // 右侧 … 菜单（Download / Copy link / Open in browser）
      Stack() {
        OctIcon({ res: $r('app.media.oct_kebab_horizontal_16'), iconSize: 18, iconColor: $r('app.color.text_secondary') })
      }
      .width(44)
      .height(44)
      .bindMenu([
        {
          value: this.stringOf($r('app.string.release_asset_download')),
          action: (): void => this.startDownload(asset)
        },
        {
          value: this.stringOf($r('app.string.release_copy_link')),
          action: (): void => this.copyUrl(releaseAssetBrowserUrl(this.owner, this.name, this.tag, asset.name))
        },
        {
          value: this.stringOf($r('app.string.release_show_browser')),
          action: (): void => this.openBrowser(releaseAssetBrowserUrl(this.owner, this.name, this.tag, asset.name))
        }
      ])
    }
    .width('100%')
    .padding({ top: 4, bottom: 4 })
    .alignItems(VerticalAlign.Center)
  }

  build() {
    Column() {
      Row({ space: 8 }) {
        Stack() {
          OctIcon({ res: $r('app.media.oct_arrow_left_24'), iconSize: 20, iconColor: $r('app.color.text_primary') })
        }
.width(44)
.height(44)
        .accessibilityDescription($r('app.string.a11y_back'))
        .focusable(true)
        .onClick(() => {
          this.pathStack.pop();
        })
        // 官方布局：两行标题=灰小字 owner / repo + release 标题；右上单图标蓝 share-android（走查修正七轮）
        Column({ space: 0 }) {
          Text(`${this.owner} / ${this.name}`)
            .fontSize($r('app.float.caption_font_size'))
            .fontColor($r('app.color.text_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.detail !== null && this.detail.name !== '' ? this.detail.name : this.tag)
            .fontSize($r('app.float.title_font_size'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Stack() {
          OctIcon({ res: $r('app.media.oct_share_android_16'), iconSize: 18, iconColor: $r('app.color.link_blue') })
        }
.width(44)
.height(44)
        .padding(6)
        .accessibilityDescription($r('app.string.a11y_share'))
        .focusable(true)
        .onClick(() => {
          if (this.detail !== null) {
            this.copyUrl(this.detail.releaseUrl);
          }
        })
      }
      .width('100%')
      .height(56)
      .padding({ left: 0, right: 0 })

      Refresh({ refreshing: $$this.isRefreshing }) {
        Scroll() {
          Column() {
            if (this.detail !== null) {
            // 版本头卡：大标题=release name（如 1.3.2），tag（v1.3.2）降为小字（走查修正）
            Column({ space: 8 }) {
              Text(this.detail.name !== '' ? this.detail.name : this.detail.tagName)
                .fontSize(32)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_primary'))
                .width('100%')
              this.badgeRow()
              Row({ space: 8 }) {
                if (this.detail.authorAvatar !== '') {
                  Image(this.detail.authorAvatar)
                    .width(22)
                    .height(22)
                    .borderRadius(11)
                    .backgroundColor($r('app.color.heat_empty'))
                }
                // 与列表页头卡同款：作者名黑体 + released this + 具体日期（走查修正六轮）
                Text(this.detail.authorLogin)
                  .fontSize($r('app.float.caption_font_size'))
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.text_primary'))
                Text(resText(this.getUIContext(), $r('app.string.releases_released_this'),
                  monthDayText(this.detail.publishedAt !== ''
                    ? this.detail.publishedAt : this.detail.createdAt)))
                  .fontSize($r('app.float.caption_font_size'))
                  .fontColor($r('app.color.text_secondary'))
              }
              .width('100%')

              if (this.detail.body !== '' || this.detail.bodyHTML !== '') {
                Divider().color($r('app.color.divider'))
                MarkdownView({
                  html: this.bodyHtml,
                  fallbackText: this.detail.body,
                  onNavigate: (rp: string, param: string) => {
                    this.pathStack.pushPathByName(rp, param);
                  }
                })
              }
              // 官方 release 反应行：笑脸圆钮弹六宫格，芯片整颗可点翻转，长按进 Reactees 整页
              ReactionBar({
                token: this.token,
                subjectId: this.detail.id,
                reactions: this.detail.reactions,
                smileyTrigger: true,
                onOpenUsers: (subjectId: string, content: string): void => {
                  // id 经 encodeURIComponent（GraphQL id 为 base64，可能含 /）
                  this.pathStack.pushPathByName('reactionUsers',
                    `${encodeURIComponent(subjectId)}/${content}`);
                }
              })
            }
            .alignItems(HorizontalAlign.Start)
            .padding($r('app.float.card_padding'))
            .borderRadius($r('app.float.card_radius'))
            .backgroundColor($r('app.color.card_background'))
            .width('100%')
            .margin({ bottom: 12 })

            // Info 分区（官方布局：分区灰标题 + 图标行；走查修正八轮）
            Divider().color($r('app.color.divider'))
            Text($r('app.string.release_info_title'))
              .fontSize($r('app.float.caption_font_size'))
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_secondary'))
              .width('100%')
              .padding({ top: 12, bottom: 4 })
            if (this.detail.tagSha !== '') {
              Row({ space: 12 }) {
                OctIcon({ res: $r('app.media.oct_git_commit_16'), iconSize: 16, iconColor: $r('app.color.text_secondary') })
                Text(this.detail.tagSha.substring(0, 7))
                  .fontSize($r('app.float.caption_font_size'))
                  .fontColor($r('app.color.text_secondary'))
              }
              .width('100%')
              .padding({ top: 10, bottom: 10 })
            }
            if (this.detail.tagName !== '') {
              Row({ space: 12 }) {
                OctIcon({ res: $r('app.media.oct_tag_16'), iconSize: 16, iconColor: $r('app.color.text_secondary') })
                Text(this.detail.tagName)
                  .fontSize($r('app.float.caption_font_size'))
                  .fontColor($r('app.color.text_secondary'))
              }
              .width('100%')
              .padding({ top: 10, bottom: 10 })
            }

            // Assets 分区（官方布局）：无资产时整个分区不渲染（走查修正九轮）
            if (this.detail.assets.length > 0) {
              Divider().color($r('app.color.divider'))
              Text($r('app.string.release_assets_title'))
                .fontSize($r('app.float.caption_font_size'))
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.text_secondary'))
                .width('100%')
                .padding({ top: 12, bottom: 4 })
              ForEach(this.detail.assets, (asset: ReleaseAsset) => {
                this.assetRow(asset)
              }, (asset: ReleaseAsset) => asset.id)
            }

            // 下载任务
            if (this.tasks.length > 0) {
              Text(this.stringOf($r('app.string.pr_changes_title')))
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.text_primary'))
                .width('100%')
                .padding({ bottom: 8 })
              ForEach(this.tasks, (task: DownloadTask) => {
                DownloadRow({
                  task: task,
                  speed: this.speedOf(task.id),
                  onCancel: (id: string) => DownloadService.cancel(id),
                  onSave: (t: DownloadTask) => this.saveFile(t),
                  onShare: (t: DownloadTask) => this.shareFile(t),
                  onCopy: (t: DownloadTask) => this.copyUrl(`file://${t.path}`)
                })
              }, (task: DownloadTask) => task.id)
            }
          } else if (this.loading || this.errorMsg !== '') {
            StateView({ loading: this.loading, error: this.errorMsg, onRetry: () => this.refresh() })
          }
        }
        .padding({ left: 16, right: 16, bottom: 16 })
        .width('100%')
      }
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
      }
      .layoutWeight(1)
      .onRefreshing((): void => {
        this.isRefreshing = true;
        this.refresh();
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_page'))
  }
}
