# moonbit-rust: moonbit-host | rust-guest

MoonBit ホストが Rust (cargo-component) ゲストコンポーネントを合成するパターンです。

## 構成

```
main.wac                  # 合成定義
wite.config.jsonc         # ビルド設定
guest/rust/               # Rust ゲストコンポーネント
  wit/world.wit           #   WIT インターフェース定義
  src/lib.rs              #   実装 (add)
```

## 前提

- `cargo-component` (`cargo install cargo-component`)
- `wasm32-wasip1` ターゲット (`rustup target add wasm32-wasip1`)

## ビルド

```bash
just example-moonbit-rust
```
