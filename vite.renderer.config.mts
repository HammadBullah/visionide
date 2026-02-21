// vite.renderer.config.mts
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
export default defineConfig({
  plugins: [
    react(),
  ],
  optimizeDeps: {
    include: [
      'monaco-editor/esm/vs/editor/editor.main',
      'monaco-editor/esm/vs/language/typescript/ts.worker',
      'monaco-editor/esm/vs/language/json/json.worker',
      // add more as needed
    ],
  },
  server: {
    port: 5173,
    strictPort: true,
  },
});