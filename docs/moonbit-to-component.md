# MoonBit to WebAssembly Component Model

MoonBit ライブラリを WebAssembly Component Model に変換するワークフロー。

## 前提条件

- MoonBit SDK (`moon` CLI)
- `wite` CLI

## ワークフロー

### 1. プロジェクト初期化

```bash
moon new my-component
cd my-component
wite componentize
```

`wite componentize` は以下の雛形を生成する:

- `wite.config.jsonc` — ビルド設定
- `wit/world.wit` — WIT インターフェース定義

### 2. WIT 定義を編集

`wit/world.wit` に export する関数を定義:

```wit
package my:component;

world app {
    export add: func(a: s32, b: s32) -> s32;
}
```

### 3. MoonBit コードを記述

```moonbit
pub fn add(a : Int, b : Int) -> Int {
  a + b
}
```

### 4. moon.pkg に link 設定を追加

`moon.pkg` に以下の設定を追加:

```
options(
  "link": {
    "wasm": { "export-memory-name": "memory" },
    "wasm-gc": { "export-memory-name": "memory" },
  },
)
```

### 5. Core Wasm をビルド

```bash
moon build --target wasm
```

### 6. Component Wasm に変換

```bash
wite componentize _build/wasm/release/build/app.wasm -o component/app.component.wasm
```

### 7. 検証

```bash
wite analyze component component/app.component.wasm
```

## コマンドリファレンス

### `wite componentize` (引数なし)

雛形ファイルを生成する。

```bash
wite componentize [--force]
```

- `--force`: 既存ファイルを上書き

### `wite componentize <core.wasm>`

Core Wasm モジュールを Component Wasm に変換する。

```bash
wite componentize <core.wasm> [options]
  -o <path>        出力先 (default: component/<name>.component.wasm)
  --wit <dir>      WIT ディレクトリ (default: wit/)
  --world <name>   world 名
```

## 制限事項 (v1)

- 数値型のみ対応 (i32/s32, i64/s64, f32, f64)
- import を持つ core module は未対応
- WASI adapter fusion は未対応
- string/buffer 型は未対応
