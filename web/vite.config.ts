import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import tailwindcss from "@tailwindcss/vite";
import path from "path";
import { readFileSync } from "node:fs";

// index.html placeholders come from the same generated content as the page
// (scripts/sync-content.mjs runs before dev and build).
function listingHtml() {
  return {
    name: "listing-html",
    transformIndexHtml(html: string) {
      const c = JSON.parse(readFileSync(path.resolve(__dirname, "src/generated/content.json"), "utf8"));
      const esc = (s: string) => String(s).replace(/&/g, "&amp;").replace(/"/g, "&quot;").replace(/</g, "&lt;");
      return html
        .replace(/%NAME%/g, esc(c.name))
        .replace(/%TAGLINE%/g, esc(c.tagline))
        .replace(/%PROMO%/g, esc(c.promotionalText));
    },
  };
}

export default defineConfig({
  plugins: [react(), tailwindcss(), listingHtml()],
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "./src"),
    },
  },
  server: {
    proxy: {
      // gRPC-Web service calls
      "/workout.v1.": {
        target: "http://127.0.0.1:50051",
        changeOrigin: true,
      },
      // Health check + assetlinks
      "/api": {
        target: "http://127.0.0.1:50051",
        changeOrigin: true,
      },
      "/.well-known": {
        target: "http://127.0.0.1:50051",
        changeOrigin: true,
      },
    },
  },
});
