# walyze API

`walyze` is a WebAssembly analyzer/optimizer/profiler for core modules and component model binaries.

`profile_runtime_zero_arg_exports` / `analyze_hotness_size_matrix` の runtime 計測は JS runtime 依存のため、`native/wasm` ターゲットではエラーを返します。

```mbt nocheck
// Public API is defined in src/lib.mbt
```
