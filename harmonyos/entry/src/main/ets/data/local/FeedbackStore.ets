import preferences from '@ohos.data.preferences';
import common from '@ohos.app.ability.common';

export interface Feedback {
  id: string;
  text: string;
  contact: string;
  images: string[];
  createdAt: number;
  sent: boolean;
  retryAt?: number;
}
const FILE: string = 'fxw_feedback';
const KEY: string = 'items';

/** Serialize read-modify-write operations; never trim pending submissions. */
export class FeedbackStore {
  private static writes: Promise<void> = Promise.resolve();
  private static async read(ctx: common.UIAbilityContext): Promise<Feedback[]> {
    const p: preferences.Preferences = await preferences.getPreferences(ctx, FILE);
    const raw: string = await p.get(KEY, '') as string;
    if (raw.length === 0) { return []; }
    const items: Feedback[] = JSON.parse(raw) as Feedback[];
    if (!Array.isArray(items)) { throw new Error('Invalid feedback queue'); }
    return items;
  }
  private static mutate(ctx: common.UIAbilityContext, change: (items: Feedback[]) => Feedback[]): Promise<void> {
    const operation: Promise<void> = FeedbackStore.writes.then(async () => {
      const items: Feedback[] = change(await FeedbackStore.read(ctx));
      const p: preferences.Preferences = await preferences.getPreferences(ctx, FILE);
      await p.put(KEY, JSON.stringify(items));
      await p.flush();
    });
    FeedbackStore.writes = operation.catch(() => {});
    return operation;
  }
  static async list(ctx: common.UIAbilityContext): Promise<Feedback[]> {
    await FeedbackStore.writes;
    return FeedbackStore.read(ctx);
  }
  static async push(ctx: common.UIAbilityContext, f: Feedback): Promise<void> {
    return FeedbackStore.mutate(ctx, (items: Feedback[]) => {
      if (!items.some((item: Feedback) => item.id === f.id)) { items.unshift(f); }
      return items;
    });
  }
  static async pendingCount(ctx: common.UIAbilityContext): Promise<number> {
    return (await FeedbackStore.pending(ctx)).length;
  }
  static async markSent(ctx: common.UIAbilityContext, id: string): Promise<void> {
    return FeedbackStore.mutate(ctx, (items: Feedback[]) => {
      let sentCount: number = 0;
      items.forEach((item: Feedback) => {
        if (item.id === id) { item.sent = true; item.images = []; item.retryAt = 0; }
      });
      return items.filter((item: Feedback) => !item.sent || ++sentCount <= 30);
    });
  }
  static async defer(ctx: common.UIAbilityContext, id: string, retryAt: number): Promise<void> {
    return FeedbackStore.mutate(ctx, (items: Feedback[]) => {
      items.forEach((item: Feedback) => { if (item.id === id && !item.sent) { item.retryAt = retryAt; } });
      return items;
    });
  }
  static async pending(ctx: common.UIAbilityContext): Promise<Feedback[]> {
    return (await FeedbackStore.list(ctx)).filter((item: Feedback) => !item.sent).reverse();
  }
  static async clear(ctx: common.UIAbilityContext): Promise<void> {
    return FeedbackStore.mutate(ctx, (_items: Feedback[]) => []);
  }
}
