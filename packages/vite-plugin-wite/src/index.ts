import { createHash } from "node:crypto";
import { readFileSync, writeFileSync } from "node:fs";
import { resolve, dirname, relative } from "node:path";
import type { Plugin, ResolvedConfig } from "vite";
import { parseWasm } from "./wasm-parser.js";
import { generateJsWrapper, generateDts } from "./codegen.js";
import { lowerComponent } from "./component.js";
import { RUNTIME_MODULE_ID, RUNTIME_MODULE_CODE } from "./runtime.js";

/**
 * Runtime target for wasm loading strategy.
 * - "browser": WebAssembly.instantiateStreaming(fetch(url)) (default)
 * - "workerd": import wasmModule → WebAssembly.instantiate(module)
 * - "node": fs.readFile → WebAssembly.instantiate(buffer)
 */
export type WiteRuntimeTarget = "browser" | "workerd" | "node";

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
  } = options;
  let config: ResolvedConfig;
  let isBuild = false;

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

      if (!source.endsWith(".wasm") && !source.endsWith(".wac")) return;
      if (source.startsWith("\0")) return;

      // In workerd runtime, wasm imports should be external (wrangler handles them)
      const env: any = (this as any).environment;
      const envName: string | undefined = env?.name;
      const envRuntime = envOptions?.[envName ?? ""]?.runtime;
      if (envRuntime === "workerd") {
        const importerDir = importer ? dirname(importer) : config.root;
        return { id: resolve(importerDir, source), external: true };
      }

      const importerDir = importer ? dirname(importer) : config.root;
      const absolutePath = resolve(importerDir, source);

      return VIRTUAL_PREFIX + absolutePath;
    },

    load(id) {
      if (id === RUNTIME_MODULE_ID) return RUNTIME_MODULE_CODE;

      if (!id.startsWith(VIRTUAL_PREFIX)) return;

      const env: any = (this as any).environment;
      const envName: string | undefined = env?.name;
      const resolved = resolveEnvOptions(
        envName,
        { shims: customShims, dts, runtime: defaultRuntime },
        envOptions,
      );

      // Auto-detect runtime if not explicitly set
      const runtime =
        envOptions?.[envName ?? ""]?.runtime ??
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

      // Handle component model: lower to core module
      if (metadata.isComponent) {
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

          server.ws.send({ type: "full-reload" });
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

  return `import { __witeGetInstance } from ${JSON.stringify(RUNTIME_MODULE_ID)};
${ctx.shimCode}
${wasmUrlCode}
const { instance } = await __witeGetInstance(wasmUrl, ${ctx.importObject});
${ctx.exports}
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
