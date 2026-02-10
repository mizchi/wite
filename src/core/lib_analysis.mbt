///|
pub fn analyze_section_sizes(
  bytes : Bytes,
) -> Result[Array[SectionSize], WiteError] {
  try? {
    let sections = parse_core_sections_raise(bytes)
    summarize_sections(sections, false)
  }
}

///|
pub fn optimize_for_size(
  bytes : Bytes,
  config? : OptimizeConfig = OptimizeConfig::default(),
) -> Result[OptimizeResult, WiteError] {
  try? {
    let rounds = if config.pass_rounds == 0U { 1U } else { config.pass_rounds }
    let mut current = bytes
    let removed_sections : Array[String] = []
    for _ in 0U..<rounds {
      let before_round_size = current.length().reinterpret_as_uint()
      let round = optimize_for_size_round_raise(current, config)
      let after_round_size = round.bytes.length().reinterpret_as_uint()
      let changed = not(bytes_equal(round.bytes, current))
      current = round.bytes
      removed_sections.append(round.removed_sections[:])
      if not(changed) {
        break
      }
      // Stop fixed-point rounds once a round regresses size.
      // Keep size-neutral rounds because they can unlock later DCE.
      if after_round_size > before_round_size {
        break
      }
    }
    let no_change_reasons = collect_optimize_no_change_reasons(
      bytes, current, config,
    )
    {
      bytes: current,
      before_size: bytes.length().reinterpret_as_uint(),
      after_size: current.length().reinterpret_as_uint(),
      removed_sections,
      no_change_reasons,
    }
  }
}

///|
pub fn profile_module(bytes : Bytes) -> Result[ModuleProfile, WiteError] {
  try? {
    let sections = parse_core_sections_raise(bytes)
    let mut function_count = 0U
    let mut import_count = 0U
    let mut export_count = 0U
    let mut code_body_count = 0U
    let mut code_body_bytes = 0U
    for section in sections {
      let payload = bytes[section.payload_start:section.section_end].to_bytes()
      match section.section_id {
        2U => import_count += parse_vec_count(payload)
        3U => function_count += parse_vec_count(payload)
        7U => export_count += parse_vec_count(payload)
        10U => {
          let (count, total_bytes) = parse_code_section_metrics(payload)
          code_body_count += count
          code_body_bytes += total_bytes
        }
        _ => ()
      }
    }
    {
      total_bytes: bytes.length().reinterpret_as_uint(),
      function_count,
      import_count,
      export_count,
      code_body_count,
      code_body_bytes,
      sections: summarize_sections(sections, false),
    }
  }
}

///|
pub fn analyze_function_sizes(
  bytes : Bytes,
) -> Result[Array[FunctionSize], WiteError] {
  try? {
    let sections = parse_core_sections_raise(bytes)
    let mut imported_function_count = 0U
    let mut local_function_count = 0U
    let mut code_body_sizes : Array[UInt] = []
    let export_names : Map[UInt, Array[String]] = {}
    let function_names : Map[UInt, String] = {}
    for section in sections {
      let payload = bytes[section.payload_start:section.section_end].to_bytes()
      match section.section_id {
        2U => imported_function_count += parse_import_function_count(payload)
        3U => local_function_count += parse_vec_count(payload)
        7U =>
          merge_export_function_names(
            export_names,
            parse_export_function_names(payload),
          )
        10U => code_body_sizes = parse_code_body_sizes(payload)
        0U =>
          match section.custom_name {
            Some(name) =>
              if name == "name" {
                parse_name_section_function_names(payload).each((
                  index,
                  function_name,
                ) => function_names.set(index, function_name))
              }
            None => ()
          }
        _ => ()
      }
    }
    if code_body_sizes.length().reinterpret_as_uint() != local_function_count {
      raise WiteError::InvalidFormat(
        "function/code section count mismatch: function=" +
        local_function_count.to_string() +
        " code=" +
        code_body_sizes.length().to_string(),
      )
    }
    let functions : Array[FunctionSize] = []
    for i in 0..<code_body_sizes.length() {
      let function_index = imported_function_count + i.reinterpret_as_uint()
      functions.push({
        function_index,
        body_bytes: code_body_sizes[i],
        name: function_names.get(function_index),
        export_names: match export_names.get(function_index) {
          Some(v) => v
          None => []
        },
      })
    }
    functions.sort_by((a, b) => if a.body_bytes > b.body_bytes {
      -1
    } else if a.body_bytes < b.body_bytes {
      1
    } else if a.function_index < b.function_index {
      -1
    } else if a.function_index > b.function_index {
      1
    } else {
      0
    })
    functions
  }
}

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

///|
fn code_block_kind_from_opcode(opcode : UInt) -> String? {
  match opcode {
    0x02U => Some("block")
    0x03U => Some("loop")
    0x04U => Some("if")
    _ => None
  }
}

///|
fn collect_function_code_blocks(
  function_index : UInt,
  function_name : String?,
  export_names : Array[String],
  instr_bytes : Bytes,
  spans : Array[InstrSpan],
) -> (Array[CodeBlockSize], Bool) {
  let entries : Array[CodeBlockSize] = []
  let instr_size = instr_bytes.length().reinterpret_as_uint()
  entries.push({
    function_index,
    function_name,
    export_names,
    block_index: 0U,
    depth: 0U,
    kind: "function",
    start_offset: 0U,
    end_offset: instr_size,
    instruction_count: spans.length().reinterpret_as_uint(),
    total_bytes: instr_size,
  })
  let mut next_block_index = 1U
  let open_stack : Array[OpenCodeBlock] = []
  for i in 0..<spans.length() {
    let span = spans[i]
    match code_block_kind_from_opcode(span.opcode) {
      Some(kind) => {
        let depth = open_stack.length().reinterpret_as_uint() + 1U
        let start_offset = span.start.reinterpret_as_uint()
        entries.push({
          function_index,
          function_name,
          export_names,
          block_index: next_block_index,
          depth,
          kind,
          start_offset,
          end_offset: start_offset,
          instruction_count: 0U,
          total_bytes: 0U,
        })
        open_stack.push({
          entry_index: entries.length() - 1,
          start_span_index: i,
          start_offset: span.start,
        })
        next_block_index += 1U
      }
      None => ()
    }
    if span.opcode == 0x0bU && open_stack.length() > 0 {
      let open = open_stack[open_stack.length() - 1]
      ignore(open_stack.pop())
      let prev = entries[open.entry_index]
      entries[open.entry_index] = {
        function_index: prev.function_index,
        function_name: prev.function_name,
        export_names: prev.export_names,
        block_index: prev.block_index,
        depth: prev.depth,
        kind: prev.kind,
        start_offset: prev.start_offset,
        end_offset: span.end_.reinterpret_as_uint(),
        instruction_count: (i - open.start_span_index + 1).reinterpret_as_uint(),
        total_bytes: (span.end_ - open.start_offset).reinterpret_as_uint(),
      }
    }
  }
  if open_stack.length() == 0 {
    return (entries, true)
  }
  let filtered : Array[CodeBlockSize] = []
  for entry in entries {
    if entry.kind == "function" || entry.total_bytes > 0U {
      filtered.push(entry)
    }
  }
  (filtered, false)
}

///|
pub fn analyze_code_block_sizes(
  bytes : Bytes,
) -> Result[CodeBlockSizeReport, WiteError] {
  try? {
    let sections = parse_core_sections_raise(bytes)
    let mut imported_function_count = 0U
    let mut local_function_count = 0U
    let mut code_bodies : Array[Bytes] = []
    let export_names : Map[UInt, Array[String]] = {}
    let function_names : Map[UInt, String] = {}
    for section in sections {
      let payload = bytes[section.payload_start:section.section_end].to_bytes()
      match section.section_id {
        2U => imported_function_count += parse_import_function_count(payload)
        3U => local_function_count += parse_vec_count(payload)
        7U =>
          merge_export_function_names(
            export_names,
            parse_export_function_names(payload),
          )
        10U => code_bodies = parse_code_bodies(payload)
        0U =>
          match section.custom_name {
            Some(name) =>
              if name == "name" {
                parse_name_section_function_names(payload).each((
                  index,
                  function_name,
                ) => function_names.set(index, function_name))
              }
            None => ()
          }
        _ => ()
      }
    }
    if code_bodies.length().reinterpret_as_uint() != local_function_count {
      raise WiteError::InvalidFormat(
        "function/code section count mismatch: function=" +
        local_function_count.to_string() +
        " code=" +
        code_bodies.length().to_string(),
      )
    }
    let blocks : Array[CodeBlockSize] = []
    let mut partial = false
    let mut total_body_bytes = 0U
    let mut total_instruction_bytes = 0U
    for i in 0..<code_bodies.length() {
      let function_index = imported_function_count + i.reinterpret_as_uint()
      let body = code_bodies[i]
      total_body_bytes += body.length().reinterpret_as_uint()
      let prefix_end_result = try? parse_local_decl_prefix_end(body)
      match prefix_end_result {
        Ok(prefix_end) => {
          let instr_bytes = body[prefix_end:body.length()].to_bytes()
          total_instruction_bytes += instr_bytes.length().reinterpret_as_uint()
          match parse_instruction_spans(instr_bytes) {
            Some(spans) => {
              let exports = match export_names.get(function_index) {
                Some(v) => v
                None => []
              }
              let (function_blocks, complete) = collect_function_code_blocks(
                function_index,
                function_names.get(function_index),
                exports,
                instr_bytes,
                spans,
              )
              blocks.append(function_blocks[:])
              if not(complete) {
                partial = true
              }
            }
            None => partial = true
          }
        }
        Err(_) => partial = true
      }
    }
    blocks.sort_by((a, b) => if a.total_bytes > b.total_bytes {
      -1
    } else if a.total_bytes < b.total_bytes {
      1
    } else if a.function_index < b.function_index {
      -1
    } else if a.function_index > b.function_index {
      1
    } else if a.block_index < b.block_index {
      -1
    } else if a.block_index > b.block_index {
      1
    } else {
      0
    })
    {
      partial,
      function_count: local_function_count,
      block_count: blocks.length().reinterpret_as_uint(),
      total_body_bytes,
      total_instruction_bytes,
      blocks,
    }
  }
}

///|
fn summarize_custom_sections_raise(
  sections : Array[RawSection],
  bytes : Bytes,
) -> Array[CustomSectionBreakdown] raise WiteError {
  let grouped : Map[String, CustomSectionBreakdown] = {}
  for section in sections {
    if section.section_id != 0U {
      continue
    }
    let name = match section.custom_name {
      Some(v) => v
      None => "(anon)"
    }
    let payload = bytes[section.payload_start:section.section_end].to_bytes()
    let payload_bytes = payload.length().reinterpret_as_uint()
    let prefix_end = parse_custom_section_name_prefix_end(payload)
    let content_bytes = (payload.length() - prefix_end).reinterpret_as_uint()
    let total_bytes = section_total_bytes(section)
    match grouped.get(name) {
      Some(prev) =>
        grouped.set(name, {
          name: prev.name,
          count: prev.count + 1U,
          total_bytes: prev.total_bytes + total_bytes,
          payload_bytes: prev.payload_bytes + payload_bytes,
          content_bytes: prev.content_bytes + content_bytes,
        })
      None =>
        grouped.set(name, {
          name,
          count: 1U,
          total_bytes,
          payload_bytes,
          content_bytes,
        })
    }
  }
  let out : Array[CustomSectionBreakdown] = []
  grouped.each((_, value) => out.push(value))
  out.sort_by((a, b) => if a.total_bytes > b.total_bytes {
    -1
  } else if a.total_bytes < b.total_bytes {
    1
  } else if a.count > b.count {
    -1
  } else if a.count < b.count {
    1
  } else {
    a.name.compare(b.name)
  })
  out
}

///|
fn to_hex_digit(v : Int) -> Char {
  match v {
    0 => '0'
    1 => '1'
    2 => '2'
    3 => '3'
    4 => '4'
    5 => '5'
    6 => '6'
    7 => '7'
    8 => '8'
    9 => '9'
    10 => 'a'
    11 => 'b'
    12 => 'c'
    13 => 'd'
    14 => 'e'
    15 => 'f'
    _ => '0'
  }
}

///|
fn format_opcode_hex(opcode : UInt) -> String {
  let value = (opcode & 0xffU).reinterpret_as_int()
  let hi = value / 16
  let lo = value % 16
  String::from_array(['0', 'x', to_hex_digit(hi), to_hex_digit(lo)])
}

///|
fn parse_prefixed_opcode_subopcode(
  instr_bytes : Bytes,
  span : InstrSpan,
) -> UInt? {
  if span.opcode != 0xfcU && span.opcode != 0xfdU {
    return None
  }
  if span.end_ <= span.start + 1 {
    return None
  }
  let parser = Cursor::new(instr_bytes)
  parser.set_pos(span.start + 1)
  let result = try? parser.read_u32_leb128()
  match result {
    Ok(v) => if parser.get_pos() <= span.end_ { Some(v) } else { None }
    Err(_) => None
  }
}

///|
fn opcode_stat_key(opcode : UInt, subopcode : UInt?) -> String {
  let base = format_opcode_hex(opcode)
  if opcode == 0xfcU || opcode == 0xfdU {
    match subopcode {
      Some(v) => base + "." + v.to_string()
      None => base
    }
  } else {
    base
  }
}

///|
fn opcode_mnemonic_or_key(
  opcode : UInt,
  subopcode : UInt?,
  key : String,
) -> String {
  match opcode {
    0x00U => "unreachable"
    0x01U => "nop"
    0x02U => "block"
    0x03U => "loop"
    0x04U => "if"
    0x05U => "else"
    0x0bU => "end"
    0x0cU => "br"
    0x0dU => "br_if"
    0x0eU => "br_table"
    0x0fU => "return"
    0x10U => "call"
    0x11U => "call_indirect"
    0x1aU => "drop"
    0x1bU => "select"
    0x20U => "local.get"
    0x21U => "local.set"
    0x22U => "local.tee"
    0x23U => "global.get"
    0x24U => "global.set"
    0x28U => "i32.load"
    0x36U => "i32.store"
    0x3fU => "memory.size"
    0x40U => "memory.grow"
    0x41U => "i32.const"
    0x42U => "i64.const"
    0x43U => "f32.const"
    0x44U => "f64.const"
    0x45U => "i32.eqz"
    0x46U => "i32.eq"
    0x47U => "i32.ne"
    0x48U => "i32.lt_s"
    0x49U => "i32.lt_u"
    0x4aU => "i32.gt_s"
    0x4bU => "i32.gt_u"
    0x4cU => "i32.le_s"
    0x4dU => "i32.le_u"
    0x4eU => "i32.ge_s"
    0x4fU => "i32.ge_u"
    0x67U => "i32.clz"
    0x68U => "i32.ctz"
    0x69U => "i32.popcnt"
    0x6aU => "i32.add"
    0x6bU => "i32.sub"
    0x6cU => "i32.mul"
    0x71U => "i32.and"
    0x72U => "i32.or"
    0x73U => "i32.xor"
    0x74U => "i32.shl"
    0x75U => "i32.shr_s"
    0x76U => "i32.shr_u"
    0xd0U => "ref.null"
    0xd1U => "ref.is_null"
    0xd2U => "ref.func"
    0xfcU =>
      match subopcode {
        Some(0U) => "i32.trunc_sat_f32_s"
        Some(1U) => "i32.trunc_sat_f32_u"
        Some(2U) => "i32.trunc_sat_f64_s"
        Some(3U) => "i32.trunc_sat_f64_u"
        Some(4U) => "i64.trunc_sat_f32_s"
        Some(5U) => "i64.trunc_sat_f32_u"
        Some(6U) => "i64.trunc_sat_f64_s"
        Some(7U) => "i64.trunc_sat_f64_u"
        Some(8U) => "memory.init"
        Some(9U) => "data.drop"
        Some(10U) => "memory.copy"
        Some(11U) => "memory.fill"
        Some(12U) => "table.init"
        Some(13U) => "elem.drop"
        Some(14U) => "table.copy"
        Some(15U) => "table.grow"
        Some(16U) => "table.size"
        Some(17U) => "table.fill"
        _ => key
      }
    0xfdU =>
      match subopcode {
        Some(0U) => "v128.load"
        Some(11U) => "v128.store"
        _ => key
      }
    _ => key
  }
}

///|
priv struct OpcodeCounter {
  opcode : UInt
  subopcode : UInt?
  count : UInt
  total_bytes : UInt
}

///|
fn compare_function_size(a : FunctionSize, b : FunctionSize) -> Int {
  if a.body_bytes > b.body_bytes {
    -1
  } else if a.body_bytes < b.body_bytes {
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
fn compare_code_block_size(a : CodeBlockSize, b : CodeBlockSize) -> Int {
  if a.total_bytes > b.total_bytes {
    -1
  } else if a.total_bytes < b.total_bytes {
    1
  } else if a.function_index < b.function_index {
    -1
  } else if a.function_index > b.function_index {
    1
  } else if a.block_index < b.block_index {
    -1
  } else if a.block_index > b.block_index {
    1
  } else {
    0
  }
}

///|
fn push_unique_u32_with_seen(
  out : Array[UInt],
  seen : Map[UInt, Bool],
  value : UInt,
) -> Unit {
  if seen.get(value) is Some(_) {
    return
  }
  seen.set(value, true)
  out.push(value)
}

///|
fn push_function_size_with_limit(
  out : Array[FunctionSize],
  entry : FunctionSize,
  top_limit : UInt,
) -> Unit {
  if top_limit == 0U {
    out.push(entry)
    return
  }
  if out.length().reinterpret_as_uint() < top_limit {
    out.push(entry)
    return
  }
  let mut worst = 0
  for i in 1..<out.length() {
    if compare_function_size(out[worst], out[i]) < 0 {
      worst = i
    }
  }
  if compare_function_size(entry, out[worst]) < 0 {
    out[worst] = entry
  }
}

///|
fn push_code_block_size_with_limit(
  out : Array[CodeBlockSize],
  entry : CodeBlockSize,
  top_limit : UInt,
) -> Unit {
  if top_limit == 0U {
    out.push(entry)
    return
  }
  if out.length().reinterpret_as_uint() < top_limit {
    out.push(entry)
    return
  }
  let mut worst = 0
  for i in 1..<out.length() {
    if compare_code_block_size(out[worst], out[i]) < 0 {
      worst = i
    }
  }
  if compare_code_block_size(entry, out[worst]) < 0 {
    out[worst] = entry
  }
}

///|
fn add_opcode_counter_base(
  grouped : Map[UInt, OpcodeCounter],
  opcode : UInt,
  span_size : UInt,
) -> Unit {
  match grouped.get(opcode) {
    Some(prev) =>
      grouped.set(opcode, {
        opcode,
        subopcode: None,
        count: prev.count + 1U,
        total_bytes: prev.total_bytes + span_size,
      })
    None =>
      grouped.set(opcode, {
        opcode,
        subopcode: None,
        count: 1U,
        total_bytes: span_size,
      })
  }
}

///|
fn add_opcode_counter_prefixed(
  grouped : Map[String, OpcodeCounter],
  opcode : UInt,
  subopcode : UInt?,
  span_size : UInt,
) -> Unit {
  let key = opcode_stat_key(opcode, subopcode)
  match grouped.get(key) {
    Some(prev) =>
      grouped.set(key, {
        opcode,
        subopcode,
        count: prev.count + 1U,
        total_bytes: prev.total_bytes + span_size,
      })
    None =>
      grouped.set(key, { opcode, subopcode, count: 1U, total_bytes: span_size })
  }
}

///|
fn opcode_stats_from_counters(
  base_grouped : Map[UInt, OpcodeCounter],
  prefixed_grouped : Map[String, OpcodeCounter],
) -> Array[OpcodeStat] {
  let out : Array[OpcodeStat] = []
  base_grouped.each((_opcode, counter) => {
    let key = format_opcode_hex(counter.opcode)
    out.push({
      key,
      mnemonic: opcode_mnemonic_or_key(counter.opcode, None, key),
      count: counter.count,
      total_bytes: counter.total_bytes,
    })
  })
  prefixed_grouped.each((key, counter) => out.push({
    key,
    mnemonic: opcode_mnemonic_or_key(counter.opcode, counter.subopcode, key),
    count: counter.count,
    total_bytes: counter.total_bytes,
  }))
  out.sort_by((a, b) => if a.total_bytes > b.total_bytes {
    -1
  } else if a.total_bytes < b.total_bytes {
    1
  } else if a.count > b.count {
    -1
  } else if a.count < b.count {
    1
  } else {
    a.key.compare(b.key)
  })
  out
}

///|
pub fn analyze_wasm_breakdown(
  bytes : Bytes,
  top_limit? : UInt = 0U,
) -> Result[WasmBreakdownReport, WiteError] {
  try? {
    let sections = parse_core_sections_raise(bytes)
    let section_sizes = summarize_sections(sections, false)
    let custom_sections = summarize_custom_sections_raise(sections, bytes)
    let export_names : Map[UInt, Array[String]] = {}
    let function_names : Map[UInt, String] = {}
    let roots : Array[UInt] = []
    let root_seen : Map[UInt, Bool] = {}
    let mut imported_function_count = 0U
    let mut local_function_count = 0U
    let mut code_bodies : Array[Bytes] = []
    let mut callgraph_partial = false
    for section in sections {
      let payload = bytes[section.payload_start:section.section_end].to_bytes()
      match section.section_id {
        2U => imported_function_count += parse_import_function_count(payload)
        3U => local_function_count = parse_vec_count(payload)
        7U => {
          let parsed = parse_export_function_names(payload)
          merge_export_function_names(export_names, parsed)
          parsed.each((index, _names) => push_unique_u32_with_seen(
            roots, root_seen, index,
          ))
        }
        8U =>
          push_unique_u32_with_seen(
            roots,
            root_seen,
            parse_start_function_index(payload),
          )
        6U => {
          let refs_result = try? parse_global_section_function_refs_raise(
            payload,
          )
          match refs_result {
            Ok(indices) =>
              for index in indices {
                push_unique_u32_with_seen(roots, root_seen, index)
              }
            Err(_) => callgraph_partial = true
          }
        }
        9U => {
          let refs_result = try? parse_element_section_function_refs_raise(
            payload,
          )
          match refs_result {
            Ok(indices) =>
              for index in indices {
                push_unique_u32_with_seen(roots, root_seen, index)
              }
            Err(_) => callgraph_partial = true
          }
        }
        10U => code_bodies = parse_code_bodies(payload)
        0U =>
          match section.custom_name {
            Some(name) =>
              if name == "name" {
                parse_name_section_function_names(payload).each((
                  index,
                  function_name,
                ) => function_names.set(index, function_name))
              }
            None => ()
          }
        _ => ()
      }
    }
    if code_bodies.length().reinterpret_as_uint() != local_function_count {
      raise WiteError::InvalidFormat(
        "function/code section count mismatch: function=" +
        local_function_count.to_string() +
        " code=" +
        code_bodies.length().to_string(),
      )
    }
    let top_functions : Array[FunctionSize] = []
    let top_blocks : Array[CodeBlockSize] = []
    let local_function_indices : Array[UInt] = []
    let direct_callees_map : Map[UInt, Array[UInt]] = {}
    let body_bytes_map : Map[UInt, UInt] = {}
    let base_opcode_grouped : Map[UInt, OpcodeCounter] = {}
    let prefixed_opcode_grouped : Map[String, OpcodeCounter] = {}
    let mut block_count = 0U
    let mut instruction_count = 0U
    let mut instruction_bytes = 0U
    let mut opcode_partial = false
    let mut has_indirect_calls = false
    for i in 0..<code_bodies.length() {
      let function_index = imported_function_count + i.reinterpret_as_uint()
      let body = code_bodies[i]
      let body_bytes = body.length().reinterpret_as_uint()
      let exports = match export_names.get(function_index) {
        Some(v) => v
        None => []
      }
      local_function_indices.push(function_index)
      body_bytes_map.set(function_index, body_bytes)
      push_function_size_with_limit(
        top_functions,
        {
          function_index,
          body_bytes,
          name: function_names.get(function_index),
          export_names: exports,
        },
        top_limit,
      )
      let mut direct_callees : Array[UInt] = []
      let prefix_result = try? parse_local_decl_prefix_end(body)
      match prefix_result {
        Ok(prefix_end) => {
          let instr_bytes = body[prefix_end:body.length()].to_bytes()
          instruction_bytes += instr_bytes.length().reinterpret_as_uint()
          match parse_instruction_spans(instr_bytes) {
            Some(spans) => {
              instruction_count += spans.length().reinterpret_as_uint()
              let (function_blocks, complete) = collect_function_code_blocks(
                function_index,
                function_names.get(function_index),
                exports,
                instr_bytes,
                spans,
              )
              block_count += function_blocks.length().reinterpret_as_uint()
              for block in function_blocks {
                push_code_block_size_with_limit(top_blocks, block, top_limit)
              }
              if not(complete) {
                opcode_partial = true
              }
              let (callees, body_has_indirect) = collect_direct_callees(
                instr_bytes, spans,
              )
              direct_callees = callees
              if body_has_indirect {
                has_indirect_calls = true
              }
              for span in spans {
                let span_size = (span.end_ - span.start).reinterpret_as_uint()
                if span.opcode == 0xfcU || span.opcode == 0xfdU {
                  add_opcode_counter_prefixed(
                    prefixed_opcode_grouped,
                    span.opcode,
                    parse_prefixed_opcode_subopcode(instr_bytes, span),
                    span_size,
                  )
                } else {
                  add_opcode_counter_base(
                    base_opcode_grouped,
                    span.opcode,
                    span_size,
                  )
                }
              }
            }
            None => {
              opcode_partial = true
              callgraph_partial = true
            }
          }
        }
        Err(_) => {
          opcode_partial = true
          callgraph_partial = true
        }
      }
      direct_callees_map.set(function_index, direct_callees)
    }
    top_functions.sort_by(compare_function_size)
    top_blocks.sort_by(compare_code_block_size)
    let opcodes = opcode_stats_from_counters(
      base_opcode_grouped, prefixed_opcode_grouped,
    )
    let visited : Map[UInt, Bool] = {}
    let queue = roots.copy()
    let mut head = 0
    while head < queue.length() {
      let index = queue[head]
      head += 1
      if visited.get(index) is Some(_) {
        continue
      }
      visited.set(index, true)
      match direct_callees_map.get(index) {
        Some(callees) =>
          for callee in callees {
            if visited.get(callee) is None {
              queue.push(callee)
            }
          }
        None => ()
      }
    }
    let mut reachable_body_bytes = 0U
    let mut dead_body_bytes = 0U
    for function_index in local_function_indices {
      let body_bytes = match body_bytes_map.get(function_index) {
        Some(v) => v
        None => 0U
      }
      if visited.get(function_index) is Some(_) {
        reachable_body_bytes += body_bytes
      } else {
        dead_body_bytes += body_bytes
      }
    }
    {
      total_bytes: bytes.length().reinterpret_as_uint(),
      sections: section_sizes,
      custom_sections,
      imported_function_count,
      local_function_count,
      top_functions,
      block_count,
      top_blocks,
      instruction_count,
      instruction_bytes,
      opcode_partial,
      opcodes,
      callgraph_partial,
      has_indirect_calls,
      reachable_body_bytes,
      dead_body_bytes,
    }
  }
}

///|
fn should_include_export_root(
  names : Array[String],
  export_root_names : Array[String]?,
) -> Bool {
  match export_root_names {
    Some(allowed) => names.any(name => allowed.contains(name))
    None => true
  }
}

///|
fn analyze_call_graph_raise(
  bytes : Bytes,
  export_root_names : Array[String]?,
) -> CallGraphReport raise WiteError {
  let sections = parse_core_sections_raise(bytes)
  let mut imported_function_count = 0U
  let mut local_function_count = 0U
  let mut code_bodies : Array[Bytes] = []
  let export_names : Map[UInt, Array[String]] = {}
  let function_names : Map[UInt, String] = {}
  let roots : Array[UInt] = []
  let root_seen : Map[UInt, Bool] = {}
  let mut partial = false
  for section in sections {
    let payload = bytes[section.payload_start:section.section_end].to_bytes()
    match section.section_id {
      2U => imported_function_count += parse_import_function_count(payload)
      3U => local_function_count += parse_vec_count(payload)
      7U => {
        let parsed = parse_export_function_names(payload)
        merge_export_function_names(export_names, parsed)
        parsed.each((index, names) => if should_include_export_root(
            names, export_root_names,
          ) {
          push_unique_u32_with_seen(roots, root_seen, index)
        })
      }
      8U => {
        let start_index = parse_start_function_index(payload)
        push_unique_u32_with_seen(roots, root_seen, start_index)
      }
      6U => {
        let refs_result = try? parse_global_section_function_refs_raise(payload)
        match refs_result {
          Ok(indices) =>
            for index in indices {
              push_unique_u32_with_seen(roots, root_seen, index)
            }
          Err(_) => partial = true
        }
      }
      9U => {
        let refs_result = try? parse_element_section_function_refs_raise(
          payload,
        )
        match refs_result {
          Ok(indices) =>
            for index in indices {
              push_unique_u32_with_seen(roots, root_seen, index)
            }
          Err(_) => partial = true
        }
      }
      10U => code_bodies = parse_code_bodies(payload)
      0U =>
        match section.custom_name {
          Some(name) =>
            if name == "name" {
              parse_name_section_function_names(payload).each((
                index,
                function_name,
              ) => function_names.set(index, function_name))
            }
          None => ()
        }
      _ => ()
    }
  }
  if code_bodies.length().reinterpret_as_uint() != local_function_count {
    raise WiteError::InvalidFormat(
      "function/code section count mismatch: function=" +
      local_function_count.to_string() +
      " code=" +
      code_bodies.length().to_string(),
    )
  }
  let nodes : Array[CallGraphNode] = []
  let index_to_pos : Map[UInt, Int] = {}
  let mut has_indirect_calls = false
  for i in 0..<code_bodies.length() {
    let function_index = imported_function_count + i.reinterpret_as_uint()
    let body = code_bodies[i]
    let mut direct_callees : Array[UInt] = []
    let direct_result = try? collect_direct_callees_from_body_raise(body)
    match direct_result {
      Ok((callees, body_has_indirect)) => {
        direct_callees = callees
        if body_has_indirect {
          has_indirect_calls = true
        }
      }
      Err(_) => partial = true
    }
    index_to_pos.set(function_index, nodes.length())
    nodes.push({
      function_index,
      body_bytes: body.length().reinterpret_as_uint(),
      name: function_names.get(function_index),
      export_names: match export_names.get(function_index) {
        Some(v) => v
        None => []
      },
      direct_callees,
      reachable_from_roots: false,
    })
  }
  let total_function_count_u = imported_function_count + local_function_count
  let total_function_count = UInt::reinterpret_as_int(total_function_count_u)
  if total_function_count < 0 {
    raise WiteError::InvalidFormat(
      "function count overflow in analyze-call-graph",
    )
  }
  let visited = make_bool_array(total_function_count, false)
  let queue = roots.copy()
  let mut head = 0
  while head < queue.length() {
    let index = queue[head]
    head += 1
    if not(mark_visited_function_index(visited, index)) {
      continue
    }
    match index_to_pos.get(index) {
      Some(pos) =>
        for callee in nodes[pos].direct_callees {
          if not(is_visited_function_index(visited, callee)) {
            queue.push(callee)
          }
        }
      None => ()
    }
  }
  let mut reachable_body_bytes = 0U
  let mut dead_body_bytes = 0U
  for i in 0..<nodes.length() {
    let node = nodes[i]
    let reachable = is_visited_function_index(visited, node.function_index)
    if reachable {
      reachable_body_bytes += node.body_bytes
    } else {
      dead_body_bytes += node.body_bytes
    }
    nodes[i] = {
      function_index: node.function_index,
      body_bytes: node.body_bytes,
      name: node.name,
      export_names: node.export_names,
      direct_callees: node.direct_callees,
      reachable_from_roots: reachable,
    }
  }
  {
    imported_function_count,
    local_function_count,
    roots,
    has_indirect_calls,
    partial,
    reachable_body_bytes,
    dead_body_bytes,
    nodes,
  }
}

///|
fn analyze_call_graph_summary_raise(
  bytes : Bytes,
) -> CallGraphSummary raise WiteError {
  let sections = parse_core_sections_raise(bytes)
  let mut imported_function_count = 0U
  let mut local_function_count = 0U
  let mut code_bodies : Array[Bytes] = []
  let roots : Array[UInt] = []
  let root_seen : Map[UInt, Bool] = {}
  let mut partial = false
  for section in sections {
    let payload = bytes[section.payload_start:section.section_end].to_bytes()
    match section.section_id {
      2U => imported_function_count += parse_import_function_count(payload)
      3U => local_function_count += parse_vec_count(payload)
      7U =>
        for index in parse_export_indices_by_kind(payload, 0U) {
          push_unique_u32_with_seen(roots, root_seen, index)
        }
      8U =>
        push_unique_u32_with_seen(
          roots,
          root_seen,
          parse_start_function_index(payload),
        )
      6U => {
        let refs_result = try? parse_global_section_function_refs_raise(payload)
        match refs_result {
          Ok(indices) =>
            for index in indices {
              push_unique_u32_with_seen(roots, root_seen, index)
            }
          Err(_) => partial = true
        }
      }
      9U => {
        let refs_result = try? parse_element_section_function_refs_raise(
          payload,
        )
        match refs_result {
          Ok(indices) =>
            for index in indices {
              push_unique_u32_with_seen(roots, root_seen, index)
            }
          Err(_) => partial = true
        }
      }
      10U => code_bodies = parse_code_bodies(payload)
      _ => ()
    }
  }
  if code_bodies.length().reinterpret_as_uint() != local_function_count {
    raise WiteError::InvalidFormat(
      "function/code section count mismatch: function=" +
      local_function_count.to_string() +
      " code=" +
      code_bodies.length().to_string(),
    )
  }
  let local_body_bytes : Array[UInt] = []
  let direct_callees_by_local : Array[Array[UInt]] = []
  let mut has_indirect_calls = false
  for body in code_bodies {
    local_body_bytes.push(body.length().reinterpret_as_uint())
    let mut direct_callees : Array[UInt] = []
    let direct_result = try? collect_direct_callees_from_body_raise(body)
    match direct_result {
      Ok((callees, body_has_indirect)) => {
        direct_callees = callees
        if body_has_indirect {
          has_indirect_calls = true
        }
      }
      Err(_) => partial = true
    }
    direct_callees_by_local.push(direct_callees)
  }
  let total_function_count_u = imported_function_count + local_function_count
  let total_function_count = UInt::reinterpret_as_int(total_function_count_u)
  if total_function_count < 0 {
    raise WiteError::InvalidFormat(
      "function count overflow in analyze-call-graph-summary",
    )
  }
  let visited = make_bool_array(total_function_count, false)
  let queue = roots.copy()
  let mut head = 0
  while head < queue.length() {
    let index = queue[head]
    head += 1
    if not(mark_visited_function_index(visited, index)) {
      continue
    }
    if index < imported_function_count {
      continue
    }
    let local_index = index - imported_function_count
    let pos = UInt::reinterpret_as_int(local_index)
    if pos < 0 || pos >= direct_callees_by_local.length() {
      continue
    }
    for callee in direct_callees_by_local[pos] {
      if not(is_visited_function_index(visited, callee)) {
        queue.push(callee)
      }
    }
  }
  let mut reachable_function_count = 0U
  let mut reachable_body_bytes = 0U
  let mut dead_body_bytes = 0U
  for i in 0..<local_body_bytes.length() {
    let function_index = imported_function_count + i.reinterpret_as_uint()
    if is_visited_function_index(visited, function_index) {
      reachable_function_count += 1U
      reachable_body_bytes += local_body_bytes[i]
    } else {
      dead_body_bytes += local_body_bytes[i]
    }
  }
  {
    imported_function_count,
    local_function_count,
    roots,
    has_indirect_calls,
    partial,
    reachable_function_count,
    dead_function_count: local_function_count - reachable_function_count,
    reachable_body_bytes,
    dead_body_bytes,
  }
}

///|
pub fn analyze_call_graph(bytes : Bytes) -> Result[CallGraphReport, WiteError] {
  try? analyze_call_graph_raise(bytes, None)
}

///|
pub fn analyze_call_graph_summary(
  bytes : Bytes,
) -> Result[CallGraphSummary, WiteError] {
  try? analyze_call_graph_summary_raise(bytes)
}

///|
fn compare_host_code_hint(a : HostCodeHint, b : HostCodeHint) -> Int {
  if a.function_index < b.function_index {
    -1
  } else if a.function_index > b.function_index {
    1
  } else {
    a.kind.compare(b.kind)
  }
}

///|
fn size_gain_bytes(before_size : UInt, after_size : UInt) -> UInt {
  if before_size > after_size {
    before_size - after_size
  } else {
    0U
  }
}

///|
fn size_regression_bytes(before_size : UInt, after_size : UInt) -> UInt {
  if after_size > before_size {
    after_size - before_size
  } else {
    0U
  }
}

///|
pub fn analyze_host_generated_code(
  bytes : Bytes,
) -> Result[HostGeneratedCodeReport, WiteError] {
  try? {
    let sections = parse_core_sections_raise(bytes)
    let mut type_payload : Bytes? = None
    let mut import_payload : Bytes? = None
    let mut function_payload : Bytes? = None
    let mut code_payload : Bytes? = None
    let export_names : Map[UInt, Array[String]] = {}
    let function_names : Map[UInt, String] = {}
    for section in sections {
      let payload = bytes[section.payload_start:section.section_end].to_bytes()
      match section.section_id {
        1U => type_payload = Some(payload)
        2U => import_payload = Some(payload)
        3U => function_payload = Some(payload)
        7U => {
          let parsed = parse_export_function_names(payload)
          merge_export_function_names(export_names, parsed)
        }
        10U => code_payload = Some(payload)
        0U =>
          match section.custom_name {
            Some(name) =>
              if name == "name" {
                parse_name_section_function_names(payload).each((
                  index,
                  function_name,
                ) => function_names.set(index, function_name))
              }
            None => ()
          }
        _ => ()
      }
    }
    let imported_function_type_indices = match import_payload {
      Some(payload) => parse_import_function_type_indices(payload)
      None => []
    }
    let imported_function_count = imported_function_type_indices
      .length()
      .reinterpret_as_uint()
    let mut local_function_count = 0U
    let mut param_forwarding_thunk_count = 0U
    let mut const_forwarding_thunk_count = 0U
    let mut signature_refinable_thunk_count = 0U
    let hints : Array[HostCodeHint] = []
    match (type_payload, function_payload, code_payload) {
      (Some(type_payload), Some(function_payload), Some(code_payload)) => {
        let local_function_type_indices = parse_function_type_indices(
          function_payload,
        )
        local_function_count = local_function_type_indices
          .length()
          .reinterpret_as_uint()
        let code_bodies = parse_code_bodies(code_payload)
        if local_function_type_indices.length() != code_bodies.length() {
          raise WiteError::InvalidFormat(
            "function/code section count mismatch for analyze-host: function=" +
            local_function_type_indices.length().to_string() +
            " code=" +
            code_bodies.length().to_string(),
          )
        }
        let function_type_by_index = imported_function_type_indices.copy()
        function_type_by_index.append(local_function_type_indices[:])
        let parsed_type_entries = parse_type_section_entries_with_refs_raise(
          type_payload, "analyze-host",
        )
        let type_count_u = parsed_type_entries.length().reinterpret_as_uint()
        let gc_type_canonical_map = collect_gc_type_canonical_map_from_entries_raise(
          parsed_type_entries,
        )
        let function_type_entry_by_type_index : Map[UInt, FunctionTypeEntry] = {}
        for i in 0..<parsed_type_entries.length() {
          if parsed_type_entries[i].form == 0x60U {
            function_type_entry_by_type_index.set(
              i.reinterpret_as_uint(),
              parse_function_type_entry_from_raw_raise(
                parsed_type_entries[i].raw,
                "analyze-host",
              ),
            )
          }
        }
        let function_param_count_by_index : Array[UInt] = []
        for type_index in function_type_by_index {
          if type_index >= type_count_u {
            raise WiteError::InvalidFormat(
              "type index out of range in analyze-host: " +
              type_index.to_string(),
            )
          }
          let type_pos = UInt::reinterpret_as_int(type_index)
          if type_pos < 0 || type_pos >= parsed_type_entries.length() {
            raise WiteError::InvalidFormat(
              "type index position out of range in analyze-host: " +
              type_index.to_string(),
            )
          }
          if parsed_type_entries[type_pos].form != 0x60U {
            raise WiteError::InvalidFormat(
              "non-function type index used by function in analyze-host: " +
              type_index.to_string(),
            )
          }
          function_param_count_by_index.push(
            parse_function_type_param_count_from_raw_raise(
              parsed_type_entries[type_pos].raw,
              "analyze-host",
            ),
          )
        }
        let param_alias_map = collect_call_forwarding_alias_map(
          code_bodies, imported_function_count, function_type_by_index, function_type_entry_by_type_index,
          function_param_count_by_index, gc_type_canonical_map,
        )
        param_alias_map.each((function_index, target_function_index) => {
          param_forwarding_thunk_count += 1U
          hints.push({
            kind: "param-forward",
            function_index,
            function_name: function_names.get(function_index),
            target_function_index,
            target_function_name: function_names.get(target_function_index),
            export_names: match export_names.get(function_index) {
              Some(v) => v
              None => []
            },
            appended_i32_const_count: 0U,
            dropped_param_count: 0U,
          })
        })
        let const_alias_map = collect_const_call_forwarding_alias_map(
          code_bodies, imported_function_count, function_type_by_index, function_type_entry_by_type_index,
          gc_type_canonical_map,
        )
        const_alias_map.each((function_index, alias_info) => {
          const_forwarding_thunk_count += 1U
          hints.push({
            kind: "const-forward",
            function_index,
            function_name: function_names.get(function_index),
            target_function_index: alias_info.target,
            target_function_name: function_names.get(alias_info.target),
            export_names: match export_names.get(function_index) {
              Some(v) => v
              None => []
            },
            appended_i32_const_count: alias_info.appended_i32_const_instrs
            .length()
            .reinterpret_as_uint(),
            dropped_param_count: 0U,
          })
        })
        let signature_alias_map = collect_signature_refine_alias_map(
          code_bodies, imported_function_count, function_type_by_index, function_type_entry_by_type_index,
          gc_type_canonical_map,
        )
        signature_alias_map.each((function_index, alias_info) => {
          signature_refinable_thunk_count += 1U
          hints.push({
            kind: "signature-refine",
            function_index,
            function_name: function_names.get(function_index),
            target_function_index: alias_info.target,
            target_function_name: function_names.get(alias_info.target),
            export_names: match export_names.get(function_index) {
              Some(v) => v
              None => []
            },
            appended_i32_const_count: 0U,
            dropped_param_count: alias_info.dropped_param_count,
          })
        })
      }
      _ => ()
    }
    hints.sort_by(compare_host_code_hint)
    let directize_result = apply_directize_raise(bytes)
    let dce_report = match analyze_dce_report(bytes) {
      Ok(v) => v
      Err(e) => raise e
    }
    {
      imported_function_count,
      local_function_count,
      param_forwarding_thunk_count,
      const_forwarding_thunk_count,
      signature_refinable_thunk_count,
      directize_candidate_call_count: directize_result.rewritten_call_count,
      dce_removable_function_count: dce_report.removable_function_count,
      dce_removable_body_bytes: dce_report.removable_body_bytes,
      dce_partial: dce_report.partial,
      hints,
    }
  }
}

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
  let stage = {
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

///|
fn export_root_names_from_config(config : OptimizeConfig) -> Array[String]? {
  if config.closed_world &&
    not(config.safe_mode) &&
    config.closed_world_root_exports.length() > 0 {
    Some(config.closed_world_root_exports)
  } else {
    None
  }
}

///|
fn collect_root_reasons_raise(
  bytes : Bytes,
  export_root_names : Array[String]?,
) -> (Map[UInt, Array[String]], Bool) raise WiteError {
  let reasons_map : Map[UInt, Array[String]] = {}
  let sections = parse_core_sections_raise(bytes)
  let mut partial = false
  for section in sections {
    let payload = bytes[section.payload_start:section.section_end].to_bytes()
    match section.section_id {
      7U => {
        let exports = parse_export_function_names(payload)
        exports.each((index, names) => if should_include_export_root(
            names, export_root_names,
          ) {
          for export_name in names {
            map_push_string_array(reasons_map, index, "export:" + export_name)
          }
        })
      }
      8U => {
        let start_index = parse_start_function_index(payload)
        map_push_string_array(reasons_map, start_index, "start")
      }
      6U => {
        let result = try? parse_global_section_function_refs_raise(payload)
        match result {
          Ok(indices) =>
            for index in indices {
              map_push_string_array(reasons_map, index, "global-ref.func")
            }
          Err(_) => partial = true
        }
      }
      9U => {
        let result = try? parse_element_section_function_refs_raise(payload)
        match result {
          Ok(indices) =>
            for index in indices {
              map_push_string_array(reasons_map, index, "element-ref.func")
            }
          Err(_) => partial = true
        }
      }
      _ => ()
    }
  }
  (reasons_map, partial)
}

///|
fn build_retain_path_from_parent_map(
  target : UInt,
  parent_map : Map[UInt, UInt],
) -> Array[UInt] {
  let reversed : Array[UInt] = [target]
  let mut current = target
  while true {
    match parent_map.get(current) {
      Some(parent) => {
        reversed.push(parent)
        current = parent
      }
      None => break
    }
  }
  let path : Array[UInt] = []
  for i in 0..<reversed.length() {
    path.push(reversed[reversed.length() - 1 - i])
  }
  path
}

///|
fn compare_retain_path_entry(a : RetainPathEntry, b : RetainPathEntry) -> Int {
  if a.function_index < b.function_index {
    -1
  } else if a.function_index > b.function_index {
    1
  } else {
    0
  }
}

///|
pub fn analyze_keep_reasons(
  bytes : Bytes,
  config? : OptimizeConfig = OptimizeConfig::default(),
) -> Result[KeepReasonReport, WiteError] {
  try? {
    let export_root_names = export_root_names_from_config(config)
    let graph = analyze_call_graph_raise(bytes, export_root_names)
    let (reasons_map, reasons_partial) = collect_root_reasons_raise(
      bytes, export_root_names,
    )
    let index_to_pos : Map[UInt, Int] = {}
    for i in 0..<graph.nodes.length() {
      index_to_pos.set(graph.nodes[i].function_index, i)
    }
    let visited : Map[UInt, Bool] = {}
    let parent_map : Map[UInt, UInt] = {}
    let queue = graph.roots.copy()
    let mut head = 0
    while head < queue.length() {
      let current = queue[head]
      head += 1
      if visited.get(current) is Some(_) {
        continue
      }
      visited.set(current, true)
      match index_to_pos.get(current) {
        Some(pos) =>
          for callee in graph.nodes[pos].direct_callees {
            if visited.get(callee) is None {
              if parent_map.get(callee) is None {
                parent_map.set(callee, current)
              }
              queue.push(callee)
            }
          }
        None => ()
      }
    }
    let entries : Array[KeepReasonEntry] = []
    for node in graph.nodes {
      if node.reachable_from_roots {
        let reasons = match reasons_map.get(node.function_index) {
          Some(v) => v.copy()
          None => []
        }
        if reasons.length() == 0 {
          match parent_map.get(node.function_index) {
            Some(parent) => reasons.push("call:" + parent.to_string())
            None => reasons.push("reachable")
          }
        }
        reasons.sort()
        reasons.dedup()
        entries.push({
          function_index: node.function_index,
          name: node.name,
          export_names: node.export_names,
          reasons,
        })
      }
    }
    entries.sort_by((a, b) => if a.function_index < b.function_index {
      -1
    } else if a.function_index > b.function_index {
      1
    } else {
      0
    })
    { partial: graph.partial || reasons_partial, entries }
  }
}

///|
pub fn analyze_retain_paths(
  bytes : Bytes,
  config? : OptimizeConfig = OptimizeConfig::default(),
) -> Result[RetainPathReport, WiteError] {
  try? {
    let export_root_names = export_root_names_from_config(config)
    let graph = analyze_call_graph_raise(bytes, export_root_names)
    let (root_reasons_map, root_reason_partial) = collect_root_reasons_raise(
      bytes, export_root_names,
    )
    let index_to_pos : Map[UInt, Int] = {}
    for i in 0..<graph.nodes.length() {
      index_to_pos.set(graph.nodes[i].function_index, i)
    }
    let visited : Map[UInt, Bool] = {}
    let parent_map : Map[UInt, UInt] = {}
    let queue = graph.roots.copy()
    let mut head = 0
    while head < queue.length() {
      let current = queue[head]
      head += 1
      if visited.get(current) is Some(_) {
        continue
      }
      visited.set(current, true)
      match index_to_pos.get(current) {
        Some(pos) =>
          for callee in graph.nodes[pos].direct_callees {
            if visited.get(callee) is None {
              if parent_map.get(callee) is None {
                parent_map.set(callee, current)
              }
              queue.push(callee)
            }
          }
        None => ()
      }
    }
    let entries : Array[RetainPathEntry] = []
    for node in graph.nodes {
      if not(node.reachable_from_roots) {
        continue
      }
      let path = build_retain_path_from_parent_map(
        node.function_index,
        parent_map,
      )
      let root_index = if path.length() > 0 {
        path[0]
      } else {
        node.function_index
      }
      let root_reasons = match root_reasons_map.get(root_index) {
        Some(v) => v.copy()
        None => []
      }
      if root_reasons.length() == 0 {
        root_reasons.push("reachable")
      }
      root_reasons.sort()
      root_reasons.dedup()
      entries.push({
        function_index: node.function_index,
        name: node.name,
        export_names: node.export_names,
        body_bytes: node.body_bytes,
        root_reasons,
        path,
      })
    }
    entries.sort_by(compare_retain_path_entry)
    {
      partial: graph.partial || root_reason_partial,
      roots: graph.roots,
      entries,
    }
  }
}

///|
pub fn analyze_dce_report(bytes : Bytes) -> Result[DceReport, WiteError] {
  match analyze_call_graph(bytes) {
    Ok(graph) => {
      let removable_functions : Array[FunctionSize] = []
      for node in graph.nodes {
        if not(node.reachable_from_roots) {
          removable_functions.push({
            function_index: node.function_index,
            body_bytes: node.body_bytes,
            name: node.name,
            export_names: node.export_names,
          })
        }
      }
      removable_functions.sort_by((a, b) => if a.body_bytes > b.body_bytes {
        -1
      } else if a.body_bytes < b.body_bytes {
        1
      } else if a.function_index < b.function_index {
        -1
      } else if a.function_index > b.function_index {
        1
      } else {
        0
      })
      Ok({
        roots: graph.roots,
        partial: graph.partial,
        removable_function_count: removable_functions
        .length()
        .reinterpret_as_uint(),
        removable_body_bytes: graph.dead_body_bytes,
        removable_functions,
      })
    }
    Err(e) => Err(e)
  }
}
