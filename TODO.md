# TODO (walyze)

component-model DCE の強みを活かすため、`wasm-opt` 互換よりも **closed-world + GC 最適化** を優先する。

## P0: Closed-World 基盤（最優先）

- [x] `closed_world` 最適化モードを `OptimizeConfig` / CLI に追加する
- [x] component 由来の root policy を定義する（WIT/export/canonical ABI）
- [x] root policy を core DCE / RUME に接続し、root 一貫性を担保する
- [x] unsafe ケース向けに `safe mode`（closed-world 無効）を追加する
- [x] root 可視化レポート（なぜ keep されたか）を出せるようにする

## P1: GC / Closed-World 最適化（差別化の本丸）

- [x] `type-refining` の基盤を実装する（重複 function type の正規化）
- [ ] GC hierarchy を考慮した `type-refining` へ拡張する
- [x] `signature-pruning` の基盤を実装する（末尾 unused param の削減 + call site drop 挿入）
- [x] `remove-unused-types` の基盤を実装する（core func type pruning）
- [ ] private GC type まで `remove-unused-types` を拡張する
- [ ] 可能なら `signature-refining` / `cfp` 系を段階導入する
- [ ] component root policy と GC 最適化の整合テストを追加する

## P2: 呼び出し経路の削減

- [ ] `directize` 相当を導入する（table 経由 call の直接化）
- [ ] directize 後に DCE / RUME が追加で効くことを検証する
- [ ] `remove-unused-module-elements` と index rewrite の境界テストを拡充する

## P3: 固定点最適化（component + core 連携）

- [ ] component↔core の固定点ループを導入する
- [ ] 収束条件（サイズ非改善 / 反復上限）を定義する
- [ ] `--converge` と固定点ループの挙動を整理・統合する

## P4: wasm-opt 互換パスの段階移植

- [ ] `optimize-instructions` / `precompute` / `local-cse` を優先移植する（precompute: `i32.const+i32.const+i32.add`、simplify-locals: `local.set+local.get -> local.tee`, `local.tee+drop -> local.set`、drop-elision: `local.get/global.get/ref.func/ref.null + drop` は実装済み）
- [ ] `simplify-locals*` / `coalesce-locals` / `rse` を移植する
- [ ] `inlining-optimizing` / `dae-optimizing` / `duplicate-import-elimination` を検討する
- [ ] `simplify-globals*` / `reorder-globals` / `memory-packing` を検討する

## P5: 計測と品質

- [ ] ベンチセット（component + core）を整備する
- [ ] KPI を明文化する（サイズ削減率 / 実行時間 / 収束ラウンド）
- [ ] 各 pass に Red/Green テストを追加し、回帰防止を徹底する
