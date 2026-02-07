# walyze

`walyze` is a MoonBit toolkit for WebAssembly binaries with a focus on component-model workflows.

## Positioning (mwac + walyze)

- `mwac`: WAC API / composition (bundler role)
- `walyze`: wasm/component optimizer + profiler (minifier role)

責務分離の原則:

- `mwac` は合成（依存解決・instantiate/export 計画）に集中する
- `walyze` はバイナリ最適化・解析に集中する
- 依存方向は `walyze -> mwac` のみ（`mwac -> walyze` の直接依存は作らない）
- 連携は「`mwac` が出力した wasm/component bytes を `walyze` が後段で最適化する」形を基本とする

It provides:

- core wasm section-size analysis (`twiggy`-style breakdown by section)
- core wasm top-function size analysis (`twiggy top`-style by code body size)
- core wasm call graph + dead-body analysis (export/start roots)
- core wasm call graph roots from global/element `ref.func`
- core wasm DCE report + apply (callgraph-based function-level pruning)
- core wasm duplicate function elimination apply (body+type based index remap)
- core wasm merge-similar-functions apply (forwarding thunk merge + index remap)
- core wasm remove-unused-module-elements apply (unused local table/element pruning)
- core wasm type-refining base pass (duplicate function-type canonicalization)
- core wasm signature-pruning base pass (unused trailing param pruning + caller drop insertion)
- core wasm remove-unused-types base pass (function-type pruning + call_indirect type remap)
- core wasm precompute/simplify-locals/rse base pass (`i32.const+i32.const+i32.add` folding, `local.set+local.get -> local.tee`, `local.tee+drop -> local.set`, `local.tee+local.set(same) -> local.set`, `local.get/global.get/ref.func/ref.null + drop` elision, local simplification fixed-point rounds)
- custom section strip passes (`strip-debug` / `strip-dwarf` / `strip-target-features`)
- optimization level presets (`-O0/-O1/-O2/-O3/-Os/-Oz`, plus `--converge`)
- size-oriented optimization pass (`wasm-opt`-style custom section stripping + vacuum + merge-blocks + remove-unused-brs + peephole + DCE + DFE + MSF)
- closed-world root filtering (`--closed-world --closed-world-root=...`, with `--safe-mode` override)
- static module profiler (imports/exports/functions/code-body bytes)
- runtime profiler for zero-arg exports (call count / total ns / avg ns)
- component model profiling (`mizchi/mwac` integration)
- component core-module top-function size reports
- component core-module call graph reports
- WIT contract gap analysis (`mizchi/wit` integration)
- component root-policy report (`component exports` + `WIT exports` + canonical ABI candidates)

## CLI

```bash
just run -- analyze path/to/module.wasm
just run -- profile path/to/module.wasm
just run -- top-functions path/to/module.wasm 20
just run -- callgraph path/to/module.wasm 20
just run -- keep-reasons path/to/module.wasm --closed-world --closed-world-root=run
just run -- dce-report path/to/module.wasm 20
just run -- runtime-profile path/to/module.wasm 100
just run -- optimize in.wasm out.wasm -Oz --strip-dwarf --strip-target-features --converge --rume-apply
just run -- component-profile path/to/component.wasm
just run -- component-top-functions path/to/component.wasm 20
just run -- component-callgraph path/to/component.wasm 20
just run -- component-dce-kpi path/to/component.wasm path/to/wit-dir --exclude=hello
just run -- contract path/to/component.wasm path/to/wit-dir
just run -- root-policy path/to/component.wasm path/to/wit-dir --exclude=hello
```

連携例（bundler + minifier）:

```bash
# mwac 側で component を生成
# (例) mwac compose input.wac -> out.component.wasm

# walyze 側で後段最適化
just run -- optimize out.component.wasm out.component.opt.wasm -Oz --converge
```

## Library API

Main APIs are in `src/lib.mbt`:

- `analyze_section_sizes(bytes)`
- `analyze_function_sizes(bytes)`
- `analyze_call_graph(bytes)`
- `analyze_keep_reasons(bytes, config=...)`
- `analyze_dce_report(bytes)`
- `optimize_for_size(bytes, config=...)`
- `profile_module(bytes)`
- `profile_runtime_zero_arg_exports(bytes, iterations=...)`
- `profile_component(bytes)`
- `analyze_component_function_sizes(bytes)`
- `analyze_component_call_graphs(bytes)`
- `optimize_component_for_size(bytes, config=..., exclude=[...])`
- `analyze_component_core_optimize(bytes, config=..., exclude=[...])`
- `analyze_component_contract(bytes, resolved_wit)`
- `analyze_component_root_policy(bytes, resolved_wit=..., exclude=[...])`

## Development

```bash
just           # check + test
just fmt       # format code
just check     # type check
just test      # run tests
just bench     # run benchmark suite
just bench-sync # sync benchmark corpus fixtures from upstream
just kpi       # collect KPI report (size first, runtime second, includes optional wasm-opt reference)
just run       # run CLI (src/main)
just info      # generate .mbti
```

## Benchmark Corpus

`bench/corpus/` に外部由来 fixture を配置しています。

- `core/binaryen`: Binaryen 由来の core wasm サンプル
- `component/wac`: wac 由来の component wasm サンプル
- `component-dce/mwac`: component-model DCE KPI 専用の component サンプル

同期定義は `bench/corpus/manifest.tsv` で、`just bench-sync` で commit 固定 + sha256 検証付きで再取得できます。

KPI 定義と計測手順は `bench/KPI.md` を参照してください。
