package com.fuxiaowai.timetable;

import android.app.AlarmManager;
import android.app.PendingIntent;
import android.appwidget.AppWidgetManager;
import android.appwidget.AppWidgetProvider;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.widget.RemoteViews;

import org.json.JSONArray;
import org.json.JSONObject;

import java.util.Calendar;

/** 2×4 今日课程卡片：读 WidgetStore 里的快照渲染，点一下打开 App */
public class DayCardWidgetProvider extends AppWidgetProvider {

    static final String ACTION_TICK = "com.fuxiaowai.timetable.WIDGET_TICK";

    @Override
    public void onReceive(Context context, Intent intent) {
        super.onReceive(context, intent);
        if (ACTION_TICK.equals(intent.getAction())) {
            refreshAll(context);
            scheduleDaily(context);
        }
    }

    @Override
    public void onUpdate(Context context, AppWidgetManager manager, int[] appWidgetIds) {
        for (int id : appWidgetIds) {
            render(context, manager, id);
        }
        scheduleDaily(context);
    }

    /** 前端推来新快照后立刻重画所有实例 */
    static void refreshAll(Context context) {
        AppWidgetManager manager = AppWidgetManager.getInstance(context);
        ComponentName name = new ComponentName(context, DayCardWidgetProvider.class);
        int[] ids = manager.getAppWidgetIds(name);
        for (int id : ids) {
            render(context, manager, id);
        }
    }

    /** 每天 06:10 再刷一次，免得整夜没打开 App 时卡片还停在昨天 */
    static void scheduleDaily(Context context) {
        AlarmManager am = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
        if (am == null) return;
        Calendar at = Calendar.getInstance();
        at.set(Calendar.HOUR_OF_DAY, 6);
        at.set(Calendar.MINUTE, 10);
        at.set(Calendar.SECOND, 0);
        at.set(Calendar.MILLISECOND, 0);
        if (at.getTimeInMillis() <= System.currentTimeMillis()) {
            at.add(Calendar.DAY_OF_YEAR, 1);
        }
        Intent tick = new Intent(context, DayCardWidgetProvider.class).setAction(ACTION_TICK);
        PendingIntent pending = PendingIntent.getBroadcast(
            context,
            7,
            tick,
            PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
        );
        am.set(AlarmManager.RTC, at.getTimeInMillis(), pending);
    }

    private static void render(Context context, AppWidgetManager manager, int appWidgetId) {
        RemoteViews views = new RemoteViews(context.getPackageName(), R.layout.widget_day);

        String headline = "今天没课";
        String sub = "";
        String empty = "今天没有课，好好休息";
        String updatedAt = "";
        JSONArray lines = new JSONArray();

        try {
            String raw = WidgetStore.load(context);
            if (raw != null && raw.length() > 0) {
                JSONObject obj = new JSONObject(raw);
                headline = obj.optString("headline", headline);
                String day = obj.optString("dayLabel", "");
                String date = obj.optString("dateLabel", "");
                sub = day.length() > 0 && date.length() > 0 ? day + " · " + date : day + date;
                empty = obj.optString("empty", empty);
                updatedAt = obj.optString("updatedAt", "");
                lines = obj.optJSONArray("lines");
            }
        } catch (Exception ignored) {
            // 快照损坏就按「今天没课」渲染，别让桌面出现空白
        }

        views.setTextViewText(R.id.widget_headline, headline);
        views.setTextViewText(R.id.widget_sub, sub);
        views.setTextViewText(R.id.widget_updated, updatedAt.length() > 0 ? updatedAt + " 更新" : "");

        views.removeAllViews(R.id.widget_lines);
        int count = lines == null ? 0 : lines.length();
        if (count == 0) {
            RemoteViews row = new RemoteViews(context.getPackageName(), R.layout.widget_line);
            row.setTextViewText(R.id.widget_line_text, empty);
            views.addView(R.id.widget_lines, row);
        } else {
            for (int i = 0; i < count && i < 4; i++) {
                RemoteViews row = new RemoteViews(context.getPackageName(), R.layout.widget_line);
                row.setTextViewText(R.id.widget_line_text, lines.optString(i, ""));
                views.addView(R.id.widget_lines, row);
            }
        }

        Intent launch = new Intent(context, MainActivity.class);
        launch.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);
        PendingIntent pending = PendingIntent.getActivity(
            context,
            0,
            launch,
            PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
        );
        views.setOnClickPendingIntent(R.id.widget_root, pending);

        manager.updateAppWidget(appWidgetId, views);
    }
}