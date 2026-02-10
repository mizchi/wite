///|
priv struct FunctionMatchPair {
  match_kind : String
  match_key : String
  left_index : UInt
  right_index : UInt
}

///|
fn map_push_uint_array(
  grouped : Map[String, Array[UInt]],
  key : String,
  value : UInt,
) -> Unit {
  match grouped.get(key) {
    Some(prev) => {
      let next = prev.copy()
      next.push(value)
      grouped.set(key, next)
    }
    None => grouped.set(key, [value])
  }
}

///|
fn build_export_match_map(
  functions : Array[FunctionSize],
) -> Map[String, Array[UInt]] {
  let grouped : Map[String, Array[UInt]] = {}
  for function in functions {
    for export_name in function.export_names {
      map_push_uint_array(
        grouped,
        "export:" + export_name,
        function.function_index,
      )
    }
  }
  grouped
}

///|
fn build_name_match_map(
  functions : Array[FunctionSize],
) -> Map[String, Array[UInt]] {
  let grouped : Map[String, Array[UInt]] = {}
  for function in functions {
    match function.name {
      Some(name) =>
        if not(name.is_empty()) {
          map_push_uint_array(grouped, "name:" + name, function.function_index)
        }
      None => ()
    }
  }
  grouped
}

///|
fn compare_function_match_pair(
  a : FunctionMatchPair,
  b : FunctionMatchPair,
) -> Int {
  if a.match_kind != b.match_kind {
    a.match_kind.compare(b.match_kind)
  } else {
    a.match_key.compare(b.match_key)
  }
}

///|
fn collect_unique_function_pairs(
  left_grouped : Map[String, Array[UInt]],
  right_grouped : Map[String, Array[UInt]],
  match_kind : String,
  used_left : Map[UInt, Bool],
  used_right : Map[UInt, Bool],
) -> Array[FunctionMatchPair] {
  let keys : Array[String] = []
  left_grouped.each((key, _) => keys.push(key))
  keys.sort()
  let out : Array[FunctionMatchPair] = []
  for key in keys {
    let left_indices = match left_grouped.get(key) {
      Some(v) => v
      None => []
    }
    let right_indices = match right_grouped.get(key) {
      Some(v) => v
      None => []
    }
    if left_indices.length() != 1 || right_indices.length() != 1 {
      continue
    }
    let left_index = left_indices[0]
    let right_index = right_indices[0]
    if used_left.get(left_index) is Some(_) {
      continue
    }
    if used_right.get(right_index) is Some(_) {
      continue
    }
    used_left.set(left_index, true)
    used_right.set(right_index, true)
    out.push({ match_kind, match_key: key, left_index, right_index })
  }
  out.sort_by(compare_function_match_pair)
  out
}

///|
fn collect_unmatched_functions(
  functions : Array[FunctionSize],
  used : Map[UInt, Bool],
) -> Array[FunctionSize] {
  let out : Array[FunctionSize] = []
  for function in functions {
    if used.get(function.function_index) is None {
      out.push(function)
    }
  }
  out.sort_by(compare_function_size)
  out
}

///|
fn signed_delta_from_uint(left : UInt, right : UInt) -> Int {
  if left >= right {
    (left - right).reinterpret_as_int()
  } else {
    -(right - left).reinterpret_as_int()
  }
}

///|
fn abs_signed_delta_from_uint(left : UInt, right : UInt) -> UInt {
  if left >= right {
    left - right
  } else {
    right - left
  }
}

///|
fn sum_function_body_bytes(functions : Array[FunctionSize]) -> UInt {
  let mut total = 0U
  for function in functions {
    total += function.body_bytes
  }
  total
}

///|
fn make_function_gap_entry(
  match_kind : String,
  match_key : String,
  left : FunctionSize?,
  right : FunctionSize?,
) -> FunctionGapEntry {
  let left_body_bytes = match left {
    Some(v) => v.body_bytes
    None => 0U
  }
  let right_body_bytes = match right {
    Some(v) => v.body_bytes
    None => 0U
  }
  {
    match_kind,
    match_key,
    left_function_index: match left {
      Some(v) => Some(v.function_index)
      None => None
    },
    right_function_index: match right {
      Some(v) => Some(v.function_index)
      None => None
    },
    left_name: match left {
      Some(v) => v.name
      None => None
    },
    right_name: match right {
      Some(v) => v.name
      None => None
    },
    left_export_names: match left {
      Some(v) => v.export_names
      None => []
    },
    right_export_names: match right {
      Some(v) => v.export_names
      None => []
    },
    left_body_bytes,
    right_body_bytes,
    left_minus_right_bytes: signed_delta_from_uint(
      left_body_bytes, right_body_bytes,
    ),
    abs_gap_bytes: abs_signed_delta_from_uint(left_body_bytes, right_body_bytes),
  }
}

///|
fn compare_function_gap_entry(
  a : FunctionGapEntry,
  b : FunctionGapEntry,
) -> Int {
  if a.abs_gap_bytes > b.abs_gap_bytes {
    -1
  } else if a.abs_gap_bytes < b.abs_gap_bytes {
    1
  } else if a.left_body_bytes > b.left_body_bytes {
    -1
  } else if a.left_body_bytes < b.left_body_bytes {
    1
  } else if a.right_body_bytes > b.right_body_bytes {
    -1
  } else if a.right_body_bytes < b.right_body_bytes {
    1
  } else if a.match_kind != b.match_kind {
    a.match_kind.compare(b.match_kind)
  } else {
    a.match_key.compare(b.match_key)
  }
}

///|
pub fn analyze_function_size_gap(
  left_bytes : Bytes,
  right_bytes : Bytes,
  top_limit? : UInt = 20U,
) -> Result[FunctionGapReport, WiteError] {
  try? {
    let left_functions = match analyze_function_sizes(left_bytes) {
      Ok(v) => v
      Err(e) => raise e
    }
    let right_functions = match analyze_function_sizes(right_bytes) {
      Ok(v) => v
      Err(e) => raise e
    }
    let left_by_index = map_function_sizes_by_index(left_functions)
    let right_by_index = map_function_sizes_by_index(right_functions)
    let used_left : Map[UInt, Bool] = {}
    let used_right : Map[UInt, Bool] = {}
    let entries : Array[FunctionGapEntry] = []
    let left_export_grouped = build_export_match_map(left_functions)
    let right_export_grouped = build_export_match_map(right_functions)
    let export_pairs = collect_unique_function_pairs(
      left_export_grouped, right_export_grouped, "export", used_left, used_right,
    )
    for pair in export_pairs {
      match
        (
          left_by_index.get(pair.left_index),
          right_by_index.get(pair.right_index),
        ) {
        (Some(left), Some(right)) =>
          entries.push(
            make_function_gap_entry(
              pair.match_kind,
              pair.match_key,
              Some(left),
              Some(right),
            ),
          )
        _ => ()
      }
    }
    let left_name_grouped = build_name_match_map(left_functions)
    let right_name_grouped = build_name_match_map(right_functions)
    let name_pairs = collect_unique_function_pairs(
      left_name_grouped, right_name_grouped, "name", used_left, used_right,
    )
    for pair in name_pairs {
      match
        (
          left_by_index.get(pair.left_index),
          right_by_index.get(pair.right_index),
        ) {
        (Some(left), Some(right)) =>
          entries.push(
            make_function_gap_entry(
              pair.match_kind,
              pair.match_key,
              Some(left),
              Some(right),
            ),
          )
        _ => ()
      }
    }
    let left_unmatched = collect_unmatched_functions(left_functions, used_left)
    let right_unmatched = collect_unmatched_functions(
      right_functions, used_right,
    )
    let shared_unmatched_count = if left_unmatched.length() <
      right_unmatched.length() {
      left_unmatched.length()
    } else {
      right_unmatched.length()
    }
    for i in 0..<shared_unmatched_count {
      entries.push(
        make_function_gap_entry(
          "rank",
          "rank:" + (i + 1).to_string(),
          Some(left_unmatched[i]),
          Some(right_unmatched[i]),
        ),
      )
    }
    let mut unmatched_left_count = 0U
    let mut unmatched_right_count = 0U
    for i in shared_unmatched_count..<left_unmatched.length() {
      unmatched_left_count += 1U
      let left = left_unmatched[i]
      entries.push(
        make_function_gap_entry(
          "left-only",
          "left:#" + left.function_index.to_string(),
          Some(left),
          None,
        ),
      )
    }
    for i in shared_unmatched_count..<right_unmatched.length() {
      unmatched_right_count += 1U
      let right = right_unmatched[i]
      entries.push(
        make_function_gap_entry(
          "right-only",
          "right:#" + right.function_index.to_string(),
          None,
          Some(right),
        ),
      )
    }
    entries.sort_by(compare_function_gap_entry)
    let limited_entries : Array[FunctionGapEntry] = []
    let mut count = 0U
    for entry in entries {
      if top_limit > 0U && count >= top_limit {
        break
      }
      limited_entries.push(entry)
      count += 1U
    }
    let left_total_body_bytes = sum_function_body_bytes(left_functions)
    let right_total_body_bytes = sum_function_body_bytes(right_functions)
    {
      left_total_body_bytes,
      right_total_body_bytes,
      left_minus_right_total_bytes: signed_delta_from_uint(
        left_total_body_bytes, right_total_body_bytes,
      ),
      unmatched_left_count,
      unmatched_right_count,
      entries: limited_entries,
    }
  }
}

