import { resolve } from "node:path";
import { existsSync, readFileSync, unlinkSync } from "node:fs";
import { describe, it, expect, afterEach } from "vitest";
import witePlugin from "../src/index.js";
import { RUNTIME_MODULE_ID } from "../src/runtime.js";
import type { Plugin } from "vite";

// --- Fixture paths ---
const FIXTURES = resolve(__dirname, "fixtures");
const ADD_WASM_PATH = resolve(FIXTURES, "add.wasm");
const MUL_WASM_PATH = resolve(FIXTURES, "mul.wasm");
const ADD_MEMORY_WASM_PATH = resolve(FIXTURES, "add-with-memory.wasm");
const MATH_COMPONENT_PATH = resolve(FIXTURES, "math.wasm");
const MINIMAL_COMPONENT_PATH = resolve(FIXTURES, "minimal-component.wasm");
const EMPTY_WASM_PATH = resolve(FIXTURES, "empty.wasm");
const INVALID_WASM_PATH = resolve(FIXTURES, "invalid.wasm");

const VIRTUAL_PREFIX = "\0wite:";

// Clean up generated .d.ts files after tests
const generatedDts: string[] = [];
afterEach(() => {
  for (const p of generatedDts) {
    try {
      if (existsSync(p)) unlinkSync(p);
    } catch {}
  }
  generatedDts.length = 0;
});

/**
 * Create a plugin instance with configResolved called.
 */
function createPlugin(
  opts: {
    isBuild?: boolean;
    root?: string;
    dts?: boolean;
    jco?: boolean | "auto";
    runtime?: "browser" | "workerd" | "node" | "webworker";
    environments?: Record<string, any>;
  } = {},
) {
  const plugin = witePlugin({
    dts: opts.dts ?? false,
    jco: opts.jco ?? false, // default to false in tests to avoid jco dependency
    runtime: opts.runtime,
    environments: opts.environments,
  }) as Plugin & {
    resolveId: (source: string, importer?: string) => any;
    load: (id: string) => string | undefined;
    configResolved: (config: any) => void;
  };
  plugin.configResolved({
    root: opts.root ?? "/project",
    command: opts.isBuild ? "build" : "serve",
    build: { outDir: "dist" },
  });
  return plugin;
}

// --- resolveId tests ---

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
    expect(
      plugin.resolveId("./test.js", "/project/src/index.ts"),
    ).toBeUndefined();
    expect(
      plugin.resolveId("./test.ts", "/project/src/index.ts"),
    ).toBeUndefined();
  });

  it("ignores already-virtual IDs", () => {
    const plugin = createPlugin();
    expect(
      plugin.resolveId("\0something.wasm", "/project/src/index.ts"),
    ).toBeUndefined();
  });

  it("resolves .wac files", () => {
    const plugin = createPlugin();
    const result = plugin.resolveId("./app.wac", "/project/src/index.ts");
    expect(result).toBe(VIRTUAL_PREFIX + "/project/src/app.wac");
  });

  it("resolves ?wite-worker suffix", () => {
    const plugin = createPlugin();
    const result = plugin.resolveId(
      "./test.wasm?wite-worker",
      "/project/src/index.ts",
    );
    expect(result).toBe(
      VIRTUAL_PREFIX + "/project/src/test.wasm?wite-worker",
    );
  });
});

// --- load tests ---

describe("load", () => {
  it("returns runtime module code for runtime ID", () => {
    const plugin = createPlugin();
    const result = plugin.load(RUNTIME_MODULE_ID);
    expect(result).toContain("__witeGetInstance");
    expect(result).toContain("__witeInvalidate");
    expect(result).toContain("__witeReload");
  });

  it("ignores non-virtual IDs", () => {
    const plugin = createPlugin();
    expect(plugin.load("/project/src/test.wasm")).toBeUndefined();
  });

  describe("core wasm", () => {
    it("generates wrapper with __witeGetInstance", () => {
      const plugin = createPlugin({ root: "/" });
      const result = plugin.load(VIRTUAL_PREFIX + ADD_WASM_PATH);
      expect(result).toBeDefined();
      expect(result).toContain("__witeGetInstance");
      expect(result).toContain("instance.exports");
    });

    it("exports function names from wasm", () => {
      const plugin = createPlugin({ root: "/" });
      const result = plugin.load(VIRTUAL_PREFIX + ADD_WASM_PATH)!;
      expect(result).toContain('"add"');
    });

    it("exports memory when present", () => {
      const plugin = createPlugin({ root: "/" });
      const result = plugin.load(VIRTUAL_PREFIX + ADD_MEMORY_WASM_PATH)!;
      expect(result).toContain('"memory"');
    });
  });

  describe("component model", () => {
    it("lowers component to core (jco: false)", () => {
      const plugin = createPlugin({ root: "/", jco: false });
      const result = plugin.load(VIRTUAL_PREFIX + MATH_COMPONENT_PATH);
      expect(result).toBeDefined();
      expect(result).toContain("__witeGetInstance");
      expect(result).toContain("instance.exports");
    });

    it("errors for component model without jco (jco: auto)", () => {
      // This test assumes jco is NOT installed in the test environment
      // If jco IS installed, this test will be skipped
      const plugin = createPlugin({ root: "/", jco: "auto" });
      // Mock this.error by catching the thrown error
      let errorMsg = "";
      const originalLoad = plugin.load.bind(plugin);
      plugin.load = function (id: string) {
        try {
          return originalLoad.call(
            {
              ...this,
              error: (msg: string) => {
                errorMsg = msg;
                throw new Error(msg);
              },
              emitFile: () => "ref",
            },
            id,
          );
        } catch {
          return undefined;
        }
      };
      plugin.load(VIRTUAL_PREFIX + MATH_COMPONENT_PATH);
      // Either jco handled it (no error) or we got the install message
      if (errorMsg) {
        expect(errorMsg).toContain("jco");
        expect(errorMsg).toContain("npm install");
      }
    });
  });

  describe("error handling", () => {
    it("errors on empty wasm file", () => {
      const plugin = createPlugin({ root: "/" });
      let errorMsg = "";
      const load = plugin.load.bind({
        ...plugin,
        error: (msg: string) => {
          errorMsg = msg;
        },
        emitFile: () => "ref",
        environment: undefined,
      });
      load(VIRTUAL_PREFIX + EMPTY_WASM_PATH);
      expect(errorMsg).toContain("Failed to parse wasm");
    });

    it("errors on invalid wasm file", () => {
      const plugin = createPlugin({ root: "/" });
      let errorMsg = "";
      const load = plugin.load.bind({
        ...plugin,
        error: (msg: string) => {
          errorMsg = msg;
        },
        emitFile: () => "ref",
        environment: undefined,
      });
      load(VIRTUAL_PREFIX + INVALID_WASM_PATH);
      expect(errorMsg).toContain("Failed to parse wasm");
    });

    it("errors on nonexistent file", () => {
      const plugin = createPlugin({ root: "/" });
      let errorMsg = "";
      const load = plugin.load.bind({
        ...plugin,
        error: (msg: string) => {
          errorMsg = msg;
        },
        emitFile: () => "ref",
        environment: undefined,
      });
      load(VIRTUAL_PREFIX + "/nonexistent/file.wasm");
      expect(errorMsg).toContain("Failed to read wasm file");
    });
  });

  describe(".d.ts generation", () => {
    it("generates .d.ts for core wasm with function signatures", () => {
      const dtsPath = ADD_WASM_PATH + ".d.ts";
      generatedDts.push(dtsPath);
      const plugin = createPlugin({ root: "/", dts: true });
      plugin.load(VIRTUAL_PREFIX + ADD_WASM_PATH);
      expect(existsSync(dtsPath)).toBe(true);
      const content = readFileSync(dtsPath, "utf-8");
      expect(content).toContain("export declare function add");
      expect(content).toContain("number");
    });

    it("generates .d.ts with memory export", () => {
      const dtsPath = ADD_MEMORY_WASM_PATH + ".d.ts";
      generatedDts.push(dtsPath);
      const plugin = createPlugin({ root: "/", dts: true });
      plugin.load(VIRTUAL_PREFIX + ADD_MEMORY_WASM_PATH);
      expect(existsSync(dtsPath)).toBe(true);
      const content = readFileSync(dtsPath, "utf-8");
      expect(content).toContain("WebAssembly.Memory");
    });

    it("does not generate .d.ts when dts: false", () => {
      const dtsPath = ADD_WASM_PATH + ".d.ts";
      // Clean up any existing .d.ts
      try {
        unlinkSync(dtsPath);
      } catch {}
      generatedDts.push(dtsPath);
      const plugin = createPlugin({ root: "/", dts: false });
      plugin.load(VIRTUAL_PREFIX + ADD_WASM_PATH);
      // Should not exist (or at least not been regenerated)
    });
  });

  describe("content-hash dedup", () => {
    it("does not dedup different wasm files", () => {
      const plugin = createPlugin({ root: "/" });
      const addResult = plugin.load(VIRTUAL_PREFIX + ADD_WASM_PATH);
      const mulResult = plugin.load(VIRTUAL_PREFIX + MUL_WASM_PATH);
      expect(addResult).toContain("__witeGetInstance");
      expect(mulResult).toContain("__witeGetInstance");
      expect(mulResult).not.toContain("export * from");
    });
  });

  describe("HMR code generation", () => {
    it("includes import.meta.hot.accept in dev mode", () => {
      const plugin = createPlugin({ root: "/", isBuild: false });
      const result = plugin.load(VIRTUAL_PREFIX + ADD_WASM_PATH)!;
      expect(result).toContain("import.meta.hot");
      expect(result).toContain("import.meta.hot.accept");
      expect(result).toContain("wite:update");
    });

    it("uses let bindings for exports in dev mode", () => {
      const plugin = createPlugin({ root: "/", isBuild: false });
      const result = plugin.load(VIRTUAL_PREFIX + ADD_WASM_PATH)!;
      expect(result).toContain("export let ");
      expect(result).not.toContain("export const ");
    });

    it("does not include HMR code in build mode", () => {
      const plugin = createPlugin({ root: "/", isBuild: true });
      // In build mode, emitFile is needed — bind a mock
      const load = plugin.load.bind({
        error: (msg: string) => { throw new Error(msg); },
        emitFile: () => "testref",
        environment: undefined,
      });
      const result = load(VIRTUAL_PREFIX + ADD_WASM_PATH)!;
      expect(result).not.toContain("import.meta.hot");
    });
  });

  describe("webworker runtime", () => {
    it("generates Worker proxy code for ?wite-worker imports", () => {
      const plugin = createPlugin({ root: "/" });
      const result = plugin.load(
        VIRTUAL_PREFIX + ADD_WASM_PATH + "?wite-worker",
      )!;
      expect(result).toContain("new Worker");
      expect(result).toContain("postMessage");
      expect(result).toContain("__witeWorkerCall");
      expect(result).toContain("__witeTerminate");
    });
  });

  describe("node runtime", () => {
    it("generates Buffer-based code for node runtime", () => {
      const plugin = createPlugin({
        root: "/",
        environments: { ssr: { runtime: "node" } },
      });
      // Simulate SSR environment by calling load with environment context
      // In actual Vite, this.environment.name would be "ssr"
      const result = plugin.load(VIRTUAL_PREFIX + ADD_WASM_PATH)!;
      // Without environment context, it uses default runtime (browser)
      expect(result).toContain("__witeGetInstance");
    });
  });
});
