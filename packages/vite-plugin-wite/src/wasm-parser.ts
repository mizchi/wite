import { parse_wasm_metadata as _parseWasmMetadata } from "./generated/wasm-parser.js";

export type WasmValType =
  | "i32"
  | "i64"
  | "f32"
  | "f64"
  | "v128"
  | "funcref"
  | "externref"
  | "unknown";

export type ExportKind = "function" | "table" | "memory" | "global";
export type ImportKind =
  | "function"
  | "table"
  | "memory"
  | "global"
  | "tag"
  | "unknown";

export interface FuncType {
  params: WasmValType[];
  results: WasmValType[];
}

export interface WasmImport {
  module: string;
  name: string;
  kind: ImportKind;
  typeIndex?: number;
}

export interface WasmExport {
  name: string;
  kind: ExportKind;
  index: number;
}

export interface WasmModuleMetadata {
  isComponent: boolean;
  types: FuncType[];
  imports: WasmImport[];
  exports: WasmExport[];
  functions: number[];
  error?: string;
}

export function parseWasm(bytes: Uint8Array): WasmModuleMetadata {
  const json = _parseWasmMetadata(bytes);
  return JSON.parse(json) as WasmModuleMetadata;
}

/**
 * Resolve the FuncType for an exported function.
 * Function index space: imported functions first, then code-section functions.
 */
export function getExportedFuncType(
  metadata: WasmModuleMetadata,
  exp: WasmExport,
): FuncType | undefined {
  if (exp.kind !== "function") return undefined;

  const importedFuncCount = metadata.imports.filter(
    (i) => i.kind === "function",
  ).length;

  if (exp.index < importedFuncCount) {
    // Re-exported import
    const imp = metadata.imports.filter((i) => i.kind === "function")[
      exp.index
    ];
    return imp?.typeIndex !== undefined
      ? metadata.types[imp.typeIndex]
      : undefined;
  }

  const localIndex = exp.index - importedFuncCount;
  if (localIndex >= metadata.functions.length) return undefined;
  const typeIndex = metadata.functions[localIndex];
  return metadata.types[typeIndex];
}

export function valTypeToTS(vt: WasmValType): string {
  switch (vt) {
    case "i32":
      return "number";
    case "i64":
      return "bigint";
    case "f32":
      return "number";
    case "f64":
      return "number";
    case "v128":
      return "number";
    case "funcref":
      return "Function";
    case "externref":
      return "any";
    default:
      return "unknown";
  }
}
