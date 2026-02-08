# Analyze 運用知見 (2026-02-08)

このドキュメントは、`zlib.wasm` の `wite` vs `wasm-opt` gap 追跡で得た知見を、今後の analyze 拡張方針として固定化する。

## 目的

- 目的1: ユーザーコード/コンパイラ由来コードの問題箇所を指摘する
- 目的2: `wasm-opt` 相当の圧縮に必要なメタデータを収集し、optimizer の実装優先度へ接続する

## 今回の有用性評価

- `zlib_gap.md`: 高い  
  section/function/block の差分で、支配要因が `code` であることを即断できる。
- `pass_waterfall.tsv`: 高い  
  `strip -> code -> dce -> rume` の寄与で、次に伸ばすべきパスを選べる。
- `migration_top3.tsv`: 高い  
  実装候補を Top3 に絞れるため、実装サイクルが速い。
- `retain-path`: 中  
  keep 理由の説明には有効だが、byte 削減寄与の定量には直接つながりにくい。
- `hot-size`: 中  
  実行系の示唆は得られるが、zero-arg export 中心だと適用範囲が狭い。

## 今回露出した不足

- section 解析は表示フォーマット変化に脆く、レポート欠落が起きうる
- `wite` と `wasm-opt` の差分を function 粒度で比較できない
- analyze 結果と TODO 優先度の接続がまだ手動寄り

## 実装済みアップデート (2026-02-08)

- `analyze-opt` に pass 単位 function 差分（gain/regression, TopK）を追加
- `runtime-profile` に unresolved 理由を追加（`import-missing` / `signature-mismatch` / `runtime-exception`）
- `runtime-profile` に scenario 入力を追加（`--scenario=<export>[:arg1,arg2,...]`）し、引数付き export の複数ケース計測を可能化
- `hot-size` に unresolved 理由集計（reason 別 count）を追加
- `hot-size` に scenario 入力を追加（`--scenario=<export>[:arg1,arg2,...]`）し、引数付き export の分類に対応
- `function-gap`（`wite` vs `wasm-opt`）を追加し、`zlib` の支配関数 gap を TopK 可視化
- `migration_top3` を function-gap 指標つきで再スコア化（`fn_gap_top` / `fn_gap_positive`）

## runtime/hot-size シナリオ運用

- 形式: `runtime-profile <core.wasm> [iterations] [--scenario=<export>[:arg1,arg2,...]]`
- 形式: `hot-size <core.wasm> [iterations] [limit] [--scenario=<export>[:arg1,arg2,...]]`
- 例:
  - `wite runtime-profile foo.wasm 20 --scenario=run`
  - `wite runtime-profile foo.wasm 20 --scenario=add1:0 --scenario=add1:41`
  - `wite hot-size foo.wasm 20 30 --scenario=run`
  - `wite hot-size foo.wasm 20 30 --scenario=add1:0 --scenario=add1:41`
- 挙動:
  - `--scenario` 指定時は指定ケースのみ計測する
  - `hot-size` でも scenario 表示名（例: `add1(41)`）のまま `code` サイズ分類に接続される
  - 署名不一致は `signature-mismatch`、export 不在は `export-not-found` として unresolved に出る

## 拡張優先度

- P1: section 解析のフォーマット耐性を上げる

## 運用ループ

1. `just kpi` を実行する
2. `bench/kpi/latest.md` で gap と waterfall を確認する
3. `bench/kpi/zlib_gap.md` で section/function/block の帰属を見る
4. `bench/kpi/migration_top3.tsv` で実装候補を決める
5. 実装後に再度 `just kpi` で差分を比較する

## 補助ルール

- 主要判断は `primary_gap_scope`（`gc_target_feature.wasm` 除外）で行う
- `reference_*` はトレンド監視専用として扱う
- 分析失敗時は結果を捨てず、`no_change_reasons`/`unresolved` として可視化する
