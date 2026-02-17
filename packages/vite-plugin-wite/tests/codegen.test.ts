import { describe, it, expect } from "vitest";
import { generateJsWrapper, generateDts } from "../src/codegen.js";
import { parseWasm } from "../src/wasm-parser.js";

// Minimal wasm: (module (func (export "add") (param i32 i32) (result i32)))
const ADD_WASM = new Uint8Array([
  0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00,
  0x01, 0x07, 0x01, 0x60, 0x02, 0x7f, 0x7f, 0x01, 0x7f,
  0x03, 0x02, 0x01, 0x00,
  0x07, 0x07, 0x01, 0x03, 0x61, 0x64, 0x64, 0x00, 0x00,
  0x0a, 0x09, 0x01, 0x07, 0x00, 0x20, 0x00, 0x20, 0x01, 0x6a, 0x0b,
]);

describe("generateDts", () => {
  it("generates correct type definitions for add function", () => {
    const metadata = parseWasm(ADD_WASM);
    const dts = generateDts(metadata);
    expect(dts).toContain(
      "export declare function add(a0: number, a1: number): number;",
    );
  });

  it("generates bigint for i64 return type", () => {
    const metadata = {
      isComponent: false,
      types: [{ params: ["i32" as const], results: ["i64" as const] }],
      imports: [],
      exports: [{ name: "get_big", kind: "function" as const, index: 0 }],
      functions: [0],
    };
    const dts = generateDts(metadata);
    expect(dts).toContain(
      "export declare function get_big(a0: number): bigint;",
    );
  });

  it("generates void for no return value", () => {
    const metadata = {
      isComponent: false,
      types: [{ params: ["i32" as const], results: [] }],
      imports: [],
      exports: [{ name: "print", kind: "function" as const, index: 0 }],
      functions: [0],
    };
    const dts = generateDts(metadata);
    expect(dts).toContain(
      "export declare function print(a0: number): void;",
    );
  });

  it("generates memory export", () => {
    const metadata = {
      isComponent: false,
      types: [],
      imports: [],
      exports: [{ name: "memory", kind: "memory" as const, index: 0 }],
      functions: [],
    };
    const dts = generateDts(metadata);
    expect(dts).toContain(
      "export declare const memory: WebAssembly.Memory;",
    );
  });
});

describe("generateJsWrapper", () => {
  it("generates wrapper with no imports", () => {
    const metadata = parseWasm(ADD_WASM);
    const code = generateJsWrapper({
      wasmPath: "./test.wasm",
      metadata,
    });
    expect(code).toContain("WebAssembly.instantiateStreaming");
    expect(code).toContain("instance.exports");
    expect(code).toContain("./test.wasm");
  });

  it("generates spectest shim when needed", () => {
    const metadata = {
      isComponent: false,
      types: [{ params: ["i32" as const], results: [] }],
      imports: [
        {
          module: "spectest",
          name: "print_char",
          kind: "function" as const,
          typeIndex: 0,
        },
      ],
      exports: [{ name: "run", kind: "function" as const, index: 1 }],
      functions: [0],
    };
    const code = generateJsWrapper({
      wasmPath: "./test.wasm",
      metadata,
    });
    expect(code).toContain("print_char");
    expect(code).toContain("__spectest");
  });
});
