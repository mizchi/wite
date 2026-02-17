import type { WasmImport } from "./wasm-parser.js";

/**
 * Generate JS code for import shims based on what the wasm module requires.
 */
export function generateImportShims(
  imports: WasmImport[],
  customShims?: Record<string, string>,
): string {
  const modules = new Set(imports.map((i) => i.module));
  const parts: string[] = [];

  for (const mod of modules) {
    if (customShims?.[mod]) {
      parts.push(customShims[mod]);
      continue;
    }

    const shimCode = getBuiltinShim(mod, imports.filter((i) => i.module === mod));
    if (shimCode) {
      parts.push(shimCode);
    }
  }

  return parts.join("\n");
}

function getBuiltinShim(
  moduleName: string,
  _imports: WasmImport[],
): string | undefined {
  switch (moduleName) {
    case "spectest":
      return SPECTEST_SHIM;
    case "wasi_snapshot_preview1":
      return WASI_STUB_SHIM;
    default:
      return undefined;
  }
}

/**
 * Generate the importObject expression for WebAssembly.instantiate.
 */
export function generateImportObject(
  imports: WasmImport[],
  customShims?: Record<string, string>,
): string {
  const modules = new Set(imports.map((i) => i.module));
  if (modules.size === 0) return "{}";

  const entries: string[] = [];
  for (const mod of modules) {
    if (customShims?.[mod]) {
      entries.push(`  ${JSON.stringify(mod)}: ${sanitizeModuleRef(mod)}`);
    } else if (mod === "spectest") {
      entries.push(`  "spectest": __spectest`);
    } else if (mod === "wasi_snapshot_preview1") {
      entries.push(`  "wasi_snapshot_preview1": __wasi`);
    } else {
      // Unknown module - create empty stub
      entries.push(
        `  ${JSON.stringify(mod)}: new Proxy({}, { get: () => () => 0 })`,
      );
    }
  }

  return `{\n${entries.join(",\n")}\n}`;
}

function sanitizeModuleRef(mod: string): string {
  return "__shim_" + mod.replace(/[^a-zA-Z0-9_]/g, "_");
}

const SPECTEST_SHIM = `let __spectest_buf = '';
const __spectest = {
  print_char(ch) {
    if (ch === 10) {
      console.log(__spectest_buf);
      __spectest_buf = '';
    } else {
      __spectest_buf += String.fromCharCode(ch);
    }
  }
};`;

const WASI_STUB_SHIM = `const __wasi = new Proxy({}, {
  get(_target, _prop) {
    return () => 0;
  }
});`;
