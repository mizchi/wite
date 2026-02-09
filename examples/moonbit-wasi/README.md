# moonbit-wasi

MoonBit で WASI preview1 の `fd_write` を直接呼び出し、Component Model 経由で JS からも実行できるサンプルです。

## ビルド・実行

```bash
make          # build → component → transpile
make run      # wasmtime で core module 実行
make run-component  # wasmtime で component 実行
make run-js   # Node.js で transpiled JS 実行
make clean    # ビルド成果物を削除
```

## パイプライン

```
main.mbt
  ↓ moon build --target wasm
core module (_build/wasm/release/build/app.wasm)
  ↓ wasm-tools component new --adapt (WASI P1→P2 adapter)
component (dist/app.component.wasm)
  ↓ jco transpile
JS (dist/js/)
```

## 仕組み

MoonBit の `println` は wasm ターゲットで `spectest.print_char` を import します。
ホスト側で実装すれば `println` も使えますが、
このサンプルでは WASI preview1 の `fd_write` を直接 FFI で呼びます。

- `moon.pkg` で `"export-memory-name": "memory"` を設定（wasmtime が要求）
- `wasm-tools component new` で WASI P1 adapter を使い component 化
- `jco transpile` で `@bytecodealliance/preview2-shim` を使う JS に変換

## 必要ツール

- [MoonBit](https://www.moonbitlang.com/) (`moon`)
- [wasm-tools](https://github.com/bytecodealliance/wasm-tools)
- [jco](https://github.com/bytecodealliance/jco) (`npm i -g @bytecodealliance/jco`)
- [wasmtime](https://wasmtime.dev/) (実行確認用)
