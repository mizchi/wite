import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { describe, it, expect } from "vitest";
import { lowerComponent } from "../src/component.js";
import { parseWasm } from "../src/wasm-parser.js";

const MATH_COMPONENT_PATH = resolve(
  __dirname,
  "../../../examples/vite-plugin-multi/src/math.wasm",
);

const ADD_CORE_PATH = resolve(
  __dirname,
  "../../../examples/vite-plugin/src/add.wasm",
);

describe("lowerComponent", () => {
  it("extracts core module from component wasm", () => {
    const bytes = new Uint8Array(readFileSync(MATH_COMPONENT_PATH));
    const metadata = parseWasm(bytes);
    expect(metadata.isComponent).toBe(true);

    const lowered = lowerComponent(bytes);
    expect(lowered).not.toBeNull();
    expect(lowered!.length).toBeGreaterThan(8);

    // Verify it's a valid core module
    const coreMetadata = parseWasm(lowered!);
    expect(coreMetadata.isComponent).toBe(false);
    expect(coreMetadata.error).toBeUndefined();
    expect(coreMetadata.exports.map((e) => e.name)).toContain("add");
    expect(coreMetadata.exports.map((e) => e.name)).toContain("mul");
  });

  it("returns null for core module (not a component)", () => {
    const bytes = new Uint8Array(readFileSync(ADD_CORE_PATH));
    const result = lowerComponent(bytes);
    expect(result).toBeNull();
  });

  it("returns null for invalid bytes", () => {
    const result = lowerComponent(new Uint8Array([0x00, 0x00, 0x00, 0x00]));
    expect(result).toBeNull();
  });
});
