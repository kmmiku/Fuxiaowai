import { UIContext } from '@ohos.arkui.UIContext';
import promptAction from '@ohos.promptAction';
import common from '@ohos.app.ability.common';
import http from '@ohos.net.http';
import preferences from '@ohos.data.preferences';
import bundleManager from '@ohos.bundle.bundleManager';
import { updateManager } from '@kit.AppGalleryKit';
import { ComponentContent } from '@ohos.arkui.node';
import { UpdateDialogParams, updateDialogBuilder } from '../../ui/components/UpdateAnnouncement';

interface Release {
  versionCode: number;
  versionName: string;
  content: string;
}
interface ReleaseResponse { ok: boolean; release: Release | null; }
let busy: boolean = false;
let startupChecked: boolean = false;
let dialog: ComponentContent<UpdateDialogParams> | null = null;

async function announcement(current: number): Promise<Release | null> {
  const client: http.HttpRequest = http.createHttp();
  try {
    const res: http.HttpResponse = await client.request('https://fuxiaowai.xyz/api/app-update', {
      method: http.RequestMethod.GET, connectTimeout: 5000, readTimeout: 5000,
      expectDataType: http.HttpDataType.STRING
    });
    if (res.responseCode !== 200 || typeof res.result !== 'string' || res.result.length > 20000) { return null; }
    const body: ReleaseResponse = JSON.parse(res.result) as ReleaseResponse;
    const r: Release | null = body.release;
    if (!body.ok || r === null || !Number.isInteger(r.versionCode) || r.versionCode <= current ||
      typeof r.versionName !== 'string' || r.versionName.length > 40 ||
      typeof r.content !== 'string' || r.content.length === 0 || r.content.length > 2500) { return null; }
    return r;
  } catch (e) { return null; } finally { client.destroy(); }
}

async function install(context: common.UIAbilityContext): Promise<void> {
  try {
    const result: updateManager.ShowUpdateResultCode = await updateManager.showUpdateDialog(context);
    if (result !== updateManager.ShowUpdateResultCode.SHOW_DIALOG_SUCCESS) {
      promptAction.showToast({ message: '暂时无法打开更新，请在华为应用市场查看' });
    }
  } catch (e) { promptAction.showToast({ message: '暂时无法打开更新，请在华为应用市场查看' }); }
}

/** 每次冷启动一次；手动检查绕过版本忽略设置。 */
export async function checkForUpdate(context: common.UIAbilityContext, uiContext: UIContext, automatic: boolean = false): Promise<void> {
  if (busy || dialog !== null || (automatic && startupChecked)) { return; }
  if (automatic) { startupChecked = true; }
  busy = true;
  try {
    const result: updateManager.CheckUpdateResult = await updateManager.checkAppUpdate(context);
    if (result.updateAvailable !== updateManager.UpdateAvailableCode.LATER_VERSION_EXIST) {
      if (!automatic) { promptAction.showToast({ message: '当前已是最新版本' }); }
      return;
    }
    const current: number = bundleManager.getBundleInfoForSelfSync(bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT).versionCode;
    const release: Release | null = await announcement(current);
    const store: preferences.Preferences = await preferences.getPreferences(context, 'fxw_app_update');
    if (automatic && release !== null && await store.get('ignoredVersion', 0) === release.versionCode) { return; }
    const close = (): void => {
      if (dialog !== null) { uiContext.getPromptAction().closeCustomDialog(dialog); dialog = null; }
    };
    const params: UpdateDialogParams = {
      version: release !== null ? release.versionName : '',
      content: release !== null ? release.content : '华为应用市场已有新版本，点击立即更新查看详细说明。',
      canIgnore: release !== null, preview: false,
      onDismiss: (ignore: boolean) => {
        if (ignore && release !== null) {
          store.put('ignoredVersion', release.versionCode).then(() => store.flush()).catch(() => {
            promptAction.showToast({ message: '未能保存忽略设置，请重试' });
          });
        }
        close();
      },
      onUpdate: () => { close(); install(context); }
    };
    dialog = new ComponentContent(uiContext, wrapBuilder(updateDialogBuilder), params);
    await uiContext.getPromptAction().openCustomDialog(dialog, { autoCancel: false, alignment: DialogAlignment.Center, onDidDisappear: () => { dialog = null; } });

  } catch (e) {
    if (!automatic) { promptAction.showToast({ message: '无法检查更新，请稍后重试或前往华为应用市场查看' }); }
  } finally { busy = false; }
}

/** 仅本地样式验收：不会伪造商店结果或保存忽略版本。 */
export function previewUpdate(uiContext: UIContext): void {
  let preview: ComponentContent<UpdateDialogParams> | null = null;
  const close = (): void => {
    if (preview !== null) { uiContext.getPromptAction().closeCustomDialog(preview); }
  };
  const params: UpdateDialogParams = { version: '0.1.2（示例）',
    content: '• 优化课表分享与口令导入\n• 提升启动与网络检测稳定性\n• 修复若干已知问题',
    canIgnore: true, preview: true, onDismiss: () => close(),
    onUpdate: () => { close(); promptAction.showToast({ message: '预览模式：未执行更新' }); }
  };
  preview = new ComponentContent(uiContext, wrapBuilder(updateDialogBuilder), params);
  uiContext.getPromptAction().openCustomDialog(preview, { autoCancel: false, alignment: DialogAlignment.Center });
}
