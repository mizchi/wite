# TODO (walyze)

完了済みの仕様は `docs/spec.md` に移動済み。

## KPI Snapshot (2026-02-08)

- core size KPI (`optimize -O1`, 主要 gap 判定 / `gc_target_feature.wasm` 除外): `171361 -> 70747 bytes` (`58.7146%`)
- wasm-opt 参考値 (`-Oz --all-features --strip-debug --strip-dwarf --strip-target-features`, 同スコープ): `171361 -> 66296 bytes` (`61.3121%`)
- gap to wasm-opt (主要): `4451 bytes` (`-2.5975pt`)
- gap to wasm-opt (参考: 全 core corpus): `4494 bytes` (`-2.6212pt`)
- component-model DCE KPI: `128170 -> 63984 bytes` (`50.0788%`)
- directize→DCE→RUME 診断: `success_files=8/8`, `dce_gain=1620 bytes`, `rume_gain=43 bytes`, `directize_calls_total=1`

## Active Backlog

- [ ] P0: core corpus 合計 gap (`gap_to_wasm_opt_ratio_pct`) を段階的に縮小する
