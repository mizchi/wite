# wite

`wite` is a MoonBit toolkit for WebAssembly binaries with a focus on component-model workflows.

## Positioning (wac + wite)

- `wac` (`mizchi/mwac`): WAC API / composition (bundler role)
- `wite`: wasm/component optimizer + profiler (minifier role)

責務分離の原則:

- `wac` は合成（依存解決・instantiate/export 計画）に集中する
- `wite` はバイナリ最適化・解析に集中する
- 依存方向は `wite -> wac` のみ（`wac -> wite` の直接依存は作らない）
- 連携は「`wac` が出力した wasm/component bytes を `wite` が後段で最適化する」形を基本とする

### wac/wite bytes I/O 契約

- 入力: `wac` の生成物（core wasm bytes / component wasm bytes）
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
- core wasm function-gap analysis (`wite` vs `wasm-opt` 等の 2 wasm 比較で TopK 差分)
- core wasm code-block size analysis (`function/block/loop/if` bytes + instruction counts)
- core wasm call graph + dead-body analysis (export/start roots)
- core wasm call graph roots from global/element `ref.func`
- retain-path analysis (root reason + shortest root-to-function chain)
- host/generated code analysis (forwarding-thunk/sig-refine/directize-candidate/dce-removable hints)
- optimize metadata analysis (`strip -> code -> dce -> rume` stage waterfall + pass-function diff TopK)
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
- runtime profiler for zero-arg exports (call count / total ns / avg ns + unresolved reason分類)
- hotness x size matrix analysis (runtime profile + code-body size buckets + unresolved reason集計)
- component model profiling (`mizchi/mwac` integration)
- component core-module top-function size reports
- component core-module call graph reports
- WIT contract gap analysis (`mizchi/wit` integration)
- component root-policy report (`component exports` + `WIT exports` + canonical ABI candidates)
- component fixed-point optimize（`component -> core optimize -> component`、`--converge` で反復）

## CLI

```bash
just run -- build path/to/entry.wac --out path/to/output.component.wasm -Oz
just run -- build path/to/module.wasm --out path/to/module.min.wasm -O2

just run -- analyze path/to/module.wasm --view=summary
just run -- analyze path/to/module.wasm --view=deep --limit=20
just run -- analyze path/to/module.wasm --view=pipeline --opt-level=Oz --diff-limit=20
just run -- analyze path/to/module.wasm --view=keep --closed-world --closed-world-root=run
just run -- analyze path/to/module.wasm --view=retain --limit=20 --closed-world --closed-world-root=run
just run -- analyze path/to/module.wasm --config=./wite.config.jsonc
just run -- build path/to/module.wasm --no-config -Oz
just run -- profile path/to/module.wasm --config=./wite.config.jsonc
just run -- diff path/to/module.wasm --baseline=wasm-opt --view=function --limit=20
just run -- diff path/to/module.wasm --baseline=wasm-opt --view=section --limit=20
just run -- diff left.wasm right.wasm --view=block --limit=20
just run -- add wkg:mizchi/markdown
just run -- add mizchi/markdown@0.1.0
just run -- add wasi:http@0.2.0 --name=http
just run -- add https://wa.dev/mizchi:tmgrammar@0.1.1 --name=tmg
just run -- add wkg:mizchi/markdown --registry=wasi.dev --name=md
just run -- add wasi:http@0.2.10 --registry=wasi.dev --verify
just run -- deps verify
just run -- deps verify --config=./wite.config.jsonc --fail-fast

# legacy low-level subcommands (still available)
just run -- analyze path/to/module.wasm
just run -- analyze-host path/to/module.wasm 20
just run -- analyze-opt path/to/module.wasm -O1 20
just run -- deep-analyze path/to/module.wasm 20
just run -- profile path/to/module.wasm
just run -- top-functions path/to/module.wasm 20
just run -- function-gap left.wasm right.wasm 20
just run -- block-sizes path/to/module.wasm 20
just run -- callgraph path/to/module.wasm 20
just run -- keep-reasons path/to/module.wasm --closed-world --closed-world-root=run
just run -- retain-path path/to/module.wasm 20 --closed-world --closed-world-root=run
just run -- dce-report path/to/module.wasm 20
just run -- runtime-profile path/to/module.wasm 100
just run -- hot-size path/to/module.wasm 100 20
just run -- optimize in.wasm out.wasm -Oz --strip-dwarf --strip-target-features --converge --rume-apply --verbose
just run -- component-profile path/to/component.wasm
just run -- component-top-functions path/to/component.wasm 20
just run -- component-callgraph path/to/component.wasm 20
just run -- component-dce-kpi path/to/component.wasm path/to/wit-dir --exclude=hello --verbose
just run -- contract path/to/component.wasm path/to/wit-dir
just run -- root-policy path/to/component.wasm path/to/wit-dir --exclude=hello
```

`optimize` は入力ヘッダから core/component を自動判定し、component では固定点ループ（`--converge` / `--rounds=<n>`）を適用します。
`runtime-profile` / `hot-size` は JS runtime が必要なため `--target js` でのみ動作し、`native/wasm` ではエラーを返します。
`build` / `analyze` / `profile` はカレントディレクトリの `wite.config.jsonc` を自動読込します（存在しない場合は無視）。
CLI マージ規則は「config の flags を先に適用し、CLI 引数で後勝ち上書き」です。`--no-config` で自動読込を無効化できます。
`diff --baseline=wasm-opt` は `wasm-opt`（または `--wasm-opt-bin` / `WASM_OPT_BIN`）を実行し、`function/section/block` の差分を直接表示します。
`add` は `wite.config.jsonc` の `deps` を更新し、`https://<registry>/<namespace>:<name>[@version]` を保存します。
`dep-spec` は `wkg:mizchi/markdown` / `mizchi/markdown` / `wasi:http` / `https://wa.dev/mizchi:tmgrammar@0.1.1` を受け付けます。
`--protocol` は入力形式のヒントとして扱い、保存形式は常に HTTPS URL です。
`--verify` を付けると `https://<host>/.well-known/wasm-pkg/registry.json` を解決し、`oci` backend では OCI API、`warg` backend では `wkg get --registry` を使って package/version 実在確認まで行います（`wkg` コマンドが必要）。
`deps verify` は `wite.config.jsonc` の `deps` 全件を同じ検証ロジックで再確認します。`--fail-fast` で最初の失敗で停止します。

```jsonc
{
  // build/analyze/profile は array 直書きか { "flags": [...] } の両方を許可
  "build": { "flags": ["-Oz", "--strip-debug", "--closed-world"] },
  "analyze": ["--view=deep", "--limit=30"],
  "profile": { "flags": [] },
  "deps": {
    "http": "https://wa.dev/wasi:http@0.2.0",
    "tmg": "https://wa.dev/mizchi:tmgrammar@0.1.1"
  }
}
```

連携例（bundler + minifier）:

```bash
# wac 側で component を生成
# (例) wac compose input.wac -> out.component.wasm

# wite 側で後段最適化
just run -- optimize out.component.wasm out.component.opt.wasm -Oz --converge
```

## Library API

Main APIs are in `src/lib.mbt`:

- `analyze_section_sizes(bytes)`
- `analyze_wasm_breakdown(bytes, top_limit=...)`
- `analyze_function_sizes(bytes)`
- `analyze_function_size_gap(left_bytes, right_bytes, top_limit=...)`
- `analyze_code_block_sizes(bytes)`
- `analyze_call_graph(bytes)`
- `analyze_call_graph_summary(bytes)`
- `analyze_host_generated_code(bytes)`
- `analyze_optimize_metadata(bytes, config=..., function_diff_limit=...)`
- `analyze_keep_reasons(bytes, config=...)`
- `analyze_retain_paths(bytes, config=...)`
- `analyze_dce_report(bytes)`
- `optimize_for_size(bytes, config=...)`
- `optimize_binary_for_size(bytes, config=..., exclude=[...])`
- `profile_module(bytes)`
- `profile_runtime_zero_arg_exports(bytes, iterations=...)`
- `analyze_hotness_size_matrix(bytes, iterations=...)`
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
- `core/pglite`: pglite 由来の core wasm サンプル（size KPI 拡張）
- `core-analyze/duckdb`: duckdb-wasm 由来の巨大 core wasm（analyze 専用）
- `component/wac`: wac 由来の component wasm サンプル
- `component-dce/mwac`: component-model DCE KPI 専用の component サンプル

同期定義は `bench/corpus/manifest.tsv` で、`just bench-sync` で commit 固定 + sha256 検証付きで再取得できます。

KPI 定義と計測手順は `bench/KPI.md` を参照してください。
