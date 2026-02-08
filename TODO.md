# TODO (walyze)

完了済みの仕様は `docs/spec.md` に移動済み。

## KPI Snapshot (2026-02-08)

- core size KPI (`optimize -O1`, 主要 gap 判定 / `gc_target_feature.wasm` 除外): `171361 -> 70711 bytes` (`58.7357%`)
- wasm-opt 参考値 (`-Oz --all-features --strip-debug --strip-dwarf --strip-target-features`, 同スコープ): `171361 -> 66296 bytes` (`61.3121%`)
- gap to wasm-opt (主要): `4415 bytes` (`-2.5764pt`)
- gap to wasm-opt (参考: 全 core corpus): `4458 bytes` (`-2.6002pt`)
- component-model DCE KPI: `128170 -> 63916 bytes` (`50.1319%`)
- directize→DCE→RUME 診断: `success_files=8/8`, `dce_gain=1656 bytes`, `rume_gain=43 bytes`, `directize_calls_total=1`
- zlib gap 分解: `code=4353 bytes`, `function=45 bytes`, `type=37 bytes`

## Active Backlog

- [ ] P0: core corpus 合計 gap (`gap_to_wasm_opt_ratio_pct`) を段階的に縮小する
- [ ] P1: P2 `signature-refining/cfp` の拡張で DCE callgraph 精度を上げる（Top1）
- [ ] P1: P5 `precompute/optimize-instructions` を拡張して code gap を削る（Top2）
- [ ] P2: N5 GC hierarchy type-refining を導入して type/function 残差を潰す（Top3）

## Analyze 拡張方針 (2026-02-08)

- [x] A4 (P0): pass ごとの function 差分レポートを追加する（before/after を function index で対応付け、削減 bytes をランキング表示）
- [ ] A5 (P0): runtime profile をシナリオ化する（zero-arg 依存を減らし、引数付き export と複数ケース計測を追加）
- [x] A6 (P1): `walyze` vs `wasm-opt` の function 対応差分レポートを追加する（gap の支配関数を TopK で特定）
- [x] A7 (P1): `hot-size` の unresolved 理由を分類する（import 不足 / signature 不一致 / 実行時例外）
- [x] A8 (P1): analyze で得た示唆を TODO 優先度へ自動接続する（`migration_top3` と function 差分の統合スコア）
- [ ] Note: 知見と運用ルールは `docs/analyze.md` に集約する

## Recent Progress

- [x] P5: `inlining-optimizing` を拡張（identity/no-op callee を call-site で除去）し、zlib の DCE 連鎖を強化
- [x] Analyze: `runtime-profile` / `hot-size` を import 依存 wasm でも動作する stub import 生成に拡張
- [x] KPI: `collect_kpi.sh` の section parser を更新し、`zlib_gap.md` の section delta（code/function/type）を復旧
- [x] テスト追加: identity inlining / import 依存 runtime-profile / zlib runtime-profile の回帰テスト
- [x] Analyze: `analyze_host_generated_code` API と `analyze-host` CLI を追加（forwarding/sig-refine/directize候補/DCE除去余地を可視化）
- [x] Analyze: `analyze_optimize_metadata` API と `analyze-opt` CLI を追加（`strip -> code -> dce -> rume` 段階ウォーターフォール）
- [x] テスト追加: host-generated report / optimize metadata report の Red/Green カバレッジを追加
- [x] Analyze: `analyze_call_graph_summary` API を追加し、`analyze` CLI で到達/未到達関数と body bytes 要約を表示
- [x] テスト追加: callgraph summary の dead-function / indirect-call カバレッジを追加
- [x] P2/P5: forwarding thunk の終端パターン `call; return; end` を `cfp/cfp-const/signature-refine` で検出可能に拡張
- [x] テスト追加: `call+return` 形 thunk の `cfp/cfp-const/signature-refining` カバレッジを追加
- [x] P2/P5: forwarding thunk が `unused local` を持つ場合でも `cfp/cfp-const/signature-refine` を適用可能に拡張
- [x] テスト追加: `cfp/cfp-const/signature-refining` の `unused local` thunk ケースを追加
- [x] P5: `optimize-instructions` に const-first 形（`i32.const 0/-1; local/global.get; op`）の簡約を追加
- [x] テスト追加: `optimize-instructions simplifies const-first bitwise and cmp patterns`
- [x] Analyze: `analyze-opt` に pass 単位 function 差分（gain/regression, TopK）を追加
- [x] Analyze: `runtime-profile` / `hot-size` に unresolved 理由分類（import-missing / signature-mismatch / runtime-exception）を追加
- [x] Analyze: `function-gap` API/CLI と `bench/kpi/zlib_function_gap.tsv` を追加（walyze vs wasm-opt function TopK 差分）
- [x] KPI: `migration_top3` のスコアに function-gap 指標（`fn_gap_top` / `fn_gap_positive`）を統合
