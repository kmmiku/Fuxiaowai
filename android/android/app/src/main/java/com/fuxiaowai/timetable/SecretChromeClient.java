package com.fuxiaowai.timetable;

import android.net.Uri;
import android.webkit.JsPromptResult;
import android.webkit.WebView;
import com.getcapacitor.Bridge;
import com.getcapacitor.BridgeWebChromeClient;
import org.json.JSONObject;

/** Preserve synchronous Store signatures without exposing an origin-blind JavaScript interface. */
final class SecretChromeClient extends BridgeWebChromeClient {
    private final SecretVault vault;
    SecretChromeClient(Bridge bridge) { super(bridge); vault = new SecretVault(bridge.getContext()); }
    @Override public boolean onJsPrompt(WebView view, String url, String message, String value, JsPromptResult result) {
        if (!"fxw-secret-v1".equals(message)) return super.onJsPrompt(view, url, message, value, result);
        JSONObject reply = new JSONObject();
        try {
            Uri origin = Uri.parse(url);
            if (!"https".equals(origin.getScheme()) || !"localhost".equals(origin.getHost()) ||
                (origin.getPort() != -1 && origin.getPort() != 443)) throw new SecurityException("Untrusted origin");
            if (value == null || value.length() > 131072) throw new IllegalArgumentException("Request too large");
            JSONObject request = new JSONObject(value);
            String aad = request.getString("context");
            if (!aad.startsWith("fxw_credential:") && !aad.startsWith("fxw_jw_session:")) throw new SecurityException("Invalid context");
            String action = request.getString("action"), input = request.getString("value");
            String output;
            if ("seal".equals(action)) output = vault.seal(input, aad);
            else if ("open".equals(action)) output = vault.open(input, aad);
            else throw new IllegalArgumentException("Invalid action");
            reply.put("ok", true); reply.put("value", output);
        } catch (Exception error) {
            try { reply.put("ok", false); } catch (Exception ignored) { }
        }
        result.confirm(reply.toString()); return true;
    }
}
