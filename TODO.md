# TODO (walyze)

完了済みの仕様は `docs/spec.md` に移動済み。

## KPI Snapshot (2026-02-08)

- core size KPI (`optimize -O1`, 主要 gap 判定 / `gc_target_feature.wasm` 除外): `171361 -> 70725 bytes` (`58.7275%`)
- wasm-opt 参考値 (`-Oz --all-features --strip-debug --strip-dwarf --strip-target-features`, 同スコープ): `171361 -> 66296 bytes` (`61.3121%`)
- gap to wasm-opt (主要): `4429 bytes` (`-2.5846pt`)
- gap to wasm-opt (参考: 全 core corpus): `4472 bytes` (`-2.6084pt`)
- component-model DCE KPI: `128170 -> 63980 bytes` (`50.0819%`)
- directize→DCE→RUME 診断: `success_files=8/8`, `dce_gain=1642 bytes`, `rume_gain=43 bytes`, `directize_calls_total=1`
- zlib gap 分解: `code=4366 bytes`, `function=46 bytes`, `type=37 bytes`

## Active Backlog

- [ ] P0: core corpus 合計 gap (`gap_to_wasm_opt_ratio_pct`) を段階的に縮小する
- [ ] P1: P2 `signature-refining/cfp` の拡張で DCE callgraph 精度を上げる（Top1）
- [ ] P1: P5 `precompute/optimize-instructions` を拡張して code gap を削る（Top2）
- [ ] P2: N5 GC hierarchy type-refining を導入して type/function 残差を潰す（Top3）

## Recent Progress

- [x] P2/P5: forwarding thunk の終端パターン `call; return; end` を `cfp/cfp-const/signature-refine` で検出可能に拡張
- [x] テスト追加: `call+return` 形 thunk の `cfp/cfp-const/signature-refining` カバレッジを追加
- [x] P2/P5: forwarding thunk が `unused local` を持つ場合でも `cfp/cfp-const/signature-refine` を適用可能に拡張
- [x] テスト追加: `cfp/cfp-const/signature-refining` の `unused local` thunk ケースを追加
- [x] P5: `optimize-instructions` に const-first 形（`i32.const 0/-1; local/global.get; op`）の簡約を追加
- [x] テスト追加: `optimize-instructions simplifies const-first bitwise and cmp patterns`
