import hilog from '@ohos.hilog';

/** Authentication diagnostics never emit caller supplied values or remote text. */
export class PrivateLog {
  static info(domain: number, tag: string, format: string, ...values: (string | number | boolean)[]): void {
    hilog.info(domain, tag, 'authentication operation');
  }
  static warn(domain: number, tag: string, format: string, ...values: (string | number | boolean)[]): void {
    hilog.warn(domain, tag, 'authentication operation incomplete');
  }
  static error(domain: number, tag: string, format: string, ...values: (string | number | boolean)[]): void {
    hilog.error(domain, tag, 'authentication operation failed');
  }
}
