# wite

[English](README.md) | [日本語](README.ja.md)

Component-model-aware WebAssembly analyzer, optimizer, and profiler for [MoonBit](https://docs.moonbitlang.com).

## Installation

```bash
# As a library
moon add mizchi/wite

# CLI (from source)
just run -- <command> [args...]
```

## Quickstart

```bash
wite init                    # generate wite.config.jsonc + main.wac
wite new --moonbit           # + guest/moonbit/ scaffold
wite add wasi:http@0.2.0     # add dependency
wite build                   # compose & optimize => composed.wasm
```

`wite new --rust` generates a `guest/rust/` cargo-component scaffold instead.

When no input is specified, `build` uses `main.wac` (or `main.wasm` as fallback).

## CLI Commands

### build

```bash
wite build path/to/entry.wac --out output.component.wasm -Oz
wite build path/to/module.wasm --out module.min.wasm -O2
wite build                   # implicit entry: main.wac | main.wasm
wite build -Oz               # flags only (implicit entry)
```

Auto-detects core/component from the input header. For components, applies fixed-point optimization with `--converge`.

### analyze

```bash
wite analyze module.wasm --view=summary
wite analyze module.wasm --view=deep --limit=20
wite analyze module.wasm --view=pipeline --opt-level=Oz --diff-limit=20
wite analyze module.wasm --view=keep --closed-world --closed-world-root=run
wite analyze module.wasm --view=retain --limit=20
wite analyze component.wasm --kind=component --view=summary
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

## Development

```bash
just               # check + test
just fmt           # format code
just check         # type check
just test          # run tests
just bench         # run benchmark suite
just kpi           # collect KPI report
just run           # run CLI (src/main)
just info          # generate .mbti
just release-check # fmt + info + check + test
```

Run CLI during development: `just run -- <command> [args...]`

Examples: `examples/minimal/` (`just example-minimal`), `examples/sample_app/` (`just example-sample-app`).

## License

Apache-2.0
