///|
fn e2e_wasm_header() -> Array[Byte] {
  [b'\x00', b'\x61', b'\x73', b'\x6D', b'\x01', b'\x00', b'\x00', b'\x00']
}

///|
fn e2e_encode_leb128(value : UInt) -> Array[Byte] {
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
fn e2e_append_section(
  out : Array[Byte],
  id : UInt,
  payload : Array[Byte],
) -> Unit {
  out
  ..push(id.to_byte())
  .append(e2e_encode_leb128(payload.length().reinterpret_as_uint())[:])
  out.append(payload[:])
}

///|
/// Minimal core wasm: 1 func () -> (), exported as "run"
fn e2e_minimal_core_wasm() -> Bytes {
  let out = e2e_wasm_header()
  // Type section: 1 type, func () -> ()
  e2e_append_section(out, 1U, [b'\x01', b'\x60', b'\x00', b'\x00'])
  // Function section: 1 func, type 0
  e2e_append_section(out, 3U, [b'\x01', b'\x00'])
  // Export section: "run" func 0
  e2e_append_section(out, 7U, [
    b'\x01', b'\x03', b'\x72', b'\x75', b'\x6E', b'\x00', b'\x00',
  ])
  // Code section: 1 body (nop; end)
  e2e_append_section(out, 10U, [b'\x01', b'\x02', b'\x00', b'\x0B'])
  Bytes::from_array(out)
}

///|
/// Core wasm with 2 functions: func1 (exported "main") calls func0 (internal)
fn e2e_core_wasm_with_call() -> Bytes {
  let out = e2e_wasm_header()
  e2e_append_section(out, 1U, [b'\x01', b'\x60', b'\x00', b'\x00'])
  e2e_append_section(out, 3U, [b'\x02', b'\x00', b'\x00'])
  // Export "main" -> func 1
  e2e_append_section(out, 7U, [
    b'\x01', b'\x04', b'\x6D', b'\x61', b'\x69', b'\x6E', b'\x00', b'\x01',
  ])
  // Code: body0 (nop;end), body1 (call 0;end)
  e2e_append_section(out, 10U, [
    b'\x02', b'\x02', b'\x00', b'\x0B', b'\x04', b'\x00', b'\x10', b'\x00', b'\x0B',
  ])
  Bytes::from_array(out)
}

///|
fn e2e_write_wasm_file(dir : String, name : String, bytes : Bytes) -> String {
  let path = dir + "/" + name
  @fs.write_bytes_to_file(path, bytes) catch {
    _ => panic()
  }
  path
}

// ---- analyze_profile tests ----

///|
test "e2e: run_analyze prints section sizes" {
  let dir = js_make_temp_dir("wite-e2e-")
  let path = e2e_write_wasm_file(dir, "test.wasm", e2e_minimal_core_wasm())
  run_analyze(path)
  js_remove_dir_recursive(dir)
}

///|
test "e2e: run_deep_analyze prints full breakdown" {
  let dir = js_make_temp_dir("wite-e2e-")
  let path = e2e_write_wasm_file(dir, "test.wasm", e2e_core_wasm_with_call())
  run_deep_analyze(path, 5U)
  js_remove_dir_recursive(dir)
}

///|
test "e2e: run_analyze_host prints host code analysis" {
  let dir = js_make_temp_dir("wite-e2e-")
  let path = e2e_write_wasm_file(dir, "test.wasm", e2e_core_wasm_with_call())
  run_analyze_host(path, 10U)
  js_remove_dir_recursive(dir)
}

///|
test "e2e: run_analyze_opt prints optimization metadata" {
  let dir = js_make_temp_dir("wite-e2e-")
  let path = e2e_write_wasm_file(dir, "test.wasm", e2e_core_wasm_with_call())
  let config = @wite_core.OptimizeConfig::o1()
  run_analyze_opt(path, config, 10U)
  js_remove_dir_recursive(dir)
}

// ---- analyze_reports tests ----

///|
test "e2e: run_dce_report prints DCE info" {
  let dir = js_make_temp_dir("wite-e2e-")
  let path = e2e_write_wasm_file(dir, "test.wasm", e2e_core_wasm_with_call())
  run_dce_report(path, 10U)
  js_remove_dir_recursive(dir)
}

///|
test "e2e: run_top_functions prints function sizes" {
  let dir = js_make_temp_dir("wite-e2e-")
  let path = e2e_write_wasm_file(dir, "test.wasm", e2e_core_wasm_with_call())
  run_top_functions(path, 10U)
  js_remove_dir_recursive(dir)
}

///|
test "e2e: run_block_sizes prints block info" {
  let dir = js_make_temp_dir("wite-e2e-")
  let path = e2e_write_wasm_file(dir, "test.wasm", e2e_core_wasm_with_call())
  run_block_sizes(path, 10U)
  js_remove_dir_recursive(dir)
}

///|
test "e2e: run_callgraph prints call graph" {
  let dir = js_make_temp_dir("wite-e2e-")
  let path = e2e_write_wasm_file(dir, "test.wasm", e2e_core_wasm_with_call())
  run_callgraph(path, 10U)
  js_remove_dir_recursive(dir)
}

///|
test "e2e: run_function_gap compares two files" {
  let dir = js_make_temp_dir("wite-e2e-")
  let path_a = e2e_write_wasm_file(dir, "a.wasm", e2e_minimal_core_wasm())
  let path_b = e2e_write_wasm_file(dir, "b.wasm", e2e_core_wasm_with_call())
  run_function_gap(path_a, path_b, 10U)
  js_remove_dir_recursive(dir)
}

///|
test "e2e: run_section_gap compares sections" {
  let dir = js_make_temp_dir("wite-e2e-")
  let path_a = e2e_write_wasm_file(dir, "a.wasm", e2e_minimal_core_wasm())
  let path_b = e2e_write_wasm_file(dir, "b.wasm", e2e_core_wasm_with_call())
  run_section_gap(path_a, path_b, 10U)
  js_remove_dir_recursive(dir)
}

///|
test "e2e: run_block_gap compares blocks" {
  let dir = js_make_temp_dir("wite-e2e-")
  let path_a = e2e_write_wasm_file(dir, "a.wasm", e2e_minimal_core_wasm())
  let path_b = e2e_write_wasm_file(dir, "b.wasm", e2e_core_wasm_with_call())
  run_block_gap(path_a, path_b, 10U)
  js_remove_dir_recursive(dir)
}

///|
test "e2e: run_keep_reasons_with_options prints keep reasons" {
  let dir = js_make_temp_dir("wite-e2e-")
  let path = e2e_write_wasm_file(dir, "test.wasm", e2e_core_wasm_with_call())
  run_keep_reasons_with_options(path, false, false, [])
  js_remove_dir_recursive(dir)
}

///|
test "e2e: run_keep_reasons_with_options closed world" {
  let dir = js_make_temp_dir("wite-e2e-")
  let path = e2e_write_wasm_file(dir, "test.wasm", e2e_core_wasm_with_call())
  run_keep_reasons_with_options(path, true, false, ["main"])
  js_remove_dir_recursive(dir)
}

///|
test "e2e: run_retain_path_with_options prints retain paths" {
  let dir = js_make_temp_dir("wite-e2e-")
  let path = e2e_write_wasm_file(dir, "test.wasm", e2e_core_wasm_with_call())
  run_retain_path_with_options(path, 10U, false, false, [])
  js_remove_dir_recursive(dir)
}

///|
test "e2e: run_runtime_profile profiles exports" {
  let dir = js_make_temp_dir("wite-e2e-")
  let path = e2e_write_wasm_file(dir, "test.wasm", e2e_minimal_core_wasm())
  run_runtime_profile(path, 3U, [])
  js_remove_dir_recursive(dir)
}

///|
test "e2e: run_hot_size reports hotness matrix" {
  let dir = js_make_temp_dir("wite-e2e-")
  let path = e2e_write_wasm_file(dir, "test.wasm", e2e_minimal_core_wasm())
  run_hot_size(path, 3U, 10U, [])
  js_remove_dir_recursive(dir)
}

// ---- optimize tests ----

///|
test "e2e: run_optimize writes optimized file" {
  let dir = js_make_temp_dir("wite-e2e-")
  let input = e2e_write_wasm_file(dir, "input.wasm", e2e_core_wasm_with_call())
  let output = dir + "/output.wasm"
  run_optimize(["wite", "optimize", input, output, "-O1"])
  assert_true(@fs.path_exists(output))
  let output_bytes = @fs.read_file_to_bytes(output) catch {
    _ => fail("failed to read optimized output")
  }
  assert_true(output_bytes.length() > 0)
  js_remove_dir_recursive(dir)
}

///|
test "e2e: run_optimize with kind core" {
  let dir = js_make_temp_dir("wite-e2e-")
  let input = e2e_write_wasm_file(dir, "input.wasm", e2e_minimal_core_wasm())
  let output = dir + "/output.wasm"
  run_optimize(["wite", "optimize", input, output, "--kind=core", "-O0"])
  assert_true(@fs.path_exists(output))
  js_remove_dir_recursive(dir)
}

// ---- diff helpers ----

///|
test "e2e: run_diff via function_gap view" {
  let dir = js_make_temp_dir("wite-e2e-")
  let left = e2e_write_wasm_file(dir, "left.wasm", e2e_minimal_core_wasm())
  let right = e2e_write_wasm_file(dir, "right.wasm", e2e_core_wasm_with_call())
  run_function_gap(left, right, 20U)
  js_remove_dir_recursive(dir)
}

///|
test "e2e: optimize_with_kind auto detects core" {
  let bytes = e2e_core_wasm_with_call()
  let config = @wite_core.OptimizeConfig::o1()
  let result = optimize_with_kind(bytes, BinaryKind::Auto, config, [])
  assert_true(result is Ok(_))
  let r = result.unwrap()
  assert_true(r.after_size <= r.before_size)
}

///|
test "e2e: optimize_with_kind core explicit" {
  let bytes = e2e_core_wasm_with_call()
  let config = @wite_core.OptimizeConfig::os()
  let result = optimize_with_kind(bytes, BinaryKind::Core, config, [])
  assert_true(result is Ok(_))
}

///|
test "e2e: to_optimize_kind maps binary kinds" {
  let auto = to_optimize_kind(BinaryKind::Auto)
  let core = to_optimize_kind(BinaryKind::Core)
  let component = to_optimize_kind(BinaryKind::Component)
  // just verify they don't panic
  ignore(auto)
  ignore(core)
  ignore(component)
}

///|
test "e2e: write_output_or_exit creates output" {
  let dir = js_make_temp_dir("wite-e2e-")
  let path = dir + "/sub/out.wasm"
  write_output_or_exit(path, e2e_minimal_core_wasm())
  assert_true(@fs.path_exists(path))
  js_remove_dir_recursive(dir)
}

// ---- analyze_helpers ----

///|
test "e2e: resolve_config_file_path returns None when disabled" {
  let selection = parse_config_selection_flags_or_exit(["--no-config"])
  let result = resolve_config_file_path(selection)
  assert_true(result is None)
}

///|
test "e2e: load_wite_config_or_exit loads valid config" {
  let dir = js_make_temp_dir("wite-e2e-")
  let config_path = dir + "/wite.config.jsonc"
  @fs.write_string_to_file(config_path, "{}") catch {
    _ => fail("failed to write config")
  }
  let config = load_wite_config_or_exit(config_path)
  assert_eq(config.build_flags, [])
  js_remove_dir_recursive(dir)
}

///|
test "e2e: read_bytes_or_exit reads wasm file" {
  let dir = js_make_temp_dir("wite-e2e-")
  let path = e2e_write_wasm_file(dir, "test.wasm", e2e_minimal_core_wasm())
  let bytes = read_bytes_or_exit(path)
  assert_true(bytes.length() > 0)
  // Check wasm magic
  assert_eq(bytes[0], b'\x00')
  assert_eq(bytes[1], b'\x61')
  assert_eq(bytes[2], b'\x73')
  assert_eq(bytes[3], b'\x6D')
  js_remove_dir_recursive(dir)
}

// ---- optimize_cli unit tests ----

///|
test "e2e: parse_keep_custom extracts keep flags" {
  let result = parse_keep_custom(
    ["--keep-custom=name", "-O1", "--keep-custom=producers"],
    0,
  )
  assert_eq(result, ["name", "producers"])
}

///|
test "e2e: parse_keep_custom empty when no flags" {
  let result = parse_keep_custom(["-O1", "--strip"], 0)
  assert_eq(result, [])
}

///|
test "e2e: parse_closed_world_roots extracts roots" {
  let result = parse_closed_world_roots(
    ["--closed-world-root=main", "--other", "--closed-world-root=init"],
    0,
  )
  assert_eq(result, ["main", "init"])
}

///|
test "e2e: parse_closed_world_roots skips empty" {
  let result = parse_closed_world_roots(["--closed-world-root="], 0)
  assert_eq(result, [])
}

///|
test "e2e: parse_excluded_roots extracts excludes" {
  let result = parse_excluded_roots(
    ["--exclude=cabi_realloc", "--other", "--exclude=memory"],
    0,
  )
  assert_eq(result, ["cabi_realloc", "memory"])
}

///|
test "e2e: parse_uint_or_exit parses valid numbers" {
  assert_eq(parse_uint_or_exit("0", "test"), 0U)
  assert_eq(parse_uint_or_exit("42", "test"), 42U)
  assert_eq(parse_uint_or_exit("1000", "test"), 1000U)
}

///|
test "e2e: parse_int_or_exit parses positive and negative" {
  assert_eq(parse_int_or_exit("42", "test"), 42)
  assert_eq(parse_int_or_exit("-5", "test"), -5)
  assert_eq(parse_int_or_exit("0", "test"), 0)
}

///|
test "e2e: split_string splits correctly" {
  let result = split_string("a:b:c", ":")
  assert_eq(result, ["a", "b", "c"])
  let single = split_string("hello", ":")
  assert_eq(single, ["hello"])
}

///|
test "e2e: resolve_wasm_opt_bin uses override" {
  assert_eq(resolve_wasm_opt_bin(Some("my-wasm-opt")), "my-wasm-opt")
}

///|
test "e2e: parse_wasm_opt_optimize_level_or_exit valid levels" {
  assert_eq(parse_wasm_opt_optimize_level_or_exit("0"), 0U)
  assert_eq(parse_wasm_opt_optimize_level_or_exit("2"), 2U)
  assert_eq(parse_wasm_opt_optimize_level_or_exit("4"), 4U)
}

///|
test "e2e: parse_wasm_opt_shrink_level_or_exit valid levels" {
  assert_eq(parse_wasm_opt_shrink_level_or_exit("0"), 0U)
  assert_eq(parse_wasm_opt_shrink_level_or_exit("1"), 1U)
  assert_eq(parse_wasm_opt_shrink_level_or_exit("2"), 2U)
}

///|
test "e2e: parse_runtime_profile_scenarios parses scenarios" {
  let scenarios = parse_runtime_profile_scenarios(
    ["--scenario=run", "--other", "--scenario=compute:1,2,3"],
    0,
  )
  assert_eq(scenarios.length(), 2)
  assert_eq(scenarios[0].export_name, "run")
  assert_eq(scenarios[0].args, [])
  assert_eq(scenarios[1].export_name, "compute")
  assert_eq(scenarios[1].args, [1, 2, 3])
}

///|
test "e2e: parse_runtime_profile_scenarios empty" {
  let scenarios = parse_runtime_profile_scenarios(["--other", "-O1"], 0)
  assert_eq(scenarios.length(), 0)
}

///|
test "e2e: parse_wasm_opt_level_or_exit normalizes levels" {
  assert_eq(parse_wasm_opt_level_or_exit("-O0"), "-O0")
  assert_eq(parse_wasm_opt_level_or_exit("-Oz"), "-Oz")
  assert_eq(parse_wasm_opt_level_or_exit("-Os"), "-Os")
  assert_eq(parse_wasm_opt_level_or_exit("-O3"), "-O3")
}

///|
test "e2e: normalize_opt_level_token handles prefix variations" {
  assert_eq(normalize_opt_level_token("-O1"), "-O1")
  assert_eq(normalize_opt_level_token("O1"), "-O1")
  assert_eq(normalize_opt_level_token("fast"), "fast")
}

///|
test "e2e: parse_opt_level_or_exit returns config" {
  let config = parse_opt_level_or_exit("-O1")
  assert_eq(config.pass_rounds, 2U)
  assert_true(config.enable_dce)
}

// ---- usage helpers ----

///|
test "e2e: print_usage does not crash" {
  print_usage()
}

///|
test "e2e: print_analyze_usage does not crash" {
  print_analyze_usage()
}

// ---- analyze view command ----

///|
async test "e2e: run_analyze_view_command summary" {
  let dir = js_make_temp_dir("wite-e2e-")
  let path = e2e_write_wasm_file(dir, "test.wasm", e2e_core_wasm_with_call())
  run_analyze_view_command([
    "wite", "analyze", path, "--view=summary", "--no-config",
  ])
  js_remove_dir_recursive(dir)
}

///|
async test "e2e: run_analyze_view_command deep" {
  let dir = js_make_temp_dir("wite-e2e-")
  let path = e2e_write_wasm_file(dir, "test.wasm", e2e_core_wasm_with_call())
  run_analyze_view_command([
    "wite", "analyze", path, "--view=deep", "--no-config",
  ])
  js_remove_dir_recursive(dir)
}

///|
async test "e2e: run_analyze_view_command functions" {
  let dir = js_make_temp_dir("wite-e2e-")
  let path = e2e_write_wasm_file(dir, "test.wasm", e2e_core_wasm_with_call())
  run_analyze_view_command([
    "wite", "analyze", path, "--view=functions", "--no-config",
  ])
  js_remove_dir_recursive(dir)
}

///|
async test "e2e: run_analyze_view_command blocks" {
  let dir = js_make_temp_dir("wite-e2e-")
  let path = e2e_write_wasm_file(dir, "test.wasm", e2e_core_wasm_with_call())
  run_analyze_view_command([
    "wite", "analyze", path, "--view=blocks", "--no-config",
  ])
  js_remove_dir_recursive(dir)
}

///|
async test "e2e: run_analyze_view_command callgraph" {
  let dir = js_make_temp_dir("wite-e2e-")
  let path = e2e_write_wasm_file(dir, "test.wasm", e2e_core_wasm_with_call())
  run_analyze_view_command([
    "wite", "analyze", path, "--view=callgraph", "--no-config",
  ])
  js_remove_dir_recursive(dir)
}

///|
async test "e2e: run_analyze_view_command host" {
  let dir = js_make_temp_dir("wite-e2e-")
  let path = e2e_write_wasm_file(dir, "test.wasm", e2e_core_wasm_with_call())
  run_analyze_view_command([
    "wite", "analyze", path, "--view=host", "--no-config",
  ])
  js_remove_dir_recursive(dir)
}

///|
async test "e2e: run_analyze_view_command pipeline" {
  let dir = js_make_temp_dir("wite-e2e-")
  let path = e2e_write_wasm_file(dir, "test.wasm", e2e_core_wasm_with_call())
  run_analyze_view_command([
    "wite", "analyze", path, "--view=pipeline", "--no-config",
  ])
  js_remove_dir_recursive(dir)
}

///|
async test "e2e: run_analyze_view_command dce" {
  let dir = js_make_temp_dir("wite-e2e-")
  let path = e2e_write_wasm_file(dir, "test.wasm", e2e_core_wasm_with_call())
  run_analyze_view_command([
    "wite", "analyze", path, "--view=dce", "--no-config",
  ])
  js_remove_dir_recursive(dir)
}

///|
async test "e2e: run_analyze_view_command keep" {
  let dir = js_make_temp_dir("wite-e2e-")
  let path = e2e_write_wasm_file(dir, "test.wasm", e2e_core_wasm_with_call())
  run_analyze_view_command([
    "wite", "analyze", path, "--view=keep", "--no-config",
  ])
  js_remove_dir_recursive(dir)
}

///|
async test "e2e: run_analyze_view_command retain" {
  let dir = js_make_temp_dir("wite-e2e-")
  let path = e2e_write_wasm_file(dir, "test.wasm", e2e_core_wasm_with_call())
  run_analyze_view_command([
    "wite", "analyze", path, "--view=retain", "--no-config",
  ])
  js_remove_dir_recursive(dir)
}

///|
async test "e2e: run_analyze_view_command pipeline with opt-level" {
  let dir = js_make_temp_dir("wite-e2e-")
  let path = e2e_write_wasm_file(dir, "test.wasm", e2e_core_wasm_with_call())
  run_analyze_view_command([
    "wite", "analyze", path, "--view=pipeline", "--opt-level=-O2", "--diff-limit=5",
    "--no-config",
  ])
  js_remove_dir_recursive(dir)
}

///|
async test "e2e: run_analyze_view_command keep with closed-world" {
  let dir = js_make_temp_dir("wite-e2e-")
  let path = e2e_write_wasm_file(dir, "test.wasm", e2e_core_wasm_with_call())
  run_analyze_view_command([
    "wite", "analyze", path, "--view=keep", "--closed-world", "--closed-world-root=main",
    "--no-config",
  ])
  js_remove_dir_recursive(dir)
}

///|
async test "e2e: run_analyze_view_command retain with safe-mode and limit" {
  let dir = js_make_temp_dir("wite-e2e-")
  let path = e2e_write_wasm_file(dir, "test.wasm", e2e_core_wasm_with_call())
  run_analyze_view_command([
    "wite", "analyze", path, "--view=retain", "--safe-mode", "--limit=5", "--no-config",
  ])
  js_remove_dir_recursive(dir)
}

///|
async test "e2e: run_analyze_view_command summary with kind=core" {
  let dir = js_make_temp_dir("wite-e2e-")
  let path = e2e_write_wasm_file(dir, "test.wasm", e2e_core_wasm_with_call())
  run_analyze_view_command([
    "wite", "analyze", path, "--view=summary", "--kind=core", "--no-config",
  ])
  js_remove_dir_recursive(dir)
}

///|
async test "e2e: run_analyze_view_command deep with limit positional" {
  let dir = js_make_temp_dir("wite-e2e-")
  let path = e2e_write_wasm_file(dir, "test.wasm", e2e_core_wasm_with_call())
  run_analyze_view_command([
    "wite", "analyze", path, "--view=deep", "5", "--no-config",
  ])
  js_remove_dir_recursive(dir)
}

///|
async test "e2e: run_analyze_view_command pipeline with positional opt-level" {
  let dir = js_make_temp_dir("wite-e2e-")
  let path = e2e_write_wasm_file(dir, "test.wasm", e2e_core_wasm_with_call())
  run_analyze_view_command([
    "wite", "analyze", path, "--view=pipeline", "-O1", "--no-config",
  ])
  js_remove_dir_recursive(dir)
}

// ---- runtime profile with scenarios ----

///|
test "e2e: run_runtime_profile with scenarios" {
  let dir = js_make_temp_dir("wite-e2e-")
  let path = e2e_write_wasm_file(dir, "test.wasm", e2e_minimal_core_wasm())
  let scenarios = [@wite_core.make_runtime_profile_scenario("run")]
  run_runtime_profile(path, 2U, scenarios)
  js_remove_dir_recursive(dir)
}

///|
test "e2e: run_hot_size with scenarios" {
  let dir = js_make_temp_dir("wite-e2e-")
  let path = e2e_write_wasm_file(dir, "test.wasm", e2e_minimal_core_wasm())
  let scenarios = [@wite_core.make_runtime_profile_scenario("run")]
  run_hot_size(path, 2U, 5U, scenarios)
  js_remove_dir_recursive(dir)
}

// ---- optimize with various options ----

///|
test "e2e: run_optimize with strip flags" {
  let dir = js_make_temp_dir("wite-e2e-")
  let input = e2e_write_wasm_file(dir, "input.wasm", e2e_core_wasm_with_call())
  let output = dir + "/output.wasm"
  run_optimize([
    "wite", "optimize", input, output, "-O2", "--strip-debug", "--strip-dwarf",
  ])
  assert_true(@fs.path_exists(output))
  js_remove_dir_recursive(dir)
}

///|
test "e2e: run_optimize with closed-world" {
  let dir = js_make_temp_dir("wite-e2e-")
  let input = e2e_write_wasm_file(dir, "input.wasm", e2e_core_wasm_with_call())
  let output = dir + "/output.wasm"
  run_optimize([
    "wite", "optimize", input, output, "-O1", "-cw", "--closed-world-root=main",
  ])
  assert_true(@fs.path_exists(output))
  js_remove_dir_recursive(dir)
}

///|
test "e2e: run_optimize with verbose" {
  let dir = js_make_temp_dir("wite-e2e-")
  let input = e2e_write_wasm_file(dir, "input.wasm", e2e_core_wasm_with_call())
  let output = dir + "/output.wasm"
  run_optimize(["wite", "optimize", input, output, "-O0", "--verbose"])
  assert_true(@fs.path_exists(output))
  js_remove_dir_recursive(dir)
}

///|
test "e2e: run_optimize with keep-custom" {
  let dir = js_make_temp_dir("wite-e2e-")
  let input = e2e_write_wasm_file(dir, "input.wasm", e2e_core_wasm_with_call())
  let output = dir + "/output.wasm"
  run_optimize([
    "wite", "optimize", input, output, "-Os", "--keep-custom=producers",
  ])
  assert_true(@fs.path_exists(output))
  js_remove_dir_recursive(dir)
}

// ---- analyze_profile with kind ----

///|
async test "e2e: run_profile_command core" {
  let dir = js_make_temp_dir("wite-e2e-")
  let path = e2e_write_wasm_file(dir, "test.wasm", e2e_core_wasm_with_call())
  run_profile_command(["wite", "profile", path, "--no-config"])
  js_remove_dir_recursive(dir)
}

///|
async test "e2e: run_profile_command with kind=core" {
  let dir = js_make_temp_dir("wite-e2e-")
  let path = e2e_write_wasm_file(dir, "test.wasm", e2e_core_wasm_with_call())
  run_profile_command(["wite", "profile", path, "--kind=core", "--no-config"])
  js_remove_dir_recursive(dir)
}

///|
async test "e2e: run_profile_command component" {
  if !e2e_component_fixture_exists() {
    return
  }
  let path = e2e_component_fixture_path()
  run_profile_command([
    "wite", "profile", path, "--kind=component", "--no-config",
  ])
}

// ---- analyze subcommand with extra args ----

///|
async test "e2e: run_analyze_subcommand host with limit" {
  let dir = js_make_temp_dir("wite-e2e-")
  let path = e2e_write_wasm_file(dir, "test.wasm", e2e_core_wasm_with_call())
  run_analyze_subcommand(["wite", "analyze", "host", path, "3"], "host")
  js_remove_dir_recursive(dir)
}

///|
async test "e2e: run_analyze_subcommand opt with level and diff-limit" {
  let dir = js_make_temp_dir("wite-e2e-")
  let path = e2e_write_wasm_file(dir, "test.wasm", e2e_core_wasm_with_call())
  run_analyze_subcommand(["wite", "analyze", "opt", path, "-O2", "3"], "opt")
  js_remove_dir_recursive(dir)
}

///|
async test "e2e: run_analyze_subcommand function-gap" {
  let dir = js_make_temp_dir("wite-e2e-")
  let left = e2e_write_wasm_file(dir, "left.wasm", e2e_minimal_core_wasm())
  let right = e2e_write_wasm_file(dir, "right.wasm", e2e_core_wasm_with_call())
  run_analyze_subcommand(
    ["wite", "analyze", "function-gap", left, right],
    "function-gap",
  )
  js_remove_dir_recursive(dir)
}

///|
async test "e2e: run_analyze_subcommand keep-reasons" {
  let dir = js_make_temp_dir("wite-e2e-")
  let path = e2e_write_wasm_file(dir, "test.wasm", e2e_core_wasm_with_call())
  run_analyze_subcommand(
    ["wite", "analyze", "keep-reasons", path],
    "keep-reasons",
  )
  js_remove_dir_recursive(dir)
}

///|
async test "e2e: run_analyze_subcommand retain-path" {
  let dir = js_make_temp_dir("wite-e2e-")
  let path = e2e_write_wasm_file(dir, "test.wasm", e2e_core_wasm_with_call())
  run_analyze_subcommand(
    ["wite", "analyze", "retain-path", path],
    "retain-path",
  )
  js_remove_dir_recursive(dir)
}

///|
async test "e2e: run_analyze_subcommand profile" {
  let dir = js_make_temp_dir("wite-e2e-")
  let path = e2e_write_wasm_file(dir, "test.wasm", e2e_core_wasm_with_call())
  run_analyze_subcommand(
    ["wite", "analyze", "profile", path, "--no-config"],
    "profile",
  )
  js_remove_dir_recursive(dir)
}

// ---- component_commands extra coverage ----

///|
test "e2e: run_component_dce_kpi_command with safe_mode" {
  if !e2e_component_fixture_exists() {
    return
  }
  run_component_dce_kpi_command(
    e2e_component_fixture_path(),
    None,
    [],
    [],
    true,
    true,
  )
}

///|
test "e2e: run_root_policy_command with excludes" {
  if !e2e_component_fixture_exists() {
    return
  }
  run_root_policy_command(e2e_component_fixture_path(), None, ["cabi_realloc"])
}

// ---- analyze subcommand dispatch ----

///|
async test "e2e: run_analyze_subcommand host" {
  let dir = js_make_temp_dir("wite-e2e-")
  let path = e2e_write_wasm_file(dir, "test.wasm", e2e_core_wasm_with_call())
  run_analyze_subcommand(["wite", "analyze", "host", path], "host")
  js_remove_dir_recursive(dir)
}

///|
async test "e2e: run_analyze_subcommand deep" {
  let dir = js_make_temp_dir("wite-e2e-")
  let path = e2e_write_wasm_file(dir, "test.wasm", e2e_core_wasm_with_call())
  run_analyze_subcommand(["wite", "analyze", "deep", path], "deep")
  js_remove_dir_recursive(dir)
}

///|
async test "e2e: run_analyze_subcommand top-functions" {
  let dir = js_make_temp_dir("wite-e2e-")
  let path = e2e_write_wasm_file(dir, "test.wasm", e2e_core_wasm_with_call())
  run_analyze_subcommand(
    ["wite", "analyze", "top-functions", path],
    "top-functions",
  )
  js_remove_dir_recursive(dir)
}

///|
async test "e2e: run_analyze_subcommand block-sizes" {
  let dir = js_make_temp_dir("wite-e2e-")
  let path = e2e_write_wasm_file(dir, "test.wasm", e2e_core_wasm_with_call())
  run_analyze_subcommand(
    ["wite", "analyze", "block-sizes", path],
    "block-sizes",
  )
  js_remove_dir_recursive(dir)
}

///|
async test "e2e: run_analyze_subcommand callgraph" {
  let dir = js_make_temp_dir("wite-e2e-")
  let path = e2e_write_wasm_file(dir, "test.wasm", e2e_core_wasm_with_call())
  run_analyze_subcommand(["wite", "analyze", "callgraph", path], "callgraph")
  js_remove_dir_recursive(dir)
}

///|
async test "e2e: run_analyze_subcommand dce-report" {
  let dir = js_make_temp_dir("wite-e2e-")
  let path = e2e_write_wasm_file(dir, "test.wasm", e2e_core_wasm_with_call())
  run_analyze_subcommand(["wite", "analyze", "dce-report", path], "dce-report")
  js_remove_dir_recursive(dir)
}

///|
async test "e2e: run_analyze_subcommand opt" {
  let dir = js_make_temp_dir("wite-e2e-")
  let path = e2e_write_wasm_file(dir, "test.wasm", e2e_core_wasm_with_call())
  run_analyze_subcommand(["wite", "analyze", "opt", path], "opt")
  js_remove_dir_recursive(dir)
}

// ---- component_commands tests ----

///|
fn e2e_component_fixture_path() -> String {
  "bench/corpus/component-dce/mwac/hello.component.wasm"
}

///|
fn e2e_component_fixture_exists() -> Bool {
  @fs.path_exists(e2e_component_fixture_path())
}

///|
test "e2e: run_component_profile_command" {
  if !e2e_component_fixture_exists() {
    return
  }
  run_component_profile_command(e2e_component_fixture_path())
}

///|
test "e2e: run_component_top_functions_command" {
  if !e2e_component_fixture_exists() {
    return
  }
  run_component_top_functions_command(e2e_component_fixture_path(), 5U)
}

///|
test "e2e: run_component_callgraph_command" {
  if !e2e_component_fixture_exists() {
    return
  }
  run_component_callgraph_command(e2e_component_fixture_path(), 5U)
}

///|
test "e2e: run_component_dce_kpi_command without wit" {
  if !e2e_component_fixture_exists() {
    return
  }
  run_component_dce_kpi_command(
    e2e_component_fixture_path(),
    None,
    [],
    [],
    false,
    false,
  )
}

///|
test "e2e: run_component_dce_kpi_command verbose" {
  if !e2e_component_fixture_exists() {
    return
  }
  run_component_dce_kpi_command(
    e2e_component_fixture_path(),
    None,
    [],
    [],
    false,
    true,
  )
}

///|
test "e2e: run_interface_command without wit" {
  if !e2e_component_fixture_exists() {
    return
  }
  run_interface_command(e2e_component_fixture_path(), None, None, false)
}

///|
test "e2e: run_root_policy_command without wit" {
  if !e2e_component_fixture_exists() {
    return
  }
  run_root_policy_command(e2e_component_fixture_path(), None, [])
}

///|
test "e2e: print_component_section_sizes handles empty" {
  print_component_section_sizes([])
}

///|
test "e2e: print_component_section_sizes prints items" {
  let sections : Array[@wite_core.SectionSize] = [
    { key: "type", section_id: 1U, total_bytes: 100U },
    { key: "code", section_id: 10U, total_bytes: 200U },
  ]
  print_component_section_sizes(sections)
}

///|
test "e2e: print_component_function_sizes respects limit" {
  let functions : Array[@wite_core.FunctionSize] = [
    {
      function_index: 0U,
      body_bytes: 50U,
      name: Some("foo"),
      export_names: ["bar"],
    },
    { function_index: 1U, body_bytes: 30U, name: None, export_names: [] },
    { function_index: 2U, body_bytes: 10U, name: Some("baz"), export_names: [] },
  ]
  print_component_function_sizes(functions, 2U)
}

///|
test "e2e: print_component_call_graph_nodes formats correctly" {
  let nodes : Array[@wite_core.CallGraphNode] = [
    {
      function_index: 0U,
      body_bytes: 100U,
      name: Some("main"),
      export_names: ["_start"],
      direct_callees: [1U, 2U],
      reachable_from_roots: true,
    },
    {
      function_index: 1U,
      body_bytes: 50U,
      name: None,
      export_names: [],
      direct_callees: [],
      reachable_from_roots: false,
    },
  ]
  print_component_call_graph_nodes(nodes, 10U)
}

// ---- diff command tests ----

///|
async test "e2e: run_diff_command function view" {
  let dir = js_make_temp_dir("wite-e2e-")
  let left = e2e_write_wasm_file(dir, "left.wasm", e2e_minimal_core_wasm())
  let right = e2e_write_wasm_file(dir, "right.wasm", e2e_core_wasm_with_call())
  run_diff_command(["wite", "diff", left, right])
  js_remove_dir_recursive(dir)
}

///|
async test "e2e: run_diff_command section view" {
  let dir = js_make_temp_dir("wite-e2e-")
  let left = e2e_write_wasm_file(dir, "left.wasm", e2e_minimal_core_wasm())
  let right = e2e_write_wasm_file(dir, "right.wasm", e2e_core_wasm_with_call())
  run_diff_command(["wite", "diff", left, right, "--view=section"])
  js_remove_dir_recursive(dir)
}

///|
async test "e2e: run_diff_command block view" {
  let dir = js_make_temp_dir("wite-e2e-")
  let left = e2e_write_wasm_file(dir, "left.wasm", e2e_minimal_core_wasm())
  let right = e2e_write_wasm_file(dir, "right.wasm", e2e_core_wasm_with_call())
  run_diff_command(["wite", "diff", left, right, "--view=block"])
  js_remove_dir_recursive(dir)
}

///|
async test "e2e: run_diff_command with limit" {
  let dir = js_make_temp_dir("wite-e2e-")
  let left = e2e_write_wasm_file(dir, "left.wasm", e2e_minimal_core_wasm())
  let right = e2e_write_wasm_file(dir, "right.wasm", e2e_core_wasm_with_call())
  run_diff_command(["wite", "diff", left, right, "--limit=5"])
  js_remove_dir_recursive(dir)
}

// ---- analyze view with kind=component ----

///|
async test "e2e: run_analyze_view_command component summary" {
  if !e2e_component_fixture_exists() {
    return
  }
  let path = e2e_component_fixture_path()
  run_analyze_view_command([
    "wite", "analyze", path, "--view=summary", "--kind=component", "--no-config",
  ])
}

///|
async test "e2e: run_analyze_view_command component functions" {
  if !e2e_component_fixture_exists() {
    return
  }
  let path = e2e_component_fixture_path()
  run_analyze_view_command([
    "wite", "analyze", path, "--view=functions", "--kind=component", "--no-config",
  ])
}

///|
async test "e2e: run_analyze_view_command component callgraph" {
  if !e2e_component_fixture_exists() {
    return
  }
  let path = e2e_component_fixture_path()
  run_analyze_view_command([
    "wite", "analyze", path, "--view=callgraph", "--kind=component", "--no-config",
  ])
}

// ---- analyze subcommand component dispatch ----

///|
async test "e2e: run_analyze_subcommand component" {
  if !e2e_component_fixture_exists() {
    return
  }
  let path = e2e_component_fixture_path()
  run_analyze_subcommand(["wite", "analyze", "component", path], "component")
}

///|
async test "e2e: run_analyze_subcommand component-top-functions" {
  if !e2e_component_fixture_exists() {
    return
  }
  let path = e2e_component_fixture_path()
  run_analyze_subcommand(
    ["wite", "analyze", "component-top-functions", path],
    "component-top-functions",
  )
}

///|
async test "e2e: run_analyze_subcommand component-callgraph" {
  if !e2e_component_fixture_exists() {
    return
  }
  let path = e2e_component_fixture_path()
  run_analyze_subcommand(
    ["wite", "analyze", "component-callgraph", path],
    "component-callgraph",
  )
}

// ---- chunk build tests ----

///|
async test "e2e: build_chunks with no chunks is no-op" {
  let config = @wite_config.empty_wite_config_file()
  build_chunks(config, ".")
}

///|
async test "e2e: build_chunks with pre-built chunk" {
  let dir = js_make_temp_dir("wite-e2e-chunk-")
  // Write a pre-built wasm file
  let _ = e2e_write_wasm_file(dir, "lib.wasm", e2e_minimal_core_wasm())
  // Parse config with chunk pointing to pre-built file
  let text =
    #|{ "chunks": { "lib": "lib.wasm" } }
  let config = @wite_config.parse_wite_config_text(text).unwrap()
  build_chunks(config, dir)
  js_remove_dir_recursive(dir)
}

///|
async test "e2e: run_chunk_build_command skips when no build and output exists" {
  let dir = js_make_temp_dir("wite-e2e-chunk-")
  let _ = e2e_write_wasm_file(dir, "existing.wasm", e2e_minimal_core_wasm())
  let text =
    #|{ "chunks": { "test": "existing.wasm" } }
  let config = @wite_config.parse_wite_config_text(text).unwrap()
  let chunk = config.chunks["test"]
  run_chunk_build_command("test", chunk, dir)
  js_remove_dir_recursive(dir)
}

///|
async test "e2e: chunk_needs_rebuild true when output missing" {
  let text =
    #|{ "chunks": { "x": { "output": "nonexistent.wasm", "build": "echo ok" } } }
  let config = @wite_config.parse_wite_config_text(text).unwrap()
  let chunk = config.chunks["x"]
  assert_true(chunk_needs_rebuild(chunk, "."))
}

///|
async test "e2e: chunk_needs_rebuild false when output exists" {
  let dir = js_make_temp_dir("wite-e2e-chunk-")
  let _ = e2e_write_wasm_file(dir, "exists.wasm", e2e_minimal_core_wasm())
  let text =
    #|{ "chunks": { "x": { "output": "exists.wasm", "build": "echo ok" } } }
  let config = @wite_config.parse_wite_config_text(text).unwrap()
  let chunk = config.chunks["x"]
  assert_false(chunk_needs_rebuild(chunk, dir))
  js_remove_dir_recursive(dir)
}

///|
async test "e2e: build_chunks skips up-to-date chunks" {
  let dir = js_make_temp_dir("wite-e2e-chunk-")
  let _ = e2e_write_wasm_file(dir, "cached.wasm", e2e_minimal_core_wasm())
  let text =
    #|{ "chunks": { "cached": { "output": "cached.wasm", "build": "echo should-not-run" } } }
  let config = @wite_config.parse_wite_config_text(text).unwrap()
  build_chunks(config, dir)
  // If build ran, it would print "echo should-not-run" — but chunk is up-to-date
  js_remove_dir_recursive(dir)
}

///|
async test "e2e: componentize_chunk skips when no wit" {
  let dir = js_make_temp_dir("wite-e2e-chunk-")
  let _ = e2e_write_wasm_file(dir, "core.wasm", e2e_minimal_core_wasm())
  let text =
    #|{ "chunks": { "core": "core.wasm" } }
  let config = @wite_config.parse_wite_config_text(text).unwrap()
  let chunk = config.chunks["core"]
  componentize_chunk("core", chunk, dir)
  // Should not fail — just returns because no wit
  js_remove_dir_recursive(dir)
}

///|
async test "e2e: componentize_chunk skips when already component" {
  if !e2e_component_fixture_exists() {
    return
  }
  // Copy a component fixture to temp dir
  let dir = js_make_temp_dir("wite-e2e-chunk-")
  let src_bytes = @fs.read_file_to_bytes(e2e_component_fixture_path()) catch {
    _ => return
  }
  let _ = e2e_write_wasm_file(dir, "comp.wasm", src_bytes)
  let text =
    #|{ "chunks": { "comp": { "output": "comp.wasm", "wit": "nonexistent.wit" } } }
  let config = @wite_config.parse_wite_config_text(text).unwrap()
  let chunk = config.chunks["comp"]
  // Should skip because it's already a component (magic bytes check)
  componentize_chunk("comp", chunk, dir)
  js_remove_dir_recursive(dir)
}

///|
test "e2e: chunk_names returns configured chunks" {
  let text =
    #|{
    #|  "chunks": {
    #|    "a": "a.wasm",
    #|    "b": { "output": "b.wasm", "build": "make b" }
    #|  }
    #|}
  let config = @wite_config.parse_wite_config_text(text).unwrap()
  let names = @wite_config.chunk_names(config)
  assert_eq(names.length(), 2)
  assert_true(names.contains("a"))
  assert_true(names.contains("b"))
}
