/**
 * 下载任务行（Spec 047）：进度条 + 已下载量/总量 + 速度；运行中可取消，
 * 完成后展开操作（保存到设备/分享/复制链接）。
 */
import { DownloadTask } from '../services/DownloadService';
import { resText } from '../utils/I18n';
import { OctIcon } from './OctIcon';
import { formatBytes } from '../models/RepoSubModels';

@ComponentV2
export struct DownloadRow {
  @Param task: DownloadTask = { id: '', name: '', total: 0, received: 0, state: 'queued',
    path: '', error: '' };
  /** 速度（字节/秒；由页面 tick 计算传入） */
  @Param speed: number = 0;
  @Event onCancel: (id: string) => void = (id: string): void => { };
  @Event onSave: (task: DownloadTask) => void = (task: DownloadTask): void => { };
  @Event onShare: (task: DownloadTask) => void = (task: DownloadTask): void => { };
  @Event onCopy: (task: DownloadTask) => void = (task: DownloadTask): void => { };

  private stringOf(res: Resource): string {
    return resText(this.getUIContext(), res);
  }

  /** 进度 0-100（total 未知时按 received 显示动画前段） */
  private percent(): number {
    if (this.task.state === 'done') {
      return 100;
    }
    if (this.task.total <= 0) {
      return Math.min(this.task.received > 0 ? 50 : 5, 99);
    }
    return Math.min(Math.floor(this.task.received * 100 / this.task.total), 99);
  }

  build() {
    Column({ space: 6 }) {
      Row({ space: 8 }) {
        OctIcon({ res: $r('app.media.oct_file_16'), iconSize: 14, iconColor: $r('app.color.text_secondary') })
        Text(this.task.name)
          .fontSize($r('app.float.body_font_size'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        if (this.task.state === 'running' || this.task.state === 'queued') {
          Text(this.stringOf($r('app.string.release_download_cancel')))
            .fontSize($r('app.float.caption_font_size'))
            .fontColor($r('app.color.link_blue'))
            .padding({ left: 8, top: 4, bottom: 4 })
            .onClick(() => this.onCancel(this.task.id))
        } else if (this.task.state === 'error') {
          Text(this.task.error !== ''
            ? this.task.error.substring(0, 20)
            : this.stringOf($r('app.string.release_download_failed')))
            .fontSize($r('app.float.caption_font_size'))
            .fontColor($r('app.color.danger_text'))
            .maxLines(1)
        }
      }
      .width('100%')

      if (this.task.state === 'running' || this.task.state === 'queued') {
        Progress({ value: this.percent(), total: 100, type: ProgressType.Linear })
          .width('100%')
          .height(4)
          .color($r('app.color.link_blue'))
          .backgroundColor($r('app.color.chip_bg'))
        Row({ space: 8 }) {
          if (this.task.state === 'running' && this.speed > 0) {
            Text(`${formatSpeed(this.speed)}/s`)
              .fontSize($r('app.float.caption_font_size'))
              .fontColor($r('app.color.text_secondary'))
          }
          Blank()
          Text(`${this.stringOf($r('app.string.release_download_done'))}: ${formatBytes(this.task.received)} / ${formatBytes(this.task.total)}`)
            .fontSize($r('app.float.caption_font_size'))
            .fontColor($r('app.color.text_secondary'))
        }
        .width('100%')
      }

      if (this.task.state === 'done') {
        Row({ space: 8 }) {
          Text(this.stringOf($r('app.string.release_save')))
            .fontSize($r('app.float.caption_font_size'))
            .fontColor($r('app.color.link_blue'))
            .padding({ left: 10, right: 10, top: 5, bottom: 5 })
            .borderRadius(6)
            .backgroundColor($r('app.color.chip_bg'))
            .onClick(() => this.onSave(this.task))
          Text(this.stringOf($r('app.string.release_share')))
            .fontSize($r('app.float.caption_font_size'))
            .fontColor($r('app.color.link_blue'))
            .padding({ left: 10, right: 10, top: 5, bottom: 5 })
            .borderRadius(6)
            .backgroundColor($r('app.color.chip_bg'))
            .onClick(() => this.onShare(this.task))
          Text(this.stringOf($r('app.string.release_copy_link')))
            .fontSize($r('app.float.caption_font_size'))
            .fontColor($r('app.color.link_blue'))
            .padding({ left: 10, right: 10, top: 5, bottom: 5 })
            .borderRadius(6)
            .backgroundColor($r('app.color.chip_bg'))
            .onClick(() => this.onCopy(this.task))
        }
        .width('100%')
        .margin({ top: 2 })
      }
    }
    .width('100%')
    .padding(12)
    .borderRadius($r('app.float.card_radius'))
    .backgroundColor($r('app.color.card_background'))
    .margin({ bottom: 8 })
  }
}

/** 字节速率 → 人类可读（KB/s 保留 1 位；0 显示空） */
function formatSpeed(bytesPerSec: number): string {
  if (bytesPerSec <= 0) {
    return '0 B';
  }
  const kb = bytesPerSec / 1024;
  if (kb < 1024) {
    return `${kb.toFixed(1)} KB`;
  }
  return `${(kb / 1024).toFixed(1)} MB`;
}
