# TODO (wite)

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
- [x] A5 (P0): runtime profile をシナリオ化する（zero-arg 依存を減らし、引数付き export と複数ケース計測を追加）
- [x] A6 (P1): `wite` vs `wasm-opt` の function 対応差分レポートを追加する（gap の支配関数を TopK で特定）
- [x] A7 (P1): `hot-size` の unresolved 理由を分類する（import 不足 / signature 不一致 / 実行時例外）
- [x] A8 (P1): analyze で得た示唆を TODO 優先度へ自動接続する（`migration_top3` と function 差分の統合スコア）
- [x] Note: 知見と運用ルールは `docs/analyze.md` に集約する

## Recent Progress

- [x] W1: `wite build` を追加し、`.wac` 入力（`mizchi/mwac` compose）と `.wasm` 入力の両方で optimize+emit を単一導線化
- [x] W2: `wite analyze --view` を追加し、`summary/deep/functions/blocks/callgraph/host/pipeline/dce/keep/retain` を統合
- [x] W3: `wite.config.jsonc` ローダーを追加し、`build/analyze/profile` の flags を `config -> CLI` 後勝ちでマージ
- [x] W4: `wite diff --baseline=wasm-opt` を追加し、`--view=function|section|block` で baseline 比較を統合
- [x] W5: `wite add` を追加し、`dep-spec`（`wkg:mizchi/markdown` など）を `wite.config.jsonc` の `deps`（HTTPS URL）へ upsert 可能にした
- [x] W6: `wite deps verify` を追加し、`wite.config.jsonc` の `deps` 全件を `.well-known` + backend 検証（oci/warg）で再確認可能にした
- [x] W7: `wite deps sync` を追加し、`wite.config.jsonc` の `deps` 全件を `deps/<name>/` へ実体化可能にした（`--dir` / `--verify` / `--fail-fast`）
- [x] W8: `build/analyze/profile` 実行時に config 内 `deps` を自動同期する導線を追加した（`deps sync --fail-fast`）
- [x] W9: root `wite.config.jsonc` テンプレートと `just deps-verify` / `just deps-sync` タスクを追加した
- [x] W10: `examples/minimal` の最小設定例と `just example-minimal` 実行タスクを追加した
- [x] W11: `build/analyze/profile` に `kind`（auto/core/component）を追加し、config/CLI で上書き可能にした
- [x] W12: `optimize` に `--kind`（auto/core/component）を追加し、core/component 経路を明示指定可能にした
- [x] テスト追加: `parse_diff_view` / `parse_diff_baseline` の回帰テスト
- [x] テスト追加: `parse_wite_config_text` / `parse_config_selection_flags` / `merge_command_flags` の回帰テスト
- [x] テスト追加: `should_auto_sync_deps` / `build_auto_sync_deps_command_args` の回帰テスト
- [x] テスト追加: `parse_binary_kind` / `analyze_view_supports_kind` / config `kind` パースの回帰テスト
- [x] テスト追加: `extract_binary_kind_flags`（`--kind=<v>` / `--kind <v>`）の回帰テスト
- [x] テスト追加: `parse_wasm_dependency_spec` / `parse_dependency_protocol` / `parse_add_command_options` / `upsert_wasm_dependency_config_json` の回帰テスト
- [x] テスト追加: `parse_deps_sync_command_options` / `build_dep_sync_target_dir` の回帰テスト
- [x] テスト追加: `parse_analyze_view` / `derive_build_output_path` / `normalize_opt_level_token` の回帰テスト
- [x] CLI: `wite new --moonbit|--rust` を追加し、guest テンプレート（MoonBit / cargo-component）を生成可能にした
- [x] 統合テスト追加: `wite new --moonbit` 生成物を `moon build` で build できることを検証
- [x] 統合テスト追加: `wite new --rust` 生成物を `cargo component build`（環境不足時は既知エラー判定 + `cargo build` fallback）で検証
- [x] CLI: `wite optimize` に `wasm-opt` 互換フラグ（`--optimize-level` / `--shrink-level` / pass alias / feature flags）を追加し、単体最適化の直接導線を強化した
- [x] モジュール分割: `src/optimize`（最適化実行 API）/ `src/bundle`（WAC compose・依存解析 API）を追加し、`main` から利用する構成へ整理した
- [x] モジュール分割: `src/analyze`（解析実行 API）/ `src/component`（component 操作 API）/ `src/config`（config 解決 API）/ `src/deps`（依存解決 API）を追加し、`main` から利用する構成へ整理した
- [x] 統合テスト追加: `bench/corpus/component-dce/wite-build-fixture`（`main.wac` + local deps）で `build` を実行し、implicit (`main.wac` + `composed.wasm`) と explicit (`-o explicit.wasm`) の出力同値性と export (`greet`) を検証
- [x] 統合テスト追加: `bench/corpus/component-dce/wite-build-fixture` を壊した失敗系（依存 wasm 欠落 / `main.wac` 構文不正）で compose が失敗することを検証
- [x] Perf: `analyze_call_graph` / `analyze_call_graph_summary` を body 直走査 (`collect_direct_callees_from_body_raise`) + bitmap visited に置換し、`parse_instruction_spans` 依存を除去
- [x] Bench: `moon bench` 内部 driver 計測で `analyze summary` が改善（`pglite mean: 110527us -> 73258us`, `duckdb mean: 801982us -> 546504us`）
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
- [x] Analyze: `runtime-profile` に scenario 入力を追加（`--scenario=<export>[:arg1,arg2,...]`）し、引数付き export の複数ケース計測を可能にした
- [x] Analyze: `hot-size` に scenario 入力を連携（`--scenario=<export>[:arg1,arg2,...]`）し、引数付き export の size 分類を可能にした
- [x] Analyze: `function-gap` API/CLI と `bench/kpi/zlib_function_gap.tsv` を追加（wite vs wasm-opt function TopK 差分）
- [x] KPI: `migration_top3` のスコアに function-gap 指標（`fn_gap_top` / `fn_gap_positive`）を統合
- [x] Perf: `analyze_call_graph_summary` を full callgraph 構築から分離し、summary 専用経路を追加（巨大 wasm の `analyze` 実行時間/メモリを削減）
- [x] Perf: export index 抽出で name 文字列デコードを回避（`skip_name_string`）し、重複排除を `seen` map で O(n) 化
- [x] Perf: `optimize_for_size` の fixed-point 反復で「サイズ回帰ラウンド」を早期終了し、巨大 wasm の O1 実行時間を削減
- [x] Bench: `pglite/duckdb` を `moon bench` に追加し、`analyze summary` / `optimize -O1` の速度を継続観測可能にした
- [x] P2/P1: `cfp/cfp-const/signature-refining` の型互換判定を GC canonical map ベースへ拡張し、type index 不一致（同値シグネチャ）でも forwarding を検出可能にした
