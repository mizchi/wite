# wite

[English](README.md) | [日本語](README.ja.md)

A WebAssembly build tool aiming to be a Component Model counterpart of Vite. Implemented in MoonBit.

Provides component dependency management and composition (WAC composition), optimization via DCE (Dead Code Elimination), analysis, profiling, and a dev server.

## Installation

Requires [MoonBit](https://www.moonbitlang.com/) toolchain.

```bash
# Install MoonBit (if not installed)
curl -fsSL https://cli.moonbitlang.com/install/unix.sh | bash

# Install wite CLI (~/.moon/bin/wite)
moon install mizchi/wite/cmd/wite

# Or install from source
git clone https://github.com/mizchi/wite.git
cd wite && just install
```

```bash
# As a library dependency
moon add mizchi/wite
```

## Quickstart

```bash
wite init                    # generate wite.config.jsonc + main.wac
wite new --moonbit           # + guest/moonbit/ scaffold
wite add wasi:http@0.2.0     # add dependency
wite build                   # compose & optimize => composed.wasm
```

See [Quick Start Guide](docs/quick-start.md) for a step-by-step walkthrough.

`wite new --rust` generates a `guest/rust/` cargo-component scaffold instead.

When no input is specified, `build` uses `main.wac` (or `main.wasm` as fallback).

## CLI Commands

### build

```bash
wite build path/to/entry.wac --out output.component.wasm -Oz
wite build path/to/module.wasm --out module.min.wasm -O2
wite build                   # implicit entry: main.wac | main.wasm
wite build -Oz               # flags only (implicit entry)
wite build hello.component.wasm --interface ./wit --world hello -o hello.checked.wasm
```

Auto-detects core/component from the input header. For components, applies fixed-point optimization with `--converge`.
When `--interface` is provided, `build` verifies the final component against the given WIT directory.
Use `--world` to choose a specific world name in that WIT package.

### dev

```bash
wite dev                       # start dev server on :8080
wite dev --port=3000           # custom port
wite dev --build-cmd="moon build --target wasm-gc --release"
```

Watches for file changes and auto-rebuilds with live reload via SSE. If `index.html` exists in the project, it serves that file; otherwise, it auto-generates an HTML page that loads the wasm module.

Access the debug UI (module analysis & profiling) at `http://localhost:8080/__wite/`.

> **Note**: Static site serving is still under development. Currently primarily useful as a wasm dev server.

### analyze

```bash
wite analyze module.wasm --view=summary
wite analyze module.wasm --view=deep --limit=20
wite analyze module.wasm --view=pipeline --opt-level=Oz --diff-limit=20
wite analyze module.wasm --view=keep --closed-world --closed-world-root=run
wite analyze module.wasm --view=retain --limit=20
wite analyze component.wasm --kind=component --view=summary
wite analyze interface component.wasm
wite analyze interface component.wasm ./wit --world hello --strict
```

Views: `summary`, `deep`, `pipeline`, `keep`, `retain` (core); `summary`, `functions`, `callgraph` (component).

### profile

```bash
wite profile module.wasm
wite profile component.wasm --kind=component
```

### diff

```bash
wite diff module.wasm --baseline=wasm-opt --view=function --limit=20
wite diff module.wasm --baseline=wasm-opt --view=section
wite diff left.wasm right.wasm --view=block --limit=20
```

### treeshake

```bash
wite treeshake app.wasm --exports=main,malloc,free
wite treeshake app.wasm --exports=run -o app.min.wasm -Oz
wite treeshake app.wasm --exports=main --verbose      # shows auto-protected exports
wite treeshake app.wasm --exports=main --no-protect   # disable auto-protection
```

Removes all code not reachable from the specified exports. Uses closed-world DCE with DFE and unused module element removal.

Well-known exports (`memory`, `__wasm_call_ctors`, `_start`, `cabi_realloc`, etc.) are automatically protected from removal. Use `--no-protect` to disable.

### add

```bash
wite add wkg:mizchi/markdown
wite add dep:a
wite add mizchi/markdown@0.1.0
wite add wasi:http@0.2.0 --name=http
wite add https://wa.dev/mizchi:tmgrammar@0.1.1 --name=tmg
wite add wasi:http@0.2.10 --registry=wasi.dev --verify
```

Updates `deps` in `wite.config.jsonc`. Use `--verify` to validate package existence via registry API.

### deps

```bash
wite deps verify                          # verify all deps
wite deps verify --fail-fast              # stop on first failure
wite deps sync                            # download deps locally
wite deps sync --dir=./deps --verify      # custom dir + verify
```

### init / new

```bash
wite init                    # generate wite.config.jsonc + main.wac
wite new --moonbit           # init + guest/moonbit/ scaffold
wite new --rust              # init + guest/rust/ scaffold
```

## Configuration

`build`, `analyze`, and `profile` auto-load `wite.config.jsonc` from the current directory. Use `--no-config` to disable.

```jsonc
{
  "build": { "kind": "auto", "flags": ["-Oz", "--strip-debug", "--closed-world"] },
  "analyze": { "kind": "core", "flags": ["--view=deep", "--limit=30"] },
  "profile": { "kind": "auto", "flags": [] },
  "deps": {
    "http": "https://wa.dev/wasi:http@0.2.0",
    "tmg": "https://wa.dev/mizchi:tmgrammar@0.1.1"
  }
}
```

Merge rule: config flags are applied first, then CLI arguments override (last wins). `--kind` priority: CLI > config > auto.

### Environments

Define per-environment build settings for multi-target deployments:

```jsonc
{
  "input": "app.wac",
  "environments": {
    "browser": { "output": "dist/browser", "optimize": "-Os", "runtime": "browser" },
    "edge": { "output": "dist/edge", "optimize": "-O1", "runtime": "workerd" },
    "standalone": { "output": "dist/standalone", "optimize": "-Oz", "runtime": "wasmtime" }
  }
}
```

```bash
wite build --env=browser     # build single environment
wite build --all-envs        # build all environments
```

### Chunks

Define per-chunk build steps that run before WAC composition:

```jsonc
{
  "chunks": {
    "guest": {
      "build": "moon build --target wasm -p guest",
      "output": "build/guest.core.wasm",
      "wit": "wit/guest.wit"
    },
    "auth": "deps/auth.wasm"
  },
  "input": "app.wac"
}
```

Chunks with a `wit` field are automatically componentized (`wasm-tools component embed` + `new`). Pre-built chunks (no `build` command) are verified to exist.

## Library API

Main APIs (`src/lib.mbt`):

- `analyze_section_sizes(bytes)` / `analyze_wasm_breakdown(bytes, top_limit=...)`
- `analyze_function_sizes(bytes)` / `analyze_code_block_sizes(bytes)`
- `analyze_call_graph(bytes)` / `analyze_host_generated_code(bytes)`
- `analyze_optimize_metadata(bytes, config=..., function_diff_limit=...)`
- `analyze_keep_reasons(bytes, config=...)` / `analyze_retain_paths(bytes, config=...)`
- `analyze_dce_report(bytes)`
- `optimize_for_size(bytes, config=...)` / `optimize_binary_for_size(bytes, config=..., exclude=[...])`
- `profile_module(bytes)` / `profile_runtime_zero_arg_exports(bytes, iterations=...)`
- `profile_component(bytes)` / `analyze_component_function_sizes(bytes)`
- `optimize_component_for_size(bytes, config=..., exclude=[...])`
- `analyze_component_root_policy(bytes, resolved_wit=..., exclude=[...])`

Subpackages: `@mizchi/wite/optimize`, `@mizchi/wite/bundle`, `@mizchi/wite/analyze`, `@mizchi/wite/component`, `@mizchi/wite/config`, `@mizchi/wite/deps`.

## Optimization Presets

| Preset | Description |
|--------|-------------|
| `-O0` | No optimization |
| `-O1` | Basic optimizations |
| `-O2` | Standard optimizations |
| `-O3` | Aggressive optimizations |
| `-Os` | Optimize for size |
| `-Oz` | Optimize aggressively for size |

Use `--converge` to repeat optimization until no further size reduction is achieved.

## Architecture

- **wac** (`mizchi/mwac`): WAC composition engine (bundler role — dependency resolution, instantiate/export planning)
- **wite**: Binary optimizer + profiler (minifier role — analysis, optimization, profiling)

Dependency direction: `wite -> wac` only. The pipeline is: wac produces wasm bytes, wite optimizes them.

## Vite Integration

A Vite plugin [`vite-plugin-wite`](./packages/vite-plugin-wite/) for directly importing `.wasm` files from existing Vite projects.

```bash
npm install vite-plugin-wite
```

```typescript
// vite.config.ts
import { defineConfig } from "vite";
import wite from "vite-plugin-wite";

export default defineConfig({
  plugins: [
    wite({
      dts: true,           // auto-generate .d.ts
      jco: "auto",         // auto-transpile Component Model via jco
      environments: {
        client: { runtime: "browser" },
        ssr: { runtime: "node", dts: false },
      },
    }),
  ],
  build: { target: "esnext" },
});
```

```typescript
// Main thread
import { add } from "./math.wasm";
console.log(add(1, 2)); // 3

// Web Worker (off-thread)
import { add } from "./math.wasm?wite-worker";
const result = await add(1, 2); // runs in Worker, returns Promise
```

Features:
- **4 runtime targets**: `browser` (fetch), `webworker` (?wite-worker), `workerd` (ESM import), `node` (Buffer)
- **HMR**: wasm changes update exports in-place without full page reload
- **Auto .d.ts**: generates type definitions from wasm function signatures
- **jco integration**: Component Model wasm auto-transpiled to ESM with full type marshaling
- **Per-environment config**: different shims/options per Vite environment (Vite 6+ Environment API)
- See [vite-plugin-wite README](./packages/vite-plugin-wite/README.md) for details

## Development

```bash
just               # check + test
just fmt           # format code
just check         # type check
just test          # run tests
just install       # install from registry
just install-local # install from local source
just bench         # run benchmark suite
just kpi           # collect KPI report
just run           # run CLI (src/cmd/wite)
just info          # generate .mbti
just release-check # fmt + info + check + test
```

Run CLI during development: `just run -- <command> [args...]`

Examples: `examples/minimal/` (`just example-minimal`), `examples/sample_app/` (`just example-sample-app`).

## License

Apache-2.0
