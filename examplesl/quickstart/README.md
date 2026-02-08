# quickstart example (`examplesl/quickstart`)

`wite` の最小フローを手順化したサンプルです。

```bash
wite init
wite add dep:a
wite add dep:b
# edit main.wac
wite build
# => composed.wasm
```

補足:

- `init` は `wite.config.jsonc` と `main.wac` を生成
- `add` は `wite.config.jsonc` の `deps` を更新
- `build` は入力省略時に `main.wac`（なければ `main.wasm`）を自動選択
- 入力省略かつ `main.wac` の場合、既定出力は `composed.wasm`
