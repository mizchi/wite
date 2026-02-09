# minimal example (`examples/minimal`)

複数のコンポーネントを `wite build` で合成するデモです。

## ユースケース

`moon-component` や `cargo-component` など異なるツールチェーンで生成したコンポーネントを、ホスト側で合成するパターンを示します。
この例では WAT ファイルでゲストコンポーネントを模しています。

## 構成

```
main.wac              # 合成定義
wite.config.jsonc     # ビルド設定
src/
  add.wat             # ゲストコンポーネント (add)
  mul.wat             # ゲストコンポーネント (mul)
deps/                 # ビルド済みコンポーネント置き場 (gitignored)
dist/                 # 最終成果物 (gitignored)
```

実プロジェクトでは `src/*.wat` の代わりに各ツールチェーンのビルド成果物を `deps/` に配置します。

## 前提

- `wasm-tools` がインストールされていること

## ビルド

```bash
# 1. ゲストコンポーネントをビルド (src/*.wat → deps/example/*.wasm)
just example-minimal-deps

# 2. 合成 (deps/ + main.wac → dist/composed.wasm)
just example-minimal
```
