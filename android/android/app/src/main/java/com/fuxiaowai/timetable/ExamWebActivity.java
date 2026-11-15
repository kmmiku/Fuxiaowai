package com.fuxiaowai.timetable;

import android.annotation.SuppressLint;
import android.app.Activity;
import android.graphics.Color;
import android.os.Bundle;
import android.view.Gravity;
import android.view.ViewGroup;
import android.webkit.CookieManager;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.TextView;

/**
 * 应用内打开教务页面（成绩查询 / 考试安排）。
 *
 * 教务页面必须在一等公民的 WebView 里打开：用 iframe 嵌到 https://localhost 里属于第三方上下文，
 * WebView 默认不发已注入的 Cookie，页面会掉回统一身份认证登录页。
 */
public class ExamWebActivity extends Activity {

    private WebView web;

    @SuppressLint("SetJavaScriptEnabled")
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        String url = getIntent().getStringExtra("url");
        String cookie = getIntent().getStringExtra("cookie");
        String title = getIntent().getStringExtra("title");
        if (title == null || title.length() == 0) title = "教务页面";
        if (url == null || url.length() == 0) {
            finish();
            return;
        }

        CookieManager cm = CookieManager.getInstance();
        cm.setAcceptCookie(true);
        if (cookie != null && cookie.length() > 0) {
            String[] pairs = cookie.split(";");
            for (String p : pairs) {
                String t = p.trim();
                int eq = t.indexOf('=');
                if (eq <= 0) continue;
                String kv = t.substring(0, eq) + "=" + t.substring(eq + 1);
                cm.setCookie("http://jw.fzfu.edu.cn", kv);
                cm.setCookie("http://jw.fzfu.edu.cn/jwglxt/", kv);
            }
            cm.flush();
        }

        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setBackgroundColor(Color.parseColor("#F6F7FB"));

        LinearLayout bar = new LinearLayout(this);
        bar.setOrientation(LinearLayout.HORIZONTAL);
        bar.setGravity(Gravity.CENTER_VERTICAL);
        bar.setPadding(dp(12), dp(10), dp(12), dp(10));
        bar.setBackgroundColor(Color.WHITE);

        Button back = new Button(this);
        back.setText("‹");
        back.setTextSize(20);
        back.setBackgroundColor(Color.TRANSPARENT);
        back.setOnClickListener(v -> finish());

        TextView tv = new TextView(this);
        tv.setText(title);
        tv.setTextSize(17);
        tv.setTextColor(Color.parseColor("#1B1D22"));
        LinearLayout.LayoutParams tvLp = new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f);
        tvLp.leftMargin = dp(4);

        Button reload = new Button(this);
        reload.setText("↻");
        reload.setTextSize(18);
        reload.setBackgroundColor(Color.TRANSPARENT);
        reload.setOnClickListener(v -> web.reload());

        bar.addView(back, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT));
        bar.addView(tv, tvLp);
        bar.addView(reload, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT));

        web = new WebView(this);
        WebSettings s = web.getSettings();
        s.setJavaScriptEnabled(true);
        s.setDomStorageEnabled(true);
        s.setMixedContentMode(WebSettings.MIXED_CONTENT_ALWAYS_ALLOW);
        s.setLoadWithOverviewMode(false);
        s.setUseWideViewPort(true);
        s.setBuiltInZoomControls(true);
        s.setDisplayZoomControls(false);
        web.setInitialScale(70);
        cm.setAcceptThirdPartyCookies(web, true);
        web.setWebViewClient(new WebViewClient());

        root.addView(bar, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));
        root.addView(web, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f));
        setContentView(root);
        web.loadUrl(url);
    }

    private int dp(int v) {
        return Math.round(v * getResources().getDisplayMetrics().density);
    }

    @Override
    public void onBackPressed() {
        if (web != null && web.canGoBack()) {
            web.goBack();
            return;
        }
        super.onBackPressed();
    }

    @Override
    protected void onDestroy() {
        if (web != null) {
            web.stopLoading();
            web.destroy();
            web = null;
        }
        super.onDestroy();
    }
}