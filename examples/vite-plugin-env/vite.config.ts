import { defineConfig } from "vite";
import wite from "vite-plugin-wite";

export default defineConfig({
  plugins: [
    wite({
      dts: true,
      // Per-environment overrides (Vite 6+ Environment API)
      // Environment names are user-defined, not limited to "client"/"ssr"
      environments: {
        client: {
          // Browser environment
        },
        server: {
          // Server-side environment (replaces legacy "ssr")
          dts: false,
        },
      },
    }),
  ],
  build: {
    target: "esnext",
  },
});
