import promptAction from '@ohos.promptAction';

/** 课表菜单与“我的”页共用的检查更新入口；当前尚未接入远端服务。 */
export function checkForUpdate(): void {
  promptAction.showToast({ message: '当前版本 0.1.1，暂未接入在线更新服务', duration: 1600 });
}
