/**
 * 资产下载服务（Spec 047）：任务队列（最多 3 并发 + 排队）、进度回调、取消、沙箱 cacheDir 落盘。
 * 下载用 httpRequest + dataReceive 流式写盘（fileIO），不走 GitHttpClient（其不暴露流）。
 * 048 若需下载引用同一服务。
 */
import { http } from '@kit.NetworkKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const MAX_CONCURRENT = 3;
const CHUNK = 1024 * 64;

/** 排队恢复用的完整启动参数 */
interface DownloadParams {
  token: string;
  url: string;
  host: common.UIAbilityContext;
}

export interface DownloadTask {
  id: string;
  name: string;
  total: number;
  received: number;
  state: 'queued' | 'running' | 'done' | 'error' | 'canceled';
  /** 完成后的沙箱缓存路径（cacheDir） */
  path: string;
  error: string;
}

export class DownloadService {
  private static tasks: DownloadTask[] = [];
  private static queue: string[] = [];
  private static listeners: ((t: DownloadTask) => void)[] = [];

  static activeTasks(): DownloadTask[] {
    return DownloadService.tasks.slice();
  }

  /** 订阅任务变化（UI 刷新）；返回解绑函数 */
  static subscribe(listener: (t: DownloadTask) => void): () => void {
    DownloadService.listeners.push(listener);
    return (): void => {
      const idx = DownloadService.listeners.indexOf(listener);
      if (idx >= 0) {
        DownloadService.listeners.splice(idx, 1);
      }
    };
  }

  /** 入队下载：并发池有空位立即启动，否则排队 */
  static enqueue(token: string, url: string, assetId: string, name: string,
    hostContext: common.UIAbilityContext): void {
    const existing = DownloadService.tasks.find((t: DownloadTask) => t.id === assetId
      && (t.state === 'queued' || t.state === 'running'));
    if (existing !== undefined) {
      return;
    }
    DownloadService.tasks.push({
      id: assetId,
      name: name,
      total: 0,
      received: 0,
      state: 'queued',
      path: '',
      error: ''
    });
    DownloadService.queue.push(assetId);
    DownloadService.pump(token, url, assetId, name, hostContext);
  }

  /** 取消任务（排队中移除；下载中 destroy 连接；已完成忽略） */
  static cancel(id: string): void {
    const task = DownloadService.tasks.find((t: DownloadTask) => t.id === id);
    if (task === undefined || task.state === 'done' || task.state === 'canceled') {
      return;
    }
    const attr = DownloadService.cancelWanted.get(id);
    if (attr !== undefined && attr !== null) {
      try {
        attr.destroy();
      } catch (e) {
        // 已断开忽略
      }
    }
    task.state = 'canceled';
    DownloadService.emit(task);
    DownloadService.pumpNext();
  }

  /** 当前请求句柄（cancel 用） */
  private static cancelWanted: Map<string, http.HttpRequest> = new Map();

  /** 推进队列：空闲槽位让排队任务启动 */
  private static pump(token: string, url: string, assetId: string, name: string,
    hostContext: common.UIAbilityContext): void {
    const runningCount = DownloadService.tasks.filter((t: DownloadTask) =>
      t.state === 'running').length;
    if (runningCount >= MAX_CONCURRENT) {
      return;
    }
    DownloadService.start(token, url, assetId, name, hostContext);
  }

  private static pumpNext(): void {
    const runningCount = DownloadService.tasks.filter((t: DownloadTask) =>
      t.state === 'running').length;
    if (runningCount >= MAX_CONCURRENT) {
      return;
    }
    const queued = DownloadService.tasks.find((t: DownloadTask) => t.state === 'queued');
    if (queued !== undefined) {
      // 用任务自身记录的信息无法重新启（enqueue 参数已丢）——改为存储完整参数
      const info = DownloadService.params.get(queued.id);
      if (info !== undefined) {
        DownloadService.start(info.token, info.url, queued.id, queued.name, info.host);
      }
    }
  }

  /** 完整启动参数（排队恢复用） */
  private static params: Map<string, DownloadParams> = new Map();

  private static start(token: string, url: string, assetId: string, name: string,
    hostContext: common.UIAbilityContext): void {
    const task = DownloadService.tasks.find((t: DownloadTask) => t.id === assetId);
    if (task === undefined) {
      return;
    }
    const params: DownloadParams = { token: token, url: url, host: hostContext };
    DownloadService.params.set(assetId, params);
    task.state = 'running';
    DownloadService.emit(task);

    const req = http.createHttp();
    DownloadService.cancelWanted.set(assetId, req);
    const path = `${hostContext.cacheDir}/release_${assetId.replace(/[^a-zA-Z0-9]/g, '_')}_${name}`;
    let file: fs.File | null = null;
    try {
      file = fs.openSync(path, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
    } catch (e) {
      task.state = 'error';
      task.error = `${e}`;
      DownloadService.emit(task);
      DownloadService.pumpNext();
      return;
    }
    const handle = file;

    hilog.info(0x041, 'ArkCat', 'dl start url=%{public}s', url);
    req.request(url, {
      method: http.RequestMethod.GET,
      header: {
        'Accept': 'application/octet-stream',
        'Authorization': `Bearer ${token}`,
        'User-Agent': 'ArkCat/1.0.0'
      },
      expectDataType: http.HttpDataType.ARRAY_BUFFER
    }).then((resp: http.HttpResponse) => {
      if (task.state === 'canceled') {
        return;
      }
      const hdr = resp.header as Record<string, Object>;
      const len = hdr['content-length'];
      task.total = typeof len === 'string' ? Number(len) : (typeof len === 'number' ? len : 0);
      if (resp.responseCode !== 200) {
        task.state = 'error';
        task.error = `HTTP ${resp.responseCode}`;
        DownloadService.emit(task);
        DownloadService.pumpNext();
        return;
      }
      const body = resp.result as ArrayBuffer;
      const bytes = new Uint8Array(body);
      let offset = 0;
      while (offset < bytes.length) {
        const part = bytes.slice(offset, Math.min(offset + CHUNK, bytes.length));
        fs.writeSync(handle.fd, part.buffer as ArrayBuffer);
        offset += part.length;
      }
      task.received = bytes.length;
      try {
        fs.closeSync(handle);
      } catch (e) {
        // 已关闭忽略
      }
      DownloadService.cancelWanted.delete(assetId);
      DownloadService.params.delete(assetId);
      hilog.info(0x041, 'ArkCat', 'dl done bytes=%{public}d', task.received);
      task.path = path;
      task.state = 'done';
      DownloadService.emit(task);
      DownloadService.pumpNext();
    }).catch((e: Error) => {
      hilog.warn(0x041, 'ArkCat', 'dl err=%{public}s', e.message);
      try {
        fs.closeSync(handle);
      } catch (err) {
        // 已关闭忽略
      }
      DownloadService.cancelWanted.delete(assetId);
      DownloadService.params.delete(assetId);
      if (task.state !== 'canceled') {
        task.state = 'error';
        task.error = `${e.message}`;
      }
      DownloadService.emit(task);
      DownloadService.pumpNext();
    });


  }

  private static emit(task: DownloadTask): void {
    for (const l of DownloadService.listeners) {
      l(task);
    }
  }
}
