# TODO (wite)

完了済みの仕様/施策は `spec/*.md` に移動済み。

## KPI Snapshot (2026-02-11)

- core size KPI (`optimize -O1`, 主要 gap 判定 / `gc_target_feature.wasm` 除外): `9033101 -> 8764815 bytes` (`2.9700%`)
- wasm-opt 参考値 (`-Oz --all-features --strip-debug --strip-dwarf --strip-target-features`, 同スコープ): `9033101 -> 8788083 bytes` (`2.7124%`)
- gap to wasm-opt (主要): `-23268 bytes` (`+0.2576pt`)
- gap to wasm-opt (参考: 全 core corpus): `-23225 bytes` (`+0.2571pt`)
- component-model DCE KPI: `225479 -> 112549 bytes` (`50.0845%`)
- directize→DCE→RUME 診断: `success_files=9/9`, `dce_gain=2298 bytes`, `rume_gain=43 bytes`, `directize_calls_total=1`
- zlib gap 分解: `code=3420 bytes`, `function=44 bytes`, `type=37 bytes`（`wite=69644`, `wasm-opt=66146`, `gap=3498`）

## Active Backlog

- [ ] P0: core corpus 合計 gap の負値（wasm-opt 超え）を維持しつつ zlib gap を継続圧縮する
- [ ] P1: P5 `precompute/optimize-instructions` を拡張して code gap を削る（Top1）
- [ ] P1: P5 `duplicate-import-elimination` で function 残差を削る（Top2）
- [ ] P2: P2 `signature-refining/cfp` の拡張で DCE callgraph 精度を上げる（Top3）
- [ ] P2: N5 GC hierarchy type-refining を導入して type 残差を潰す（Top4）

## Next Actions (2026-02-11)

1. [ ] Top1 P5 `precompute/optimize-instructions` 拡張
目的: `zlib` の `code` gap (`3420 bytes`) を優先縮小。完了条件: `bench/kpi/zlib_gap.md` の `code` gap が減少し、`gap_to_wasm_opt_bytes` も改善。
2. [ ] Top2 P5 `duplicate-import-elimination`
目的: `zlib` の `function` 残差 (`44 bytes`) を削る。完了条件: `bench/kpi/zlib_gap.md` の `function` gap が減少。
3. [ ] Top3 P2 `signature-refining/cfp` 拡張
目的: DCE callgraph 精度を上げる。完了条件: `bench/kpi/directize_chain.tsv` の `dce_gain_bytes` が現状 (`2298`) より増加。

## Completed Specs

- Analyze 拡張方針 / Recent Progress の完了項目は `spec/completed-2026-02.md` へ移動済み
