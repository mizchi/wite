///|
pub fn run_analyze_host(path : String, limit : UInt) -> Unit {
  let bytes = read_bytes_or_exit(path)
  match analyze_host_generated_code(bytes) {
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
  match analyze_optimize_metadata(bytes, config~, function_diff_limit~) {
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
