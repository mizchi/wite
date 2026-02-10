///|
async fn auto_sync_deps_from_config_if_needed(
  selection : @wite_config.ConfigSelectionFlags,
) -> Unit {
  let config_exists = @fs.path_exists(selection.config_path)
  if not(
      @wite_config.should_auto_sync_deps(selection.use_config, config_exists),
    ) {
    return
  }
  if not(@wite_deps.config_has_dep_entries_or_exit(selection.config_path)) {
    return
  }
  let sync_args = @wite_config.build_auto_sync_deps_command_args(
    selection.config_path,
  )
  println("auto deps sync: " + selection.config_path + " -> deps/")
  @wite_deps.run_deps_sync_command(sync_args, @wite_deps.noop_usage_printer)
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
fn print_section_sizes(sections : Array[@wite.SectionSize]) -> Unit {
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
