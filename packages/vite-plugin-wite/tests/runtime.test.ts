import { describe, it, expect } from "vitest";
import { RUNTIME_MODULE_ID, RUNTIME_MODULE_CODE } from "../src/runtime.js";

describe("RUNTIME_MODULE_ID", () => {
  it("starts with null byte (virtual module)", () => {
    expect(RUNTIME_MODULE_ID).toBe("\0wite-runtime");
    expect(RUNTIME_MODULE_ID.startsWith("\0")).toBe(true);
  });
});

describe("RUNTIME_MODULE_CODE", () => {
  it("exports __witeGetInstance function", () => {
    expect(RUNTIME_MODULE_CODE).toContain("export function __witeGetInstance");
  });

  it("uses a Map for caching", () => {
    expect(RUNTIME_MODULE_CODE).toContain("new Map()");
  });

  it("calls WebAssembly.instantiateStreaming", () => {
    expect(RUNTIME_MODULE_CODE).toContain(
      "WebAssembly.instantiateStreaming(fetch(url), importObject)",
    );
  });

  it("caches by URL key", () => {
    expect(RUNTIME_MODULE_CODE).toContain("__cache.get(key)");
    expect(RUNTIME_MODULE_CODE).toContain("__cache.set(key,");
  });

  it("returns cached entry on second call", () => {
    // The code should get from cache first, only create if missing
    expect(RUNTIME_MODULE_CODE).toContain("if (!entry)");
  });
});
