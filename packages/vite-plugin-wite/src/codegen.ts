import {
  type WasmModuleMetadata,
  type WasmExport,
  getExportedFuncType,
  valTypeToTS,
} from "./wasm-parser.js";
import { generateImportShims, generateImportObject } from "./shims.js";

export interface CodegenOptions {
  wasmPath: string;
  metadata: WasmModuleMetadata;
  customShims?: Record<string, string>;
}

/**
 * Generate JS wrapper module for a wasm file.
 */
export function generateJsWrapper(options: CodegenOptions): string {
  const { wasmPath, metadata, customShims } = options;

  const shimCode = generateImportShims(metadata.imports, customShims);
  const importObject = generateImportObject(metadata.imports, customShims);

  const exportStatements: string[] = [];

  for (const exp of metadata.exports) {
    if (exp.kind === "function") {
      exportStatements.push(
        `export const ${safeIdentifier(exp.name)} = instance.exports[${JSON.stringify(exp.name)}];`,
      );
    } else if (exp.kind === "memory") {
      exportStatements.push(
        `export const ${safeIdentifier(exp.name)} = instance.exports[${JSON.stringify(exp.name)}];`,
      );
    } else if (exp.kind === "table") {
      exportStatements.push(
        `export const ${safeIdentifier(exp.name)} = instance.exports[${JSON.stringify(exp.name)}];`,
      );
    } else if (exp.kind === "global") {
      exportStatements.push(
        `export const ${safeIdentifier(exp.name)} = instance.exports[${JSON.stringify(exp.name)}];`,
      );
    }
  }

  return `${shimCode}
const wasmUrl = new URL(${JSON.stringify(wasmPath)}, import.meta.url);
const { instance } = await WebAssembly.instantiateStreaming(
  fetch(wasmUrl),
  ${importObject}
);
${exportStatements.join("\n")}
`;
}

/**
 * Generate .d.ts type definitions for a wasm module's exports.
 */
export function generateDts(metadata: WasmModuleMetadata): string {
  const lines: string[] = [];

  for (const exp of metadata.exports) {
    if (exp.kind === "function") {
      lines.push(generateFuncDts(metadata, exp));
    } else if (exp.kind === "memory") {
      lines.push(
        `export declare const ${safeIdentifier(exp.name)}: WebAssembly.Memory;`,
      );
    } else if (exp.kind === "table") {
      lines.push(
        `export declare const ${safeIdentifier(exp.name)}: WebAssembly.Table;`,
      );
    } else if (exp.kind === "global") {
      lines.push(
        `export declare const ${safeIdentifier(exp.name)}: WebAssembly.Global;`,
      );
    }
  }

  return lines.join("\n") + "\n";
}

function generateFuncDts(
  metadata: WasmModuleMetadata,
  exp: WasmExport,
): string {
  const funcType = getExportedFuncType(metadata, exp);
  if (!funcType) {
    return `export declare function ${safeIdentifier(exp.name)}(...args: unknown[]): unknown;`;
  }

  const params = funcType.params
    .map((p, i) => `a${i}: ${valTypeToTS(p)}`)
    .join(", ");

  const returnType =
    funcType.results.length === 0
      ? "void"
      : funcType.results.length === 1
        ? valTypeToTS(funcType.results[0])
        : `[${funcType.results.map(valTypeToTS).join(", ")}]`;

  return `export declare function ${safeIdentifier(exp.name)}(${params}): ${returnType};`;
}

const JS_RESERVED = new Set([
  "break", "case", "catch", "continue", "debugger", "default", "delete",
  "do", "else", "finally", "for", "function", "if", "in", "instanceof",
  "new", "return", "switch", "this", "throw", "try", "typeof", "var",
  "void", "while", "with", "class", "const", "enum", "export", "extends",
  "import", "super", "implements", "interface", "let", "package", "private",
  "protected", "public", "static", "yield",
]);

function safeIdentifier(name: string): string {
  if (JS_RESERVED.has(name)) return `_${name}`;
  if (!/^[a-zA-Z_$][a-zA-Z0-9_$]*$/.test(name)) return `_${name.replace(/[^a-zA-Z0-9_$]/g, "_")}`;
  return name;
}
