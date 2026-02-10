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
