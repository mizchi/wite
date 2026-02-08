# minimal example (`examplesl/minimal`)

最小の `wite.config.jsonc` で `analyze` を動かすサンプルです。

## 実行

リポジトリ root で:

```bash
just example-minimal
```

これは内部的に次を実行します:

```bash
moon run src/main --target js -- analyze bench/corpus/core/binaryen/br_to_exit.wasm --config=./examplesl/minimal/wite.config.jsonc
```

## 期待される挙動

- `wite.config.jsonc` の `deps` が自動同期される（`deps sync --fail-fast`）
- 続けて `analyze --view=summary` が実行される
- `analyze.kind=core` の設定が適用される（CLI `--kind=` で上書き可能）
