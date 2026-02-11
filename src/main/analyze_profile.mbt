///|
pub fn run_analyze_host(path : String, limit : UInt) -> Unit {
  let bytes = read_bytes_or_exit(path)
  match @wite_analyze.analyze_host_generated_code(bytes) {
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
      println("analyze-host failed: " + @wite.error_to_string(e))
      @sys.exit(1)
    }
  }
}

///|
fn print_optimize_metadata_stage(stage : @wite.OptimizeStageMetadata) -> Unit {
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
      let exports = match diff.export_names {
        [] => ""
        [_, ..] => " exports=" + diff.export_names.join(",")
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
pub fn run_analyze_opt(
  path : String,
  config : @wite.OptimizeConfig,
  function_diff_limit : UInt,
) -> Unit {
  let bytes = read_bytes_or_exit(path)
  match
    @wite_analyze.analyze_optimize_metadata(
      bytes,
      config~,
      function_diff_limit~,
    ) {
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
      println("analyze-opt failed: " + @wite.error_to_string(e))
      @sys.exit(1)
    }
  }
}

///|
pub fn run_analyze(path : String) -> Unit {
  let bytes = read_bytes_or_exit(path)
  match @wite_analyze.analyze_section_sizes(bytes) {
    Ok(sections) => {
      println("section size analysis:")
      print_section_sizes_with_share(
        sections,
        bytes.length().reinterpret_as_uint(),
      )
      match @wite_analyze.analyze_call_graph_summary(bytes) {
        Ok(summary) => print_call_graph_summary(summary)
        Err(e) => {
          println("analyze failed: " + @wite.error_to_string(e))
          @sys.exit(1)
        }
      }
    }
    Err(e) => {
      println("analyze failed: " + @wite.error_to_string(e))
      @sys.exit(1)
    }
  }
}

///|
pub fn run_deep_analyze(path : String, limit : UInt) -> Unit {
  let bytes = read_bytes_or_exit(path)
  match @wite_analyze.analyze_wasm_breakdown(bytes, top_limit=limit) {
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
      println("deep-analyze failed: " + @wite.error_to_string(e))
      @sys.exit(1)
    }
  }
}

///|
fn run_profile(path : String) -> Unit {
  let bytes = read_bytes_or_exit(path)
  match @wite_analyze.profile_module(bytes) {
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
      println("profile failed: " + @wite.error_to_string(e))
      @sys.exit(1)
    }
  }
}

///|
fn run_profile_with_kind(path : String, kind : BinaryKind) -> Unit {
  match kind {
    BinaryKind::Auto | BinaryKind::Core => run_profile(path)
    BinaryKind::Component => @wite_component.run_component_profile(path)
  }
}

///|
async fn run_profile_command(args : Array[String]) -> Unit {
  if args.length() < 3 {
    print_analyze_usage()
    @sys.exit(1)
  }
  let path = args[2]
  let raw_flags : Array[String] = []
  for i in 3..<args.length() {
    raw_flags.push(args[i])
  }
  let config_selection = @wite_config.parse_config_selection_flags(raw_flags)
  auto_sync_deps_from_config_if_needed(config_selection)
  let config_file = @wite_config.resolve_wite_config_or_default(
    config_selection,
  )
  let merged_flags = @wite_config.merge_command_flags(
    config_file.profile_flags,
    config_selection.remaining_flags,
  )
  let mut kind = from_config_binary_kind(config_file.profile_kind)
  let mut i = 0
  while i < merged_flags.length() {
    let arg = merged_flags[i]
    if arg == "--kind" {
      if i + 1 >= merged_flags.length() {
        println("missing value after --kind")
        @sys.exit(1)
      }
      kind = parse_binary_kind_or_exit(merged_flags[i + 1], "profile kind")
      i += 2
      continue
    }
    if arg.strip_prefix("--kind=") is Some(value) {
      kind = parse_binary_kind_or_exit(value.to_string(), "profile kind")
      i += 1
      continue
    }
    println("unknown profile option: " + arg)
    @sys.exit(1)
  }
  run_profile_with_kind(path, kind)
}
