import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

// Local dev: proxy /api ke Vercel dev server (vercel dev) di port 3000.
// Produksi: same-domain di Vercel → tidak ada CORS issue (lihat B / catatan arsitektur).
export default defineConfig({
  plugins: [react()],
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
});
