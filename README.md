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

### mwac/walyze bytes I/O 契約

- 入力: `mwac` の生成物（core wasm bytes / component wasm bytes）
- 出力: 最適化済み bytes（同じバイナリ種別を維持）
- 不変条件:
  - decode/encode 可能な wasm 形式を維持する
  - `--safe-mode` または closed-world policy に従って root 保持を行う
  - `exclude=[...]` で指定した root 候補は keep 対象に追加する
- API 契約:
  - core: `optimize_for_size(bytes, config=...)`
  - component: `optimize_component_for_size(bytes, config=..., exclude=[...])`
  - core/component 自動判定: `optimize_binary_for_size(bytes, config=..., exclude=[...])`
  - plan 非依存 config 組み立て: `make_component_optimize_config(base=..., root_name_candidates=[...], exclude=[...])`
  - root-policy 診断: `analyze_component_root_policy(bytes, resolved_wit=..., exclude=[...])`
  - core 内訳診断: `analyze_component_core_optimize(bytes, config=..., exclude=[...])`

It provides:

- core wasm section-size analysis (`twiggy`-style breakdown by section)
- core wasm deep breakdown analysis (sections/custom-sections/functions/blocks/opcodes/callgraph in one report)
- core wasm top-function size analysis (`twiggy top`-style by code body size)
- core wasm code-block size analysis (`function/block/loop/if` bytes + instruction counts)
- core wasm call graph + dead-body analysis (export/start roots)
- core wasm call graph roots from global/element `ref.func`
- host/generated code analysis (forwarding-thunk/sig-refine/directize-candidate/dce-removable hints)
- optimize metadata analysis (`strip -> code -> dce -> rume` stage waterfall for optimizer input)
- core wasm DCE report + apply (callgraph-based function-level pruning)
- core wasm duplicate function elimination apply (body+type based index remap)
- core wasm merge-similar-functions apply (forwarding thunk merge + index remap)
- core wasm remove-unused-module-elements apply (unused local table/element pruning)
- core wasm directize base pass (safe `i32.const + call_indirect -> call` rewrite under static table constraints)
- core wasm cfp pass (`call thunk -> call target`, including param-forwarding thunk patterns)
- core wasm type-refining base pass (duplicate function-type canonicalization)
- core wasm signature-pruning base pass (unused trailing param pruning + caller drop insertion)
- core wasm inlining-optimizing base pass (trivial `() -> i32.const` callee inline)
- core wasm dae-optimizing base pass (drop される純粋式の簡約)
- core wasm remove-unused-types base pass (function-type pruning + call_indirect type remap + private GC type dependency-aware pruning)
- core wasm optimize-instructions/precompute/simplify-locals/rse/coalesce-locals base pass (`i32.const+i32.const+i32.add` folding, `i32.const+i32.eqz` folding, `i32.eqz+i32.eqz+br_if` simplification, i32 rhs identity elimination (`+0`, `-0`, `|0`, `^0`, `<<0`, ...), bitwise/cmp simplification around const operands (`x&0 -> 0`, `x&-1 -> x`, `x==0 -> eqz`, `x<u0 -> 0`, `x>=u0 -> 1`, ...), same-local simplification (`x^x -> 0`, `x-x -> 0`, `x==x -> 1`, `x|x -> x`, ...), straight-line local const propagation, `local.set+local.get -> local.tee`, `local.tee+drop -> local.set`, `local.tee+local.set(same) -> local.set`, `local.get/global.get/ref.func/ref.null/memory.size/table.size + drop` elision, local simplification fixed-point rounds, unused local elimination + local index compaction)
- custom section strip passes (`strip-debug` / `strip-dwarf` / `strip-target-features`)
- optimization level presets (`-O0/-O1/-O2/-O3/-Os/-Oz`, plus `--converge`)
- size-oriented optimization pass (`wasm-opt`-style custom section stripping + vacuum + merge-blocks + remove-unused-brs + peephole + DCE + DFE + MSF + best-effort RUME)
- closed-world root filtering (`--closed-world --closed-world-root=...`, with `--safe-mode` override)
- static module profiler (imports/exports/functions/code-body bytes)
- runtime profiler for zero-arg exports (call count / total ns / avg ns)
- component model profiling (`mizchi/mwac` integration)
- component core-module top-function size reports
- component core-module call graph reports
- WIT contract gap analysis (`mizchi/wit` integration)
- component root-policy report (`component exports` + `WIT exports` + canonical ABI candidates)
- component fixed-point optimize（`component -> core optimize -> component`、`--converge` で反復）

## CLI

```bash
just run -- analyze path/to/module.wasm
just run -- analyze-host path/to/module.wasm 20
just run -- analyze-opt path/to/module.wasm -O1
just run -- deep-analyze path/to/module.wasm 20
just run -- profile path/to/module.wasm
just run -- top-functions path/to/module.wasm 20
just run -- block-sizes path/to/module.wasm 20
just run -- callgraph path/to/module.wasm 20
just run -- keep-reasons path/to/module.wasm --closed-world --closed-world-root=run
just run -- dce-report path/to/module.wasm 20
just run -- runtime-profile path/to/module.wasm 100
just run -- optimize in.wasm out.wasm -Oz --strip-dwarf --strip-target-features --converge --rume-apply --verbose
just run -- component-profile path/to/component.wasm
just run -- component-top-functions path/to/component.wasm 20
just run -- component-callgraph path/to/component.wasm 20
just run -- component-dce-kpi path/to/component.wasm path/to/wit-dir --exclude=hello --verbose
just run -- contract path/to/component.wasm path/to/wit-dir
just run -- root-policy path/to/component.wasm path/to/wit-dir --exclude=hello
```

`optimize` は入力ヘッダから core/component を自動判定し、component では固定点ループ（`--converge` / `--rounds=<n>`）を適用します。

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
- `analyze_wasm_breakdown(bytes, top_limit=...)`
- `analyze_function_sizes(bytes)`
- `analyze_code_block_sizes(bytes)`
- `analyze_call_graph(bytes)`
- `analyze_call_graph_summary(bytes)`
- `analyze_host_generated_code(bytes)`
- `analyze_optimize_metadata(bytes, config=...)`
- `analyze_keep_reasons(bytes, config=...)`
- `analyze_dce_report(bytes)`
- `optimize_for_size(bytes, config=...)`
- `optimize_binary_for_size(bytes, config=..., exclude=[...])`
- `profile_module(bytes)`
- `profile_runtime_zero_arg_exports(bytes, iterations=...)`
- `profile_component(bytes)`
- `analyze_component_function_sizes(bytes)`
- `analyze_component_call_graphs(bytes)`
- `make_component_optimize_config(base=..., root_name_candidates=[...], exclude=[...])`
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
just kpi       # collect KPI report (size first, runtime second, wasm-opt ref + heatmap/waterfall/no-change diagnostics)
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
