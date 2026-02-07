# walyze

`walyze` is a MoonBit toolkit for WebAssembly binaries with a focus on component-model workflows.

It provides:

- core wasm section-size analysis (`twiggy`-style breakdown by section)
- core wasm top-function size analysis (`twiggy top`-style by code body size)
- core wasm call graph + dead-body analysis (export/start roots)
- core wasm DCE report + apply (callgraph-based function-level pruning)
- core wasm duplicate function elimination apply (body+type based index remap)
- core wasm merge-similar-functions apply (forwarding thunk merge + index remap)
- size-oriented optimization pass (`wasm-opt`-style custom section stripping + vacuum + merge-blocks + remove-unused-brs + peephole + DCE + DFE + MSF)
- static module profiler (imports/exports/functions/code-body bytes)
- runtime profiler for zero-arg exports (call count / total ns / avg ns)
- component model profiling (`mizchi/mwac` integration)
- component core-module top-function size reports
- component core-module call graph reports
- WIT contract gap analysis (`mizchi/wit` integration)

## CLI

```bash
just run -- analyze path/to/module.wasm
just run -- profile path/to/module.wasm
just run -- top-functions path/to/module.wasm 20
just run -- callgraph path/to/module.wasm 20
just run -- dce-report path/to/module.wasm 20
just run -- runtime-profile path/to/module.wasm 100
just run -- optimize in.wasm out.wasm --strip-all-custom --converge --dce-apply --dfe-apply --msf-apply
just run -- component-profile path/to/component.wasm
just run -- component-top-functions path/to/component.wasm 20
just run -- component-callgraph path/to/component.wasm 20
just run -- contract path/to/component.wasm path/to/wit-dir
```

## Library API

Main APIs are in `src/lib.mbt`:

- `analyze_section_sizes(bytes)`
- `analyze_function_sizes(bytes)`
- `analyze_call_graph(bytes)`
- `analyze_dce_report(bytes)`
- `optimize_for_size(bytes, config=...)`
- `profile_module(bytes)`
- `profile_runtime_zero_arg_exports(bytes, iterations=...)`
- `profile_component(bytes)`
- `analyze_component_function_sizes(bytes)`
- `analyze_component_call_graphs(bytes)`
- `analyze_component_contract(bytes, resolved_wit)`

## Development

```bash
just           # check + test
just fmt       # format code
just check     # type check
just test      # run tests
just run       # run CLI (src/main)
just info      # generate .mbti
```
