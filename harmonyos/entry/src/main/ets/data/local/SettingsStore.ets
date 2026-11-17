import preferences from '@ohos.data.preferences';
import common from '@ohos.app.ability.common';

/** 课表显示设置（全局，单例读一次） */
export interface AppSettings {
  showWeekend: boolean;     // 显示周末两天
  showGhost: boolean;       // 是否显示非本周的课（其他周有、本周不上）
  density: number;          // 旧档位：0 紧凑 1 标准 2 宽松（仅用于迁移出 cellHeight）
  cellHeight: number;       // 课表格子高度 vp：CELL_MIN ~ CELL_MAX，无极调节
  cellWidth: number;        // 旧绝对vp值，仅兼容读取
  cellWidthRatio: number;   // 0自动，手动0.8～1
  dark: boolean;            // 深色模式
  theme: string;            // 主题标识：default / 后续扩展（当前仅占位）
  remindBefore: number;     // 上课提醒提前分钟数，0 表示关闭
  calendarRemind: boolean;  // 导出到系统日历时，日程是否也带提前提醒
}

export const DEFAULT_SETTINGS: AppSettings = {
  showWeekend: true,
  showGhost: false,
  density: 1,
  cellHeight: 60,
  cellWidth: 0,
  cellWidthRatio: 0,
  dark: false,
  theme: 'default',
  remindBefore: 0,
  calendarRemind: true
};

/** 行高可调范围（vp） */
export const CELL_MIN: number = 40;
export const CELL_MAX: number = 80;

/** 旧版三档行高，仅用于把老数据迁移成连续值 */
export const DENSITY_HEIGHT: number[] = [44, 52, 64];

const FILE: string = 'fxw_settings';
const KEY: string = 'app_settings';

function clamp(v: number, lo: number, hi: number): number {
  return v < lo ? lo : (v > hi ? hi : v);
}

export class SettingsStore {
  private static cached: AppSettings | null = null;

  static async load(ctx: common.Context): Promise<AppSettings> {
    if (SettingsStore.cached) {
      return SettingsStore.cached;
    }
    try {
      const p: preferences.Preferences = await preferences.getPreferences(ctx, FILE);
      const raw: string = await p.get(KEY, '') as string;
      if (raw.length === 0) {
        SettingsStore.cached = DEFAULT_SETTINGS;
        return DEFAULT_SETTINGS;
      }
      const saved: AppSettings = JSON.parse(raw) as AppSettings;
      const oldDensity: number = saved.density === 0 || saved.density === 2 ? saved.density : 1;
      const fallbackCell: number = DENSITY_HEIGHT[oldDensity];
      // 用默认值兜底，避免旧版本缺字段
      const merged: AppSettings = {
        showWeekend: saved.showWeekend !== false,
        showGhost: saved.showGhost === true,
        density: oldDensity,
        cellHeight: typeof saved.cellHeight === 'number' && !isNaN(saved.cellHeight)
          ? clamp(saved.cellHeight, CELL_MIN, CELL_MAX)
          : fallbackCell,
        cellWidth: typeof saved.cellWidth === 'number' && isFinite(saved.cellWidth) && saved.cellWidth > 0
          ? clamp(saved.cellWidth, 1, 55) : 0,
        cellWidthRatio: typeof saved.cellWidthRatio === 'number' && isFinite(saved.cellWidthRatio) && saved.cellWidthRatio > 0
          ? clamp(saved.cellWidthRatio, 0.8, 1) : 0,
        dark: saved.dark === true,
        theme: typeof saved.theme === 'string' && saved.theme.length > 0 ? saved.theme : 'default',
        remindBefore: saved.remindBefore > 0 ? saved.remindBefore : 0,
        calendarRemind: saved.calendarRemind !== false
      };
      SettingsStore.cached = merged;
      return merged;
    } catch (e) {
      SettingsStore.cached = DEFAULT_SETTINGS;
      return DEFAULT_SETTINGS;
    }
  }

  static async save(ctx: common.Context, s: AppSettings): Promise<boolean> {
    try {
      const p: preferences.Preferences = await preferences.getPreferences(ctx, FILE);
      await p.put(KEY, JSON.stringify(s));
      await p.flush();
      SettingsStore.cached = s;
      return true;
    } catch (e) {
      return false;
    }
  }

  /** 让下次 load 重新读盘 */
  static invalidate(): void {
    SettingsStore.cached = null;
  }
}