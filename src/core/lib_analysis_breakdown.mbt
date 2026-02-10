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

