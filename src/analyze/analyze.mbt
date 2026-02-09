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
pub fn print_section_sizes(sections : Array[@wite.SectionSize]) -> Unit {
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
  sections : Array[@wite.SectionSize],
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
  sections : Array[@wite.CustomSectionBreakdown],
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
  stats : Array[@wite.OpcodeStat],
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
fn print_call_graph_summary(summary : @wite.CallGraphSummary) -> Unit {
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
  hints : Array[@wite.HostCodeHint],
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
pub fn run_analyze_host(path : String, limit : UInt) -> Unit {
  let bytes = read_bytes_or_exit(path)
  match @wite.analyze_host_generated_code(bytes) {
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
pub fn run_analyze_opt(
  path : String,
  config : @wite.OptimizeConfig,
  function_diff_limit : UInt,
) -> Unit {
  let bytes = read_bytes_or_exit(path)
  match @wite.analyze_optimize_metadata(bytes, config~, function_diff_limit~) {
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
  match @wite.analyze_section_sizes(bytes) {
    Ok(sections) => {
      println("section size analysis:")
      print_section_sizes_with_share(
        sections,
        bytes.length().reinterpret_as_uint(),
      )
      match @wite.analyze_call_graph_summary(bytes) {
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
  match @wite.analyze_wasm_breakdown(bytes, top_limit=limit) {
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
pub fn run_profile(path : String) -> Unit {
  let bytes = read_bytes_or_exit(path)
  match @wite.profile_module(bytes) {
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
pub fn run_dce_report(path : String, limit : UInt) -> Unit {
  let bytes = read_bytes_or_exit(path)
  match @wite.analyze_dce_report(bytes) {
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
      println("dce-report failed: " + @wite.error_to_string(e))
      @sys.exit(1)
    }
  }
}

///|
pub fn run_runtime_profile(
  path : String,
  iterations : UInt,
  scenarios : Array[@wite.RuntimeProfileScenario],
) -> Unit {
  let bytes = read_bytes_or_exit(path)
  match @wite.profile_runtime_exports(bytes, iterations~, scenarios~) {
    Ok(profile) => {
      println("runtime profile:")
      println("  instantiate_ns: " + profile.instantiate_ns.to_string())
      println("  iterations: " + profile.iterations.to_string())
      if scenarios.length() > 0 {
        println("  scenarios: " + scenarios.length().to_string())
      }
      if profile.functions.length() == 0 {
        if scenarios.length() > 0 {
          println("  functions: (no runnable scenarios)")
        } else {
          println("  functions: (no zero-arg exports)")
        }
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
  entries : Array[@wite.HotnessSizeEntry],
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
fn print_hotness_size_buckets(buckets : Array[@wite.HotnessSizeBucket]) -> Unit {
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
  counts : Array[@wite.HotnessUnresolvedReasonCount],
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
pub fn run_hot_size(
  path : String,
  iterations : UInt,
  limit : UInt,
  scenarios : Array[@wite.RuntimeProfileScenario],
) -> Unit {
  let bytes = read_bytes_or_exit(path)
  match @wite.analyze_hotness_size_matrix(bytes, iterations~, scenarios~) {
    Ok(report) => {
      println("hot-size matrix:")
      println("  instantiate_ns: " + report.instantiate_ns.to_string())
      println("  iterations: " + report.iterations.to_string())
      if scenarios.length() > 0 {
        println("  scenarios: " + scenarios.length().to_string())
      }
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
pub fn print_function_sizes(
  functions : Array[@wite.FunctionSize],
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
fn print_function_gap_entries(entries : Array[@wite.FunctionGapEntry]) -> Unit {
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
  blocks : Array[@wite.CodeBlockSize],
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
pub fn run_block_sizes(path : String, limit : UInt) -> Unit {
  let bytes = read_bytes_or_exit(path)
  match @wite.analyze_code_block_sizes(bytes) {
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
      println("block-sizes failed: " + @wite.error_to_string(e))
      @sys.exit(1)
    }
  }
}

///|
pub fn run_top_functions(path : String, limit : UInt) -> Unit {
  let bytes = read_bytes_or_exit(path)
  match @wite.analyze_function_sizes(bytes) {
    Ok(functions) => {
      println("top functions:")
      println("  count: " + functions.length().to_string())
      print_function_sizes(functions, limit)
    }
    Err(e) => {
      println("top-functions failed: " + @wite.error_to_string(e))
      @sys.exit(1)
    }
  }
}

///|
pub fn run_function_gap(
  left_path : String,
  right_path : String,
  limit : UInt,
) -> Unit {
  let left_bytes = read_bytes_or_exit(left_path)
  let right_bytes = read_bytes_or_exit(right_path)
  match
    @wite.analyze_function_size_gap(left_bytes, right_bytes, top_limit=limit) {
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
      println("function-gap failed: " + @wite.error_to_string(e))
      @sys.exit(1)
    }
  }
}

///|
fn format_signed_int(value : Int) -> String {
  if value > 0 {
    "+" + value.to_string()
  } else {
    value.to_string()
  }
}

///|
fn abs_int_to_uint(value : Int) -> UInt {
  if value < 0 {
    (-value).reinterpret_as_uint()
  } else {
    value.reinterpret_as_uint()
  }
}

///|
fn diff_uint(left : UInt, right : UInt) -> Int {
  if left >= right {
    (left - right).reinterpret_as_int()
  } else {
    -(right - left).reinterpret_as_int()
  }
}

///|
priv struct SectionGapEntry {
  key : String
  left_bytes : UInt
  right_bytes : UInt
  delta_bytes : Int
  abs_gap_bytes : UInt
}

///|
fn compare_section_gap_entry(a : SectionGapEntry, b : SectionGapEntry) -> Int {
  if a.abs_gap_bytes > b.abs_gap_bytes {
    -1
  } else if a.abs_gap_bytes < b.abs_gap_bytes {
    1
  } else {
    a.key.compare(b.key)
  }
}

///|
fn collect_section_gap_entries(
  left_sections : Array[@wite.SectionSize],
  right_sections : Array[@wite.SectionSize],
) -> Array[SectionGapEntry] {
  let left_map : Map[String, UInt] = {}
  for section in left_sections {
    left_map.set(section.key, section.total_bytes)
  }
  let right_map : Map[String, UInt] = {}
  for section in right_sections {
    right_map.set(section.key, section.total_bytes)
  }
  let seen : Map[String, Bool] = {}
  let entries : Array[SectionGapEntry] = []
  let add_entry = fn(key : String) {
    if seen.contains(key) {
      return
    }
    seen.set(key, true)
    let left_bytes = match left_map.get(key) {
      Some(v) => v
      None => 0U
    }
    let right_bytes = match right_map.get(key) {
      Some(v) => v
      None => 0U
    }
    let delta_bytes = diff_uint(left_bytes, right_bytes)
    entries.push({
      key,
      left_bytes,
      right_bytes,
      delta_bytes,
      abs_gap_bytes: abs_int_to_uint(delta_bytes),
    })
  }
  left_map.each((key, _) => add_entry(key))
  right_map.each((key, _) => add_entry(key))
  entries.sort_by(compare_section_gap_entry)
  entries
}

///|
pub fn run_section_gap(
  left_path : String,
  right_path : String,
  limit : UInt,
) -> Unit {
  let left_bytes = read_bytes_or_exit(left_path)
  let right_bytes = read_bytes_or_exit(right_path)
  let left_sections = match @wite.analyze_section_sizes(left_bytes) {
    Ok(v) => v
    Err(e) => {
      println("section diff failed (left): " + @wite.error_to_string(e))
      @sys.exit(1)
      []
    }
  }
  let right_sections = match @wite.analyze_section_sizes(right_bytes) {
    Ok(v) => v
    Err(e) => {
      println("section diff failed (right): " + @wite.error_to_string(e))
      @sys.exit(1)
      []
    }
  }
  let entries = collect_section_gap_entries(left_sections, right_sections)
  println("section-gap:")
  println("  left_total_bytes: " + left_bytes.length().to_string())
  println("  right_total_bytes: " + right_bytes.length().to_string())
  println(
    "  left_minus_right_total_bytes: " +
    diff_uint(
      left_bytes.length().reinterpret_as_uint(),
      right_bytes.length().reinterpret_as_uint(),
    ).to_string(),
  )
  println("  entries_count: " + entries.length().to_string())
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
    println(
      "    " +
      entry.key +
      " left=" +
      entry.left_bytes.to_string() +
      " right=" +
      entry.right_bytes.to_string() +
      " delta=" +
      format_signed_int(entry.delta_bytes) +
      " abs_gap=" +
      entry.abs_gap_bytes.to_string(),
    )
    printed += 1U
  }
}

///|
priv struct BlockGapEntry {
  key : String
  function_index : UInt
  function_name : String?
  kind : String
  depth : UInt
  left_bytes : UInt
  right_bytes : UInt
  delta_bytes : Int
  abs_gap_bytes : UInt
}

///|
fn compare_block_gap_entry(a : BlockGapEntry, b : BlockGapEntry) -> Int {
  if a.abs_gap_bytes > b.abs_gap_bytes {
    -1
  } else if a.abs_gap_bytes < b.abs_gap_bytes {
    1
  } else {
    a.key.compare(b.key)
  }
}

///|
fn block_gap_key(block : @wite.CodeBlockSize) -> String {
  block.function_index.to_string() +
  ":" +
  block.block_index.to_string() +
  ":" +
  block.kind +
  ":" +
  block.depth.to_string()
}

///|
fn collect_block_gap_entries(
  left_blocks : Array[@wite.CodeBlockSize],
  right_blocks : Array[@wite.CodeBlockSize],
) -> Array[BlockGapEntry] {
  let left_map : Map[String, @wite.CodeBlockSize] = {}
  for block in left_blocks {
    left_map.set(block_gap_key(block), block)
  }
  let right_map : Map[String, @wite.CodeBlockSize] = {}
  for block in right_blocks {
    right_map.set(block_gap_key(block), block)
  }
  let seen : Map[String, Bool] = {}
  let entries : Array[BlockGapEntry] = []
  let add_entry = fn(key : String) {
    if seen.contains(key) {
      return
    }
    seen.set(key, true)
    let left_block = left_map.get(key)
    let right_block = right_map.get(key)
    let left_bytes = match left_block {
      Some(v) => v.total_bytes
      None => 0U
    }
    let right_bytes = match right_block {
      Some(v) => v.total_bytes
      None => 0U
    }
    let delta_bytes = diff_uint(left_bytes, right_bytes)
    let reference = match left_block {
      Some(v) => v
      None =>
        match right_block {
          Some(v) => v
          None => return
        }
    }
    entries.push({
      key,
      function_index: reference.function_index,
      function_name: reference.function_name,
      kind: reference.kind,
      depth: reference.depth,
      left_bytes,
      right_bytes,
      delta_bytes,
      abs_gap_bytes: abs_int_to_uint(delta_bytes),
    })
  }
  left_map.each((key, _) => add_entry(key))
  right_map.each((key, _) => add_entry(key))
  entries.sort_by(compare_block_gap_entry)
  entries
}

///|
pub fn run_block_gap(
  left_path : String,
  right_path : String,
  limit : UInt,
) -> Unit {
  let left_bytes = read_bytes_or_exit(left_path)
  let right_bytes = read_bytes_or_exit(right_path)
  let left_report = match @wite.analyze_code_block_sizes(left_bytes) {
    Ok(v) => v
    Err(e) => {
      println("block diff failed (left): " + @wite.error_to_string(e))
      @sys.exit(1)
      panic()
    }
  }
  let right_report = match @wite.analyze_code_block_sizes(right_bytes) {
    Ok(v) => v
    Err(e) => {
      println("block diff failed (right): " + @wite.error_to_string(e))
      @sys.exit(1)
      panic()
    }
  }
  let entries = collect_block_gap_entries(
    left_report.blocks,
    right_report.blocks,
  )
  println("block-gap:")
  println(
    "  left_total_instruction_bytes: " +
    left_report.total_instruction_bytes.to_string(),
  )
  println(
    "  right_total_instruction_bytes: " +
    right_report.total_instruction_bytes.to_string(),
  )
  println(
    "  left_minus_right_total_instruction_bytes: " +
    diff_uint(
      left_report.total_instruction_bytes,
      right_report.total_instruction_bytes,
    ).to_string(),
  )
  println("  entries_count: " + entries.length().to_string())
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
    let label = match entry.function_name {
      Some(v) => v
      None => "#\{entry.function_index.to_string()}"
    }
    println(
      "    " +
      label +
      " key=" +
      entry.key +
      " kind=" +
      entry.kind +
      " depth=" +
      entry.depth.to_string() +
      " left=" +
      entry.left_bytes.to_string() +
      " right=" +
      entry.right_bytes.to_string() +
      " delta=" +
      format_signed_int(entry.delta_bytes) +
      " abs_gap=" +
      entry.abs_gap_bytes.to_string(),
    )
    printed += 1U
  }
}

///|
pub fn print_call_graph_nodes(
  nodes : Array[@wite.CallGraphNode],
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
pub fn run_callgraph(path : String, limit : UInt) -> Unit {
  let bytes = read_bytes_or_exit(path)
  match @wite.analyze_call_graph(bytes) {
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
      println("callgraph failed: " + @wite.error_to_string(e))
      @sys.exit(1)
    }
  }
}

///|
pub fn run_keep_reasons_with_options(
  path : String,
  closed_world : Bool,
  safe_mode : Bool,
  closed_world_root_exports : Array[String],
) -> Unit {
  let bytes = read_bytes_or_exit(path)
  let config = @wite.make_optimize_config(
    closed_world~,
    closed_world_root_exports~,
    safe_mode~,
  )
  match @wite.analyze_keep_reasons(bytes, config~) {
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
      println("keep-reasons failed: " + @wite.error_to_string(e))
      @sys.exit(1)
    }
  }
}

///|
fn print_retain_path_entries(
  entries : Array[@wite.RetainPathEntry],
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
pub fn run_retain_path_with_options(
  path : String,
  limit : UInt,
  closed_world : Bool,
  safe_mode : Bool,
  closed_world_root_exports : Array[String],
) -> Unit {
  let bytes = read_bytes_or_exit(path)
  let config = @wite.make_optimize_config(
    closed_world~,
    closed_world_root_exports~,
    safe_mode~,
  )
  match @wite.analyze_retain_paths(bytes, config~) {
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
      println("retain-path failed: " + @wite.error_to_string(e))
      @sys.exit(1)
    }
  }
}
