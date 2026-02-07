# Benchmark Corpus

`walyze` のベンチセット初期版。

- `core/binaryen`: Binaryen の core wasm テスト素材
- `component/wac`: wac の component wasm テスト素材
- `component-dce/mwac`: component-model DCE KPI 専用の mwac component 素材

## 同期

```bash
just bench-sync
```

`bench/corpus/manifest.tsv` にある commit/path/sha256 を使って再取得し、ハッシュ検証します。

## ライセンス

- Binaryen: Apache-2.0 (`https://github.com/WebAssembly/binaryen`)
- wac: Apache-2.0 (`https://github.com/bytecodealliance/wac`)
