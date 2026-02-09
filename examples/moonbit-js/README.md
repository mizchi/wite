# moonbit-js

MoonBit の関数を wasm にビルドし、JS から直接呼び出す最小サンプルです。WASI 不要。

## ビルド・実行

```bash
moon build --target wasm
node run.mjs
# add(1, 2) = 3
# fib(10) = 55
```
