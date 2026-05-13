import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  // When building for Firebase Hosting, output goes to public/b2b/
  build: {
    outDir: '../public/b2b',
    emptyOutDir: true,
  },
  // Dev server proxies /api → local B2B API (port 8090 by default)
  server: {
    proxy: {
      '/api': {
        target: 'http://localhost:8090',
        changeOrigin: true,
      },
    },
  },
  define: {
    // Default to mock mode in dev; set VITE_MOCK=false to hit real API
    'import.meta.env.VITE_MOCK': JSON.stringify(process.env.VITE_MOCK ?? 'true'),
  },
});
