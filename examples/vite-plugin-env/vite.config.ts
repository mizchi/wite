import { defineConfig } from "vite";
import wite from "vite-plugin-wite";

export default defineConfig({
  plugins: [
    wite({
      // Default shims for all environments
      dts: true,
      // Per-environment overrides
      environments: {
        client: {
          // Browser environment: no special shims needed for this example
        },
        ssr: {
          // SSR environment: could use Node.js-specific shims
          dts: false, // skip .d.ts in SSR
        },
      },
    }),
  ],
  build: {
    target: "esnext",
  },
});
