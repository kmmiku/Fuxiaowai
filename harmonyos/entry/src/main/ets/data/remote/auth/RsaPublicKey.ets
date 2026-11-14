import util from '@ohos.util';
import cryptoFramework from '@ohos.security.cryptoFramework';

/**
 * RSA 公钥加密（PKCS#1 v1.5），纯 ArkTS 实现。
 *
 * 为什么不用系统 cryptoFramework：
 * 正方教务下发的是 RSA-1024 公钥，部分系统加密库按安全策略拒绝 1024 位密钥；
 * 这里用 BigInt 直接做模幂，语义与教务前端 jsbn 的 RSAKey.encrypt 完全一致：
 *   EM = 0x00 || 0x02 || 随机非零填充 || 0x00 || 明文(UTF-8)
 *   C  = EM^e mod n，输出定长字节的 Base64
 */
export class RsaPublicKey {
  private modulus: bigint;
  private exponent: bigint;
  private byteSize: number;

  constructor(modulusB64: string, exponentB64: string) {
    const helper: util.Base64Helper = new util.Base64Helper();
    const modBytes: Uint8Array = helper.decodeSync(modulusB64);
    const expBytes: Uint8Array = helper.decodeSync(exponentB64);
    this.modulus = RsaPublicKey.bytesToBigInt(modBytes);
    this.exponent = RsaPublicKey.bytesToBigInt(expBytes);
    const hex: string = this.modulus.toString(16);
    this.byteSize = Math.ceil(hex.length / 2);
  }

  /** 模长（字节），1024 位 = 128 */
  size(): number {
    return this.byteSize;
  }

  /** 模数十六进制（诊断用：与浏览器/脚本取到的 modulus 比对） */
  modulusHex(): string {
    return this.modulus.toString(16);
  }

  /** 明文 UTF-8 加密后返回 Base64 密文 */
  encrypt(plain: string): string {
    const encoder: util.TextEncoder = new util.TextEncoder('utf-8');
    const msg: Uint8Array = encoder.encodeInto(plain);
    const k: number = this.byteSize;
    if (msg.length > k - 11) {
      throw new Error('密码过长，超过 RSA 可加密长度');
    }
    const em: Uint8Array = new Uint8Array(k);
    em[0] = 0x00;
    em[1] = 0x02;
    const padEnd: number = k - msg.length - 1;
    const random: cryptoFramework.Random = cryptoFramework.createRandom();
    let offset: number = 2;
    while (offset < padEnd) {
      const bytes: Uint8Array = random.generateRandomSync(padEnd - offset).data;
      for (let i = 0; i < bytes.length && offset < padEnd; i++) {
        if (bytes[i] !== 0) { em[offset++] = bytes[i]; }
      }
    }
    em[padEnd] = 0x00;
    em.set(msg, padEnd + 1);
    const m: bigint = RsaPublicKey.bytesToBigInt(em);
    const c: bigint = RsaPublicKey.modPow(m, this.exponent, this.modulus);
    const out: Uint8Array = RsaPublicKey.bigIntToBytes(c, k);
    const helper: util.Base64Helper = new util.Base64Helper();
    return helper.encodeToStringSync(out);
  }

  private static modPow(base: bigint, exp: bigint, mod: bigint): bigint {
    let result: bigint = 1n;
    let b: bigint = base % mod;
    let e: bigint = exp;
    while (e > 0n) {
      if ((e & 1n) === 1n) {
        result = (result * b) % mod;
      }
      b = (b * b) % mod;
      e = e >> 1n;
    }
    return result;
  }

  private static bytesToBigInt(bytes: Uint8Array): bigint {
    let hex: string = '';
    for (let i = 0; i < bytes.length; i++) {
      const h: string = bytes[i].toString(16);
      hex += h.length === 1 ? '0' + h : h;
    }
    if (hex.length === 0) {
      return 0n;
    }
    return BigInt('0x' + hex);
  }

  private static bigIntToBytes(value: bigint, size: number): Uint8Array {
    const out: Uint8Array = new Uint8Array(size);
    let v: bigint = value;
    for (let i = size - 1; i >= 0; i--) {
      out[i] = parseInt((v & 255n).toString(), 10);
      v = v >> 8n;
    }
    return out;
  }
}

/** 学期推导：8 月及以后算新学年的第一学期（正方 xqm: 3=第一学期, 12=第二学期, 16=第三学期） */
export interface Semester {
  xnm: number;
  xqm: number;
  label: string;
}

export function currentSemester(now: Date): Semester {
  const y: number = now.getFullYear();
  const m: number = now.getMonth() + 1;
  const xnm: number = m >= 8 ? y : y - 1;
  const firstTerm: boolean = m >= 8 || m <= 1;
  const xqm: number = firstTerm ? 3 : 12;
  const label: string = `${xnm}-${xnm + 1}学年 第${firstTerm ? 1 : 2}学期`;
  return { xnm: xnm, xqm: xqm, label: label };
}
