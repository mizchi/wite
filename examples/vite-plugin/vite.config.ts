import { defineConfig } from "vite";
import wite from "vite-plugin-wite";

export default defineConfig({
  plugins: [wite()],
  build: {
    target: "esnext",
  },
});
