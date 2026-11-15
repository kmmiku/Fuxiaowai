package com.fuxiaowai.timetable;

import android.app.Activity;
import android.content.Intent;

import androidx.activity.result.ActivityResult;

import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.ActivityCallback;
import com.getcapacitor.annotation.CapacitorPlugin;

/**
 * 打开统一身份认证网页完成登录，把浏览器内核里的 Cookie 交回前端。
 * 门户 CAS 有动态防护，纯 HTTP 客户端会被判「登录页面闲置时间过长」，
 * 只有真正的浏览器内核能过；拿到的 Cookie 再交给原有 HTTP 通道抓课表。
 */
@CapacitorPlugin(name = "FxwPortal")
public class PortalLoginPlugin extends Plugin {

    @PluginMethod
    public void login(PluginCall call) {
        String url = call.getString("url", "");
        if (url.length() == 0) {
            call.reject("缺少登录地址");
            return;
        }
        Intent intent = new Intent(getContext(), PortalLoginActivity.class);
        intent.putExtra("url", url);
        intent.putExtra("user", call.getString("user", ""));
        intent.putExtra("pwd", call.getString("pwd", ""));
        intent.putExtra("silent", call.getBoolean("silent", true) ? "true" : "false");
        startActivityForResult(call, intent, "loginResult");
    }

    @ActivityCallback
    private void loginResult(PluginCall call, ActivityResult result) {
        if (call == null) return;
        Intent data = result.getData();
        if (result.getResultCode() != Activity.RESULT_OK || data == null) {
            String error = data == null ? "" : data.getStringExtra("error");
            call.reject(error == null || error.length() == 0 ? "已取消登录" : error);
            return;
        }
        JSObject ret = new JSObject();
        ret.put("jw", data.getStringExtra("jw") == null ? "" : data.getStringExtra("jw"));
        ret.put("portal", data.getStringExtra("portal") == null ? "" : data.getStringExtra("portal"));
        call.resolve(ret);
    }
}