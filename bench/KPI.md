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

### wasm-opt gap 判定スコープ（固定）

- 主要 gap 判定:
  - 対象: `bench/corpus/core/binaryen/*.wasm` から `gc_target_feature.wasm` を除外
  - 理由: GC feature 由来の乖離が大きく、core size 主戦場の比較ノイズになるため
  - レポート: `latest.md` の `total_*` / `gap_to_wasm_opt_*` はこの主要スコープで集計
- 参考 gap（全件）:
  - 対象: core corpus 全件（`gc_target_feature.wasm` を含む）
  - レポート: `latest.md` の `reference_*` に併記し、トレンド監視に使う

### component-model DCE 専用（第一KPI）

- 指標: `size_reduction_ratio_component_dce_core_modules`
- 定義:
  - 対象: `bench/corpus/component-dce/**/*.wasm`
  - 実行: `component-dce-kpi`（closed-world root policy + core module DCE）
  - 算出: `(sum(core_before_bytes) - sum(core_after_bytes)) / sum(core_before_bytes)`
- 判定:
  - 値が大きいほど良い
  - 既存値からの悪化を回帰とみなす

### directize→DCE→RUME 連鎖可視化（第一KPI診断）

- 指標: `directize_dce_rume_chain_gain`
- 定義:
  - 対象: `bench/corpus/core/binaryen/*.wasm`
  - 実行:
    - pre-DCE: `optimize --strip-debug --strip-dwarf --strip-target-features --rounds=2`
    - post-DCE: 上記 + `--dce-apply --dfe-apply --msf-apply`
    - post-RUME: 上記 + `--rume-apply`
  - 算出:
    - `dce_gain_bytes = pre_dce_after_bytes - post_dce_after_bytes`
    - `rume_gain_bytes = post_dce_after_bytes - post_rume_after_bytes`
    - `total_gain_bytes = pre_dce_after_bytes - post_rume_after_bytes`
    - 併せて `directize_calls` を記録
- 備考:
  - `directize` 自体の書換件数と、その後段（DCE/RUME）で実サイズがどれだけ追加で落ちたかを追跡する
  - 主要KPI（`-O1` サイズ）とは別に、最適化連鎖の効き方を診断するための補助指標

### before/after 階層ヒートマップ（第一KPI診断）

- 指標: `hierarchical_before_after_heatmap`
- 定義:
  - 対象: `bench/corpus/core/binaryen/*.wasm`
  - 実行: `optimize -O1` の `before/after` を比較
  - 階層:
    - section: `module bytes` 差分
    - function: `profile code_body_bytes` 差分
    - block: `block-sizes total_instruction_bytes` 差分
  - 算出:
    - `*_gain_bytes = before - after`
    - `*_gain_ratio_pct = *_gain_bytes / before * 100`
    - `heat` は比率に応じた段階バー（`+.` ～ `+########`）

### pass waterfall（第一KPI診断）

- 指標: `pass_waterfall_gain`
- 定義:
  - 対象: `bench/corpus/core/binaryen/*.wasm`
  - ステージ順:
    - `strip`: `--strip-debug --strip-dwarf --strip-target-features --rounds=1 --no-peephole --no-vacuum --no-merge-blocks --no-remove-unused-brs`
    - `code`: `--strip-debug --strip-dwarf --strip-target-features --rounds=2`
    - `dce`: `code + --dce-apply --dfe-apply --msf-apply`
    - `rume`: `dce + --rume-apply`
  - 算出:
    - `strip_gain = before - strip_after`
    - `code_gain = strip_after - code_after`
    - `dce_gain = code_after - dce_after`
    - `rume_gain = dce_after - rume_after`
    - `total_gain = before - rume_after`

### no-change 理由ダッシュボード（第一KPI診断）

- 指標: `no_change_reason_dashboard`
- 定義:
  - 対象: `o1 / strip / code / dce / rume` 各ステージの `--verbose` 出力
  - 集計:
    - `no-change reasons:` の文言を抽出
    - stage + 正規化カテゴリ + 原文理由で件数化
    - サンプルファイル（最大3件）を併記
- 目的:
  - 「最適化できない理由」を定量化し、次の実装優先順位に直結させる

### zlib gap 詳細レポート（第一KPIアトリビューション）

- 指標: `zlib_gap_detail`
- 定義:
  - 対象: `bench/corpus/core/binaryen/zlib.wasm`
  - 比較: `before` / `walyze -O1` / `wasm-opt -Oz`
  - 出力:
    - module/code_body/block_instruction の要約比較
    - section 差分（before->walyze / before->wasm-opt）
    - top-functions / block-sizes のスナップショット
- 目的:
  - core corpus gap の支配要因（現状ほぼ zlib）を、関数/ブロック/section 単位で帰属する

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
- `bench/kpi/heatmap.tsv`: before/after 階層ヒートマップ（section/function/block）
- `bench/kpi/pass_waterfall.tsv`: pass waterfall の段階別差分
- `bench/kpi/directize_chain.tsv`: directize→DCE→RUME 連鎖の段階差分
- `bench/kpi/no_change_reasons.tsv`: no-change 理由ダッシュボードの生データ
- `bench/kpi/zlib_gap.md`: zlib 専用の gap 詳細レポート
- `bench/kpi/component_dce.tsv`: component-model DCE サイズKPIの明細
- `bench/kpi/runtime.tsv`: 速度KPIの明細
- `bench/kpi/bench.raw.log`: `moon bench` の生ログ
