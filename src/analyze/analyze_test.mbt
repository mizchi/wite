///|
fn wasm_header() -> Array[Byte] {
  [b'\x00', b'\x61', b'\x73', b'\x6D', b'\x01', b'\x00', b'\x00', b'\x00']
}

///|
fn encode_leb128(value : UInt) -> Array[Byte] {
  let out : Array[Byte] = []
  let mut v = value
  while true {
    let mut b = (v % 128U).to_byte()
    v = v / 128U
    if v > 0U {
      b = (b.to_int() | 0x80).to_byte()
      out.push(b)
    } else {
      out.push(b)
      break
    }
  }
  out
}

///|
fn append_section(out : Array[Byte], id : UInt, payload : Array[Byte]) -> Unit {
  out
  ..push(id.to_byte())
  .append(encode_leb128(payload.length().reinterpret_as_uint())[:])
  out.append(payload[:])
}

///|
/// Build a minimal valid core wasm module with:
/// - 1 type: () -> ()
/// - 1 function
/// - 1 export "run"
/// - 1 code body (nop; end)
fn minimal_core_wasm() -> Bytes {
  let out = wasm_header()
  // Type section (id=1): 1 type, func () -> ()
  let type_payload : Array[Byte] = [
    b'\x01', // count=1
     b'\x60', // func
     b'\x00', // 0 params
     b'\x00', // 0 results
  ]
  append_section(out, 1U, type_payload)
  // Function section (id=3): 1 func, type index 0
  let func_payload : Array[Byte] = [
    b'\x01', // count=1
     b'\x00', // type index 0
  ]
  append_section(out, 3U, func_payload)
  // Export section (id=7): export "run" as func 0
  let export_payload : Array[Byte] = [
    b'\x01', // count=1
     b'\x03', // name length=3
     b'\x72', b'\x75', b'\x6E', // "run"
     b'\x00', // kind=func
     b'\x00', // index=0
  ]
  append_section(out, 7U, export_payload)
  // Code section (id=10): 1 body
  let body : Array[Byte] = [
    b'\x02', // body size=2
     b'\x00', // 0 locals
     b'\x0B', // end
  ]
  let code_payload : Array[Byte] = [b'\x01'] // count=1
  code_payload.append(body[:])
  append_section(out, 10U, code_payload)
  Bytes::from_array(out)
}

///|
/// Build core wasm with 2 functions where func1 calls func0
fn core_wasm_with_call() -> Bytes {
  let out = wasm_header()
  // Type section: () -> ()
  append_section(out, 1U, [b'\x01', b'\x60', b'\x00', b'\x00'])
  // Function section: 2 funcs, both type 0
  append_section(out, 3U, [b'\x02', b'\x00', b'\x00'])
  // Export section: export "main" as func 1
  let export_payload : Array[Byte] = [
    b'\x01', b'\x04', b'\x6D', b'\x61', b'\x69', b'\x6E', b'\x00', b'\x01',
  ]
  append_section(out, 7U, export_payload)
  // Code section: 2 bodies
  // body0: nop; end (internal)
  // body1: call 0; end (exported)
  let code_payload : Array[Byte] = [
    b'\x02', // count=2
     b'\x02', b'\x00', b'\x0B', // body0: size=2, 0 locals, end
     b'\x04', b'\x00', b'\x10', b'\x00', b'\x0B', // body1: size=4, 0 locals, call 0, end
  ]
  append_section(out, 10U, code_payload)
  Bytes::from_array(out)
}

///|
test "analyze_section_sizes returns sections for valid wasm" {
  let bytes = minimal_core_wasm()
  let sections = @analyze.analyze_section_sizes(bytes).unwrap()
  assert_true(sections.length() > 0)
  let keys = sections.map(fn(s) { s.key })
  assert_true(keys.contains("type"))
  assert_true(keys.contains("function"))
  assert_true(keys.contains("export"))
  assert_true(keys.contains("code"))
}

///|
test "analyze_section_sizes rejects invalid magic" {
  let result = @analyze.analyze_section_sizes(b"\x00\x00\x00\x00")
  assert_true(result is Err(_))
}

///|
test "profile_module reports correct counts" {
  let bytes = minimal_core_wasm()
  let profile = @analyze.profile_module(bytes).unwrap()
  assert_eq(profile.function_count, 1U)
  assert_eq(profile.export_count, 1U)
  assert_eq(profile.import_count, 0U)
  assert_true(profile.total_bytes > 0U)
  assert_true(profile.code_body_count > 0U)
}

///|
test "profile_module with call wasm" {
  let bytes = core_wasm_with_call()
  let profile = @analyze.profile_module(bytes).unwrap()
  assert_eq(profile.function_count, 2U)
  assert_eq(profile.export_count, 1U)
}

///|
test "analyze_function_sizes returns sorted by body size desc" {
  let bytes = core_wasm_with_call()
  let functions = @analyze.analyze_function_sizes(bytes).unwrap()
  assert_eq(functions.length(), 2)
  // Larger body first
  assert_true(functions[0].body_bytes >= functions[1].body_bytes)
}

///|
test "analyze_call_graph reports nodes and roots" {
  let bytes = core_wasm_with_call()
  let report = @analyze.analyze_call_graph(bytes).unwrap()
  assert_eq(report.local_function_count, 2U)
  assert_true(report.roots.length() > 0)
  assert_eq(report.nodes.length(), 2)
}

///|
test "analyze_call_graph_summary counts reachable vs dead" {
  let bytes = core_wasm_with_call()
  let summary = @analyze.analyze_call_graph_summary(bytes).unwrap()
  assert_eq(summary.local_function_count, 2U)
  // func0 is called by func1 (exported), so both are reachable
  assert_eq(summary.reachable_function_count, 2U)
  assert_eq(summary.dead_function_count, 0U)
}

///|
test "analyze_dce_report for module with no dead code" {
  let bytes = core_wasm_with_call()
  let report = @analyze.analyze_dce_report(bytes).unwrap()
  assert_eq(report.removable_function_count, 0U)
  assert_eq(report.removable_body_bytes, 0U)
}

///|
test "analyze_wasm_breakdown returns full report" {
  let bytes = core_wasm_with_call()
  let report = @analyze.analyze_wasm_breakdown(bytes).unwrap()
  assert_true(report.total_bytes > 0U)
  assert_eq(report.local_function_count, 2U)
  assert_eq(report.imported_function_count, 0U)
  assert_true(report.sections.length() > 0)
  assert_true(report.top_functions.length() > 0)
}

///|
test "analyze_wasm_breakdown top_limit limits functions" {
  let bytes = core_wasm_with_call()
  let report = @analyze.analyze_wasm_breakdown(bytes, top_limit=1U).unwrap()
  assert_eq(report.top_functions.length(), 1)
}

///|
test "optimize_for_size on minimal wasm" {
  let bytes = minimal_core_wasm()
  let result = @analyze.optimize_for_size(bytes).unwrap()
  assert_eq(result.before_size, bytes.length().reinterpret_as_uint())
  assert_true(result.after_size > 0U)
  assert_true(result.after_size <= result.before_size)
  assert_true(result.bytes.length() > 0)
}

///|
test "analyze_code_block_sizes returns blocks" {
  let bytes = core_wasm_with_call()
  let report = @analyze.analyze_code_block_sizes(bytes).unwrap()
  assert_true(report.function_count > 0U)
  assert_true(report.block_count > 0U)
}

///|
test "analyze_keep_reasons shows export roots" {
  let bytes = minimal_core_wasm()
  let report = @analyze.analyze_keep_reasons(bytes).unwrap()
  assert_true(report.entries.length() > 0)
  // The exported function should have a keep reason
  let has_export_reason = report.entries
    .iter()
    .any(fn(e) { e.reasons.iter().any(fn(r) { r.contains("export") }) })
  assert_true(has_export_reason)
}

///|
test "analyze_retain_paths returns paths" {
  let bytes = core_wasm_with_call()
  let report = @analyze.analyze_retain_paths(bytes).unwrap()
  assert_true(report.roots.length() > 0)
  assert_true(report.entries.length() > 0)
}

///|
test "analyze_function_size_gap compares two binaries" {
  let a = minimal_core_wasm()
  let b = core_wasm_with_call()
  let report = @analyze.analyze_function_size_gap(a, b).unwrap()
  assert_true(report.entries.length() > 0)
}

///|
test "analyze_optimize_metadata reports stages" {
  let bytes = core_wasm_with_call()
  let report = @analyze.analyze_optimize_metadata(bytes).unwrap()
  assert_eq(report.before_size, bytes.length().reinterpret_as_uint())
  assert_true(report.stages.length() > 0)
}

///|
test "analyze_host_generated_code on simple module" {
  let bytes = core_wasm_with_call()
  let report = @analyze.analyze_host_generated_code(bytes).unwrap()
  assert_eq(report.imported_function_count, 0U)
  assert_eq(report.local_function_count, 2U)
}

///|
test "bytes_equal same bytes" {
  assert_true(@analyze.bytes_equal(b"\x00\x01", b"\x00\x01"))
}

///|
test "bytes_equal different bytes" {
  assert_false(@analyze.bytes_equal(b"\x00\x01", b"\x00\x02"))
}

///|
test "bytes_equal different lengths" {
  assert_false(@analyze.bytes_equal(b"\x00", b"\x00\x01"))
}

///|
test "unique_sorted deduplicates and sorts" {
  let result = @analyze.unique_sorted(["c", "a", "b", "a", "c"])
  assert_eq(result, ["a", "b", "c"])
}

///|
test "unique_sorted empty" {
  let result = @analyze.unique_sorted([])
  assert_eq(result, [])
}

///|
test "make_bool_array creates array with default value" {
  let arr = @analyze.make_bool_array(3, false)
  assert_eq(arr.length(), 3)
  assert_false(arr[0])
  assert_false(arr[1])
  assert_false(arr[2])
}

///|
test "mark_visited_function_index returns true for new, false for revisit" {
  let visited = @analyze.make_bool_array(5, false)
  let marked = @analyze.mark_visited_function_index(visited, 2U)
  assert_true(marked) // first time: successfully marked
  let marked2 = @analyze.mark_visited_function_index(visited, 2U)
  assert_false(marked2) // already visited: returns false
}

///|
test "is_visited_function_index checks bounds" {
  let visited = @analyze.make_bool_array(3, false)
  assert_false(@analyze.is_visited_function_index(visited, 0U))
  @analyze.mark_visited_function_index(visited, 0U) |> ignore
  assert_true(@analyze.is_visited_function_index(visited, 0U))
  // Out of bounds returns false
  assert_false(@analyze.is_visited_function_index(visited, 10U))
}

///|
test "map_push_string_array creates and appends" {
  let map : Map[UInt, Array[String]] = {}
  @analyze.map_push_string_array(map, 0U, "a")
  @analyze.map_push_string_array(map, 0U, "b")
  @analyze.map_push_string_array(map, 1U, "c")
  assert_eq(map.get(0U).unwrap(), ["a", "b"])
  assert_eq(map.get(1U).unwrap(), ["c"])
}

///|
test "merge_export_function_names merges into target" {
  let target : Map[UInt, Array[String]] = {}
  target[0U] = ["run"]
  let source : Map[UInt, Array[String]] = {}
  source[0U] = ["execute"]
  source[1U] = ["init"]
  @analyze.merge_export_function_names(target, source)
  assert_eq(target.get(0U).unwrap(), ["run", "execute"])
  assert_eq(target.get(1U).unwrap(), ["init"])
}

// ---- complex wasm fixtures ----

///|
fn append_name_bytes(out : Array[Byte], name : String) -> Unit {
  let name_bytes = name.to_array().map(fn(c) { c.to_int().to_byte() })
  out.append(encode_leb128(name_bytes.length().reinterpret_as_uint())[:])
  out.append(name_bytes[:])
}

///|
/// Build wasm with: 1 import, 2 local funcs, name section, custom section,
/// block/if structure, dead code
fn complex_core_wasm() -> Bytes {
  let out = wasm_header()
  // Type section (id=1): 2 types
  // type 0: () -> ()
  // type 1: (i32) -> (i32)
  let type_payload : Array[Byte] = [
    b'\x02', // count=2
     b'\x60', b'\x00', b'\x00', // func () -> ()
     b'\x60', b'\x01', b'\x7F', b'\x01', b'\x7F', // func (i32) -> (i32)
  ]
  append_section(out, 1U, type_payload)
  // Import section (id=2): 1 import (func type 0)
  let import_payload : Array[Byte] = [b'\x01'] // count=1
  append_name_bytes(import_payload, "env")
  append_name_bytes(import_payload, "log")
  import_payload.push(b'\x00') // kind=func
  import_payload.push(b'\x00') // type index 0
  append_section(out, 2U, import_payload)
  // Function section (id=3): 2 local funcs
  append_section(out, 3U, [b'\x02', b'\x01', b'\x00'])
  // Export section (id=7): export "compute" as func 1, "unused" as func 2
  let export_payload : Array[Byte] = [b'\x02'] // count=2
  append_name_bytes(export_payload, "compute")
  export_payload..push(b'\x00').push(b'\x01') // kind=func, index=1
  append_name_bytes(export_payload, "unused")
  export_payload..push(b'\x00').push(b'\x02') // kind=func, index=2
  append_section(out, 7U, export_payload)
  // Code section (id=10): 2 bodies
  // body0 (func idx 1, type 1): (i32)->i32
  //   local.get 0; if (result i32); i32.const 1; else; i32.const 0; end; end
  // body content: 12 bytes (0 locals + 11 instruction bytes)
  let body0 : Array[Byte] = [
    b'\x0C', // body size=12
     b'\x00', // 0 locals
     b'\x20', b'\x00', // local.get 0
     b'\x04', b'\x7F', // if (result i32)
     b'\x41', b'\x01', // i32.const 1
     b'\x05', // else
     b'\x41', b'\x00', // i32.const 0
     b'\x0B', // end (if)
     b'\x0B', // end (func)
  ]
  // body1 (func idx 2, type 0): () -> ()
  //   nop; end (dead code - exported but never called from compute)
  let body1 : Array[Byte] = [
    b'\x02', // body size=2
     b'\x00', // 0 locals
     b'\x0B',
  ] // end
  let code_payload : Array[Byte] = [b'\x02'] // count=2
  code_payload.append(body0[:])
  code_payload.append(body1[:])
  append_section(out, 10U, code_payload)
  // Name section (custom section, id=0, name="name")
  // subsection 1 (function names)
  let name_sub : Array[Byte] = [b'\x03'] // count=3
  // func 0: "log"
  name_sub.append(encode_leb128(0U)[:])
  append_name_bytes(name_sub, "log")
  // func 1: "compute"
  name_sub.append(encode_leb128(1U)[:])
  append_name_bytes(name_sub, "compute")
  // func 2: "unused_fn"
  name_sub.append(encode_leb128(2U)[:])
  append_name_bytes(name_sub, "unused_fn")
  let name_payload : Array[Byte] = []
  append_name_bytes(name_payload, "name")
  name_payload.push(b'\x01') // subsection id=1 (function names)
  name_payload.append(encode_leb128(name_sub.length().reinterpret_as_uint())[:])
  name_payload.append(name_sub[:])
  append_section(out, 0U, name_payload)
  // Custom section "producers"
  let producers_payload : Array[Byte] = []
  append_name_bytes(producers_payload, "producers")
  producers_payload.push(b'\x00') // empty producers content
  append_section(out, 0U, producers_payload)
  Bytes::from_array(out)
}

///|
/// Wasm with block/loop structure for opcode coverage
fn wasm_with_block_loop() -> Bytes {
  let out = wasm_header()
  // Type: () -> ()
  append_section(out, 1U, [b'\x01', b'\x60', b'\x00', b'\x00'])
  // Func: 1 func
  append_section(out, 3U, [b'\x01', b'\x00'])
  // Export: "entry"
  let export_p : Array[Byte] = [b'\x01']
  append_name_bytes(export_p, "entry")
  export_p..push(b'\x00').push(b'\x00')
  append_section(out, 7U, export_p)
  // Code: block { loop { br 1 } } end
  // content: 0 locals + 9 instr bytes = 10 bytes
  let body : Array[Byte] = [
    b'\x0A', // body size=10
     b'\x00', // 0 locals
     b'\x02', b'\x40', // block void
     b'\x03', b'\x40', // loop void
     b'\x0C', b'\x01', // br 1
     b'\x0B', // end (loop)
     b'\x0B', // end (block)
     b'\x0B', // end (func)
  ]
  let code_p : Array[Byte] = [b'\x01']
  code_p.append(body[:])
  append_section(out, 10U, code_p)
  Bytes::from_array(out)
}

///|
/// Wasm with 3 functions, one dead (not exported, not called)
fn wasm_with_dead_code() -> Bytes {
  let out = wasm_header()
  append_section(out, 1U, [b'\x01', b'\x60', b'\x00', b'\x00'])
  // 3 funcs
  append_section(out, 3U, [b'\x03', b'\x00', b'\x00', b'\x00'])
  // Export only func 0
  let export_p : Array[Byte] = [b'\x01']
  append_name_bytes(export_p, "main")
  export_p..push(b'\x00').push(b'\x00')
  append_section(out, 7U, export_p)
  // Code: func0 calls func1, func1 is nop, func2 is dead
  let code_p : Array[Byte] = [
    b'\x03', // count=3
     b'\x04', b'\x00', b'\x10', b'\x01', b'\x0B', // body0: call 1; end
     b'\x02', b'\x00', b'\x0B', // body1: end
     b'\x02', b'\x00', b'\x0B', // body2 (dead): end
  ]
  append_section(out, 10U, code_p)
  Bytes::from_array(out)
}

// ---- tests with complex wasm ----

///|
test "analyze_wasm_breakdown with import and name section" {
  let bytes = complex_core_wasm()
  let report = @analyze.analyze_wasm_breakdown(bytes).unwrap()
  assert_eq(report.imported_function_count, 1U)
  assert_eq(report.local_function_count, 2U)
  assert_true(report.instruction_count > 0U)
  assert_true(report.opcodes.length() > 0)
  // Custom sections should include "name" and "producers"
  assert_true(report.custom_sections.length() > 0)
  let custom_names = report.custom_sections.map(fn(s) { s.name })
  assert_true(custom_names.contains("name"))
  assert_true(custom_names.contains("producers"))
}

///|
test "analyze_wasm_breakdown with top_limit=1" {
  let bytes = complex_core_wasm()
  let report = @analyze.analyze_wasm_breakdown(bytes, top_limit=1U).unwrap()
  assert_eq(report.top_functions.length(), 1)
  // top block limited to 1
  assert_true(report.top_blocks.length() <= 1)
}

///|
test "analyze_function_sizes with imports" {
  let bytes = complex_core_wasm()
  let functions = @analyze.analyze_function_sizes(bytes).unwrap()
  // Only local functions, not imports
  assert_eq(functions.length(), 2)
  // Should have names from name section
  let named = functions.filter(fn(f) { f.name is Some(_) })
  assert_true(named.length() > 0)
}

///|
test "analyze_call_graph with import" {
  let bytes = complex_core_wasm()
  let report = @analyze.analyze_call_graph(bytes).unwrap()
  assert_eq(report.imported_function_count, 1U)
  assert_eq(report.local_function_count, 2U)
  // exported functions should be roots
  assert_true(report.roots.length() > 0)
}

///|
test "analyze_call_graph_summary with dead code" {
  let bytes = wasm_with_dead_code()
  let summary = @analyze.analyze_call_graph_summary(bytes).unwrap()
  assert_eq(summary.local_function_count, 3U)
  // func2 is dead
  assert_eq(summary.dead_function_count, 1U)
  assert_eq(summary.reachable_function_count, 2U)
  assert_true(summary.dead_body_bytes > 0U)
}

///|
test "analyze_dce_report finds dead functions" {
  let bytes = wasm_with_dead_code()
  let report = @analyze.analyze_dce_report(bytes).unwrap()
  assert_eq(report.removable_function_count, 1U)
  assert_true(report.removable_body_bytes > 0U)
  assert_eq(report.removable_functions.length(), 1)
}

///|
test "analyze_code_block_sizes with block and loop" {
  let bytes = wasm_with_block_loop()
  let report = @analyze.analyze_code_block_sizes(bytes).unwrap()
  assert_true(report.block_count > 1U) // function block + block + loop
  // Check we have different kinds
  let kinds = report.blocks.map(fn(b) { b.kind })
  assert_true(kinds.contains("function"))
  assert_true(kinds.contains("block"))
  assert_true(kinds.contains("loop"))
}

///|
test "analyze_code_block_sizes with if/else" {
  let bytes = complex_core_wasm()
  let report = @analyze.analyze_code_block_sizes(bytes).unwrap()
  let kinds = report.blocks.map(fn(b) { b.kind })
  assert_true(kinds.contains("if"))
}

///|
test "analyze_wasm_breakdown with block/loop opcodes" {
  let bytes = wasm_with_block_loop()
  let report = @analyze.analyze_wasm_breakdown(bytes).unwrap()
  let opcodes_keys = report.opcodes.map(fn(o) { o.mnemonic })
  assert_true(opcodes_keys.contains("block"))
  assert_true(opcodes_keys.contains("loop"))
  assert_true(opcodes_keys.contains("br"))
}

///|
test "analyze_keep_reasons with closed_world" {
  let bytes = wasm_with_dead_code()
  let config = @analyze.make_optimize_config(closed_world=true, closed_world_root_exports=[
    "main",
  ])
  let report = @analyze.analyze_keep_reasons(bytes, config~).unwrap()
  assert_true(report.entries.length() > 0)
}

///|
test "analyze_retain_paths with dead code" {
  let bytes = wasm_with_dead_code()
  let report = @analyze.analyze_retain_paths(bytes).unwrap()
  assert_true(report.roots.length() > 0)
  assert_true(report.entries.length() > 0)
  // Dead function should have empty path
  let dead_entries = report.entries.filter(fn(e) { e.path.length() == 0 })
  // At least some entries should have paths
  let rooted_entries = report.entries.filter(fn(e) {
    e.root_reasons.length() > 0
  })
  assert_true(rooted_entries.length() > 0 || dead_entries.length() > 0)
}

///|
test "analyze_retain_paths with closed_world config" {
  let bytes = wasm_with_dead_code()
  let config = @analyze.make_optimize_config(closed_world=true, closed_world_root_exports=[
    "main",
  ])
  let report = @analyze.analyze_retain_paths(bytes, config~).unwrap()
  assert_true(report.entries.length() > 0)
}

///|
test "optimize_for_size reduces dead code" {
  let bytes = wasm_with_dead_code()
  let config = @analyze.make_optimize_config(
    enable_dce=true,
    enable_peephole=true,
    enable_vacuum=true,
  )
  let result = @analyze.optimize_for_size(bytes, config~).unwrap()
  // DCE should remove the dead function
  assert_true(result.after_size <= result.before_size)
}

///|
test "analyze_optimize_metadata with o1 config" {
  let bytes = wasm_with_dead_code()
  let config = @analyze.optimize_config_from_opt_level("-O1").unwrap()
  let report = @analyze.analyze_optimize_metadata(
    bytes,
    config~,
    function_diff_limit=5U,
  ).unwrap()
  assert_true(report.stages.length() > 0)
  assert_true(report.total_gain_bytes > 0U)
}

///|
test "analyze_host_generated_code with import" {
  let bytes = complex_core_wasm()
  let report = @analyze.analyze_host_generated_code(bytes).unwrap()
  assert_eq(report.imported_function_count, 1U)
  assert_eq(report.local_function_count, 2U)
}

///|
test "analyze_function_size_gap with different dead code" {
  let a = wasm_with_dead_code()
  let b = complex_core_wasm()
  let report = @analyze.analyze_function_size_gap(a, b, top_limit=10U).unwrap()
  assert_true(report.entries.length() > 0)
}

///|
test "analyze_wasm_breakdown dead_body_bytes counted" {
  let bytes = wasm_with_dead_code()
  let report = @analyze.analyze_wasm_breakdown(bytes).unwrap()
  assert_true(report.dead_body_bytes > 0U)
  assert_true(report.reachable_body_bytes > 0U)
}

///|
test "profile_module with import and custom sections" {
  let bytes = complex_core_wasm()
  let profile = @analyze.profile_module(bytes).unwrap()
  assert_eq(profile.import_count, 1U)
  assert_eq(profile.function_count, 2U)
  assert_eq(profile.export_count, 2U)
  assert_true(profile.sections.length() > 0)
  assert_true(profile.sections.length() > 0)
}
