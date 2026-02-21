// vite.main.config.mts
import { defineConfig } from 'vite';

export default defineConfig({
  build: {
    lib: {
      entry: 'src/main.mts',
      formats: ['es'],           // ← use 'es' instead of 'cjs'
      fileName: () => 'main.mjs', // or 'main.js' if you prefer
    },
    outDir: '.vite/build',
    sourcemap: true,
    minify: false,
    rollupOptions: {
      external: ['electron'],
    },
    target: 'node20',
  },
});