import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// 相对 base：Capacitor 的 WebView 用 file:// 或本地 http 容器加载，绝对路径会 404
export default defineConfig({
  plugins: [react()],
  base: './',
  server: { host: '0.0.0.0', port: 5173, strictPort: true },
  build: {
    outDir: 'dist',
    assetsInlineLimit: 4096,
    chunkSizeWarningLimit: 1200
  }
});