import { defineConfig } from "vite";
import wite from "vite-plugin-wite";

export default defineConfig({
  plugins: [wite({ dts: true, jco: false })],
  build: { target: "esnext" },
  base: "./",
});
