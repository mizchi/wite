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

## Performance Improvements (2026-03-20)

### 完了済み

- [x] peephole: `to_array()` 中間コピー削減 → 効果なし（push ループより `to_array` + `append` の方が速い）
- [x] peephole: dirty flag + opcode pre-filter → spans パース前に不要パスをスキップ
- [x] peephole: **18 stateless パスを unified single-parse に統合** → optimize -O1: 1.3s → 290ms (-78%)
- [x] round: diminishing-returns 早期終了 → -Oz/O3 で不要ラウンドをスキップ

### 未着手

- [ ] **sections 使い回し** (推定 -30~40%, Medium Effort)
  `optimize_for_size_round_raise` 内で各パスが独立に `parse_core_sections_raise(bytes)` を呼んでいる。
  1ラウンドあたり 15+ 回のフルパース → sections を1回パースして各パスに渡す。
  パスのシグネチャ変更: `(Bytes) → Result` から `(Bytes, Array[RawSection]) → Result` に。

- [ ] **DCE cluster 統合** (推定 -10~15%, Medium Effort)
  directize, CFP, CFP-const, signature refine, DCE の5パスを1関数にまとめて
  sections/code_bodies を共有。

- [ ] **各モジュールパスに dirty flag** (推定 -5~10%, High Effort)
  `apply_type_refining` 等が変更なしでも新 `Bytes` を返す。
  dirty flag で元の参照を返せば `physical_equal` で O(1) 変更検出可能。

- [ ] **旧 peephole パス関数の削除** (コードサイズ削減, Low Effort)
  `apply_merged_stateless_peephole` 導入後、個別の `apply_precompute_*` は未使用。

## Architecture Improvements

- [ ] Library API facade 拡充: `src/top.mbt` に bundle/config の pure API を追加
- [ ] deps パッケージの I/O 抽象化: コールバック/trait で I/O 注入可能に

## Feature Backlog

- [ ] `wite build --chunk=NAME`: 特定 chunk のみリビルド
- [ ] `wite build --all-envs`: 全 environment 一括ビルド
- [ ] chunk 間依存グラフ (`depends_on` フィールド)
- [ ] dev mode chunk 単位 watch
- [ ] wasm-gc chunk 分割の制約ドキュメント（CM boundary での型制約）

## Testing

カバレッジ: 69.3% (8,981/12,967)

改善ターゲット:
- [ ] `deps/` (16%) — mock 化が必要
- [ ] `plugin-api/` (0%) — JS export 専用テスト
- [ ] `cmd/wite/dev.mbt` (20%) — async dev server E2E 拡充

## Completed Specs

- Analyze 拡張方針 / Recent Progress の完了項目は `spec/completed-2026-02.md` へ移動済み
