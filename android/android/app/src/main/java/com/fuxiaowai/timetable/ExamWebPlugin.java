package com.fuxiaowai.timetable;

import android.content.Intent;

import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;

/** 应用内打开教务页面（成绩查询 / 考试安排），由原生 WebView 承担，避免 iframe 的第三方 Cookie 问题。 */
@CapacitorPlugin(name = "FxwWeb")
public class ExamWebPlugin extends Plugin {

    @PluginMethod
    public void open(PluginCall call) {
        String url = call.getString("url", "");
        String cookie = call.getString("cookie", "");
        String title = call.getString("title", "教务页面");
        if (url == null || url.length() == 0) {
            call.reject("缺少页面地址");
            return;
        }
        Intent intent = new Intent(getContext(), ExamWebActivity.class);
        intent.putExtra("url", url);
        intent.putExtra("cookie", cookie);
        intent.putExtra("title", title);
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        getContext().startActivity(intent);
        JSObject ret = new JSObject();
        ret.put("opened", true);
        call.resolve(ret);
    }
}