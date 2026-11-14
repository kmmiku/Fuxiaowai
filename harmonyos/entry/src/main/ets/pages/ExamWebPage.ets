import router from '@ohos.router';
import webview from '@ohos.web.webview';
import { Font, Palette, TC } from '../common/design/Tokens';

interface WebParams {
  url?: string;
  base?: string;
  cookie?: string;
}

/**
 * 内置浏览器：打开教务页面。
 * 已登录时把 App 里抓到的 JSESSIONID 注入 WebCookieManager，
 * 页面再发请求就带着同一会话，不用在网页里重输账号密码。
 */
@Entry
@Component
struct ExamWebPage {
  @StorageLink('dark') dark: boolean = false;
  @State title: string = '教务系统';
  @State progress: number = 0;
  @State loading: boolean = true;
  @State errMsg: string = '';
  private controller: webview.WebviewController = new webview.WebviewController();
  private target: string = 'http://jw.fzfu.edu.cn/jwglxt/kwgl/kscx_cxXsksxxIndex.html?gnmkdm=N358105';

  aboutToAppear(): void {
    const p: WebParams = router.getParams() as WebParams;
    if (p !== undefined && p !== null) {
      if (p.url !== undefined && p.url.length > 0) {
        this.target = p.url;
      }
      // Cookie 必须在 Web 组件创建前配置好，否则首帧请求漏带会话
      if (p.cookie !== undefined && p.cookie.length > 0) {
        const base: string = p.base !== undefined && p.base.length > 0 ? p.base : this.target;
        try {
          webview.WebCookieManager.configCookieSync(base, p.cookie);
        } catch (e) {
          // 注入失败不阻断浏览，用户在网页里重新登录即可
        }
      }
    }
  }

  /**
   * 正方页面是桌面版，没有 viewport meta，手机上会被整体缩成蚂蚁字。
   * 页面加载完注入一份 viewport，让它按手机宽度排版；表格仍可横向滑动。
   */
  private fixViewport(): void {
    const js: string =
      '(function(){' +
      'var h=document.head||document.getElementsByTagName("head")[0];' +
      'if(!h){return;}' +
      'var m=document.querySelector("meta[name=viewport]");' +
      'if(!m){m=document.createElement("meta");m.setAttribute("name","viewport");h.appendChild(m);}' +
      'm.setAttribute("content","width=device-width,initial-scale=1.0,maximum-scale=5.0,user-scalable=yes");' +
      'var s=document.getElementById("fxw-fit");' +
      'if(!s){s=document.createElement("style");s.id="fxw-fit";h.appendChild(s);}' +
      's.textContent="body{overflow-x:auto!important}table{max-width:none!important}";' +
      '})()';
    try {
      this.controller.runJavaScript(js);
    } catch (e) {
      // 控制器未就绪时忽略
    }
  }

  @Builder
  headerBar() {
    Row() {
      Text('‹')
        .fontSize(26)
        .fontColor(TC(this.dark).text)
        .width(40)
        .height(40)
        .textAlign(TextAlign.Center)
        .onClick(() => {
          router.back();
        })
      Text(this.title)
        .fontSize(Font.body)
        .fontWeight(FontWeight.Medium)
        .fontColor(TC(this.dark).text)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
        .margin({ left: 4 })
      Text('↻')
        .fontSize(18)
        .fontColor(TC(this.dark).text)
        .width(36)
        .height(36)
        .textAlign(TextAlign.Center)
        .onClick(() => {
          try {
            this.controller.refresh();
          } catch (e) {
            // 控制器未就绪时忽略
          }
        })
    }
    .width('100%')
    .height(48)
    .padding({ left: 6, right: 10 })
  }

  build() {
    Column() {
      this.headerBar()

      Stack({ alignContent: Alignment.Top }) {
        Web({ src: this.target, controller: this.controller })
          .width('100%')
          .height('100%')
          .javaScriptAccess(true)
          .domStorageAccess(true)
          .fileAccess(false)
          .metaViewport(true)
          .zoomAccess(true)
          .mixedMode(MixedMode.All)
          .cacheMode(CacheMode.Default)
          .darkMode(WebDarkMode.Auto)
          .onPageBegin(() => {
            this.loading = true;
            this.errMsg = '';
          })
          .onPageEnd((ev: OnPageEndEvent) => {
            this.loading = false;
            this.fixViewport();
            const t: string = ev !== undefined && ev.url !== undefined ? ev.url : '';
            if (t.indexOf('login_slogin') >= 0) {
              this.title = '登录教务系统';
            } else if (t.indexOf('kscx') >= 0) {
              this.title = '考试安排';
            } else if (t.indexOf('cjcx') >= 0) {
              this.title = '成绩查询';
            }
          })
          .onProgressChange((ev: OnProgressChangeEvent) => {
            this.progress = ev !== undefined ? ev.newProgress : 0;
          })
          .onErrorReceive((ev: OnErrorReceiveEvent) => {
            this.loading = false;
            if (ev !== undefined && ev.error !== undefined) {
              this.errMsg = `加载失败：${ev.error.getErrorInfo()}`;
            }
          })
          .onHttpErrorReceive((ev: OnHttpErrorReceiveEvent) => {
            if (ev !== undefined && ev.response !== undefined) {
              this.errMsg = `服务器返回 ${ev.response.getResponseCode()}`;
            }
          })

        if (this.loading) {
          Progress({ value: this.progress, total: 100, type: ProgressType.Linear })
            .width('100%')
            .height(2)
            .color(Palette.primary)
            .backgroundColor(Color.Transparent)
        }

        if (this.errMsg.length > 0) {
          Column() {
            Text('打不开教务页面')
              .fontSize(Font.body)
              .fontColor(TC(this.dark).text)
            Text(this.errMsg)
              .fontSize(Font.small)
              .fontColor(TC(this.dark).textSub)
              .textAlign(TextAlign.Center)
              .margin({ top: 8 })
            Text('校园网外访问不到 jw.fzfu.edu.cn，连接校园网或 VPN 后重试')
              .fontSize(Font.tiny)
              .fontColor(TC(this.dark).textHint)
              .textAlign(TextAlign.Center)
              .margin({ top: 10 })
            Text('重试')
              .fontSize(Font.body)
              .fontColor(Color.White)
              .padding({ left: 24, right: 24, top: 9, bottom: 9 })
              .backgroundColor(Palette.primary)
              .borderRadius(10)
              .margin({ top: 16 })
              .onClick(() => {
                this.errMsg = '';
                try {
                  this.controller.refresh();
                } catch (e) {
                  // 忽略
                }
              })
          }
          .width('100%')
          .padding(32)
          .backgroundColor(TC(this.dark).card)
          .alignItems(HorizontalAlign.Center)
          .margin({ top: 60, left: 20, right: 20 })
          .borderRadius(14)
        }
      }
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(TC(this.dark).bg)
  }
}