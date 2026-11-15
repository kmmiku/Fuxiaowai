package com.fuxiaowai.timetable;

import android.os.Bundle;

import com.getcapacitor.BridgeActivity;

public class MainActivity extends BridgeActivity {
    @Override
    protected void load() {
        super.load();
        bridge.getWebView().setWebChromeClient(new SecretChromeClient(bridge));
    }
    @Override
    public void onCreate(Bundle savedInstanceState) {
        registerPlugin(UpdateLinkPlugin.class);
        registerPlugin(CalendarPlugin.class);
        registerPlugin(FxwWidgetPlugin.class);
        registerPlugin(PortalLoginPlugin.class);
        registerPlugin(ExamWebPlugin.class);
        super.onCreate(savedInstanceState);
    }
}
