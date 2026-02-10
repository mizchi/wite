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
  let left_report = match analyze_code_block_sizes(left_bytes) {
    Ok(v) => v
    Err(e) => {
      println("block diff failed (left): " + @wite.error_to_string(e))
      @sys.exit(1)
      panic()
    }
  }
  let right_report = match analyze_code_block_sizes(right_bytes) {
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
  match analyze_call_graph(bytes) {
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
