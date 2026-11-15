import { loadFeedback, saveFeedback } from './store';
import { postFeedback, deviceLabel } from './feedback';
import { accountToken, isCurrent } from './accountScope';
const active = new Map<string, Promise<boolean>>();
let tail: Promise<unknown> = Promise.resolve();
export function deliverFeedback(id: string): Promise<boolean> {
  const existing = active.get(id); if (existing) return existing;
  const token = accountToken();
  const task = tail.then(async () => {
    if (!isCurrent(token)) return false;
    const item = loadFeedback().find(f => f.id === id);
    if (!item || item.sent || (item.retryAt ?? 0) > Date.now()) return false;
    try {
      await postFeedback({text:item.text,contact:item.contact,images:item.images,requestId:item.id,
        app:'android',version:'0.1.0',device:deviceLabel()});
      if (!isCurrent(token)) return false;
      saveFeedback(loadFeedback().map(f => f.id === id ? {...f,sent:true,images:[],retryAt:undefined} : f));
      return true;
    } catch (error) {
      const e = error as {status?:number;retryAfter?:number};
      if (e.status === 429 && isCurrent(token)) {
        const retryAt = Date.now() + Math.max(1,e.retryAfter || 1800)*1000;
        saveFeedback(loadFeedback().map(f => f.id === id ? {...f,retryAt} : f));
      }
      throw error;
    }
  });
  active.set(id, task); tail=task.catch(() => undefined);
  void task.then(() => active.delete(id), () => active.delete(id));
  return task;
}
