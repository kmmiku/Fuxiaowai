import router from '@ohos.router';
import webview from '@ohos.web.webview';
import { SessionStore } from '../data/local/SessionStore';
import { AccountScope } from '../common/util/AccountScope';
import { TC, Palette } from '../common/design/Tokens';

interface ServiceParams { url?: string; title?: string; temporary?: boolean; }
@Entry
@Component
struct ServiceWebPage {
  @StorageLink('dark') dark: boolean = false;
  @State title: string = '';
  @State ready: boolean = false;
  @State error: string = '';
  @State progress: number = 0;
  private target: string = '';
  private temporary: boolean = false;
  private token: number = 0;
  private controller: webview.WebviewController = new webview.WebviewController();
  aboutToAppear(): void { this.prepare(); }
  aboutToDisappear(): void { try { this.controller.stop(); } catch (_) {} }
  onBackPress(): boolean {
    if (!this.temporary && this.controller.accessBackward()) { this.controller.backward(); return true; }
    return false;
  }
  private async prepare(): Promise<void> {
    const p: ServiceParams = router.getParams() as ServiceParams;
    const url: string = p.url || '';
    if (!/^https:\/\/(www\.fzfu\.com|passport\.neea\.edu\.cn|iam\.neea\.edu\.cn)\//.test(url) &&
      !url.startsWith('http://jw.fzfu.edu.cn/jwglxt/xsxk/')) { this.error = '不支持的服务地址'; return; }
    this.title = p.title || '校园服务'; this.target = url; this.temporary = p.temporary === true;
    this.token = AccountScope.token();
    if (url.startsWith('http://jw.fzfu.edu.cn/')) {
      const cookie: string = await SessionStore.loadJw();
      if (!AccountScope.valid(this.token)) { this.error = '账号已切换，请重新打开'; return; }
      if (!cookie) { this.error = '请先登录教务系统'; return; }
      try { webview.WebCookieManager.configCookieSync('http://jw.fzfu.edu.cn/jwglxt/', cookie); }
      catch (_) { this.error = '教务会话不可用，请重新登录'; return; }
    }
    this.ready = true;
  }
  build() {
    Column() {
      Row() {
        Text('‹').fontSize(28).fontColor(Palette.primary).width(44).height(44).textAlign(TextAlign.Center).onClick(() => router.back())
        Text(this.title).fontSize(18).fontWeight(FontWeight.Medium).fontColor(TC(this.dark).text).layoutWeight(1).textAlign(TextAlign.Center)
        Text('↻').fontSize(24).fontColor(Palette.primary).width(44).height(44).textAlign(TextAlign.Center).onClick(() => { if (this.ready) { this.controller.refresh(); } })
      }.width('100%').height(56)
      if (this.error) { Text(this.error).fontColor(TC(this.dark).textSub).padding(24) }
      if (this.ready) {
        Web({ src: this.target, controller: this.controller }).width('100%').layoutWeight(1)
          .javaScriptAccess(true).domStorageAccess(true).fileAccess(false).zoomAccess(true)
          .mixedMode(MixedMode.Compatible).onProgressChange((event: OnProgressChangeEvent) => { this.progress = event.newProgress; })
          .onPageBegin(() => {
            if (!AccountScope.valid(this.token) && !this.temporary) { this.controller.stop(); this.ready = false; this.error = '账号已切换，请重新打开'; }
          })
          .onErrorReceive((event: OnErrorReceiveEvent) => { if (event.request.isMainFrame()) { this.error = '网页加载失败，请检查网络后刷新'; } })
      } else { Blank() }
    }.width('100%').height('100%').backgroundColor(TC(this.dark).bg)
  }
}
