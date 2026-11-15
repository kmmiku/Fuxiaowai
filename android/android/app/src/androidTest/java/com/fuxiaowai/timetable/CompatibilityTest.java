package com.fuxiaowai.timetable;
import static org.junit.Assert.*;
import android.content.Context;
import android.database.Cursor;
import android.provider.CalendarContract;
import android.webkit.WebView;
import androidx.test.core.app.ActivityScenario;
import androidx.test.platform.app.InstrumentationRegistry;
import androidx.test.ext.junit.runners.AndroidJUnit4;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicReference;
import org.json.JSONObject;
import org.junit.Test;
import org.junit.runner.RunWith;
@RunWith(AndroidJUnit4.class)
public class CompatibilityTest {
 @Test public void keystoreRoundTripUsesRandomNonceAndRejectsOtherAccount() throws Exception {
  Context context=InstrumentationRegistry.getInstrumentation().getTargetContext();
  SecretVault vault=new SecretVault(context);
  String a=vault.seal("test-password", "fxw_credential:A");
  String b=vault.seal("test-password", "fxw_credential:A");
  assertNotEquals(a,b); assertEquals("test-password",vault.open(a,"fxw_credential:A"));
  try {vault.open(a,"fxw_credential:B");fail("Wrong account accepted");}catch(Exception expected){}
  try {vault.open(a.substring(0,a.length()-3)+"AAA","fxw_credential:A");fail("Tampering accepted");}catch(Exception expected){}
  assertEquals("test-password",new SecretVault(context).open(a,"fxw_credential:A"));
 }
 private String js(ActivityScenario<MainActivity> scenario,String script) throws Exception {
  CountDownLatch done=new CountDownLatch(1);AtomicReference<String> value=new AtomicReference<>();
  scenario.onActivity(a->a.getBridge().getWebView().evaluateJavascript(script,r->{value.set(r);done.countDown();}));
  assertTrue(done.await(10,TimeUnit.SECONDS));return value.get();
 }
 private void ready(ActivityScenario<MainActivity> scenario) throws Exception {
  for(int i=0;i<80;i++){if("\"complete\"".equals(js(scenario,"document.readyState")))return;Thread.sleep(100);}fail("WebView not ready");
 }
 @Test public void trustedAppPromptEncryptsAndUntrustedOriginCannotUseVault() throws Exception {
  try(ActivityScenario<MainActivity> scenario=ActivityScenario.launch(MainActivity.class)){
   ready(scenario);
   String script="(function(){var a=JSON.parse(prompt('fxw-secret-v1',JSON.stringify({action:'seal',value:'test',context:'fxw_credential:A'})));if(!a.ok)return false;var b=JSON.parse(prompt('fxw-secret-v1',JSON.stringify({action:'open',value:a.value,context:'fxw_credential:A'})));return b.ok&&b.value==='test';})()";
   assertEquals("true",js(scenario,script));
   scenario.onActivity(a->a.getBridge().getWebView().loadDataWithBaseURL("https://evil.invalid/","<html><body>isolated origin test</body></html>","text/html","UTF-8",null));
   ready(scenario);
   assertEquals("false",js(scenario,script));
  }
 }
 @Test public void repeatedCalendarExportUpdatesOneOwnedEvent() throws Exception {
  try(ActivityScenario<MainActivity> scenario=ActivityScenario.launch(MainActivity.class)){
   ready(scenario);
   long start=System.currentTimeMillis()+86400000;
   String options="{owner:'qa-account',table:'t1',events:[{key:'qa-key',title:'QA course',start:"+start+",end:"+(start+3600000)+",reminder:10}]}";
   for(int n=0;n<2;n++){
    js(scenario,"window.qaResult=null;window.Capacitor.nativePromise('FxwCalendar','export',"+options+").then(r=>window.qaResult=r).catch(e=>window.qaResult={error:e.message});true");
    String raw="null";for(int i=0;i<80;i++){raw=js(scenario,"window.qaResult");if(!raw.equals("null"))break;Thread.sleep(100);}
    JSONObject result=new JSONObject(raw);assertFalse(result.toString(),result.has("error"));assertEquals(0,result.getInt("failed"));
    if(n==1)assertEquals(1,result.getInt("updated"));
   }
   Context context=InstrumentationRegistry.getInstrumentation().getTargetContext();
   try(Cursor c=context.getContentResolver().query(CalendarContract.Events.CONTENT_URI,new String[]{CalendarContract.Events._ID},CalendarContract.Events.CUSTOM_APP_PACKAGE+"=? AND "+CalendarContract.Events.TITLE+"=? AND "+CalendarContract.Events.DELETED+"=0",new String[]{"com.fuxiaowai.timetable","QA course"},null)){assertNotNull(c);assertEquals(1,c.getCount());}
  }
 }
}
