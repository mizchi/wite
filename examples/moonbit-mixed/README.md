# moonbit-mixed: moonbit-host | moonbit-guest + rust-guest

MoonBit ホストが MoonBit と Rust 両方のゲストコンポーネントを合成するパターンです。
現在は Rust ゲスト (mul) のみビルド可能です。

## 構成

```
main.wac                  # 合成定義
wite.config.jsonc         # ビルド設定
guest/moonbit/            # MoonBit ゲストコンポーネント (TODO)
guest/rust/               # Rust ゲストコンポーネント
  wit/world.wit           #   WIT インターフェース定義
  src/lib.rs              #   実装 (mul)
```

## 前提

- `moon` (MoonBit toolchain)
- `cargo-component` (`cargo install cargo-component`)
- `wasm32-wasip1` ターゲット (`rustup target add wasm32-wasip1`)

## ビルド

```bash
just example-moonbit-mixed
```
