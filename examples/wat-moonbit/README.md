# wat-moonbit: wat-host | moonbit-guest

WAT ホストコンポーネントと MoonBit ゲストコンポーネントを合成するパターンです。

## 構成

```
main.wac                  # 合成定義
wite.config.jsonc         # ビルド設定
src/
  add.wat                 # WAT ホストコンポーネント (add)
guest/moonbit/            # MoonBit ゲストコンポーネント
```

## 前提

- `wasm-tools`
- `moon` (MoonBit toolchain)

## ビルド

```bash
# WAT ホストビルド
mkdir -p deps/example
wasm-tools parse src/add.wat -o deps/example/add.wasm

# MoonBit ゲストビルド
(cd guest/moonbit && moon build --target wasm)
cp guest/moonbit/target/wasm/release/build/*.wasm deps/example/moonbit-guest.wasm

# 合成
wite build -o dist/composed.wasm
```
