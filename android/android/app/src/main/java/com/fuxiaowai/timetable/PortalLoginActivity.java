package com.fuxiaowai.timetable;

import android.app.Activity;
import android.content.Intent;
import android.graphics.Color;
import android.os.Bundle;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.webkit.CookieManager;
import android.webkit.WebResourceRequest;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.TextView;

/**
 * 统一身份认证的登录窗口。
 *
 * 门户 CAS 前面挂了动态防护（页面里的 tac.min.js/_pv0），纯 HTTP 客户端把字段、加密、
 * Cookie 全按浏览器发一遍，服务端仍然回「登录页面闲置时间过长，请打开新页面」；
 * 只有真浏览器内核能过。所以登录这一步交给 WebView：
 *   - 默认「静默模式」：窗口透明、账号密码自动填、自动提交，用户只看到登录页上的「正在登录…」，
 *     看不到网页跳转；拿到教务 Cookie 后立刻收工，课表仍由 HTTP 通道在后台抓。
 *   - 万一教学平台要求图片验证码，才把窗口显形让用户手输。
 */
public class PortalLoginActivity extends Activity {

    private WebView web;
    private LinearLayout bar;
    private LinearLayout root;
    private String entryUrl = "";
    private String prefillUser = "";
    private String prefillPwd = "";
    private boolean silent = true;
    private boolean finished = false;
    private int attempts = 0;
    private boolean revealed = false;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        Intent intent = getIntent();
        entryUrl = intent.getStringExtra("url");
        prefillUser = intent.getStringExtra("user") == null ? "" : intent.getStringExtra("user");
        prefillPwd = intent.getStringExtra("pwd") == null ? "" : intent.getStringExtra("pwd");
        silent = !"false".equals(intent.getStringExtra("silent"));

        root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setBackgroundColor(Color.WHITE);

        bar = buildBar();
        root.addView(bar, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));

        View line = new View(this);
        line.setBackgroundColor(Color.parseColor("#E6E8EE"));
        root.addView(line, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(1)));

        web = buildWebView();
        root.addView(web, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f));
        setContentView(root);

        if (silent) {
            // 透明 + 不可见：WebView 照常跑 JS，用户看不到这一步
            root.setAlpha(0f);
            bar.setVisibility(View.GONE);
            line.setVisibility(View.GONE);
        }

        if (entryUrl != null && entryUrl.length() > 0) {
            web.loadUrl(entryUrl);
        } else {
            finishWithResult(RESULT_CANCELED, "", "缺少登录地址");
        }
    }

    private LinearLayout buildBar() {
        LinearLayout head = new LinearLayout(this);
        head.setOrientation(LinearLayout.HORIZONTAL);
        head.setGravity(Gravity.CENTER_VERTICAL);
        head.setPadding(dp(16), dp(10), dp(8), dp(10));
        head.setBackgroundColor(Color.WHITE);

        TextView title = new TextView(this);
        title.setText("统一身份认证");
        title.setTextSize(16f);
        title.setTextColor(Color.parseColor("#2A2F3A"));
        head.addView(title, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f));

        Button cancel = new Button(this);
        cancel.setText("取消");
        cancel.setAllCaps(false);
        cancel.setTextColor(Color.parseColor("#2F7BF6"));
        cancel.setBackgroundColor(Color.TRANSPARENT);
        cancel.setOnClickListener(v -> finishWithResult(RESULT_CANCELED, "", "已取消登录"));
        head.addView(cancel);
        return head;
    }

    private WebView buildWebView() {
        WebView view = new WebView(this);
        WebSettings s = view.getSettings();
        s.setJavaScriptEnabled(true);
        s.setDomStorageEnabled(true);
        s.setDatabaseEnabled(true);
        s.setMixedContentMode(WebSettings.MIXED_CONTENT_ALWAYS_ALLOW);
        s.setCacheMode(WebSettings.LOAD_DEFAULT);

        CookieManager cm = CookieManager.getInstance();
        cm.setAcceptCookie(true);
        cm.setAcceptThirdPartyCookies(view, true);
        // 每次打开都从干净会话开始：否则上一个人登录过的门户 SSO 会把这次登录直接认成他
        cm.removeAllCookies(null);
        cm.flush();

        view.setWebViewClient(new WebViewClient() {
            @Override
            public void onPageFinished(WebView v, String url) {
                super.onPageFinished(v, url);
                if (url == null) return;

                if (url.startsWith("http://jw.fzfu.edu.cn/jwglxt/kbcx/")) {
                    // 跳转刚落地时 Cookie 还没落进 CookieManager，等一拍再收集
                    v.postDelayed(() -> finishWithResult(RESULT_OK, url, ""), 500);
                    return;
                }
                if (url.contains("/cas/login")) {
                    onCasPage(v);
                }
            }

            @Override
            public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) {
                return false;
            }
        });
        return view;
    }

    /** 到了 CAS 登录页：先自动填+自动交，交过就检查页面说了什么 */
    private void onCasPage(WebView view) {
        String probe = "(function(){try{"
                + "var c=document.getElementById('authcode');"
                + "var needC=!!(c&&c.offsetParent!==null);"
                + "var m=document.getElementById('errormsg')||document.getElementById('msg');"
                + "var t=m?(m.innerText||m.textContent||''):'';"
                + "return (needC?'CAPTCHA|':'')+t.replace(/\\s+/g,' ').trim();"
                + "}catch(e){return 'PROBE_ERR';}})();";

        view.evaluateJavascript(probe, raw -> {
            String state = unquote(raw);
            boolean needCaptcha = state.startsWith("CAPTCHA|");
            String msg = needCaptcha ? state.substring(8) : state;

            if (needCaptcha) {
                // 只有这种时候才需要用户出面
                reveal();
                return;
            }
            if (msg.length() > 0 && msg.indexOf("请输入") < 0) {
                finishWithResult(RESULT_CANCELED, "", msg);
                return;
            }
            if (attempts >= 2) {
                finishWithResult(RESULT_CANCELED, "", "教学综合平台没有接受这次登录，请稍后重试");
                return;
            }
            attempts += 1;
            view.evaluateJavascript(submitJs(), null);
        });
    }

    /** 填账号密码并触发页面自己的校验/加密流程（等价于用户点「登录」） */
    private String submitJs() {
        return "(function(){try{"
                + "var u=document.getElementById('username');if(u){u.value='" + escape(prefillUser) + "';}"
                + "var p=document.getElementById('ppassword');if(p){p.value='" + escape(prefillPwd) + "';}"
                + "if(typeof checkForm==='function'){checkForm();return 'checkForm';}"
                + "var f=document.getElementById('fm1');"
                + "if(f){var b=f.querySelector('button,a.login-btn,input[type=submit]');"
                + "if(b){b.click();return 'click';}f.submit();return 'submit';}"
                + "return 'noform';"
                + "}catch(e){return 'ERR:'+e.message;}})();";
    }

    private void reveal() {
        if (revealed) return;
        revealed = true;
        runOnUiThread(() -> {
            root.setAlpha(1f);
            bar.setVisibility(View.VISIBLE);
            android.util.Log.i("FxwPortal", "captcha required, show window");
        });
    }

    private static String unquote(String raw) {
        if (raw == null) return "";
        String s = raw;
        if (s.length() >= 2 && s.startsWith("\"") && s.endsWith("\"")) {
            s = s.substring(1, s.length() - 1);
        }
        return s.replace("\\n", " ").replace("\\\"", "\"").replace("\\/", "/");
    }

    private static String escape(String raw) {
        return raw.replace("\\", "\\\\").replace("'", "\\'").replace("\n", "");
    }

    private void finishWithResult(int code, String pageUrl, String error) {
        if (finished) return;
        finished = true;
        Intent data = new Intent();
        data.putExtra("error", error == null ? "" : error);
        CookieManager cm = CookieManager.getInstance();
        cm.flush();
        // CookieManager.getCookie 只返回「路径能覆盖该 URL」的 Cookie，
        // 教务的 JSESSIONID 落在 /jwglxt 下，只查根路径会拿到空串。
        String jw = "";
        if (pageUrl != null && pageUrl.length() > 0) jw = nullToEmpty(cm.getCookie(pageUrl));
        String rootJw = nullToEmpty(cm.getCookie("http://jw.fzfu.edu.cn/"));
        if (rootJw.length() > 0) jw = jw.length() == 0 ? rootJw : jw + "; " + rootJw;
        data.putExtra("jw", jw);
        data.putExtra("portal", nullToEmpty(cm.getCookie("http://portal.fzfu.edu.cn/")));

        setResult(code, data);
        finish();
    }

    private static String nullToEmpty(String v) {
        return v == null ? "" : v;
    }

    private int dp(int v) {
        return Math.round(getResources().getDisplayMetrics().density * v);
    }

    @Override
    public void onBackPressed() {
        if (!silent && web != null && web.canGoBack() && revealed) {
            web.goBack();
            return;
        }
        finishWithResult(RESULT_CANCELED, "", "已取消登录");
    }

    @Override
    protected void onDestroy() {
        if (web != null) {
            ViewGroup parent = (ViewGroup) web.getParent();
            if (parent != null) parent.removeView(web);
            web.destroy();
            web = null;
        }
        super.onDestroy();
    }
}