# vite-plugin-wite

Vite plugin for importing `.wasm` files as ES modules with full TypeScript support.

## Features

- Import `.wasm` files directly from TypeScript/JavaScript
- Auto-generated `.d.ts` type definitions from wasm exports
- Component Model support (extracts core module automatically)
- Built-in shims for `spectest` and `wasi_snapshot_preview1` imports
- Custom import shims for arbitrary wasm host modules
- HMR support in dev mode
- Rollup asset emission in build mode

## Install

```bash
npm install vite-plugin-wite
```

## Usage

### vite.config.ts

```ts
import { defineConfig } from "vite";
import wite from "vite-plugin-wite";

export default defineConfig({
  plugins: [wite()],
  build: {
    target: "esnext",
  },
});
```

### Import wasm

```ts
import { add } from "./add.wasm";

console.log(add(1, 2)); // 3
```

The plugin parses the wasm binary, generates a JS wrapper that calls `WebAssembly.instantiateStreaming`, and re-exports all wasm exports as named ES module exports.

A `.d.ts` file is auto-generated next to the `.wasm` file:

```ts
// add.wasm.d.ts (auto-generated)
export declare function add(a0: number, a1: number): number;
export declare const memory: WebAssembly.Memory;
```

## Options

```ts
wite({
  // Custom import shims for wasm modules that require host imports.
  // Key: module name, Value: JS code string providing the import object.
  shims: {
    "my:host": `const __shim_my_host = { log: (x) => console.log(x) };`,
  },

  // Generate .d.ts files alongside .wasm files (default: true)
  dts: true,
});
```

## Component Model

When the plugin detects a Component Model wasm binary (magic bytes `\0asm\x0d\x00\x01\x00`), it automatically extracts the first embedded core module and uses that for instantiation.

This works for components with primitive types only (i32, i64, f32, f64). Components using string, list, or record types require canonical ABI adapters which are not yet supported.

## Built-in Shims

| Module | Description |
|---|---|
| `spectest` | MoonBit's `println` output via `print_char` |
| `wasi_snapshot_preview1` | Stub that returns 0 for all WASI calls |

For unknown import modules, a `Proxy` stub is generated that returns 0 for any call.

## License

MIT
