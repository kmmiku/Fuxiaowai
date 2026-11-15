package com.fuxiaowai.timetable;

import android.content.Context;
import android.content.SharedPreferences;
import android.os.Build;
import android.security.KeyPairGeneratorSpec;
import android.security.keystore.KeyGenParameterSpec;
import android.security.keystore.KeyProperties;
import android.util.Base64;
import java.math.BigInteger;
import java.nio.charset.StandardCharsets;
import java.security.KeyPairGenerator;
import java.security.KeyStore;
import java.util.Calendar;
import javax.crypto.Cipher;
import javax.crypto.KeyGenerator;
import javax.crypto.SecretKey;
import javax.crypto.spec.GCMParameterSpec;
import javax.crypto.spec.SecretKeySpec;
import javax.security.auth.x500.X500Principal;

/** Keys never enter JavaScript. API 22 uses a Keystore RSA key to wrap the AES key. */
final class SecretVault {
    private static final String ALIAS = "fxw.secrets.v1";
    private final Context context;
    SecretVault(Context context) { this.context = context.getApplicationContext(); }
    private SecretKey key(boolean create) throws Exception {
        KeyStore store = KeyStore.getInstance("AndroidKeyStore"); store.load(null);
        if (Build.VERSION.SDK_INT >= 23) {
            if (!store.containsAlias(ALIAS)) {
                if (!create) throw new IllegalStateException("Missing key");
                KeyGenerator gen = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore");
                gen.init(new KeyGenParameterSpec.Builder(ALIAS, KeyProperties.PURPOSE_ENCRYPT | KeyProperties.PURPOSE_DECRYPT)
                    .setBlockModes(KeyProperties.BLOCK_MODE_GCM).setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                    .setRandomizedEncryptionRequired(true).build()); gen.generateKey();
            }
            return (SecretKey) store.getKey(ALIAS, null);
        }
        SharedPreferences prefs = context.getSharedPreferences("fxw_secret_wrapped", Context.MODE_PRIVATE);
        String wrapped = prefs.getString("aes", null);
        if (!store.containsAlias(ALIAS)) {
            if (!create || wrapped != null) throw new IllegalStateException("Missing wrapping key");
            Calendar start = Calendar.getInstance(), end = Calendar.getInstance(); end.add(Calendar.YEAR, 30);
            KeyPairGenerator gen = KeyPairGenerator.getInstance("RSA", "AndroidKeyStore");
            gen.initialize(new KeyPairGeneratorSpec.Builder(context).setAlias(ALIAS)
                .setSubject(new X500Principal("CN=FXW local secrets")) .setSerialNumber(BigInteger.ONE)
                .setStartDate(start.getTime()).setEndDate(end.getTime()).build()); gen.generateKeyPair();
        }
        Cipher rsa = Cipher.getInstance("RSA/ECB/PKCS1Padding");
        if (wrapped == null) {
            if (!create) throw new IllegalStateException("Missing wrapped key");
            KeyGenerator gen = KeyGenerator.getInstance("AES"); gen.init(256);
            SecretKey aes = gen.generateKey();
            rsa.init(Cipher.ENCRYPT_MODE, store.getCertificate(ALIAS).getPublicKey());
            if (!prefs.edit().putString("aes", Base64.encodeToString(rsa.doFinal(aes.getEncoded()), Base64.NO_WRAP)).commit())
                throw new IllegalStateException("Cannot persist wrapped key");
            return aes;
        }
        rsa.init(Cipher.DECRYPT_MODE, store.getKey(ALIAS, null));
        return new SecretKeySpec(rsa.doFinal(Base64.decode(wrapped, Base64.NO_WRAP)), "AES");
    }
    synchronized String seal(String plain, String aad) throws Exception {
        Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
        cipher.init(Cipher.ENCRYPT_MODE, key(true)); cipher.updateAAD(aad.getBytes(StandardCharsets.UTF_8));
        return "v1:" + Base64.encodeToString(cipher.getIV(), Base64.NO_WRAP) + ":" +
            Base64.encodeToString(cipher.doFinal(plain.getBytes(StandardCharsets.UTF_8)), Base64.NO_WRAP);
    }
    synchronized String open(String sealed, String aad) throws Exception {
        String[] parts = sealed.split(":", -1);
        if (parts.length != 3 || !parts[0].equals("v1")) throw new IllegalArgumentException("Invalid secret");
        byte[] iv = Base64.decode(parts[1], Base64.NO_WRAP);
        if (iv.length != 12) throw new IllegalArgumentException("Invalid nonce");
        Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
        cipher.init(Cipher.DECRYPT_MODE, key(false), new GCMParameterSpec(128, iv));
        cipher.updateAAD(aad.getBytes(StandardCharsets.UTF_8));
        return new String(cipher.doFinal(Base64.decode(parts[2], Base64.NO_WRAP)), StandardCharsets.UTF_8);
    }
}
