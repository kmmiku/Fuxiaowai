import UIAbility from '@ohos.app.ability.UIAbility';
import AbilityConstant from '@ohos.app.ability.AbilityConstant';
import Want from '@ohos.app.ability.Want';
import window from '@ohos.window';
import hilog from '@ohos.hilog';
import { BusinessError } from '@ohos.base';
import { Locator } from '../app/di/ServiceLocator';
import { AppSettings, SettingsStore } from '../data/local/SettingsStore';

const DOMAIN: number = 0x0001;
const TAG: string = 'Fuxiaowai';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'EntryAbility onCreate');
    this.init().catch((e: BusinessError) => {
      hilog.error(DOMAIN, TAG, 'init failed: %{public}s', JSON.stringify(e));
    });
  }

  /** 打开数据库（幂等），页面 aboutToAppear 时可直接查库 */
  private async init(): Promise<void> {
    try {
      await Locator.init(this.context);
      hilog.info(DOMAIN, TAG, '%{public}s', 'db ready');
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'open db failed: %{public}s', JSON.stringify(e));
    }
    // 全局主题开关：所有页面用 @StorageLink('dark') 跟随
    try {
      const s: AppSettings = await SettingsStore.load(this.context);
      AppStorage.setOrCreate('dark', s.dark);
    } catch (e) {
      AppStorage.setOrCreate('dark', false);
    }
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.loadContent('pages/Index', (err: BusinessError) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, 'loadContent failed: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, TAG, '%{public}s', 'loadContent ok');
    });
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'EntryAbility onDestroy');
  }
}