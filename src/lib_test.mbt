///|
fn bytes_of(xs : Array[Int]) -> Array[Byte] {
  xs.map(v => v.to_byte())
}

///|
fn encode_u32_leb128(value : UInt) -> Array[Byte] {
  [value.to_byte()]
}

///|
fn append_section(out : Array[Byte], id : UInt, payload : Array[Byte]) -> Unit {
  out.push(id.to_byte())
  out.append(encode_u32_leb128(payload.length().reinterpret_as_uint())[:])
  out.append(payload[:])
}

///|
fn ascii_bytes(text : String) -> Array[Byte] {
  let out : Array[Byte] = []
  for ch in text {
    out.push(ch.to_int().to_byte())
  }
  out
}

///|
fn append_named_custom_section(
  out : Array[Byte],
  name : String,
  body : Array[Int],
) -> Unit {
  let name_bytes = ascii_bytes(name)
  let payload : Array[Byte] = []
  payload.append(
    encode_u32_leb128(name_bytes.length().reinterpret_as_uint())[:],
  )
  payload.append(name_bytes[:])
  payload.append(bytes_of(body)[:])
  append_section(out, 0U, payload)
}

///|
fn find_keep_reason_entry(
  entries : Array[KeepReasonEntry],
  function_index : UInt,
) -> KeepReasonEntry? {
  for entry in entries {
    if entry.function_index == function_index {
      return Some(entry)
    }
  }
  None
}

///|
fn split_string(text : String, delim : String) -> Array[String] {
  let out : Array[String] = []
  for part in text.split(delim) {
    out.push(part.to_string())
  }
  out
}

///|
fn join_int_csv(values : Array[Int]) -> String {
  let mut out = ""
  for i in 0..<values.length() {
    if i > 0 {
      out = out + ","
    }
    out = out + values[i].to_string()
  }
  out
}

///|
extern "js" fn js_compare_export_runtime_outputs(
  before_bytes : Bytes,
  after_bytes : Bytes,
  export_name : String,
  args_csv : String,
) -> String =
  #| (beforeBytes, afterBytes, exportName, argsCsv) => {
  #|   try {
  #|     const toRaw = (value) => value instanceof Uint8Array
  #|       ? value
  #|       : (Array.isArray(value) ? Uint8Array.from(value) : new Uint8Array(value));
  #|     const args = argsCsv.length === 0
  #|       ? []
  #|       : argsCsv.split(',')
  #|           .filter((item) => item.length > 0)
  #|           .map((item) => Number.parseInt(item, 10));
  #|     const run = (raw) => {
  #|       const mod = new WebAssembly.Module(toRaw(raw));
  #|       const instance = new WebAssembly.Instance(mod, {});
  #|       const fn = instance.exports[exportName];
  #|       if (typeof fn !== 'function') {
  #|         return { ok: false, error: 'missing export: ' + exportName };
  #|       }
  #|       const values = [];
  #|       if (args.length === 0) {
  #|         const result = fn();
  #|         values.push(typeof result === 'bigint' ? result.toString() + 'n' : String(result));
  #|       } else {
  #|         for (const arg of args) {
  #|           const result = fn(arg);
  #|           values.push(typeof result === 'bigint' ? result.toString() + 'n' : String(result));
  #|         }
  #|       }
  #|       return { ok: true, values: values.join(',') };
  #|     };
  #|     const before = run(beforeBytes);
  #|     if (!before.ok) return 'err|' + before.error;
  #|     const after = run(afterBytes);
  #|     if (!after.ok) return 'err|' + after.error;
  #|     return 'ok|' + (before.values === after.values ? '1' : '0') + '|' + before.values + '|' + after.values;
  #|   } catch (e) {
  #|     const msg = e && e.message ? e.message : String(e);
  #|     return 'err|' + msg;
  #|   }
  #| }

///|
extern "js" fn js_compare_zlib_runtime_behaviors(
  before_bytes : Bytes,
  after_bytes : Bytes,
) -> String =
  #| (beforeBytes, afterBytes) => {
  #|   try {
  #|     const toRaw = (value) => value instanceof Uint8Array
  #|       ? value
  #|       : (Array.isArray(value) ? Uint8Array.from(value) : new Uint8Array(value));
  #|     const normalize = (value) =>
  #|       typeof value === 'bigint' ? value.toString() + 'n' : String(value);
  #|     const buildImports = () => {
  #|       const memory = new WebAssembly.Memory({ initial: 256, maximum: 256 });
  #|       const table = new WebAssembly.Table({ element: 'anyfunc', initial: 32 });
  #|       const sbrkPtr = 1024;
  #|       new DataView(memory.buffer).setInt32(sbrkPtr, 8192, true);
  #|       return {
  #|         env: {
  #|           memory,
  #|           __indirect_function_table: table,
  #|           exit: (code) => code | 0,
  #|           abort: () => {
  #|             throw new Error('abort');
  #|           },
  #|           emscripten_get_sbrk_ptr: () => sbrkPtr,
  #|           emscripten_resize_heap: () => 0,
  #|           emscripten_memcpy_big: (dst, src, num) => {
  #|             const view = new Uint8Array(memory.buffer);
  #|             view.copyWithin(dst >>> 0, src >>> 0, (src + num) >>> 0);
  #|             return dst | 0;
  #|           },
  #|         },
  #|         wasi_snapshot_preview1: {
  #|           fd_seek: () => 0,
  #|           fd_close: () => 0,
  #|           fd_write: () => 0,
  #|         },
  #|       };
  #|     };
  #|     const invokeWithStubs = (raw) => {
  #|       const module = new WebAssembly.Module(toRaw(raw));
  #|       const instance = new WebAssembly.Instance(module, buildImports());
  #|       const ex = instance.exports;
  #|       const out = [];
  #|       const invoke = (name, args) => {
  #|         const fn = ex[name];
  #|         if (typeof fn !== 'function') {
  #|           out.push(name + '=missing');
  #|           return undefined;
  #|         }
  #|         try {
  #|           const value = fn(...args);
  #|           out.push(name + '=ok:' + normalize(value));
  #|           return value;
  #|         } catch (e) {
  #|           const msg = e && e.message ? e.message : String(e);
  #|           out.push(name + '=err:' + msg);
  #|           return undefined;
  #|         }
  #|       };
  #|       if (ex.__data_end && typeof ex.__data_end.value !== 'undefined') {
  #|         out.push('__data_end=' + normalize(ex.__data_end.value));
  #|       } else {
  #|         out.push('__data_end=missing');
  #|       }
  #|       invoke('__wasm_call_ctors', []);
  #|       invoke('__errno_location', []);
  #|       const mallocResult = invoke('malloc', [64]);
  #|       let freePtr = 0;
  #|       if (typeof mallocResult === 'number' && Number.isFinite(mallocResult)) {
  #|         freePtr = mallocResult | 0;
  #|       }
  #|       invoke('free', [freePtr]);
  #|       invoke('setThrew', [1, 2]);
  #|       return out.join(';');
  #|     };
  #|     const before = invokeWithStubs(beforeBytes);
  #|     const after = invokeWithStubs(afterBytes);
  #|     return 'ok|' + (before === after ? '1' : '0') + '|' + before + '|' + after;
  #|   } catch (e) {
  #|     const msg = e && e.message ? e.message : String(e);
  #|     return 'err|' + msg;
  #|   }
  #| }

///|
extern "js" fn js_compare_zero_arg_export_behaviors(
  before_bytes : Bytes,
  after_bytes : Bytes,
) -> String =
  #| (beforeBytes, afterBytes) => {
  #|   try {
  #|     const toRaw = (value) => value instanceof Uint8Array
  #|       ? value
  #|       : (Array.isArray(value) ? Uint8Array.from(value) : new Uint8Array(value));
  #|     const normalize = (value) =>
  #|       typeof value === 'bigint' ? value.toString() + 'n' : String(value);
  #|     const instantiate = (raw) => {
  #|       const module = new WebAssembly.Module(toRaw(raw));
  #|       const importDescs = WebAssembly.Module.imports(module);
  #|       const imports = {};
  #|       const ensureBucket = (name) => {
  #|         if (!imports[name]) imports[name] = {};
  #|         return imports[name];
  #|       };
  #|       let envMemory = null;
  #|       let sbrkPtr = 1024;
  #|       const ensureSbrk = () => {
  #|         if (!envMemory) return;
  #|         if (envMemory.buffer.byteLength < sbrkPtr + 4) return;
  #|         new DataView(envMemory.buffer).setInt32(sbrkPtr, 8192, true);
  #|       };
  #|       for (const imp of importDescs) {
  #|         const bucket = ensureBucket(imp.module);
  #|         if (imp.kind === 'memory') {
  #|           const minimum = Math.max(1, Number(imp.minimum ?? 1));
  #|           const maximum = imp.maximum == null ? minimum : Math.max(minimum, Number(imp.maximum));
  #|           const memory = new WebAssembly.Memory({ initial: minimum, maximum });
  #|           bucket[imp.name] = memory;
  #|           if (imp.module === 'env' && imp.name === 'memory') {
  #|             envMemory = memory;
  #|           }
  #|         } else if (imp.kind === 'table') {
  #|           const minimum = Math.max(1, Number(imp.minimum ?? 1));
  #|           const tableInit = {
  #|             element: imp.element ?? 'anyfunc',
  #|             initial: minimum,
  #|           };
  #|           if (imp.maximum != null) {
  #|             tableInit.maximum = Math.max(minimum, Number(imp.maximum));
  #|           }
  #|           bucket[imp.name] = new WebAssembly.Table(tableInit);
  #|         } else if (imp.kind === 'global') {
  #|           const value = imp.value ?? 'i32';
  #|           const mutable = !!imp.mutable;
  #|           const init = value === 'i64' ? 0n : 0;
  #|           bucket[imp.name] = new WebAssembly.Global({ value, mutable }, init);
  #|         }
  #|       }
  #|       if (!envMemory) {
  #|         envMemory = new WebAssembly.Memory({ initial: 256, maximum: 256 });
  #|         ensureBucket('env').memory = envMemory;
  #|       }
  #|       ensureSbrk();
  #|       for (const imp of importDescs) {
  #|         if (imp.kind !== 'function') continue;
  #|         const bucket = ensureBucket(imp.module);
  #|         if (typeof bucket[imp.name] === 'function') continue;
  #|         const key = imp.module + '.' + imp.name;
  #|         if (key === 'env.abort') {
  #|           bucket[imp.name] = () => { throw new Error('abort'); };
  #|         } else if (key === 'env.exit') {
  #|           bucket[imp.name] = (code) => code | 0;
  #|         } else if (key === 'env.emscripten_get_sbrk_ptr') {
  #|           bucket[imp.name] = () => sbrkPtr;
  #|         } else if (key === 'env.emscripten_resize_heap') {
  #|           bucket[imp.name] = () => 0;
  #|         } else if (key === 'env.emscripten_memcpy_big') {
  #|           bucket[imp.name] = (dst, src, num) => {
  #|             if (envMemory) {
  #|               const view = new Uint8Array(envMemory.buffer);
  #|               view.copyWithin(dst >>> 0, src >>> 0, (src + num) >>> 0);
  #|             }
  #|             return dst | 0;
  #|           };
  #|         } else if (imp.module === 'wasi_snapshot_preview1') {
  #|           bucket[imp.name] = () => 0;
  #|         } else {
  #|           bucket[imp.name] = () => 0;
  #|         }
  #|       }
  #|       return new WebAssembly.Instance(module, imports);
  #|     };
  #|     const run = (raw) => {
  #|       const instance = instantiate(raw);
  #|       const out = [];
  #|       const names = Object.keys(instance.exports).sort();
  #|       for (const name of names) {
  #|         const value = instance.exports[name];
  #|         if (typeof value !== 'function') continue;
  #|         if (value.length !== 0) continue;
  #|         try {
  #|           out.push(name + '=ok:' + normalize(value()));
  #|         } catch (e) {
  #|           const msg = e && e.message ? e.message : String(e);
  #|           out.push(name + '=err:' + msg);
  #|         }
  #|       }
  #|       if (out.length === 0) {
  #|         out.push('no-zero-arg-export');
  #|       }
  #|       return out.join(';');
  #|     };
  #|     const before = run(beforeBytes);
  #|     const after = run(afterBytes);
  #|     return 'ok|' + (before === after ? '1' : '0') + '|' + before + '|' + after;
  #|   } catch (e) {
  #|     const msg = e && e.message ? e.message : String(e);
  #|     return 'err|' + msg;
  #|   }
  #| }

///|
fn runtime_export_outputs_equal(
  before_bytes : Bytes,
  after_bytes : Bytes,
  export_name : String,
  args : Array[Int],
) -> Bool {
  let raw = js_compare_export_runtime_outputs(
    before_bytes,
    after_bytes,
    export_name,
    join_int_csv(args),
  )
  let parts = split_string(raw, "|")
  if parts.length() < 2 {
    return false
  }
  if parts[0] != "ok" {
    return false
  }
  parts[1] == "1"
}

///|
fn runtime_zlib_behaviors_equal(
  before_bytes : Bytes,
  after_bytes : Bytes,
) -> Bool {
  let raw = js_compare_zlib_runtime_behaviors(before_bytes, after_bytes)
  let parts = split_string(raw, "|")
  if parts.length() < 2 {
    return false
  }
  if parts[0] != "ok" {
    return false
  }
  parts[1] == "1"
}

///|
fn runtime_zero_arg_export_behaviors_equal(
  before_bytes : Bytes,
  after_bytes : Bytes,
) -> Bool {
  let raw = js_compare_zero_arg_export_behaviors(before_bytes, after_bytes)
  let parts = split_string(raw, "|")
  if parts.length() < 2 {
    return false
  }
  if parts[0] != "ok" {
    return false
  }
  parts[1] == "1"
}

///|
fn bench_core_corpus_paths() -> Array[String] {
  [
    "bench/corpus/core/binaryen/br_to_exit.wasm", "bench/corpus/core/binaryen/elided-br.wasm",
    "bench/corpus/core/binaryen/complexBinaryNames.wasm", "bench/corpus/core/binaryen/empty.wasm",
    "bench/corpus/core/binaryen/gc_target_feature.wasm", "bench/corpus/core/binaryen/zlib.wasm",
  ]
}

///|
fn bench_core_runtime_corpus_paths() -> Array[String] {
  [
    "bench/corpus/core/binaryen/br_to_exit.wasm", "bench/corpus/core/binaryen/elided-br.wasm",
    "bench/corpus/core/binaryen/complexBinaryNames.wasm", "bench/corpus/core/binaryen/empty.wasm",
    "bench/corpus/core/binaryen/zlib.wasm",
  ]
}

///|
fn bench_component_corpus_paths() -> Array[String] {
  [
    "bench/corpus/component/wac/dummy_wasi_http_0.2.0.wasm", "bench/corpus/component/wac/dummy_wasi_http_0.2.3.wasm",
  ]
}

///|
fn bench_component_dce_corpus_paths() -> Array[String] {
  [
    "bench/corpus/component-dce/mwac/hello.component.wasm", "bench/corpus/component-dce/mwac/wac_hello.wasm",
    "bench/corpus/component-dce/mwac/wac_greeter.wasm",
  ]
}

///|
fn has_component_export(
  exports : Array[@mwac_component.ExportInfo],
  name : Bytes,
  kind : @mwac_component.ExternKind,
) -> Bool {
  for e in exports {
    if e.kind == kind && e.name == name {
      return true
    }
  }
  false
}

///|
fn component_dce_kpi_optimize_config(roots : Array[String]) -> OptimizeConfig {
  make_optimize_config(
    strip_all_custom=false,
    strip_name_section=false,
    strip_producers_section=false,
    strip_debug_sections=false,
    strip_dwarf_sections=false,
    strip_target_features_section=false,
    pass_rounds=1U,
    enable_peephole=false,
    peephole_remove_nop=false,
    peephole_remove_const_drop=false,
    enable_vacuum=false,
    enable_merge_blocks=false,
    enable_remove_unused_brs=false,
    enable_dce=true,
    enable_dfe=false,
    enable_merge_similar_functions=false,
    enable_remove_unused_module_elements=true,
    closed_world=true,
    closed_world_root_exports=roots,
    safe_mode=false,
  )
}

///|
fn component_gc_optimize_config(roots : Array[String]) -> OptimizeConfig {
  make_optimize_config(
    strip_all_custom=false,
    strip_name_section=false,
    strip_producers_section=false,
    strip_debug_sections=false,
    strip_dwarf_sections=false,
    strip_target_features_section=false,
    pass_rounds=1U,
    enable_peephole=false,
    peephole_remove_nop=false,
    peephole_remove_const_drop=false,
    enable_vacuum=false,
    enable_merge_blocks=false,
    enable_remove_unused_brs=false,
    enable_dce=true,
    enable_dfe=true,
    enable_merge_similar_functions=false,
    enable_remove_unused_module_elements=true,
    closed_world=true,
    closed_world_root_exports=roots,
    safe_mode=false,
  )
}

///|
fn sample_component_with_single_core_module(core_bytes : Bytes) -> Bytes {
  let out = bytes_of([0x00, 0x61, 0x73, 0x6d, 0x0d, 0x00, 0x01, 0x00])
  append_section(out, 1U, core_bytes.to_array())
  Bytes::from_array(out[:])
}

///|
fn sample_module_bytes() -> Bytes {
  let out = bytes_of([0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00])

  // type section: 1 func type () -> ()
  append_section(out, 1U, bytes_of([0x01, 0x60, 0x00, 0x00]))
  // function section: 1 function -> type idx 0
  append_section(out, 3U, bytes_of([0x01, 0x00]))
  // export section: export func 0 as "run"
  append_section(out, 7U, bytes_of([0x01, 0x03, 0x72, 0x75, 0x6e, 0x00, 0x00]))
  // code section: 1 body, size=2, local decl count=0, end
  append_section(out, 10U, bytes_of([0x01, 0x02, 0x00, 0x0b]))

  // custom sections
  append_section(out, 0U, bytes_of([0x04, 0x6e, 0x61, 0x6d, 0x65, 0x00]))
  append_section(
    out,
    0U,
    bytes_of([0x09, 0x70, 0x72, 0x6f, 0x64, 0x75, 0x63, 0x65, 0x72, 0x73, 0x01]),
  )
  Bytes::from_array(out[:])
}

///|
fn sample_module_with_peephole_bytes() -> Bytes {
  let out = bytes_of([0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00])

  // type section: 1 func type () -> (i32)
  append_section(out, 1U, bytes_of([0x01, 0x60, 0x00, 0x01, 0x7f]))
  // function section: 1 function -> type idx 0
  append_section(out, 3U, bytes_of([0x01, 0x00]))
  // export section: export func 0 as "run"
  append_section(out, 7U, bytes_of([0x01, 0x03, 0x72, 0x75, 0x6e, 0x00, 0x00]))
  // code section body: local decl count=0, nop, i32.const 0, drop, i32.const 42, end
  append_section(
    out,
    10U,
    bytes_of([0x01, 0x08, 0x00, 0x01, 0x41, 0x00, 0x1a, 0x41, 0x2a, 0x0b]),
  )
  Bytes::from_array(out[:])
}

///|
fn sample_module_with_misc_custom_sections_bytes() -> Bytes {
  let out = bytes_of([0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00])

  // type section: 1 func type () -> ()
  append_section(out, 1U, bytes_of([0x01, 0x60, 0x00, 0x00]))
  // function section: 1 function -> type idx 0
  append_section(out, 3U, bytes_of([0x01, 0x00]))
  // export section: export func 0 as "run"
  append_section(out, 7U, bytes_of([0x01, 0x03, 0x72, 0x75, 0x6e, 0x00, 0x00]))
  // code section: 1 body, size=2, local decl count=0, end
  append_section(out, 10U, bytes_of([0x01, 0x02, 0x00, 0x0b]))
  append_named_custom_section(out, "sourceMappingURL", [0x00])
  append_named_custom_section(out, ".debug_info", [0x00])
  append_named_custom_section(out, "target_features", [0x00])
  append_named_custom_section(out, "keepme", [0x00])
  Bytes::from_array(out[:])
}

///|
fn sample_module_with_named_functions_bytes() -> Bytes {
  let out = bytes_of([0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00])

  // type section: 1 func type () -> ()
  append_section(out, 1U, bytes_of([0x01, 0x60, 0x00, 0x00]))
  // import section: import func env.imp type 0
  append_section(
    out,
    2U,
    bytes_of([0x01, 0x03, 0x65, 0x6e, 0x76, 0x03, 0x69, 0x6d, 0x70, 0x00, 0x00]),
  )
  // function section: 2 local functions -> type idx 0
  append_section(out, 3U, bytes_of([0x02, 0x00, 0x00]))
  // export section: export func idx 1 as "small", idx 2 as "large"
  append_section(
    out,
    7U,
    bytes_of([
      0x02, 0x05, 0x73, 0x6d, 0x61, 0x6c, 0x6c, 0x00, 0x01, 0x05, 0x6c, 0x61, 0x72,
      0x67, 0x65, 0x00, 0x02,
    ]),
  )
  // code section:
  //   body#0 size=2  (0 locals + end)
  //   body#1 size=5  (0 locals + i32.const 1 + drop + end)
  append_section(
    out,
    10U,
    bytes_of([0x02, 0x02, 0x00, 0x0b, 0x05, 0x00, 0x41, 0x01, 0x1a, 0x0b]),
  )
  // custom name section:
  //   function names subsection(id=1)
  //   index 1 -> "small", index 2 -> "large"
  append_section(
    out,
    0U,
    bytes_of([
      0x04, 0x6e, 0x61, 0x6d, 0x65, 0x01, 0x0f, 0x02, 0x01, 0x05, 0x73, 0x6d, 0x61,
      0x6c, 0x6c, 0x02, 0x05, 0x6c, 0x61, 0x72, 0x67, 0x65,
    ]),
  )
  Bytes::from_array(out[:])
}

///|
fn sample_module_with_hot_size_runtime_gap_bytes() -> Bytes {
  let out = bytes_of([0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00])

  // type section: 1 func type () -> ()
  append_section(out, 1U, bytes_of([0x01, 0x60, 0x00, 0x00]))
  // function section: 2 local functions
  append_section(out, 3U, bytes_of([0x02, 0x00, 0x00]))
  // export section: export idx 0 as "light", idx 1 as "heavy"
  append_section(
    out,
    7U,
    bytes_of([
      0x02, 0x05, 0x6c, 0x69, 0x67, 0x68, 0x74, 0x00, 0x00, 0x05, 0x68, 0x65, 0x61,
      0x76, 0x79, 0x00, 0x01,
    ]),
  )
  // code section:
  //   #0 light body: locals=0, end
  //   #1 heavy body: locals=0, (i32.const 0; drop) * 20, end
  let heavy_body : Array[Int] = [0x00]
  for _ in 0..<20 {
    heavy_body.push(0x41)
    heavy_body.push(0x00)
    heavy_body.push(0x1a)
  }
  heavy_body.push(0x0b)
  let code_payload : Array[Byte] = bytes_of([0x02, 0x02, 0x00, 0x0b])
  code_payload.push(heavy_body.length().reinterpret_as_uint().to_byte())
  code_payload.append(bytes_of(heavy_body)[:])
  append_section(out, 10U, code_payload)
  Bytes::from_array(out[:])
}

///|
fn sample_module_with_nested_blocks_bytes() -> Bytes {
  let out = bytes_of([0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00])

  // type section: 1 func type () -> ()
  append_section(out, 1U, bytes_of([0x01, 0x60, 0x00, 0x00]))
  // function section: 1 local function
  append_section(out, 3U, bytes_of([0x01, 0x00]))
  // export section: export index 0 as "run"
  append_section(out, 7U, bytes_of([0x01, 0x03, 0x72, 0x75, 0x6e, 0x00, 0x00]))
  // code section body:
  // local decl count=0
  // block
  //   loop
  //     i32.const 0
  //     br_if 0
  //   end
  // end
  // end(function)
  append_section(
    out,
    10U,
    bytes_of([
      0x01, 0x0c, 0x00, 0x02, 0x40, 0x03, 0x40, 0x41, 0x00, 0x0d, 0x00, 0x0b, 0x0b,
      0x0b,
    ]),
  )
  Bytes::from_array(out[:])
}

///|
fn sample_module_with_dead_function_bytes() -> Bytes {
  let out = bytes_of([0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00])

  // type section: 1 func type () -> ()
  append_section(out, 1U, bytes_of([0x01, 0x60, 0x00, 0x00]))
  // import section: import func env.imp type 0 (function index 0)
  append_section(
    out,
    2U,
    bytes_of([0x01, 0x03, 0x65, 0x6e, 0x76, 0x03, 0x69, 0x6d, 0x70, 0x00, 0x00]),
  )
  // function section: 3 local functions (indices 1,2,3)
  append_section(out, 3U, bytes_of([0x03, 0x00, 0x00, 0x00]))
  // export section: export index 1 as "main"
  append_section(
    out,
    7U,
    bytes_of([0x01, 0x04, 0x6d, 0x61, 0x69, 0x6e, 0x00, 0x01]),
  )
  // code section:
  // #1: call 2, end (size=4)
  // #2: end (size=2)
  // #3: i32.const 1, drop, end (size=5) dead
  append_section(
    out,
    10U,
    bytes_of([
      0x03, 0x04, 0x00, 0x10, 0x02, 0x0b, 0x02, 0x00, 0x0b, 0x05, 0x00, 0x41, 0x01,
      0x1a, 0x0b,
    ]),
  )
  // name section: function names for local functions
  append_section(
    out,
    0U,
    bytes_of([
      0x04, 0x6e, 0x61, 0x6d, 0x65, 0x01, 0x15, 0x03, 0x01, 0x09, 0x6d, 0x61, 0x69,
      0x6e, 0x5f, 0x69, 0x6d, 0x70, 0x6c, 0x02, 0x06, 0x68, 0x65, 0x6c, 0x70, 0x65,
      0x72, 0x03, 0x04, 0x64, 0x65, 0x61, 0x64,
    ]),
  )
  Bytes::from_array(out[:])
}

///|
fn sample_module_with_two_exported_functions_bytes() -> Bytes {
  let out = bytes_of([0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00])

  // type section: 1 func type () -> ()
  append_section(out, 1U, bytes_of([0x01, 0x60, 0x00, 0x00]))
  // function section: 2 local functions
  append_section(out, 3U, bytes_of([0x02, 0x00, 0x00]))
  // export section: export index 0 as "keep", index 1 as "drop"
  append_section(
    out,
    7U,
    bytes_of([
      0x02, 0x04, 0x6b, 0x65, 0x65, 0x70, 0x00, 0x00, 0x04, 0x64, 0x72, 0x6f, 0x70,
      0x00, 0x01,
    ]),
  )
  // code section: 2 bodies, each is (locals=0, end)
  append_section(out, 10U, bytes_of([0x02, 0x02, 0x00, 0x0b, 0x02, 0x00, 0x0b]))
  Bytes::from_array(out[:])
}

///|
fn sample_module_with_fc_opcode_bytes() -> Bytes {
  let out = bytes_of([0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00])

  // type section: 1 func type () -> ()
  append_section(out, 1U, bytes_of([0x01, 0x60, 0x00, 0x00]))
  // function section: 1 local function
  append_section(out, 3U, bytes_of([0x01, 0x00]))
  // export section: export index 0 as "run"
  append_section(out, 7U, bytes_of([0x01, 0x03, 0x72, 0x75, 0x6e, 0x00, 0x00]))
  // code section:
  // local decl count=0
  // f32.const 1.0
  // i32.trunc_sat_f32_s (0xfc 0x00)
  // drop
  // end
  append_section(
    out,
    10U,
    bytes_of([
      0x01, 0x0a, 0x00, 0x43, 0x00, 0x00, 0x80, 0x3f, 0xfc, 0x00, 0x1a, 0x0b,
    ]),
  )
  Bytes::from_array(out[:])
}

///|
fn sample_module_with_fd_memarg_bytes() -> Bytes {
  let out = bytes_of([0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00])

  // type section: 1 func type () -> ()
  append_section(out, 1U, bytes_of([0x01, 0x60, 0x00, 0x00]))
  // function section: 1 local function
  append_section(out, 3U, bytes_of([0x01, 0x00]))
  // memory section: 1 memory min=1
  append_section(out, 5U, bytes_of([0x01, 0x00, 0x01]))
  // export section: export index 0 as "run"
  append_section(out, 7U, bytes_of([0x01, 0x03, 0x72, 0x75, 0x6e, 0x00, 0x00]))
  // code section:
  // local decl count=0
  // i32.const 0
  // v128.load align=0 offset=0 (0xfd 0x00 0x00 0x00)
  // drop
  // end
  append_section(
    out,
    10U,
    bytes_of([0x01, 0x09, 0x00, 0x41, 0x00, 0xfd, 0x00, 0x00, 0x00, 0x1a, 0x0b]),
  )
  Bytes::from_array(out[:])
}

///|
fn sample_module_with_dce_reindex_bytes() -> Bytes {
  let out = bytes_of([0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00])

  // type section: 1 func type () -> ()
  append_section(out, 1U, bytes_of([0x01, 0x60, 0x00, 0x00]))
  // function section: 3 local functions (indices 0,1,2)
  append_section(out, 3U, bytes_of([0x03, 0x00, 0x00, 0x00]))
  // export section: export index 0 as "main"
  append_section(
    out,
    7U,
    bytes_of([0x01, 0x04, 0x6d, 0x61, 0x69, 0x6e, 0x00, 0x00]),
  )
  // code section:
  // #0: call 2, end (size=4)
  // #1: end (size=2) dead
  // #2: end (size=2)
  append_section(
    out,
    10U,
    bytes_of([
      0x03, 0x04, 0x00, 0x10, 0x02, 0x0b, 0x02, 0x00, 0x0b, 0x02, 0x00, 0x0b,
    ]),
  )
  Bytes::from_array(out[:])
}

///|
fn sample_module_with_dce_reindex_result_bytes() -> Bytes {
  let out = bytes_of([0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00])

  // type section: 1 func type () -> (i32)
  append_section(out, 1U, bytes_of([0x01, 0x60, 0x00, 0x01, 0x7f]))
  // function section: 3 local functions (indices 0,1,2)
  append_section(out, 3U, bytes_of([0x03, 0x00, 0x00, 0x00]))
  // export section: export index 0 as "main"
  append_section(
    out,
    7U,
    bytes_of([0x01, 0x04, 0x6d, 0x61, 0x69, 0x6e, 0x00, 0x00]),
  )
  // code section:
  // #0: call 2, end (size=4)
  // #1: i32.const 99, end (size=4) dead
  // #2: i32.const 7, end (size=4)
  append_section(
    out,
    10U,
    bytes_of([
      0x03, 0x04, 0x00, 0x10, 0x02, 0x0b, 0x04, 0x00, 0x41, 0x63, 0x0b, 0x04, 0x00,
      0x41, 0x07, 0x0b,
    ]),
  )
  Bytes::from_array(out[:])
}

///|
fn sample_module_with_duplicate_functions_bytes() -> Bytes {
  let out = bytes_of([0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00])

  // type section: 1 func type () -> ()
  append_section(out, 1U, bytes_of([0x01, 0x60, 0x00, 0x00]))
  // function section: 3 local functions (indices 0,1,2)
  append_section(out, 3U, bytes_of([0x03, 0x00, 0x00, 0x00]))
  // export section: export main and alias (alias points duplicated function index 2)
  append_section(
    out,
    7U,
    bytes_of([
      0x02, 0x04, 0x6d, 0x61, 0x69, 0x6e, 0x00, 0x00, 0x05, 0x61, 0x6c, 0x69, 0x61,
      0x73, 0x00, 0x02,
    ]),
  )
  // code section:
  // #0: call 1, call 2, end
  // #1: end
  // #2: end (duplicate body/type with #1)
  append_section(
    out,
    10U,
    bytes_of([
      0x03, 0x06, 0x00, 0x10, 0x01, 0x10, 0x02, 0x0b, 0x02, 0x00, 0x0b, 0x02, 0x00,
      0x0b,
    ]),
  )
  Bytes::from_array(out[:])
}

///|
fn sample_module_with_duplicate_functions_but_split_types_bytes() -> Bytes {
  let out = bytes_of([0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00])

  // type section: 2 duplicated func types () -> ()
  append_section(out, 1U, bytes_of([0x02, 0x60, 0x00, 0x00, 0x60, 0x00, 0x00]))
  // function section: 2 local functions with split type indices [0,1]
  append_section(out, 3U, bytes_of([0x02, 0x00, 0x01]))
  // export section: export both functions
  append_section(
    out,
    7U,
    bytes_of([
      0x02, 0x04, 0x6d, 0x61, 0x69, 0x6e, 0x00, 0x00, 0x05, 0x61, 0x6c, 0x69, 0x61,
      0x73, 0x00, 0x01,
    ]),
  )
  // code section:
  // #0: end
  // #1: end (duplicate body, different type index)
  append_section(out, 10U, bytes_of([0x02, 0x02, 0x00, 0x0b, 0x02, 0x00, 0x0b]))
  Bytes::from_array(out[:])
}

///|
fn sample_module_with_duplicate_functions_but_split_types_and_gc_bytes() -> Bytes {
  let out = bytes_of([0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00])

  // type section:
  //   #0 struct(i32)
  //   #1 () -> ()
  //   #2 () -> ()  (duplicate of #1)
  append_section(
    out,
    1U,
    bytes_of([0x03, 0x5f, 0x01, 0x7f, 0x00, 0x60, 0x00, 0x00, 0x60, 0x00, 0x00]),
  )
  // function section: 2 local functions with split type indices [1,2]
  append_section(out, 3U, bytes_of([0x02, 0x01, 0x02]))
  // export section: export both functions
  append_section(
    out,
    7U,
    bytes_of([
      0x02, 0x04, 0x6d, 0x61, 0x69, 0x6e, 0x00, 0x00, 0x05, 0x61, 0x6c, 0x69, 0x61,
      0x73, 0x00, 0x01,
    ]),
  )
  // code section: identical bodies
  append_section(out, 10U, bytes_of([0x02, 0x02, 0x00, 0x0b, 0x02, 0x00, 0x0b]))
  Bytes::from_array(out[:])
}

///|
fn sample_module_with_gc_hierarchy_duplicate_function_types_bytes() -> Bytes {
  let out = bytes_of([0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00])

  // type section:
  //   #0 struct(i32)
  //   #1 struct(i32)  (duplicate of #0)
  //   #2 () -> ()
  //   #3 (ref null #0) -> ()
  //   #4 (ref null #1) -> ()
  append_section(
    out,
    1U,
    bytes_of([
      0x05, 0x5f, 0x01, 0x7f, 0x00, 0x5f, 0x01, 0x7f, 0x00, 0x60, 0x00, 0x00, 0x60,
      0x01, 0x63, 0x00, 0x00, 0x60, 0x01, 0x63, 0x01, 0x00,
    ]),
  )
  // function section: 3 local functions with type indices [2,3,4]
  append_section(out, 3U, bytes_of([0x03, 0x02, 0x03, 0x04]))
  // export section: export run/a/b
  append_section(
    out,
    7U,
    bytes_of([
      0x03, 0x03, 0x72, 0x75, 0x6e, 0x00, 0x00, 0x01, 0x61, 0x00, 0x01, 0x01, 0x62,
      0x00, 0x02,
    ]),
  )
  // code section:
  // #0: end
  // #1: local.get 0; drop; end
  // #2: local.get 0; drop; end
  append_section(
    out,
    10U,
    bytes_of([
      0x03, 0x02, 0x00, 0x0b, 0x05, 0x00, 0x20, 0x00, 0x1a, 0x0b, 0x05, 0x00, 0x20,
      0x00, 0x1a, 0x0b,
    ]),
  )
  Bytes::from_array(out[:])
}

///|
fn sample_module_with_signature_pruning_candidate_bytes() -> Bytes {
  let out = bytes_of([0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00])

  // type section:
  //   #0 () -> ()
  //   #1 (i32, i32) -> ()
  append_section(
    out,
    1U,
    bytes_of([0x02, 0x60, 0x00, 0x00, 0x60, 0x02, 0x7f, 0x7f, 0x00]),
  )
  // function section: 2 locals with type indices [0, 1]
  append_section(out, 3U, bytes_of([0x02, 0x00, 0x01]))
  // export section: export function #0 as "main"
  append_section(
    out,
    7U,
    bytes_of([0x01, 0x04, 0x6d, 0x61, 0x69, 0x6e, 0x00, 0x00]),
  )
  // code section:
  // #0: i32.const 1, i32.const 2, call 1, end
  // #1: local.get 0, drop, end  (param#1 is unused)
  append_section(
    out,
    10U,
    bytes_of([
      0x02, 0x08, 0x00, 0x41, 0x01, 0x41, 0x02, 0x10, 0x01, 0x0b, 0x05, 0x00, 0x20,
      0x00, 0x1a, 0x0b,
    ]),
  )
  Bytes::from_array(out[:])
}

///|
fn sample_module_with_inlining_const_callee_bytes() -> Bytes {
  let out = bytes_of([0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00])

  // type section: 1 func type () -> (i32)
  append_section(out, 1U, bytes_of([0x01, 0x60, 0x00, 0x01, 0x7f]))
  // function section: 2 local functions with type idx 0
  append_section(out, 3U, bytes_of([0x02, 0x00, 0x00]))
  // export section: export func 0 as "run"
  append_section(out, 7U, bytes_of([0x01, 0x03, 0x72, 0x75, 0x6e, 0x00, 0x00]))
  // code section:
  // #0: call 1, end
  // #1: i32.const 42, end
  append_section(
    out,
    10U,
    bytes_of([0x02, 0x04, 0x00, 0x10, 0x01, 0x0b, 0x04, 0x00, 0x41, 0x2a, 0x0b]),
  )
  Bytes::from_array(out[:])
}

///|
fn sample_module_with_dae_expression_drop_bytes() -> Bytes {
  let out = bytes_of([0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00])

  // type section:
  //   #0 () -> ()
  //   #1 (i32, i32) -> ()
  append_section(
    out,
    1U,
    bytes_of([0x02, 0x60, 0x00, 0x00, 0x60, 0x02, 0x7f, 0x7f, 0x00]),
  )
  // function section: 2 local functions [0, 1]
  append_section(out, 3U, bytes_of([0x02, 0x00, 0x01]))
  // export section: export func 0 as "run"
  append_section(out, 7U, bytes_of([0x01, 0x03, 0x72, 0x75, 0x6e, 0x00, 0x00]))
  // code section:
  // #0: i32.const 1, i32.const 10, i32.const 20, i32.add, call 1, end
  // #1: local.get 0, drop, end (param#1 is unused)
  append_section(
    out,
    10U,
    bytes_of([
      0x02, 0x0b, 0x00, 0x41, 0x01, 0x41, 0x0a, 0x41, 0x14, 0x6a, 0x10, 0x01, 0x0b,
      0x05, 0x00, 0x20, 0x00, 0x1a, 0x0b,
    ]),
  )
  Bytes::from_array(out[:])
}

///|
fn sample_module_with_i32_add_precompute_bytes() -> Bytes {
  let out = bytes_of([0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00])

  // type section: 1 func type () -> (i32)
  append_section(out, 1U, bytes_of([0x01, 0x60, 0x00, 0x01, 0x7f]))
  // function section: 1 local function
  append_section(out, 3U, bytes_of([0x01, 0x00]))
  // export section: export index 0 as "run"
  append_section(out, 7U, bytes_of([0x01, 0x03, 0x72, 0x75, 0x6e, 0x00, 0x00]))
  // code section body:
  // local decl count=0
  // i32.const 20
  // i32.const 22
  // i32.add
  // end
  append_section(
    out,
    10U,
    bytes_of([0x01, 0x07, 0x00, 0x41, 0x14, 0x41, 0x16, 0x6a, 0x0b]),
  )
  Bytes::from_array(out[:])
}

///|
fn sample_module_with_local_set_get_pair_bytes() -> Bytes {
  let out = bytes_of([0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00])

  // type section: 1 func type () -> (i32)
  append_section(out, 1U, bytes_of([0x01, 0x60, 0x00, 0x01, 0x7f]))
  // function section: 1 local function
  append_section(out, 3U, bytes_of([0x01, 0x00]))
  // export section: export index 0 as "run"
  append_section(out, 7U, bytes_of([0x01, 0x03, 0x72, 0x75, 0x6e, 0x00, 0x00]))
  // code section body:
  // local decl count=1, local group(count=1, i32)
  // i32.const 42
  // local.set 0
  // local.get 0
  // end
  append_section(
    out,
    10U,
    bytes_of([
      0x01, 0x0a, 0x01, 0x01, 0x7f, 0x41, 0x2a, 0x21, 0x00, 0x20, 0x00, 0x0b,
    ]),
  )
  Bytes::from_array(out[:])
}

///|
fn sample_module_with_local_get_drop_bytes() -> Bytes {
  let out = bytes_of([0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00])

  // type section: 1 func type (i32) -> ()
  append_section(out, 1U, bytes_of([0x01, 0x60, 0x01, 0x7f, 0x00]))
  // function section: 1 local function
  append_section(out, 3U, bytes_of([0x01, 0x00]))
  // export section: export index 0 as "run"
  append_section(out, 7U, bytes_of([0x01, 0x03, 0x72, 0x75, 0x6e, 0x00, 0x00]))
  // code section body:
  // local decl count=0
  // local.get 0
  // drop
  // end
  append_section(out, 10U, bytes_of([0x01, 0x05, 0x00, 0x20, 0x00, 0x1a, 0x0b]))
  Bytes::from_array(out[:])
}

///|
fn sample_module_with_local_tee_drop_bytes() -> Bytes {
  let out = bytes_of([0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00])

  // type section: 1 func type () -> ()
  append_section(out, 1U, bytes_of([0x01, 0x60, 0x00, 0x00]))
  // function section: 1 local function
  append_section(out, 3U, bytes_of([0x01, 0x00]))
  // export section: export index 0 as "run"
  append_section(out, 7U, bytes_of([0x01, 0x03, 0x72, 0x75, 0x6e, 0x00, 0x00]))
  // code section body:
  // local decl count=1, local group(count=1, i32)
  // i32.const 42
  // local.tee 0
  // drop
  // end
  append_section(
    out,
    10U,
    bytes_of([0x01, 0x09, 0x01, 0x01, 0x7f, 0x41, 0x2a, 0x22, 0x00, 0x1a, 0x0b]),
  )
  Bytes::from_array(out[:])
}

///|
fn sample_module_with_local_get_set_noop_bytes() -> Bytes {
  let out = bytes_of([0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00])

  // type section: 1 func type (i32) -> ()
  append_section(out, 1U, bytes_of([0x01, 0x60, 0x01, 0x7f, 0x00]))
  // function section: 1 local function
  append_section(out, 3U, bytes_of([0x01, 0x00]))
  // export section: export index 0 as "run"
  append_section(out, 7U, bytes_of([0x01, 0x03, 0x72, 0x75, 0x6e, 0x00, 0x00]))
  // code section body:
  // local decl count=0
  // local.get 0
  // local.set 0
  // end
  append_section(
    out,
    10U,
    bytes_of([0x01, 0x06, 0x00, 0x20, 0x00, 0x21, 0x00, 0x0b]),
  )
  Bytes::from_array(out[:])
}

///|
fn sample_module_with_local_get_tee_pair_bytes() -> Bytes {
  let out = bytes_of([0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00])

  // type section: 1 func type (i32) -> (i32)
  append_section(out, 1U, bytes_of([0x01, 0x60, 0x01, 0x7f, 0x01, 0x7f]))
  // function section: 1 local function
  append_section(out, 3U, bytes_of([0x01, 0x00]))
  // export section: export index 0 as "run"
  append_section(out, 7U, bytes_of([0x01, 0x03, 0x72, 0x75, 0x6e, 0x00, 0x00]))
  // code section body:
  // local decl count=0
  // local.get 0
  // local.tee 0
  // end
  append_section(
    out,
    10U,
    bytes_of([0x01, 0x06, 0x00, 0x20, 0x00, 0x22, 0x00, 0x0b]),
  )
  Bytes::from_array(out[:])
}

///|
fn sample_module_with_i32_identity_ops_bytes() -> Bytes {
  let out = bytes_of([0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00])

  // type section: 1 func type (i32) -> (i32)
  append_section(out, 1U, bytes_of([0x01, 0x60, 0x01, 0x7f, 0x01, 0x7f]))
  // function section: 1 local function
  append_section(out, 3U, bytes_of([0x01, 0x00]))
  // export section: export index 0 as "run"
  append_section(out, 7U, bytes_of([0x01, 0x03, 0x72, 0x75, 0x6e, 0x00, 0x00]))
  // code section body:
  // local decl count=0
  // local.get 0
  // i32.const 0
  // i32.add
  // i32.const 0
  // i32.sub
  // i32.const 1
  // i32.mul
  // end
  append_section(
    out,
    10U,
    bytes_of([
      0x01, 0x0d, 0x00, 0x20, 0x00, 0x41, 0x00, 0x6a, 0x41, 0x00, 0x6b, 0x41, 0x01,
      0x6c, 0x0b,
    ]),
  )
  Bytes::from_array(out[:])
}

///|
fn sample_module_with_optimize_instructions_bytes() -> Bytes {
  let out = bytes_of([0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00])

  // type section: 1 func type (i32) -> (i32)
  append_section(out, 1U, bytes_of([0x01, 0x60, 0x01, 0x7f, 0x01, 0x7f]))
  // function section: 1 local function
  append_section(out, 3U, bytes_of([0x01, 0x00]))
  // export section: export index 0 as "run"
  append_section(out, 7U, bytes_of([0x01, 0x03, 0x72, 0x75, 0x6e, 0x00, 0x00]))
  // code section body:
  // local decl count=0
  // local.get 0
  // i32.const 0
  // i32.or
  // i32.const 0
  // i32.shl
  // local.get 0
  // local.get 0
  // i32.xor
  // i32.or
  // end
  append_section(
    out,
    10U,
    bytes_of([
      0x01, 0x10, 0x00, 0x20, 0x00, 0x41, 0x00, 0x72, 0x41, 0x00, 0x74, 0x20, 0x00,
      0x20, 0x00, 0x73, 0x72, 0x0b,
    ]),
  )
  Bytes::from_array(out[:])
}

///|
fn sample_module_with_optimize_instructions_bitwise_cmp_bytes() -> Bytes {
  let out = bytes_of([0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00])

  // type section: 1 func type (i32) -> (i32)
  append_section(out, 1U, bytes_of([0x01, 0x60, 0x01, 0x7f, 0x01, 0x7f]))
  // function section: 1 local function
  append_section(out, 3U, bytes_of([0x01, 0x00]))
  // export section: export index 0 as "run"
  append_section(out, 7U, bytes_of([0x01, 0x03, 0x72, 0x75, 0x6e, 0x00, 0x00]))
  // code section body:
  // local decl count=0
  // local.get 0; i32.const 0; i32.lt_u; drop
  // local.get 0; i32.const 0; i32.ge_u; drop
  // local.get 0; i32.const 0; i32.and; drop
  // local.get 0; i32.const 0; i32.eq; i32.eqz
  // end
  append_section(
    out,
    10U,
    bytes_of([
      0x01, 0x1a, 0x00, 0x20, 0x00, 0x41, 0x00, 0x49, 0x1a, 0x20, 0x00, 0x41, 0x00,
      0x4f, 0x1a, 0x20, 0x00, 0x41, 0x00, 0x71, 0x1a, 0x20, 0x00, 0x41, 0x00, 0x46,
      0x45, 0x0b,
    ]),
  )
  Bytes::from_array(out[:])
}

///|
fn sample_module_with_optimize_instructions_const_first_bytes() -> Bytes {
  let out = bytes_of([0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00])

  // type section: 1 func type (i32) -> (i32)
  append_section(out, 1U, bytes_of([0x01, 0x60, 0x01, 0x7f, 0x01, 0x7f]))
  // function section: 1 local function
  append_section(out, 3U, bytes_of([0x01, 0x00]))
  // export section: export index 0 as "run"
  append_section(out, 7U, bytes_of([0x01, 0x03, 0x72, 0x75, 0x6e, 0x00, 0x00]))
  // code section body:
  // local decl count=0
  // i32.const 0; local.get 0; i32.eq; drop
  // i32.const 0; local.get 0; i32.ne; drop
  // i32.const 0; local.get 0; i32.or; drop
  // i32.const -1; local.get 0; i32.and
  // end
  append_section(
    out,
    10U,
    bytes_of([
      0x01, 0x19, 0x00, 0x41, 0x00, 0x20, 0x00, 0x46, 0x1a, 0x41, 0x00, 0x20, 0x00,
      0x47, 0x1a, 0x41, 0x00, 0x20, 0x00, 0x72, 0x1a, 0x41, 0x7f, 0x20, 0x00, 0x71,
      0x0b,
    ]),
  )
  Bytes::from_array(out[:])
}

///|
fn sample_module_with_local_cse_get_set_get_bytes() -> Bytes {
  let out = bytes_of([0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00])

  // type section: 1 func type (i32) -> (i32)
  append_section(out, 1U, bytes_of([0x01, 0x60, 0x01, 0x7f, 0x01, 0x7f]))
  // function section: 1 local function
  append_section(out, 3U, bytes_of([0x01, 0x00]))
  // export section: export index 0 as "run"
  append_section(out, 7U, bytes_of([0x01, 0x03, 0x72, 0x75, 0x6e, 0x00, 0x00]))
  // code section body:
  // local decl count=1, local group(count=1, i32) => local index #1
  // local.get 0
  // local.set 1
  // local.get 0
  // end
  append_section(
    out,
    10U,
    bytes_of([
      0x01, 0x0a, 0x01, 0x01, 0x7f, 0x20, 0x00, 0x21, 0x01, 0x20, 0x00, 0x0b,
    ]),
  )
  Bytes::from_array(out[:])
}

///|
fn sample_module_with_local_tee_set_same_bytes() -> Bytes {
  let out = bytes_of([0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00])

  // type section: 1 func type () -> ()
  append_section(out, 1U, bytes_of([0x01, 0x60, 0x00, 0x00]))
  // function section: 1 local function
  append_section(out, 3U, bytes_of([0x01, 0x00]))
  // export section: export index 0 as "run"
  append_section(out, 7U, bytes_of([0x01, 0x03, 0x72, 0x75, 0x6e, 0x00, 0x00]))
  // code section body:
  // local decl count=1, local group(count=1, i32)
  // i32.const 1
  // local.tee 0
  // local.set 0
  // end
  append_section(
    out,
    10U,
    bytes_of([
      0x01, 0x0a, 0x01, 0x01, 0x7f, 0x41, 0x01, 0x22, 0x00, 0x21, 0x00, 0x0b,
    ]),
  )
  Bytes::from_array(out[:])
}

///|
fn sample_module_with_local_chain_simplify_bytes() -> Bytes {
  let out = bytes_of([0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00])

  // type section: 1 func type (i32) -> ()
  append_section(out, 1U, bytes_of([0x01, 0x60, 0x01, 0x7f, 0x00]))
  // function section: 1 local function
  append_section(out, 3U, bytes_of([0x01, 0x00]))
  // export section: export index 0 as "run"
  append_section(out, 7U, bytes_of([0x01, 0x03, 0x72, 0x75, 0x6e, 0x00, 0x00]))
  // code section body:
  // local decl count=0
  // local.get 0
  // local.tee 0
  // local.set 0
  // end
  append_section(
    out,
    10U,
    bytes_of([0x01, 0x08, 0x00, 0x20, 0x00, 0x22, 0x00, 0x21, 0x00, 0x0b]),
  )
  Bytes::from_array(out[:])
}

///|
fn sample_module_with_br_if_const_zero_bytes() -> Bytes {
  let out = bytes_of([0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00])

  // type section: 1 func type () -> ()
  append_section(out, 1U, bytes_of([0x01, 0x60, 0x00, 0x00]))
  // function section: 1 local function
  append_section(out, 3U, bytes_of([0x01, 0x00]))
  // export section: export index 0 as "run"
  append_section(out, 7U, bytes_of([0x01, 0x03, 0x72, 0x75, 0x6e, 0x00, 0x00]))
  // code section body:
  // local decl count=0
  // block
  //   i32.const 0
  //   br_if 0
  // end
  // end
  append_section(
    out,
    10U,
    bytes_of([0x01, 0x09, 0x00, 0x02, 0x40, 0x41, 0x00, 0x0d, 0x00, 0x0b, 0x0b]),
  )
  Bytes::from_array(out[:])
}

///|
fn sample_module_with_br_if_const_nonzero_bytes() -> Bytes {
  let out = bytes_of([0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00])

  // type section: 1 func type () -> ()
  append_section(out, 1U, bytes_of([0x01, 0x60, 0x00, 0x00]))
  // function section: 1 local function
  append_section(out, 3U, bytes_of([0x01, 0x00]))
  // export section: export index 0 as "run"
  append_section(out, 7U, bytes_of([0x01, 0x03, 0x72, 0x75, 0x6e, 0x00, 0x00]))
  // code section body:
  // local decl count=0
  // block
  //   i32.const 1
  //   br_if 0
  // end
  // end
  append_section(
    out,
    10U,
    bytes_of([0x01, 0x09, 0x00, 0x02, 0x40, 0x41, 0x01, 0x0d, 0x00, 0x0b, 0x0b]),
  )
  Bytes::from_array(out[:])
}

///|
fn sample_module_with_double_eqz_br_if_bytes() -> Bytes {
  let out = bytes_of([0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00])

  // type section: 1 func type (i32) -> ()
  append_section(out, 1U, bytes_of([0x01, 0x60, 0x01, 0x7f, 0x00]))
  // function section: 1 local function
  append_section(out, 3U, bytes_of([0x01, 0x00]))
  // export section: export index 0 as "run"
  append_section(out, 7U, bytes_of([0x01, 0x03, 0x72, 0x75, 0x6e, 0x00, 0x00]))
  // code section body:
  // local decl count=0
  // block
  //   local.get 0
  //   i32.eqz
  //   i32.eqz
  //   br_if 0
  // end
  // end
  append_section(
    out,
    10U,
    bytes_of([
      0x01, 0x0b, 0x00, 0x02, 0x40, 0x20, 0x00, 0x45, 0x45, 0x0d, 0x00, 0x0b, 0x0b,
    ]),
  )
  Bytes::from_array(out[:])
}

///|
fn sample_module_with_local_const_propagation_bytes() -> Bytes {
  let out = bytes_of([0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00])

  // type section: 1 func type () -> (i32)
  append_section(out, 1U, bytes_of([0x01, 0x60, 0x00, 0x01, 0x7f]))
  // function section: 1 local function
  append_section(out, 3U, bytes_of([0x01, 0x00]))
  // export section: export index 0 as "run"
  append_section(out, 7U, bytes_of([0x01, 0x03, 0x72, 0x75, 0x6e, 0x00, 0x00]))
  // code section body:
  // local decl count=1, local group(count=1, i32)
  // i32.const 42
  // local.set 0
  // nop
  // local.get 0
  // i32.const 1
  // i32.add
  // end
  append_section(
    out,
    10U,
    bytes_of([
      0x01, 0x0e, 0x01, 0x01, 0x7f, 0x41, 0x2a, 0x21, 0x00, 0x01, 0x20, 0x00, 0x41,
      0x01, 0x6a, 0x0b,
    ]),
  )
  Bytes::from_array(out[:])
}

///|
fn sample_module_with_unused_locals_for_coalesce_bytes() -> Bytes {
  let out = bytes_of([0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00])

  // type section: 1 func type () -> (i32)
  append_section(out, 1U, bytes_of([0x01, 0x60, 0x00, 0x01, 0x7f]))
  // function section: 1 local function
  append_section(out, 3U, bytes_of([0x01, 0x00]))
  // export section: export index 0 as "run"
  append_section(out, 7U, bytes_of([0x01, 0x03, 0x72, 0x75, 0x6e, 0x00, 0x00]))
  // code section body:
  // local decl count=2, both i32 (local #0 is unused, #1 is used)
  // i32.const 7
  // local.set 1
  // local.get 1
  // end
  append_section(
    out,
    10U,
    bytes_of([
      0x01, 0x0c, 0x02, 0x01, 0x7f, 0x01, 0x7f, 0x41, 0x07, 0x21, 0x01, 0x20, 0x01,
      0x0b,
    ]),
  )
  Bytes::from_array(out[:])
}

///|
fn sample_module_with_unreachable_tail_bytes() -> Bytes {
  let out = bytes_of([0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00])

  // type section: 1 func type () -> ()
  append_section(out, 1U, bytes_of([0x01, 0x60, 0x00, 0x00]))
  // function section: 1 local function
  append_section(out, 3U, bytes_of([0x01, 0x00]))
  // export section: export index 0 as "run"
  append_section(out, 7U, bytes_of([0x01, 0x03, 0x72, 0x75, 0x6e, 0x00, 0x00]))
  // code section body:
  // local decl count=0
  // return
  // i32.const 7, drop (unreachable tail)
  // end
  append_section(
    out,
    10U,
    bytes_of([0x01, 0x06, 0x00, 0x0f, 0x41, 0x07, 0x1a, 0x0b]),
  )
  Bytes::from_array(out[:])
}

///|
fn sample_module_with_redundant_block_branch_bytes() -> Bytes {
  let out = bytes_of([0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00])

  // type section: 1 func type () -> ()
  append_section(out, 1U, bytes_of([0x01, 0x60, 0x00, 0x00]))
  // function section: 1 local function
  append_section(out, 3U, bytes_of([0x01, 0x00]))
  // export section: export index 0 as "run"
  append_section(out, 7U, bytes_of([0x01, 0x03, 0x72, 0x75, 0x6e, 0x00, 0x00]))
  // code section body:
  // local decl count=0
  // block void
  //   br 0
  // end
  // end
  append_section(
    out,
    10U,
    bytes_of([0x01, 0x07, 0x00, 0x02, 0x40, 0x0c, 0x00, 0x0b, 0x0b]),
  )
  Bytes::from_array(out[:])
}

///|
fn sample_module_with_unused_function_types_bytes() -> Bytes {
  let out = bytes_of([0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00])

  // type section: 3 func types, only #0 should remain after DCE
  append_section(
    out,
    1U,
    bytes_of([0x03, 0x60, 0x00, 0x00, 0x60, 0x00, 0x00, 0x60, 0x00, 0x00]),
  )
  // function section: 3 local functions -> type idx [0,1,2]
  append_section(out, 3U, bytes_of([0x03, 0x00, 0x01, 0x02]))
  // export section: export func 0 as "main"
  append_section(
    out,
    7U,
    bytes_of([0x01, 0x04, 0x6d, 0x61, 0x69, 0x6e, 0x00, 0x00]),
  )
  // code section: 3 bodies, all (locals=0, end)
  append_section(
    out,
    10U,
    bytes_of([0x03, 0x02, 0x00, 0x0b, 0x02, 0x00, 0x0b, 0x02, 0x00, 0x0b]),
  )
  Bytes::from_array(out[:])
}

///|
fn sample_module_with_unused_private_gc_type_bytes() -> Bytes {
  // Generated from:
  // (module
  //   (type (func))
  //   (type (struct (field i32)))
  //   (func (type 0))
  //   (export "run" (func 0)))
  Bytes::from_array(
    bytes_of([
      0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x02, 0x60, 0x00,
      0x00, 0x5f, 0x01, 0x7f, 0x00, 0x03, 0x02, 0x01, 0x00, 0x07, 0x07, 0x01, 0x03,
      0x72, 0x75, 0x6e, 0x00, 0x00, 0x0a, 0x04, 0x01, 0x02, 0x00, 0x0b,
    ])[:],
  )
}

///|
fn sample_module_with_referenced_private_gc_type_bytes() -> Bytes {
  // Generated from:
  // (module
  //   (type (func (param (ref 1))))
  //   (type (struct (field i32)))
  //   (func (type 0) local.get 0 drop)
  //   (export "run" (func 0)))
  Bytes::from_array(
    bytes_of([
      0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00, 0x01, 0x0a, 0x02, 0x60, 0x01,
      0x64, 0x01, 0x00, 0x5f, 0x01, 0x7f, 0x00, 0x03, 0x02, 0x01, 0x00, 0x07, 0x07,
      0x01, 0x03, 0x72, 0x75, 0x6e, 0x00, 0x00, 0x0a, 0x07, 0x01, 0x05, 0x00, 0x20,
      0x00, 0x1a, 0x0b,
    ])[:],
  )
}

///|
fn sample_module_with_call_indirect_type_gap_bytes() -> Bytes {
  let out = bytes_of([0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00])

  // type section: 2 func types, only #1 is used
  append_section(out, 1U, bytes_of([0x02, 0x60, 0x00, 0x00, 0x60, 0x00, 0x00]))
  // function section: 1 local function -> type idx 1
  append_section(out, 3U, bytes_of([0x01, 0x01]))
  // table section: 1 funcref table min=1
  append_section(out, 4U, bytes_of([0x01, 0x70, 0x00, 0x01]))
  // export section: export function 0 as "run"
  append_section(out, 7U, bytes_of([0x01, 0x03, 0x72, 0x75, 0x6e, 0x00, 0x00]))
  // element section: active table 0, offset 0, initialize with function index 0
  append_section(out, 9U, bytes_of([0x01, 0x00, 0x41, 0x00, 0x0b, 0x01, 0x00]))
  // code section:
  //   local decl count=0
  //   i32.const 0
  //   call_indirect type=1 table=0
  //   end
  append_section(
    out,
    10U,
    bytes_of([0x01, 0x07, 0x00, 0x41, 0x00, 0x11, 0x01, 0x00, 0x0b]),
  )
  Bytes::from_array(out[:])
}

///|
fn sample_module_with_similar_thunks_bytes() -> Bytes {
  let out = bytes_of([0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00])

  // type section: 1 func type () -> ()
  append_section(out, 1U, bytes_of([0x01, 0x60, 0x00, 0x00]))
  // function section: 4 local functions (indices 0..3)
  append_section(out, 3U, bytes_of([0x04, 0x00, 0x00, 0x00, 0x00]))
  // export section: export index 0 as "main", index 2 as "alias"
  append_section(
    out,
    7U,
    bytes_of([
      0x02, 0x04, 0x6d, 0x61, 0x69, 0x6e, 0x00, 0x00, 0x05, 0x61, 0x6c, 0x69, 0x61,
      0x73, 0x00, 0x02,
    ]),
  )
  // code section:
  // #0: call 1, call 2, end
  // #1: call 3, end
  // #2: call 3, end
  // #3: end
  append_section(
    out,
    10U,
    bytes_of([
      0x04, 0x06, 0x00, 0x10, 0x01, 0x10, 0x02, 0x0b, 0x04, 0x00, 0x10, 0x03, 0x0b,
      0x04, 0x00, 0x10, 0x03, 0x0b, 0x02, 0x00, 0x0b,
    ]),
  )
  Bytes::from_array(out[:])
}

///|
fn sample_module_with_param_forwarding_thunk_bytes() -> Bytes {
  let out = bytes_of([0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00])

  // type section: 1 func type (i32) -> (i32)
  append_section(out, 1U, bytes_of([0x01, 0x60, 0x01, 0x7f, 0x01, 0x7f]))
  // function section: 3 local functions (indices 0..2)
  append_section(out, 3U, bytes_of([0x03, 0x00, 0x00, 0x00]))
  // export section: export index 0 as "run"
  append_section(out, 7U, bytes_of([0x01, 0x03, 0x72, 0x75, 0x6e, 0x00, 0x00]))
  // code section:
  // #0: local.get 0; call 1; end
  // #1: local.get 0; call 2; end (param-forwarding thunk)
  // #2: local.get 0; i32.const 1; i32.add; end
  append_section(
    out,
    10U,
    bytes_of([
      0x03, 0x06, 0x00, 0x20, 0x00, 0x10, 0x01, 0x0b, 0x06, 0x00, 0x20, 0x00, 0x10,
      0x02, 0x0b, 0x07, 0x00, 0x20, 0x00, 0x41, 0x01, 0x6a, 0x0b,
    ]),
  )
  Bytes::from_array(out[:])
}

///|
fn sample_module_with_param_forwarding_thunk_with_unused_local_bytes() -> Bytes {
  let out = bytes_of([0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00])

  // type section: 1 func type (i32) -> (i32)
  append_section(out, 1U, bytes_of([0x01, 0x60, 0x01, 0x7f, 0x01, 0x7f]))
  // function section: 3 local functions (indices 0..2)
  append_section(out, 3U, bytes_of([0x03, 0x00, 0x00, 0x00]))
  // export section: export index 0 as "run"
  append_section(out, 7U, bytes_of([0x01, 0x03, 0x72, 0x75, 0x6e, 0x00, 0x00]))
  // code section:
  // #0: local.get 0; call 1; end
  // #1: (local i32) local.get 0; call 2; end (unused-local forwarding thunk)
  // #2: local.get 0; i32.const 1; i32.add; end
  append_section(
    out,
    10U,
    bytes_of([
      0x03, 0x06, 0x00, 0x20, 0x00, 0x10, 0x01, 0x0b, 0x08, 0x01, 0x01, 0x7f, 0x20,
      0x00, 0x10, 0x02, 0x0b, 0x07, 0x00, 0x20, 0x00, 0x41, 0x01, 0x6a, 0x0b,
    ]),
  )
  Bytes::from_array(out[:])
}

///|
fn sample_module_with_param_forwarding_call_return_thunk_bytes() -> Bytes {
  let out = bytes_of([0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00])

  // type section: 1 func type (i32) -> (i32)
  append_section(out, 1U, bytes_of([0x01, 0x60, 0x01, 0x7f, 0x01, 0x7f]))
  // function section: 3 local functions (indices 0..2)
  append_section(out, 3U, bytes_of([0x03, 0x00, 0x00, 0x00]))
  // export section: export index 0 as "run"
  append_section(out, 7U, bytes_of([0x01, 0x03, 0x72, 0x75, 0x6e, 0x00, 0x00]))
  // code section:
  // #0: local.get 0; call 1; end
  // #1: local.get 0; call 2; return; end (forwarding thunk with return)
  // #2: local.get 0; i32.const 1; i32.add; end
  append_section(
    out,
    10U,
    bytes_of([
      0x03, 0x06, 0x00, 0x20, 0x00, 0x10, 0x01, 0x0b, 0x07, 0x00, 0x20, 0x00, 0x10,
      0x02, 0x0f, 0x0b, 0x07, 0x00, 0x20, 0x00, 0x41, 0x01, 0x6a, 0x0b,
    ]),
  )
  Bytes::from_array(out[:])
}

///|
fn sample_module_with_const_forwarding_thunk_bytes() -> Bytes {
  let out = bytes_of([0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00])

  // type section:
  //   #0 (func (param i32 i32) (result i32))
  //   #1 (func (param i32 i32 i32) (result i32))
  append_section(
    out,
    1U,
    bytes_of([
      0x02, 0x60, 0x02, 0x7f, 0x7f, 0x01, 0x7f, 0x60, 0x03, 0x7f, 0x7f, 0x7f, 0x01,
      0x7f,
    ]),
  )
  // function section: 3 local functions (indices 0..2) with type idx [0,0,1]
  append_section(out, 3U, bytes_of([0x03, 0x00, 0x00, 0x01]))
  // export section: export index 0 as "run"
  append_section(out, 7U, bytes_of([0x01, 0x03, 0x72, 0x75, 0x6e, 0x00, 0x00]))
  // code section:
  // #0: local.get 0; local.get 1; call 1; end
  // #1: local.get 0; local.get 1; i32.const 5; call 2; end (const-forward thunk)
  // #2: local.get 0; local.get 1; i32.add; local.get 2; i32.add; end
  append_section(
    out,
    10U,
    bytes_of([
      0x03, 0x08, 0x00, 0x20, 0x00, 0x20, 0x01, 0x10, 0x01, 0x0b, 0x0a, 0x00, 0x20,
      0x00, 0x20, 0x01, 0x41, 0x05, 0x10, 0x02, 0x0b, 0x0a, 0x00, 0x20, 0x00, 0x20,
      0x01, 0x6a, 0x20, 0x02, 0x6a, 0x0b,
    ]),
  )
  Bytes::from_array(out[:])
}

///|
fn sample_module_with_const_forwarding_thunk_with_unused_local_bytes() -> Bytes {
  let out = bytes_of([0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00])

  // type section:
  //   #0 (func (param i32 i32) (result i32))
  //   #1 (func (param i32 i32 i32) (result i32))
  append_section(
    out,
    1U,
    bytes_of([
      0x02, 0x60, 0x02, 0x7f, 0x7f, 0x01, 0x7f, 0x60, 0x03, 0x7f, 0x7f, 0x7f, 0x01,
      0x7f,
    ]),
  )
  // function section: 3 local functions (indices 0..2) with type idx [0,0,1]
  append_section(out, 3U, bytes_of([0x03, 0x00, 0x00, 0x01]))
  // export section: export index 0 as "run"
  append_section(out, 7U, bytes_of([0x01, 0x03, 0x72, 0x75, 0x6e, 0x00, 0x00]))
  // code section:
  // #0: local.get 0; local.get 1; call 1; end
  // #1: (local i32) local.get 0; local.get 1; i32.const 5; call 2; end
  // #2: local.get 0; local.get 1; i32.add; local.get 2; i32.add; end
  append_section(
    out,
    10U,
    bytes_of([
      0x03, 0x08, 0x00, 0x20, 0x00, 0x20, 0x01, 0x10, 0x01, 0x0b, 0x0c, 0x01, 0x01,
      0x7f, 0x20, 0x00, 0x20, 0x01, 0x41, 0x05, 0x10, 0x02, 0x0b, 0x0a, 0x00, 0x20,
      0x00, 0x20, 0x01, 0x6a, 0x20, 0x02, 0x6a, 0x0b,
    ]),
  )
  Bytes::from_array(out[:])
}

///|
fn sample_module_with_const_forwarding_call_return_thunk_bytes() -> Bytes {
  let out = bytes_of([0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00])

  // type section:
  //   #0 (func (param i32 i32) (result i32))
  //   #1 (func (param i32 i32 i32) (result i32))
  append_section(
    out,
    1U,
    bytes_of([
      0x02, 0x60, 0x02, 0x7f, 0x7f, 0x01, 0x7f, 0x60, 0x03, 0x7f, 0x7f, 0x7f, 0x01,
      0x7f,
    ]),
  )
  // function section: 3 local functions (indices 0..2) with type idx [0,0,1]
  append_section(out, 3U, bytes_of([0x03, 0x00, 0x00, 0x01]))
  // export section: export index 0 as "run"
  append_section(out, 7U, bytes_of([0x01, 0x03, 0x72, 0x75, 0x6e, 0x00, 0x00]))
  // code section:
  // #0: local.get 0; local.get 1; call 1; end
  // #1: local.get 0; local.get 1; i32.const 5; call 2; return; end
  // #2: local.get 0; local.get 1; i32.add; local.get 2; i32.add; end
  append_section(
    out,
    10U,
    bytes_of([
      0x03, 0x08, 0x00, 0x20, 0x00, 0x20, 0x01, 0x10, 0x01, 0x0b, 0x0b, 0x00, 0x20,
      0x00, 0x20, 0x01, 0x41, 0x05, 0x10, 0x02, 0x0f, 0x0b, 0x0a, 0x00, 0x20, 0x00,
      0x20, 0x01, 0x6a, 0x20, 0x02, 0x6a, 0x0b,
    ]),
  )
  Bytes::from_array(out[:])
}

///|
fn sample_module_with_gc_signature_refining_thunk_bytes() -> Bytes {
  let out = bytes_of([0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00])

  // type section:
  //   #0 (struct (field i32))   // gc type (non-func)
  //   #1 (func (param i32) (result i32))
  //   #2 (func (param i32 i32) (result i32))
  append_section(
    out,
    1U,
    bytes_of([
      0x03, 0x5f, 0x01, 0x7f, 0x00, 0x60, 0x01, 0x7f, 0x01, 0x7f, 0x60, 0x02, 0x7f,
      0x7f, 0x01, 0x7f,
    ]),
  )
  // function section: 3 local functions (indices 0..2) with type idx [2,2,1]
  append_section(out, 3U, bytes_of([0x03, 0x02, 0x02, 0x01]))
  // export section: export index 0 as "run"
  append_section(out, 7U, bytes_of([0x01, 0x03, 0x72, 0x75, 0x6e, 0x00, 0x00]))
  // code section:
  // #0: local.get 0; local.get 1; call 1; end
  // #1: local.get 0; call 2; end  (signature-refining candidate)
  // #2: local.get 0; i32.const 1; i32.add; end
  append_section(
    out,
    10U,
    bytes_of([
      0x03, 0x08, 0x00, 0x20, 0x00, 0x20, 0x01, 0x10, 0x01, 0x0b, 0x06, 0x00, 0x20,
      0x00, 0x10, 0x02, 0x0b, 0x07, 0x00, 0x20, 0x00, 0x41, 0x01, 0x6a, 0x0b,
    ]),
  )
  Bytes::from_array(out[:])
}

///|
fn sample_module_with_gc_signature_refining_thunk_with_unused_local_bytes() -> Bytes {
  let out = bytes_of([0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00])

  // type section:
  //   #0 (struct (field i32))   // gc type (non-func)
  //   #1 (func (param i32) (result i32))
  //   #2 (func (param i32 i32) (result i32))
  append_section(
    out,
    1U,
    bytes_of([
      0x03, 0x5f, 0x01, 0x7f, 0x00, 0x60, 0x01, 0x7f, 0x01, 0x7f, 0x60, 0x02, 0x7f,
      0x7f, 0x01, 0x7f,
    ]),
  )
  // function section: 3 local functions (indices 0..2) with type idx [2,2,1]
  append_section(out, 3U, bytes_of([0x03, 0x02, 0x02, 0x01]))
  // export section: export index 0 as "run"
  append_section(out, 7U, bytes_of([0x01, 0x03, 0x72, 0x75, 0x6e, 0x00, 0x00]))
  // code section:
  // #0: local.get 0; local.get 1; call 1; end
  // #1: (local i32) local.get 0; call 2; end (signature-refining candidate)
  // #2: local.get 0; i32.const 1; i32.add; end
  append_section(
    out,
    10U,
    bytes_of([
      0x03, 0x08, 0x00, 0x20, 0x00, 0x20, 0x01, 0x10, 0x01, 0x0b, 0x08, 0x01, 0x01,
      0x7f, 0x20, 0x00, 0x10, 0x02, 0x0b, 0x07, 0x00, 0x20, 0x00, 0x41, 0x01, 0x6a,
      0x0b,
    ]),
  )
  Bytes::from_array(out[:])
}

///|
fn sample_module_with_gc_signature_refining_call_return_thunk_bytes() -> Bytes {
  let out = bytes_of([0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00])

  // type section:
  //   #0 (struct (field i32))   // gc type (non-func)
  //   #1 (func (param i32) (result i32))
  //   #2 (func (param i32 i32) (result i32))
  append_section(
    out,
    1U,
    bytes_of([
      0x03, 0x5f, 0x01, 0x7f, 0x00, 0x60, 0x01, 0x7f, 0x01, 0x7f, 0x60, 0x02, 0x7f,
      0x7f, 0x01, 0x7f,
    ]),
  )
  // function section: 3 local functions (indices 0..2) with type idx [2,2,1]
  append_section(out, 3U, bytes_of([0x03, 0x02, 0x02, 0x01]))
  // export section: export index 0 as "run"
  append_section(out, 7U, bytes_of([0x01, 0x03, 0x72, 0x75, 0x6e, 0x00, 0x00]))
  // code section:
  // #0: local.get 0; local.get 1; call 1; end
  // #1: local.get 0; call 2; return; end (signature-refining candidate)
  // #2: local.get 0; i32.const 1; i32.add; end
  append_section(
    out,
    10U,
    bytes_of([
      0x03, 0x08, 0x00, 0x20, 0x00, 0x20, 0x01, 0x10, 0x01, 0x0b, 0x07, 0x00, 0x20,
      0x00, 0x10, 0x02, 0x0f, 0x0b, 0x07, 0x00, 0x20, 0x00, 0x41, 0x01, 0x6a, 0x0b,
    ]),
  )
  Bytes::from_array(out[:])
}

///|
fn sample_module_with_global_and_element_refs_bytes() -> Bytes {
  let out = bytes_of([0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00])

  // type section: 1 func type () -> ()
  append_section(out, 1U, bytes_of([0x01, 0x60, 0x00, 0x00]))
  // function section: 3 local functions (indices 0,1,2)
  append_section(out, 3U, bytes_of([0x03, 0x00, 0x00, 0x00]))
  // table section: 1 funcref table min=1
  append_section(out, 4U, bytes_of([0x01, 0x70, 0x00, 0x01]))
  // global section:
  //   global funcref const ref.func 2 end
  append_section(out, 6U, bytes_of([0x01, 0x70, 0x00, 0xd2, 0x02, 0x0b]))
  // export section: export index 0 as "main"
  append_section(
    out,
    7U,
    bytes_of([0x01, 0x04, 0x6d, 0x61, 0x69, 0x6e, 0x00, 0x00]),
  )
  // element section:
  //   active segment table0 offset(i32.const 0)
  //   function indices [2]
  append_section(out, 9U, bytes_of([0x01, 0x00, 0x41, 0x00, 0x0b, 0x01, 0x02]))
  // code section:
  // #0: call 2, end
  // #1: end (dead)
  // #2: end
  append_section(
    out,
    10U,
    bytes_of([
      0x03, 0x04, 0x00, 0x10, 0x02, 0x0b, 0x02, 0x00, 0x0b, 0x02, 0x00, 0x0b,
    ]),
  )
  Bytes::from_array(out[:])
}

///|
fn sample_module_with_global_and_element_root_only_bytes() -> Bytes {
  let out = bytes_of([0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00])

  // type section: 1 func type () -> ()
  append_section(out, 1U, bytes_of([0x01, 0x60, 0x00, 0x00]))
  // function section: 2 local functions (indices 0,1)
  append_section(out, 3U, bytes_of([0x02, 0x00, 0x00]))
  // table section: 1 funcref table min=1
  append_section(out, 4U, bytes_of([0x01, 0x70, 0x00, 0x01]))
  // global section: global funcref const ref.func 1 end
  append_section(out, 6U, bytes_of([0x01, 0x70, 0x00, 0xd2, 0x01, 0x0b]))
  // export section: export main(index 0)
  append_section(
    out,
    7U,
    bytes_of([0x01, 0x04, 0x6d, 0x61, 0x69, 0x6e, 0x00, 0x00]),
  )
  // element section: active segment contains function index 1
  append_section(out, 9U, bytes_of([0x01, 0x00, 0x41, 0x00, 0x0b, 0x01, 0x01]))
  // code section:
  // #0: end
  // #1: end
  append_section(out, 10U, bytes_of([0x02, 0x02, 0x00, 0x0b, 0x02, 0x00, 0x0b]))
  Bytes::from_array(out[:])
}

///|
fn sample_module_with_unused_table_and_element_bytes() -> Bytes {
  let out = bytes_of([0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00])

  // type section: 1 func type () -> ()
  append_section(out, 1U, bytes_of([0x01, 0x60, 0x00, 0x00]))
  // function section: 1 local function
  append_section(out, 3U, bytes_of([0x01, 0x00]))
  // table section: 2 local funcref tables
  append_section(out, 4U, bytes_of([0x02, 0x70, 0x00, 0x01, 0x70, 0x00, 0x01]))
  // export section: export function index 0 as "run"
  append_section(out, 7U, bytes_of([0x01, 0x03, 0x72, 0x75, 0x6e, 0x00, 0x00]))
  // element section:
  // seg0: active table 0 (will be removed)
  // seg1: active table 1 (will be kept and remapped to 0)
  append_section(
    out,
    9U,
    bytes_of([
      0x02, 0x02, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x01, 0x00, 0x02, 0x01, 0x41, 0x00,
      0x0b, 0x00, 0x01, 0x00,
    ]),
  )
  // code section:
  // #0: table.size 1, drop, end
  append_section(
    out,
    10U,
    bytes_of([0x01, 0x06, 0x00, 0xfc, 0x10, 0x01, 0x1a, 0x0b]),
  )
  Bytes::from_array(out[:])
}

///|
fn sample_module_with_table_init_elem_reindex_bytes() -> Bytes {
  let out = bytes_of([0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00])

  // type section: 1 func type () -> ()
  append_section(out, 1U, bytes_of([0x01, 0x60, 0x00, 0x00]))
  // function section: 1 local function
  append_section(out, 3U, bytes_of([0x01, 0x00]))
  // table section: 2 local funcref tables
  append_section(out, 4U, bytes_of([0x02, 0x70, 0x00, 0x01, 0x70, 0x00, 0x01]))
  // export section: export function index 0 as "run"
  append_section(out, 7U, bytes_of([0x01, 0x03, 0x72, 0x75, 0x6e, 0x00, 0x00]))
  // element section:
  // seg0: active on table 0 (removed with table 0)
  // seg1: passive (kept); table.init references this with elemidx=1
  append_section(
    out,
    9U,
    bytes_of([
      0x02, 0x02, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x01, 0x00, 0x01, 0x00, 0x01, 0x00,
    ]),
  )
  // code section:
  // #0: i32.const 0; i32.const 0; i32.const 1; table.init elem=1 table=1; end
  append_section(
    out,
    10U,
    bytes_of([
      0x01, 0x0c, 0x00, 0x41, 0x00, 0x41, 0x00, 0x41, 0x01, 0xfc, 0x0c, 0x01, 0x01,
      0x0b,
    ]),
  )
  Bytes::from_array(out[:])
}

///|
fn sample_module_with_unused_import_memory_global_table_bytes() -> Bytes {
  let out = bytes_of([0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00])

  // type section: 1 func type () -> ()
  append_section(out, 1U, bytes_of([0x01, 0x60, 0x00, 0x00]))
  // import section:
  //   table env.t0 (used), table env.t1 (unused)
  //   memory env.m0 (used), memory env.m1 (unused)
  //   global env.g0 (used), global env.g1 (unused)
  append_section(
    out,
    2U,
    bytes_of([
      0x06, 0x03, 0x65, 0x6e, 0x76, 0x02, 0x74, 0x30, 0x01, 0x70, 0x00, 0x01, 0x03,
      0x65, 0x6e, 0x76, 0x02, 0x74, 0x31, 0x01, 0x70, 0x00, 0x01, 0x03, 0x65, 0x6e,
      0x76, 0x02, 0x6d, 0x30, 0x02, 0x00, 0x01, 0x03, 0x65, 0x6e, 0x76, 0x02, 0x6d,
      0x31, 0x02, 0x00, 0x01, 0x03, 0x65, 0x6e, 0x76, 0x02, 0x67, 0x30, 0x03, 0x7f,
      0x00, 0x03, 0x65, 0x6e, 0x76, 0x02, 0x67, 0x31, 0x03, 0x7f, 0x00,
    ]),
  )
  // function section: 1 local function
  append_section(out, 3U, bytes_of([0x01, 0x00]))
  // table section: 2 local tables (index 2 used, index 3 unused)
  append_section(out, 4U, bytes_of([0x02, 0x70, 0x00, 0x01, 0x70, 0x00, 0x01]))
  // memory section: 2 local memories (index 2 used, index 3 unused)
  append_section(out, 5U, bytes_of([0x02, 0x00, 0x01, 0x00, 0x01]))
  // global section:
  //   local#0(index 2) = global.get 0
  //   local#1(index 3) = global.get 2
  //   local#2(index 4) = i32.const 1 (unused)
  append_section(
    out,
    6U,
    bytes_of([
      0x03, 0x7f, 0x00, 0x23, 0x00, 0x0b, 0x7f, 0x00, 0x23, 0x02, 0x0b, 0x7f, 0x00,
      0x41, 0x01, 0x0b,
    ]),
  )
  // export section:
  //   run(func 0), t_local(table 2), m_local(memory 2), g_local(global 3)
  append_section(
    out,
    7U,
    bytes_of([
      0x04, 0x03, 0x72, 0x75, 0x6e, 0x00, 0x00, 0x07, 0x74, 0x5f, 0x6c, 0x6f, 0x63,
      0x61, 0x6c, 0x01, 0x02, 0x07, 0x6d, 0x5f, 0x6c, 0x6f, 0x63, 0x61, 0x6c, 0x02,
      0x02, 0x07, 0x67, 0x5f, 0x6c, 0x6f, 0x63, 0x61, 0x6c, 0x03, 0x03,
    ]),
  )
  // code section:
  //   global.get 3, drop
  //   table.size 0, drop
  //   table.size 2, drop
  //   memory.size 0, drop
  //   memory.size 2, drop
  append_section(
    out,
    10U,
    bytes_of([
      0x01, 0x13, 0x00, 0x23, 0x03, 0x1a, 0xfc, 0x10, 0x00, 0x1a, 0xfc, 0x10, 0x02,
      0x1a, 0x3f, 0x00, 0x1a, 0x3f, 0x02, 0x1a, 0x0b,
    ]),
  )
  Bytes::from_array(out[:])
}

///|
fn sample_module_with_duplicate_imports_bytes() -> Bytes {
  let out = bytes_of([0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00])

  // type section:
  //   #0: () -> ()
  append_section(out, 1U, bytes_of([0x01, 0x60, 0x00, 0x00]))
  // import section:
  //   func env.f type 0 (x2 duplicate)
  //   table env.t (x2 duplicate)
  //   memory env.m (x2 duplicate)
  //   global env.g i32 const (x2 duplicate)
  append_section(
    out,
    2U,
    bytes_of([
      0x08, 0x03, 0x65, 0x6e, 0x76, 0x01, 0x66, 0x00, 0x00, 0x03, 0x65, 0x6e, 0x76,
      0x01, 0x66, 0x00, 0x00, 0x03, 0x65, 0x6e, 0x76, 0x01, 0x74, 0x01, 0x70, 0x00,
      0x01, 0x03, 0x65, 0x6e, 0x76, 0x01, 0x74, 0x01, 0x70, 0x00, 0x01, 0x03, 0x65,
      0x6e, 0x76, 0x01, 0x6d, 0x02, 0x00, 0x01, 0x03, 0x65, 0x6e, 0x76, 0x01, 0x6d,
      0x02, 0x00, 0x01, 0x03, 0x65, 0x6e, 0x76, 0x01, 0x67, 0x03, 0x7f, 0x00, 0x03,
      0x65, 0x6e, 0x76, 0x01, 0x67, 0x03, 0x7f, 0x00,
    ]),
  )
  // function section: 1 local function (index old=2)
  append_section(out, 3U, bytes_of([0x01, 0x00]))
  // global section:
  //   local#0(index old=2): i32 = global.get 1
  //   local#1(index old=3): funcref = ref.func 1
  append_section(
    out,
    6U,
    bytes_of([0x02, 0x7f, 0x00, 0x23, 0x01, 0x0b, 0x70, 0x00, 0xd2, 0x01, 0x0b]),
  )
  // export section:
  //   run(func old=2), t(table old=1), m(memory old=1), gfun(global old=3)
  append_section(
    out,
    7U,
    bytes_of([
      0x04, 0x03, 0x72, 0x75, 0x6e, 0x00, 0x02, 0x01, 0x74, 0x01, 0x01, 0x01, 0x6d,
      0x02, 0x01, 0x04, 0x67, 0x66, 0x75, 0x6e, 0x03, 0x03,
    ]),
  )
  // start section: old function index 2
  append_section(out, 8U, bytes_of([0x02]))
  // element section:
  //   active table old=1, function old=2
  append_section(
    out,
    9U,
    bytes_of([0x01, 0x02, 0x01, 0x41, 0x00, 0x0b, 0x00, 0x01, 0x02]),
  )
  // code section (#0):
  //   call 1; global.get 2; drop; global.get 3; drop;
  //   table.size 1; drop; memory.size 1; drop; end
  append_section(
    out,
    10U,
    bytes_of([
      0x01, 0x11, 0x00, 0x10, 0x01, 0x23, 0x02, 0x1a, 0x23, 0x03, 0x1a, 0xfc, 0x10,
      0x01, 0x1a, 0x3f, 0x01, 0x1a, 0x0b,
    ]),
  )
  // data section:
  //   active memory old=1
  append_section(
    out,
    11U,
    bytes_of([0x01, 0x02, 0x01, 0x41, 0x00, 0x0b, 0x01, 0x00]),
  )
  Bytes::from_array(out[:])
}

///|
fn sample_module_with_simplifiable_global_get_bytes() -> Bytes {
  let out = bytes_of([0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00])
  // type section: 1 func type () -> i32
  append_section(out, 1U, bytes_of([0x01, 0x60, 0x00, 0x01, 0x7f]))
  // function section: 1 local function (type 0)
  append_section(out, 3U, bytes_of([0x01, 0x00]))
  // global section: immutable i32 global = i32.const 7
  append_section(out, 6U, bytes_of([0x01, 0x7f, 0x00, 0x41, 0x07, 0x0b]))
  // export section: run (func 0)
  append_section(out, 7U, bytes_of([0x01, 0x03, 0x72, 0x75, 0x6e, 0x00, 0x00]))
  // code section: global.get 0; end
  append_section(out, 10U, bytes_of([0x01, 0x04, 0x00, 0x23, 0x00, 0x0b]))
  Bytes::from_array(out[:])
}

///|
fn sample_module_with_reorderable_globals_bytes() -> Bytes {
  let out = bytes_of([0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00])
  // type section: 1 func type () -> i32
  append_section(out, 1U, bytes_of([0x01, 0x60, 0x00, 0x01, 0x7f]))
  // function section: 1 local function (type 0)
  append_section(out, 3U, bytes_of([0x01, 0x00]))
  // global section:
  //   g0: (mut i32) i32.const 1
  //   g1: (mut i32) i32.const 2
  //   g2: (mut i32) i32.const 3
  append_section(
    out,
    6U,
    bytes_of([
      0x03, 0x7f, 0x01, 0x41, 0x01, 0x0b, 0x7f, 0x01, 0x41, 0x02, 0x0b, 0x7f, 0x01,
      0x41, 0x03, 0x0b,
    ]),
  )
  // export section: run(func 0), g0/g1/g2(global 0/1/2)
  append_section(
    out,
    7U,
    bytes_of([
      0x04, 0x03, 0x72, 0x75, 0x6e, 0x00, 0x00, 0x02, 0x67, 0x30, 0x03, 0x00, 0x02,
      0x67, 0x31, 0x03, 0x01, 0x02, 0x67, 0x32, 0x03, 0x02,
    ]),
  )
  // code section: global.get 2; end
  append_section(out, 10U, bytes_of([0x01, 0x04, 0x00, 0x23, 0x02, 0x0b]))
  Bytes::from_array(out[:])
}

///|
fn sample_module_with_reorderable_memories_bytes() -> Bytes {
  let out = bytes_of([0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00])
  // type section: 1 func type () -> i32
  append_section(out, 1U, bytes_of([0x01, 0x60, 0x00, 0x01, 0x7f]))
  // function section: 1 local function (type 0)
  append_section(out, 3U, bytes_of([0x01, 0x00]))
  // memory section: 3 local memories min=1
  append_section(out, 5U, bytes_of([0x03, 0x00, 0x01, 0x00, 0x01, 0x00, 0x01]))
  // export section: run(func 0), m2(memory 2)
  append_section(
    out,
    7U,
    bytes_of([
      0x02, 0x03, 0x72, 0x75, 0x6e, 0x00, 0x00, 0x02, 0x6d, 0x32, 0x02, 0x02,
    ]),
  )
  // code section: memory.size 2; end
  append_section(out, 10U, bytes_of([0x01, 0x04, 0x00, 0x3f, 0x02, 0x0b]))
  // data section: active segment on memory 2 at offset 0, one byte payload
  append_section(
    out,
    11U,
    bytes_of([0x01, 0x02, 0x02, 0x41, 0x00, 0x0b, 0x01, 0x00]),
  )
  Bytes::from_array(out[:])
}

///|
fn bytes_contains_seq(bytes : Bytes, seq : Array[Int]) -> Bool {
  if seq.length() == 0 {
    return true
  }
  if bytes.length() < seq.length() {
    return false
  }
  for start in 0..<=(bytes.length() - seq.length()) {
    let mut matched = true
    for j in 0..<seq.length() {
      if bytes[start + j] != seq[j].to_byte() {
        matched = false
        break
      }
    }
    if matched {
      return true
    }
  }
  false
}

///|
fn find_section_size(sections : Array[SectionSize], key : String) -> UInt? {
  for section in sections {
    if section.key == key {
      return Some(section.total_bytes)
    }
  }
  None
}

///|
fn find_custom_section_breakdown(
  sections : Array[CustomSectionBreakdown],
  name : String,
) -> CustomSectionBreakdown? {
  for section in sections {
    if section.name == name {
      return Some(section)
    }
  }
  None
}

///|
fn find_opcode_stat(stats : Array[OpcodeStat], key : String) -> OpcodeStat? {
  for stat in stats {
    if stat.key == key {
      return Some(stat)
    }
  }
  None
}

///|
fn find_host_code_hint(
  hints : Array[HostCodeHint],
  kind : String,
) -> HostCodeHint? {
  for hint in hints {
    if hint.kind == kind {
      return Some(hint)
    }
  }
  None
}

///|
fn find_optimize_stage(
  stages : Array[OptimizeStageMetadata],
  stage : String,
) -> OptimizeStageMetadata? {
  for item in stages {
    if item.stage == stage {
      return Some(item)
    }
  }
  None
}

///|
fn find_retain_path_entry(
  entries : Array[RetainPathEntry],
  function_index : UInt,
) -> RetainPathEntry? {
  for entry in entries {
    if entry.function_index == function_index {
      return Some(entry)
    }
  }
  None
}

///|
fn find_hotness_size_entry(
  entries : Array[HotnessSizeEntry],
  export_name : String,
) -> HotnessSizeEntry? {
  for entry in entries {
    if entry.export_name == export_name {
      return Some(entry)
    }
  }
  None
}

///|
fn find_hotness_size_bucket(
  buckets : Array[HotnessSizeBucket],
  bucket : String,
) -> HotnessSizeBucket? {
  for item in buckets {
    if item.bucket == bucket {
      return Some(item)
    }
  }
  None
}

///|
test "analyze section sizes for core module" {
  let bytes = sample_module_bytes()
  guard analyze_section_sizes(bytes) is Ok(sections) else {
    assert_true(false)
    return
  }
  assert_true(sections.length() >= 6)
  assert_eq(find_section_size(sections, "type"), Some(6U))
  assert_eq(find_section_size(sections, "function"), Some(4U))
  assert_eq(find_section_size(sections, "export"), Some(9U))
  assert_eq(find_section_size(sections, "code"), Some(6U))
  assert_eq(find_section_size(sections, "custom:name"), Some(8U))
  assert_eq(find_section_size(sections, "custom:producers"), Some(13U))
}

///|
test "optimize for size strips custom sections" {
  let bytes = sample_module_bytes()
  let config = OptimizeConfig::aggressive()
  guard optimize_for_size(bytes, config~) is Ok(optimized) else {
    assert_true(false)
    return
  }
  assert_true(optimized.after_size < optimized.before_size)
  guard analyze_section_sizes(optimized.bytes) is Ok(sections_after) else {
    assert_true(false)
    return
  }
  assert_eq(find_section_size(sections_after, "type"), Some(6U))
  assert_eq(find_section_size(sections_after, "function"), Some(4U))
  assert_eq(find_section_size(sections_after, "export"), Some(9U))
  assert_eq(find_section_size(sections_after, "code"), Some(6U))
  assert_true(not(sections_after.any(s => s.key.contains("custom:"))))
}

///|
test "optimize can strip debug/dwarf/target-features sections" {
  let bytes = sample_module_with_misc_custom_sections_bytes()
  let config = make_optimize_config(
    strip_all_custom=false,
    strip_name_section=false,
    strip_producers_section=false,
    strip_debug_sections=true,
    strip_dwarf_sections=true,
    strip_target_features_section=true,
    enable_peephole=false,
    enable_vacuum=false,
    enable_merge_blocks=false,
    enable_remove_unused_brs=false,
  )
  guard optimize_for_size(bytes, config~) is Ok(optimized) else {
    assert_true(false)
    return
  }
  guard analyze_section_sizes(optimized.bytes) is Ok(sections_after) else {
    assert_true(false)
    return
  }
  assert_true(not(sections_after.any(s => s.key == "custom:sourceMappingURL")))
  assert_true(not(sections_after.any(s => s.key == "custom:.debug_info")))
  assert_true(not(sections_after.any(s => s.key == "custom:target_features")))
  assert_true(sections_after.any(s => s.key == "custom:keepme"))
}

///|
test "opt level presets map to expected optimizer knobs" {
  guard optimize_config_from_opt_level("-O0") is Some(o0) else {
    assert_true(false)
    return
  }
  assert_true(not(o0.enable_peephole))
  assert_true(not(o0.enable_dce))
  assert_true(not(o0.enable_dfe))
  assert_true(not(o0.enable_merge_similar_functions))
  assert_true(not(o0.closed_world))
  assert_true(not(o0.safe_mode))
  assert_eq(o0.pass_rounds, 1U)
  guard optimize_config_from_opt_level("-O1") is Some(o1) else {
    assert_true(false)
    return
  }
  assert_true(o1.enable_peephole)
  assert_true(o1.enable_dce)
  assert_true(o1.enable_dfe)
  assert_true(o1.enable_merge_similar_functions)
  assert_true(o1.enable_remove_unused_module_elements)
  assert_eq(o1.pass_rounds, 2U)
  assert_true(o1.strip_debug_sections)
  assert_true(o1.strip_dwarf_sections)
  assert_true(o1.strip_target_features_section)
  guard optimize_config_from_opt_level("-O2") is Some(o2) else {
    assert_true(false)
    return
  }
  assert_true(o2.enable_peephole)
  assert_true(o2.enable_dce)
  assert_true(not(o2.enable_dfe))
  assert_true(not(o2.closed_world))
  assert_true(not(o2.safe_mode))
  assert_eq(o2.pass_rounds, 2U)
  guard optimize_config_from_opt_level("-Oz") is Some(oz) else {
    assert_true(false)
    return
  }
  assert_true(oz.enable_dce)
  assert_true(oz.enable_dfe)
  assert_true(oz.enable_merge_similar_functions)
  assert_true(not(oz.closed_world))
  assert_true(not(oz.safe_mode))
  assert_eq(oz.pass_rounds, 8U)
  match optimize_config_from_opt_level("-Ox") {
    Some(_) => assert_true(false)
    None => ()
  }
}

///|
test "make optimize config can enable closed-world mode" {
  let default_config = make_optimize_config()
  assert_true(not(default_config.closed_world))
  assert_eq(default_config.closed_world_root_exports.length(), 0)
  assert_true(not(default_config.safe_mode))
  let closed_world_config = make_optimize_config(closed_world=true)
  assert_true(closed_world_config.closed_world)
  let closed_world_with_roots = make_optimize_config(closed_world=true, closed_world_root_exports=[
    "keep",
  ])
  assert_eq(closed_world_with_roots.closed_world_root_exports, ["keep"])
  let safe_mode_config = make_optimize_config(
    closed_world=true,
    closed_world_root_exports=["keep"],
    safe_mode=true,
  )
  assert_true(safe_mode_config.safe_mode)
}

///|
test "optimize with -O0 preset disables size passes" {
  let bytes = sample_module_with_peephole_bytes()
  let config = match optimize_config_from_opt_level("-O0") {
    Some(v) => v
    None => {
      assert_true(false)
      return
    }
  }
  guard optimize_for_size(bytes, config~) is Ok(optimized) else {
    assert_true(false)
    return
  }
  guard profile_module(optimized.bytes) is Ok(after) else {
    assert_true(false)
    return
  }
  assert_eq(after.code_body_bytes, 8U)
}

///|
test "optimize with -O2 preset applies dce" {
  let bytes = sample_module_with_dce_reindex_bytes()
  let config = match optimize_config_from_opt_level("-O2") {
    Some(v) => v
    None => {
      assert_true(false)
      return
    }
  }
  guard optimize_for_size(bytes, config~) is Ok(optimized) else {
    assert_true(false)
    return
  }
  guard profile_module(optimized.bytes) is Ok(after) else {
    assert_true(false)
    return
  }
  assert_eq(after.function_count, 2U)
}

///|
test "profile core module metrics" {
  let bytes = sample_module_bytes()
  guard profile_module(bytes) is Ok(profile) else {
    assert_true(false)
    return
  }
  assert_eq(profile.total_bytes, bytes.length().reinterpret_as_uint())
  assert_eq(profile.function_count, 1U)
  assert_eq(profile.import_count, 0U)
  assert_eq(profile.export_count, 1U)
  assert_eq(profile.code_body_count, 1U)
  assert_eq(profile.code_body_bytes, 2U)
}

///|
test "analyze function sizes with names and exports" {
  let bytes = sample_module_with_named_functions_bytes()
  guard analyze_function_sizes(bytes) is Ok(functions) else {
    assert_true(false)
    return
  }
  assert_eq(functions.length(), 2)
  assert_eq(functions[0].function_index, 2U)
  assert_eq(functions[0].body_bytes, 5U)
  assert_eq(functions[0].name, Some("large"))
  assert_eq(functions[0].export_names, ["large"])
  assert_eq(functions[1].function_index, 1U)
  assert_eq(functions[1].body_bytes, 2U)
  assert_eq(functions[1].name, Some("small"))
  assert_eq(functions[1].export_names, ["small"])
}

///|
test "analyze code block sizes for nested block module" {
  let bytes = sample_module_with_nested_blocks_bytes()
  guard analyze_code_block_sizes(bytes) is Ok(report) else {
    assert_true(false)
    return
  }
  assert_true(not(report.partial))
  assert_eq(report.function_count, 1U)
  assert_eq(report.block_count, 3U)
  assert_eq(report.total_body_bytes, 12U)
  assert_eq(report.total_instruction_bytes, 11U)
  assert_eq(report.blocks.length(), 3)
  assert_eq(report.blocks[0].kind, "function")
  assert_eq(report.blocks[0].depth, 0U)
  assert_eq(report.blocks[0].total_bytes, 11U)
  assert_eq(report.blocks[0].instruction_count, 7U)
  assert_eq(report.blocks[1].kind, "block")
  assert_eq(report.blocks[1].depth, 1U)
  assert_eq(report.blocks[1].total_bytes, 10U)
  assert_eq(report.blocks[2].kind, "loop")
  assert_eq(report.blocks[2].depth, 2U)
  assert_eq(report.blocks[2].total_bytes, 7U)
  assert_eq(report.blocks[2].instruction_count, 4U)
}

///|
test "analyze wasm breakdown reports deep section and opcode details" {
  let bytes = sample_module_with_named_functions_bytes()
  guard analyze_wasm_breakdown(bytes) is Ok(report) else {
    assert_true(false)
    return
  }
  assert_eq(report.total_bytes, bytes.length().reinterpret_as_uint())
  assert_eq(report.imported_function_count, 1U)
  assert_eq(report.local_function_count, 2U)
  assert_eq(report.instruction_count, 4U)
  assert_eq(report.instruction_bytes, 5U)
  assert_true(not(report.opcode_partial))
  assert_true(not(report.callgraph_partial))
  assert_true(not(report.has_indirect_calls))
  assert_eq(report.reachable_body_bytes, 7U)
  assert_eq(report.dead_body_bytes, 0U)
  assert_eq(report.top_functions.length(), 2)
  assert_eq(report.top_blocks.length(), 2)
  guard find_custom_section_breakdown(report.custom_sections, "name")
    is Some(custom_name) else {
    assert_true(false)
    return
  }
  assert_eq(custom_name.count, 1U)
  assert_true(custom_name.total_bytes > 0U)
  guard find_opcode_stat(report.opcodes, "0x41") is Some(const_opcode) else {
    assert_true(false)
    return
  }
  assert_eq(const_opcode.count, 1U)
  assert_eq(const_opcode.total_bytes, 2U)
  guard find_opcode_stat(report.opcodes, "0x0b") is Some(end_opcode) else {
    assert_true(false)
    return
  }
  assert_eq(end_opcode.count, 2U)
}

///|
test "analyze wasm breakdown respects top_limit" {
  let bytes = sample_module_with_named_functions_bytes()
  guard analyze_wasm_breakdown(bytes, top_limit=1U) is Ok(report) else {
    assert_true(false)
    return
  }
  assert_eq(report.local_function_count, 2U)
  assert_eq(report.block_count, 2U)
  assert_eq(report.top_functions.length(), 1)
  assert_eq(report.top_blocks.length(), 1)
}

///|
test "analyze wasm breakdown splits prefixed opcodes" {
  let bytes = sample_module_with_fc_opcode_bytes()
  guard analyze_wasm_breakdown(bytes) is Ok(report) else {
    assert_true(false)
    return
  }
  guard find_opcode_stat(report.opcodes, "0xfc.0") is Some(fc_stat) else {
    assert_true(false)
    return
  }
  assert_eq(fc_stat.count, 1U)
  assert_true(fc_stat.total_bytes >= 2U)
}

///|
test "analyze call graph with dead function" {
  let bytes = sample_module_with_dead_function_bytes()
  guard analyze_call_graph(bytes) is Ok(report) else {
    assert_true(false)
    return
  }
  assert_eq(report.imported_function_count, 1U)
  assert_eq(report.local_function_count, 3U)
  assert_eq(report.reachable_body_bytes, 6U)
  assert_eq(report.dead_body_bytes, 5U)
  assert_true(report.roots.contains(1U))
  assert_true(report.nodes.length() == 3)
  let main_node = report.nodes[0]
  assert_eq(main_node.function_index, 1U)
  assert_eq(main_node.direct_callees, [2U])
  assert_true(main_node.reachable_from_roots)
  assert_eq(main_node.export_names, ["main"])
  let dead_node = report.nodes[2]
  assert_eq(dead_node.function_index, 3U)
  assert_true(not(dead_node.reachable_from_roots))
}

///|
test "analyze call graph summary with dead function" {
  let bytes = sample_module_with_dead_function_bytes()
  guard analyze_call_graph_summary(bytes) is Ok(summary) else {
    assert_true(false)
    return
  }
  assert_eq(summary.imported_function_count, 1U)
  assert_eq(summary.local_function_count, 3U)
  assert_true(summary.roots.contains(1U))
  assert_true(not(summary.has_indirect_calls))
  assert_true(not(summary.partial))
  assert_eq(summary.reachable_function_count, 2U)
  assert_eq(summary.dead_function_count, 1U)
  assert_eq(summary.reachable_body_bytes, 6U)
  assert_eq(summary.dead_body_bytes, 5U)
}

///|
test "analyze call graph summary marks indirect calls" {
  let bytes = sample_module_with_call_indirect_type_gap_bytes()
  guard analyze_call_graph_summary(bytes) is Ok(summary) else {
    assert_true(false)
    return
  }
  assert_eq(summary.imported_function_count, 0U)
  assert_eq(summary.local_function_count, 1U)
  assert_true(summary.has_indirect_calls)
  assert_true(not(summary.partial))
  assert_eq(summary.reachable_function_count, 1U)
  assert_eq(summary.dead_function_count, 0U)
}

///|
test "analyze host-generated code detects forwarding thunks" {
  let bytes = sample_module_with_const_forwarding_thunk_bytes()
  guard analyze_host_generated_code(bytes) is Ok(report) else {
    assert_true(false)
    return
  }
  assert_eq(report.imported_function_count, 0U)
  assert_eq(report.local_function_count, 3U)
  assert_eq(report.param_forwarding_thunk_count, 1U)
  assert_eq(report.const_forwarding_thunk_count, 1U)
  assert_eq(report.signature_refinable_thunk_count, 0U)
  guard find_host_code_hint(report.hints, "const-forward") is Some(const_hint) else {
    assert_true(false)
    return
  }
  assert_eq(const_hint.function_index, 1U)
  assert_eq(const_hint.target_function_index, 2U)
  assert_eq(const_hint.appended_i32_const_count, 1U)
}

///|
test "analyze host-generated code detects signature-refine thunk" {
  let bytes = sample_module_with_gc_signature_refining_thunk_bytes()
  guard analyze_host_generated_code(bytes) is Ok(report) else {
    assert_true(false)
    return
  }
  assert_eq(report.signature_refinable_thunk_count, 1U)
  guard find_host_code_hint(report.hints, "signature-refine") is Some(sig_hint) else {
    assert_true(false)
    return
  }
  assert_eq(sig_hint.function_index, 1U)
  assert_eq(sig_hint.target_function_index, 2U)
  assert_eq(sig_hint.dropped_param_count, 1U)
}

///|
test "analyze host-generated code reports directize and dce metadata" {
  let directize_bytes = sample_module_with_call_indirect_type_gap_bytes()
  guard analyze_host_generated_code(directize_bytes) is Ok(directize_report) else {
    assert_true(false)
    return
  }
  assert_eq(directize_report.directize_candidate_call_count, 1U)
  let dead_bytes = sample_module_with_dead_function_bytes()
  guard analyze_host_generated_code(dead_bytes) is Ok(dead_report) else {
    assert_true(false)
    return
  }
  assert_true(not(dead_report.dce_partial))
  assert_eq(dead_report.dce_removable_function_count, 1U)
  assert_eq(dead_report.dce_removable_body_bytes, 5U)
}

///|
test "analyze optimize metadata reports stage waterfall" {
  let bytes = sample_module_with_dead_function_bytes()
  guard analyze_optimize_metadata(bytes, config=OptimizeConfig::o1())
    is Ok(report) else {
    assert_true(false)
    return
  }
  assert_eq(report.before_size, bytes.length().reinterpret_as_uint())
  assert_true(report.after_size <= report.before_size)
  assert_eq(report.stages.length(), 4)
  guard find_optimize_stage(report.stages, "dce") is Some(dce_stage) else {
    assert_true(false)
    return
  }
  assert_true(dce_stage.gain_bytes > 0U)
  assert_true(dce_stage.after_size <= dce_stage.before_size)
  guard find_optimize_stage(report.stages, "rume") is Some(rume_stage) else {
    assert_true(false)
    return
  }
  assert_true(rume_stage.after_size <= rume_stage.before_size)
}

///|
test "analyze call graph supports fc opcodes" {
  let bytes = sample_module_with_fc_opcode_bytes()
  guard analyze_call_graph(bytes) is Ok(report) else {
    assert_true(false)
    return
  }
  assert_eq(report.local_function_count, 1U)
  assert_true(not(report.partial))
  assert_eq(report.reachable_body_bytes, 10U)
  assert_eq(report.dead_body_bytes, 0U)
  assert_eq(report.nodes.length(), 1)
}

///|
test "analyze call graph supports fd memarg opcodes" {
  let bytes = sample_module_with_fd_memarg_bytes()
  guard analyze_call_graph(bytes) is Ok(report) else {
    assert_true(false)
    return
  }
  assert_eq(report.local_function_count, 1U)
  assert_true(not(report.partial))
  assert_eq(report.reachable_body_bytes, 9U)
  assert_eq(report.dead_body_bytes, 0U)
  assert_eq(report.nodes.length(), 1)
}

///|
test "analyze dce report extracts removable functions" {
  let bytes = sample_module_with_dead_function_bytes()
  guard analyze_dce_report(bytes) is Ok(report) else {
    assert_true(false)
    return
  }
  assert_true(not(report.partial))
  assert_eq(report.removable_function_count, 1U)
  assert_eq(report.removable_body_bytes, 5U)
  assert_eq(report.removable_functions.length(), 1)
  assert_eq(report.removable_functions[0].function_index, 3U)
}

///|
test "analyze keep reasons reports export and call-based keep causes" {
  let bytes = sample_module_with_dce_reindex_bytes()
  let config = make_optimize_config(closed_world=true, closed_world_root_exports=[
    "main",
  ])
  guard analyze_keep_reasons(bytes, config~) is Ok(report) else {
    assert_true(false)
    return
  }
  assert_true(not(report.partial))
  assert_eq(report.entries.length(), 2)
  guard find_keep_reason_entry(report.entries, 0U) is Some(main_entry) else {
    assert_true(false)
    return
  }
  assert_true(main_entry.reasons.any(r => r == "export:main"))
  guard find_keep_reason_entry(report.entries, 2U) is Some(helper_entry) else {
    assert_true(false)
    return
  }
  assert_true(helper_entry.reasons.any(r => r == "call:0"))
  match find_keep_reason_entry(report.entries, 1U) {
    Some(_) => assert_true(false)
    None => ()
  }
}

///|
test "analyze keep reasons honors safe-mode override" {
  let bytes = sample_module_with_two_exported_functions_bytes()
  let config = make_optimize_config(
    closed_world=true,
    closed_world_root_exports=["keep"],
    safe_mode=true,
  )
  guard analyze_keep_reasons(bytes, config~) is Ok(report) else {
    assert_true(false)
    return
  }
  assert_eq(report.entries.length(), 2)
  guard find_keep_reason_entry(report.entries, 0U) is Some(keep_entry) else {
    assert_true(false)
    return
  }
  assert_true(keep_entry.reasons.any(r => r == "export:keep"))
  guard find_keep_reason_entry(report.entries, 1U) is Some(drop_entry) else {
    assert_true(false)
    return
  }
  assert_true(drop_entry.reasons.any(r => r == "export:drop"))
}

///|
test "analyze retain paths reports root to callee chain" {
  let bytes = sample_module_with_dead_function_bytes()
  let config = make_optimize_config(closed_world=true, closed_world_root_exports=[
    "main",
  ])
  guard analyze_retain_paths(bytes, config~) is Ok(report) else {
    assert_true(false)
    return
  }
  assert_true(not(report.partial))
  assert_true(report.roots.contains(1U))
  assert_eq(report.entries.length(), 2)
  guard find_retain_path_entry(report.entries, 1U) is Some(main_entry) else {
    assert_true(false)
    return
  }
  assert_eq(main_entry.path, [1U])
  assert_true(main_entry.root_reasons.any(r => r == "export:main"))
  guard find_retain_path_entry(report.entries, 2U) is Some(helper_entry) else {
    assert_true(false)
    return
  }
  assert_eq(helper_entry.path, [1U, 2U])
  assert_true(helper_entry.root_reasons.any(r => r == "export:main"))
  match find_retain_path_entry(report.entries, 3U) {
    Some(_) => assert_true(false)
    None => ()
  }
}

///|
test "analyze retain paths records element roots" {
  let bytes = sample_module_with_call_indirect_type_gap_bytes()
  guard analyze_retain_paths(bytes) is Ok(report) else {
    assert_true(false)
    return
  }
  guard find_retain_path_entry(report.entries, 0U) is Some(run_entry) else {
    assert_true(false)
    return
  }
  assert_eq(run_entry.path, [0U])
  assert_true(run_entry.root_reasons.any(r => r == "export:run"))
  assert_true(run_entry.root_reasons.any(r => r == "element-ref.func"))
}

///|
test "optimize with dce apply removes dead and rewrites calls" {
  let bytes = sample_module_with_dce_reindex_bytes()
  guard analyze_call_graph(bytes) is Ok(before_graph) else {
    assert_true(false)
    return
  }
  assert_eq(before_graph.dead_body_bytes, 2U)
  assert_eq(before_graph.nodes[0].direct_callees, [2U])
  let config = make_optimize_config(
    strip_all_custom=false,
    strip_name_section=false,
    strip_producers_section=false,
    enable_peephole=false,
    enable_dce=true,
  )
  guard optimize_for_size(bytes, config~) is Ok(optimized) else {
    assert_true(false)
    return
  }
  assert_true(
    optimized.removed_sections.any(s => s.contains("dce:functions:1")),
  )
  guard profile_module(optimized.bytes) is Ok(after_profile) else {
    assert_true(false)
    return
  }
  assert_eq(after_profile.function_count, 2U)
  assert_eq(after_profile.code_body_count, 2U)
  guard analyze_call_graph(optimized.bytes) is Ok(after_graph) else {
    assert_true(false)
    return
  }
  assert_eq(after_graph.dead_body_bytes, 0U)
  assert_eq(after_graph.nodes.length(), 2)
  assert_eq(after_graph.nodes[0].direct_callees, [1U])
}

///|
test "optimize with dce apply preserves runtime output" {
  let bytes = sample_module_with_dce_reindex_result_bytes()
  let config = make_optimize_config(
    strip_all_custom=false,
    strip_name_section=false,
    strip_producers_section=false,
    pass_rounds=2U,
    enable_peephole=false,
    enable_vacuum=false,
    enable_merge_blocks=false,
    enable_remove_unused_brs=false,
    enable_dce=true,
    enable_dfe=false,
    enable_merge_similar_functions=false,
    enable_remove_unused_module_elements=false,
  )
  guard optimize_for_size(bytes, config~) is Ok(optimized) else {
    assert_true(false)
    return
  }
  assert_true(
    optimized.removed_sections.any(s => s.contains("dce:functions:1")),
  )
  assert_true(runtime_export_outputs_equal(bytes, optimized.bytes, "main", []))
}

///|
test "optimize with closed-world dce filters export roots by name" {
  let bytes = sample_module_with_two_exported_functions_bytes()
  guard profile_module(bytes) is Ok(before) else {
    assert_true(false)
    return
  }
  assert_eq(before.function_count, 2U)
  let config = make_optimize_config(
    strip_all_custom=false,
    strip_name_section=false,
    strip_producers_section=false,
    pass_rounds=2U,
    enable_peephole=false,
    enable_vacuum=false,
    enable_merge_blocks=false,
    enable_remove_unused_brs=false,
    enable_dce=true,
    closed_world=true,
    closed_world_root_exports=["keep"],
  )
  guard optimize_for_size(bytes, config~) is Ok(optimized) else {
    assert_true(false)
    return
  }
  assert_true(
    optimized.removed_sections.any(s => s.contains("dce:functions:1")),
  )
  guard profile_module(optimized.bytes) is Ok(after) else {
    assert_true(false)
    return
  }
  assert_eq(after.function_count, 1U)
  assert_true(
    bytes_contains_seq(optimized.bytes, [
      0x07, 0x08, 0x01, 0x04, 0x6b, 0x65, 0x65, 0x70, 0x00, 0x00,
    ]),
  )
  assert_true(
    not(
      bytes_contains_seq(optimized.bytes, [
        0x04, 0x64, 0x72, 0x6f, 0x70, 0x00, 0x01,
      ]),
    ),
  )
}

///|
test "optimize with safe-mode disables closed-world dce filtering" {
  let bytes = sample_module_with_two_exported_functions_bytes()
  let config = make_optimize_config(
    strip_all_custom=false,
    strip_name_section=false,
    strip_producers_section=false,
    enable_peephole=false,
    enable_vacuum=false,
    enable_merge_blocks=false,
    enable_remove_unused_brs=false,
    enable_dce=true,
    closed_world=true,
    closed_world_root_exports=["keep"],
    safe_mode=true,
  )
  guard optimize_for_size(bytes, config~) is Ok(optimized) else {
    assert_true(false)
    return
  }
  assert_true(
    not(optimized.removed_sections.any(s => s.contains("dce:functions:"))),
  )
  guard profile_module(optimized.bytes) is Ok(after) else {
    assert_true(false)
    return
  }
  assert_eq(after.function_count, 2U)
}

///|
test "optimize with dce prunes now-unused function types" {
  let bytes = sample_module_with_unused_function_types_bytes()
  let config = make_optimize_config(
    enable_peephole=false,
    enable_vacuum=false,
    enable_merge_blocks=false,
    enable_remove_unused_brs=false,
    enable_dce=true,
    closed_world=true,
    closed_world_root_exports=["main"],
  )
  guard optimize_for_size(bytes, config~) is Ok(optimized) else {
    assert_true(false)
    return
  }
  assert_true(
    optimized.removed_sections.any(s => s.contains("dce:functions:2")),
  )
  assert_true(optimized.removed_sections.any(s => s.contains("types:2")))
  guard analyze_section_sizes(optimized.bytes) is Ok(sections_after) else {
    assert_true(false)
    return
  }
  assert_eq(find_section_size(sections_after, "type"), Some(6U))
  guard profile_module(optimized.bytes) is Ok(after_profile) else {
    assert_true(false)
    return
  }
  assert_eq(after_profile.function_count, 1U)
}

///|
test "optimize rewrites call_indirect type indices after type pruning" {
  let bytes = sample_module_with_call_indirect_type_gap_bytes()
  let config = make_optimize_config(
    enable_peephole=false,
    enable_vacuum=false,
    enable_merge_blocks=false,
    enable_remove_unused_brs=false,
    enable_remove_unused_module_elements=true,
  )
  guard optimize_for_size(bytes, config~) is Ok(optimized) else {
    assert_true(false)
    return
  }
  assert_true(optimized.removed_sections.any(s => s.contains("types:1")))
  assert_true(bytes_contains_seq(optimized.bytes, [0x03, 0x02, 0x01, 0x00]))
  assert_true(bytes_contains_seq(optimized.bytes, [0x11, 0x00, 0x00]))
  assert_true(not(bytes_contains_seq(optimized.bytes, [0x11, 0x01, 0x00])))
}

///|
test "optimize with dce apply rewrites global and element refs" {
  let bytes = sample_module_with_global_and_element_refs_bytes()
  let config = make_optimize_config(
    strip_all_custom=false,
    strip_name_section=false,
    strip_producers_section=false,
    enable_peephole=false,
    enable_vacuum=false,
    enable_merge_blocks=false,
    enable_remove_unused_brs=false,
    enable_dce=true,
  )
  guard optimize_for_size(bytes, config~) is Ok(optimized) else {
    assert_true(false)
    return
  }
  guard profile_module(optimized.bytes) is Ok(after_profile) else {
    assert_true(false)
    return
  }
  assert_eq(after_profile.function_count, 2U)
  guard analyze_call_graph(optimized.bytes) is Ok(after_graph) else {
    assert_true(false)
    return
  }
  assert_eq(after_graph.nodes.length(), 2)
  assert_eq(after_graph.nodes[0].direct_callees, [1U])
  assert_true(bytes_contains_seq(optimized.bytes, [0xd2, 0x01, 0x0b]))
  assert_true(not(bytes_contains_seq(optimized.bytes, [0xd2, 0x02, 0x0b])))
  assert_true(
    bytes_contains_seq(optimized.bytes, [0x41, 0x00, 0x0b, 0x01, 0x01]),
  )
}

///|
test "analyze call graph treats global and element refs as roots" {
  let bytes = sample_module_with_global_and_element_root_only_bytes()
  guard analyze_call_graph(bytes) is Ok(graph) else {
    assert_true(false)
    return
  }
  assert_true(graph.roots.contains(0U))
  assert_true(graph.roots.contains(1U))
  assert_eq(graph.dead_body_bytes, 0U)
}

///|
test "optimize with dce keeps functions referenced by global/element roots" {
  let bytes = sample_module_with_global_and_element_root_only_bytes()
  let config = make_optimize_config(
    strip_all_custom=false,
    strip_name_section=false,
    strip_producers_section=false,
    enable_peephole=false,
    enable_vacuum=false,
    enable_merge_blocks=false,
    enable_remove_unused_brs=false,
    enable_dce=true,
  )
  guard optimize_for_size(bytes, config~) is Ok(optimized) else {
    assert_true(false)
    return
  }
  guard profile_module(optimized.bytes) is Ok(after_profile) else {
    assert_true(false)
    return
  }
  assert_eq(after_profile.function_count, 2U)
  assert_true(
    not(optimized.removed_sections.any(s => s.contains("dce:functions:"))),
  )
}

///|
test "optimize with rume apply removes unused table and element segment" {
  let bytes = sample_module_with_unused_table_and_element_bytes()
  let config = make_optimize_config(
    strip_all_custom=false,
    strip_name_section=false,
    strip_producers_section=false,
    enable_peephole=false,
    enable_vacuum=false,
    enable_merge_blocks=false,
    enable_remove_unused_brs=false,
    enable_remove_unused_module_elements=true,
  )
  guard optimize_for_size(bytes, config~) is Ok(optimized) else {
    assert_true(false)
    return
  }
  assert_true(optimized.removed_sections.any(s => s.contains("tables:1")))
  assert_true(
    bytes_contains_seq(optimized.bytes, [0x04, 0x04, 0x01, 0x70, 0x00, 0x01]),
  )
  assert_true(bytes_contains_seq(optimized.bytes, [0xfc, 0x10, 0x00]))
  assert_true(not(bytes_contains_seq(optimized.bytes, [0xfc, 0x10, 0x01])))
}

///|
test "optimize with rume apply rewrites table.init elem index after element removal" {
  let bytes = sample_module_with_table_init_elem_reindex_bytes()
  let config = make_optimize_config(
    strip_all_custom=false,
    strip_name_section=false,
    strip_producers_section=false,
    enable_peephole=false,
    enable_vacuum=false,
    enable_merge_blocks=false,
    enable_remove_unused_brs=false,
    enable_remove_unused_module_elements=true,
  )
  guard optimize_for_size(bytes, config~) is Ok(optimized) else {
    assert_true(false)
    return
  }
  assert_true(optimized.removed_sections.any(s => s.contains("tables:1")))
  assert_true(optimized.removed_sections.any(s => s.contains("elements:1")))
  assert_true(bytes_contains_seq(optimized.bytes, [0xfc, 0x0c, 0x00, 0x00]))
  assert_true(
    not(bytes_contains_seq(optimized.bytes, [0xfc, 0x0c, 0x01, 0x00])),
  )
  assert_true(runtime_zero_arg_export_behaviors_equal(bytes, optimized.bytes))
}

///|
test "optimize with rume apply honors closed-world export roots" {
  let bytes = sample_module_with_two_exported_functions_bytes()
  let config = make_optimize_config(
    strip_all_custom=false,
    strip_name_section=false,
    strip_producers_section=false,
    enable_peephole=false,
    enable_vacuum=false,
    enable_merge_blocks=false,
    enable_remove_unused_brs=false,
    enable_remove_unused_module_elements=true,
    closed_world=true,
    closed_world_root_exports=["keep"],
  )
  guard optimize_for_size(bytes, config~) is Ok(optimized) else {
    assert_true(false)
    return
  }
  assert_true(optimized.removed_sections.any(s => s.contains("exports:1")))
  assert_true(
    bytes_contains_seq(optimized.bytes, [
      0x07, 0x08, 0x01, 0x04, 0x6b, 0x65, 0x65, 0x70, 0x00, 0x00,
    ]),
  )
  assert_true(
    not(
      bytes_contains_seq(optimized.bytes, [
        0x04, 0x64, 0x72, 0x6f, 0x70, 0x00, 0x01,
      ]),
    ),
  )
}

///|
test "optimize with rume apply removes unused import/global/memory/table and remaps indices" {
  let bytes = sample_module_with_unused_import_memory_global_table_bytes()
  guard profile_module(bytes) is Ok(before_profile) else {
    assert_true(false)
    return
  }
  assert_eq(before_profile.import_count, 6U)
  let config = make_optimize_config(
    strip_all_custom=false,
    strip_name_section=false,
    strip_producers_section=false,
    enable_peephole=false,
    enable_vacuum=false,
    enable_merge_blocks=false,
    enable_remove_unused_brs=false,
    enable_remove_unused_module_elements=true,
  )
  guard optimize_for_size(bytes, config~) is Ok(optimized) else {
    assert_true(false)
    return
  }
  assert_true(optimized.removed_sections.any(s => s.contains("imports:3")))
  guard profile_module(optimized.bytes) is Ok(after_profile) else {
    assert_true(false)
    return
  }
  assert_eq(after_profile.import_count, 3U)
  assert_true(
    bytes_contains_seq(optimized.bytes, [0x04, 0x04, 0x01, 0x70, 0x00, 0x01]),
  )
  assert_true(
    bytes_contains_seq(optimized.bytes, [0x05, 0x03, 0x01, 0x00, 0x01]),
  )
  assert_true(
    bytes_contains_seq(optimized.bytes, [
      0x06, 0x0b, 0x02, 0x7f, 0x00, 0x23, 0x00, 0x0b, 0x7f, 0x00, 0x23, 0x01, 0x0b,
    ]),
  )
  assert_true(bytes_contains_seq(optimized.bytes, [0xfc, 0x10, 0x01]))
  assert_true(not(bytes_contains_seq(optimized.bytes, [0xfc, 0x10, 0x02])))
  assert_true(bytes_contains_seq(optimized.bytes, [0x3f, 0x01]))
  assert_true(not(bytes_contains_seq(optimized.bytes, [0x3f, 0x02])))
  assert_true(bytes_contains_seq(optimized.bytes, [0x23, 0x02]))
  assert_true(not(bytes_contains_seq(optimized.bytes, [0x23, 0x03])))
  assert_true(
    bytes_contains_seq(optimized.bytes, [
      0x07, 0x74, 0x5f, 0x6c, 0x6f, 0x63, 0x61, 0x6c, 0x01, 0x01,
    ]),
  )
  assert_true(
    bytes_contains_seq(optimized.bytes, [
      0x07, 0x6d, 0x5f, 0x6c, 0x6f, 0x63, 0x61, 0x6c, 0x02, 0x01,
    ]),
  )
  assert_true(
    bytes_contains_seq(optimized.bytes, [
      0x07, 0x67, 0x5f, 0x6c, 0x6f, 0x63, 0x61, 0x6c, 0x03, 0x02,
    ]),
  )
}

///|
test "optimize removes duplicate imports and remaps all related indices" {
  let bytes = sample_module_with_duplicate_imports_bytes()
  guard profile_module(bytes) is Ok(before_profile) else {
    assert_true(false)
    return
  }
  assert_eq(before_profile.import_count, 8U)
  let config = make_optimize_config(
    strip_all_custom=false,
    strip_name_section=false,
    strip_producers_section=false,
    enable_peephole=false,
    enable_vacuum=false,
    enable_merge_blocks=false,
    enable_remove_unused_brs=false,
    enable_dce=true,
    enable_dfe=false,
    enable_merge_similar_functions=false,
    enable_remove_unused_module_elements=false,
  )
  guard optimize_for_size(bytes, config~) is Ok(optimized) else {
    assert_true(false)
    return
  }
  assert_true(optimized.removed_sections.any(s => s.contains("dup-imports:")))
  guard profile_module(optimized.bytes) is Ok(after_profile) else {
    assert_true(false)
    return
  }
  assert_eq(after_profile.import_count, 4U)
  assert_true(bytes_contains_seq(optimized.bytes, [0x10, 0x00]))
  assert_true(not(bytes_contains_seq(optimized.bytes, [0x10, 0x01])))
  assert_true(bytes_contains_seq(optimized.bytes, [0xd2, 0x00, 0x0b]))
  assert_true(not(bytes_contains_seq(optimized.bytes, [0xd2, 0x01, 0x0b])))
  assert_true(bytes_contains_seq(optimized.bytes, [0xfc, 0x10, 0x00]))
  assert_true(not(bytes_contains_seq(optimized.bytes, [0xfc, 0x10, 0x01])))
  assert_true(bytes_contains_seq(optimized.bytes, [0x3f, 0x00]))
  assert_true(not(bytes_contains_seq(optimized.bytes, [0x3f, 0x01])))
  assert_true(
    bytes_contains_seq(optimized.bytes, [0x03, 0x72, 0x75, 0x6e, 0x00, 0x01]),
  )
  assert_true(bytes_contains_seq(optimized.bytes, [0x01, 0x74, 0x01, 0x00]))
  assert_true(bytes_contains_seq(optimized.bytes, [0x01, 0x6d, 0x02, 0x00]))
  assert_true(
    bytes_contains_seq(optimized.bytes, [
      0x04, 0x67, 0x66, 0x75, 0x6e, 0x03, 0x01,
    ]) ||
    bytes_contains_seq(optimized.bytes, [
      0x04, 0x67, 0x66, 0x75, 0x6e, 0x03, 0x02,
    ]),
  )
  assert_true(bytes_contains_seq(optimized.bytes, [0x08, 0x01, 0x01]))
  assert_true(runtime_zero_arg_export_behaviors_equal(bytes, optimized.bytes))
}

///|
test "optimize simplify-globals rewrites immutable global.get to i32.const" {
  let bytes = sample_module_with_simplifiable_global_get_bytes()
  let config = make_optimize_config(
    strip_all_custom=false,
    strip_name_section=false,
    strip_producers_section=false,
    enable_peephole=false,
    enable_vacuum=false,
    enable_merge_blocks=false,
    enable_remove_unused_brs=false,
    enable_dce=true,
    enable_dfe=false,
    enable_merge_similar_functions=false,
    enable_remove_unused_module_elements=false,
  )
  guard optimize_for_size(bytes, config~) is Ok(optimized) else {
    assert_true(false)
    return
  }
  assert_true(
    optimized.removed_sections.any(s => s.contains("simplify-globals:gets:1")),
  )
  assert_true(bytes_contains_seq(optimized.bytes, [0x41, 0x07, 0x0b]))
  assert_true(not(bytes_contains_seq(optimized.bytes, [0x23, 0x00, 0x0b])))
  assert_true(runtime_export_outputs_equal(bytes, optimized.bytes, "run", []))
}

///|
test "optimize reorder-globals remaps global indices in code and exports" {
  let bytes = sample_module_with_reorderable_globals_bytes()
  let config = make_optimize_config(
    strip_all_custom=false,
    strip_name_section=false,
    strip_producers_section=false,
    enable_peephole=false,
    enable_vacuum=false,
    enable_merge_blocks=false,
    enable_remove_unused_brs=false,
    enable_dce=true,
    enable_dfe=false,
    enable_merge_similar_functions=false,
    enable_remove_unused_module_elements=false,
  )
  guard optimize_for_size(bytes, config~) is Ok(optimized) else {
    assert_true(false)
    return
  }
  assert_true(
    optimized.removed_sections.any(s => s.contains("reorder-globals:locals:")),
  )
  assert_true(bytes_contains_seq(optimized.bytes, [0x23, 0x00, 0x0b]))
  assert_true(not(bytes_contains_seq(optimized.bytes, [0x23, 0x02, 0x0b])))
  assert_true(
    bytes_contains_seq(optimized.bytes, [0x02, 0x67, 0x32, 0x03, 0x00]),
  )
  assert_true(runtime_export_outputs_equal(bytes, optimized.bytes, "run", []))
}

///|
test "optimize memory-packing reorders local memories and remaps users" {
  let bytes = sample_module_with_reorderable_memories_bytes()
  let config = make_optimize_config(
    strip_all_custom=false,
    strip_name_section=false,
    strip_producers_section=false,
    enable_peephole=false,
    enable_vacuum=false,
    enable_merge_blocks=false,
    enable_remove_unused_brs=false,
    enable_dce=true,
    enable_dfe=false,
    enable_merge_similar_functions=false,
    enable_remove_unused_module_elements=false,
  )
  guard optimize_for_size(bytes, config~) is Ok(optimized) else {
    assert_true(false)
    return
  }
  assert_true(
    optimized.removed_sections.any(s => s.contains("memory-packing:locals:")),
  )
  assert_true(bytes_contains_seq(optimized.bytes, [0x3f, 0x01, 0x0b]))
  assert_true(not(bytes_contains_seq(optimized.bytes, [0x3f, 0x02, 0x0b])))
  assert_true(
    bytes_contains_seq(optimized.bytes, [0x02, 0x6d, 0x32, 0x02, 0x01]),
  )
  assert_true(
    bytes_contains_seq(optimized.bytes, [
      0x02, 0x01, 0x41, 0x00, 0x0b, 0x01, 0x00,
    ]),
  )
  assert_true(
    not(
      bytes_contains_seq(optimized.bytes, [
        0x02, 0x02, 0x41, 0x00, 0x0b, 0x01, 0x00,
      ]),
    ),
  )
}

///|
test "kpi rume gain fixture has positive post-dce to post-rume delta" {
  let bytes = @fs.read_file_to_bytes(
    "bench/corpus/core/binaryen/rume_gain_fixture.wasm",
  ) catch {
    _ => {
      assert_true(false)
      return
    }
  }
  let pre_config = make_optimize_config(
    strip_all_custom=false,
    strip_name_section=true,
    strip_producers_section=true,
    strip_debug_sections=true,
    strip_dwarf_sections=true,
    strip_target_features_section=true,
    pass_rounds=2U,
    enable_dce=false,
    enable_dfe=false,
    enable_merge_similar_functions=false,
    enable_remove_unused_module_elements=false,
  )
  let post_dce_config = make_optimize_config(
    strip_all_custom=false,
    strip_name_section=true,
    strip_producers_section=true,
    strip_debug_sections=true,
    strip_dwarf_sections=true,
    strip_target_features_section=true,
    pass_rounds=2U,
    enable_dce=true,
    enable_dfe=true,
    enable_merge_similar_functions=true,
    enable_remove_unused_module_elements=false,
  )
  let post_rume_config = make_optimize_config(
    strip_all_custom=false,
    strip_name_section=true,
    strip_producers_section=true,
    strip_debug_sections=true,
    strip_dwarf_sections=true,
    strip_target_features_section=true,
    pass_rounds=2U,
    enable_dce=true,
    enable_dfe=true,
    enable_merge_similar_functions=true,
    enable_remove_unused_module_elements=true,
  )
  guard optimize_for_size(bytes, config=pre_config) is Ok(pre) else {
    assert_true(false)
    return
  }
  guard optimize_for_size(bytes, config=post_dce_config) is Ok(post_dce) else {
    assert_true(false)
    return
  }
  guard optimize_for_size(bytes, config=post_rume_config) is Ok(post_rume) else {
    assert_true(false)
    return
  }
  assert_true(post_dce.after_size <= pre.after_size)
  assert_true(post_rume.after_size < post_dce.after_size)
  assert_true(post_rume.removed_sections.any(s => s.contains("rume:")))
  assert_true(runtime_export_outputs_equal(bytes, post_rume.bytes, "run", []))
}

///|
test "optimize -O1 shrinks rume gain fixture by removing table.size drop" {
  let bytes = @fs.read_file_to_bytes(
    "bench/corpus/core/binaryen/rume_gain_fixture.wasm",
  ) catch {
    _ => {
      assert_true(false)
      return
    }
  }
  let config = OptimizeConfig::o1()
  guard optimize_for_size(bytes, config~) is Ok(optimized) else {
    assert_true(false)
    return
  }
  assert_true(optimized.after_size <= 34U)
  assert_true(
    not(bytes_contains_seq(optimized.bytes, [0xfc, 0x10, 0x00, 0x1a])),
  )
  assert_true(runtime_export_outputs_equal(bytes, optimized.bytes, "run", []))
}

///|
test "kpi directize gain fixture records directize call rewrite" {
  let bytes = @fs.read_file_to_bytes(
    "bench/corpus/core/binaryen/directize_gain_fixture.wasm",
  ) catch {
    _ => {
      assert_true(false)
      return
    }
  }
  let pre_config = make_optimize_config(
    strip_all_custom=false,
    strip_name_section=true,
    strip_producers_section=true,
    strip_debug_sections=true,
    strip_dwarf_sections=true,
    strip_target_features_section=true,
    pass_rounds=2U,
    enable_dce=false,
    enable_dfe=false,
    enable_merge_similar_functions=false,
    enable_remove_unused_module_elements=false,
  )
  let post_dce_config = make_optimize_config(
    strip_all_custom=false,
    strip_name_section=true,
    strip_producers_section=true,
    strip_debug_sections=true,
    strip_dwarf_sections=true,
    strip_target_features_section=true,
    pass_rounds=2U,
    enable_dce=true,
    enable_dfe=true,
    enable_merge_similar_functions=true,
    enable_remove_unused_module_elements=false,
  )
  let post_rume_config = make_optimize_config(
    strip_all_custom=false,
    strip_name_section=true,
    strip_producers_section=true,
    strip_debug_sections=true,
    strip_dwarf_sections=true,
    strip_target_features_section=true,
    pass_rounds=2U,
    enable_dce=true,
    enable_dfe=true,
    enable_merge_similar_functions=true,
    enable_remove_unused_module_elements=true,
  )
  guard optimize_for_size(bytes, config=pre_config) is Ok(pre) else {
    assert_true(false)
    return
  }
  guard optimize_for_size(bytes, config=post_dce_config) is Ok(post_dce) else {
    assert_true(false)
    return
  }
  guard optimize_for_size(bytes, config=post_rume_config) is Ok(post_rume) else {
    assert_true(false)
    return
  }
  assert_true(post_dce.after_size < pre.after_size)
  assert_true(
    post_dce.removed_sections.any(s => s.contains("directize:calls:1")),
  )
  assert_true(post_rume.after_size <= post_dce.after_size)
  assert_true(runtime_zero_arg_export_behaviors_equal(bytes, post_rume.bytes))
}

///|
test "optimize with dfe apply merges duplicate functions" {
  let bytes = sample_module_with_duplicate_functions_bytes()
  guard profile_module(bytes) is Ok(before_profile) else {
    assert_true(false)
    return
  }
  assert_eq(before_profile.function_count, 3U)
  assert_eq(before_profile.code_body_count, 3U)
  let config = make_optimize_config(
    strip_all_custom=false,
    strip_name_section=false,
    strip_producers_section=false,
    enable_peephole=false,
    enable_dce=false,
    enable_dfe=true,
  )
  guard optimize_for_size(bytes, config~) is Ok(optimized) else {
    assert_true(false)
    return
  }
  assert_true(
    optimized.removed_sections.any(s => s.contains("dfe:functions:1")),
  )
  guard profile_module(optimized.bytes) is Ok(after_profile) else {
    assert_true(false)
    return
  }
  assert_eq(after_profile.function_count, 2U)
  assert_eq(after_profile.code_body_count, 2U)
  guard analyze_call_graph(optimized.bytes) is Ok(after_graph) else {
    assert_true(false)
    return
  }
  assert_eq(after_graph.nodes.length(), 2)
  assert_eq(after_graph.nodes[0].direct_callees, [1U])
  guard analyze_function_sizes(optimized.bytes) is Ok(functions) else {
    assert_true(false)
    return
  }
  assert_true(
    functions.any(f => f.function_index == 1U &&
      f.export_names.contains("alias")),
  )
}

///|
test "optimize type refining unlocks dfe across duplicated type entries" {
  let bytes = sample_module_with_duplicate_functions_but_split_types_bytes()
  let config = make_optimize_config(
    strip_all_custom=false,
    strip_name_section=false,
    strip_producers_section=false,
    enable_peephole=false,
    enable_vacuum=false,
    enable_merge_blocks=false,
    enable_remove_unused_brs=false,
    enable_dce=false,
    enable_dfe=true,
  )
  guard optimize_for_size(bytes, config~) is Ok(optimized) else {
    assert_true(false)
    return
  }
  assert_true(
    optimized.removed_sections.any(s => s.contains("type-refine:types:1")),
  )
  assert_true(
    optimized.removed_sections.any(s => s.contains("dfe:functions:1")),
  )
  guard profile_module(optimized.bytes) is Ok(after_profile) else {
    assert_true(false)
    return
  }
  assert_eq(after_profile.function_count, 1U)
}

///|
test "optimize type refining works on gc-mixed type section and unlocks dfe" {
  let bytes = sample_module_with_duplicate_functions_but_split_types_and_gc_bytes()
  let config = make_optimize_config(
    strip_all_custom=false,
    strip_name_section=false,
    strip_producers_section=false,
    enable_peephole=false,
    enable_vacuum=false,
    enable_merge_blocks=false,
    enable_remove_unused_brs=false,
    enable_dce=false,
    enable_dfe=true,
  )
  guard optimize_for_size(bytes, config~) is Ok(optimized) else {
    assert_true(false)
    return
  }
  assert_true(
    optimized.removed_sections.any(s => s.contains("type-refine:types:1")),
  )
  assert_true(
    optimized.removed_sections.any(s => s.contains("dfe:functions:1")),
  )
  guard profile_module(optimized.bytes) is Ok(after_profile) else {
    assert_true(false)
    return
  }
  assert_eq(after_profile.function_count, 1U)
  assert_true(runtime_export_outputs_equal(bytes, optimized.bytes, "main", []))
}

///|
test "optimize type refining considers gc hierarchy-equivalent refs and unlocks dfe" {
  let bytes = sample_module_with_gc_hierarchy_duplicate_function_types_bytes()
  let config = make_optimize_config(
    strip_all_custom=false,
    strip_name_section=false,
    strip_producers_section=false,
    enable_peephole=false,
    enable_vacuum=false,
    enable_merge_blocks=false,
    enable_remove_unused_brs=false,
    enable_dce=false,
    enable_dfe=true,
    closed_world=true,
    closed_world_root_exports=["run", "a", "b"],
  )
  guard optimize_for_size(bytes, config~) is Ok(optimized) else {
    assert_true(false)
    return
  }
  assert_true(
    optimized.removed_sections.any(s => s.contains("type-refine:types:1")),
  )
  assert_true(
    optimized.removed_sections.any(s => s.contains("dfe:functions:1")),
  )
  guard profile_module(optimized.bytes) is Ok(after_profile) else {
    assert_true(false)
    return
  }
  assert_eq(after_profile.function_count, 2U)
  assert_true(runtime_export_outputs_equal(bytes, optimized.bytes, "run", []))
}

///|
test "optimize signature pruning removes unused trailing params and rewrites callers" {
  let bytes = sample_module_with_signature_pruning_candidate_bytes()
  let config = make_optimize_config(
    strip_all_custom=false,
    strip_name_section=false,
    strip_producers_section=false,
    enable_peephole=false,
    enable_vacuum=false,
    enable_merge_blocks=false,
    enable_remove_unused_brs=false,
    enable_dce=true,
    enable_dfe=false,
  )
  guard optimize_for_size(bytes, config~) is Ok(optimized) else {
    assert_true(false)
    return
  }
  assert_true(
    optimized.removed_sections.any(s => s.contains(
      "signature-prune:functions:1",
    )),
  )
  assert_true(optimized.removed_sections.any(s => s.contains("types:1")))
  assert_true(bytes_contains_seq(optimized.bytes, [0x60, 0x01, 0x7f, 0x00]))
  assert_true(
    not(bytes_contains_seq(optimized.bytes, [0x60, 0x02, 0x7f, 0x7f, 0x00])),
  )
  assert_true(
    not(
      bytes_contains_seq(optimized.bytes, [
        0x41, 0x01, 0x41, 0x02, 0x1a, 0x10, 0x01, 0x0b,
      ]),
    ),
  )
  assert_true(
    bytes_contains_seq(optimized.bytes, [0x41, 0x01, 0x10, 0x01, 0x0b]),
  )
}

///|
test "optimize inlining-optimizing rewrites call to inline const and enables dce" {
  let bytes = sample_module_with_inlining_const_callee_bytes()
  let config = make_optimize_config(
    strip_all_custom=false,
    strip_name_section=false,
    strip_producers_section=false,
    pass_rounds=2U,
    enable_peephole=false,
    enable_vacuum=false,
    enable_merge_blocks=false,
    enable_remove_unused_brs=false,
    enable_dce=true,
    enable_dfe=false,
    enable_merge_similar_functions=false,
    enable_remove_unused_module_elements=false,
  )
  guard optimize_for_size(bytes, config~) is Ok(optimized) else {
    assert_true(false)
    return
  }
  assert_true(
    optimized.removed_sections.any(s => s.contains("inlining:calls:1")),
  )
  assert_true(
    optimized.removed_sections.any(s => s.contains("dce:functions:1")),
  )
  assert_true(bytes_contains_seq(optimized.bytes, [0x41, 0x2a, 0x0b]))
  assert_true(not(bytes_contains_seq(optimized.bytes, [0x10, 0x01])))
  guard profile_module(optimized.bytes) is Ok(profile) else {
    assert_true(false)
    return
  }
  assert_eq(profile.function_count, 1U)
  assert_true(runtime_export_outputs_equal(bytes, optimized.bytes, "run", []))
}

///|
test "optimize dae-optimizing removes pure expression for dropped argument" {
  let bytes = sample_module_with_dae_expression_drop_bytes()
  let config = make_optimize_config(
    strip_all_custom=false,
    strip_name_section=false,
    strip_producers_section=false,
    enable_peephole=false,
    enable_vacuum=false,
    enable_merge_blocks=false,
    enable_remove_unused_brs=false,
    enable_dce=true,
    enable_dfe=false,
    enable_merge_similar_functions=false,
    enable_remove_unused_module_elements=false,
  )
  guard optimize_for_size(bytes, config~) is Ok(optimized) else {
    assert_true(false)
    return
  }
  assert_true(
    optimized.removed_sections.any(s => s.contains(
      "signature-prune:functions:1",
    )),
  )
  assert_true(optimized.removed_sections.any(s => s.contains("dae:instrs:")))
  assert_true(
    not(
      bytes_contains_seq(optimized.bytes, [0x41, 0x0a, 0x41, 0x14, 0x6a, 0x1a]),
    ),
  )
  assert_true(
    bytes_contains_seq(optimized.bytes, [0x41, 0x01, 0x10, 0x01, 0x0b]),
  )
  assert_true(runtime_export_outputs_equal(bytes, optimized.bytes, "run", []))
}

///|
test "optimize remove-unused-types prunes unused private gc type" {
  let bytes = sample_module_with_unused_private_gc_type_bytes()
  let config = make_optimize_config(
    strip_all_custom=false,
    strip_name_section=false,
    strip_producers_section=false,
    enable_peephole=false,
    enable_vacuum=false,
    enable_merge_blocks=false,
    enable_remove_unused_brs=false,
    enable_dce=true,
    enable_dfe=false,
    enable_merge_similar_functions=false,
    enable_remove_unused_module_elements=false,
  )
  guard optimize_for_size(bytes, config~) is Ok(optimized) else {
    assert_true(false)
    return
  }
  assert_true(optimized.removed_sections.any(s => s.contains("types:1")))
  assert_true(
    not(bytes_contains_seq(optimized.bytes, [0x5f, 0x01, 0x7f, 0x00])),
  )
}

///|
test "optimize remove-unused-types keeps referenced private gc type" {
  let bytes = sample_module_with_referenced_private_gc_type_bytes()
  let config = make_optimize_config(
    strip_all_custom=false,
    strip_name_section=false,
    strip_producers_section=false,
    enable_peephole=false,
    enable_vacuum=false,
    enable_merge_blocks=false,
    enable_remove_unused_brs=false,
    enable_dce=true,
    enable_dfe=false,
    enable_merge_similar_functions=false,
    enable_remove_unused_module_elements=false,
  )
  guard optimize_for_size(bytes, config~) is Ok(optimized) else {
    assert_true(false)
    return
  }
  assert_true(not(optimized.removed_sections.any(s => s.contains("types:1"))))
  assert_true(bytes_contains_seq(optimized.bytes, [0x5f, 0x01, 0x7f, 0x00]))
}

///|
test "optimize vacuum removes unreachable tail" {
  let bytes = sample_module_with_unreachable_tail_bytes()
  guard profile_module(bytes) is Ok(before) else {
    assert_true(false)
    return
  }
  assert_eq(before.code_body_bytes, 6U)
  let config = make_optimize_config(
    strip_all_custom=false,
    strip_name_section=false,
    strip_producers_section=false,
    enable_peephole=true,
    enable_vacuum=true,
  )
  guard optimize_for_size(bytes, config~) is Ok(optimized) else {
    assert_true(false)
    return
  }
  guard profile_module(optimized.bytes) is Ok(after) else {
    assert_true(false)
    return
  }
  assert_eq(after.code_body_bytes, 3U)
}

///|
test "optimize vacuum works even when peephole is disabled" {
  let bytes = sample_module_with_unreachable_tail_bytes()
  let config = make_optimize_config(
    strip_all_custom=false,
    strip_name_section=false,
    strip_producers_section=false,
    pass_rounds=1U,
    enable_peephole=false,
    enable_vacuum=true,
    enable_merge_blocks=false,
    enable_remove_unused_brs=false,
  )
  guard optimize_for_size(bytes, config~) is Ok(optimized) else {
    assert_true(false)
    return
  }
  guard profile_module(optimized.bytes) is Ok(after) else {
    assert_true(false)
    return
  }
  assert_eq(after.code_body_bytes, 3U)
}

///|
test "optimize remove-unused-brs and merge-blocks shrink block wrapper" {
  let bytes = sample_module_with_redundant_block_branch_bytes()
  guard profile_module(bytes) is Ok(before) else {
    assert_true(false)
    return
  }
  assert_eq(before.code_body_bytes, 7U)
  let config = make_optimize_config(
    strip_all_custom=false,
    strip_name_section=false,
    strip_producers_section=false,
    enable_peephole=true,
    enable_merge_blocks=true,
    enable_remove_unused_brs=true,
  )
  guard optimize_for_size(bytes, config~) is Ok(optimized) else {
    assert_true(false)
    return
  }
  guard profile_module(optimized.bytes) is Ok(after) else {
    assert_true(false)
    return
  }
  assert_eq(after.code_body_bytes, 2U)
}

///|
test "optimize treats pass_rounds=0 as one round" {
  let bytes = sample_module_with_peephole_bytes()
  let config = make_optimize_config(
    strip_all_custom=false,
    strip_name_section=false,
    strip_producers_section=false,
    pass_rounds=0U,
    enable_peephole=true,
    enable_vacuum=false,
    enable_merge_blocks=false,
    enable_remove_unused_brs=false,
  )
  guard optimize_for_size(bytes, config~) is Ok(optimized) else {
    assert_true(false)
    return
  }
  guard profile_module(optimized.bytes) is Ok(after) else {
    assert_true(false)
    return
  }
  assert_eq(after.code_body_bytes, 4U)
}

///|
test "optimize with merge-similar-functions removes forwarding thunks" {
  let bytes = sample_module_with_similar_thunks_bytes()
  guard profile_module(bytes) is Ok(before_profile) else {
    assert_true(false)
    return
  }
  assert_eq(before_profile.function_count, 4U)
  let config = make_optimize_config(
    strip_all_custom=false,
    strip_name_section=false,
    strip_producers_section=false,
    enable_peephole=false,
    enable_dce=false,
    enable_dfe=false,
    enable_merge_similar_functions=true,
  )
  guard optimize_for_size(bytes, config~) is Ok(optimized) else {
    assert_true(false)
    return
  }
  assert_true(
    optimized.removed_sections.any(s => s.contains("msf:functions:2")),
  )
  guard profile_module(optimized.bytes) is Ok(after_profile) else {
    assert_true(false)
    return
  }
  assert_eq(after_profile.function_count, 2U)
  guard analyze_call_graph(optimized.bytes) is Ok(after_graph) else {
    assert_true(false)
    return
  }
  assert_eq(after_graph.nodes.length(), 2)
  assert_eq(after_graph.nodes[0].direct_callees, [1U])
  guard analyze_function_sizes(optimized.bytes) is Ok(functions) else {
    assert_true(false)
    return
  }
  assert_true(
    functions.any(f => f.function_index == 1U &&
      f.export_names.contains("alias")),
  )
}

///|
test "optimize with merge-similar-functions removes param-forwarding thunk" {
  let bytes = sample_module_with_param_forwarding_thunk_bytes()
  guard profile_module(bytes) is Ok(before_profile) else {
    assert_true(false)
    return
  }
  assert_eq(before_profile.function_count, 3U)
  let config = make_optimize_config(
    strip_all_custom=false,
    strip_name_section=false,
    strip_producers_section=false,
    enable_peephole=false,
    enable_vacuum=false,
    enable_merge_blocks=false,
    enable_remove_unused_brs=false,
    enable_dce=false,
    enable_dfe=false,
    enable_merge_similar_functions=true,
  )
  guard optimize_for_size(bytes, config~) is Ok(optimized) else {
    assert_true(false)
    return
  }
  assert_true(optimized.removed_sections.any(s => s.contains("msf:functions:")))
  guard profile_module(optimized.bytes) is Ok(after_profile) else {
    assert_true(false)
    return
  }
  assert_true(after_profile.function_count < before_profile.function_count)
  assert_true(after_profile.function_count <= 2U)
  assert_true(
    runtime_export_outputs_equal(bytes, optimized.bytes, "run", [
      -7, -1, 0, 1, 42, 123456,
    ]),
  )
}

///|
test "optimize cfp rewrites forwarding calls and enables dce without msf" {
  let bytes = sample_module_with_similar_thunks_bytes()
  guard profile_module(bytes) is Ok(before_profile) else {
    assert_true(false)
    return
  }
  assert_eq(before_profile.function_count, 4U)
  let config = make_optimize_config(
    strip_all_custom=false,
    strip_name_section=false,
    strip_producers_section=false,
    enable_peephole=false,
    enable_vacuum=false,
    enable_merge_blocks=false,
    enable_remove_unused_brs=false,
    enable_dce=true,
    enable_dfe=false,
    enable_merge_similar_functions=false,
  )
  guard optimize_for_size(bytes, config~) is Ok(optimized) else {
    assert_true(false)
    return
  }
  assert_true(optimized.removed_sections.any(s => s.contains("cfp:calls:2")))
  assert_true(
    optimized.removed_sections.any(s => s.contains("dce:functions:1")),
  )
  guard profile_module(optimized.bytes) is Ok(after_profile) else {
    assert_true(false)
    return
  }
  assert_eq(after_profile.function_count, 3U)
  guard analyze_call_graph(optimized.bytes) is Ok(after_graph) else {
    assert_true(false)
    return
  }
  assert_eq(after_graph.nodes.length(), 3)
  assert_eq(after_graph.nodes[0].direct_callees.length(), 1)
  assert_true(runtime_export_outputs_equal(bytes, optimized.bytes, "main", []))
}

///|
test "optimize cfp phase2 rewrites param-forwarding thunk and enables dce" {
  let bytes = sample_module_with_param_forwarding_thunk_bytes()
  guard profile_module(bytes) is Ok(before_profile) else {
    assert_true(false)
    return
  }
  assert_eq(before_profile.function_count, 3U)
  let config = make_optimize_config(
    strip_all_custom=false,
    strip_name_section=false,
    strip_producers_section=false,
    enable_peephole=false,
    enable_vacuum=false,
    enable_merge_blocks=false,
    enable_remove_unused_brs=false,
    enable_dce=true,
    enable_dfe=false,
    enable_merge_similar_functions=false,
  )
  guard optimize_for_size(bytes, config~) is Ok(optimized) else {
    assert_true(false)
    return
  }
  assert_true(optimized.removed_sections.any(s => s.contains("cfp:calls:1")))
  assert_true(
    optimized.removed_sections.any(s => s.contains("dce:functions:1")),
  )
  guard profile_module(optimized.bytes) is Ok(after_profile) else {
    assert_true(false)
    return
  }
  assert_eq(after_profile.function_count, 2U)
  assert_true(
    runtime_export_outputs_equal(bytes, optimized.bytes, "run", [
      -7, -1, 0, 1, 42, 123456,
    ]),
  )
}

///|
test "optimize cfp phase2 rewrites forwarding thunk with unused locals and enables dce" {
  let bytes = sample_module_with_param_forwarding_thunk_with_unused_local_bytes()
  guard profile_module(bytes) is Ok(before_profile) else {
    assert_true(false)
    return
  }
  assert_eq(before_profile.function_count, 3U)
  let config = make_optimize_config(
    strip_all_custom=false,
    strip_name_section=false,
    strip_producers_section=false,
    enable_peephole=false,
    enable_vacuum=false,
    enable_merge_blocks=false,
    enable_remove_unused_brs=false,
    enable_dce=true,
    enable_dfe=false,
    enable_merge_similar_functions=false,
  )
  guard optimize_for_size(bytes, config~) is Ok(optimized) else {
    assert_true(false)
    return
  }
  assert_true(optimized.removed_sections.any(s => s.contains("cfp:calls:1")))
  assert_true(
    optimized.removed_sections.any(s => s.contains("dce:functions:1")),
  )
  guard profile_module(optimized.bytes) is Ok(after_profile) else {
    assert_true(false)
    return
  }
  assert_eq(after_profile.function_count, 2U)
  assert_true(
    runtime_export_outputs_equal(bytes, optimized.bytes, "run", [
      -7, -1, 0, 1, 42, 123456,
    ]),
  )
}

///|
test "optimize cfp phase2 rewrites forwarding thunk with call+return and enables dce" {
  let bytes = sample_module_with_param_forwarding_call_return_thunk_bytes()
  guard profile_module(bytes) is Ok(before_profile) else {
    assert_true(false)
    return
  }
  assert_eq(before_profile.function_count, 3U)
  let config = make_optimize_config(
    strip_all_custom=false,
    strip_name_section=false,
    strip_producers_section=false,
    enable_peephole=false,
    enable_vacuum=false,
    enable_merge_blocks=false,
    enable_remove_unused_brs=false,
    enable_dce=true,
    enable_dfe=false,
    enable_merge_similar_functions=false,
  )
  guard optimize_for_size(bytes, config~) is Ok(optimized) else {
    assert_true(false)
    return
  }
  assert_true(optimized.removed_sections.any(s => s.contains("cfp:calls:1")))
  assert_true(
    optimized.removed_sections.any(s => s.contains("dce:functions:1")),
  )
  guard profile_module(optimized.bytes) is Ok(after_profile) else {
    assert_true(false)
    return
  }
  assert_eq(after_profile.function_count, 2U)
  assert_true(
    runtime_export_outputs_equal(bytes, optimized.bytes, "run", [
      -7, -1, 0, 1, 42, 123456,
    ]),
  )
}

///|
test "optimize cfp-const rewrites const-forwarding thunk and enables dce" {
  let bytes = sample_module_with_const_forwarding_thunk_bytes()
  guard profile_module(bytes) is Ok(before_profile) else {
    assert_true(false)
    return
  }
  assert_eq(before_profile.function_count, 3U)
  let config = make_optimize_config(
    strip_all_custom=false,
    strip_name_section=false,
    strip_producers_section=false,
    enable_peephole=false,
    enable_vacuum=false,
    enable_merge_blocks=false,
    enable_remove_unused_brs=false,
    enable_dce=true,
    enable_dfe=false,
    enable_merge_similar_functions=false,
  )
  guard optimize_for_size(bytes, config~) is Ok(optimized) else {
    assert_true(false)
    return
  }
  assert_true(
    optimized.removed_sections.any(s => s.contains("cfp-const:calls:1")),
  )
  assert_true(
    optimized.removed_sections.any(s => s.contains("dce:functions:1")),
  )
  guard profile_module(optimized.bytes) is Ok(after_profile) else {
    assert_true(false)
    return
  }
  assert_eq(after_profile.function_count, 2U)
  assert_true(
    runtime_export_outputs_equal(bytes, optimized.bytes, "run", [
      -7, -1, 0, 1, 42, 123456,
    ]),
  )
}

///|
test "optimize cfp-const rewrites thunk with unused locals and enables dce" {
  let bytes = sample_module_with_const_forwarding_thunk_with_unused_local_bytes()
  guard profile_module(bytes) is Ok(before_profile) else {
    assert_true(false)
    return
  }
  assert_eq(before_profile.function_count, 3U)
  let config = make_optimize_config(
    strip_all_custom=false,
    strip_name_section=false,
    strip_producers_section=false,
    enable_peephole=false,
    enable_vacuum=false,
    enable_merge_blocks=false,
    enable_remove_unused_brs=false,
    enable_dce=true,
    enable_dfe=false,
    enable_merge_similar_functions=false,
  )
  guard optimize_for_size(bytes, config~) is Ok(optimized) else {
    assert_true(false)
    return
  }
  assert_true(
    optimized.removed_sections.any(s => s.contains("cfp-const:calls:1")),
  )
  assert_true(
    optimized.removed_sections.any(s => s.contains("dce:functions:1")),
  )
  guard profile_module(optimized.bytes) is Ok(after_profile) else {
    assert_true(false)
    return
  }
  assert_eq(after_profile.function_count, 2U)
  assert_true(
    runtime_export_outputs_equal(bytes, optimized.bytes, "run", [
      -7, -1, 0, 1, 42, 123456,
    ]),
  )
}

///|
test "optimize cfp-const rewrites thunk with call+return and enables dce" {
  let bytes = sample_module_with_const_forwarding_call_return_thunk_bytes()
  guard profile_module(bytes) is Ok(before_profile) else {
    assert_true(false)
    return
  }
  assert_eq(before_profile.function_count, 3U)
  let config = make_optimize_config(
    strip_all_custom=false,
    strip_name_section=false,
    strip_producers_section=false,
    enable_peephole=false,
    enable_vacuum=false,
    enable_merge_blocks=false,
    enable_remove_unused_brs=false,
    enable_dce=true,
    enable_dfe=false,
    enable_merge_similar_functions=false,
  )
  guard optimize_for_size(bytes, config~) is Ok(optimized) else {
    assert_true(false)
    return
  }
  assert_true(
    optimized.removed_sections.any(s => s.contains("cfp-const:calls:1")),
  )
  assert_true(
    optimized.removed_sections.any(s => s.contains("dce:functions:1")),
  )
  guard profile_module(optimized.bytes) is Ok(after_profile) else {
    assert_true(false)
    return
  }
  assert_eq(after_profile.function_count, 2U)
  assert_true(
    runtime_export_outputs_equal(bytes, optimized.bytes, "run", [
      -7, -1, 0, 1, 42, 123456,
    ]),
  )
}

///|
test "optimize signature-refining phase3 rewrites mismatched forwarding thunk in gc mixed module" {
  let bytes = sample_module_with_gc_signature_refining_thunk_bytes()
  guard profile_module(bytes) is Ok(before_profile) else {
    assert_true(false)
    return
  }
  assert_eq(before_profile.function_count, 3U)
  let config = make_optimize_config(
    strip_all_custom=false,
    strip_name_section=false,
    strip_producers_section=false,
    pass_rounds=1U,
    enable_peephole=false,
    enable_vacuum=false,
    enable_merge_blocks=false,
    enable_remove_unused_brs=false,
    enable_dce=true,
    enable_dfe=false,
    enable_merge_similar_functions=false,
    closed_world=true,
    closed_world_root_exports=["run"],
  )
  guard optimize_for_size(bytes, config~) is Ok(optimized) else {
    assert_true(false)
    return
  }
  assert_true(
    optimized.removed_sections.any(s => s.contains("signature-refine:calls:1")),
  )
  assert_true(
    optimized.removed_sections.any(s => s.contains("dce:functions:1")),
  )
  guard profile_module(optimized.bytes) is Ok(after_profile) else {
    assert_true(false)
    return
  }
  assert_eq(after_profile.function_count, 2U)
  assert_true(
    runtime_export_outputs_equal(bytes, optimized.bytes, "run", [
      -9, -1, 0, 1, 7, 123456,
    ]),
  )
}

///|
test "optimize signature-refining phase3 rewrites forwarding thunk with call+return in gc mixed module" {
  let bytes = sample_module_with_gc_signature_refining_call_return_thunk_bytes()
  guard profile_module(bytes) is Ok(before_profile) else {
    assert_true(false)
    return
  }
  assert_eq(before_profile.function_count, 3U)
  let config = make_optimize_config(
    strip_all_custom=false,
    strip_name_section=false,
    strip_producers_section=false,
    pass_rounds=1U,
    enable_peephole=false,
    enable_vacuum=false,
    enable_merge_blocks=false,
    enable_remove_unused_brs=false,
    enable_dce=true,
    enable_dfe=false,
    enable_merge_similar_functions=false,
    closed_world=true,
    closed_world_root_exports=["run"],
  )
  guard optimize_for_size(bytes, config~) is Ok(optimized) else {
    assert_true(false)
    return
  }
  assert_true(
    optimized.removed_sections.any(s => s.contains("signature-refine:calls:1")),
  )
  assert_true(
    optimized.removed_sections.any(s => s.contains("dce:functions:1")),
  )
  guard profile_module(optimized.bytes) is Ok(after_profile) else {
    assert_true(false)
    return
  }
  assert_eq(after_profile.function_count, 2U)
  assert_true(
    runtime_export_outputs_equal(bytes, optimized.bytes, "run", [
      -9, -1, 0, 1, 7, 123456,
    ]),
  )
}

///|
test "optimize signature-refining phase3 rewrites forwarding thunk with unused locals in gc mixed module" {
  let bytes = sample_module_with_gc_signature_refining_thunk_with_unused_local_bytes()
  guard profile_module(bytes) is Ok(before_profile) else {
    assert_true(false)
    return
  }
  assert_eq(before_profile.function_count, 3U)
  let config = make_optimize_config(
    strip_all_custom=false,
    strip_name_section=false,
    strip_producers_section=false,
    pass_rounds=1U,
    enable_peephole=false,
    enable_vacuum=false,
    enable_merge_blocks=false,
    enable_remove_unused_brs=false,
    enable_dce=true,
    enable_dfe=false,
    enable_merge_similar_functions=false,
    closed_world=true,
    closed_world_root_exports=["run"],
  )
  guard optimize_for_size(bytes, config~) is Ok(optimized) else {
    assert_true(false)
    return
  }
  assert_true(
    optimized.removed_sections.any(s => s.contains("signature-refine:calls:1")),
  )
  assert_true(
    optimized.removed_sections.any(s => s.contains("dce:functions:1")),
  )
  guard profile_module(optimized.bytes) is Ok(after_profile) else {
    assert_true(false)
    return
  }
  assert_eq(after_profile.function_count, 2U)
  assert_true(
    runtime_export_outputs_equal(bytes, optimized.bytes, "run", [
      -9, -1, 0, 1, 7, 123456,
    ]),
  )
}

///|
test "optimize peephole removes nop and const-drop" {
  let bytes = sample_module_with_peephole_bytes()
  guard profile_module(bytes) is Ok(before) else {
    assert_true(false)
    return
  }
  assert_eq(before.code_body_bytes, 8U)
  let config = make_optimize_config(
    strip_all_custom=false,
    strip_name_section=false,
    strip_producers_section=false,
  )
  guard optimize_for_size(bytes, config~) is Ok(optimized) else {
    assert_true(false)
    return
  }
  assert_eq(optimized.removed_sections.length(), 0)
  guard profile_module(optimized.bytes) is Ok(after) else {
    assert_true(false)
    return
  }
  assert_eq(after.code_body_bytes, 4U)
  assert_true(optimized.after_size < optimized.before_size)
}

///|
test "optimize peephole precomputes i32.const+i32.const+i32.add" {
  let bytes = sample_module_with_i32_add_precompute_bytes()
  guard profile_module(bytes) is Ok(before) else {
    assert_true(false)
    return
  }
  assert_eq(before.code_body_bytes, 7U)
  let config = make_optimize_config(
    strip_all_custom=false,
    strip_name_section=false,
    strip_producers_section=false,
    enable_peephole=true,
    enable_vacuum=false,
    enable_merge_blocks=false,
    enable_remove_unused_brs=false,
    enable_dce=false,
    enable_dfe=false,
    enable_merge_similar_functions=false,
    enable_remove_unused_module_elements=false,
  )
  guard optimize_for_size(bytes, config~) is Ok(optimized) else {
    assert_true(false)
    return
  }
  guard profile_module(optimized.bytes) is Ok(after) else {
    assert_true(false)
    return
  }
  assert_eq(after.code_body_bytes, 4U)
  assert_true(bytes_contains_seq(optimized.bytes, [0x41, 0x2a, 0x0b]))
  assert_true(
    not(bytes_contains_seq(optimized.bytes, [0x41, 0x14, 0x41, 0x16, 0x6a])),
  )
}

///|
test "optimize peephole rewrites local.set+local.get to local.tee" {
  let bytes = sample_module_with_local_set_get_pair_bytes()
  guard profile_module(bytes) is Ok(before) else {
    assert_true(false)
    return
  }
  assert_eq(before.code_body_bytes, 10U)
  let config = make_optimize_config(
    strip_all_custom=false,
    strip_name_section=false,
    strip_producers_section=false,
    enable_peephole=true,
    enable_vacuum=false,
    enable_merge_blocks=false,
    enable_remove_unused_brs=false,
    enable_dce=false,
    enable_dfe=false,
    enable_merge_similar_functions=false,
    enable_remove_unused_module_elements=false,
  )
  guard optimize_for_size(bytes, config~) is Ok(optimized) else {
    assert_true(false)
    return
  }
  guard profile_module(optimized.bytes) is Ok(after) else {
    assert_true(false)
    return
  }
  assert_eq(after.code_body_bytes, 8U)
  assert_true(bytes_contains_seq(optimized.bytes, [0x22, 0x00]))
  assert_true(
    not(bytes_contains_seq(optimized.bytes, [0x21, 0x00, 0x20, 0x00])),
  )
}

///|
test "optimize peephole removes local.get+drop" {
  let bytes = sample_module_with_local_get_drop_bytes()
  guard profile_module(bytes) is Ok(before) else {
    assert_true(false)
    return
  }
  assert_eq(before.code_body_bytes, 5U)
  let config = make_optimize_config(
    strip_all_custom=false,
    strip_name_section=false,
    strip_producers_section=false,
    enable_peephole=true,
    enable_vacuum=false,
    enable_merge_blocks=false,
    enable_remove_unused_brs=false,
    enable_dce=false,
    enable_dfe=false,
    enable_merge_similar_functions=false,
    enable_remove_unused_module_elements=false,
  )
  guard optimize_for_size(bytes, config~) is Ok(optimized) else {
    assert_true(false)
    return
  }
  guard profile_module(optimized.bytes) is Ok(after) else {
    assert_true(false)
    return
  }
  assert_eq(after.code_body_bytes, 2U)
  assert_true(not(bytes_contains_seq(optimized.bytes, [0x20, 0x00, 0x1a])))
}

///|
test "optimize peephole rewrites local.tee+drop to local.set" {
  let bytes = sample_module_with_local_tee_drop_bytes()
  guard profile_module(bytes) is Ok(before) else {
    assert_true(false)
    return
  }
  assert_eq(before.code_body_bytes, 9U)
  let config = make_optimize_config(
    strip_all_custom=false,
    strip_name_section=false,
    strip_producers_section=false,
    enable_peephole=true,
    enable_vacuum=false,
    enable_merge_blocks=false,
    enable_remove_unused_brs=false,
    enable_dce=false,
    enable_dfe=false,
    enable_merge_similar_functions=false,
    enable_remove_unused_module_elements=false,
  )
  guard optimize_for_size(bytes, config~) is Ok(optimized) else {
    assert_true(false)
    return
  }
  guard profile_module(optimized.bytes) is Ok(after) else {
    assert_true(false)
    return
  }
  assert_eq(after.code_body_bytes, 8U)
  assert_true(bytes_contains_seq(optimized.bytes, [0x21, 0x00]))
  assert_true(not(bytes_contains_seq(optimized.bytes, [0x22, 0x00, 0x1a])))
}

///|
test "optimize peephole removes local.get+local.set noop" {
  let bytes = sample_module_with_local_get_set_noop_bytes()
  guard profile_module(bytes) is Ok(before) else {
    assert_true(false)
    return
  }
  assert_eq(before.code_body_bytes, 6U)
  let config = make_optimize_config(
    strip_all_custom=false,
    strip_name_section=false,
    strip_producers_section=false,
    enable_peephole=true,
    enable_vacuum=false,
    enable_merge_blocks=false,
    enable_remove_unused_brs=false,
    enable_dce=false,
    enable_dfe=false,
    enable_merge_similar_functions=false,
    enable_remove_unused_module_elements=false,
  )
  guard optimize_for_size(bytes, config~) is Ok(optimized) else {
    assert_true(false)
    return
  }
  guard profile_module(optimized.bytes) is Ok(after) else {
    assert_true(false)
    return
  }
  assert_eq(after.code_body_bytes, 2U)
  assert_true(
    not(bytes_contains_seq(optimized.bytes, [0x20, 0x00, 0x21, 0x00])),
  )
}

///|
test "optimize peephole simplifies local.get+local.tee to local.get" {
  let bytes = sample_module_with_local_get_tee_pair_bytes()
  guard profile_module(bytes) is Ok(before) else {
    assert_true(false)
    return
  }
  assert_eq(before.code_body_bytes, 6U)
  let config = make_optimize_config(
    strip_all_custom=false,
    strip_name_section=false,
    strip_producers_section=false,
    enable_peephole=true,
    enable_vacuum=false,
    enable_merge_blocks=false,
    enable_remove_unused_brs=false,
    enable_dce=false,
    enable_dfe=false,
    enable_merge_similar_functions=false,
    enable_remove_unused_module_elements=false,
  )
  guard optimize_for_size(bytes, config~) is Ok(optimized) else {
    assert_true(false)
    return
  }
  guard profile_module(optimized.bytes) is Ok(after) else {
    assert_true(false)
    return
  }
  assert_eq(after.code_body_bytes, 4U)
  assert_true(
    not(bytes_contains_seq(optimized.bytes, [0x20, 0x00, 0x22, 0x00])),
  )
}

///|
test "optimize peephole removes i32 arithmetic identity operations" {
  let bytes = sample_module_with_i32_identity_ops_bytes()
  guard profile_module(bytes) is Ok(before) else {
    assert_true(false)
    return
  }
  assert_eq(before.code_body_bytes, 13U)
  let config = make_optimize_config(
    strip_all_custom=false,
    strip_name_section=false,
    strip_producers_section=false,
    enable_peephole=true,
    enable_vacuum=false,
    enable_merge_blocks=false,
    enable_remove_unused_brs=false,
    enable_dce=false,
    enable_dfe=false,
    enable_merge_similar_functions=false,
    enable_remove_unused_module_elements=false,
  )
  guard optimize_for_size(bytes, config~) is Ok(optimized) else {
    assert_true(false)
    return
  }
  guard profile_module(optimized.bytes) is Ok(after) else {
    assert_true(false)
    return
  }
  assert_eq(after.code_body_bytes, 4U)
  assert_true(bytes_contains_seq(optimized.bytes, [0x20, 0x00, 0x0b]))
  assert_true(not(bytes_contains_seq(optimized.bytes, [0x41, 0x00, 0x6a])))
  assert_true(not(bytes_contains_seq(optimized.bytes, [0x41, 0x00, 0x6b])))
  assert_true(not(bytes_contains_seq(optimized.bytes, [0x41, 0x01, 0x6c])))
}

///|
test "optimize-instructions simplifies i32 identity and same-local patterns" {
  let bytes = sample_module_with_optimize_instructions_bytes()
  guard profile_module(bytes) is Ok(before) else {
    assert_true(false)
    return
  }
  assert_eq(before.code_body_bytes, 16U)
  let config = make_optimize_config(
    strip_all_custom=false,
    strip_name_section=false,
    strip_producers_section=false,
    enable_peephole=true,
    enable_vacuum=false,
    enable_merge_blocks=false,
    enable_remove_unused_brs=false,
    enable_dce=false,
    enable_dfe=false,
    enable_merge_similar_functions=false,
    enable_remove_unused_module_elements=false,
  )
  guard optimize_for_size(bytes, config~) is Ok(optimized) else {
    assert_true(false)
    return
  }
  guard profile_module(optimized.bytes) is Ok(after) else {
    assert_true(false)
    return
  }
  assert_eq(after.code_body_bytes, 4U)
  assert_true(bytes_contains_seq(optimized.bytes, [0x20, 0x00, 0x0b]))
  assert_true(not(bytes_contains_seq(optimized.bytes, [0x41, 0x00, 0x72])))
  assert_true(not(bytes_contains_seq(optimized.bytes, [0x41, 0x00, 0x74])))
  assert_true(
    not(bytes_contains_seq(optimized.bytes, [0x20, 0x00, 0x20, 0x00, 0x73])),
  )
  assert_true(
    runtime_export_outputs_equal(bytes, optimized.bytes, "run", [
      -7, -1, 0, 1, 42, 123456,
    ]),
  )
}

///|
test "optimize-instructions simplifies bitwise and cmp with i32.const 0" {
  let bytes = sample_module_with_optimize_instructions_bitwise_cmp_bytes()
  guard profile_module(bytes) is Ok(before) else {
    assert_true(false)
    return
  }
  assert_eq(before.code_body_bytes, 26U)
  let config = make_optimize_config(
    strip_all_custom=false,
    strip_name_section=false,
    strip_producers_section=false,
    enable_peephole=true,
    enable_vacuum=false,
    enable_merge_blocks=false,
    enable_remove_unused_brs=false,
    enable_dce=false,
    enable_dfe=false,
    enable_merge_similar_functions=false,
    enable_remove_unused_module_elements=false,
  )
  guard optimize_for_size(bytes, config~) is Ok(optimized) else {
    assert_true(false)
    return
  }
  guard profile_module(optimized.bytes) is Ok(after) else {
    assert_true(false)
    return
  }
  assert_true(after.code_body_bytes < before.code_body_bytes)
  assert_true(not(bytes_contains_seq(optimized.bytes, [0x41, 0x00, 0x49])))
  assert_true(not(bytes_contains_seq(optimized.bytes, [0x41, 0x00, 0x4f])))
  assert_true(not(bytes_contains_seq(optimized.bytes, [0x41, 0x00, 0x71])))
  assert_true(not(bytes_contains_seq(optimized.bytes, [0x41, 0x00, 0x46])))
  assert_true(
    runtime_export_outputs_equal(bytes, optimized.bytes, "run", [
      -7, -1, 0, 1, 42, 123456,
    ]),
  )
}

///|
test "optimize-instructions simplifies const-first bitwise and cmp patterns" {
  let bytes = sample_module_with_optimize_instructions_const_first_bytes()
  guard profile_module(bytes) is Ok(before) else {
    assert_true(false)
    return
  }
  assert_eq(before.code_body_bytes, 25U)
  let config = make_optimize_config(
    strip_all_custom=false,
    strip_name_section=false,
    strip_producers_section=false,
    enable_peephole=true,
    enable_vacuum=false,
    enable_merge_blocks=false,
    enable_remove_unused_brs=false,
    enable_dce=false,
    enable_dfe=false,
    enable_merge_similar_functions=false,
    enable_remove_unused_module_elements=false,
  )
  guard optimize_for_size(bytes, config~) is Ok(optimized) else {
    assert_true(false)
    return
  }
  guard profile_module(optimized.bytes) is Ok(after) else {
    assert_true(false)
    return
  }
  assert_true(after.code_body_bytes < before.code_body_bytes)
  assert_true(
    not(bytes_contains_seq(optimized.bytes, [0x41, 0x00, 0x20, 0x00, 0x46])),
  )
  assert_true(
    not(bytes_contains_seq(optimized.bytes, [0x41, 0x00, 0x20, 0x00, 0x47])),
  )
  assert_true(
    not(bytes_contains_seq(optimized.bytes, [0x41, 0x00, 0x20, 0x00, 0x72])),
  )
  assert_true(
    not(bytes_contains_seq(optimized.bytes, [0x41, 0x7f, 0x20, 0x00, 0x71])),
  )
  assert_true(
    runtime_export_outputs_equal(bytes, optimized.bytes, "run", [
      -7, -1, 0, 1, 42, 123456,
    ]),
  )
}

///|
test "optimize local-cse rewrites local.get+local.set+local.get" {
  let bytes = sample_module_with_local_cse_get_set_get_bytes()
  guard profile_module(bytes) is Ok(before) else {
    assert_true(false)
    return
  }
  assert_eq(before.code_body_bytes, 10U)
  let config = make_optimize_config(
    strip_all_custom=false,
    strip_name_section=false,
    strip_producers_section=false,
    enable_peephole=true,
    enable_vacuum=false,
    enable_merge_blocks=false,
    enable_remove_unused_brs=false,
    enable_dce=false,
    enable_dfe=false,
    enable_merge_similar_functions=false,
    enable_remove_unused_module_elements=false,
  )
  guard optimize_for_size(bytes, config~) is Ok(optimized) else {
    assert_true(false)
    return
  }
  guard profile_module(optimized.bytes) is Ok(after) else {
    assert_true(false)
    return
  }
  assert_eq(after.code_body_bytes, 8U)
  assert_true(
    bytes_contains_seq(optimized.bytes, [0x20, 0x00, 0x22, 0x01, 0x0b]),
  )
  assert_true(
    not(
      bytes_contains_seq(optimized.bytes, [0x20, 0x00, 0x21, 0x01, 0x20, 0x00]),
    ),
  )
}

///|
test "optimize rse rewrites local.tee+local.set(same) to local.set" {
  let bytes = sample_module_with_local_tee_set_same_bytes()
  guard profile_module(bytes) is Ok(before) else {
    assert_true(false)
    return
  }
  assert_eq(before.code_body_bytes, 10U)
  let config = make_optimize_config(
    strip_all_custom=false,
    strip_name_section=false,
    strip_producers_section=false,
    enable_peephole=true,
    enable_vacuum=false,
    enable_merge_blocks=false,
    enable_remove_unused_brs=false,
    enable_dce=false,
    enable_dfe=false,
    enable_merge_similar_functions=false,
    enable_remove_unused_module_elements=false,
  )
  guard optimize_for_size(bytes, config~) is Ok(optimized) else {
    assert_true(false)
    return
  }
  guard profile_module(optimized.bytes) is Ok(after) else {
    assert_true(false)
    return
  }
  assert_eq(after.code_body_bytes, 8U)
  assert_true(
    bytes_contains_seq(optimized.bytes, [0x41, 0x01, 0x21, 0x00, 0x0b]),
  )
  assert_true(
    not(bytes_contains_seq(optimized.bytes, [0x22, 0x00, 0x21, 0x00])),
  )
}

///|
test "optimize local simplify chain reaches fixed-point" {
  let bytes = sample_module_with_local_chain_simplify_bytes()
  guard profile_module(bytes) is Ok(before) else {
    assert_true(false)
    return
  }
  assert_eq(before.code_body_bytes, 8U)
  let config = make_optimize_config(
    strip_all_custom=false,
    strip_name_section=false,
    strip_producers_section=false,
    enable_peephole=true,
    enable_vacuum=false,
    enable_merge_blocks=false,
    enable_remove_unused_brs=false,
    enable_dce=false,
    enable_dfe=false,
    enable_merge_similar_functions=false,
    enable_remove_unused_module_elements=false,
  )
  guard optimize_for_size(bytes, config~) is Ok(optimized) else {
    assert_true(false)
    return
  }
  guard profile_module(optimized.bytes) is Ok(after) else {
    assert_true(false)
    return
  }
  assert_eq(after.code_body_bytes, 2U)
  assert_true(
    not(bytes_contains_seq(optimized.bytes, [0x20, 0x00, 0x22, 0x00])),
  )
  assert_true(
    not(bytes_contains_seq(optimized.bytes, [0x20, 0x00, 0x21, 0x00])),
  )
}

///|
test "optimize precompute removes i32.const 0 + br_if" {
  let bytes = sample_module_with_br_if_const_zero_bytes()
  guard profile_module(bytes) is Ok(before) else {
    assert_true(false)
    return
  }
  assert_eq(before.code_body_bytes, 9U)
  let config = make_optimize_config(
    strip_all_custom=false,
    strip_name_section=false,
    strip_producers_section=false,
    enable_peephole=true,
    peephole_remove_nop=false,
    peephole_remove_const_drop=false,
    enable_vacuum=false,
    enable_merge_blocks=false,
    enable_remove_unused_brs=false,
    enable_dce=false,
    enable_dfe=false,
    enable_merge_similar_functions=false,
    enable_remove_unused_module_elements=false,
  )
  guard optimize_for_size(bytes, config~) is Ok(optimized) else {
    assert_true(false)
    return
  }
  guard profile_module(optimized.bytes) is Ok(after) else {
    assert_true(false)
    return
  }
  assert_eq(after.code_body_bytes, 5U)
  assert_true(
    not(bytes_contains_seq(optimized.bytes, [0x41, 0x00, 0x0d, 0x00])),
  )
}

///|
test "optimize precompute rewrites i32.const nonzero + br_if to br" {
  let bytes = sample_module_with_br_if_const_nonzero_bytes()
  guard profile_module(bytes) is Ok(before) else {
    assert_true(false)
    return
  }
  assert_eq(before.code_body_bytes, 9U)
  let config = make_optimize_config(
    strip_all_custom=false,
    strip_name_section=false,
    strip_producers_section=false,
    enable_peephole=true,
    peephole_remove_nop=false,
    peephole_remove_const_drop=false,
    enable_vacuum=false,
    enable_merge_blocks=false,
    enable_remove_unused_brs=false,
    enable_dce=false,
    enable_dfe=false,
    enable_merge_similar_functions=false,
    enable_remove_unused_module_elements=false,
  )
  guard optimize_for_size(bytes, config~) is Ok(optimized) else {
    assert_true(false)
    return
  }
  guard profile_module(optimized.bytes) is Ok(after) else {
    assert_true(false)
    return
  }
  assert_eq(after.code_body_bytes, 7U)
  assert_true(
    bytes_contains_seq(optimized.bytes, [0x02, 0x40, 0x0c, 0x00, 0x0b]),
  )
  assert_true(
    not(bytes_contains_seq(optimized.bytes, [0x41, 0x01, 0x0d, 0x00])),
  )
}

///|
test "optimize precompute removes i32.eqz+i32.eqz before br_if" {
  let bytes = sample_module_with_double_eqz_br_if_bytes()
  guard profile_module(bytes) is Ok(before) else {
    assert_true(false)
    return
  }
  assert_eq(before.code_body_bytes, 11U)
  let config = make_optimize_config(
    strip_all_custom=false,
    strip_name_section=false,
    strip_producers_section=false,
    enable_peephole=true,
    peephole_remove_nop=false,
    peephole_remove_const_drop=false,
    enable_vacuum=false,
    enable_merge_blocks=false,
    enable_remove_unused_brs=false,
    enable_dce=false,
    enable_dfe=false,
    enable_merge_similar_functions=false,
    enable_remove_unused_module_elements=false,
  )
  guard optimize_for_size(bytes, config~) is Ok(optimized) else {
    assert_true(false)
    return
  }
  guard profile_module(optimized.bytes) is Ok(after) else {
    assert_true(false)
    return
  }
  assert_eq(after.code_body_bytes, 9U)
  assert_true(bytes_contains_seq(optimized.bytes, [0x20, 0x00, 0x0d, 0x00]))
  assert_true(
    not(
      bytes_contains_seq(optimized.bytes, [0x20, 0x00, 0x45, 0x45, 0x0d, 0x00]),
    ),
  )
  assert_true(
    runtime_export_outputs_equal(bytes, optimized.bytes, "run", [
      -7, -1, 0, 1, 42,
    ]),
  )
}

///|
test "optimize precompute propagates local const and folds arithmetic" {
  let bytes = sample_module_with_local_const_propagation_bytes()
  guard profile_module(bytes) is Ok(before) else {
    assert_true(false)
    return
  }
  assert_eq(before.code_body_bytes, 14U)
  let config = make_optimize_config(
    strip_all_custom=false,
    strip_name_section=false,
    strip_producers_section=false,
    enable_peephole=true,
    enable_vacuum=false,
    enable_merge_blocks=false,
    enable_remove_unused_brs=false,
    enable_dce=false,
    enable_dfe=false,
    enable_merge_similar_functions=false,
    enable_remove_unused_module_elements=false,
  )
  guard optimize_for_size(bytes, config~) is Ok(optimized) else {
    assert_true(false)
    return
  }
  guard profile_module(optimized.bytes) is Ok(after) else {
    assert_true(false)
    return
  }
  assert_true(after.code_body_bytes < before.code_body_bytes)
  assert_true(bytes_contains_seq(optimized.bytes, [0x41, 0x2b, 0x0b]))
  assert_true(not(bytes_contains_seq(optimized.bytes, [0x20, 0x00])))
  assert_true(runtime_export_outputs_equal(bytes, optimized.bytes, "run", []))
}

///|
test "optimize peephole preserves runtime outputs for zero-arg i32 exports" {
  let config = make_optimize_config(
    strip_all_custom=false,
    strip_name_section=false,
    strip_producers_section=false,
    enable_peephole=true,
    enable_vacuum=false,
    enable_merge_blocks=false,
    enable_remove_unused_brs=false,
    enable_dce=false,
    enable_dfe=false,
    enable_merge_similar_functions=false,
    enable_remove_unused_module_elements=false,
  )
  let bytes0 = sample_module_with_peephole_bytes()
  guard optimize_for_size(bytes0, config~) is Ok(optimized0) else {
    assert_true(false)
    return
  }
  assert_true(runtime_export_outputs_equal(bytes0, optimized0.bytes, "run", []))
  let bytes1 = sample_module_with_i32_add_precompute_bytes()
  guard optimize_for_size(bytes1, config~) is Ok(optimized1) else {
    assert_true(false)
    return
  }
  assert_true(runtime_export_outputs_equal(bytes1, optimized1.bytes, "run", []))
  let bytes2 = sample_module_with_local_set_get_pair_bytes()
  guard optimize_for_size(bytes2, config~) is Ok(optimized2) else {
    assert_true(false)
    return
  }
  assert_true(runtime_export_outputs_equal(bytes2, optimized2.bytes, "run", []))
}

///|
test "optimize peephole preserves runtime outputs for unary i32 export" {
  let bytes = sample_module_with_i32_identity_ops_bytes()
  let config = make_optimize_config(
    strip_all_custom=false,
    strip_name_section=false,
    strip_producers_section=false,
    enable_peephole=true,
    enable_vacuum=false,
    enable_merge_blocks=false,
    enable_remove_unused_brs=false,
    enable_dce=false,
    enable_dfe=false,
    enable_merge_similar_functions=false,
    enable_remove_unused_module_elements=false,
  )
  guard optimize_for_size(bytes, config~) is Ok(optimized) else {
    assert_true(false)
    return
  }
  assert_true(
    runtime_export_outputs_equal(bytes, optimized.bytes, "run", [
      -7, -1, 0, 1, 42, 123456,
    ]),
  )
}

///|
test "optimize with dce apply directizes const call_indirect to call" {
  let bytes = sample_module_with_call_indirect_type_gap_bytes()
  let config = make_optimize_config(
    strip_all_custom=false,
    strip_name_section=false,
    strip_producers_section=false,
    enable_peephole=false,
    enable_vacuum=false,
    enable_merge_blocks=false,
    enable_remove_unused_brs=false,
    enable_dce=true,
    enable_dfe=false,
    enable_merge_similar_functions=false,
    enable_remove_unused_module_elements=false,
  )
  guard optimize_for_size(bytes, config~) is Ok(optimized) else {
    assert_true(false)
    return
  }
  assert_true(
    optimized.removed_sections.any(s => s.contains("directize:calls:1")),
  )
  assert_true(bytes_contains_seq(optimized.bytes, [0x10, 0x00]))
  assert_true(not(bytes_contains_seq(optimized.bytes, [0x11, 0x01, 0x00])))
}

///|
test "optimize with dce apply skips partial call graph modules" {
  let bytes = @fs.read_file_to_bytes(
    "bench/corpus/core/binaryen/gc_target_feature.wasm",
  ) catch {
    _ => {
      assert_true(false)
      return
    }
  }
  let config = make_optimize_config(
    strip_all_custom=false,
    strip_name_section=false,
    strip_producers_section=false,
    strip_debug_sections=false,
    strip_dwarf_sections=false,
    strip_target_features_section=false,
    enable_peephole=false,
    enable_vacuum=false,
    enable_merge_blocks=false,
    enable_remove_unused_brs=false,
    enable_dce=true,
    enable_dfe=false,
    enable_merge_similar_functions=false,
    enable_remove_unused_module_elements=false,
  )
  guard optimize_for_size(bytes, config~) is Ok(optimized) else {
    assert_true(false)
    return
  }
  assert_eq(optimized.before_size, optimized.after_size)
  assert_eq(optimized.removed_sections.length(), 0)
  assert_true(
    optimized.no_change_reasons.any(r => r.contains("partial call graph")),
  )
}

///|
test "optimize coalesces unused locals and remaps local indices" {
  let bytes = sample_module_with_unused_locals_for_coalesce_bytes()
  guard profile_module(bytes) is Ok(before) else {
    assert_true(false)
    return
  }
  assert_true(before.code_body_bytes > 0U)
  let config = make_optimize_config(
    strip_all_custom=false,
    strip_name_section=false,
    strip_producers_section=false,
    enable_peephole=true,
    enable_vacuum=false,
    enable_merge_blocks=false,
    enable_remove_unused_brs=false,
    enable_dce=false,
    enable_dfe=false,
    enable_merge_similar_functions=false,
    enable_remove_unused_module_elements=false,
  )
  guard optimize_for_size(bytes, config~) is Ok(optimized) else {
    assert_true(false)
    return
  }
  guard profile_module(optimized.bytes) is Ok(after) else {
    assert_true(false)
    return
  }
  assert_true(after.code_body_bytes < before.code_body_bytes)
  assert_true(
    optimized.removed_sections.any(s => s.contains("coalesce-locals:removed:1")),
  )
  assert_true(not(bytes_contains_seq(optimized.bytes, [0x21, 0x01])))
  assert_true(not(bytes_contains_seq(optimized.bytes, [0x20, 0x01])))
  assert_true(runtime_export_outputs_equal(bytes, optimized.bytes, "run", []))
}

///|
test "optimize reports no-change reasons when all passes are disabled" {
  let bytes = sample_module_bytes()
  let config = make_optimize_config(
    strip_all_custom=false,
    strip_name_section=false,
    strip_producers_section=false,
    strip_debug_sections=false,
    strip_dwarf_sections=false,
    strip_target_features_section=false,
    enable_peephole=false,
    enable_vacuum=false,
    enable_merge_blocks=false,
    enable_remove_unused_brs=false,
    enable_dce=false,
    enable_dfe=false,
    enable_merge_similar_functions=false,
    enable_remove_unused_module_elements=false,
  )
  guard optimize_for_size(bytes, config~) is Ok(optimized) else {
    assert_true(false)
    return
  }
  assert_eq(optimized.before_size, optimized.after_size)
  assert_true(
    optimized.no_change_reasons.contains(
      "no optimization pass is enabled in config",
    ),
  )
}

///|
test "optimize -O1 runs dce and drops empty function/code sections" {
  let bytes = @fs.read_file_to_bytes(
    "bench/corpus/core/binaryen/br_to_exit.wasm",
  ) catch {
    _ => {
      assert_true(false)
      return
    }
  }
  let config = OptimizeConfig::o1()
  guard optimize_for_size(bytes, config~) is Ok(optimized) else {
    assert_true(false)
    return
  }
  assert_eq(optimized.after_size, 8U)
  guard profile_module(optimized.bytes) is Ok(profile) else {
    assert_true(false)
    return
  }
  assert_eq(profile.function_count, 0U)
  assert_eq(profile.code_body_count, 0U)
}

///|
test "runtime profiler profiles zero-arg exports" {
  let bytes = sample_module_with_peephole_bytes()
  guard profile_runtime_zero_arg_exports(bytes, iterations=5U) is Ok(profile) else {
    assert_true(false)
    return
  }
  assert_eq(profile.iterations, 5U)
  assert_true(profile.instantiate_ns > 0UL)
  assert_true(profile.functions.length() > 0)
  assert_true(profile.functions.any(f => f.calls == 5U))
}

///|
test "analyze hotness-size matrix combines runtime and body-size signals" {
  let bytes = sample_module_with_hot_size_runtime_gap_bytes()
  guard analyze_hotness_size_matrix(bytes, iterations=200U) is Ok(report) else {
    assert_true(false)
    return
  }
  assert_eq(report.entries.length(), 2)
  assert_eq(report.unresolved_exports.length(), 0)
  assert_true(report.hot_threshold_ns > 0UL)
  assert_true(report.large_threshold_bytes > 0U)
  guard find_hotness_size_entry(report.entries, "heavy") is Some(heavy_entry) else {
    assert_true(false)
    return
  }
  guard find_hotness_size_entry(report.entries, "light") is Some(light_entry) else {
    assert_true(false)
    return
  }
  assert_eq(heavy_entry.function_index, Some(1U))
  assert_eq(light_entry.function_index, Some(0U))
  assert_true(heavy_entry.body_bytes > light_entry.body_bytes)
  assert_true(heavy_entry.bucket.contains("large"))
  assert_true(light_entry.bucket.contains("small"))
  guard find_hotness_size_bucket(report.buckets, heavy_entry.bucket)
    is Some(heavy_bucket) else {
    assert_true(false)
    return
  }
  guard find_hotness_size_bucket(report.buckets, light_entry.bucket)
    is Some(light_bucket) else {
    assert_true(false)
    return
  }
  assert_true(heavy_bucket.count >= 1U)
  assert_true(light_bucket.count >= 1U)
}

///|
test "optimize -O1 preserves zlib runtime behavior with stub imports" {
  let bytes = @fs.read_file_to_bytes("bench/corpus/core/binaryen/zlib.wasm") catch {
    _ => {
      assert_true(false)
      return
    }
  }
  let config = OptimizeConfig::o1()
  guard optimize_for_size(bytes, config~) is Ok(optimized) else {
    assert_true(false)
    return
  }
  assert_true(optimized.after_size <= optimized.before_size)
  assert_true(runtime_zlib_behaviors_equal(bytes, optimized.bytes))
}

///|
test "profile component with nested core modules" {
  let component_path = "../mwac/examples/hello/hello.component.wasm"
  let bytes = @fs.read_file_to_bytes(component_path) catch {
    _ => {
      inspect("skip", content="skip")
      return
    }
  }
  guard profile_component(bytes) is Ok(profile) else {
    assert_true(false)
    return
  }
  assert_true(profile.core_module_count > 0U)
  assert_true(profile.export_count > 0U)
  assert_eq(
    profile.core_modules.length().reinterpret_as_uint(),
    profile.core_module_count,
  )
}

///|
test "component contract report with wit resolve" {
  let component_path = "../mwac/examples/hello/hello.component.wasm"
  let wit_path = "../mwac/examples/hello/wit"
  let bytes = @fs.read_file_to_bytes(component_path) catch {
    _ => {
      inspect("skip", content="skip")
      return
    }
  }
  let resolved = match @wit.resolve_path(wit_path) {
    Ok(v) => v
    Err(_) => {
      inspect("skip", content="skip")
      return
    }
  }
  guard analyze_component_contract(bytes, resolved) is Ok(report) else {
    assert_true(false)
    return
  }
  assert_true(report.component_exports.length() > 0)
  assert_true(report.wit_exports.length() > 0)
}

///|
test "component root policy report combines component/wit/canonical roots" {
  let component_path = "../mwac/examples/hello/hello.component.wasm"
  let wit_path = "../mwac/examples/hello/wit"
  let bytes = @fs.read_file_to_bytes(component_path) catch {
    _ => {
      inspect("skip", content="skip")
      return
    }
  }
  let resolved = match @wit.resolve_path(wit_path) {
    Ok(v) => v
    Err(_) => {
      inspect("skip", content="skip")
      return
    }
  }
  guard analyze_component_root_policy(bytes, resolved_wit=Some(resolved))
    is Ok(policy) else {
    assert_true(false)
    return
  }
  assert_true(policy.component_exports.length() > 0)
  assert_true(policy.wit_exports.length() > 0)
  assert_true(policy.canonical_abi_roots.contains("cabi_realloc"))
  assert_true(
    policy.root_name_candidates.length() >= policy.component_exports.length(),
  )
}

///|
test "component root policy can include dce exclude roots" {
  let component_path = "bench/corpus/component-dce/mwac/wac_greeter.wasm"
  let bytes = @fs.read_file_to_bytes(component_path) catch {
    _ => {
      inspect("skip", content="skip")
      return
    }
  }
  guard analyze_component_root_policy(bytes, exclude=["hello"]) is Ok(policy) else {
    assert_true(false)
    return
  }
  assert_true(policy.root_name_candidates.contains("hello"))
}

///|
test "component function size report returns core module entries" {
  let component_path = "../mwac/examples/hello/hello.component.wasm"
  let bytes = @fs.read_file_to_bytes(component_path) catch {
    _ => {
      inspect("skip", content="skip")
      return
    }
  }
  guard analyze_component_function_sizes(bytes) is Ok(reports) else {
    assert_true(false)
    return
  }
  assert_true(reports.length() > 0)
  assert_true(reports.any(r => r.function_count > 0U))
}

///|
test "component call graph report returns core module entries" {
  let component_path = "../mwac/examples/hello/hello.component.wasm"
  let bytes = @fs.read_file_to_bytes(component_path) catch {
    _ => {
      inspect("skip", content="skip")
      return
    }
  }
  guard analyze_component_call_graphs(bytes) is Ok(reports) else {
    assert_true(false)
    return
  }
  assert_true(reports.length() > 0)
  assert_true(reports.any(r => r.graph.local_function_count > 0U))
}

///|
test "bench corpus core fixtures are parseable as core wasm" {
  for path in bench_core_corpus_paths() {
    let bytes = @fs.read_file_to_bytes(path) catch {
      _ => {
        inspect(path, content="missing")
        assert_true(false)
        return
      }
    }
    guard profile_module(bytes) is Ok(profile) else {
      inspect(path, content="core parse failed")
      assert_true(false)
      return
    }
    assert_true(profile.total_bytes > 0U)
  }
}

///|
test "kpi core corpus -O1 does not increase size" {
  let config = OptimizeConfig::o1()
  for path in bench_core_corpus_paths() {
    let bytes = @fs.read_file_to_bytes(path) catch {
      _ => {
        inspect(path, content="missing")
        assert_true(false)
        return
      }
    }
    guard optimize_for_size(bytes, config~) is Ok(result) else {
      inspect(path, content="optimize failed")
      assert_true(false)
      return
    }
    assert_true(result.after_size <= result.before_size)
  }
}

///|
test "kpi core runtime corpus -O1 preserves runtime behavior" {
  let config = OptimizeConfig::o1()
  for path in bench_core_runtime_corpus_paths() {
    let bytes = @fs.read_file_to_bytes(path) catch {
      _ => {
        inspect(path, content="missing")
        assert_true(false)
        return
      }
    }
    guard optimize_for_size(bytes, config~) is Ok(result) else {
      inspect(path, content="optimize failed")
      assert_true(false)
      return
    }
    let ok = if path.contains("zlib.wasm") {
      runtime_zlib_behaviors_equal(bytes, result.bytes)
    } else {
      runtime_zero_arg_export_behaviors_equal(bytes, result.bytes)
    }
    if not(ok) {
      inspect(path, content="runtime mismatch")
      assert_true(false)
      return
    }
  }
}

///|
test "bench corpus component fixtures are parseable as component wasm" {
  for path in bench_component_corpus_paths() {
    let bytes = @fs.read_file_to_bytes(path) catch {
      _ => {
        inspect(path, content="missing")
        assert_true(false)
        return
      }
    }
    guard profile_component(bytes) is Ok(profile) else {
      inspect(path, content="component parse failed")
      assert_true(false)
      return
    }
    assert_true(profile.total_bytes > 0U)
  }
}

///|
test "component dce corpus fixtures are parseable as component wasm" {
  for path in bench_component_dce_corpus_paths() {
    let bytes = @fs.read_file_to_bytes(path) catch {
      _ => {
        inspect(path, content="missing")
        assert_true(false)
        return
      }
    }
    guard profile_component(bytes) is Ok(profile) else {
      inspect(path, content="component parse failed")
      assert_true(false)
      return
    }
    assert_true(profile.total_bytes > 0U)
  }
}

///|
test "component dce corpus can run component core optimize kpi config" {
  for path in bench_component_dce_corpus_paths() {
    let bytes = @fs.read_file_to_bytes(path) catch {
      _ => {
        inspect(path, content="missing")
        assert_true(false)
        return
      }
    }
    guard analyze_component_root_policy(bytes) is Ok(policy) else {
      inspect(path, content="root policy failed")
      assert_true(false)
      return
    }
    let config = component_dce_kpi_optimize_config(policy.root_name_candidates)
    guard analyze_component_core_optimize(bytes, config~) is Ok(report) else {
      inspect(path, content="component core optimize failed")
      assert_true(false)
      return
    }
    assert_eq(
      report.entries.length().reinterpret_as_uint(),
      report.core_module_count,
    )
    assert_true(report.total_core_after_bytes <= report.total_core_before_bytes)
  }
}

///|
test "component root policy integrates with gc-aware optimize config" {
  for path in bench_component_dce_corpus_paths() {
    let bytes = @fs.read_file_to_bytes(path) catch {
      _ => {
        inspect(path, content="missing")
        assert_true(false)
        return
      }
    }
    guard analyze_component_root_policy(bytes) is Ok(policy) else {
      inspect(path, content="root policy failed")
      assert_true(false)
      return
    }
    let config = component_gc_optimize_config(policy.root_name_candidates)
    guard analyze_component_core_optimize(bytes, config~) is Ok(report) else {
      inspect(path, content="component core optimize failed")
      assert_true(false)
      return
    }
    assert_eq(
      report.entries.length().reinterpret_as_uint(),
      report.core_module_count,
    )
    assert_true(report.total_core_after_bytes <= report.total_core_before_bytes)
  }
}

///|
test "component dce corpus applies dce and strictly shrinks core size" {
  for path in bench_component_dce_corpus_paths() {
    let bytes = @fs.read_file_to_bytes(path) catch {
      _ => {
        inspect(path, content="missing")
        assert_true(false)
        return
      }
    }
    guard analyze_component_root_policy(bytes) is Ok(policy) else {
      inspect(path, content="root policy failed")
      assert_true(false)
      return
    }
    let config = component_dce_kpi_optimize_config(policy.root_name_candidates)
    guard analyze_component_core_optimize(bytes, config~) is Ok(report) else {
      inspect(path, content="component core optimize failed")
      assert_true(false)
      return
    }
    assert_true(report.total_core_after_bytes < report.total_core_before_bytes)
    assert_true(
      report.entries.any(entry => entry.removed_sections.any(s => s.contains(
        "dce:functions:",
      ))),
    )
  }
}

///|
test "component optimize with exclude keeps socket pluggable after dce" {
  let socket_path = "bench/corpus/component-dce/mwac/wac_greeter.wasm"
  let plug_path = "bench/corpus/component-dce/mwac/wac_hello.wasm"
  let socket_bytes = @fs.read_file_to_bytes(socket_path) catch {
    _ => {
      inspect("skip", content="skip")
      return
    }
  }
  let plug_bytes = @fs.read_file_to_bytes(plug_path) catch {
    _ => {
      inspect("skip", content="skip")
      return
    }
  }
  guard analyze_component_root_policy(socket_bytes) is Ok(policy) else {
    assert_true(false)
    return
  }
  let config = component_dce_kpi_optimize_config(policy.root_name_candidates)
  guard optimize_component_for_size(socket_bytes, config~, exclude=["hello"])
    is Ok(optimized_socket) else {
    assert_true(false)
    return
  }
  assert_true(optimized_socket.after_size <= optimized_socket.before_size)
  guard @mwac_component.parse_component_info(socket_bytes) is Ok(socket_info) else {
    assert_true(false)
    return
  }
  guard @mwac_component.plug_components(optimized_socket.bytes, [plug_bytes])
    is Ok(composed) else {
    assert_true(false)
    return
  }
  guard @mwac_component.parse_component_info(composed) is Ok(composed_info) else {
    assert_true(false)
    return
  }
  assert_eq(composed_info.imports.length(), 0)
  assert_eq(composed_info.exports.length(), socket_info.exports.length())
  for e in socket_info.exports {
    assert_true(has_component_export(composed_info.exports, e.name, e.kind))
  }
}

///|
test "component optimize reports no-change reasons when all passes are disabled" {
  let component_path = "bench/corpus/component-dce/mwac/wac_greeter.wasm"
  let bytes = @fs.read_file_to_bytes(component_path) catch {
    _ => {
      inspect("skip", content="skip")
      return
    }
  }
  let config = make_optimize_config(
    strip_all_custom=false,
    strip_name_section=false,
    strip_producers_section=false,
    strip_debug_sections=false,
    strip_dwarf_sections=false,
    strip_target_features_section=false,
    enable_peephole=false,
    enable_vacuum=false,
    enable_merge_blocks=false,
    enable_remove_unused_brs=false,
    enable_dce=false,
    enable_dfe=false,
    enable_merge_similar_functions=false,
    enable_remove_unused_module_elements=false,
    closed_world=false,
    safe_mode=false,
  )
  guard optimize_component_for_size(bytes, config~) is Ok(optimized) else {
    assert_true(false)
    return
  }
  assert_eq(optimized.before_size, optimized.after_size)
  assert_true(
    optimized.no_change_reasons.any(r => r.contains(
      "no optimization pass is enabled in config",
    )),
  )
  guard analyze_component_core_optimize(bytes, config~) is Ok(report) else {
    assert_true(false)
    return
  }
  assert_true(report.entries.length() > 0)
  for entry in report.entries {
    assert_true(
      entry.no_change_reasons.contains(
        "no optimization pass is enabled in config",
      ),
    )
  }
}

///|
test "make_component_optimize_config merges roots without wac plan type" {
  let base = make_optimize_config(
    strip_all_custom=false,
    strip_name_section=false,
    strip_producers_section=false,
    pass_rounds=3U,
    enable_peephole=false,
    enable_vacuum=false,
    enable_merge_blocks=false,
    enable_remove_unused_brs=false,
    enable_dce=true,
    enable_dfe=false,
    enable_merge_similar_functions=false,
    enable_remove_unused_module_elements=true,
    closed_world=true,
    closed_world_root_exports=["run", "cabi_realloc"],
    safe_mode=false,
  )
  let effective = make_component_optimize_config(
    base~,
    root_name_candidates=["hello", "run"],
    exclude=["socket", "hello"],
  )
  let merged_roots = effective.closed_world_root_exports
  assert_eq(merged_roots.length(), 4)
  assert_true(merged_roots.contains("cabi_realloc"))
  assert_true(merged_roots.contains("hello"))
  assert_true(merged_roots.contains("run"))
  assert_true(merged_roots.contains("socket"))
  assert_eq(effective.pass_rounds, base.pass_rounds)
  assert_eq(effective.enable_dce, base.enable_dce)
  assert_eq(
    effective.enable_remove_unused_module_elements,
    base.enable_remove_unused_module_elements,
  )
}

///|
test "component optimize converge loops until no size improvement" {
  let component_bytes = sample_component_with_single_core_module(
    sample_module_with_inlining_const_callee_bytes(),
  )
  let single_round = make_optimize_config(
    strip_all_custom=false,
    strip_name_section=false,
    strip_producers_section=false,
    pass_rounds=1U,
    enable_peephole=false,
    enable_vacuum=false,
    enable_merge_blocks=false,
    enable_remove_unused_brs=false,
    enable_dce=true,
    enable_dfe=false,
    enable_merge_similar_functions=false,
    enable_remove_unused_module_elements=false,
    closed_world=false,
    safe_mode=false,
  )
  let converge_rounds = make_optimize_config(
    strip_all_custom=false,
    strip_name_section=false,
    strip_producers_section=false,
    pass_rounds=4U,
    enable_peephole=false,
    enable_vacuum=false,
    enable_merge_blocks=false,
    enable_remove_unused_brs=false,
    enable_dce=true,
    enable_dfe=false,
    enable_merge_similar_functions=false,
    enable_remove_unused_module_elements=false,
    closed_world=false,
    safe_mode=false,
  )
  guard optimize_component_for_size(component_bytes, config=single_round)
    is Ok(single_result) else {
    assert_true(false)
    return
  }
  guard optimize_component_for_size(component_bytes, config=converge_rounds)
    is Ok(converged_result) else {
    assert_true(false)
    return
  }
  assert_true(converged_result.after_size < single_result.after_size)
  assert_true(
    converged_result.removed_sections.any(s => s.contains(
      "core#0:dce:functions:1",
    )),
  )
  assert_true(
    converged_result.removed_sections.any(s => s.contains("component-converge:")),
  )
}

///|
test "component optimize converge stops on non-improving round" {
  let component_bytes = sample_component_with_single_core_module(
    sample_module_bytes(),
  )
  let config = make_optimize_config(
    strip_all_custom=false,
    strip_name_section=false,
    strip_producers_section=false,
    pass_rounds=8U,
    enable_peephole=false,
    enable_vacuum=false,
    enable_merge_blocks=false,
    enable_remove_unused_brs=false,
    enable_dce=false,
    enable_dfe=false,
    enable_merge_similar_functions=false,
    enable_remove_unused_module_elements=false,
    closed_world=false,
    safe_mode=false,
  )
  guard optimize_component_for_size(component_bytes, config~) is Ok(result) else {
    assert_true(false)
    return
  }
  assert_eq(result.before_size, result.after_size)
  assert_true(
    result.removed_sections.any(s => s.contains(
      "component-converge:no-improve:",
    )),
  )
}

///|
test "optimize_binary_for_size auto-detects component wasm" {
  let component_bytes = sample_component_with_single_core_module(
    sample_module_bytes(),
  )
  let config = make_optimize_config(
    strip_all_custom=false,
    strip_name_section=false,
    strip_producers_section=false,
    pass_rounds=2U,
    enable_peephole=false,
    enable_vacuum=false,
    enable_merge_blocks=false,
    enable_remove_unused_brs=false,
    enable_dce=false,
    enable_dfe=false,
    enable_merge_similar_functions=false,
    enable_remove_unused_module_elements=false,
    closed_world=false,
    safe_mode=false,
  )
  guard optimize_component_for_size(component_bytes, config~) is Ok(direct) else {
    assert_true(false)
    return
  }
  guard optimize_binary_for_size(component_bytes, config~) is Ok(dispatched) else {
    assert_true(false)
    return
  }
  assert_eq(dispatched.after_size, direct.after_size)
  assert_eq(dispatched.before_size, direct.before_size)
  assert_eq(dispatched.removed_sections, direct.removed_sections)
  assert_true(
    dispatched.no_change_reasons.any(r => r.contains("no optimization pass")),
  )
}
