import common from '@ohos.app.ability.common';
import fs from '@ohos.file.fs';
import image from '@ohos.multimedia.image';
import util from '@ohos.util';
import cryptoFramework from '@ohos.security.cryptoFramework';
import { Feedback, FeedbackStore } from '../local/FeedbackStore';
import { FeedbackRequest, uploadFeedback } from './ShareApi';
import { AccountScope } from '../../common/util/AccountScope';

export function newFeedbackId(): string {
  const bytes: Uint8Array = cryptoFramework.createRandom().generateRandomSync(12).data;
  let suffix: string = '';
  bytes.forEach((value: number) => { suffix += value.toString(16).padStart(2, '0'); });
  return `fb_${Date.now()}_${suffix}`;
}

/** Always decode and re-encode, so the MIME type and actual bytes agree. */
export async function encodeFeedbackImage(uri: string): Promise<string> {
  const file: fs.File = fs.openSync(uri, fs.OpenMode.READ_ONLY);
  let source: image.ImageSource | undefined = undefined;
  let packer: image.ImagePacker | undefined = undefined;
  try {
    source = image.createImageSource(file.fd);
    const info: image.ImageInfo = await source.getImageInfo();
    if (info.size.width <= 0 || info.size.height <= 0) { throw new Error('图片尺寸无效'); }
    packer = image.createImagePacker();
    const edges: number[] = [1600, 1200, 900, 600];
    const qualities: number[] = [85, 65, 45, 30];
    for (let i = 0; i < edges.length; i++) {
      const scale: number = Math.min(1, edges[i] / Math.max(info.size.width, info.size.height));
      const pixels: image.PixelMap = await source.createPixelMap({ desiredSize: {
        width: Math.max(1, Math.round(info.size.width * scale)), height: Math.max(1, Math.round(info.size.height * scale))
      } });
      try {
        for (let q = 0; q < qualities.length; q++) {
          const bytes: ArrayBuffer = await packer.packing(pixels, { format: 'image/jpeg', quality: qualities[q] });
          if (bytes.byteLength > 0 && bytes.byteLength <= 900000) {
            return 'data:image/jpeg;base64,' + new util.Base64Helper().encodeToStringSync(new Uint8Array(bytes));
          }
        }
      } finally { await pixels.release(); }
    }
    throw new Error('图片压缩后仍然过大');
  } finally {
    if (packer !== undefined) { await packer.release().catch(() => {}); }
    if (source !== undefined) { await source.release().catch(() => {}); }
    fs.closeSync(file);
  }
}

/** Only remove cache copies owned by feedback; pending records retain their files. */
export function removeFeedbackImage(uri: string): void {
  const path: string = uri.startsWith('file://') ? uri.substring(7) : uri;
  if (!/\/fb_[^/]+\.[a-zA-Z0-9]+$/.test(path)) { return; }
  try { fs.unlinkSync(path); } catch (_) {}
}

export class FeedbackDelivery {
  private static sending: Promise<void> = Promise.resolve();
  static async send(ctx: common.UIAbilityContext, feedback: Feedback): Promise<string> {
    const token: number = AccountScope.token();
    const operation: Promise<string> = FeedbackDelivery.sending.then(() => FeedbackDelivery.deliver(ctx, feedback, token));
    FeedbackDelivery.sending = operation.then(() => {}, () => {});
    return operation;
  }
  private static async deliver(ctx: common.UIAbilityContext, feedback: Feedback, token: number): Promise<string> {
    if (!AccountScope.valid(token)) { return 'fail'; }
    if (feedback.retryAt !== undefined && feedback.retryAt > Date.now()) { return 'limited'; }
    const existing: Feedback | undefined = (await FeedbackStore.list(ctx)).find((item: Feedback) => item.id === feedback.id);
    if (existing === undefined || !AccountScope.valid(token)) { return 'fail'; }
    if (existing !== undefined && existing.sent) { return 'ok'; }
    if (existing !== undefined && existing.retryAt !== undefined && existing.retryAt > Date.now()) { return 'limited'; }
    const images: string[] = [];
    try {
      if (feedback.images.length > 3) { throw new Error('图片数量过多'); }
      for (let i = 0; i < feedback.images.length; i++) { images.push(await encodeFeedbackImage(feedback.images[i])); }
    } catch (_) { return 'image'; }
    const payload: FeedbackRequest = { text: feedback.text, contact: feedback.contact, images: images,
      app: 'harmony', version: '0.1.1', device: 'HarmonyOS', requestId: feedback.id };
    try {
      if (!AccountScope.valid(token)) { return 'fail'; }
      await uploadFeedback(payload);
      await FeedbackStore.markSent(ctx, feedback.id);
      feedback.images.forEach((uri: string) => { removeFeedbackImage(uri); });
      return 'ok';
    } catch (error) {
      const message: string = error instanceof Error ? error.message : '';
      if (message.startsWith('TOO_FREQUENT')) {
        const raw: number = Number(message.split(':')[1]);
        const seconds: number = Number.isFinite(raw) && raw > 0 ? raw : 1800;
        feedback.retryAt = Date.now() + seconds * 1000;
        await FeedbackStore.defer(ctx, feedback.id, feedback.retryAt);
        return 'limited';
      }
      return 'fail';
    }
  }
  static async flush(ctx: common.UIAbilityContext): Promise<void> {
    const list: Feedback[] = await FeedbackStore.pending(ctx);
    for (let i = 0; i < list.length; i++) {
      if (list[i].retryAt !== undefined && (list[i].retryAt as number) > Date.now()) { continue; }
      const state: string = await FeedbackDelivery.send(ctx, list[i]);
      if (state === 'image') { throw new Error('待提交反馈的图片处理失败，内容仍保存在本机'); }
      if (state !== 'ok') { break; }
    }
  }
}
