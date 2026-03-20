import { createHash } from "node:crypto";
import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { resolve, dirname, relative } from "node:path";
import type { Plugin, ResolvedConfig } from "vite";
import { parseWasm } from "./wasm-parser.js";
import { generateJsWrapper, generateDts } from "./codegen.js";
import { lowerComponent } from "./component.js";
import { RUNTIME_MODULE_ID, RUNTIME_MODULE_CODE } from "./runtime.js";
import {
  jcoTranspile,
  jcoTranspileWithTypes,
  isJcoAvailable,
} from "./jco.js";

/**
 * Runtime target for wasm loading strategy.
 * - "browser": WebAssembly.instantiateStreaming(fetch(url)) (default)
 * - "workerd": import wasmModule → WebAssembly.instantiate(module)
 * - "node": fs.readFile → WebAssembly.instantiate(buffer)
 */
export type WiteRuntimeTarget = "browser" | "workerd" | "node" | "webworker";

/**
 * Per-environment options for the wite plugin.
 */
export interface WiteEnvironmentOptions {
  /** Custom import shims for this environment */
  shims?: Record<string, string>;
  /** Generate .d.ts files for this environment */
  dts?: boolean;
  /** Optimization level applied during build */
  optimize?: string;
  /** Binary kind override */
  kind?: "auto" | "core" | "component";
  /**
   * Runtime target for wasm loading.
   * Determines how wasm modules are instantiated.
   * @default "browser"
   */
  runtime?: WiteRuntimeTarget;
}

export interface WitePluginOptions {
  /**
   * Custom import shims for wasm modules.
   */
  shims?: Record<string, string>;

  /**
   * Generate .d.ts files alongside .wasm files.
   * @default true
   */
  dts?: boolean;

  /**
   * Default runtime target for wasm loading.
   * @default "browser"
   */
  runtime?: WiteRuntimeTarget;

  /**
   * Per-environment overrides, keyed by Vite environment name.
   */
  environments?: Record<string, WiteEnvironmentOptions>;

  /**
   * Enable jco transpile for Component Model wasm.
   * When true (or "auto"), component .wasm files are automatically
   * transpiled to ESM using jco, with full string/record marshaling.
   * Requires `jco` to be installed (npx jco).
   * @default "auto" (use jco if available)
   */
  jco?: boolean | "auto";
}

const VIRTUAL_PREFIX = "\0wite:";

interface ResolvedEnvOptions {
  shims: Record<string, string>;
  dts: boolean;
  optimize?: string;
  runtime: WiteRuntimeTarget;
}

function resolveEnvOptions(
  envName: string | undefined,
  topLevel: {
    shims?: Record<string, string>;
    dts: boolean;
    runtime: WiteRuntimeTarget;
  },
  environments?: Record<string, WiteEnvironmentOptions>,
): ResolvedEnvOptions {
  const envOpts = envName ? environments?.[envName] : undefined;
  return {
    shims: { ...topLevel.shims, ...envOpts?.shims },
    dts: envOpts?.dts ?? topLevel.dts,
    optimize: envOpts?.optimize,
    runtime: envOpts?.runtime ?? topLevel.runtime,
  };
}

/**
 * Auto-detect runtime from Vite environment.
 * Falls back to the configured default.
 */
function detectRuntime(
  envName: string | undefined,
  envConfig: any,
  defaultRuntime: WiteRuntimeTarget,
): WiteRuntimeTarget {
  // Check if environment consumer type hints at server-side
  if (envConfig?.consumer === "server") {
    // Check for workerd-specific indicators
    if (envName === "workerd" || envName === "edge") {
      return "workerd";
    }
    return "node";
  }
  return defaultRuntime;
}

export default function witePlugin(options: WitePluginOptions = {}): Plugin {
  const {
    shims: customShims,
    dts = true,
    runtime: defaultRuntime = "browser",
    environments: envOptions,
    jco: jcoOption = "auto",
  } = options;
  let config: ResolvedConfig;
  let isBuild = false;
  const useJco =
    jcoOption === true || (jcoOption === "auto" && isJcoAvailable());

  const contentHashMap = new Map<string, string>();

  return {
    name: "vite-plugin-wite",
    enforce: "pre",

    configResolved(resolvedConfig) {
      config = resolvedConfig;
      isBuild = resolvedConfig.command === "build";
    },

    resolveId(source, importer) {
      if (source === RUNTIME_MODULE_ID) return source;

      // Support ?wite-worker suffix for webworker runtime
      const isWorkerImport = source.endsWith(".wasm?wite-worker");
      const cleanSource = isWorkerImport
        ? source.replace("?wite-worker", "")
        : source;

      if (!cleanSource.endsWith(".wasm") && !cleanSource.endsWith(".wac"))
        return;
      if (cleanSource.startsWith("\0")) return;

      // In workerd runtime, wasm imports should be external
      const env: any = (this as any).environment;
      const envName: string | undefined = env?.name;
      const envRuntime = envOptions?.[envName ?? ""]?.runtime;
      if (envRuntime === "workerd") {
        const importerDir = importer ? dirname(importer) : config.root;
        return { id: resolve(importerDir, cleanSource), external: true };
      }

      const importerDir = importer ? dirname(importer) : config.root;
      const absolutePath = resolve(importerDir, cleanSource);

      // Mark webworker imports with a suffix the load hook can detect
      const suffix = isWorkerImport ? "?wite-worker" : "";
      return VIRTUAL_PREFIX + absolutePath + suffix;
    },

    load(id) {
      if (id === RUNTIME_MODULE_ID) return RUNTIME_MODULE_CODE;

      if (!id.startsWith(VIRTUAL_PREFIX)) return;

      // Detect ?wite-worker suffix for webworker runtime override
      const isWorkerImport = id.endsWith("?wite-worker");
      if (isWorkerImport) {
        id = id.slice(0, -"?wite-worker".length);
      }

      const env: any = (this as any).environment;
      const envName: string | undefined = env?.name;
      const resolved = resolveEnvOptions(
        envName,
        { shims: customShims, dts, runtime: defaultRuntime },
        envOptions,
      );

      // Determine runtime: ?wite-worker suffix overrides environment config
      const runtime = isWorkerImport
        ? ("webworker" as WiteRuntimeTarget)
        : envOptions?.[envName ?? ""]?.runtime ??
          detectRuntime(envName, env?.config, defaultRuntime);

      const wasmPath = id.slice(VIRTUAL_PREFIX.length);
      let bytes: Uint8Array;
      try {
        bytes = new Uint8Array(readFileSync(wasmPath));
      } catch {
        this.error(`Failed to read wasm file: ${wasmPath}`);
        return;
      }

      let metadata = parseWasm(bytes);

      if (metadata.error) {
        this.error(`Failed to parse wasm: ${metadata.error}`);
        return;
      }

      // Handle component model
      if (metadata.isComponent) {
        // jco is required for Component Model wasm (unless explicitly disabled)
        if (jcoOption !== false && !isJcoAvailable()) {
          this.error(
            `[vite-plugin-wite] Component Model wasm requires jco for browser transpilation.\n` +
            `\n` +
            `Install jco:\n` +
            `  npm install -g @bytecodealliance/jco\n` +
            `  # or\n` +
            `  pnpm add -D @bytecodealliance/jco\n` +
            `\n` +
            `File: ${wasmPath}\n` +
            `\n` +
            `To use core wasm extraction as a fallback (loses CM type marshaling), set:\n` +
            `  wite({ jco: false })`,
          );
          return;
        }

        // Try jco transpile (full CM support with string marshaling)
        if (useJco && runtime === "browser") {
          const result = jcoTranspile(wasmPath);
          if (result) {
            if (resolved.dts) {
              generateComponentDts(wasmPath, result.files);
            }
            return result.js;
          }
        }

        // jco: false — fallback to core module extraction
        // TODO: implement built-in CM→ESM transpilation to remove jco dependency
        const lowered = lowerComponent(bytes);
        if (!lowered) {
          this.error(
            `Failed to lower component model wasm: no core module found.`,
          );
          return;
        }
        bytes = lowered;
        metadata = parseWasm(bytes);
        if (metadata.error) {
          this.error(`Failed to parse lowered wasm: ${metadata.error}`);
          return;
        }
        // metadata now has core module types — .d.ts will be generated below
      }

      // Content-hash dedup
      const hash = createHash("sha256")
        .update(bytes)
        .digest("hex")
        .slice(0, 16);
      const canonicalId = contentHashMap.get(hash);
      if (canonicalId && canonicalId !== id) {
        return `export * from ${JSON.stringify(canonicalId)};`;
      }
      contentHashMap.set(hash, id);

      // Generate .d.ts if enabled
      if (resolved.dts) {
        const dtsContent = generateDts(metadata);
        const dtsPath = wasmPath + ".d.ts";
        try {
          writeFileSync(dtsPath, dtsContent);
        } catch {
          // Non-fatal
        }
      }

      // Generate import shims
      const shimCode =
        metadata.imports.length > 0
          ? generateImportShimsInline(metadata, resolved.shims)
          : "";
      const importObject =
        metadata.imports.length > 0
          ? generateImportObjectInline(metadata, resolved.shims)
          : "{}";

      const exports = metadata.exports
        .map((exp) => {
          const ident = safeId(exp.name);
          return `export const ${ident} = instance.exports[${JSON.stringify(exp.name)}];`;
        })
        .join("\n");

      // Generate runtime-specific instantiation code
      return generateModuleCode(runtime, {
        wasmPath,
        isBuild,
        config,
        shimCode,
        importObject,
        exports,
        bytes,
        emitFile: (opts) => this.emitFile(opts),
      });
    },

    configureServer(server) {
      server.watcher.on("change", (file) => {
        if (file.endsWith(".wasm") || file.endsWith(".wac")) {
          // Auto-regenerate .d.ts on wasm change
          if (dts && file.endsWith(".wasm")) {
            try {
              const bytes = new Uint8Array(readFileSync(file));
              const metadata = parseWasm(bytes);
              if (metadata.isComponent) {
                // Component Model: use jco or lowered core for .d.ts
                generateComponentDts(file);
              } else if (!metadata.error) {
                const dtsContent = generateDts(metadata);
                writeFileSync(file + ".d.ts", dtsContent);
              }
            } catch {
              // Non-fatal
            }
          }

          for (const [hash, cachedId] of contentHashMap) {
            if (cachedId === VIRTUAL_PREFIX + file) {
              contentHashMap.delete(hash);
              break;
            }
          }

          // Vite 6+ Environment API
          if (server.environments) {
            for (const env of Object.values(server.environments)) {
              const mod = (env as any).moduleGraph?.getModuleById(
                VIRTUAL_PREFIX + file,
              );
              if (mod) {
                (env as any).moduleGraph?.invalidateModule(mod);
              }
            }
          }

          // Vite 5 fallback
          const mod = server.moduleGraph.getModuleById(VIRTUAL_PREFIX + file);
          if (mod) {
            server.moduleGraph.invalidateModule(mod);
          }

          // Send wasm-specific HMR event (modules with accept() handle it)
          // Falls back to full-reload for modules without HMR support
          const relPath = relative(config.root, file);
          const wasmUrl = "/" + relPath.split("\\").join("/");
          server.ws.send({
            type: "custom",
            event: "wite:update",
            data: { url: wasmUrl, file },
          });
        }
      });
    },
  };
}

// --- Code generation per runtime target ---

interface CodeGenContext {
  wasmPath: string;
  isBuild: boolean;
  config: ResolvedConfig;
  shimCode: string;
  importObject: string;
  exports: string;
  bytes: Uint8Array;
  emitFile: (opts: { type: "asset"; name?: string; source: Uint8Array }) => string;
}

function generateModuleCode(
  runtime: WiteRuntimeTarget,
  ctx: CodeGenContext,
): string {
  switch (runtime) {
    case "workerd":
      return generateWorkerdCode(ctx);
    case "node":
      return generateNodeCode(ctx);
    case "webworker":
      return generateWebWorkerCode(ctx);
    case "browser":
    default:
      return generateBrowserCode(ctx);
  }
}

function generateBrowserCode(ctx: CodeGenContext): string {
  let wasmUrlCode: string;
  if (ctx.isBuild) {
    const fileRef = ctx.emitFile({
      type: "asset",
      name: ctx.wasmPath.split("/").pop(),
      source: ctx.bytes,
    });
    wasmUrlCode = `const wasmUrl = import.meta.ROLLUP_FILE_URL_${fileRef};`;
  } else {
    const relPath = relative(ctx.config.root, ctx.wasmPath);
    const normalizedPath = "/" + relPath.split("\\").join("/");
    wasmUrlCode = `const wasmUrl = ${JSON.stringify(normalizedPath)} + "?t=" + ${JSON.stringify(String(Date.now()))};`;
  }

  const hmrCode = ctx.isBuild
    ? ""
    : `
if (import.meta.hot) {
  import.meta.hot.accept();
  import.meta.hot.on('wite:update', async (data) => {
    const { __witeReload } = await import(${JSON.stringify(RUNTIME_MODULE_ID)});
    const reloaded = await __witeReload(wasmUrl, ${ctx.importObject});
    const newExports = reloaded.instance.exports;
    ${ctx.exports
      .split("\n")
      .filter((l) => l.startsWith("export const "))
      .map((l) => {
        const match = l.match(/export const (\w+) = instance\.exports\["(.+)"\]/);
        if (!match) return "";
        return `    ${match[1]} = newExports["${match[2]}"];`;
      })
      .filter(Boolean)
      .join("\n")}
  });
}`;

  return `import { __witeGetInstance } from ${JSON.stringify(RUNTIME_MODULE_ID)};
${ctx.shimCode}
${wasmUrlCode}
const { instance } = await __witeGetInstance(wasmUrl, ${ctx.importObject});
${ctx.exports.replace(/export const /g, "export let ")}
${hmrCode}
`;
}

function generateWorkerdCode(ctx: CodeGenContext): string {
  // Cloudflare Workers: ALL dynamic WebAssembly compilation is disallowed.
  // Wasm modules must be imported via ESM `import` statements, which
  // wrangler converts to wasm bindings at deploy time.
  //
  // We write the .wasm file next to the output and emit a direct import.
  // The resolveId hook must NOT intercept this import (it starts with
  // a special marker that the plugin ignores).
  const wasmFileName = ctx.wasmPath.split("/").pop() ?? "module.wasm";

  // Write the wasm bytes to a file next to where the output will be
  // This will be picked up by wrangler's bundler
  const outDir = ctx.config.build?.outDir ?? "dist";
  const wasmOutPath = resolve(ctx.config.root, outDir, wasmFileName);
  try {
    writeFileSync(wasmOutPath, ctx.bytes);
  } catch {
    // Will be written after build dir is created
  }

  // ?wite-raw marker tells resolveId to treat this as external
  return `${ctx.shimCode}
import __wasmModule from "./${wasmFileName}?wite-raw";
const instance = await WebAssembly.instantiate(__wasmModule, ${ctx.importObject});
${ctx.exports}
`;
}

function generateNodeCode(ctx: CodeGenContext): string {
  // Node.js: use synchronous instantiation with buffer
  const base64 = Buffer.from(ctx.bytes).toString("base64");

  return `${ctx.shimCode}
const __wasmBytes = Buffer.from(${JSON.stringify(base64)}, "base64");
const __wasmModule = new WebAssembly.Module(__wasmBytes);
const instance = new WebAssembly.Instance(__wasmModule, ${ctx.importObject});
${ctx.exports}
`;
}

function generateWebWorkerCode(ctx: CodeGenContext): string {
  // Web Worker: wasm runs in a dedicated Worker thread.
  // Main thread gets async proxy functions that communicate via postMessage.
  //
  // Generated code:
  // 1. Inline worker script as a Blob URL
  // 2. Worker loads wasm, listens for { id, method, args } messages
  // 3. Main thread exports async functions that send messages and await responses

  let wasmLoadCode: string;
  if (ctx.isBuild) {
    const fileRef = ctx.emitFile({
      type: "asset",
      name: ctx.wasmPath.split("/").pop(),
      source: ctx.bytes,
    });
    wasmLoadCode = `const wasmUrl = import.meta.ROLLUP_FILE_URL_${fileRef};`;
  } else {
    const relPath = relative(ctx.config.root, ctx.wasmPath);
    const normalizedPath = "/" + relPath.split("\\").join("/");
    wasmLoadCode = `const wasmUrl = ${JSON.stringify(normalizedPath)};`;
  }

  // Parse export names from metadata for the proxy
  const exportNames = ctx.exports
    .split("\n")
    .map((line) => {
      const match = line.match(/export const (\w+)/);
      return match ? match[1] : null;
    })
    .filter(Boolean) as string[];

  // Worker script (runs inside the Worker)
  const workerScript = `
${ctx.shimCode}
const { instance } = await WebAssembly.instantiateStreaming(
  fetch(new URL(self.__witeWasmUrl, self.location.href)),
  ${ctx.importObject}
);
self.onmessage = (e) => {
  const { id, method, args } = e.data;
  try {
    const fn = instance.exports[method];
    const result = typeof fn === 'function' ? fn(...args) : undefined;
    self.postMessage({ id, result });
  } catch (error) {
    self.postMessage({ id, error: String(error) });
  }
};
self.postMessage({ type: 'ready' });
`.trim();

  // Escape for embedding in template literal
  const escapedWorkerScript = workerScript
    .replace(/\\/g, "\\\\")
    .replace(/`/g, "\\`")
    .replace(/\$/g, "\\$");

  // Proxy functions on the main thread
  const proxyExports = exportNames
    .map(
      (name) =>
        `export function ${name}(...args) {
  return __witeWorkerCall(${JSON.stringify(name)}, args);
}`,
    )
    .join("\n\n");

  return `${wasmLoadCode}

const __workerScript = \`self.__witeWasmUrl = '\${wasmUrl}';
${escapedWorkerScript}\`;

const __workerBlob = new Blob([__workerScript], { type: "text/javascript" });
const __workerUrl = URL.createObjectURL(__workerBlob);
const __worker = new Worker(__workerUrl, { type: "classic" });

let __callId = 0;
const __pending = new Map();

__worker.onmessage = (e) => {
  if (e.data.type === 'ready') return;
  const { id, result, error } = e.data;
  const resolve = __pending.get(id);
  if (resolve) {
    __pending.delete(id);
    if (error) resolve.reject(new Error(error));
    else resolve.resolve(result);
  }
};

function __witeWorkerCall(method, args) {
  return new Promise((resolve, reject) => {
    const id = ++__callId;
    __pending.set(id, { resolve, reject });
    __worker.postMessage({ id, method, args });
  });
}

${proxyExports}

export function __witeTerminate() {
  __worker.terminate();
  URL.revokeObjectURL(__workerUrl);
}
`;
}

// Re-export types
export type {
  WasmModuleMetadata,
  WasmExport,
  WasmImport,
  FuncType,
  WasmValType,
} from "./wasm-parser.js";

// --- Inline helpers ---

import { generateImportShims, generateImportObject } from "./shims.js";
import type { WasmModuleMetadata } from "./wasm-parser.js";

function generateImportShimsInline(
  metadata: WasmModuleMetadata,
  customShims?: Record<string, string>,
): string {
  return generateImportShims(metadata.imports, customShims);
}

function generateImportObjectInline(
  metadata: WasmModuleMetadata,
  customShims?: Record<string, string>,
): string {
  return generateImportObject(metadata.imports, customShims);
}

function safeId(name: string): string {
  const reserved = new Set([
    "break", "case", "catch", "continue", "debugger", "default", "delete",
    "do", "else", "finally", "for", "function", "if", "in", "instanceof",
    "new", "return", "switch", "this", "throw", "try", "typeof", "var",
    "void", "while", "with", "class", "const", "enum", "export", "extends",
    "import", "super",
  ]);
  if (reserved.has(name)) return `_${name}`;
  if (!/^[a-zA-Z_$][a-zA-Z0-9_$]*$/.test(name))
    return `_${name.replace(/[^a-zA-Z0-9_$]/g, "_")}`;
  return name;
}

/**
 * Generate .d.ts for a Component Model wasm.
 * Uses jco transpile --typescript if available, otherwise
 * falls back to lowered core module signatures.
 */
function generateComponentDts(
  wasmPath: string,
  jcoFiles?: string[],
): void {
  const dtsPath = wasmPath + ".d.ts";

  // Check if jco already generated a .d.ts
  if (jcoFiles) {
    const dtsFile = jcoFiles.find((f) => f.endsWith(".d.ts"));
    if (dtsFile) {
      const jcoDir = resolve(dirname(wasmPath), ".wite-jco");
      const srcDts = resolve(jcoDir, dtsFile);
      if (existsSync(srcDts)) {
        try {
          const content = readFileSync(srcDts, "utf-8");
          writeFileSync(dtsPath, content);
          return;
        } catch {
          // Fall through
        }
      }
    }
  }

  // Fallback: use jco transpile with types
  const result = jcoTranspileWithTypes(wasmPath);
  if (result) {
    try {
      writeFileSync(dtsPath, result.dts);
      return;
    } catch {
      // Fall through
    }
  }

  // Final fallback: lower to core and generate from signatures
  try {
    const bytes = new Uint8Array(readFileSync(wasmPath));
    const lowered = lowerComponent(bytes);
    if (lowered) {
      const metadata = parseWasm(lowered);
      if (!metadata.error) {
        const dtsContent = generateDts(metadata);
        writeFileSync(dtsPath, dtsContent);
      }
    }
  } catch {
    // Non-fatal
  }
}
