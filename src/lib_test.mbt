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
