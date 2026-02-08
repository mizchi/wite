# Analyze 運用知見 (2026-02-08)

このドキュメントは、`zlib.wasm` の `walyze` vs `wasm-opt` gap 追跡で得た知見を、今後の analyze 拡張方針として固定化する。

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

- import 依存 wasm で runtime 系分析が壊れやすい
- section 解析は表示フォーマット変化に脆く、レポート欠落が起きうる
- `walyze` と `wasm-opt` の差分を function 粒度で比較できない
- unresolved の理由が粗く、次の実装タスクに接続しづらい

## 拡張優先度

- P0: pass ごとの function 差分レポート（before/after, gain bytes, TopK）
- P0: runtime profile のシナリオ化（引数付き export、複数ケース）
- P1: `walyze` vs `wasm-opt` の function 対応差分
- P1: unresolved 理由の分類（import / signature / runtime）
- P1: analyze 結果を TODO 優先度へ自動接続するスコアリング

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
