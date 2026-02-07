# KPI Policy

`walyze` の最適化評価は以下の優先順で行う。

1. サイズ縮小（第一KPI）
2. 実行速度（第二KPI）

## 第一KPI: サイズ縮小

- 指標: `size_reduction_ratio_o1_core_corpus`
- 定義:
  - 対象: `bench/corpus/core/binaryen/*.wasm`
  - 実行: `optimize -O1`
  - 算出: `(sum(before_bytes) - sum(after_bytes)) / sum(before_bytes)`
  - ファイル別: `size.tsv` に各 wasm の減衰率を記録
- 判定:
  - 値が大きいほど良い
  - 既存値からの悪化を回帰とみなす

### wasm-opt 参考値（比較用）

- 指標: `wasm_opt_reduction_ratio_oz_core_corpus`（参考）
- 定義:
  - 対象: `bench/corpus/core/binaryen/*.wasm`
  - 実行: `wasm-opt -Oz --all-features --strip-debug --strip-dwarf --strip-target-features`（`wasm-opt` 利用可能時）
  - 算出: `(sum(before_bytes) - sum(wasm_opt_after_bytes)) / sum(before_bytes)`
- 備考:
  - `size.tsv` と `latest.md` に `walyze` との差分（bytes / ratio）を併記
  - `wasm-opt` がない環境では `NA` として継続実行

### component-model DCE 専用（第一KPI）

- 指標: `size_reduction_ratio_component_dce_core_modules`
- 定義:
  - 対象: `bench/corpus/component-dce/**/*.wasm`
  - 実行: `component-dce-kpi`（closed-world root policy + core module DCE）
  - 算出: `(sum(core_before_bytes) - sum(core_after_bytes)) / sum(core_before_bytes)`
- 判定:
  - 値が大きいほど良い
  - 既存値からの悪化を回帰とみなす

## 第二KPI: 実行速度

- 指標: `moon_bench_mean`
- 定義:
  - 対象: `src/lib_bench.mbt` の `bench:` ケース
  - 実行: `moon bench --target js`
  - 算出: MoonBit bench の `mean` 値を記録
- 判定:
  - サイズKPIを維持した上で改善を狙う
  - サイズKPIと競合する場合はサイズを優先する

## 収集コマンド

```bash
just kpi
```

成果物:

- `bench/kpi/latest.md`: 人間向けサマリ
- `bench/kpi/size.tsv`: サイズKPIの明細（walyze + wasm-opt 参考値 + 差分）
- `bench/kpi/component_dce.tsv`: component-model DCE サイズKPIの明細
- `bench/kpi/runtime.tsv`: 速度KPIの明細
- `bench/kpi/bench.raw.log`: `moon bench` の生ログ
