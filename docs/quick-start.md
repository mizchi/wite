# Quick Start

This guide walks through composing two WebAssembly components into one using wite.

## Prerequisites

- [MoonBit](https://www.moonbitlang.com/) toolchain
- [wasm-tools](https://github.com/bytecodealliance/wasm-tools) (for building WAT sources)

```bash
# Install MoonBit
curl -fsSL https://cli.moonbitlang.com/install/unix.sh | bash

# Install wite CLI
moon install mizchi/wite/cmd/wite

# Install wasm-tools (via cargo)
cargo install wasm-tools
```

## 1. Create project structure

```bash
mkdir my-wasm-app && cd my-wasm-app
```

Create two guest components as WAT files:

**src/add.wat** — a component that exports an `add` function:

```wat
(component
  (core module $m
    (func $add (param i32 i32) (result i32)
      local.get 0
      local.get 1
      i32.add
    )
    (export "add" (func $add))
  )
  (core instance $i (instantiate $m))
  (func (export "add") (param "a" s32) (param "b" s32) (result s32)
    (canon lift (core func $i "add"))
  )
)
```

**src/mul.wat** — a component that exports a `mul` function:

```wat
(component
  (core module $m
    (func $mul (param i32 i32) (result i32)
      local.get 0
      local.get 1
      i32.mul
    )
    (export "mul" (func $mul))
  )
  (core instance $i (instantiate $m))
  (func (export "mul") (param "a" s32) (param "b" s32) (result s32)
    (canon lift (core func $i "mul"))
  )
)
```

## 2. Build guest components

Convert WAT to wasm and place them in `deps/`:

```bash
mkdir -p deps/example
wasm-tools parse src/add.wat -o deps/example/add.wasm
wasm-tools parse src/mul.wat -o deps/example/mul.wasm
```

## 3. Write composition definition

**main.wac** — compose the two components into one:

```wac
package example:app;

let add = new example:add {};
let mul = new example:mul {};

export add.add;
export mul.mul;
```

This instantiates both components and re-exports their functions.

## 4. Add build config

**wite.config.jsonc**:

```jsonc
{
  "build": { "kind": "component", "flags": ["-Oz"] }
}
```

## 5. Build

```bash
wite build main.wac -o composed.wasm
```

This composes the components via WAC and optimizes the output with DCE.

## 6. Verify

```bash
# Print the composed component as WAT
wasm-tools print composed.wasm

# Analyze structure
wite analyze composed.wasm --kind=component --view=summary
```

## Next steps

- Use `wite new --moonbit` to scaffold a MoonBit guest component
- Use `wite new --rust` to scaffold a Rust (cargo-component) guest
- Use `wite add wasi:http@0.2.0` to add registry dependencies
- Use `wite dev` to start a dev server with live reload
- See [examples/](../examples/) for more patterns
