///|
pub fn run_analyze(path : String) -> Unit {
  let bytes = read_bytes_or_exit(path)
  match analyze_section_sizes(bytes) {
    Ok(sections) => {
      println("section size analysis:")
      print_section_sizes_with_share(
        sections,
        bytes.length().reinterpret_as_uint(),
      )
      match analyze_call_graph_summary(bytes) {
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
  match analyze_wasm_breakdown(bytes, top_limit=limit) {
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
  match profile_module(bytes) {
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
  match analyze_dce_report(bytes) {
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
