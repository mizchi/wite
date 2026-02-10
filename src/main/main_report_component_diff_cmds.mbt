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
fn print_function_sizes(
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
fn print_call_graph_nodes(
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
fn run_keep_reasons_with_options(
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
fn run_keep_reasons(args : Array[String]) -> Unit {
  if args.length() < 3 {
    print_analyze_usage()
    @sys.exit(1)
  }
  let path = args[2]
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
  run_keep_reasons_with_options(
    path, closed_world, safe_mode, closed_world_root_exports,
  )
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
fn run_retain_path_with_options(
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

///|
fn run_retain_path(args : Array[String]) -> Unit {
  if args.length() < 3 {
    print_analyze_usage()
    @sys.exit(1)
  }
  let path = args[2]
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
  run_retain_path_with_options(
    path, limit, closed_world, safe_mode, closed_world_root_exports,
  )
}

///|
pub fn run_component_profile(path : String) -> Unit {
  @wite_component.run_component_profile(path)
}

///|
pub fn run_component_top_functions(path : String, limit : UInt) -> Unit {
  @wite_component.run_component_top_functions(path, limit)
}

///|
pub fn run_component_callgraph(path : String, limit : UInt) -> Unit {
  @wite_component.run_component_callgraph(path, limit)
}

///|
fn run_component_dce_kpi(args : Array[String]) -> Unit {
  if args.length() < 3 {
    print_analyze_usage()
    @sys.exit(1)
  }
  let component_path = args[2]
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
  @wite_component.run_component_dce_kpi_with_options(
    component_path,
    wit_path,
    excludes,
    parse_closed_world_roots(args, 3),
    safe_mode,
    verbose,
  )
}

///|
fn run_contract(component_path : String, wit_path : String) -> Unit {
  @wite_component.run_contract(component_path, wit_path)
}

///|
fn run_root_policy(args : Array[String]) -> Unit {
  if args.length() < 3 {
    print_analyze_usage()
    @sys.exit(1)
  }
  let component_path = args[2]
  let excludes = parse_excluded_roots(args, 3)
  let mut wit_path : String? = None
  for i in 3..<args.length() {
    if not(args[i].has_prefix("--")) && wit_path is None {
      wit_path = Some(args[i])
    }
  }
  @wite_component.run_root_policy_with_options(
    component_path, wit_path, excludes,
  )
}

///|
fn run_diff_command(args : Array[String]) -> Unit {
  if args.length() < 3 {
    print_usage()
    @sys.exit(1)
  }
  let left_path = args[2]
  let mut view = DiffView::Function
  let mut limit = 20U
  let mut baseline : DiffBaseline? = None
  let mut baseline_opt_level = "-Oz"
  let mut wasm_opt_bin_override : String? = None
  let wasm_opt_extra_args : Array[String] = []
  let positional : Array[String] = []
  for i in 3..<args.length() {
    let arg = args[i]
    match arg.strip_prefix("--view=") {
      Some(name) =>
        match parse_diff_view(name.to_string()) {
          Some(v) => view = v
          None => {
            println("unknown diff view: " + name.to_string())
            @sys.exit(1)
          }
        }
      None =>
        match arg.strip_prefix("--limit=") {
          Some(value) => limit = parse_uint_or_exit(value.to_string(), "limit")
          None =>
            match arg.strip_prefix("--baseline=") {
              Some(name) =>
                match parse_diff_baseline(name.to_string()) {
                  Some(v) => baseline = Some(v)
                  None => {
                    println("unknown diff baseline: " + name.to_string())
                    @sys.exit(1)
                  }
                }
              None =>
                match arg.strip_prefix("--wasm-opt-bin=") {
                  Some(path) => {
                    if path.is_empty() {
                      println("wasm-opt-bin must not be empty")
                      @sys.exit(1)
                    }
                    wasm_opt_bin_override = Some(path.to_string())
                  }
                  None =>
                    match arg.strip_prefix("--baseline-opt-level=") {
                      Some(level) =>
                        baseline_opt_level = parse_wasm_opt_level_or_exit(
                          level.to_string(),
                        )
                      None =>
                        match arg.strip_prefix("--baseline-arg=") {
                          Some(v) =>
                            if not(v.is_empty()) {
                              wasm_opt_extra_args.push(v.to_string())
                            }
                          None =>
                            if arg.has_prefix("--") {
                              println("unknown diff option: " + arg)
                              @sys.exit(1)
                            } else {
                              positional.push(arg)
                            }
                        }
                    }
                }
            }
        }
    }
  }
  if positional.length() > 1 {
    println("unexpected diff argument: " + positional[1])
    @sys.exit(1)
  }
  if positional.length() == 1 && baseline is Some(_) {
    println("cannot combine explicit right.wasm with --baseline")
    @sys.exit(1)
  }
  let mut generated_baseline_path : String? = None
  let right_path = if positional.length() == 1 {
    positional[0]
  } else {
    match baseline {
      Some(DiffBaseline::WasmOpt) => {
        let wasm_opt_bin = resolve_wasm_opt_bin(wasm_opt_bin_override)
        let output_path = js_make_temp_wasm_path("wite-diff-wasm-opt")
        run_wasm_opt_baseline_or_exit(
          left_path, output_path, wasm_opt_bin, baseline_opt_level, wasm_opt_extra_args,
        )
        generated_baseline_path = Some(output_path)
        output_path
      }
      None => {
        println("diff requires <right.wasm> or --baseline=wasm-opt")
        @sys.exit(1)
        ""
      }
    }
  }
  match view {
    DiffView::Function =>
      @wite_analyze.run_function_gap(left_path, right_path, limit)
    DiffView::Section =>
      @wite_analyze.run_section_gap(left_path, right_path, limit)
    DiffView::Block => @wite_analyze.run_block_gap(left_path, right_path, limit)
  }
  match generated_baseline_path {
    Some(path) => @fs.remove_file(path) catch { _ => () }
    None => ()
  }
}

///|
