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
fn bench_core_corpus_paths() -> Array[String] {
  [
    "bench/corpus/core/binaryen/br_to_exit.wasm", "bench/corpus/core/binaryen/elided-br.wasm",
    "bench/corpus/core/binaryen/complexBinaryNames.wasm", "bench/corpus/core/binaryen/empty.wasm",
    "bench/corpus/core/binaryen/gc_target_feature.wasm", "bench/corpus/core/binaryen/zlib.wasm",
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
  assert_true(not(o1.enable_dce))
  assert_true(o1.enable_dfe)
  assert_true(o1.enable_merge_similar_functions)
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
    bytes_contains_seq(optimized.bytes, [
      0x41, 0x01, 0x41, 0x02, 0x1a, 0x10, 0x01, 0x0b,
    ]),
  )
  assert_true(bytes_contains_seq(optimized.bytes, [0x20, 0x00, 0x1a, 0x0b]))
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
  assert_true(bytes_contains_seq(optimized.bytes, [0x41, 0x01, 0x21, 0x00, 0x0b]))
  assert_true(not(bytes_contains_seq(optimized.bytes, [0x22, 0x00, 0x21, 0x00])))
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
  assert_true(not(bytes_contains_seq(optimized.bytes, [0x20, 0x00, 0x22, 0x00])))
  assert_true(not(bytes_contains_seq(optimized.bytes, [0x20, 0x00, 0x21, 0x00])))
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
