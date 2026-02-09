# sample_app (`examples/sample_app`)

`wite new --moonbit` を起点に、ローカル dep を使って component bundle する最小サンプルです。

## 含まれるもの

- `wite.config.jsonc`: sample 用の build/analyze/profile 設定
- `main.wac`: `example:hello` を instantiate して `hello` を export
- `guest/moonbit/`: `wite new --moonbit` と同等の雛形
- `deps/example/hello.wasm`: bundle 用のローカル component 依存

## 実行

リポジトリ root で:

```bash
just example-sample-app
```

内部的には次を実行します:

```bash
moon run src/main --target js -- build ./examples/sample_app/main.wac --no-config -o ./examples/sample_app/sample.composed.wasm
```

`--no-config` により、ネットワーク依存なしでローカル `deps/` だけで compose できます。

## new コマンドとの対応

このサンプルは `wite new --moonbit` で生成される `guest/moonbit/` 構成を保持しています。
必要なら次で再生成できます。

```bash
cd examples/sample_app
moon run ../../src/main --target js -- new --moonbit --force
# main.wac は sample 用に戻す
```
