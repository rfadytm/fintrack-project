/// <reference types="vitest/config" />
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import tailwindcss from "@tailwindcss/vite";

// Local dev: proxy /api ke Vercel dev server (vercel dev) di port 3000.
// Produksi: same-domain di Vercel → tidak ada CORS issue (lihat B / catatan arsitektur).
export default defineConfig({
  plugins: [react(), tailwindcss()],
  build: { outDir: "dist" },
  server: {
    port: 5173,
    proxy: {
      "/api": {
        target: "http://localhost:3000",
        changeOrigin: true,
      },
    },
  },
  test: {
    environment: "jsdom",
    globals: true,
    setupFiles: ["./src/test/setup.ts"],
    css: true,
    exclude: ["e2e/**", "node_modules/**"],
    // Pin the timezone so date-only ISO strings ("2026-07-08") parse the same
    // day in every CI/dev machine regardless of host timezone.
    env: { TZ: "UTC" },
  },
});
