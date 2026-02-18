import { createHash } from "node:crypto";
import { readFileSync, writeFileSync } from "node:fs";
import { resolve, dirname, relative } from "node:path";
import type { Plugin, ResolvedConfig } from "vite";
import { parseWasm } from "./wasm-parser.js";
import { generateJsWrapper, generateDts } from "./codegen.js";
import { lowerComponent } from "./component.js";
import { RUNTIME_MODULE_ID, RUNTIME_MODULE_CODE } from "./runtime.js";

export interface WitePluginOptions {
  /**
   * Custom import shims for wasm modules.
   * Key: module name (e.g. "my:module")
   * Value: JS code string that provides the import object for that module.
   */
  shims?: Record<string, string>;

  /**
   * Generate .d.ts files alongside .wasm files.
   * @default true
   */
  dts?: boolean;
}

const VIRTUAL_PREFIX = "\0wite:";

export default function witePlugin(options: WitePluginOptions = {}): Plugin {
  const { shims: customShims, dts = true } = options;
  let config: ResolvedConfig;
  let isBuild = false;

  // Content-hash dedup: maps hash -> first virtual module ID
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

      if (!source.endsWith(".wasm")) return;
      if (source.startsWith("\0")) return;

      const importerDir = importer ? dirname(importer) : config.root;
      const absolutePath = resolve(importerDir, source);

      return VIRTUAL_PREFIX + absolutePath;
    },

    load(id) {
      if (id === RUNTIME_MODULE_ID) return RUNTIME_MODULE_CODE;

      if (!id.startsWith(VIRTUAL_PREFIX)) return;

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

      // Content-hash dedup: if identical wasm was already processed, re-export
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
      if (dts) {
        const dtsContent = generateDts(metadata);
        const dtsPath = wasmPath + ".d.ts";
        try {
          writeFileSync(dtsPath, dtsContent);
        } catch {
          // Non-fatal: .d.ts generation failure shouldn't block the build
        }
      }

      // Generate JS wrapper
      const shimCode =
        metadata.imports.length > 0
          ? generateImportShimsInline(metadata, customShims)
          : "";
      const importObject =
        metadata.imports.length > 0
          ? generateImportObjectInline(metadata, customShims)
          : "{}";

      const exports = metadata.exports
        .map((exp) => {
          const ident = safeId(exp.name);
          return `export const ${ident} = instance.exports[${JSON.stringify(exp.name)}];`;
        })
        .join("\n");

      let wasmUrlCode: string;
      if (isBuild) {
        // Build mode: emit as Rollup asset
        const fileRef = this.emitFile({
          type: "asset",
          name: wasmPath.split("/").pop(),
          source: bytes,
        });
        wasmUrlCode = `const wasmUrl = import.meta.ROLLUP_FILE_URL_${fileRef};`;
      } else {
        // Dev mode: serve the original file via Vite's static file serving
        // Add timestamp for cache busting when wasm files change
        const relPath = relative(config.root, wasmPath);
        const normalizedPath = "/" + relPath.split("\\").join("/");
        wasmUrlCode = `const wasmUrl = ${JSON.stringify(normalizedPath)} + "?t=" + ${JSON.stringify(String(Date.now()))};`;
      }

      return `import { __witeGetInstance } from ${JSON.stringify(RUNTIME_MODULE_ID)};
${shimCode}
${wasmUrlCode}
const { instance } = await __witeGetInstance(wasmUrl, ${importObject});
${exports}
`;
    },

    configureServer(server) {
      // Watch .wasm files for HMR
      server.watcher.on("change", (file) => {
        if (file.endsWith(".wasm")) {
          // Invalidate content-hash cache so re-load uses fresh bytes
          for (const [hash, cachedId] of contentHashMap) {
            if (cachedId === VIRTUAL_PREFIX + file) {
              contentHashMap.delete(hash);
              break;
            }
          }

          const mod = server.moduleGraph.getModuleById(
            VIRTUAL_PREFIX + file,
          );
          if (mod) {
            server.moduleGraph.invalidateModule(mod);
            server.ws.send({ type: "full-reload" });
          }
        }
      });
    },
  };
}

// Re-export types for consumers
export type {
  WasmModuleMetadata,
  WasmExport,
  WasmImport,
  FuncType,
  WasmValType,
} from "./wasm-parser.js";

// --- Inline helpers (avoid circular deps with codegen for plugin load hook) ---

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
