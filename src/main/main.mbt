///|
fn print_usage() -> Unit {
  println("walyze commands:")
  println("  analyze <core.wasm>")
  println("  profile <core.wasm>")
  println("  top-functions <core.wasm> [limit]")
  println("  callgraph <core.wasm> [limit]")
  println(
    "  keep-reasons <core.wasm> [--closed-world] [--closed-world-root=<export-name>] [--safe-mode]",
  )
  println("  dce-report <core.wasm> [limit]")
  println("  runtime-profile <core.wasm> [iterations]")
  println(
    "  optimize <input.wasm> <output.wasm> [-O|-O0|-O1|-O2|-O3|-O4|-Os|-Oz] [--strip-all-custom] [--strip-debug] [--strip-dwarf] [--strip-target-features] [--keep-custom=<name>] [--no-peephole] [--no-vacuum] [--no-merge-blocks] [--no-remove-unused-brs] [--converge] [--rounds=<n>] [--dce-apply] [--dfe-apply] [--msf-apply] [--rume-apply] [--closed-world] [--closed-world-root=<export-name>] [--safe-mode]",
  )
  println("  component-profile <component.wasm>")
  println("  component-top-functions <component.wasm> [limit]")
  println("  component-callgraph <component.wasm> [limit]")
  println("  contract <component.wasm> <wit-dir>")
  println("  root-policy <component.wasm> [wit-dir]")
}

///|
fn read_bytes_or_exit(path : String) -> Bytes {
  @fs.read_file_to_bytes(path) catch {
    e => {
      println("failed to read file: " + path + " (" + e.to_string() + ")")
      @sys.exit(1)
      b""
    }
  }
}

///|
fn print_section_sizes(sections : Array[@walyze.SectionSize]) -> Unit {
  for section in sections {
    println(
      "  " + section.key + ": " + section.total_bytes.to_string() + " bytes",
    )
  }
}

///|
fn run_analyze(path : String) -> Unit {
  let bytes = read_bytes_or_exit(path)
  match @walyze.analyze_section_sizes(bytes) {
    Ok(sections) => {
      println("section size analysis:")
      print_section_sizes(sections)
    }
    Err(e) => {
      println("analyze failed: " + @walyze.error_to_string(e))
      @sys.exit(1)
    }
  }
}

///|
fn run_profile(path : String) -> Unit {
  let bytes = read_bytes_or_exit(path)
  match @walyze.profile_module(bytes) {
    Ok(profile) => {
      println("core wasm profile:")
      println("  total_bytes: " + profile.total_bytes.to_string())
      println("  function_count: " + profile.function_count.to_string())
      println("  import_count: " + profile.import_count.to_string())
      println("  export_count: " + profile.export_count.to_string())
      println("  code_body_count: " + profile.code_body_count.to_string())
      println("  code_body_bytes: " + profile.code_body_bytes.to_string())
      println("  sections:")
      print_section_sizes(profile.sections)
    }
    Err(e) => {
      println("profile failed: " + @walyze.error_to_string(e))
      @sys.exit(1)
    }
  }
}

///|
fn parse_keep_custom(args : Array[String], start : Int) -> Array[String] {
  let keep : Array[String] = []
  for i in start..<args.length() {
    let arg = args[i]
    match arg.strip_prefix("--keep-custom=") {
      Some(name) => keep.push(name.to_string())
      None => ()
    }
  }
  keep
}

///|
fn parse_closed_world_roots(args : Array[String], start : Int) -> Array[String] {
  let roots : Array[String] = []
  for i in start..<args.length() {
    match args[i].strip_prefix("--closed-world-root=") {
      Some(name) => if not(name.is_empty()) { roots.push(name.to_string()) }
      None => ()
    }
  }
  roots
}

///|
fn parse_uint_or_exit(text : String, name : String) -> UInt {
  if text.is_empty() {
    println("invalid " + name + ": empty string")
    @sys.exit(1)
    return 0U
  }
  let mut value = 0U
  for ch in text {
    let code = ch.to_int()
    if code < 48 || code > 57 {
      println("invalid " + name + ": " + text)
      @sys.exit(1)
      return 0U
    }
    value = value * 10U + (code - 48).reinterpret_as_uint()
  }
  value
}

///|
fn run_optimize(args : Array[String]) -> Unit {
  if args.length() < 4 {
    print_usage()
    @sys.exit(1)
  }
  let input_path = args[2]
  let output_path = args[3]
  let mut strip_all_custom = false
  let mut strip_name_section = true
  let mut strip_producers_section = true
  let mut strip_debug_sections = false
  let mut strip_dwarf_sections = false
  let mut strip_target_features_section = false
  let mut enable_peephole = true
  let mut enable_vacuum = true
  let mut enable_merge_blocks = true
  let mut enable_remove_unused_brs = true
  let mut pass_rounds = 1U
  let mut enable_dce = false
  let mut enable_dfe = false
  let mut enable_merge_similar_functions = false
  let mut enable_remove_unused_module_elements = false
  let mut closed_world = false
  let mut safe_mode = false
  for i in 4..<args.length() {
    match @walyze.optimize_config_from_opt_level(args[i]) {
      Some(preset) => {
        strip_all_custom = preset.strip_all_custom
        strip_name_section = preset.strip_name_section
        strip_producers_section = preset.strip_producers_section
        strip_debug_sections = preset.strip_debug_sections
        strip_dwarf_sections = preset.strip_dwarf_sections
        strip_target_features_section = preset.strip_target_features_section
        pass_rounds = preset.pass_rounds
        enable_peephole = preset.enable_peephole
        enable_vacuum = preset.enable_vacuum
        enable_merge_blocks = preset.enable_merge_blocks
        enable_remove_unused_brs = preset.enable_remove_unused_brs
        enable_dce = preset.enable_dce
        enable_dfe = preset.enable_dfe
        enable_merge_similar_functions = preset.enable_merge_similar_functions
        enable_remove_unused_module_elements = preset.enable_remove_unused_module_elements
        closed_world = preset.closed_world
        safe_mode = preset.safe_mode
      }
      None => ()
    }
    if args[i] == "--strip-all-custom" {
      strip_all_custom = true
    }
    if args[i] == "--strip-debug" {
      strip_debug_sections = true
    }
    if args[i] == "--strip-dwarf" {
      strip_dwarf_sections = true
    }
    if args[i] == "--strip-target-features" {
      strip_target_features_section = true
    }
    if args[i] == "--no-peephole" {
      enable_peephole = false
    }
    if args[i] == "--no-vacuum" {
      enable_vacuum = false
    }
    if args[i] == "--no-merge-blocks" {
      enable_merge_blocks = false
    }
    if args[i] == "--no-remove-unused-brs" {
      enable_remove_unused_brs = false
    }
    if args[i] == "--converge" {
      pass_rounds = 8U
    }
    match args[i].strip_prefix("--rounds=") {
      Some(value) =>
        pass_rounds = parse_uint_or_exit(value.to_string(), "rounds")
      None => ()
    }
    if args[i] == "--dce-apply" {
      enable_dce = true
    }
    if args[i] == "--dfe-apply" {
      enable_dfe = true
    }
    if args[i] == "--msf-apply" {
      enable_merge_similar_functions = true
    }
    if args[i] == "--rume-apply" {
      enable_remove_unused_module_elements = true
    }
    if args[i] == "--closed-world" {
      closed_world = true
    }
    if args[i] == "--safe-mode" {
      safe_mode = true
    }
  }
  let keep_custom_sections = parse_keep_custom(args, 4)
  let closed_world_root_exports = parse_closed_world_roots(args, 4)
  let config = @walyze.make_optimize_config(
    strip_all_custom~,
    strip_name_section~,
    strip_producers_section~,
    strip_debug_sections~,
    strip_dwarf_sections~,
    strip_target_features_section~,
    keep_custom_sections~,
    pass_rounds~,
    enable_peephole~,
    enable_vacuum~,
    enable_merge_blocks~,
    enable_remove_unused_brs~,
    enable_dce~,
    enable_dfe~,
    enable_merge_similar_functions~,
    enable_remove_unused_module_elements~,
    closed_world~,
    closed_world_root_exports~,
    safe_mode~,
  )
  let bytes = read_bytes_or_exit(input_path)
  match @walyze.optimize_for_size(bytes, config~) {
    Ok(result) => {
      @fs.write_bytes_to_file(output_path, result.bytes) catch {
        e => {
          println(
            "failed to write file: " + output_path + " (" + e.to_string() + ")",
          )
          @sys.exit(1)
        }
      }
      println(
        "optimized: " +
        result.before_size.to_string() +
        " -> " +
        result.after_size.to_string() +
        " bytes",
      )
      if result.removed_sections.length() > 0 {
        println("removed sections: " + result.removed_sections.join(", "))
      }
    }
    Err(e) => {
      println("optimize failed: " + @walyze.error_to_string(e))
      @sys.exit(1)
    }
  }
}

///|
fn run_dce_report(path : String, limit : UInt) -> Unit {
  let bytes = read_bytes_or_exit(path)
  match @walyze.analyze_dce_report(bytes) {
    Ok(report) => {
      println("dce report:")
      println("  roots: " + report.roots.map(i => i.to_string()).join(", "))
      println("  partial: " + report.partial.to_string())
      println(
        "  removable_function_count: " +
        report.removable_function_count.to_string(),
      )
      println(
        "  removable_body_bytes: " + report.removable_body_bytes.to_string(),
      )
      if report.removable_functions.length() > 0 {
        println("  removable_functions:")
        print_function_sizes(report.removable_functions, limit)
      }
    }
    Err(e) => {
      println("dce-report failed: " + @walyze.error_to_string(e))
      @sys.exit(1)
    }
  }
}

///|
fn run_runtime_profile(path : String, iterations : UInt) -> Unit {
  let bytes = read_bytes_or_exit(path)
  match @walyze.profile_runtime_zero_arg_exports(bytes, iterations~) {
    Ok(profile) => {
      println("runtime profile:")
      println("  instantiate_ns: " + profile.instantiate_ns.to_string())
      println("  iterations: " + profile.iterations.to_string())
      if profile.functions.length() == 0 {
        println("  functions: (no zero-arg exports)")
      } else {
        println("  functions:")
        for fn_profile in profile.functions {
          println(
            "    " +
            fn_profile.name +
            " calls=" +
            fn_profile.calls.to_string() +
            " total_ns=" +
            fn_profile.total_ns.to_string() +
            " avg_ns=" +
            fn_profile.average_ns.to_string(),
          )
        }
      }
      if profile.skipped_exports.length() > 0 {
        println("  skipped_exports: " + profile.skipped_exports.join(", "))
      }
    }
    Err(msg) => {
      println("runtime profile failed: " + msg)
      @sys.exit(1)
    }
  }
}

///|
fn print_function_sizes(
  functions : Array[@walyze.FunctionSize],
  limit : UInt,
) -> Unit {
  let mut printed = 0U
  for fn_size in functions {
    if printed >= limit {
      break
    }
    let label = match fn_size.name {
      Some(name) => name
      None => "#\{fn_size.function_index.to_string()}"
    }
    let exports = if fn_size.export_names.length() == 0 {
      ""
    } else {
      " exports=" + fn_size.export_names.join(",")
    }
    println(
      "    " +
      label +
      " idx=" +
      fn_size.function_index.to_string() +
      " body=" +
      fn_size.body_bytes.to_string() +
      exports,
    )
    printed += 1U
  }
}

///|
fn run_top_functions(path : String, limit : UInt) -> Unit {
  let bytes = read_bytes_or_exit(path)
  match @walyze.analyze_function_sizes(bytes) {
    Ok(functions) => {
      println("top functions:")
      println("  count: " + functions.length().to_string())
      print_function_sizes(functions, limit)
    }
    Err(e) => {
      println("top-functions failed: " + @walyze.error_to_string(e))
      @sys.exit(1)
    }
  }
}

///|
fn print_call_graph_nodes(
  nodes : Array[@walyze.CallGraphNode],
  limit : UInt,
) -> Unit {
  let mut printed = 0U
  for node in nodes {
    if printed >= limit {
      break
    }
    let label = match node.name {
      Some(name) => name
      None => "#\{node.function_index.to_string()}"
    }
    let status = if node.reachable_from_roots { "reachable" } else { "dead" }
    let export_part = if node.export_names.length() == 0 {
      ""
    } else {
      " exports=" + node.export_names.join(",")
    }
    let callee_part = if node.direct_callees.length() == 0 {
      ""
    } else {
      " callees=" + node.direct_callees.map(i => i.to_string()).join(",")
    }
    println(
      "    " +
      label +
      " idx=" +
      node.function_index.to_string() +
      " body=" +
      node.body_bytes.to_string() +
      " " +
      status +
      export_part +
      callee_part,
    )
    printed += 1U
  }
}

///|
fn run_callgraph(path : String, limit : UInt) -> Unit {
  let bytes = read_bytes_or_exit(path)
  match @walyze.analyze_call_graph(bytes) {
    Ok(report) => {
      println("call graph:")
      println(
        "  functions: imported=" +
        report.imported_function_count.to_string() +
        " local=" +
        report.local_function_count.to_string(),
      )
      println("  roots: " + report.roots.map(i => i.to_string()).join(", "))
      println("  has_indirect_calls: " + report.has_indirect_calls.to_string())
      println("  partial: " + report.partial.to_string())
      println(
        "  reachable_body_bytes: " + report.reachable_body_bytes.to_string(),
      )
      println("  dead_body_bytes: " + report.dead_body_bytes.to_string())
      println("  nodes:")
      print_call_graph_nodes(report.nodes, limit)
    }
    Err(e) => {
      println("callgraph failed: " + @walyze.error_to_string(e))
      @sys.exit(1)
    }
  }
}

///|
fn run_keep_reasons(args : Array[String]) -> Unit {
  if args.length() < 3 {
    print_usage()
    @sys.exit(1)
  }
  let path = args[2]
  let bytes = read_bytes_or_exit(path)
  let mut closed_world = false
  let mut safe_mode = false
  for i in 3..<args.length() {
    if args[i] == "--closed-world" {
      closed_world = true
    }
    if args[i] == "--safe-mode" {
      safe_mode = true
    }
  }
  let closed_world_root_exports = parse_closed_world_roots(args, 3)
  let config = @walyze.make_optimize_config(
    closed_world~,
    closed_world_root_exports~,
    safe_mode~,
  )
  match @walyze.analyze_keep_reasons(bytes, config~) {
    Ok(report) => {
      println("keep reasons:")
      println("  partial: " + report.partial.to_string())
      if report.entries.length() == 0 {
        println("  entries: (none)")
      } else {
        println("  entries:")
        for entry in report.entries {
          let label = match entry.name {
            Some(v) => v
            None => "#\{entry.function_index.to_string()}"
          }
          let exports = if entry.export_names.length() == 0 {
            ""
          } else {
            " exports=" + entry.export_names.join(",")
          }
          println(
            "    " +
            label +
            " idx=" +
            entry.function_index.to_string() +
            exports +
            " reasons=" +
            entry.reasons.join(","),
          )
        }
      }
    }
    Err(e) => {
      println("keep-reasons failed: " + @walyze.error_to_string(e))
      @sys.exit(1)
    }
  }
}

///|
fn run_component_profile(path : String) -> Unit {
  let bytes = read_bytes_or_exit(path)
  match @walyze.profile_component(bytes) {
    Ok(profile) => {
      println("component profile:")
      println("  total_bytes: " + profile.total_bytes.to_string())
      println("  import_count: " + profile.import_count.to_string())
      println("  export_count: " + profile.export_count.to_string())
      println("  core_module_count: " + profile.core_module_count.to_string())
      println(
        "  nested_component_count: " +
        profile.nested_component_count.to_string(),
      )
      println("  sections:")
      print_section_sizes(profile.sections)
      println("  core modules:")
      for i in 0..<profile.core_modules.length() {
        let core = profile.core_modules[i]
        println(
          "    #" +
          i.to_string() +
          " total=" +
          core.total_bytes.to_string() +
          " funcs=" +
          core.function_count.to_string() +
          " code=" +
          core.code_body_bytes.to_string(),
        )
      }
    }
    Err(msg) => {
      println("component profile failed: " + msg)
      @sys.exit(1)
    }
  }
}

///|
fn run_component_top_functions(path : String, limit : UInt) -> Unit {
  let bytes = read_bytes_or_exit(path)
  match @walyze.analyze_component_function_sizes(bytes) {
    Ok(reports) => {
      println("component top functions:")
      println("  core_modules: " + reports.length().to_string())
      for report in reports {
        println(
          "  core module #" +
          report.module_index.to_string() +
          " function_count=" +
          report.function_count.to_string() +
          " total_body_bytes=" +
          report.total_body_bytes.to_string(),
        )
        print_function_sizes(report.functions, limit)
      }
    }
    Err(msg) => {
      println("component-top-functions failed: " + msg)
      @sys.exit(1)
    }
  }
}

///|
fn run_component_callgraph(path : String, limit : UInt) -> Unit {
  let bytes = read_bytes_or_exit(path)
  match @walyze.analyze_component_call_graphs(bytes) {
    Ok(reports) => {
      println("component call graph:")
      println("  core_modules: " + reports.length().to_string())
      for report in reports {
        println("  core module #" + report.module_index.to_string())
        println(
          "    functions: imported=" +
          report.graph.imported_function_count.to_string() +
          " local=" +
          report.graph.local_function_count.to_string(),
        )
        println(
          "    reachable_body_bytes=" +
          report.graph.reachable_body_bytes.to_string() +
          " dead_body_bytes=" +
          report.graph.dead_body_bytes.to_string(),
        )
        println("    partial=" + report.graph.partial.to_string())
        print_call_graph_nodes(report.graph.nodes, limit)
      }
    }
    Err(msg) => {
      println("component-callgraph failed: " + msg)
      @sys.exit(1)
    }
  }
}

///|
fn run_contract(component_path : String, wit_path : String) -> Unit {
  let bytes = read_bytes_or_exit(component_path)
  match @wit.resolve_path(wit_path) {
    Ok(resolved) =>
      match @walyze.analyze_component_contract(bytes, resolved) {
        Ok(report) => {
          println("component imports: " + report.component_imports.join(", "))
          println("component exports: " + report.component_exports.join(", "))
          println("wit imports: " + report.wit_imports.join(", "))
          println("wit exports: " + report.wit_exports.join(", "))
          println(
            "missing component imports: " +
            report.missing_component_imports.join(", "),
          )
          println(
            "missing component exports: " +
            report.missing_component_exports.join(", "),
          )
        }
        Err(msg) => {
          println("contract analyze failed: " + msg)
          @sys.exit(1)
        }
      }
    Err(e) => {
      println("wit resolve failed: " + e.to_string())
      @sys.exit(1)
    }
  }
}

///|
fn run_root_policy(component_path : String, wit_path : String?) -> Unit {
  let bytes = read_bytes_or_exit(component_path)
  let resolved_wit : @wit.ResolveInput? = match wit_path {
    Some(path) =>
      match @wit.resolve_path(path) {
        Ok(v) => Some(v)
        Err(e) => {
          println("wit resolve failed: " + e.to_string())
          @sys.exit(1)
          None
        }
      }
    None => None
  }
  match @walyze.analyze_component_root_policy(bytes, resolved_wit~) {
    Ok(policy) => {
      println("component imports: " + policy.component_imports.join(", "))
      println("component exports: " + policy.component_exports.join(", "))
      println("wit imports: " + policy.wit_imports.join(", "))
      println("wit exports: " + policy.wit_exports.join(", "))
      println("canonical abi roots: " + policy.canonical_abi_roots.join(", "))
      println("root candidates: " + policy.root_name_candidates.join(", "))
    }
    Err(msg) => {
      println("root-policy analyze failed: " + msg)
      @sys.exit(1)
    }
  }
}

///|
fn main {
  let args = @sys.get_cli_args()
  if args.length() < 2 {
    print_usage()
    @sys.exit(1)
  }
  match args[1] {
    "analyze" => {
      if args.length() < 3 {
        print_usage()
        @sys.exit(1)
      }
      run_analyze(args[2])
    }
    "profile" => {
      if args.length() < 3 {
        print_usage()
        @sys.exit(1)
      }
      run_profile(args[2])
    }
    "top-functions" => {
      if args.length() < 3 {
        print_usage()
        @sys.exit(1)
      }
      let limit = if args.length() >= 4 {
        parse_uint_or_exit(args[3], "limit")
      } else {
        20U
      }
      run_top_functions(args[2], limit)
    }
    "callgraph" => {
      if args.length() < 3 {
        print_usage()
        @sys.exit(1)
      }
      let limit = if args.length() >= 4 {
        parse_uint_or_exit(args[3], "limit")
      } else {
        20U
      }
      run_callgraph(args[2], limit)
    }
    "keep-reasons" => run_keep_reasons(args)
    "dce-report" => {
      if args.length() < 3 {
        print_usage()
        @sys.exit(1)
      }
      let limit = if args.length() >= 4 {
        parse_uint_or_exit(args[3], "limit")
      } else {
        20U
      }
      run_dce_report(args[2], limit)
    }
    "runtime-profile" => {
      if args.length() < 3 {
        print_usage()
        @sys.exit(1)
      }
      let iterations = if args.length() >= 4 {
        parse_uint_or_exit(args[3], "iterations")
      } else {
        50U
      }
      run_runtime_profile(args[2], iterations)
    }
    "optimize" => run_optimize(args)
    "component-profile" => {
      if args.length() < 3 {
        print_usage()
        @sys.exit(1)
      }
      run_component_profile(args[2])
    }
    "component-top-functions" => {
      if args.length() < 3 {
        print_usage()
        @sys.exit(1)
      }
      let limit = if args.length() >= 4 {
        parse_uint_or_exit(args[3], "limit")
      } else {
        20U
      }
      run_component_top_functions(args[2], limit)
    }
    "component-callgraph" => {
      if args.length() < 3 {
        print_usage()
        @sys.exit(1)
      }
      let limit = if args.length() >= 4 {
        parse_uint_or_exit(args[3], "limit")
      } else {
        20U
      }
      run_component_callgraph(args[2], limit)
    }
    "contract" => {
      if args.length() < 4 {
        print_usage()
        @sys.exit(1)
      }
      run_contract(args[2], args[3])
    }
    "root-policy" => {
      if args.length() < 3 {
        print_usage()
        @sys.exit(1)
      }
      let wit_path = if args.length() >= 4 { Some(args[3]) } else { None }
      run_root_policy(args[2], wit_path)
    }
    _ => {
      print_usage()
      @sys.exit(1)
    }
  }
}
