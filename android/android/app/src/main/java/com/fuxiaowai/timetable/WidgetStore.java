package com.fuxiaowai.timetable;

import android.content.Context;
import android.content.SharedPreferences;

/** 小组件快照存储：前端推上来的 JSON 放 SharedPreferences，Provider 直接读 */
final class WidgetStore {

    private static final String PREFS = "fxw_widget";
    private static final String KEY = "snapshot";

    private WidgetStore() {}

    static void save(Context context, String json) {
        prefs(context).edit().putString(KEY, json).apply();
    }

    static String load(Context context) {
        return prefs(context).getString(KEY, "");
    }

    private static SharedPreferences prefs(Context context) {
        return context.getApplicationContext().getSharedPreferences(PREFS, Context.MODE_PRIVATE);
    }
}