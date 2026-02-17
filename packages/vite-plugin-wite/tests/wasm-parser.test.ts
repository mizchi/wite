import { describe, it, expect } from "vitest";
import { parseWasm, getExportedFuncType, valTypeToTS } from "../src/wasm-parser.js";

// Minimal wasm: (module (func (export "add") (param i32 i32) (result i32)))
const ADD_WASM = new Uint8Array([
  0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00,
  // Type section
  0x01, 0x07, 0x01, 0x60, 0x02, 0x7f, 0x7f, 0x01, 0x7f,
  // Function section
  0x03, 0x02, 0x01, 0x00,
  // Export section
  0x07, 0x07, 0x01, 0x03, 0x61, 0x64, 0x64, 0x00, 0x00,
  // Code section
  0x0a, 0x09, 0x01, 0x07, 0x00, 0x20, 0x00, 0x20, 0x01, 0x6a, 0x0b,
]);

describe("parseWasm", () => {
  it("parses a simple add module", () => {
    const result = parseWasm(ADD_WASM);
    expect(result.isComponent).toBe(false);
    expect(result.error).toBeUndefined();
    expect(result.types).toHaveLength(1);
    expect(result.types[0].params).toEqual(["i32", "i32"]);
    expect(result.types[0].results).toEqual(["i32"]);
    expect(result.exports).toHaveLength(1);
    expect(result.exports[0]).toEqual({
      name: "add",
      kind: "function",
      index: 0,
    });
    expect(result.functions).toEqual([0]);
    expect(result.imports).toHaveLength(0);
  });

  it("detects component model", () => {
    const componentBytes = new Uint8Array([
      0x00, 0x61, 0x73, 0x6d, 0x0d, 0x00, 0x01, 0x00,
    ]);
    const result = parseWasm(componentBytes);
    expect(result.isComponent).toBe(true);
  });

  it("returns error for invalid bytes", () => {
    const result = parseWasm(new Uint8Array([0x00, 0x00, 0x00, 0x00]));
    expect(result.error).toBeDefined();
  });
});

describe("getExportedFuncType", () => {
  it("resolves func type for exported function", () => {
    const metadata = parseWasm(ADD_WASM);
    const funcType = getExportedFuncType(metadata, metadata.exports[0]);
    expect(funcType).toBeDefined();
    expect(funcType!.params).toEqual(["i32", "i32"]);
    expect(funcType!.results).toEqual(["i32"]);
  });

  it("returns undefined for non-function exports", () => {
    const metadata = parseWasm(ADD_WASM);
    const result = getExportedFuncType(metadata, {
      name: "memory",
      kind: "memory",
      index: 0,
    });
    expect(result).toBeUndefined();
  });
});

describe("valTypeToTS", () => {
  it("maps wasm types to TypeScript", () => {
    expect(valTypeToTS("i32")).toBe("number");
    expect(valTypeToTS("i64")).toBe("bigint");
    expect(valTypeToTS("f32")).toBe("number");
    expect(valTypeToTS("f64")).toBe("number");
    expect(valTypeToTS("funcref")).toBe("Function");
    expect(valTypeToTS("externref")).toBe("any");
  });
});
