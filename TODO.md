# TODO (walyze)

## KPI Snapshot (2026-02-07)

- core size KPI (`optimize -O1`): `171331 -> 70803 bytes` (`58.6747%`)
- wasm-opt 参考値 (`-Oz --all-features --strip-debug --strip-dwarf --strip-target-features`): `171331 -> 66220 bytes` (`61.3497%`)
- gap to wasm-opt: `4583 bytes` (`-2.6750pt`)
- component-model DCE KPI: `128170 -> 64076 bytes` (`50.0070%`)

上記より、当面は **core size の wasm-opt ギャップ解消** を最優先にしつつ、差別化軸である **closed-world + GC 最適化** を次優先で進める。

## Architecture Guardrails（mwac / walyze）

- [x] 役割を bundler (`mwac`) / minifier (`walyze`) として整理する
- [x] 依存方向を `walyze -> mwac` に固定する（`mwac -> walyze` 依存を禁止）
- [ ] `mwac` 連携点は bytes I/O 契約（生成物の入出力）として定義する
- [ ] `walyze` 側の component 最適化 API を「WAC計画型非依存」で拡張する
- [ ] 固定点最適化は `component bytes -> core module optimize -> component bytes` の形で設計する

## P0: Core Size ギャップ解消（最優先）

- [ ] core corpus 合計 gap (`gap_to_wasm_opt_ratio_pct`) を段階的に縮小する
- [ ] `zlib.wasm` 向けに `optimize-instructions` / `precompute` / `local-cse` を優先実装する
- [ ] 小型 fixture（`br_to_exit`, `elided-br`, `complexBinaryNames`）での pass 適用漏れを潰す
- [ ] `gc_target_feature.wasm` の `wasm-opt` 側サイズ増ケースを比較注記し、評価対象の扱いを決める

## P1: Closed-World 基盤

- [x] `closed_world` 最適化モードを `OptimizeConfig` / CLI に追加する
- [x] component 由来の root policy を定義する（WIT/export/canonical ABI）
- [x] root policy を core DCE / RUME に接続し、root 一貫性を担保する
- [x] unsafe ケース向けに `safe mode`（closed-world 無効）を追加する
- [x] root 可視化レポート（なぜ keep されたか）を出せるようにする

## P2: GC / Closed-World 最適化（差別化の本丸）

- [x] `type-refining` の基盤を実装する（重複 function type の正規化）
- [ ] GC hierarchy を考慮した `type-refining` へ拡張する
- [x] `signature-pruning` の基盤を実装する（末尾 unused param の削減 + call site drop 挿入）
- [x] `remove-unused-types` の基盤を実装する（core func type pruning）
- [x] private GC type まで `remove-unused-types` を拡張する
- [ ] 可能なら `signature-refining` / `cfp` 系を段階導入する
- [ ] component root policy と GC 最適化の整合テストを追加する

## P3: 呼び出し経路の削減

- [x] `directize` 相当を導入する（`i32.const + call_indirect` の安全な直接化）
- [ ] directize 後に DCE / RUME が追加で効くことを検証する
- [ ] `remove-unused-module-elements` と index rewrite の境界テストを拡充する

## P4: 固定点最適化（component + core 連携）

- [ ] component↔core の固定点ループを導入する
- [ ] 収束条件（サイズ非改善 / 反復上限）を定義する
- [ ] `--converge` と固定点ループの挙動を整理・統合する

## P5: wasm-opt 互換パスの段階移植（拡張バックログ）

- [ ] `optimize-instructions` / `precompute` / `local-cse` を優先移植する
- [x] `precompute` 基盤: `i32.const+i32.const+i32.add` の定数畳み込み
- [x] `precompute` 基盤: `i32.const 0 + add/sub`, `i32.const 1 + mul` の恒等変換
- [x] `simplify-locals` 基盤: `local.set+local.get -> local.tee`
- [x] `simplify-locals` 基盤: `local.tee+drop -> local.set`
- [x] `simplify-locals` 基盤: `local.get+local.set(same)` の no-op 削除
- [x] `simplify-locals` 基盤: `local.get+local.tee(same) -> local.get`
- [x] `drop-elision` 基盤: `local.get/global.get/ref.func/ref.null + drop`
- [x] `local-cse` の最小実装（`local.get a; local.set b; local.get a -> local.get a; local.tee b`）
- [ ] `precompute` の拡張（`eqz(eqz(x))` などの安全な定数/論理簡約）
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
