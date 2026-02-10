///|
fn make_optimize_stage_config(
  base : OptimizeConfig,
  strip_only : Bool,
  include_dce_group : Bool,
  include_rume : Bool,
) -> OptimizeConfig {
  let pass_rounds = if strip_only {
    1U
  } else if base.pass_rounds == 0U {
    1U
  } else {
    base.pass_rounds
  }
  make_optimize_config(
    strip_all_custom=base.strip_all_custom,
    strip_name_section=base.strip_name_section,
    strip_producers_section=base.strip_producers_section,
    strip_debug_sections=base.strip_debug_sections,
    strip_dwarf_sections=base.strip_dwarf_sections,
    strip_target_features_section=base.strip_target_features_section,
    keep_custom_sections=base.keep_custom_sections,
    pass_rounds~,
    enable_peephole=if strip_only { false } else { base.enable_peephole },
    peephole_remove_nop=if strip_only {
      false
    } else {
      base.peephole_remove_nop
    },
    peephole_remove_const_drop=if strip_only {
      false
    } else {
      base.peephole_remove_const_drop
    },
    enable_vacuum=if strip_only { false } else { base.enable_vacuum },
    enable_merge_blocks=if strip_only {
      false
    } else {
      base.enable_merge_blocks
    },
    enable_remove_unused_brs=if strip_only {
      false
    } else {
      base.enable_remove_unused_brs
    },
    enable_dce=if include_dce_group { base.enable_dce } else { false },
    enable_dfe=if include_dce_group { base.enable_dfe } else { false },
    enable_merge_similar_functions=if include_dce_group {
      base.enable_merge_similar_functions
    } else {
      false
    },
    enable_remove_unused_module_elements=if include_rume {
      base.enable_remove_unused_module_elements
    } else {
      false
    },
    closed_world=base.closed_world,
    closed_world_root_exports=base.closed_world_root_exports,
    safe_mode=base.safe_mode,
  )
}

///|
fn compare_function_size_diff(
  a : FunctionSizeDiff,
  b : FunctionSizeDiff,
) -> Int {
  if a.gain_bytes > b.gain_bytes {
    -1
  } else if a.gain_bytes < b.gain_bytes {
    1
  } else if a.regression_bytes > b.regression_bytes {
    -1
  } else if a.regression_bytes < b.regression_bytes {
    1
  } else if a.before_body_bytes > b.before_body_bytes {
    -1
  } else if a.before_body_bytes < b.before_body_bytes {
    1
  } else if a.function_index < b.function_index {
    -1
  } else if a.function_index > b.function_index {
    1
  } else {
    0
  }
}

///|
fn map_function_sizes_by_index(
  functions : Array[FunctionSize],
) -> Map[UInt, FunctionSize] {
  let out : Map[UInt, FunctionSize] = {}
  for function in functions {
    out.set(function.function_index, function)
  }
  out
}

///|
fn collect_function_size_diff_indices(
  before_map : Map[UInt, FunctionSize],
  after_map : Map[UInt, FunctionSize],
) -> Array[UInt] {
  let out : Array[UInt] = []
  let seen : Map[UInt, Bool] = {}
  before_map.each((function_index, _) => {
    seen.set(function_index, true)
    out.push(function_index)
  })
  after_map.each((function_index, _) => if seen.get(function_index) is None {
    seen.set(function_index, true)
    out.push(function_index)
  })
  out
}

///|
fn merged_export_names_for_function_diff(
  before : FunctionSize?,
  after : FunctionSize?,
) -> Array[String] {
  let names : Array[String] = []
  match before {
    Some(v) => names.append(v.export_names[:])
    None => ()
  }
  match after {
    Some(v) =>
      for name in v.export_names {
        if not(names.contains(name)) {
          names.push(name)
        }
      }
    None => ()
  }
  names
}

///|
fn collect_function_size_diffs_raise(
  before_bytes : Bytes,
  after_bytes : Bytes,
  limit : UInt,
) -> (UInt, UInt, Array[FunctionSizeDiff]) raise WiteError {
  let before_functions = match analyze_function_sizes(before_bytes) {
    Ok(v) => v
    Err(e) => raise e
  }
  let after_functions = match analyze_function_sizes(after_bytes) {
    Ok(v) => v
    Err(e) => raise e
  }
  let before_by_index = map_function_sizes_by_index(before_functions)
  let after_by_index = map_function_sizes_by_index(after_functions)
  let indices = collect_function_size_diff_indices(
    before_by_index, after_by_index,
  )
  let mut total_gain = 0U
  let mut total_regression = 0U
  let diffs : Array[FunctionSizeDiff] = []
  for function_index in indices {
    let before_function = before_by_index.get(function_index)
    let after_function = after_by_index.get(function_index)
    let before_body_bytes = match before_function {
      Some(v) => v.body_bytes
      None => 0U
    }
    let after_body_bytes = match after_function {
      Some(v) => v.body_bytes
      None => 0U
    }
    let gain_bytes = size_gain_bytes(before_body_bytes, after_body_bytes)
    let regression_bytes = size_regression_bytes(
      before_body_bytes, after_body_bytes,
    )
    total_gain += gain_bytes
    total_regression += regression_bytes
    if gain_bytes > 0U || regression_bytes > 0U {
      diffs.push({
        function_index,
        before_body_bytes,
        after_body_bytes,
        gain_bytes,
        regression_bytes,
        before_name: match before_function {
          Some(v) => v.name
          None => None
        },
        after_name: match after_function {
          Some(v) => v.name
          None => None
        },
        export_names: merged_export_names_for_function_diff(
          before_function, after_function,
        ),
      })
    }
  }
  diffs.sort_by(compare_function_size_diff)
  let top_diffs : Array[FunctionSizeDiff] = []
  let mut count = 0U
  for diff in diffs {
    if limit > 0U && count >= limit {
      break
    }
    top_diffs.push(diff)
    count += 1U
  }
  (total_gain, total_regression, top_diffs)
}

///|
priv struct OptimizeStageRunResult {
  bytes : Bytes
  stage : OptimizeStageMetadata
}

///|
fn run_optimize_stage_raise(
  stage_name : String,
  bytes : Bytes,
  config : OptimizeConfig,
  function_diff_limit : UInt,
) -> OptimizeStageRunResult raise WiteError {
  let optimized = match optimize_for_size(bytes, config~) {
    Ok(v) => v
    Err(err) => raise err
  }
  let (function_gain_bytes, function_regression_bytes, function_diffs) = collect_function_size_diffs_raise(
    bytes,
    optimized.bytes,
    function_diff_limit,
  )
  let stage : OptimizeStageMetadata = {
    stage: stage_name,
    before_size: optimized.before_size,
    after_size: optimized.after_size,
    gain_bytes: size_gain_bytes(optimized.before_size, optimized.after_size),
    regression_bytes: size_regression_bytes(
      optimized.before_size,
      optimized.after_size,
    ),
    function_gain_bytes,
    function_regression_bytes,
    function_diffs,
    removed_sections: optimized.removed_sections,
    no_change_reasons: optimized.no_change_reasons,
  }
  { bytes: optimized.bytes, stage }
}

///|
pub fn analyze_optimize_metadata(
  bytes : Bytes,
  config? : OptimizeConfig = OptimizeConfig::o1(),
  function_diff_limit? : UInt = 20U,
) -> Result[OptimizeMetadataReport, WiteError] {
  try? {
    let strip_stage = run_optimize_stage_raise(
      "strip",
      bytes,
      make_optimize_stage_config(config, true, false, false),
      function_diff_limit,
    )
    let code_stage = run_optimize_stage_raise(
      "code",
      strip_stage.bytes,
      make_optimize_stage_config(config, false, false, false),
      function_diff_limit,
    )
    let dce_stage = run_optimize_stage_raise(
      "dce",
      code_stage.bytes,
      make_optimize_stage_config(config, false, true, false),
      function_diff_limit,
    )
    let rume_stage = run_optimize_stage_raise(
      "rume",
      dce_stage.bytes,
      make_optimize_stage_config(config, false, true, true),
      function_diff_limit,
    )
    let before_size = bytes.length().reinterpret_as_uint()
    let after_size = rume_stage.bytes.length().reinterpret_as_uint()
    {
      before_size,
      after_size,
      total_gain_bytes: size_gain_bytes(before_size, after_size),
      total_regression_bytes: size_regression_bytes(before_size, after_size),
      stages: [
        strip_stage.stage,
        code_stage.stage,
        dce_stage.stage,
        rume_stage.stage,
      ],
    }
  }
}
