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
    let exports = match fn_size.export_names {
      [] => ""
      [_, ..] => " exports=" + fn_size.export_names.join(",")
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
    let left_exports = match entry.left_export_names {
      [] => "-"
      [_, ..] => entry.left_export_names.join(",")
    }
    let right_exports = match entry.right_export_names {
      [] => "-"
      [_, ..] => entry.right_export_names.join(",")
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
    let exports = match block.export_names {
      [] => ""
      [_, ..] => " exports=" + block.export_names.join(",")
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
  match analyze_code_block_sizes(bytes) {
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
  match analyze_function_sizes(bytes) {
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
  match analyze_function_size_gap(left_bytes, right_bytes, top_limit=limit) {
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
