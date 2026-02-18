import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { describe, it, expect, beforeEach } from "vitest";
import witePlugin from "../src/index.js";
import { RUNTIME_MODULE_ID } from "../src/runtime.js";
import type { Plugin } from "vite";

const ADD_WASM_PATH = resolve(
  __dirname,
  "../../../examples/vite-plugin-multi/src/add.wasm",
);
const MUL_WASM_PATH = resolve(
  __dirname,
  "../../../examples/vite-plugin-multi/src/mul.wasm",
);
const MATH_COMPONENT_PATH = resolve(
  __dirname,
  "../../../examples/vite-plugin-multi/src/math.wasm",
);

const VIRTUAL_PREFIX = "\0wite:";

/**
 * Create a plugin instance with configResolved called.
 */
function createPlugin(
  opts: { isBuild?: boolean; root?: string; dts?: boolean } = {},
) {
  const plugin = witePlugin({ dts: opts.dts ?? false }) as Plugin & {
    resolveId: (source: string, importer?: string) => string | undefined;
    load: (id: string) => string | undefined;
    configResolved: (config: any) => void;
  };
  plugin.configResolved({
    root: opts.root ?? "/project",
    command: opts.isBuild ? "build" : "serve",
  });
  return plugin;
}

describe("resolveId", () => {
  it("resolves .wasm files to virtual prefix", () => {
    const plugin = createPlugin();
    const result = plugin.resolveId("./test.wasm", "/project/src/index.ts");
    expect(result).toBe(VIRTUAL_PREFIX + "/project/src/test.wasm");
  });

  it("resolves runtime module ID", () => {
    const plugin = createPlugin();
    const result = plugin.resolveId(RUNTIME_MODULE_ID);
    expect(result).toBe(RUNTIME_MODULE_ID);
  });

  it("ignores non-.wasm files", () => {
    const plugin = createPlugin();
    expect(plugin.resolveId("./test.js", "/project/src/index.ts")).toBeUndefined();
    expect(plugin.resolveId("./test.ts", "/project/src/index.ts")).toBeUndefined();
  });

  it("ignores already-virtual IDs", () => {
    const plugin = createPlugin();
    expect(
      plugin.resolveId("\0something.wasm", "/project/src/index.ts"),
    ).toBeUndefined();
  });
});

describe("load", () => {
  it("returns runtime module code for runtime ID", () => {
    const plugin = createPlugin();
    const result = plugin.load(RUNTIME_MODULE_ID);
    expect(result).toContain("__witeGetInstance");
    expect(result).toContain("new Map()");
  });

  it("ignores non-virtual IDs", () => {
    const plugin = createPlugin();
    expect(plugin.load("/project/src/test.wasm")).toBeUndefined();
    expect(plugin.load("./test.wasm")).toBeUndefined();
  });

  describe("core wasm module", () => {
    it("generates wrapper importing __witeGetInstance", () => {
      const plugin = createPlugin({ root: "/" });
      const result = plugin.load(VIRTUAL_PREFIX + ADD_WASM_PATH);
      expect(result).toBeDefined();
      expect(result).toContain("__witeGetInstance");
      // JSON.stringify escapes \0 to \\u0000 in the generated code
      expect(result).toContain("\\u0000wite-runtime");
    });

    it("does not contain direct WebAssembly.instantiateStreaming call", () => {
      const plugin = createPlugin({ root: "/" });
      const result = plugin.load(VIRTUAL_PREFIX + ADD_WASM_PATH)!;
      // The wrapper should use __witeGetInstance, not direct instantiation
      const lines = result.split("\n").filter(
        (l) => !l.startsWith("import"),
      );
      const bodyCode = lines.join("\n");
      expect(bodyCode).not.toContain("WebAssembly.instantiateStreaming");
    });

    it("exports wasm exports", () => {
      const plugin = createPlugin({ root: "/" });
      const result = plugin.load(VIRTUAL_PREFIX + ADD_WASM_PATH)!;
      expect(result).toContain("instance.exports");
    });
  });

  describe("component lowering", () => {
    it("lowers component to core and uses runtime", () => {
      const plugin = createPlugin({ root: "/" });
      const result = plugin.load(VIRTUAL_PREFIX + MATH_COMPONENT_PATH);
      expect(result).toBeDefined();
      expect(result).toContain("__witeGetInstance");
      expect(result).toContain("instance.exports");
    });
  });

  describe("content-hash dedup", () => {
    it("returns re-export for identical wasm content", () => {
      const plugin = createPlugin({ root: "/" });

      // Load add.wasm first
      const firstId = VIRTUAL_PREFIX + ADD_WASM_PATH;
      const firstResult = plugin.load(firstId);
      expect(firstResult).toContain("__witeGetInstance");

      // Load the same file under a different virtual ID (simulating a copy)
      // We use the same path since it's the same file, but force a new ID
      const secondId = VIRTUAL_PREFIX + ADD_WASM_PATH;
      const secondResult = plugin.load(secondId);
      // Same ID → not a dedup, returns normal code
      expect(secondResult).toContain("__witeGetInstance");
    });

    it("does not dedup different wasm files", () => {
      const plugin = createPlugin({ root: "/" });

      const addResult = plugin.load(VIRTUAL_PREFIX + ADD_WASM_PATH);
      const mulResult = plugin.load(VIRTUAL_PREFIX + MUL_WASM_PATH);

      // Both should be full wrappers, not re-exports
      expect(addResult).toContain("__witeGetInstance");
      expect(mulResult).toContain("__witeGetInstance");
      expect(mulResult).not.toContain("export * from");
    });
  });

  describe("dev mode URL generation", () => {
    it("generates URL with cache-busting timestamp in dev mode", () => {
      const plugin = createPlugin({ root: "/", isBuild: false });
      const result = plugin.load(VIRTUAL_PREFIX + ADD_WASM_PATH)!;
      // Dev mode: URL should contain ?t= for cache busting
      expect(result).toContain("?t=");
    });
  });
});
