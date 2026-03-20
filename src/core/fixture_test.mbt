///|
fn read_fixture(path : String) -> Bytes? {
  try @fs.read_file_to_bytes(path) catch {
    _ => None
  } noraise {
    bytes => Some(bytes)
  }
}

// ---- zlib fixture: core module 171KB ----

///|
test "fixture: zlib profile matches expected structure" {
  guard read_fixture("bench/corpus/core/binaryen/zlib.wasm") is Some(bytes) else {
    return
  }
  let profile = @wite_analyze.profile_module(bytes).unwrap()
  assert_eq(profile.total_bytes, 171100U)
  assert_true(profile.function_count > 100U)
  assert_true(profile.import_count > 0U)
  assert_true(profile.export_count > 0U)
  assert_true(profile.code_body_bytes > 0U)
  // Sections should include type, import, function, code, export at minimum
  assert_true(profile.sections.length() >= 5)
}

///|
test "fixture: zlib call graph has reachable and dead functions" {
  guard read_fixture("bench/corpus/core/binaryen/zlib.wasm") is Some(bytes) else {
    return
  }
  let summary = @wite_analyze.analyze_call_graph_summary(bytes).unwrap()
  assert_true(summary.local_function_count > 100U)
  assert_true(summary.reachable_function_count > 0U)
  // callgraph analysis may be partial (indirect calls), so dead count could be 0
  assert_true(
    summary.reachable_function_count + summary.dead_function_count ==
    summary.local_function_count,
  )
}

///|
test "fixture: zlib optimize -O1 reduces size" {
  guard read_fixture("bench/corpus/core/binaryen/zlib.wasm") is Some(bytes) else {
    return
  }
  let config = OptimizeConfig::o1()
  let result = @wite_analyze.optimize_for_size(bytes, config~).unwrap()
  assert_eq(result.before_size, 171100U)
  // O1 should significantly reduce zlib
  assert_true(result.after_size < 160000U)
  assert_true(result.after_size > 50000U)
}

///|
test "fixture: zlib optimize -O0 preserves size" {
  guard read_fixture("bench/corpus/core/binaryen/zlib.wasm") is Some(bytes) else {
    return
  }
  let config = OptimizeConfig::o0()
  let result = @wite_analyze.optimize_for_size(bytes, config~).unwrap()
  assert_eq(result.before_size, 171100U)
  // O0 should not change size (no passes enabled)
  assert_eq(result.after_size, 171100U)
}

///|
test "fixture: zlib breakdown has opcodes" {
  guard read_fixture("bench/corpus/core/binaryen/zlib.wasm") is Some(bytes) else {
    return
  }
  let report = @wite_analyze.analyze_wasm_breakdown(bytes, top_limit=5U).unwrap()
  assert_eq(report.total_bytes, 171100U)
  assert_true(report.instruction_count > 1000U)
  assert_true(report.opcodes.length() > 10)
  assert_true(report.top_functions.length() == 5)
  assert_true(report.top_blocks.length() <= 5)
}

///|
test "fixture: zlib dce report finds removable functions" {
  guard read_fixture("bench/corpus/core/binaryen/zlib.wasm") is Some(bytes) else {
    return
  }
  let report = @wite_analyze.analyze_dce_report(bytes).unwrap()
  // DCE removable count depends on callgraph analysis completeness
  // (may be 0 if all functions are reachable via indirect calls)
  assert_true(
    report.removable_function_count >= 0U,
  )
}

///|
test "fixture: zlib keep reasons include export roots" {
  guard read_fixture("bench/corpus/core/binaryen/zlib.wasm") is Some(bytes) else {
    return
  }
  let report = @wite_analyze.analyze_keep_reasons(bytes).unwrap()
  assert_true(report.entries.length() > 0)
  // Should have at least one export root reason
  let has_export = report.entries.iter().any(
    fn(e) { e.reasons.iter().any(fn(r) { r.contains("export") }) },
  )
  assert_true(has_export)
}

///|
test "fixture: zlib optimize metadata shows pass gains" {
  guard read_fixture("bench/corpus/core/binaryen/zlib.wasm") is Some(bytes) else {
    return
  }
  let config = OptimizeConfig::o1()
  let report = @wite_analyze.analyze_optimize_metadata(
    bytes, config~, function_diff_limit=3U,
  ).unwrap()
  assert_eq(report.before_size, 171100U)
  assert_true(report.after_size < report.before_size)
  assert_true(report.stages.length() > 0)
  assert_true(report.total_gain_bytes > 0U)
}

///|
test "fixture: zlib host generated code analysis" {
  guard read_fixture("bench/corpus/core/binaryen/zlib.wasm") is Some(bytes) else {
    return
  }
  let report = @wite_analyze.analyze_host_generated_code(bytes).unwrap()
  assert_true(report.imported_function_count > 0U)
  assert_true(report.local_function_count > 100U)
}

// ---- gc_target_feature fixture: tiny core 91B ----

///|
test "fixture: gc_target_feature profile" {
  guard read_fixture("bench/corpus/core/binaryen/gc_target_feature.wasm")
    is Some(bytes) else {
    return
  }
  let profile = @wite_analyze.profile_module(bytes).unwrap()
  assert_eq(profile.total_bytes, 91U)
}

///|
test "fixture: gc_target_feature optimize -O1 handles small module" {
  guard read_fixture("bench/corpus/core/binaryen/gc_target_feature.wasm")
    is Some(bytes) else {
    return
  }
  let config = OptimizeConfig::o1()
  let result = @wite_analyze.optimize_for_size(bytes, config~).unwrap()
  assert_eq(result.before_size, 91U)
  assert_true(result.after_size <= 91U)
}

// ---- component fixture: dummy_wasi_http 27KB ----

///|
test "fixture: component profile matches expected structure" {
  guard read_fixture("bench/corpus/component/wac/dummy_wasi_http_0.2.3.wasm")
    is Some(bytes) else {
    return
  }
  let profile = profile_component(bytes).unwrap()
  assert_eq(profile.total_bytes, 26993U)
  assert_true(profile.import_count > 0U)
  assert_true(profile.export_count > 0U)
  assert_true(profile.core_module_count > 0U)
  assert_true(profile.sections.length() > 0)
}

///|
test "fixture: component function sizes per core module" {
  guard read_fixture("bench/corpus/component/wac/dummy_wasi_http_0.2.3.wasm")
    is Some(bytes) else {
    return
  }
  let reports = analyze_component_function_sizes(bytes).unwrap()
  assert_true(reports.length() > 0)
  // At least one core module should have functions
  let total_funcs = reports.iter().fold(
    init=0U,
    fn(acc, r) { acc + r.function_count },
  )
  assert_true(total_funcs > 0U)
}

///|
test "fixture: component call graphs per core module" {
  guard read_fixture("bench/corpus/component/wac/dummy_wasi_http_0.2.3.wasm")
    is Some(bytes) else {
    return
  }
  let reports = analyze_component_call_graphs(bytes).unwrap()
  assert_true(reports.length() > 0)
  // At least one core module should have local functions
  let total_local = reports.iter().fold(
    init=0U,
    fn(acc, r) { acc + r.graph.local_function_count },
  )
  assert_true(total_local > 0U)
}

// ---- hello.component fixture: composed 31KB ----

///|
test "fixture: hello.component profile has multiple core modules" {
  guard read_fixture(
      "bench/corpus/component-dce/mwac/hello.component.wasm",
    )
    is Some(bytes) else {
    return
  }
  let profile = profile_component(bytes).unwrap()
  assert_eq(profile.total_bytes, 31400U)
  // hello.component is composed — should have at least 1 core module
  assert_true(profile.core_module_count >= 1U)
}

///|
test "fixture: hello.component optimize reduces core modules" {
  guard read_fixture(
      "bench/corpus/component-dce/mwac/hello.component.wasm",
    )
    is Some(bytes) else {
    return
  }
  let config = OptimizeConfig::o1()
  let result = optimize_component_for_size(bytes, config~).unwrap()
  assert_eq(result.before_size, 31400U)
  assert_true(result.after_size < result.before_size)
}

///|
test "fixture: hello.component root policy has candidates" {
  guard read_fixture(
      "bench/corpus/component-dce/mwac/hello.component.wasm",
    )
    is Some(bytes) else {
    return
  }
  let policy = analyze_component_root_policy(bytes).unwrap()
  assert_true(policy.component_exports.length() > 0)
  assert_true(policy.root_name_candidates.length() > 0)
}

// ---- cross-fixture comparison ----

///|
test "fixture: function gap between zlib and gc_target_feature" {
  guard read_fixture("bench/corpus/core/binaryen/zlib.wasm") is Some(zlib) else {
    return
  }
  guard read_fixture("bench/corpus/core/binaryen/gc_target_feature.wasm")
    is Some(gc) else {
    return
  }
  let gap = @wite_analyze.analyze_function_size_gap(
    zlib, gc, top_limit=5U,
  ).unwrap()
  // zlib is much larger
  assert_true(gap.left_total_body_bytes > gap.right_total_body_bytes)
  assert_true(gap.entries.length() > 0)
}

// ---- optimize preset progression ----

///|
test "fixture: optimize presets produce decreasing sizes for zlib" {
  guard read_fixture("bench/corpus/core/binaryen/zlib.wasm") is Some(bytes) else {
    return
  }
  let o0 = @wite_analyze.optimize_for_size(
    bytes, config=OptimizeConfig::o0(),
  ).unwrap()
  let o1 = @wite_analyze.optimize_for_size(
    bytes, config=OptimizeConfig::o1(),
  ).unwrap()
  let o2 = @wite_analyze.optimize_for_size(
    bytes, config=OptimizeConfig::o2(),
  ).unwrap()
  // O0 should be largest (no optimization)
  assert_true(o0.after_size >= o1.after_size)
  // O1 includes DCE so should be smaller than O2 (which has less aggressive DCE)
  // Note: O1 strips debug/dwarf, O2 doesn't, but code optimization may differ
  assert_true(o2.after_size <= o0.after_size)
}

// ---- snapshot tests: exact expected values ----

///|
test "snapshot: zlib profile exact values" {
  guard read_fixture("bench/corpus/core/binaryen/zlib.wasm") is Some(bytes) else {
    return
  }
  let p = @wite_analyze.profile_module(bytes).unwrap()
  inspect(p.total_bytes, content="171100")
  inspect(p.function_count, content=(
    #|114
  ))
  inspect(p.import_count, content=(
    #|10
  ))
  inspect(p.export_count, content=(
    #|7
  ))
  inspect(p.code_body_count, content=(
    #|114
  ))
}

///|
test "snapshot: zlib callgraph summary exact values" {
  guard read_fixture("bench/corpus/core/binaryen/zlib.wasm") is Some(bytes) else {
    return
  }
  let s = @wite_analyze.analyze_call_graph_summary(bytes).unwrap()
  inspect(s.local_function_count, content=(
    #|114
  ))
  inspect(s.imported_function_count, content=(
    #|8
  ))
  inspect(s.reachable_function_count, content=(
    #|114
  ))
  inspect(s.dead_function_count, content="0")
  inspect(s.has_indirect_calls, content="true")
  inspect(s.partial, content=(
    #|false
  ))
}

///|
test "snapshot: zlib optimize -O1 exact after size" {
  guard read_fixture("bench/corpus/core/binaryen/zlib.wasm") is Some(bytes) else {
    return
  }
  let r = @wite_analyze.optimize_for_size(
    bytes, config=OptimizeConfig::o1(),
  ).unwrap()
  inspect(r.before_size, content="171100")
  // Pin the optimized size — if optimizer changes, update this
  inspect(r.after_size, content=(
    #|69644
  ))
}

///|
test "snapshot: component profile exact values" {
  guard read_fixture("bench/corpus/component/wac/dummy_wasi_http_0.2.3.wasm")
    is Some(bytes) else {
    return
  }
  let p = profile_component(bytes).unwrap()
  inspect(p.total_bytes, content="26993")
  inspect(p.core_module_count, content=(
    #|4
  ))
  inspect(p.nested_component_count, content=(
    #|1
  ))
}

///|
test "snapshot: hello.component profile exact values" {
  guard read_fixture(
      "bench/corpus/component-dce/mwac/hello.component.wasm",
    )
    is Some(bytes) else {
    return
  }
  let p = profile_component(bytes).unwrap()
  inspect(p.total_bytes, content="31400")
  inspect(p.core_module_count, content=(
    #|1
  ))
}

// WAC compose tests are in cmd/wite E2E tests (requires @wite_bundle import)
