import type { CapacitorConfig } from '@capacitor/cli';

const config: CapacitorConfig = {
  appId: 'com.fuxiaowai.timetable',
  appName: '福小外',
  webDir: 'dist',
  // 教务是 http，WebView 页面在 https://localhost 下，必须允许混合内容 + 原生 HTTP
  android: {
    allowMixedContent: true,
    webContentsDebuggingEnabled: false,
    useLegacyBridge: false
  },
  server: {
    androidScheme: 'https',
    cleartext: true
  },
  plugins: {
    CapacitorHttp: { enabled: true },
    CapacitorCookies: { enabled: true },
    // 启动图与鸿蒙 splash.png 同一张：白底 + 圆角企鹅 logo + 「福小外」蓝字。
    // launchAutoHide 关掉，等 React 首帧画好后再 hide()，避免白屏一闪。
    SplashScreen: {
      launchAutoHide: true,
      launchShowDuration: 700,
      launchFadeOutDuration: 180,
      backgroundColor: '#FFFFFF',
      androidScaleType: 'CENTER_CROP',
      showSpinner: false,
      splashFullScreen: true,
      splashImmersive: false,
      androidSplashResourceName: 'splash'
    }
  }
};

export default config;