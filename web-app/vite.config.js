import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// Build langsung ke web-build/ supaya Vercel tetap melayani satu folder.
// Saat `vite dev`, /api diteruskan ke serverless lokal atau produksi.
export default defineConfig({
  plugins: [react()],
  build: {
    outDir: '../web-build',
    emptyOutDir: true,
  },
  server: {
    proxy: {
      // Default ke API lokal (scripts/dev-api.js). Set OV_API untuk menembak server lain.
      '/api': process.env.OV_API || 'http://127.0.0.1:5198',
    },
  },
});
