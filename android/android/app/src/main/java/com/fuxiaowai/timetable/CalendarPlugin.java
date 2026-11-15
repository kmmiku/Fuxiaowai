package com.fuxiaowai.timetable;

import android.Manifest;
import android.content.ContentResolver;
import android.content.ContentUris;
import android.content.ContentValues;
import android.content.ContentProviderOperation;
import java.util.ArrayList;
import java.util.concurrent.Executors;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.atomic.AtomicLong;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import android.database.Cursor;
import android.net.Uri;
import android.provider.CalendarContract;
import android.util.Log;

import com.getcapacitor.JSArray;
import com.getcapacitor.JSObject;
import com.getcapacitor.PermissionState;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;
import com.getcapacitor.annotation.Permission;
import com.getcapacitor.annotation.PermissionCallback;

import org.json.JSONObject;

import java.util.TimeZone;

/**
 * 把课表写成系统日历事件。
 *
 * 为什么自己写插件：Capacitor 没有官方日历插件，而「导出到日程」要一次写上百条，
 * 用 Intent(ACTION_INSERT) 一次只能开一个新建界面，只能直接走 CalendarProvider。
 *
 * 权限：READ_CALENDAR / WRITE_CALENDAR，运行时申请。
 */
@CapacitorPlugin(
        name = "FxwCalendar",
        permissions = {
                @Permission(
                        alias = "calendar",
                        strings = {Manifest.permission.READ_CALENDAR, Manifest.permission.WRITE_CALENDAR}
                )
        }
)
public class CalendarPlugin extends Plugin {

    private static final String TAG = "FxwCalendar";
    private static final String OWNER = "com.fuxiaowai.timetable";
    private static final ExecutorService WRITES = Executors.newSingleThreadExecutor();
    private static final AtomicLong GENERATION = new AtomicLong();
    private static String digest(String value) throws Exception {
        byte[] bytes = MessageDigest.getInstance("SHA-256").digest(value.getBytes(StandardCharsets.UTF_8));
        StringBuilder out = new StringBuilder(); for (byte b: bytes) out.append(String.format("%02x", b & 255)); return out.toString();
    }

    /** 找一个可写的日历；找不到就用本地账户新建一个 */
    private long ensureCalendarId() {
        ContentResolver cr = getContext().getContentResolver();
        String[] projection = new String[]{
                CalendarContract.Calendars._ID,
                CalendarContract.Calendars.CALENDAR_DISPLAY_NAME,
                CalendarContract.Calendars.CALENDAR_ACCESS_LEVEL
        };
        String selection = CalendarContract.Calendars.ACCOUNT_NAME + "=? AND " +
                CalendarContract.Calendars.ACCOUNT_TYPE + "=? AND " + CalendarContract.Calendars.NAME + "=?";

        Cursor c = null;
        try {
            c = cr.query(CalendarContract.Calendars.CONTENT_URI, projection, selection, new String[]{OWNER, CalendarContract.ACCOUNT_TYPE_LOCAL, "fxw-owned-v1"},
                    CalendarContract.Calendars.IS_PRIMARY + " DESC");
            if (c != null && c.moveToFirst()) {
                return c.getLong(0);
            }
        } catch (Exception e) {
            Log.w(TAG, "query calendars failed");
        } finally {
            if (c != null) c.close();
        }

        // 没有可写日历 → 建一个本地日历（不需要账号）
        Uri uri = CalendarContract.Calendars.CONTENT_URI.buildUpon()
                .appendQueryParameter(CalendarContract.CALLER_IS_SYNCADAPTER, "true")
                .appendQueryParameter(CalendarContract.Calendars.ACCOUNT_NAME, OWNER)
                .appendQueryParameter(CalendarContract.Calendars.ACCOUNT_TYPE, CalendarContract.ACCOUNT_TYPE_LOCAL)
                .build();
        ContentValues cv = new ContentValues();
        cv.put(CalendarContract.Calendars.ACCOUNT_NAME, OWNER);
        cv.put(CalendarContract.Calendars.ACCOUNT_TYPE, CalendarContract.ACCOUNT_TYPE_LOCAL);
        cv.put(CalendarContract.Calendars.NAME, "fxw-owned-v1");
        cv.put(CalendarContract.Calendars.CALENDAR_DISPLAY_NAME, "福小外课表");
        cv.put(CalendarContract.Calendars.CALENDAR_COLOR, 0xFF3D5AFE);
        cv.put(CalendarContract.Calendars.CALENDAR_ACCESS_LEVEL, CalendarContract.Calendars.CAL_ACCESS_OWNER);
        cv.put(CalendarContract.Calendars.OWNER_ACCOUNT, "福小外");
        cv.put(CalendarContract.Calendars.VISIBLE, 1);
        cv.put(CalendarContract.Calendars.SYNC_EVENTS, 1);
        try {
            Uri created = cr.insert(uri, cv);
            if (created != null) return ContentUris.parseId(created);
        } catch (Exception e) {
            Log.w(TAG, "create local calendar failed");
        }
        return -1;
    }

    @PluginMethod
    public void export(PluginCall call) {
        call.getData().put("_generation", GENERATION.get());
        if (getPermissionState("calendar") != PermissionState.GRANTED) {
            requestPermissionForAlias("calendar", call, "afterPermission");
            return;
        }
        doExport(call);
    }

    @PermissionCallback
    private void afterPermission(PluginCall call) {
        if (getPermissionState("calendar") != PermissionState.GRANTED) {
            call.reject("没有日历权限，无法写入日程");
            return;
        }
        doExport(call);
    }

    private void doExport(PluginCall call) {
        JSArray events = call.getArray("events");
        if (events == null || events.length()>48000) { call.reject("日历参数不正确"); return; }
        long generation=call.getData().optLong("_generation", -1);
        WRITES.execute(() -> {
            if (generation!=GENERATION.get()) {call.reject("账号状态已改变");return;}
            long calendarId=ensureCalendarId();
            if (calendarId<0) {call.reject("这台设备上没有可写入的日历");return;}
            if(!getContext().getSharedPreferences("fxw_calendar_registry",0).edit().putBoolean("used",true).commit()) {call.reject("日历登记失败");return;}
            ContentResolver cr=getContext().getContentResolver();
            int inserted=0,failed=0,updated=0;
            try {
                String prefix="fxw://owned/"+digest(call.getString("owner",""))+"/"+digest(call.getString("table","t1"))+"/";
                for(int i=0;i<events.length();i++) {
                    if(generation!=GENERATION.get()){call.reject("账号状态已改变");return;}
                    try {
                        JSONObject e=events.getJSONObject(i);
                        String marker=prefix+digest(e.optString("key",e.optString("title")+":"+e.optLong("start")));
                        long start=e.getLong("start"),end=e.getLong("end");
                        if(start<=0 || end<=start)throw new IllegalArgumentException("Invalid event time");
                        long existing=-1;
                        try(Cursor c=cr.query(CalendarContract.Events.CONTENT_URI,new String[]{CalendarContract.Events._ID},
                            CalendarContract.Events.CALENDAR_ID+"=? AND "+CalendarContract.Events.CUSTOM_APP_PACKAGE+"=? AND "+
                            CalendarContract.Events.CUSTOM_APP_URI+"=? AND "+CalendarContract.Events.DELETED+"=0",
                            new String[]{String.valueOf(calendarId),OWNER,marker},null)) { if(c!=null&&c.moveToFirst())existing=c.getLong(0); }
                        ContentValues cv=new ContentValues();
                        int minutes=e.optInt("reminder",10);
                        cv.put(CalendarContract.Events.CALENDAR_ID,calendarId);
                        cv.put(CalendarContract.Events.TITLE,e.optString("title","课程"));
                        cv.put(CalendarContract.Events.DESCRIPTION,e.optString("description",""));
                        cv.put(CalendarContract.Events.EVENT_LOCATION,e.optString("location",""));
                        cv.put(CalendarContract.Events.DTSTART,start); cv.put(CalendarContract.Events.DTEND,end);
                        cv.put(CalendarContract.Events.EVENT_TIMEZONE,TimeZone.getDefault().getID());
                        cv.put(CalendarContract.Events.HAS_ALARM,minutes>0?1:0);
                        cv.put(CalendarContract.Events.CUSTOM_APP_PACKAGE,OWNER); cv.put(CalendarContract.Events.CUSTOM_APP_URI,marker);
                        ArrayList<ContentProviderOperation> ops=new ArrayList<>();
                        if(existing<0) ops.add(ContentProviderOperation.newInsert(CalendarContract.Events.CONTENT_URI).withValues(cv).build());
                        else {
                            ops.add(ContentProviderOperation.newUpdate(ContentUris.withAppendedId(CalendarContract.Events.CONTENT_URI,existing)).withValues(cv).build());
                            ops.add(ContentProviderOperation.newDelete(CalendarContract.Reminders.CONTENT_URI)
                                .withSelection(CalendarContract.Reminders.EVENT_ID+"=?",new String[]{String.valueOf(existing)}).build());
                        }
                        if(minutes>0){
                            ContentProviderOperation.Builder reminder=ContentProviderOperation.newInsert(CalendarContract.Reminders.CONTENT_URI)
                                .withValue(CalendarContract.Reminders.MINUTES,minutes).withValue(CalendarContract.Reminders.METHOD,CalendarContract.Reminders.METHOD_ALERT);
                            if(existing<0)reminder.withValueBackReference(CalendarContract.Reminders.EVENT_ID,0);
                            else reminder.withValue(CalendarContract.Reminders.EVENT_ID,existing);
                            ops.add(reminder.build());
                        }
                        // Marker, event and reminder are one provider transaction: retry can find every successful event.
                        cr.applyBatch(CalendarContract.AUTHORITY,ops);
                        if(existing<0)inserted++;else updated++;
                    } catch(Exception error) {failed++;Log.w(TAG,"Calendar write failed");}
                }
            } catch(Exception error){call.reject("日历写入失败，请重试");return;}
            JSObject ret=new JSObject();ret.put("inserted",inserted+updated);ret.put("updated",updated);ret.put("failed",failed);ret.put("total",events.length());call.resolve(ret);
        });
    }

    @PluginMethod public void clearOwned(PluginCall call) {
        GENERATION.incrementAndGet();
        if(!getContext().getSharedPreferences("fxw_calendar_registry",0).getBoolean("used",false)){call.resolve();return;}
        WRITES.execute(() -> {
            try {
                ContentResolver cr=getContext().getContentResolver();
                String owner=call.getString("owner","");
                String prefix="fxw://owned/"+(owner.isEmpty()?"":digest(owner)+"/");
                ArrayList<ContentProviderOperation> ops=new ArrayList<>();
                try(Cursor c=cr.query(CalendarContract.Events.CONTENT_URI,new String[]{CalendarContract.Events._ID,CalendarContract.Events.CUSTOM_APP_URI},
                    CalendarContract.Events.CUSTOM_APP_PACKAGE+"=?",new String[]{OWNER},null)) {
                    if(c!=null)while(c.moveToNext())if(c.getString(1)!=null&&c.getString(1).startsWith(prefix))
                        ops.add(ContentProviderOperation.newDelete(ContentUris.withAppendedId(CalendarContract.Events.CONTENT_URI,c.getLong(0))).build());
                }
                // Bounded batches; retry queries remaining markers after partial cleanup.
                for(int i=0;i<ops.size();i+=100)cr.applyBatch(CalendarContract.AUTHORITY,new ArrayList<>(ops.subList(i,Math.min(i+100,ops.size()))));
                call.resolve();
            }catch(Exception error){call.reject("系统课表日程尚未清除，请授予日历权限后重试");}
        });
    }
}
