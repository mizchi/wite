import { extract_first_core_module } from "./generated/wasm-parser.js";

/**
 * Extract the first core module from a component model wasm binary.
 * Returns the core module bytes, or null if extraction fails.
 */
export function lowerComponent(bytes: Uint8Array): Uint8Array | null {
  const result = extract_first_core_module(bytes);
  return result.length > 0 ? result : null;
}
