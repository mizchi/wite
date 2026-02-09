# moonbit-wasi: moonbit-host | wasi-guest

MoonBit ホストが WASI 依存を利用するパターンです。

## 設定

```jsonc
{
  "component": {
    "entry": "example:app"
  },
  "deps": {
    "wasi:cli": "https://wa.dev/wasi:cli@0.2.0",
    "example:app": "./guest/moonbit/target/wasm/release/build/app.wasm"
  }
}
```

- `component.entry` — 合成のルートコンポーネント。省略時は deps が 1 つなら自動選択。
- `deps` — レジストリ URL またはローカルパス。`wite install` でレジストリ依存を `deps/` にダウンロード。

## フロー

```bash
# MoonBit ゲストをビルド
(cd guest/moonbit && moon build --target wasm)

# レジストリ依存をダウンロード
wite install

# 合成 + 最適化
wite build -Oz
```

## main.wac への脱出

設定ベースをやめて wac を直接管理したい場合:

```bash
# 現在の設定から wac を出力
wite build --print-wac > main.wac

# 以降は wac を直接指定
wite build main.wac -Oz
```
