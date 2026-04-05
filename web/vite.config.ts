import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import tailwindcss from "@tailwindcss/vite";
import path from "path";

export default defineConfig({
  plugins: [react(), tailwindcss()],
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
