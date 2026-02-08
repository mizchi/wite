///|
fn print_usage() -> Unit {
  println("walyze commands:")
  println("  analyze <core.wasm>")
  println("  analyze-host <core.wasm> [limit]")
  println("  analyze-opt <core.wasm> [opt-level] [diff-limit]")
  println("  deep-analyze <core.wasm> [limit]")
  println("  profile <core.wasm>")
  println("  top-functions <core.wasm> [limit]")
  println("  function-gap <left.wasm> <right.wasm> [limit]")
  println("  block-sizes <core.wasm> [limit]")
  println("  callgraph <core.wasm> [limit]")
  println(
    "  keep-reasons <core.wasm> [--closed-world] [--closed-world-root=<export-name>] [--safe-mode]",
  )
  println(
    "  retain-path <core.wasm> [limit] [--closed-world] [--closed-world-root=<export-name>] [--safe-mode]",
  )
  println("  dce-report <core.wasm> [limit]")
  println("  runtime-profile <core.wasm> [iterations]")
  println("  hot-size <core.wasm> [iterations] [limit]")
  println(
    "  optimize <input.wasm> <output.wasm> [-O|-O0|-O1|-O2|-O3|-O4|-Os|-Oz] [--strip-all-custom] [--strip-debug] [--strip-dwarf] [--strip-target-features] [--keep-custom=<name>] [--exclude=<name>] [--no-peephole] [--no-vacuum] [--no-merge-blocks] [--no-remove-unused-brs] [--converge] [--rounds=<n>] [--dce-apply] [--dfe-apply] [--msf-apply] [--rume-apply] [--closed-world] [--closed-world-root=<export-name>] [--safe-mode] [--verbose]",
  )
  println("  component-profile <component.wasm>")
  println("  component-top-functions <component.wasm> [limit]")
  println("  component-callgraph <component.wasm> [limit]")
  println(
    "  component-dce-kpi <component.wasm> [wit-dir] [--exclude=<name>] [--closed-world-root=<export-name>] [--safe-mode] [--verbose]",
  )
  println("  contract <component.wasm> <wit-dir>")
  println("  root-policy <component.wasm> [wit-dir] [--exclude=<name>]")
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
fn pad_two_digits_u64(value : UInt64) -> String {
  if value < 10UL {
    "0" + value.to_string()
  } else {
    value.to_string()
  }
}

///|
fn format_percent(numerator : UInt, denominator : UInt) -> String {
  if denominator == 0U {
    return "0.00%"
  }
  let scaled = numerator.to_uint64() * 10000UL / denominator.to_uint64()
  let whole = scaled / 100UL
  let frac = scaled % 100UL
  whole.to_string() + "." + pad_two_digits_u64(frac) + "%"
}

///|
fn print_section_sizes_with_share(
  sections : Array[@walyze.SectionSize],
  total_bytes : UInt,
) -> Unit {
  for section in sections {
    println(
      "    " +
      section.key +
      ": " +
      section.total_bytes.to_string() +
      " bytes (" +
      format_percent(section.total_bytes, total_bytes) +
      ")",
    )
  }
}

///|
fn print_custom_section_breakdown(
  sections : Array[@walyze.CustomSectionBreakdown],
  total_bytes : UInt,
  limit : UInt,
) -> Unit {
  if sections.length() == 0 {
    println("  custom sections: (none)")
    return
  }
  println("  custom sections:")
  let mut printed = 0U
  for section in sections {
    if printed >= limit {
      break
    }
    println(
      "    " +
      section.name +
      " count=" +
      section.count.to_string() +
      " total=" +
      section.total_bytes.to_string() +
      " bytes (" +
      format_percent(section.total_bytes, total_bytes) +
      ") payload=" +
      section.payload_bytes.to_string() +
      " content=" +
      section.content_bytes.to_string(),
    )
    printed += 1U
  }
}

///|
fn print_opcode_stats(
  stats : Array[@walyze.OpcodeStat],
  total_instruction_bytes : UInt,
  limit : UInt,
) -> Unit {
  if stats.length() == 0 {
    println("  opcode mix: (none)")
    return
  }
  println("  opcode mix:")
  let mut printed = 0U
  for stat in stats {
    if printed >= limit {
      break
    }
    println(
      "    " +
      stat.mnemonic +
      " [" +
      stat.key +
      "] count=" +
      stat.count.to_string() +
      " bytes=" +
      stat.total_bytes.to_string() +
      " (" +
      format_percent(stat.total_bytes, total_instruction_bytes) +
      ")",
    )
    printed += 1U
  }
}

///|
fn format_root_preview(roots : Array[UInt], limit : UInt) -> String {
  if roots.length() == 0 {
    return "(none)"
  }
  let items : Array[String] = []
  let mut printed = 0U
  for index in roots {
    if printed >= limit {
      break
    }
    items.push(index.to_string())
    printed += 1U
  }
  if roots.length().reinterpret_as_uint() > limit {
    items.join(", ") +
    " ... (+" +
    (roots.length().reinterpret_as_uint() - limit).to_string() +
    ")"
  } else {
    items.join(", ")
  }
}

///|
fn print_call_graph_summary(summary : @walyze.CallGraphSummary) -> Unit {
  println("call graph summary:")
  println(
    "  functions: imported=" +
    summary.imported_function_count.to_string() +
    " local=" +
    summary.local_function_count.to_string() +
    " reachable=" +
    summary.reachable_function_count.to_string() +
    " dead=" +
    summary.dead_function_count.to_string(),
  )
  println("  roots: " + format_root_preview(summary.roots, 8U))
  println("  has_indirect_calls: " + summary.has_indirect_calls.to_string())
  println("  partial: " + summary.partial.to_string())
  let total_local_body_bytes = summary.reachable_body_bytes +
    summary.dead_body_bytes
  println(
    "  reachable_body_bytes: " +
    summary.reachable_body_bytes.to_string() +
    " (" +
    format_percent(summary.reachable_body_bytes, total_local_body_bytes) +
    ")",
  )
  println(
    "  dead_body_bytes: " +
    summary.dead_body_bytes.to_string() +
    " (" +
    format_percent(summary.dead_body_bytes, total_local_body_bytes) +
    ")",
  )
}

///|
fn print_host_code_hints(
  hints : Array[@walyze.HostCodeHint],
  limit : UInt,
) -> Unit {
  if hints.length() == 0 {
    println("  hints: (none)")
    return
  }
  println("  hints:")
  let mut printed = 0U
  for hint in hints {
    if printed >= limit {
      break
    }
    let label = match hint.function_name {
      Some(name) => name
      None => "#\{hint.function_index.to_string()}"
    }
    let target_label = match hint.target_function_name {
      Some(name) => name
      None => "#\{hint.target_function_index.to_string()}"
    }
    let export_part = if hint.export_names.length() == 0 {
      ""
    } else {
      " exports=" + hint.export_names.join(",")
    }
    println(
      "    " +
      hint.kind +
      " " +
      label +
      " -> " +
      target_label +
      " consts=" +
      hint.appended_i32_const_count.to_string() +
      " drops=" +
      hint.dropped_param_count.to_string() +
      export_part,
    )
    printed += 1U
  }
}

///|
fn run_analyze_host(path : String, limit : UInt) -> Unit {
  let bytes = read_bytes_or_exit(path)
  match @walyze.analyze_host_generated_code(bytes) {
    Ok(report) => {
      println("host/generated code analysis:")
      println(
        "  functions: imported=" +
        report.imported_function_count.to_string() +
        " local=" +
        report.local_function_count.to_string(),
      )
      println(
        "  forwarding_thunks: param=" +
        report.param_forwarding_thunk_count.to_string() +
        " const=" +
        report.const_forwarding_thunk_count.to_string() +
        " signature-refine=" +
        report.signature_refinable_thunk_count.to_string(),
      )
      println(
        "  directize_candidate_calls: " +
        report.directize_candidate_call_count.to_string(),
      )
      println(
        "  dce_removable: functions=" +
        report.dce_removable_function_count.to_string() +
        " bytes=" +
        report.dce_removable_body_bytes.to_string() +
        " partial=" +
        report.dce_partial.to_string(),
      )
      print_host_code_hints(report.hints, limit)
    }
    Err(e) => {
      println("analyze-host failed: " + @walyze.error_to_string(e))
      @sys.exit(1)
    }
  }
}

///|
fn print_optimize_metadata_stage(stage : @walyze.OptimizeStageMetadata) -> Unit {
  println(
    "    " +
    stage.stage +
    ": " +
    stage.before_size.to_string() +
    " -> " +
    stage.after_size.to_string() +
    " gain=" +
    stage.gain_bytes.to_string() +
    " regression=" +
    stage.regression_bytes.to_string(),
  )
  if stage.removed_sections.length() > 0 {
    println("      pass markers: " + stage.removed_sections.join(", "))
  }
  if stage.no_change_reasons.length() > 0 {
    println("      no-change: " + stage.no_change_reasons.join(", "))
  }
  println(
    "      function-delta: gain=" +
    stage.function_gain_bytes.to_string() +
    " regression=" +
    stage.function_regression_bytes.to_string(),
  )
  if stage.function_diffs.length() > 0 {
    println("      top-function-diffs:")
    let mut printed = 0U
    for diff in stage.function_diffs {
      if printed >= 5U {
        break
      }
      let label = match diff.before_name {
        Some(v) => v
        None =>
          match diff.after_name {
            Some(v) => v
            None => "#\{diff.function_index.to_string()}"
          }
      }
      let exports = if diff.export_names.length() == 0 {
        ""
      } else {
        " exports=" + diff.export_names.join(",")
      }
      println(
        "        " +
        label +
        " idx=" +
        diff.function_index.to_string() +
        " before=" +
        diff.before_body_bytes.to_string() +
        " after=" +
        diff.after_body_bytes.to_string() +
        " gain=" +
        diff.gain_bytes.to_string() +
        " regression=" +
        diff.regression_bytes.to_string() +
        exports,
      )
      printed += 1U
    }
  }
}

///|
fn run_analyze_opt(
  path : String,
  config : @walyze.OptimizeConfig,
  function_diff_limit : UInt,
) -> Unit {
  let bytes = read_bytes_or_exit(path)
  match
    @walyze.analyze_optimize_metadata(bytes, config~, function_diff_limit~) {
    Ok(report) => {
      println("optimize metadata analysis:")
      println(
        "  total: " +
        report.before_size.to_string() +
        " -> " +
        report.after_size.to_string() +
        " gain=" +
        report.total_gain_bytes.to_string() +
        " regression=" +
        report.total_regression_bytes.to_string(),
      )
      println("  stages:")
      for stage in report.stages {
        print_optimize_metadata_stage(stage)
      }
    }
    Err(e) => {
      println("analyze-opt failed: " + @walyze.error_to_string(e))
      @sys.exit(1)
    }
  }
}

///|
fn run_analyze(path : String) -> Unit {
  let bytes = read_bytes_or_exit(path)
  match @walyze.analyze_section_sizes(bytes) {
    Ok(sections) => {
      println("section size analysis:")
      print_section_sizes_with_share(
        sections,
        bytes.length().reinterpret_as_uint(),
      )
      match @walyze.analyze_call_graph_summary(bytes) {
        Ok(summary) => print_call_graph_summary(summary)
        Err(e) => {
          println("analyze failed: " + @walyze.error_to_string(e))
          @sys.exit(1)
        }
      }
    }
    Err(e) => {
      println("analyze failed: " + @walyze.error_to_string(e))
      @sys.exit(1)
    }
  }
}

///|
fn run_deep_analyze(path : String, limit : UInt) -> Unit {
  let bytes = read_bytes_or_exit(path)
  match @walyze.analyze_wasm_breakdown(bytes, top_limit=limit) {
    Ok(report) => {
      println("wasm deep analysis:")
      println("  total_bytes: " + report.total_bytes.to_string())
      println(
        "  functions: imported=" +
        report.imported_function_count.to_string() +
        " local=" +
        report.local_function_count.to_string(),
      )
      println("  instruction_count: " + report.instruction_count.to_string())
      println("  instruction_bytes: " + report.instruction_bytes.to_string())
      println("  opcode_partial: " + report.opcode_partial.to_string())
      println("  callgraph_partial: " + report.callgraph_partial.to_string())
      println("  has_indirect_calls: " + report.has_indirect_calls.to_string())
      let total_local_body_bytes = report.reachable_body_bytes +
        report.dead_body_bytes
      println(
        "  reachable_body_bytes: " +
        report.reachable_body_bytes.to_string() +
        " (" +
        format_percent(report.reachable_body_bytes, total_local_body_bytes) +
        ")",
      )
      println(
        "  dead_body_bytes: " +
        report.dead_body_bytes.to_string() +
        " (" +
        format_percent(report.dead_body_bytes, total_local_body_bytes) +
        ")",
      )
      println("  sections:")
      print_section_sizes_with_share(report.sections, report.total_bytes)
      print_custom_section_breakdown(
        report.custom_sections,
        report.total_bytes,
        limit,
      )
      println("  top functions:")
      print_function_sizes(report.top_functions, limit)
      println("  top blocks:")
      print_code_block_sizes(report.top_blocks, limit)
      print_opcode_stats(report.opcodes, report.instruction_bytes, limit)
    }
    Err(e) => {
      println("deep-analyze failed: " + @walyze.error_to_string(e))
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
fn parse_excluded_roots(args : Array[String], start : Int) -> Array[String] {
  let excludes : Array[String] = []
  for i in start..<args.length() {
    match args[i].strip_prefix("--exclude=") {
      Some(name) => if not(name.is_empty()) { excludes.push(name.to_string()) }
      None => ()
    }
  }
  excludes
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
  let mut verbose = false
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
    if args[i] == "--verbose" {
      verbose = true
    }
  }
  let keep_custom_sections = parse_keep_custom(args, 4)
  let closed_world_root_exports = parse_closed_world_roots(args, 4)
  let excluded_roots = parse_excluded_roots(args, 4)
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
  match
    @walyze.optimize_binary_for_size(bytes, config~, exclude=excluded_roots) {
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
      if verbose && result.no_change_reasons.length() > 0 {
        println("no-change reasons: " + result.no_change_reasons.join(", "))
      }
    }
    Err(msg) => {
      println("optimize failed: " + msg)
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
      if profile.unresolved_exports.length() > 0 {
        println("  unresolved_exports:")
        for unresolved in profile.unresolved_exports {
          let detail = if unresolved.detail.is_empty() {
            ""
          } else {
            " detail=" + unresolved.detail
          }
          println(
            "    " +
            unresolved.export_name +
            " reason=" +
            unresolved.reason +
            detail,
          )
        }
      }
    }
    Err(msg) => {
      println("runtime profile failed: " + msg)
      @sys.exit(1)
    }
  }
}

///|
fn print_hotness_size_entries(
  entries : Array[@walyze.HotnessSizeEntry],
  limit : UInt,
) -> Unit {
  if entries.length() == 0 {
    println("  entries: (none)")
    return
  }
  println("  entries:")
  let mut printed = 0U
  for entry in entries {
    if printed >= limit {
      break
    }
    let index_text = match entry.function_index {
      Some(v) => v.to_string()
      None => "-"
    }
    let function_name = match entry.function_name {
      Some(v) => v
      None => "-"
    }
    let unresolved_reason = match entry.unresolved_reason {
      Some(v) => " reason=" + v
      None => ""
    }
    let unresolved_detail = match entry.unresolved_detail {
      Some(v) => if v.is_empty() { "" } else { " detail=" + v }
      None => ""
    }
    println(
      "    " +
      entry.export_name +
      " idx=" +
      index_text +
      " fn=" +
      function_name +
      " body=" +
      entry.body_bytes.to_string() +
      " calls=" +
      entry.calls.to_string() +
      " total_ns=" +
      entry.total_ns.to_string() +
      " avg_ns=" +
      entry.average_ns.to_string() +
      " bucket=" +
      entry.bucket +
      unresolved_reason +
      unresolved_detail,
    )
    printed += 1U
  }
}

///|
fn print_hotness_size_buckets(
  buckets : Array[@walyze.HotnessSizeBucket],
) -> Unit {
  println("  buckets:")
  for bucket in buckets {
    println(
      "    " +
      bucket.bucket +
      " count=" +
      bucket.count.to_string() +
      " body_bytes=" +
      bucket.body_bytes.to_string() +
      " total_ns=" +
      bucket.total_ns.to_string(),
    )
  }
}

///|
fn print_hotness_unresolved_reason_counts(
  counts : Array[@walyze.HotnessUnresolvedReasonCount],
) -> Unit {
  if counts.length() == 0 {
    return
  }
  println("  unresolved_reasons:")
  for count in counts {
    println("    " + count.reason + " count=" + count.count.to_string())
  }
}

///|
fn run_hot_size(path : String, iterations : UInt, limit : UInt) -> Unit {
  let bytes = read_bytes_or_exit(path)
  match @walyze.analyze_hotness_size_matrix(bytes, iterations~) {
    Ok(report) => {
      println("hot-size matrix:")
      println("  instantiate_ns: " + report.instantiate_ns.to_string())
      println("  iterations: " + report.iterations.to_string())
      println(
        "  thresholds: hot_ns>=" +
        report.hot_threshold_ns.to_string() +
        " large_bytes>=" +
        report.large_threshold_bytes.to_string(),
      )
      if report.unresolved_exports.length() > 0 {
        println("  unresolved_exports: " + report.unresolved_exports.join(", "))
      }
      print_hotness_unresolved_reason_counts(report.unresolved_reason_counts)
      print_hotness_size_buckets(report.buckets)
      print_hotness_size_entries(report.entries, limit)
    }
    Err(msg) => {
      println("hot-size failed: " + msg)
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
fn format_opt_uint(value : UInt?) -> String {
  match value {
    Some(v) => v.to_string()
    None => "-"
  }
}

///|
fn format_opt_name(value : String?) -> String {
  match value {
    Some(v) => if v.is_empty() { "-" } else { v }
    None => "-"
  }
}

///|
fn print_function_gap_entries(
  entries : Array[@walyze.FunctionGapEntry],
) -> Unit {
  if entries.length() == 0 {
    println("  entries: (none)")
    return
  }
  println("  entries:")
  for entry in entries {
    let left_exports = if entry.left_export_names.length() == 0 {
      "-"
    } else {
      entry.left_export_names.join(",")
    }
    let right_exports = if entry.right_export_names.length() == 0 {
      "-"
    } else {
      entry.right_export_names.join(",")
    }
    println(
      "    kind=" +
      entry.match_kind +
      " key=" +
      entry.match_key +
      " left_idx=" +
      format_opt_uint(entry.left_function_index) +
      " right_idx=" +
      format_opt_uint(entry.right_function_index) +
      " left_name=" +
      format_opt_name(entry.left_name) +
      " right_name=" +
      format_opt_name(entry.right_name) +
      " left_body=" +
      entry.left_body_bytes.to_string() +
      " right_body=" +
      entry.right_body_bytes.to_string() +
      " delta=" +
      entry.left_minus_right_bytes.to_string() +
      " abs_gap=" +
      entry.abs_gap_bytes.to_string() +
      " left_exports=" +
      left_exports +
      " right_exports=" +
      right_exports,
    )
    println(
      "    tsv\t" +
      entry.match_kind +
      "\t" +
      entry.match_key +
      "\t" +
      format_opt_uint(entry.left_function_index) +
      "\t" +
      format_opt_uint(entry.right_function_index) +
      "\t" +
      entry.left_body_bytes.to_string() +
      "\t" +
      entry.right_body_bytes.to_string() +
      "\t" +
      entry.left_minus_right_bytes.to_string() +
      "\t" +
      entry.abs_gap_bytes.to_string() +
      "\t" +
      left_exports +
      "\t" +
      right_exports,
    )
  }
}

///|
fn print_code_block_sizes(
  blocks : Array[@walyze.CodeBlockSize],
  limit : UInt,
) -> Unit {
  let mut printed = 0U
  for block in blocks {
    if printed >= limit {
      break
    }
    let label = match block.function_name {
      Some(name) => name
      None => "#\{block.function_index.to_string()}"
    }
    let exports = if block.export_names.length() == 0 {
      ""
    } else {
      " exports=" + block.export_names.join(",")
    }
    println(
      "    " +
      label +
      " idx=" +
      block.function_index.to_string() +
      " block=" +
      block.block_index.to_string() +
      " kind=" +
      block.kind +
      " depth=" +
      block.depth.to_string() +
      " bytes=" +
      block.total_bytes.to_string() +
      " instrs=" +
      block.instruction_count.to_string() +
      " span=" +
      block.start_offset.to_string() +
      ".." +
      block.end_offset.to_string() +
      exports,
    )
    printed += 1U
  }
}

///|
fn run_block_sizes(path : String, limit : UInt) -> Unit {
  let bytes = read_bytes_or_exit(path)
  match @walyze.analyze_code_block_sizes(bytes) {
    Ok(report) => {
      println("code block size analysis:")
      println("  partial: " + report.partial.to_string())
      println("  function_count: " + report.function_count.to_string())
      println("  block_count: " + report.block_count.to_string())
      println("  total_body_bytes: " + report.total_body_bytes.to_string())
      println(
        "  total_instruction_bytes: " +
        report.total_instruction_bytes.to_string(),
      )
      println("  blocks:")
      print_code_block_sizes(report.blocks, limit)
    }
    Err(e) => {
      println("block-sizes failed: " + @walyze.error_to_string(e))
      @sys.exit(1)
    }
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
fn run_function_gap(
  left_path : String,
  right_path : String,
  limit : UInt,
) -> Unit {
  let left_bytes = read_bytes_or_exit(left_path)
  let right_bytes = read_bytes_or_exit(right_path)
  match
    @walyze.analyze_function_size_gap(left_bytes, right_bytes, top_limit=limit) {
    Ok(report) => {
      println("function-gap:")
      println(
        "  left_total_body_bytes: " + report.left_total_body_bytes.to_string(),
      )
      println(
        "  right_total_body_bytes: " + report.right_total_body_bytes.to_string(),
      )
      println(
        "  left_minus_right_total_bytes: " +
        report.left_minus_right_total_bytes.to_string(),
      )
      println(
        "  unmatched_left_count: " + report.unmatched_left_count.to_string(),
      )
      println(
        "  unmatched_right_count: " + report.unmatched_right_count.to_string(),
      )
      println("  entries_count: " + report.entries.length().to_string())
      println(
        "  tsv_header\tkind\tkey\tleft_idx\tright_idx\tleft_body\tright_body\tdelta\tabs_gap\tleft_exports\tright_exports",
      )
      print_function_gap_entries(report.entries)
    }
    Err(e) => {
      println("function-gap failed: " + @walyze.error_to_string(e))
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
fn print_retain_path_entries(
  entries : Array[@walyze.RetainPathEntry],
  limit : UInt,
) -> Unit {
  if entries.length() == 0 {
    println("  entries: (none)")
    return
  }
  println("  entries:")
  let mut printed = 0U
  for entry in entries {
    if printed >= limit {
      break
    }
    let label = match entry.name {
      Some(v) => v
      None => "#\{entry.function_index.to_string()}"
    }
    let exports = if entry.export_names.length() == 0 {
      ""
    } else {
      " exports=" + entry.export_names.join(",")
    }
    let root_reasons = if entry.root_reasons.length() == 0 {
      "reachable"
    } else {
      entry.root_reasons.join(",")
    }
    let path = if entry.path.length() == 0 {
      "(none)"
    } else {
      entry.path.map(i => i.to_string()).join(" -> ")
    }
    println(
      "    " +
      label +
      " idx=" +
      entry.function_index.to_string() +
      " body=" +
      entry.body_bytes.to_string() +
      exports +
      " root=" +
      root_reasons +
      " path=" +
      path,
    )
    printed += 1U
  }
}

///|
fn run_retain_path(args : Array[String]) -> Unit {
  if args.length() < 3 {
    print_usage()
    @sys.exit(1)
  }
  let path = args[2]
  let bytes = read_bytes_or_exit(path)
  let mut limit = 20U
  let mut closed_world = false
  let mut safe_mode = false
  for i in 3..<args.length() {
    let arg = args[i]
    if arg == "--closed-world" {
      closed_world = true
    } else if arg == "--safe-mode" {
      safe_mode = true
    } else if arg.has_prefix("--closed-world-root=") {
      ()
    } else if arg.has_prefix("--") {
      println("unknown retain-path option: " + arg)
      @sys.exit(1)
    } else {
      limit = parse_uint_or_exit(arg, "limit")
    }
  }
  let closed_world_root_exports = parse_closed_world_roots(args, 3)
  let config = @walyze.make_optimize_config(
    closed_world~,
    closed_world_root_exports~,
    safe_mode~,
  )
  match @walyze.analyze_retain_paths(bytes, config~) {
    Ok(report) => {
      println("retain-path analysis:")
      println("  partial: " + report.partial.to_string())
      if report.roots.length() == 0 {
        println("  roots: (none)")
      } else {
        println("  roots: " + report.roots.map(i => i.to_string()).join(", "))
      }
      print_retain_path_entries(report.entries, limit)
    }
    Err(e) => {
      println("retain-path failed: " + @walyze.error_to_string(e))
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
fn run_component_dce_kpi(args : Array[String]) -> Unit {
  if args.length() < 3 {
    print_usage()
    @sys.exit(1)
  }
  let component_path = args[2]
  let bytes = read_bytes_or_exit(component_path)
  let excludes = parse_excluded_roots(args, 3)
  let mut wit_path : String? = None
  let mut safe_mode = false
  let mut verbose = false
  for i in 3..<args.length() {
    if args[i] == "--safe-mode" {
      safe_mode = true
    } else if args[i] == "--verbose" {
      verbose = true
    } else if not(args[i].has_prefix("--")) && wit_path is None {
      wit_path = Some(args[i])
    }
  }
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
  let policy = match
    @walyze.analyze_component_root_policy(
      bytes,
      resolved_wit~,
      exclude=excludes,
    ) {
    Ok(v) => v
    Err(msg) => {
      println("component-dce-kpi root policy failed: " + msg)
      @sys.exit(1)
      return
    }
  }
  let roots = policy.root_name_candidates.copy()
  roots.append(parse_closed_world_roots(args, 3)[:])
  roots.sort()
  roots.dedup()
  let config = @walyze.make_optimize_config(
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
    safe_mode~,
  )
  match @walyze.analyze_component_core_optimize(bytes, config~) {
    Ok(report) => {
      println("component dce kpi:")
      println(
        "  total_component_bytes: " + report.total_component_bytes.to_string(),
      )
      println("  core_module_count: " + report.core_module_count.to_string())
      println(
        "  total_core_before_bytes: " +
        report.total_core_before_bytes.to_string(),
      )
      println(
        "  total_core_after_bytes: " + report.total_core_after_bytes.to_string(),
      )
      println("  root_count: " + roots.length().to_string())
      println("  exclude_count: " + excludes.length().to_string())
      for entry in report.entries {
        println(
          "  core module #" +
          entry.module_index.to_string() +
          " " +
          entry.before_bytes.to_string() +
          " -> " +
          entry.after_bytes.to_string() +
          " bytes",
        )
        if verbose && entry.no_change_reasons.length() > 0 {
          println(
            "    no-change reasons: " + entry.no_change_reasons.join(", "),
          )
        }
      }
      println(
        "kpi-total-component-bytes=" + report.total_component_bytes.to_string(),
      )
      println(
        "kpi-total-core-before-bytes=" +
        report.total_core_before_bytes.to_string(),
      )
      println(
        "kpi-total-core-after-bytes=" +
        report.total_core_after_bytes.to_string(),
      )
      println("kpi-core-module-count=" + report.core_module_count.to_string())
      println("kpi-root-count=" + roots.length().to_string())
      println("kpi-exclude-count=" + excludes.length().to_string())
    }
    Err(msg) => {
      println("component-dce-kpi failed: " + msg)
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
fn run_root_policy(args : Array[String]) -> Unit {
  if args.length() < 3 {
    print_usage()
    @sys.exit(1)
  }
  let component_path = args[2]
  let bytes = read_bytes_or_exit(component_path)
  let excludes = parse_excluded_roots(args, 3)
  let mut wit_path : String? = None
  for i in 3..<args.length() {
    if not(args[i].has_prefix("--")) && wit_path is None {
      wit_path = Some(args[i])
    }
  }
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
  match
    @walyze.analyze_component_root_policy(
      bytes,
      resolved_wit~,
      exclude=excludes,
    ) {
    Ok(policy) => {
      println("component imports: " + policy.component_imports.join(", "))
      println("component exports: " + policy.component_exports.join(", "))
      println("wit imports: " + policy.wit_imports.join(", "))
      println("wit exports: " + policy.wit_exports.join(", "))
      println("canonical abi roots: " + policy.canonical_abi_roots.join(", "))
      println("dce excludes: " + excludes.join(", "))
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
    "analyze-host" => {
      if args.length() < 3 {
        print_usage()
        @sys.exit(1)
      }
      let limit = if args.length() >= 4 {
        parse_uint_or_exit(args[3], "limit")
      } else {
        20U
      }
      run_analyze_host(args[2], limit)
    }
    "analyze-opt" => {
      if args.length() < 3 {
        print_usage()
        @sys.exit(1)
      }
      let mut config = @walyze.OptimizeConfig::o1()
      let mut diff_limit = 20U
      if args.length() >= 4 {
        match @walyze.optimize_config_from_opt_level(args[3]) {
          Some(v) => {
            config = v
            if args.length() >= 5 {
              diff_limit = parse_uint_or_exit(args[4], "diff-limit")
            }
          }
          None => diff_limit = parse_uint_or_exit(args[3], "diff-limit")
        }
      }
      run_analyze_opt(args[2], config, diff_limit)
    }
    "deep-analyze" => {
      if args.length() < 3 {
        print_usage()
        @sys.exit(1)
      }
      let limit = if args.length() >= 4 {
        parse_uint_or_exit(args[3], "limit")
      } else {
        20U
      }
      run_deep_analyze(args[2], limit)
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
    "function-gap" => {
      if args.length() < 4 {
        print_usage()
        @sys.exit(1)
      }
      let limit = if args.length() >= 5 {
        parse_uint_or_exit(args[4], "limit")
      } else {
        20U
      }
      run_function_gap(args[2], args[3], limit)
    }
    "block-sizes" => {
      if args.length() < 3 {
        print_usage()
        @sys.exit(1)
      }
      let limit = if args.length() >= 4 {
        parse_uint_or_exit(args[3], "limit")
      } else {
        20U
      }
      run_block_sizes(args[2], limit)
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
    "retain-path" => run_retain_path(args)
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
    "hot-size" => {
      if args.length() < 3 {
        print_usage()
        @sys.exit(1)
      }
      let iterations = if args.length() >= 4 {
        parse_uint_or_exit(args[3], "iterations")
      } else {
        50U
      }
      let limit = if args.length() >= 5 {
        parse_uint_or_exit(args[4], "limit")
      } else {
        20U
      }
      run_hot_size(args[2], iterations, limit)
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
    "component-dce-kpi" => run_component_dce_kpi(args)
    "contract" => {
      if args.length() < 4 {
        print_usage()
        @sys.exit(1)
      }
      run_contract(args[2], args[3])
    }
    "root-policy" => run_root_policy(args)
    _ => {
      print_usage()
      @sys.exit(1)
    }
  }
}
