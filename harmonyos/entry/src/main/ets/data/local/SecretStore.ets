import huks from '@ohos.security.huks';
import cryptoFramework from '@ohos.security.cryptoFramework';
import util from '@ohos.util';
import { BusinessError } from '@ohos.base';

const ALIAS: string = 'fxw.local.aes256.v1';

/** Authenticated encryption; the key stays in the platform keystore. */
export class SecretStore {
  private static ready: Promise<void> | null = null;

  private static properties(purpose: number): huks.HuksParam[] {
    return [
      { tag: huks.HuksTag.HUKS_TAG_ALGORITHM, value: huks.HuksKeyAlg.HUKS_ALG_AES },
      { tag: huks.HuksTag.HUKS_TAG_KEY_SIZE, value: huks.HuksKeySize.HUKS_AES_KEY_SIZE_256 },
      { tag: huks.HuksTag.HUKS_TAG_PURPOSE, value: purpose },
      { tag: huks.HuksTag.HUKS_TAG_PADDING, value: huks.HuksKeyPadding.HUKS_PADDING_NONE },
      { tag: huks.HuksTag.HUKS_TAG_BLOCK_MODE, value: huks.HuksCipherMode.HUKS_MODE_GCM }
    ];
  }

  private static async ensureKey(): Promise<void> {
    if (SecretStore.ready === null) {
      SecretStore.ready = SecretStore.createKey();
    }
    try {
      await SecretStore.ready;
    } catch (e) {
      SecretStore.ready = null;
      throw new Error('安全存储暂不可用，请重试');
    }
  }

  private static async createKey(): Promise<void> {
    let exists: boolean = false;
    try {
      exists = await huks.isKeyItemExist(ALIAS, { properties: [] });
    } catch (e) {
      // HUKS reports an absent key through rejection on supported platform versions.
      if ((e as BusinessError).code !== 12000011) { throw new Error('HUKS key query failed: ' + (e as BusinessError).code); }
    }
    if (!exists) {
      await huks.generateKeyItem(ALIAS, { properties: SecretStore.properties(
        huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_ENCRYPT | huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_DECRYPT) });
    }
  }

  static async seal(plain: string, context: string): Promise<string> {
    if (plain.length === 0) {
      return '';
    }
    await SecretStore.ensureKey();
    const nonce: Uint8Array = (await cryptoFramework.createRandom().generateRandom(12)).data;
    const params: huks.HuksParam[] = SecretStore.properties(huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_ENCRYPT);
    params.push({ tag: huks.HuksTag.HUKS_TAG_NONCE, value: nonce });
    params.push({ tag: huks.HuksTag.HUKS_TAG_ASSOCIATED_DATA, value: new util.TextEncoder().encodeInto(context) });
    const options: huks.HuksOptions = { properties: params, inData: new util.TextEncoder().encodeInto(plain) };
    const session: huks.HuksSessionHandle = await huks.initSession(ALIAS, options);
    let result: huks.HuksReturnResult;
    try {
      result = await huks.finishSession(session.handle, options);
    } catch (e) {
      try { await huks.abortSession(session.handle, { properties: [] }); } catch (ignored) {}
      throw new Error('安全存储加密失败');
    }
    const cipher: Uint8Array = result.outData as Uint8Array;
    if (cipher === undefined || cipher.length < 16) {
      throw new Error('安全存储返回无效数据');
    }
    const bytes: Uint8Array = new Uint8Array(nonce.length + cipher.length);
    bytes.set(nonce);
    bytes.set(cipher, nonce.length);
    return 'v1:' + new util.Base64Helper().encodeToStringSync(bytes);
  }

  static async open(value: string, context: string): Promise<string> {
    if (value.length === 0) {
      return '';
    }
    if (!value.startsWith('v1:') || value.length > 32768) {
      throw new Error('安全存储格式异常');
    }
    await SecretStore.ensureKey();
    const bytes: Uint8Array = new util.Base64Helper().decodeSync(value.substring(3));
    if (bytes.length < 29) {
      throw new Error('安全存储数据不完整');
    }
    const params: huks.HuksParam[] = SecretStore.properties(huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_DECRYPT);
    params.push({ tag: huks.HuksTag.HUKS_TAG_NONCE, value: bytes.slice(0, 12) });
    params.push({ tag: huks.HuksTag.HUKS_TAG_ASSOCIATED_DATA, value: new util.TextEncoder().encodeInto(context) });
    params.push({ tag: huks.HuksTag.HUKS_TAG_AE_TAG, value: bytes.slice(bytes.length - 16) });
    const options: huks.HuksOptions = { properties: params, inData: bytes.slice(12, bytes.length - 16) };
    const session: huks.HuksSessionHandle = await huks.initSession(ALIAS, options);
    try {
      const result: huks.HuksReturnResult = await huks.finishSession(session.handle, options);
      return util.TextDecoder.create('utf-8').decodeToString(result.outData as Uint8Array);
    } catch (e) {
      try { await huks.abortSession(session.handle, { properties: [] }); } catch (ignored) {}
      throw new Error('安全存储校验失败，请重新验证身份');
    }
  }
}
