///|
pub fn make_component_optimize_config(
  base? : OptimizeConfig = OptimizeConfig::default(),
  root_name_candidates? : Array[String] = [],
  exclude? : Array[String] = [],
) -> OptimizeConfig {
  @wite_optimize.make_component_optimize_config(
    base~,
    root_name_candidates~,
    exclude~,
  )
}

///|
fn world_keys(xs : Map[String, @wit.RWorldItem]) -> Array[String] {
  let out : Array[String] = []
  xs.each((key, _) => out.push(key))
  out
}

///|
pub fn profile_component(bytes : Bytes) -> Result[ComponentProfile, String] {
  let sections_result = try? parse_component_sections_raise(bytes)
  let sections = match sections_result {
    Ok(v) => v
    Err(e) =>
      return Err("component section parse failed: " + error_to_string(e))
  }
  let detail = match @mwac_component.parse_component_detail(bytes) {
    Ok(v) => v
    Err(e) => return Err("component detail parse failed: " + e.to_string())
  }
  let core_modules : Array[ModuleProfile] = []
  for i in 0..<detail.core_modules.length() {
    let core_bytes = detail.core_modules[i]
    match profile_module(core_bytes) {
      Ok(profile) => core_modules.push(profile)
      Err(e) =>
        return Err(
          "core module profile failed at index " +
          i.to_string() +
          ": " +
          error_to_string(e),
        )
    }
  }
  Ok({
    total_bytes: bytes.length().reinterpret_as_uint(),
    import_count: detail.imports.length().reinterpret_as_uint(),
    export_count: detail.exports.length().reinterpret_as_uint(),
    core_module_count: detail.core_modules.length().reinterpret_as_uint(),
    nested_component_count: detail.components.length().reinterpret_as_uint(),
    sections: summarize_sections(sections, true),
    core_modules,
  })
}

///|
pub fn analyze_component_function_sizes(
  bytes : Bytes,
) -> Result[Array[ComponentFunctionSizeReport], String] {
  let detail = match @mwac_component.parse_component_detail(bytes) {
    Ok(v) => v
    Err(e) => return Err("component detail parse failed: " + e.to_string())
  }
  let reports : Array[ComponentFunctionSizeReport] = []
  for i in 0..<detail.core_modules.length() {
    let core_bytes = detail.core_modules[i]
    let functions = match analyze_function_sizes(core_bytes) {
      Ok(v) => v
      Err(e) =>
        return Err(
          "core module function-size analysis failed at index " +
          i.to_string() +
          ": " +
          error_to_string(e),
        )
    }
    let mut total_body_bytes = 0U
    for fn_size in functions {
      total_body_bytes += fn_size.body_bytes
    }
    reports.push({
      module_index: i.reinterpret_as_uint(),
      function_count: functions.length().reinterpret_as_uint(),
      total_body_bytes,
      functions,
    })
  }
  Ok(reports)
}

///|
pub fn analyze_component_call_graphs(
  bytes : Bytes,
) -> Result[Array[ComponentCallGraphReport], String] {
  let detail = match @mwac_component.parse_component_detail(bytes) {
    Ok(v) => v
    Err(e) => return Err("component detail parse failed: " + e.to_string())
  }
  let reports : Array[ComponentCallGraphReport] = []
  for i in 0..<detail.core_modules.length() {
    let core_bytes = detail.core_modules[i]
    let graph = match analyze_call_graph(core_bytes) {
      Ok(v) => v
      Err(e) =>
        return Err(
          "core module call graph failed at index " +
          i.to_string() +
          ": " +
          error_to_string(e),
        )
    }
    reports.push({ module_index: i.reinterpret_as_uint(), graph })
  }
  Ok(reports)
}

///|
fn filter_prefixed_items(
  items : Array[String],
  prefix : String,
) -> Array[String] {
  let out : Array[String] = []
  for item in items {
    match item.strip_prefix(prefix) {
      Some(rest) => out.push(rest.to_string())
      None => ()
    }
  }
  out
}

///|
fn sum_core_module_bytes(core_modules : Array[Bytes]) -> UInt {
  let mut total = 0U
  for core_bytes in core_modules {
    total += core_bytes.length().reinterpret_as_uint()
  }
  total
}

///|
pub fn analyze_component_core_optimize(
  bytes : Bytes,
  config? : OptimizeConfig = OptimizeConfig::default(),
  exclude? : Array[String] = [],
) -> Result[ComponentCoreOptimizeReport, String] {
  let before_detail = match @mwac_component.parse_component_detail(bytes) {
    Ok(v) => v
    Err(e) => return Err("component detail parse failed: " + e.to_string())
  }
  let optimized_component = match
    optimize_component_for_size(bytes, config~, exclude~) {
    Ok(v) => v
    Err(e) => return Err("component optimize failed: " + e)
  }
  let after_detail = match
    @mwac_component.parse_component_detail(optimized_component.bytes) {
    Ok(v) => v
    Err(e) =>
      return Err("optimized component detail parse failed: " + e.to_string())
  }
  if before_detail.core_modules.length() != after_detail.core_modules.length() {
    return Err(
      "core module count mismatch after optimize: before=" +
      before_detail.core_modules.length().to_string() +
      " after=" +
      after_detail.core_modules.length().to_string(),
    )
  }
  let entries : Array[ComponentCoreOptimizeEntry] = []
  for i in 0..<before_detail.core_modules.length() {
    let before_bytes = before_detail.core_modules[i]
      .length()
      .reinterpret_as_uint()
    let after_bytes = after_detail.core_modules[i]
      .length()
      .reinterpret_as_uint()
    let prefix = "core#" + i.to_string() + ":"
    entries.push({
      module_index: i.reinterpret_as_uint(),
      before_bytes,
      after_bytes,
      removed_sections: filter_prefixed_items(
        optimized_component.removed_sections,
        prefix,
      ),
      no_change_reasons: filter_prefixed_items(
        optimized_component.no_change_reasons,
        prefix,
      ),
    })
  }
  Ok({
    total_component_bytes: bytes.length().reinterpret_as_uint(),
    core_module_count: before_detail.core_modules.length().reinterpret_as_uint(),
    total_core_before_bytes: sum_core_module_bytes(before_detail.core_modules),
    total_core_after_bytes: sum_core_module_bytes(after_detail.core_modules),
    entries,
  })
}

///|
pub fn optimize_component_for_size(
  bytes : Bytes,
  config? : OptimizeConfig = OptimizeConfig::default(),
  exclude? : Array[String] = [],
) -> Result[OptimizeResult, String] {
  @wite_optimize.optimize_component_for_size(bytes, config~, exclude~)
}

///|
pub fn optimize_binary_for_size(
  bytes : Bytes,
  config? : OptimizeConfig = OptimizeConfig::default(),
  exclude? : Array[String] = [],
) -> Result[OptimizeResult, String] {
  @wite_optimize.optimize_binary_for_size(bytes, config~, exclude~)
}

///|
pub fn analyze_component_contract(
  bytes : Bytes,
  resolved : @wit.ResolveInput,
) -> Result[ContractReport, String] {
  let detail = match @mwac_component.parse_component_detail(bytes) {
    Ok(v) => v
    Err(e) => return Err("component detail parse failed: " + e.to_string())
  }
  if resolved.world_id < 0 ||
    resolved.world_id >= resolved.resolve.worlds.length() {
    return Err("invalid world id: " + resolved.world_id.to_string())
  }
  let world = resolved.resolve.worlds[resolved.world_id]
  let component_imports = unique_sorted(
    detail.imports.map(item => item.name.to_string()),
  )
  let component_exports = unique_sorted(
    detail.exports.map(item => item.name.to_string()),
  )
  let wit_imports = unique_sorted(world_keys(world.imports))
  let wit_exports = unique_sorted(world_keys(world.exports))
  let missing_component_imports : Array[String] = []
  for name in wit_imports {
    if not(component_imports.contains(name)) {
      missing_component_imports.push(name)
    }
  }
  let missing_component_exports : Array[String] = []
  for name in wit_exports {
    if not(component_exports.contains(name)) {
      missing_component_exports.push(name)
    }
  }
  Ok({
    component_imports,
    component_exports,
    wit_imports,
    wit_exports,
    missing_component_imports,
    missing_component_exports,
  })
}

///|
fn collect_canonical_abi_root_names(
  component_exports : Array[String],
  wit_exports : Array[String],
) -> Array[String] {
  let roots : Array[String] = ["cabi_realloc"]
  for name in component_exports {
    match name.strip_prefix("cabi_") {
      Some(_) => roots.push(name)
      None => ()
    }
  }
  for name in wit_exports {
    roots.push("cabi_post_" + name)
  }
  unique_sorted(roots)
}

///|
pub fn analyze_component_root_policy(
  bytes : Bytes,
  resolved_wit? : @wit.ResolveInput? = None,
  exclude? : Array[String] = [],
) -> Result[ComponentRootPolicyReport, String] {
  let detail = match @mwac_component.parse_component_detail(bytes) {
    Ok(v) => v
    Err(e) => return Err("component detail parse failed: " + e.to_string())
  }
  let component_imports = unique_sorted(
    detail.imports.map(item => item.name.to_string()),
  )
  let component_exports = unique_sorted(
    detail.exports.map(item => item.name.to_string()),
  )
  let mut wit_imports : Array[String] = []
  let mut wit_exports : Array[String] = []
  match resolved_wit {
    Some(resolved) => {
      if resolved.world_id < 0 ||
        resolved.world_id >= resolved.resolve.worlds.length() {
        return Err("invalid world id: " + resolved.world_id.to_string())
      }
      let world = resolved.resolve.worlds[resolved.world_id]
      wit_imports = unique_sorted(world_keys(world.imports))
      wit_exports = unique_sorted(world_keys(world.exports))
    }
    None => ()
  }
  let canonical_abi_roots = collect_canonical_abi_root_names(
    component_exports, wit_exports,
  )
  let root_name_candidates = component_exports.copy()
  root_name_candidates.append(wit_exports[:])
  root_name_candidates.append(canonical_abi_roots[:])
  root_name_candidates.append(exclude[:])
  Ok({
    component_imports,
    component_exports,
    wit_imports,
    wit_exports,
    canonical_abi_roots,
    root_name_candidates: unique_sorted(root_name_candidates),
  })
}

///|
fn runtime_profile_scenario_display_name(
  scenario : RuntimeProfileScenario,
) -> String {
  if scenario.args.length() == 0 {
    return scenario.export_name
  }
  let encoded_args : Array[String] = []
  for arg in scenario.args {
    encoded_args.push(arg.to_string())
  }
  scenario.export_name + "(" + encoded_args.join("_") + ")"
}

///|
fn average_u64(values : Array[UInt64]) -> UInt64 {
  if values.length() == 0 {
    return 0UL
  }
  let mut total = 0UL
  for value in values {
    total += value
  }
  total / values.length().to_uint64()
}

///|
fn average_u32(values : Array[UInt]) -> UInt {
  if values.length() == 0 {
    return 0U
  }
  let mut total = 0U
  for value in values {
    total += value
  }
  total / values.length().reinterpret_as_uint()
}

///|
fn map_export_name_to_function_index(
  functions : Array[FunctionSize],
) -> Map[String, UInt] {
  let out : Map[String, UInt] = {}
  for function in functions {
    for export_name in function.export_names {
      if out.get(export_name) is None {
        out.set(export_name, function.function_index)
      }
    }
  }
  out
}

///|
fn map_function_size_by_index(
  functions : Array[FunctionSize],
) -> Map[UInt, FunctionSize] {
  let out : Map[UInt, FunctionSize] = {}
  for function in functions {
    out.set(function.function_index, function)
  }
  out
}

///|
fn map_runtime_unresolved_by_export_name(
  unresolved_exports : Array[RuntimeUnresolvedExport],
) -> Map[String, RuntimeUnresolvedExport] {
  let out : Map[String, RuntimeUnresolvedExport] = {}
  for entry in unresolved_exports {
    if out.get(entry.export_name) is None {
      out.set(entry.export_name, entry)
    }
  }
  out
}

///|
fn map_runtime_scenario_display_to_export_name(
  scenarios : Array[RuntimeProfileScenario],
) -> Map[String, String] {
  let out : Map[String, String] = {}
  for scenario in scenarios {
    let display_name = runtime_profile_scenario_display_name(scenario)
    if out.get(display_name) is None {
      out.set(display_name, scenario.export_name)
    }
  }
  out
}

///|
fn has_hotness_size_entry(
  entries : Array[HotnessSizeEntry],
  export_name : String,
) -> Bool {
  for entry in entries {
    if entry.export_name == export_name {
      return true
    }
  }
  false
}

///|
fn classify_hotness_size_bucket(
  total_ns : UInt64,
  body_bytes : UInt,
  hot_threshold_ns : UInt64,
  large_threshold_bytes : UInt,
  resolved : Bool,
) -> String {
  if not(resolved) {
    return "unresolved"
  }
  let hot = total_ns >= hot_threshold_ns
  let large = body_bytes >= large_threshold_bytes
  if hot && large {
    "hot-large"
  } else if hot {
    "hot-small"
  } else if large {
    "cold-large"
  } else {
    "cold-small"
  }
}

///|
fn compare_hotness_size_entry(
  a : HotnessSizeEntry,
  b : HotnessSizeEntry,
) -> Int {
  if a.total_ns > b.total_ns {
    -1
  } else if a.total_ns < b.total_ns {
    1
  } else if a.body_bytes > b.body_bytes {
    -1
  } else if a.body_bytes < b.body_bytes {
    1
  } else {
    a.export_name.compare(b.export_name)
  }
}

///|
fn compare_hotness_unresolved_reason_count(
  a : HotnessUnresolvedReasonCount,
  b : HotnessUnresolvedReasonCount,
) -> Int {
  if a.count > b.count {
    -1
  } else if a.count < b.count {
    1
  } else {
    a.reason.compare(b.reason)
  }
}

///|
fn collect_hotness_size_buckets(
  entries : Array[HotnessSizeEntry],
) -> Array[HotnessSizeBucket] {
  let order = [
    "hot-large", "hot-small", "cold-large", "cold-small", "unresolved",
  ]
  let grouped : Map[String, HotnessSizeBucket] = {}
  for bucket in order {
    grouped.set(bucket, { bucket, count: 0U, body_bytes: 0U, total_ns: 0UL })
  }
  for entry in entries {
    let prev = match grouped.get(entry.bucket) {
      Some(v) => v
      None => {
        let empty : HotnessSizeBucket = {
          bucket: entry.bucket,
          count: 0U,
          body_bytes: 0U,
          total_ns: 0UL,
        }
        grouped.set(entry.bucket, empty)
        empty
      }
    }
    grouped.set(entry.bucket, {
      bucket: entry.bucket,
      count: prev.count + 1U,
      body_bytes: prev.body_bytes + entry.body_bytes,
      total_ns: prev.total_ns + entry.total_ns,
    })
  }
  let buckets : Array[HotnessSizeBucket] = []
  for bucket in order {
    match grouped.get(bucket) {
      Some(v) => buckets.push(v)
      None => buckets.push({ bucket, count: 0U, body_bytes: 0U, total_ns: 0UL })
    }
  }
  buckets
}

///|
fn collect_hotness_unresolved_reason_counts(
  entries : Array[HotnessSizeEntry],
) -> Array[HotnessUnresolvedReasonCount] {
  let counts : Map[String, UInt] = {}
  for entry in entries {
    if entry.bucket != "unresolved" {
      continue
    }
    let reason = match entry.unresolved_reason {
      Some(v) => v
      None => "unknown"
    }
    let prev = match counts.get(reason) {
      Some(v) => v
      None => 0U
    }
    counts.set(reason, prev + 1U)
  }
  let out : Array[HotnessUnresolvedReasonCount] = []
  counts.each((reason, count) => out.push({ reason, count }))
  out.sort_by(compare_hotness_unresolved_reason_count)
  out
}

///|
pub fn analyze_hotness_size_matrix(
  bytes : Bytes,
  iterations? : UInt = 50U,
  scenarios? : Array[RuntimeProfileScenario] = [],
) -> Result[HotnessSizeMatrixReport, String] {
  let runtime = match profile_runtime_exports(bytes, iterations~, scenarios~) {
    Ok(v) => v
    Err(msg) => return Err(msg)
  }
  let function_sizes = match analyze_function_sizes(bytes) {
    Ok(v) => v
    Err(err) =>
      return Err("function size analysis failed: " + error_to_string(err))
  }
  let export_to_function_index = map_export_name_to_function_index(
    function_sizes,
  )
  let function_size_by_index = map_function_size_by_index(function_sizes)
  let runtime_unresolved_by_name = map_runtime_unresolved_by_export_name(
    runtime.unresolved_exports,
  )
  let scenario_display_to_export_name = map_runtime_scenario_display_to_export_name(
    scenarios,
  )
  let resolved_total_ns : Array[UInt64] = []
  let resolved_body_bytes : Array[UInt] = []
  let unresolved_exports : Array[String] = []
  for fn_profile in runtime.functions {
    let lookup_name = match
      scenario_display_to_export_name.get(fn_profile.name) {
      Some(v) => v
      None => fn_profile.name
    }
    match export_to_function_index.get(lookup_name) {
      Some(function_index) =>
        match function_size_by_index.get(function_index) {
          Some(function_size) => {
            resolved_total_ns.push(fn_profile.total_ns)
            resolved_body_bytes.push(function_size.body_bytes)
          }
          None => unresolved_exports.push(fn_profile.name)
        }
      None => unresolved_exports.push(fn_profile.name)
    }
  }
  let hot_threshold_ns = average_u64(resolved_total_ns)
  let large_threshold_bytes = average_u32(resolved_body_bytes)
  let entries : Array[HotnessSizeEntry] = []
  for fn_profile in runtime.functions {
    let lookup_name = match
      scenario_display_to_export_name.get(fn_profile.name) {
      Some(v) => v
      None => fn_profile.name
    }
    match export_to_function_index.get(lookup_name) {
      Some(function_index) =>
        match function_size_by_index.get(function_index) {
          Some(function_size) =>
            entries.push({
              export_name: fn_profile.name,
              function_index: Some(function_index),
              function_name: function_size.name,
              body_bytes: function_size.body_bytes,
              calls: fn_profile.calls,
              total_ns: fn_profile.total_ns,
              average_ns: fn_profile.average_ns,
              bucket: classify_hotness_size_bucket(
                fn_profile.total_ns,
                function_size.body_bytes,
                hot_threshold_ns,
                large_threshold_bytes,
                true,
              ),
              unresolved_reason: None,
              unresolved_detail: None,
            })
          None => {
            let unresolved = runtime_unresolved_by_name.get(fn_profile.name)
            let unresolved_reason = match unresolved {
              Some(v) => v.reason
              None => "import-missing"
            }
            let unresolved_detail_text = match unresolved {
              Some(v) =>
                if v.detail.is_empty() {
                  "no local function body matched export"
                } else {
                  v.detail
                }
              None => "no local function body matched export"
            }
            entries.push({
              export_name: fn_profile.name,
              function_index: None,
              function_name: None,
              body_bytes: 0U,
              calls: fn_profile.calls,
              total_ns: fn_profile.total_ns,
              average_ns: fn_profile.average_ns,
              bucket: "unresolved",
              unresolved_reason: Some(unresolved_reason),
              unresolved_detail: Some(unresolved_detail_text),
            })
            unresolved_exports.push(fn_profile.name)
          }
        }
      None => {
        let unresolved = runtime_unresolved_by_name.get(fn_profile.name)
        let unresolved_reason = match unresolved {
          Some(v) => v.reason
          None => "import-missing"
        }
        let unresolved_detail_text = match unresolved {
          Some(v) =>
            if v.detail.is_empty() {
              "no local function body matched export"
            } else {
              v.detail
            }
          None => "no local function body matched export"
        }
        entries.push({
          export_name: fn_profile.name,
          function_index: None,
          function_name: None,
          body_bytes: 0U,
          calls: fn_profile.calls,
          total_ns: fn_profile.total_ns,
          average_ns: fn_profile.average_ns,
          bucket: "unresolved",
          unresolved_reason: Some(unresolved_reason),
          unresolved_detail: Some(unresolved_detail_text),
        })
        unresolved_exports.push(fn_profile.name)
      }
    }
  }
  for unresolved in runtime.unresolved_exports {
    if has_hotness_size_entry(entries, unresolved.export_name) {
      continue
    }
    entries.push({
      export_name: unresolved.export_name,
      function_index: None,
      function_name: None,
      body_bytes: 0U,
      calls: 0U,
      total_ns: 0UL,
      average_ns: 0UL,
      bucket: "unresolved",
      unresolved_reason: Some(unresolved.reason),
      unresolved_detail: if unresolved.detail.is_empty() {
        None
      } else {
        Some(unresolved.detail)
      },
    })
    unresolved_exports.push(unresolved.export_name)
  }
  unresolved_exports.sort()
  unresolved_exports.dedup()
  entries.sort_by(compare_hotness_size_entry)
  let buckets = collect_hotness_size_buckets(entries)
  let unresolved_reason_counts = collect_hotness_unresolved_reason_counts(
    entries,
  )
  Ok({
    iterations: runtime.iterations,
    instantiate_ns: runtime.instantiate_ns,
    hot_threshold_ns,
    large_threshold_bytes,
    unresolved_exports,
    unresolved_reason_counts,
    buckets,
    entries,
  })
}
