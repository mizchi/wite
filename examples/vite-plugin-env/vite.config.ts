import { defineConfig } from "vite";
import wite from "vite-plugin-wite";

export default defineConfig({
  plugins: [
    wite({
      dts: true,
      // Per-environment overrides (Vite 6+ Environment API)
      environments: {
        client: {
          // Browser environment
        },
        server: {
          // Server-side Node.js environment
          dts: false,
        },
        // Cloudflare Workers (workerd) environment
        // Activated when using @cloudflare/vite-plugin or --ssr with workerd
        workerd: {
          dts: false,
        },
      },
    }),
  ],
  build: {
    target: "esnext",
  },
});
