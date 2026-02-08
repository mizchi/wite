# TODO (walyze)

## KPI Snapshot (2026-02-07)

- core size KPI (`optimize -O1`, 主要 gap 判定 / `gc_target_feature.wasm` 除外): `171361 -> 70794 bytes` (`58.6872%`)
- wasm-opt 参考値 (`-Oz --all-features --strip-debug --strip-dwarf --strip-target-features`, 同スコープ): `171361 -> 66296 bytes` (`61.3121%`)
- gap to wasm-opt (主要): `4498 bytes` (`-2.6249pt`)
- gap to wasm-opt (参考: 全 core corpus): `4541 bytes` (`-2.6486pt`)
- component-model DCE KPI: `128170 -> 64046 bytes` (`50.0304%`)
- directize→DCE→RUME 診断: `success_files=7/8`, `dce_gain=1620 bytes`, `rume_gain=26 bytes`, `directize_calls_total=1`

上記より、当面は **core size の wasm-opt ギャップ解消** を最優先にしつつ、差別化軸である **closed-world + GC 最適化** を次優先で進める。

## Next Up (2026-02-08)

- [x] P2 (P1): `cfp` phase1（forward call 伝播）を導入し、DCE の callgraph 精度を上げる
- [x] P5 (P1): `precompute` を拡張（`eqz(eqz(x))+br_if`）して code セクション gap を削る
- [x] P2 (P1): `cfp` phase2（param-forwarding thunk 伝播）を導入し、DCE の callgraph 精度を上げる
- [x] P2 (P1): `signature-refining` phase3 を導入し、closed-world/GC 文脈の callgraph 精度を上げる
- [x] N5 (P2): GC hierarchy を考慮した `type-refining` に着手し、closed-world と組み合わせた差分を測る
- [x] N8 (P1): `remove-unused-module-elements` と index rewrite の境界テストを拡充する
- [x] N9 (Guardrails): `mwac` 連携点の bytes I/O 契約（入出力）を文書化する

## Analysis Next (2026-02-08)

- [x] A1: `zlib.wasm` 専用の gap 詳細レポートを追加し、`before/walyze/wasm-opt` の差分を section/function/block で見える化する
- [x] A2: no-change 理由を「実装対象 / 非対象」に分類し、優先度と工数見積もりを TODO に接続する（`bench/kpi/no_change_triage.tsv`）
- [x] A3: pass waterfall の寄与をもとに、`code` / `dce` の追加移植候補を Top3 に絞る（`bench/kpi/migration_top3.md`）

## Performance Review (2026-02-08)

- 対象: `deep-analyze` の性能レビュー（`section/custom/function/block/opcode/callgraph` 統合レポート）
- 計測サンプル:
  - `duckdb-mvp.wasm` (`39,362,651 bytes`)
  - `function_count=62,171`, `block_count=618,122`
- 実測（ローカル）:
  - `analyze`: `0.03s`
  - `top-functions`: `0.28s`
  - `block-sizes`: `1.08s`
  - `callgraph`: `1.68s`
  - `deep-analyze`: `4.13s`（条件により `~6.14s`）、`max RSS ~1.16GB`（条件により `~1.93GB`）
- 主要ボトルネック:
  - `deep-analyze` が `analyze_function_sizes` / `analyze_code_block_sizes` / `analyze_call_graph` / opcode集計で同一 wasm を多重走査している
  - `deep-analyze` では summary だけ欲しい箇所でも callgraph `nodes` 全量を構築している
  - top-N 表示でも関数/ブロックを全件保持・全件ソートしている
  - opcode 集計で命令ごとに key/mnemonic 文字列生成と `0xfc/0xfd` immediate decode を繰り返している
  - roots/callees dedup が `Array.contains` ベースで、件数増で悪化しやすい
- 改善結果（2026-02-08, `duckdb-mvp.wasm`, `deep-analyze ... 20`）:
  - 実行時間: `4.13s -> 1.34s`
  - 最大RSS: `~1.16GB -> ~640MB`

### Perf TODO (priority)

- [x] PR1 (P0): `analyze_wasm_breakdown` を単一パイプライン化し、section/code 走査を 1 回に統合する
- [x] PR2 (P0): `deep-analyze` 用に lightweight callgraph summary API（`nodes` なし）を追加する
- [x] PR3 (P0): top-k 収集を API レベルで導入し、全件ソートをやめる（`limit` 連携）
- [x] PR4 (P1): opcode 集計を数値キー中心に変更し、文字列化を最終出力時に遅延する（非-prefixed 命令）
- [x] PR5 (P1): roots/callees dedup を `Map/Set` ベースへ置換する（`contains` 依存を削減）
- [x] PR6 (Bug): `deep-analyze` の `%` 表示オーバーフローを修正する（`numerator * 10000` 回避）

## Architecture Guardrails（mwac / walyze）

- [x] 役割を bundler (`mwac`) / minifier (`walyze`) として整理する
- [x] 依存方向を `walyze -> mwac` に固定する（`mwac -> walyze` 依存を禁止）
- [x] `mwac` 連携点は bytes I/O 契約（生成物の入出力）として定義する
- [ ] `walyze` 側の component 最適化 API を「WAC計画型非依存」で拡張する
- [ ] 固定点最適化は `component bytes -> core module optimize -> component bytes` の形で設計する

## P0: Core Size ギャップ解消（最優先）

- [ ] core corpus 合計 gap (`gap_to_wasm_opt_ratio_pct`) を段階的に縮小する
- [x] `zlib.wasm` 向けに `precompute` / `local-cse` の優先実装を進める（基盤実装まで完了）
- [x] `zlib.wasm` 向け `optimize-instructions` を優先実装する（基盤実装まで完了）
- [x] `zlib.wasm` 向け `optimize-instructions` を拡張する（bitwise/cmp の追加簡約）
- [x] 小型 fixture（`br_to_exit`, `elided-br`, `complexBinaryNames`）での pass 適用漏れを潰す
- [x] `gc_target_feature.wasm` の `wasm-opt` 比較注記を KPI に反映する
- [x] `gc_target_feature.wasm` は主要 gap 判定から除外し、参考値（`reference_*`）として併記する方針に固定する
- [x] `zlib.wasm` の gap を専用レポート（`bench/kpi/zlib_gap.md`）で継続観測する

## P1: Closed-World 基盤

- [x] `closed_world` 最適化モードを `OptimizeConfig` / CLI に追加する
- [x] component 由来の root policy を定義する（WIT/export/canonical ABI）
- [x] root policy を core DCE / RUME に接続し、root 一貫性を担保する
- [x] unsafe ケース向けに `safe mode`（closed-world 無効）を追加する
- [x] root 可視化レポート（なぜ keep されたか）を出せるようにする

## P2: GC / Closed-World 最適化（差別化の本丸）

- [x] `type-refining` の基盤を実装する（重複 function type の正規化）
- [x] `type-refining` を GC 混在 type section でも適用可能にする（function type のみ正規化）
- [x] GC hierarchy を考慮した `type-refining` へ拡張する
- [x] `signature-pruning` の基盤を実装する（末尾 unused param の削減 + call site drop 挿入）
- [x] `remove-unused-types` の基盤を実装する（core func type pruning）
- [x] private GC type まで `remove-unused-types` を拡張する
- [x] `cfp` phase1: forward call 伝播（`call thunk -> call target`）を導入する
- [x] `cfp` phase2: param-forwarding thunk 伝播（`local.get 0..N; call -> call target`）を導入する
- [x] `signature-refining` phase3: GC/closed-world 文脈での型特化を導入する
- [x] component root policy と GC 最適化の整合テストを追加する

## P3: 呼び出し経路の削減

- [x] `directize` 相当を導入する（`i32.const + call_indirect` の安全な直接化）
- [x] directize 後に DCE / RUME が追加で効くことを検証する（KPI 可視化を追加）
- [x] directize が効く core corpus を追加し、`directize_calls_total > 0` を継続観測できるようにする
- [x] RUME が効く core corpus を追加し、`rume_gain_bytes > 0` を継続観測できるようにする
- [x] `remove-unused-module-elements` と index rewrite の境界テストを拡充する

## P4: 固定点最適化（component + core 連携）

- [ ] component↔core の固定点ループを導入する
- [ ] 収束条件（サイズ非改善 / 反復上限）を定義する
- [ ] `--converge` と固定点ループの挙動を整理・統合する

## P5: wasm-opt 互換パスの段階移植（拡張バックログ）

- [x] `optimize-instructions` を優先移植する（最小実装: i32 rhs 恒等 + same-local 簡約）
- [x] `precompute` / `local-cse` を優先移植する（最小実装）
- [x] `precompute` 基盤: `i32.const+i32.const+i32.add` の定数畳み込み
- [x] `precompute` 基盤: `i32.const 0 + add/sub`, `i32.const 1 + mul` の恒等変換
- [x] `simplify-locals` 基盤: `local.set+local.get -> local.tee`
- [x] `simplify-locals` 基盤: `local.tee+drop -> local.set`
- [x] `simplify-locals` 基盤: `local.get+local.set(same)` の no-op 削除
- [x] `simplify-locals` 基盤: `local.get+local.tee(same) -> local.get`
- [x] `drop-elision` 基盤: `local.get/global.get/ref.func/ref.null + drop`
- [x] `local-cse` の最小実装（`local.get a; local.set b; local.get a -> local.get a; local.tee b`）
- [x] `precompute` 拡張: `eqz(eqz(x)) + br_if` の簡約
- [x] `precompute` 拡張: `i32.const + i32.eqz` の定数畳み込み
- [x] `precompute-propagate` 最小実装: straight-line な local 定数伝播
- [x] `simplify-locals*` 基盤: local 簡約パイプラインを固定点で反復する
- [x] `rse` 基盤: `local.tee x; local.set x -> local.set x`
- [x] `coalesce-locals` 最小実装（unused local 削減 + local index 圧縮）
- [x] `inlining-optimizing` の最小実装（`() -> i32.const` callee の call inline）
- [x] `dae-optimizing` の最小実装（drop される純粋式の除去）
- [ ] `duplicate-import-elimination` を検討する
- [ ] `simplify-globals*` / `reorder-globals` / `memory-packing` を検討する

## P6: 計測と品質

- [x] ベンチセット（component + core）初版を整備する（Binaryen/wac fixture + `moon bench` 導線）
- [x] KPI を明文化する（優先順: サイズ削減率 > 実行時間、`bench/KPI.md` + `just kpi`）
- [x] component-model DCE KPI 専用 corpus を追加する（`bench/corpus/component-dce/mwac`）
- [ ] 各 pass に Red/Green テストを追加し、回帰防止を徹底する
