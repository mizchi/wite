# wite 仕様（実装済み + 合意方針）

このドキュメントは、直近で合意した API/アーキテクチャ方針を仕様として固定化したもの。
`TODO.md` から移管した完了履歴（`[x]`）は `spec/*.md` を参照。

分析運用の知見と拡張方針は `docs/analyze.md` を参照。

## 基本方針

- 外部向けのプロダクト名は `wite` とし、`vite` 的な高水準インターフェースを提供する
- `wite` は bundler + minifier + analyzer を一体で提供するフロントドアとする
- 内部実装は `wac`（compose/bundle, 現在は `mizchi/mwac`）を利用しつつ、最適化/解析ロジックは `wite` 側で提供する
- 連携単位は core/component wasm bytes の入出力契約を維持する
- 公開パッケージ名・CLI 名は `wite` 名前空間に統一する

## wite API 体系（合意）

- Canonical CLI は `new` / `build` / `analyze` / `profile` / `diff` / `add` / `deps` / `component` とする
- `build` は「bundle + optimize + emit」を 1 コマンドで実行する
- `init` は quickstart 用の `wite.config.jsonc` / `main.wac` ひな型を生成する
- `new` は `--moonbit` / `--rust` を受け付け、`wite.config.jsonc` / `main.wac` に加えて guest テンプレートを生成する
- `build` は入力省略時に `main.wac`（優先）または `main.wasm` を自動選択する
- `build` が入力省略で `main.wac` を使う場合、既定出力は `composed.wasm` とする
- `analyze` は `--view` で `summary|deep|functions|blocks|callgraph|host|pipeline|dce|keep|retain` を切り替える
- `profile` は `--view runtime|hot-size` と `--scenario=<export>[:arg1,arg2,...]` を標準化する
- `build/analyze/profile/optimize` は `--kind=auto|core|component` を受け付ける
- `build/analyze/profile` の kind は `CLI --kind > config.kind > auto` で決定し、`optimize` の kind は `CLI --kind > auto` で決定する
- `analyze kind=component` は `summary|functions|callgraph` をサポートし、それ以外の view は明示エラーにする
- `diff` は `--view function|section|block` を提供し、`wite` vs `wasm-opt` 比較を標準運用にする
- `diff --baseline=wasm-opt` は `wasm-opt` を直接実行して baseline を生成し、`function/section/block` を同一導線で比較する
- `add` は `wite.config.jsonc` の `deps` を更新し、`https://<registry>/<namespace>:<name>[@version]` を保存する
- `add` の `dep-spec` は `wkg:mizchi/markdown` / `mizchi/markdown` / `wasi:http` / `https://wa.dev/mizchi:tmgrammar@0.1.1` を受け付ける
- `add --verify` は `https://<host>/.well-known/wasm-pkg/registry.json` を解決し、`oci` backend は OCI API、`warg` backend は `wkg get --registry` で package/version 実在確認まで行う
- `deps verify` は `wite.config.jsonc` の `deps` 全件を `add --verify` と同じ検証ロジックで再確認する（`--fail-fast` あり）
- `deps sync` は `wite.config.jsonc` の `deps` 全件を `wkg get` で `deps/<dep-name>/` に実体化する（`--dir` / `--verify` / `--fail-fast` あり）
- `component` は `roots|contract|kpi` を提供し、component-model closed-world 運用を集約する
- 設定ファイルは `wite.config.jsonc` を標準とし、`build/analyze/profile` を単一設定で扱う
- `wite.config.jsonc` は `build/analyze/profile` それぞれで `["..."]` または `{ "flags": ["..."] }` の両形式を受け付ける
- `build/analyze/profile` は `wite.config.jsonc` を自動読込し、マージ規則は「config flags -> CLI flags（後勝ち）」とする
- `wite.config.jsonc` は `deps`（object）を受け付け、`add` で URL を upsert する
- `build/analyze/profile` は `deps` が存在する場合に `deps sync --fail-fast` を自動実行して `deps/` を最新化する（`--no-config` では無効）
- リポジトリ root に `wite.config.jsonc` テンプレートを置き、`just deps-verify` / `just deps-sync` で運用できるようにする
- `examples/minimal` に最小設定例を置き、`just example-minimal` で動作確認できるようにする
- CLI は `wite` に集約するが、`optimize` は移植・比較容易化のため `wasm-opt` 互換フラグを受け付ける


## Next Up (2026-02-08)

- W0 (P0): `wite` 名での CLI エントリを追加し、公開名を `wite` に統一する
- W1 (Done): `wite build` を実装し、`wac` compose + `wite` optimize を単一導線で実行可能
- W2 (Done): `wite analyze --view` へ既存 analyze サブコマンド群を統合
- W3 (Done): `wite.config.jsonc` ローダーを実装し、CLI 引数とのマージ規則を定義する
- W4 (Done): `wite diff --baseline=wasm-opt` を実装し、KPI と直結する比較導線を用意する
- W5 (Done): `wite add` を実装し、依存を `wite.config.jsonc` の `deps`（HTTPS URL）へ追加できるようにする
- W6 (Done): `wite deps verify` を実装し、`deps` 全件の `.well-known` + backend 検証を再実行可能にする
- W7 (Done): `wite deps sync` を実装し、`deps` 全件をローカル `deps/` へ実体化できるようにする
- W8 (Done): `build/analyze/profile` 実行時に `deps` 自動同期（`deps sync --fail-fast`）を追加する
- W9 (Done): root `wite.config.jsonc` テンプレートと `just deps-verify` / `just deps-sync` タスクを追加する
- W10 (Done): `examples/minimal` 最小設定例と `just example-minimal` タスクを追加する
- W11 (Done): `build/analyze/profile` に `kind`（auto/core/component）を導入し、config/CLI で指定可能にする
- W12 (Done): `optimize` に `--kind`（auto/core/component）を追加し、core/component 経路を明示可能にする
- W13 (Done): `wite init` を追加し、quickstart ひな型（`wite.config.jsonc` / `main.wac`）を生成可能にする
- W14 (Done): `wite build` の入力省略を許可し、`main.wac` / `main.wasm` 自動選択を追加する
- W15 (Done): `wite new --moonbit|--rust` を追加し、MoonBit / cargo-component の guest テンプレート生成と build smoke を追加する
- W16 (Done): `wite optimize` に `wasm-opt` 互換フラグ（`--optimize-level` / `--shrink-level` / pass alias / feature flags）を追加し、単体最適化導線を強化する
- P2 (P1): `cfp` phase1（forward call 伝播）を導入し、DCE の callgraph 精度を上げる
- P5 (P1): `precompute` を拡張（`eqz(eqz(x))+br_if`）して code セクション gap を削る
- P2 (P1): `cfp` phase2（param-forwarding thunk 伝播）を導入し、DCE の callgraph 精度を上げる
- P2 (P1): `signature-refining` phase3 を導入し、closed-world/GC 文脈の callgraph 精度を上げる
- N5 (P2): GC hierarchy を考慮した `type-refining` に着手し、closed-world と組み合わせた差分を測る
- N8 (P1): `remove-unused-module-elements` と index rewrite の境界テストを拡充する
- N9 (Guardrails): `wac` 連携点の bytes I/O 契約（入出力）を文書化する

## Analysis Next (2026-02-08)

- A1: `zlib.wasm` 専用の gap 詳細レポートを追加し、`before/wite/wasm-opt` の差分を section/function/block で見える化する
- A2: no-change 理由を「実装対象 / 非対象」に分類し、優先度と工数見積もりを TODO に接続する（`bench/kpi/no_change_triage.tsv`）
- A3: pass waterfall の寄与をもとに、`code` / `dce` の追加移植候補を Top3 に絞る（`bench/kpi/migration_top3.md`）

## Performance Review (2026-02-08)

### Perf TODO (priority)

- PR1 (P0): `analyze_wasm_breakdown` を単一パイプライン化し、section/code 走査を 1 回に統合する
- PR2 (P0): `deep-analyze` 用に lightweight callgraph summary API（`nodes` なし）を追加する
- PR3 (P0): top-k 収集を API レベルで導入し、全件ソートをやめる（`limit` 連携）
- PR4 (P1): opcode 集計を数値キー中心に変更し、文字列化を最終出力時に遅延する（非-prefixed 命令）
- PR5 (P1): roots/callees dedup を `Map/Set` ベースへ置換する（`contains` 依存を削減）
- PR6 (Bug): `deep-analyze` の `%` 表示オーバーフローを修正する（`numerator * 10000` 回避）

## Architecture Guardrails（wite / wac）

- `wite` を唯一の公開エントリにする（ユーザーは原則 `wite` のみを触る）
- `wite` は内部で `wac` を使って bundle/compose し、同一パッケージ内の optimizer/analyzer を使って optimize/analyze/profile を行う
- 依存方向は `wite -> wac` を許可し、`wac -> wite` の直接依存は持たない
- 連携点は bytes I/O 契約（`component bytes -> core module optimize -> component bytes`）として定義する
- `closed-world root policy` は `wite component roots` で決定し、optimize/analyze に同じ設定を渡す
- `wite` の低レベル API は再利用可能な optimizer/analyzer ライブラリとして維持する
- `src/optimize`（最適化実行）と `src/bundle`（WAC compose/依存解析）を独立パッケージとして維持し、CLI 依存なしで再利用可能にする
- `src/analyze`（解析実行/表示）, `src/component`（component 専用操作）, `src/config`（config 解決）, `src/deps`（依存解決/同期）を独立パッケージとして維持する

## Optimization Hint Conventions

`wite` は producer 非依存の規約として、custom section 経由の optimize hint を受け付ける。

`wite.cfp_const_hints` の設計意図と producer 実装指針は
`docs/adr/0001-cfp-const-hints.md` を参照。

### `wite.cfp_const_hints` v1

- section 名: `wite.cfp_const_hints`
- 用途: `cfp-const` / `cfp-const-specialize` の seed
- 適用対象: const-forward / interleaved-const 系 wrapper
- 有効化条件: experimental flag が有効な optimize 実行に限る

現状は default で無効であり、CLI では `--experimental-cfp-const-hints`
または `--enable-experimental-cfp-const-hints` を指定したときだけ使う。

payload schema:

```text
version: u32 = 1
entry_count: u32
repeat entry_count times:
  wrapper_index: u32
  target_index: u32
  arg_instr_count: u32
  repeat arg_instr_count times:
    instr_len: u32
    instr_bytes: byte[instr_len]
```

`wrapper_index` / `target_index` は import を含んだ absolute function index とする。  
`instr_bytes` は target へ渡す引数 recipe を表す raw wasm instruction bytes で、v1 では次だけを対象にする。

- `local.get <wrapper_param_index>`
- `i32.const`
- `i64.const`
- `f32.const`
- `f64.const`

### producer 側の規約

- hint は advisory であり、`wite` は常に無視してよい
- wrapper/target index は emitted wasm に対する実 index と一致していなければならない
- arg recipe は target の全 param を順に埋める必要がある
- `local.get` は wrapper param を参照する。wrapper local は参照してはならない
- wrapper の各 param は recipe 全体でちょうど 1 回ずつ使う。重複参照や未使用は不可
- raw instruction は 1 引数 = 1 instruction とする。extra bytes や block/if/call など複合命令は不可
- malformed な section は section 単位で無視してよい
- unknown version は無視してよい

### `cfp-const` が hint を使える条件

以下を満たす entry だけが alias candidate になる。

- wrapper が local function である
- wrapper と target の function type が recipe と整合する
- recipe 内に const arg が 1 つ以上ある
- recipe 内の `local.get` / `*.const` は、それぞれ raw bytes 全体でちょうど 1 命令として decode できる
- scratch local が必要な場合、その wrapper param type を 1-byte value type として再構成できる
- 既存 auto-detect alias がある場合はそちらを優先し、hint は不足分だけ補う

書き換えは既存 `cfp-const` の profitability 判定を通った場合のみ発火する。

現状の `analyze host` は、section 数・unknown version section 数・malformed section 数、
parsed entry 数・usable entry 数に加えて、次の structural reject reason を集計する。

- `wrapper-not-local`
- `self-target`
- `wrapper-index-out-of-range`
- `target-index-out-of-range`
- `wrapper-type-missing`
- `target-type-missing`
- `recipe-type-mismatch`
- `scratch-local-types-unsupported`

ここでいう reject は `cfp-const` seed としての構造的妥当性だけを表し、profitability や root policy のような pass 固有条件は含まない。

experimental flag が有効な場合、通常の `optimize` / `build` / `treeshake` でも
`OptimizeResult.observations` に同じ集計を載せる。固定点 round を回す optimize では
`round#N: ...`、component optimize ではさらに `core#M:...` が前置される。

`analyze optimize metadata` では、experimental flag が有効な場合に限り、DCE stage の
`observations` に同じ hint 集計と、`cfp-const` / `cfp-const-specialize` がその stage で
実際に発火したかどうかを併記する。

### `cfp-const-specialize` が hint を使える条件

hint entry があっても、specialize はさらに次を満たす場合だけ発火する。

- wrapper が root ではない
- wrapper が local decl を持たない
- target が local function である
- target の direct caller 数が 1
- recipe が scratch local を必要とする
- 既存の type / profitability / root policy をすべて通る

つまり hint は「最適化を強制する契約」ではなく、「既存 heuristic の candidate を与える契約」である。

現状の `analyze host` は、structural に valid な hint を対象に
`cfp-const-specialize` 候補数と次の reject reason を集計する。

- `wrapper-root`
- `wrapper-body-missing`
- `wrapper-index-out-of-range`
- `wrapper-type-missing`
- `wrapper-has-locals`
- `self-target`
- `target-root`
- `target-direct-callers!=1`
- `target-not-local`
- `target-index-out-of-range`
- `target-body-missing`
- `target-type-missing`
- `scratch-not-needed`
- `cfp-const-still-profitable`
- `recipe-type-mismatch`
- `specialize-build-invalid`

### strip 規約

現状の実装では、`wite.cfp_const_hints` を使った `cfp-const` または
`cfp-const-specialize` の rewrite が成功した場合、その section を最終出力から除去する。

experimental flag が無効な場合、`wite` はこの section を hint としては読まず、通常の custom section として扱う。

rewrite が発火しなかった場合に常に strip するかは未確定で、今後の analyze/debug 運用を見て決める。

## P0: Core Size ギャップ解消（最優先）

- `zlib.wasm` 向けに `precompute` / `local-cse` の優先実装を進める（基盤実装まで完了）
- `zlib.wasm` 向け `optimize-instructions` を優先実装する（基盤実装まで完了）
- `zlib.wasm` 向け `optimize-instructions` を拡張する（bitwise/cmp の追加簡約）
- 小型 fixture（`br_to_exit`, `elided-br`, `complexBinaryNames`）での pass 適用漏れを潰す
- `gc_target_feature.wasm` の `wasm-opt` 比較注記を KPI に反映する
- `gc_target_feature.wasm` は主要 gap 判定から除外し、参考値（`reference_*`）として併記する方針に固定する
- `zlib.wasm` の gap を専用レポート（`bench/kpi/zlib_gap.md`）で継続観測する

## P1: Closed-World 基盤

- `closed_world` 最適化モードを `OptimizeConfig` / CLI に追加する
- component 由来の root policy を定義する（WIT/export/canonical ABI）
- root policy を core DCE / RUME に接続し、root 一貫性を担保する
- unsafe ケース向けに `safe mode`（closed-world 無効）を追加する
- root 可視化レポート（なぜ keep されたか）を出せるようにする

## P2: GC / Closed-World 最適化（差別化の本丸）

- `type-refining` の基盤を実装する（重複 function type の正規化）
- `type-refining` を GC 混在 type section でも適用可能にする（function type のみ正規化）
- GC hierarchy を考慮した `type-refining` へ拡張する
- `signature-pruning` の基盤を実装する（末尾 unused param の削減 + call site drop 挿入）
- `remove-unused-types` の基盤を実装する（core func type pruning）
- private GC type まで `remove-unused-types` を拡張する
- `cfp` phase1: forward call 伝播（`call thunk -> call target`）を導入する
- `cfp` phase2: param-forwarding thunk 伝播（`local.get 0..N; call -> call target`）を導入する
- `signature-refining` phase3: GC/closed-world 文脈での型特化を導入する
- component root policy と GC 最適化の整合テストを追加する

## P3: 呼び出し経路の削減

- `directize` 相当を導入する（`i32.const + call_indirect` の安全な直接化）
- directize 後に DCE / RUME が追加で効くことを検証する（KPI 可視化を追加）
- directize が効く core corpus を追加し、`directize_calls_total > 0` を継続観測できるようにする
- RUME が効く core corpus を追加し、`rume_gain_bytes > 0` を継続観測できるようにする
- `remove-unused-module-elements` と index rewrite の境界テストを拡充する

## P4: 固定点最適化（component + core 連携）

- component↔core の固定点ループを導入する
- 収束条件（サイズ非改善 / 反復上限）を定義する
- `--converge` と固定点ループの挙動を整理・統合する

## P5: wasm-opt 互換パスの段階移植（拡張バックログ）

- `optimize-instructions` を優先移植する（最小実装: i32 rhs 恒等 + same-local 簡約）
- `precompute` / `local-cse` を優先移植する（最小実装）
- `precompute` 基盤: `i32.const+i32.const+i32.add` の定数畳み込み
- `precompute` 基盤: `i32.const 0 + add/sub`, `i32.const 1 + mul` の恒等変換
- `simplify-locals` 基盤: `local.set+local.get -> local.tee`
- `simplify-locals` 基盤: `local.tee+drop -> local.set`
- `simplify-locals` 基盤: `local.get+local.set(same)` の no-op 削除
- `simplify-locals` 基盤: `local.get+local.tee(same) -> local.get`
- `drop-elision` 基盤: `local.get/global.get/ref.func/ref.null + drop`
- `drop-elision` 拡張: `memory.size/table.size + drop` の除去
- `local-cse` の最小実装（`local.get a; local.set b; local.get a -> local.get a; local.tee b`）
- `precompute` 拡張: `eqz(eqz(x)) + br_if` の簡約
- `precompute` 拡張: `i32.const + i32.eqz` の定数畳み込み
- `precompute-propagate` 最小実装: straight-line な local 定数伝播
- `simplify-locals*` 基盤: local 簡約パイプラインを固定点で反復する
- `rse` 基盤: `local.tee x; local.set x -> local.set x`
- `coalesce-locals` 最小実装（unused local 削減 + local index 圧縮）
- `inlining-optimizing` の最小実装（`() -> i32.const` callee の call inline）
- `dae-optimizing` の最小実装（drop される純粋式の除去）
- `duplicate-import-elimination` の最小実装（func/table/memory/global の重複 import 統合 + index remap）
- `simplify-globals*` / `reorder-globals` / `memory-packing` の最小実装を導入する（immutable i32 global.get の const 化 / local global 再配置 / local memory 再配置）

## P6: 計測と品質

- ベンチセット（component + core）初版を整備する（Binaryen/wac fixture + `moon bench` 導線）
- KPI を明文化する（優先順: サイズ削減率 > 実行時間、`bench/KPI.md` + `just kpi`）
- component-model DCE KPI 専用 corpus を追加する（`bench/corpus/component-dce/mwac`）
- 各 pass に Red/Green テストを追加し、回帰防止を徹底する

## 備考

- 未完了タスク（`[ ]`）は `TODO.md` で管理する。
