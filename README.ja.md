# wite

[English](README.md) | [日本語](README.ja.md)

[MoonBit](https://docs.moonbitlang.com) で実装された、コンポーネントモデル対応の WebAssembly アナライザ・オプティマイザ・プロファイラです。

## インストール

```bash
# ライブラリとして
moon add mizchi/wite

# CLI（ソースから実行）
just run -- <command> [args...]
```

## クイックスタート

```bash
wite init                    # wite.config.jsonc + main.wac を生成
wite new --moonbit           # + guest/moonbit/ の雛形を生成
wite add wasi:http@0.2.0     # 依存を追加
wite build                   # 合成 & 最適化 => composed.wasm
```

`wite new --rust` は `guest/rust/` の cargo-component 雛形を生成します。

入力を省略した場合、`build` は `main.wac`（なければ `main.wasm`）を使います。

## CLI コマンド

### build

```bash
wite build path/to/entry.wac --out output.component.wasm -Oz
wite build path/to/module.wasm --out module.min.wasm -O2
wite build                   # 暗黙の入力: main.wac | main.wasm
wite build -Oz               # フラグのみ（暗黙の入力）
```

入力ヘッダから core/component を自動判定します。component の場合、`--converge` で固定点最適化を適用します。

### analyze

```bash
wite analyze module.wasm --view=summary
wite analyze module.wasm --view=deep --limit=20
wite analyze module.wasm --view=pipeline --opt-level=Oz --diff-limit=20
wite analyze module.wasm --view=keep --closed-world --closed-world-root=run
wite analyze module.wasm --view=retain --limit=20
wite analyze component.wasm --kind=component --view=summary
```

ビュー: `summary`, `deep`, `pipeline`, `keep`, `retain`（core 用）; `summary`, `functions`, `callgraph`（component 用）。

### profile

```bash
wite profile module.wasm
wite profile component.wasm --kind=component
```

### diff

```bash
wite diff module.wasm --baseline=wasm-opt --view=function --limit=20
wite diff module.wasm --baseline=wasm-opt --view=section
wite diff left.wasm right.wasm --view=block --limit=20
```

### add

```bash
wite add wkg:mizchi/markdown
wite add dep:a
wite add mizchi/markdown@0.1.0
wite add wasi:http@0.2.0 --name=http
wite add https://wa.dev/mizchi:tmgrammar@0.1.1 --name=tmg
wite add wasi:http@0.2.10 --registry=wasi.dev --verify
```

`wite.config.jsonc` の `deps` を更新します。`--verify` でレジストリ API 経由のパッケージ存在確認を行います。

### deps

```bash
wite deps verify                          # 全 deps を検証
wite deps verify --fail-fast              # 最初の失敗で停止
wite deps sync                            # deps をローカルにダウンロード
wite deps sync --dir=./deps --verify      # カスタムディレクトリ + 検証
```

### init / new

```bash
wite init                    # wite.config.jsonc + main.wac を生成
wite new --moonbit           # init + guest/moonbit/ 雛形
wite new --rust              # init + guest/rust/ 雛形
```

## 設定

`build`, `analyze`, `profile` はカレントディレクトリの `wite.config.jsonc` を自動読込します。`--no-config` で無効化できます。

```jsonc
{
  "build": { "kind": "auto", "flags": ["-Oz", "--strip-debug", "--closed-world"] },
  "analyze": { "kind": "core", "flags": ["--view=deep", "--limit=30"] },
  "profile": { "kind": "auto", "flags": [] },
  "deps": {
    "http": "https://wa.dev/wasi:http@0.2.0",
    "tmg": "https://wa.dev/mizchi:tmgrammar@0.1.1"
  }
}
```

マージ規則: config のフラグを先に適用し、CLI 引数で後勝ち上書きします。`--kind` の優先順位: CLI > config > auto。

## ライブラリ API

主要 API（`src/lib.mbt`）:

- `analyze_section_sizes(bytes)` / `analyze_wasm_breakdown(bytes, top_limit=...)`
- `analyze_function_sizes(bytes)` / `analyze_code_block_sizes(bytes)`
- `analyze_call_graph(bytes)` / `analyze_host_generated_code(bytes)`
- `analyze_optimize_metadata(bytes, config=..., function_diff_limit=...)`
- `analyze_keep_reasons(bytes, config=...)` / `analyze_retain_paths(bytes, config=...)`
- `analyze_dce_report(bytes)`
- `optimize_for_size(bytes, config=...)` / `optimize_binary_for_size(bytes, config=..., exclude=[...])`
- `profile_module(bytes)` / `profile_runtime_zero_arg_exports(bytes, iterations=...)`
- `profile_component(bytes)` / `analyze_component_function_sizes(bytes)`
- `optimize_component_for_size(bytes, config=..., exclude=[...])`
- `analyze_component_root_policy(bytes, resolved_wit=..., exclude=[...])`

サブパッケージ: `@mizchi/wite/optimize`, `@mizchi/wite/bundle`, `@mizchi/wite/analyze`, `@mizchi/wite/component`, `@mizchi/wite/config`, `@mizchi/wite/deps`。

## 最適化プリセット

| プリセット | 説明 |
|-----------|------|
| `-O0` | 最適化なし |
| `-O1` | 基本的な最適化 |
| `-O2` | 標準的な最適化 |
| `-O3` | 積極的な最適化 |
| `-Os` | サイズ最適化 |
| `-Oz` | 積極的なサイズ最適化 |

`--converge` を使うと、サイズ削減がなくなるまで最適化を繰り返します。

## アーキテクチャ

- **wac** (`mizchi/mwac`): WAC 合成エンジン（バンドラ役 — 依存解決、instantiate/export 計画）
- **wite**: バイナリオプティマイザ + プロファイラ（ミニファイア役 — 解析、最適化、プロファイリング）

依存方向: `wite -> wac` のみ。パイプライン: wac が wasm bytes を出力し、wite がそれを最適化します。

## 開発

```bash
just               # check + test
just fmt           # コードフォーマット
just check         # 型チェック
just test          # テスト実行
just bench         # ベンチマーク実行
just kpi           # KPI レポート収集
just run           # CLI 実行（src/main）
just info          # .mbti 生成
just release-check # fmt + info + check + test
```

開発中の CLI 実行: `just run -- <command> [args...]`

サンプル: `examples/minimal/`（`just example-minimal`）、`examples/sample_app/`（`just example-sample-app`）。

## ライセンス

Apache-2.0
