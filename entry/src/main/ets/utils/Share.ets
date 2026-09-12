/**
 * 系统分享面板封装（Spec 061）：全 App 分享按钮的唯一出口。
 *
 * 链接分享走 ShareKit HYPERLINK（面板内提供链接预览卡与目标应用列表），文件分享走
 * general.file + 沙箱 file:// URI；面板拉起失败统一 toast，文件分享可传降级回调。
 * 各页面的 github.com 页面地址也集中在此（纯函数，宿主单测覆盖），避免逐页各拼一份字符串。
 */
import { UIContext } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { systemShare } from '@kit.ShareKit';
import { uniformTypeDescriptor as utd } from '@kit.ArkData';

/** 系统面板选项：默认预览卡 + 单选目标 */
const SHARE_OPTIONS: systemShare.ShareControllerOptions = {
  previewMode: systemShare.SharePreviewMode.DEFAULT,
  selectionMode: systemShare.SelectionMode.SINGLE
};

/** 用户 / 组织主页地址 */
export function userPageUrl(login: string): string {
  return `https://github.com/${login}`;
}

/** 仓库主页地址 */
export function repoPageUrl(owner: string, name: string): string {
  return `https://github.com/${owner}/${name}`;
}

/** 仓库目录地址（dirPath 为空 = 根目录，即仓库主页；ref 固定 HEAD） */
export function repoTreeUrl(owner: string, name: string, dirPath: string): string {
  if (dirPath === '') {
    return repoPageUrl(owner, name);
  }
  return `${repoPageUrl(owner, name)}/tree/HEAD/${dirPath}`;
}

/** 代码文件地址（ref 固定 HEAD） */
export function blobPageUrl(owner: string, name: string, filePath: string): string {
  return `${repoPageUrl(owner, name)}/blob/HEAD/${filePath}`;
}

/** PR 详情地址 */
export function pullPageUrl(owner: string, name: string, number: number): string {
  return `${repoPageUrl(owner, name)}/pull/${number}`;
}

/** Issue 详情地址 */
export function issuePageUrl(owner: string, name: string, number: number): string {
  return `${repoPageUrl(owner, name)}/issues/${number}`;
}

/** Commit 详情地址 */
export function commitPageUrl(owner: string, name: string, oid: string): string {
  return `${repoPageUrl(owner, name)}/commit/${oid}`;
}

/** 取页面所属 UIAbilityContext；无宿主（如 preview）时返回 undefined */
function hostAbilityContext(ui: UIContext): common.UIAbilityContext | undefined {
  return ui.getHostContext() as common.UIAbilityContext | undefined;
}

/** 分享失败提示：面板未拉起（异常或用户侧失败）时兜底 */
function failToast(ui: UIContext): void {
  ui.getPromptAction().showToast({ message: $r('app.string.share_failed') });
}

/**
 * 分享链接：url 为空或拿不到宿主 Context 时静默返回（不弹面板）；
 * title 用于预览卡标题，缺省以 url 兜底。
 */
export function shareLink(ui: UIContext, url: string, title: string = ''): void {
  const ctx = hostAbilityContext(ui);
  if (ctx === undefined || url === '') {
    return;
  }
  try {
    const data = new systemShare.SharedData({
      utd: utd.UniformDataType.HYPERLINK,
      content: url,
      title: title === '' ? url : title
    });
    const controller = new systemShare.ShareController(data);
    controller.show(ctx, SHARE_OPTIONS).catch((): void => {
      failToast(ui);
    });
  } catch (e) {
    failToast(ui);
  }
}

/**
 * 分享本地文件（沙箱绝对路径）：面板拉起失败时执行 onFail（如复制链接），
 * 未传 onFail 则 toast 失败提示。
 */
export function shareFile(ui: UIContext, filePath: string, onFail?: () => void): void {
  const ctx = hostAbilityContext(ui);
  if (ctx === undefined || filePath === '') {
    return;
  }
  const fallback: () => void = onFail !== undefined ? onFail : (): void => failToast(ui);
  try {
    const data = new systemShare.SharedData({ utd: 'general.file', uri: `file://${filePath}` });
    const controller = new systemShare.ShareController(data);
    controller.show(ctx, SHARE_OPTIONS).catch((): void => {
      fallback();
    });
  } catch (e) {
    fallback();
  }
}
