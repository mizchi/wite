import { resolve } from "node:path";
import { defineConfig } from "vite";
import wite from "vite-plugin-wite";

export default defineConfig({
  plugins: [wite()],
  build: {
    target: "esnext",
    rollupOptions: {
      input: {
        main: resolve(__dirname, "index.html"),
        calc: resolve(__dirname, "calc.html"),
        compose: resolve(__dirname, "compose.html"),
      },
    },
  },
});
