# wite bundle fixture

`wite build` の結合テスト用 fixture。

- `main.wac`: local dependency (`example:hello`, `example:greeter`) を compose する入力
- `deps/example/*.wasm`: local deps 実体

`src/main/main_wbtest.mbt` の bundle 結合テストは、このディレクトリを一時領域へコピーして実行する。
