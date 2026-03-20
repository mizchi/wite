import { defineConfig } from "vite";
import wite from "vite-plugin-wite";

export default defineConfig({
  plugins: [
    wite({
      dts: true,
      environments: {
        client: {
          runtime: "browser",
        },
        ssr: {
          runtime: "node",
          dts: false,
        },
      },
    }),
  ],
  build: {
    target: "esnext",
  },
  ssr: {
    // Workers use direct wasm imports — don't process through the plugin
    external: [/\.wasm$/],
  },
});
