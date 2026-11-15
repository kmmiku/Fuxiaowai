package com.fuxiaowai.timetable;

import com.getcapacitor.JSArray;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;

import org.json.JSONArray;
import org.json.JSONObject;

/** 接收前端推来的今日课程快照，写盘并刷新桌面小组件 */
@CapacitorPlugin(name = "FxwWidget")
public class FxwWidgetPlugin extends Plugin {

    @PluginMethod
    public void sync(PluginCall call) {
        JSONObject snapshot = new JSONObject();
        try {
            snapshot.put("headline", call.getString("headline", "今天没课"));
            snapshot.put("dayLabel", call.getString("dayLabel", ""));
            snapshot.put("dateLabel", call.getString("dateLabel", ""));
            snapshot.put("empty", call.getString("empty", "今天没有课，好好休息"));
            snapshot.put("updatedAt", call.getString("updatedAt", ""));

            JSArray lines = call.getArray("lines", new JSArray());
            JSONArray safe = new JSONArray();
            for (int i = 0; i < lines.length(); i++) {
                String line = lines.getString(i);
                if (line != null && line.length() > 0) safe.put(line);
            }
            snapshot.put("lines", safe);
        } catch (Exception e) {
            call.reject("小组件数据格式不对：" + e.getMessage());
            return;
        }

        WidgetStore.save(getContext(), snapshot.toString());
        DayCardWidgetProvider.refreshAll(getContext());
        call.resolve();
    }
}