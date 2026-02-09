# Benchmark Corpus

`wite` のベンチセット初期版。

- `core/binaryen`: Binaryen の core wasm テスト素材
- `core/pglite`: pglite の core wasm（size KPI 拡張ターゲット）
- `core-analyze/duckdb`: duckdb-wasm の巨大 core wasm（analyze 専用）
- `component/wac`: wac の component wasm テスト素材
- `component-dce/mwac`: component-model DCE KPI 専用の mwac component 素材
- `component-dce/wite-build-fixture`: `wite build` 結合テスト用の local fixture（`main.wac` + local deps）
- `core/binaryen/rume_gain_fixture.wasm`: `directize→DCE→RUME` 診断で `rume_gain_bytes` を観測するためのローカル fixture
- `core/binaryen/directize_gain_fixture.wasm`: `directize→DCE→RUME` 診断で `directize_calls_total` を観測するためのローカル fixture

## 同期

```bash
just bench-sync
```

`bench/corpus/manifest.tsv` にある commit/path/sha256 を使って再取得し、ハッシュ検証します。

`rume_gain_fixture.wasm` / `directize_gain_fixture.wasm` / `component-dce/wite-build-fixture` はローカル管理 fixture のため `bench-sync` では再取得しません。

## ライセンス

- Binaryen: Apache-2.0 (`https://github.com/WebAssembly/binaryen`)
- wac: Apache-2.0 (`https://github.com/bytecodealliance/wac`)
- pglite: Apache-2.0 (`https://github.com/electric-sql/pglite`)
- duckdb-wasm: MIT (`https://github.com/duckdb/duckdb-wasm`)
