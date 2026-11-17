import http from '@ohos.net.http';

/** 过渡 HTTP 会明文传输学号。备案后切换下方 HTTPS，保留系统证书验证，禁止忽略证书。 */
const METRICS_BASE: string = 'http://113.45.242.182';
// const METRICS_BASE: string = 'https://fuxiaowai.xyz';

/** 成功登录后尽力上报：不记录内容、不写本地队列，不阻塞登录。 */
export async function reportLoginMetric(studentId: string): Promise<void> {
  if (!/^\d{6,20}$/.test(studentId)) { return; }
  const request: http.HttpRequest = http.createHttp();
  try {
    await request.request(METRICS_BASE + '/api/user-metrics/login', {
      method: http.RequestMethod.POST,
      header: { 'Content-Type': 'application/json' },
      extraData: JSON.stringify({ studentId: studentId }),
      connectTimeout: 5000, readTimeout: 5000
    });
  } catch (_) {
    // 统计失败不重试、不输出个人数据。
  } finally { request.destroy(); }
}
