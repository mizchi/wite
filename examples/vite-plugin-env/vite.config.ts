import { defineConfig } from "vite";
import wite from "vite-plugin-wite";

export default defineConfig({
  plugins: [
    wite({
      dts: true,
      environments: {
        client: {
          // Browser main thread: fetch-based wasm loading
          runtime: "browser",
        },
        ssr: {
          // Cloudflare Workers: direct wasm import
          runtime: "workerd",
          dts: false,
        },
      },
      // Use webworker runtime for specific imports:
      // In vite.config, set runtime per-environment.
      // For webworker, use a separate vite config or
      // import from a ?worker suffixed path.
      runtime: "browser", // default
    }),
  ],
  build: {
    target: "esnext",
    rollupOptions: {
      input: {
        main: "index.html",
        worker: "worker.html",
      },
    },
  },
});
