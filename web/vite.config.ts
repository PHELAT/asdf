import path from "path";
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react-swc";
import tailwindcss from "@tailwindcss/vite";
import { catdoesWatch } from "@catdoes/watch-web/vite";

// https://vite.dev/config/
export default defineConfig({
  plugins: [catdoesWatch(), react(), tailwindcss()],
  server: {
    hmr: {
      overlay: false,
    },
    forwardConsole: {
      logLevels: ["warn", "error"],
    },
  },
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "./src"),
    },
    dedupe: [
      "react",
      "react-dom",
      "react/jsx-runtime",
      "react/jsx-dev-runtime",
      "@tanstack/react-query",
      "@tanstack/query-core",
    ],
  },
});
