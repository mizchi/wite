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

## Performance Improvements (2026-03-21)

### 完了済み

- [x] peephole: `to_array()` 中間コピー削減 → 効果なし（push ループより `to_array` + `append` の方が速い）
- [x] peephole: dirty flag + opcode pre-filter → spans パース前に不要パスをスキップ
- [x] peephole: **18 stateless パスを unified single-parse に統合** → optimize -O1: 1.3s → 290ms (-78%)
- [x] round: diminishing-returns 早期終了 → -Oz/O3 で不要ラウンドをスキップ
- [x] **sections 使い回し**: 17パスに `_with_sections` 版を追加、サイズ変更時のみ再パース
- [x] **旧 peephole パス関数の削除** → -1004行
- [x] Library API facade 拡充 → bundle/config を root facade に追加

### 未着手

- [ ] **DCE cluster 統合** (推定 -10~15%, Medium Effort)
  directize, CFP, CFP-const, signature refine, DCE の5パスを1関数にまとめて
  sections/code_bodies を共有。

- [ ] **各モジュールパスに dirty flag** (推定 -5~10%, High Effort)
  `apply_type_refining` 等が変更なしでも新 `Bytes` を返す。
  dirty flag で元の参照を返せば `physical_equal` で O(1) 変更検出可能。

- [ ] deps パッケージの I/O 抽象化: コールバック/trait で I/O 注入可能に

## Architecture (2026-03-21)

### 完了済み

- [x] I/O 分離: analyze/component/config から I/O を cmd/wite に移動、pure library 化
- [x] Environment API: RuntimeTarget, EnvironmentDef, resolve_all_environments, --env/--all-envs
- [x] Chunk build: ChunkConfig, build command 実行, componentize (wasm-tools), incremental
- [x] Vite plugin Environment API: per-env options, this.environment.name, server.environments
- [x] 4 runtime targets: browser, webworker, workerd, node
- [x] wasm HMR: import.meta.hot.accept, wite:update custom event
- [x] .d.ts 自動生成: core wasm (signatures), CM (jco or lowered core), dev server watch
- [x] jco transpile 統合: auto/true/false, missing jco error with install instructions

### 未着手

- [ ] `wite build --chunk=NAME`: 特定 chunk のみリビルド
- [ ] chunk 間依存グラフ (`depends_on` フィールド)
- [ ] dev mode chunk 単位 watch
- [ ] **built-in CM→ESM transpiler** (jco 代替): CM wasm をブラウザ用 ESM に変換する機能を wite 内蔵で実装し、jco 依存を除去する
- [ ] WASI browser shims 自動注入（要検証）
- [ ] wasm streaming compilation + caching (Cache API / IndexedDB)
- [ ] wasm source map (DWARF debug info → Chrome DevTools)
- [ ] wasm bundle splitting (lazy wasm loading)
- [ ] Vite devtools 統合 (wasm サイズ/callgraph 表示)

## Testing (2026-03-21)

### MoonBit

- テスト: 627
- カバレッジ: **69.9%** (9,148/13,080)

改善ターゲット:
- [ ] `deps/` (16%) — mock 化が必要
- [ ] `plugin-api/` (0%) — JS export 専用テスト
- [ ] `cmd/wite/dev.mbt` (20%) — async dev server E2E 拡充

### Vite Plugin

- テスト: 46 (5 ファイル)
- Fixtures: 7 wasm ファイル (core, CM, error cases)

## Completed Specs

- Analyze 拡張方針 / Recent Progress の完了項目は `spec/completed-2026-02.md` へ移動済み
