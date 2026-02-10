///|
fn parse_instruction_spans(instr_bytes : Bytes) -> Array[InstrSpan]? {
  let result = try? parse_instruction_spans_raise(instr_bytes)
  match result {
    Ok(v) => Some(v)
    Err(_) => None
  }
}

///|
fn decode_u32_leb128_bytes(bytes : Bytes) -> UInt? {
  let parser = Cursor::new(bytes)
  let result = try? parser.read_u32_leb128()
  match result {
    Ok(v) => if parser.eof() { Some(v) } else { None }
    Err(_) => None
  }
}

///|
fn decode_u32_leb128_range(bytes : Bytes, start : Int, end_ : Int) -> UInt? {
  if start < 0 || start >= end_ || end_ > bytes.length() {
    return None
  }
  let parser = Cursor::new(bytes)
  parser.set_pos(start)
  let result = try? parser.read_u32_leb128()
  match result {
    Ok(v) => if parser.get_pos() == end_ { Some(v) } else { None }
    Err(_) => None
  }
}

///|
fn collect_direct_callees(
  instr_bytes : Bytes,
  spans : Array[InstrSpan],
) -> (Array[UInt], Bool) {
  let callees : Array[UInt] = []
  let mut has_indirect = false
  for span in spans {
    if span.opcode == 0x10U {
      match decode_span_u32_immediate(instr_bytes, span) {
        Some(index) => push_unique_u32(callees, index)
        None => ()
      }
    } else if span.opcode == 0x11U {
      has_indirect = true
    }
  }
  (callees, has_indirect)
}

///|
fn collect_direct_callees_from_body_raise(
  body : Bytes,
) -> (Array[UInt], Bool) raise WiteError {
  let prefix_end = parse_local_decl_prefix_end(body)
  let parser = Cursor::new(body)
  parser.set_pos(prefix_end)
  let callees : Array[UInt] = []
  let mut has_indirect = false
  while not(parser.eof()) {
    let opcode = parser.read_byte().to_uint()
    match opcode {
      0x10U => push_unique_u32(callees, parser.read_u32_leb128())
      0x11U => {
        has_indirect = true
        ignore(parser.read_u32_leb128())
        ignore(parser.read_u32_leb128())
      }
      _ => skip_instruction_immediate_raise(parser, opcode)
    }
  }
  (callees, has_indirect)
}

///|
fn read_name_bytes(parser : Cursor) -> Bytes raise WiteError {
  let name_len_u = parser.read_u32_leb128()
  let name_len = UInt::reinterpret_as_int(name_len_u)
  if name_len < 0 {
    raise WiteError::InvalidFormat("name length overflow")
  }
  let start = parser.get_pos()
  let end_ = start + name_len
  if end_ > parser.bytes.length() {
    raise WiteError::UnexpectedEof
  }
  parser.set_pos(end_)
  parser.bytes[start:end_].to_bytes()
}

///|
fn append_name_bytes(out : Array[Byte], name : Bytes) -> Unit {
  out.append(encode_u32_leb128(name.length().reinterpret_as_uint())[:])
  out.append(name[:].to_array())
}

///|
fn remap_function_index_raise(
  index : UInt,
  index_map : Map[UInt, UInt],
) -> UInt raise WiteError {
  match index_map.get(index) {
    Some(v) => v
    None =>
      raise WiteError::InvalidFormat(
        "dce remap missing function index: " + index.to_string(),
      )
  }
}

///|
fn remap_type_index_raise(
  index : UInt,
  type_index_map : Map[UInt, UInt],
) -> UInt raise WiteError {
  match type_index_map.get(index) {
    Some(v) => v
    None =>
      raise WiteError::InvalidFormat(
        "type remap missing index: " + index.to_string(),
      )
  }
}

///|
fn read_val_type_bytes_raise(parser : Cursor) -> Bytes raise WiteError {
  let start = parser.get_pos()
  let code = parser.read_byte().to_uint()
  match code {
    0x7fU | 0x7eU | 0x7dU | 0x7cU | 0x7bU | 0x70U | 0x6fU => ()
    0x63U | 0x64U => skip_heap_type(parser)
    _ =>
      raise WiteError::InvalidFormat(
        "unsupported value type in global section: " + code.to_string(),
      )
  }
  let end_ = parser.get_pos()
  parser.bytes[start:end_].to_bytes()
}

///|
fn read_ref_type_bytes_raise(parser : Cursor) -> Bytes raise WiteError {
  let start = parser.get_pos()
  let code = parser.read_byte().to_uint()
  match code {
    0x70U | 0x6fU => ()
    0x63U | 0x64U => skip_heap_type(parser)
    _ =>
      raise WiteError::InvalidFormat(
        "unsupported reference type in element section: " + code.to_string(),
      )
  }
  let end_ = parser.get_pos()
  parser.bytes[start:end_].to_bytes()
}

///|
fn decode_heap_type_ref_index_bytes(heap_type_bytes : Bytes) -> UInt? {
  if heap_type_bytes.length() == 0 {
    return None
  }
  let last = heap_type_bytes[heap_type_bytes.length() - 1].to_uint()
  // Signed heaptype immediates with sign bit set are negative builtins.
  if (last & 0x40U) != 0U {
    return None
  }
  decode_u32_leb128_bytes(heap_type_bytes)
}

///|
fn decode_ref_type_index_from_type_bytes(type_bytes : Bytes) -> UInt? {
  if type_bytes.length() < 2 {
    return None
  }
  let code = type_bytes[0].to_uint()
  if code != 0x63U && code != 0x64U {
    return None
  }
  decode_heap_type_ref_index_bytes(type_bytes[1:type_bytes.length()].to_bytes())
}

///|
fn remap_gc_type_index_for_refine(
  index : UInt,
  gc_type_canonical_map : Map[UInt, UInt],
) -> UInt {
  match gc_type_canonical_map.get(index) {
    Some(v) => v
    None => index
  }
}

///|
fn type_bytes_equal_with_gc_canonical_map(
  left : Bytes,
  right : Bytes,
  gc_type_canonical_map : Map[UInt, UInt],
) -> Bool {
  if bytes_equal(left, right) {
    return true
  }
  if left.length() == 0 || right.length() == 0 {
    return false
  }
  let left_code = left[0].to_uint()
  let right_code = right[0].to_uint()
  if left_code != right_code {
    return false
  }
  let left_index = match decode_ref_type_index_from_type_bytes(left) {
    Some(v) => v
    None => return false
  }
  let right_index = match decode_ref_type_index_from_type_bytes(right) {
    Some(v) => v
    None => return false
  }
  remap_gc_type_index_for_refine(left_index, gc_type_canonical_map) ==
  remap_gc_type_index_for_refine(right_index, gc_type_canonical_map)
}

///|
fn read_storage_type_bytes_raise(
  parser : Cursor,
  context : String,
) -> Bytes raise WiteError {
  let start = parser.get_pos()
  let code = parser.read_byte().to_uint()
  match code {
    0x78U | 0x77U => ()
    0x7fU | 0x7eU | 0x7dU | 0x7cU | 0x7bU | 0x70U | 0x6fU => ()
    0x63U | 0x64U => skip_heap_type(parser)
    _ =>
      raise WiteError::InvalidFormat(
        "unsupported storage type in " + context + ": " + code.to_string(),
      )
  }
  let end_ = parser.get_pos()
  parser.bytes[start:end_].to_bytes()
}

///|
priv struct ParsedGcTypeField {
  storage_type : Bytes
  mutability : Byte
}

///|
priv struct ParsedGcTypeEntry {
  form : UInt
  fields : Array[ParsedGcTypeField]
}

///|
fn parse_gc_non_function_type_entry_from_raw_raise(
  raw : Bytes,
  context : String,
) -> ParsedGcTypeEntry raise WiteError {
  let parser = Cursor::new(raw)
  let form = parser.read_byte().to_uint()
  let fields : Array[ParsedGcTypeField] = []
  match form {
    0x5fU => {
      let field_count = parser.read_u32_leb128()
      for _ in 0U..<field_count {
        let storage_type = read_storage_type_bytes_raise(parser, context)
        let mutability = parser.read_byte().to_uint()
        if mutability > 1U {
          raise WiteError::InvalidFormat(
            "invalid field mutability in " +
            context +
            ": " +
            mutability.to_string(),
          )
        }
        fields.push({ storage_type, mutability: mutability.to_byte() })
      }
    }
    0x5eU => {
      let storage_type = read_storage_type_bytes_raise(parser, context)
      let mutability = parser.read_byte().to_uint()
      if mutability > 1U {
        raise WiteError::InvalidFormat(
          "invalid array field mutability in " +
          context +
          ": " +
          mutability.to_string(),
        )
      }
      fields.push({ storage_type, mutability: mutability.to_byte() })
    }
    _ =>
      raise WiteError::InvalidFormat(
        "unsupported gc type form in " + context + ": " + form.to_string(),
      )
  }
  if not(parser.eof()) {
    raise WiteError::InvalidFormat(
      "trailing bytes in gc type entry in " + context,
    )
  }
  { form, fields }
}

///|
fn gc_type_entries_equal_with_canonical_map_raise(
  left_raw : Bytes,
  right_raw : Bytes,
  gc_type_canonical_map : Map[UInt, UInt],
) -> Bool raise WiteError {
  if bytes_equal(left_raw, right_raw) {
    return true
  }
  let left = parse_gc_non_function_type_entry_from_raw_raise(
    left_raw, "type-refine-gc-compare",
  )
  let right = parse_gc_non_function_type_entry_from_raw_raise(
    right_raw, "type-refine-gc-compare",
  )
  if left.form != right.form || left.fields.length() != right.fields.length() {
    return false
  }
  for i in 0..<left.fields.length() {
    if left.fields[i].mutability != right.fields[i].mutability {
      return false
    }
    if not(
        type_bytes_equal_with_gc_canonical_map(
          left.fields[i].storage_type,
          right.fields[i].storage_type,
          gc_type_canonical_map,
        ),
      ) {
      return false
    }
  }
  true
}

///|
fn read_const_expr_bytes_raise(
  parser : Cursor,
  payload : Bytes,
) -> Bytes raise WiteError {
  let start = parser.get_pos()
  while true {
    let opcode = parser.read_byte().to_uint()
    skip_instruction_immediate_raise(parser, opcode)
    if opcode == 0x0bU {
      let end_ = parser.get_pos()
      return payload[start:end_].to_bytes()
    }
  }
  b""
}

///|
fn rewrite_const_expr_function_indices_raise(
  expr_bytes : Bytes,
  index_map : Map[UInt, UInt],
) -> Bytes raise WiteError {
  let spans = parse_instruction_spans_raise(expr_bytes)
  rewrite_instruction_function_indices_raise(expr_bytes, spans, index_map)
}

///|
fn push_unique_u32(out : Array[UInt], value : UInt) -> Unit {
  if not(out.contains(value)) {
    out.push(value)
  }
}

///|
fn make_bool_array(length : Int, value : Bool) -> Array[Bool] {
  let out : Array[Bool] = []
  for _ in 0..<length {
    out.push(value)
  }
  out
}

///|
fn is_visited_function_index(visited : Array[Bool], index : UInt) -> Bool {
  let pos = UInt::reinterpret_as_int(index)
  if pos < 0 || pos >= visited.length() {
    false
  } else {
    visited[pos]
  }
}

///|
fn mark_visited_function_index(visited : Array[Bool], index : UInt) -> Bool {
  let pos = UInt::reinterpret_as_int(index)
  if pos < 0 || pos >= visited.length() || visited[pos] {
    false
  } else {
    visited[pos] = true
    true
  }
}

///|
fn collect_ref_func_indices_from_expr_raise(
  expr_bytes : Bytes,
) -> Array[UInt] raise WiteError {
  let spans = parse_instruction_spans_raise(expr_bytes)
  let out : Array[UInt] = []
  for span in spans {
    if span.opcode == 0xd2U {
      match decode_span_u32_immediate(expr_bytes, span) {
        Some(index) => push_unique_u32(out, index)
        None =>
          raise WiteError::InvalidFormat(
            "failed to decode ref.func immediate in const expr",
          )
      }
    }
  }
  out
}

///|
fn collect_ref_func_indices_from_instruction_raise(
  instr_bytes : Bytes,
  spans : Array[InstrSpan],
) -> Array[UInt] raise WiteError {
  let out : Array[UInt] = []
  for span in spans {
    if span.opcode == 0xd2U {
      match decode_span_u32_immediate(instr_bytes, span) {
        Some(index) => push_unique_u32(out, index)
        None =>
          raise WiteError::InvalidFormat(
            "failed to decode ref.func immediate in code",
          )
      }
    }
  }
  out
}

///|
fn collect_ref_func_indices_from_code_section_raise(
  payload : Bytes,
) -> Array[UInt] raise WiteError {
  let out : Array[UInt] = []
  let bodies = parse_code_bodies(payload)
  for body in bodies {
    let prefix_end = parse_local_decl_prefix_end(body)
    let instr_bytes = body[prefix_end:body.length()].to_bytes()
    let spans = parse_instruction_spans_raise(instr_bytes)
    for
      index in collect_ref_func_indices_from_instruction_raise(
        instr_bytes, spans,
      ) {
      push_unique_u32(out, index)
    }
  }
  out
}

///|
fn collect_global_get_indices_from_expr_raise(
  expr_bytes : Bytes,
) -> Array[UInt] raise WiteError {
  let spans = parse_instruction_spans_raise(expr_bytes)
  let out : Array[UInt] = []
  for span in spans {
    if span.opcode == 0x23U {
      match decode_span_u32_immediate(expr_bytes, span) {
        Some(index) => push_unique_u32(out, index)
        None =>
          raise WiteError::InvalidFormat(
            "failed to decode global.get immediate in const expr",
          )
      }
    }
  }
  out
}

///|
fn remap_global_index_raise(
  index : UInt,
  global_index_map : Map[UInt, UInt],
) -> UInt raise WiteError {
  match global_index_map.get(index) {
    Some(v) => v
    None =>
      raise WiteError::InvalidFormat(
        "global remap missing index: " + index.to_string(),
      )
  }
}

///|
fn remap_memory_index_raise(
  index : UInt,
  memory_index_map : Map[UInt, UInt],
) -> UInt raise WiteError {
  match memory_index_map.get(index) {
    Some(v) => v
    None =>
      raise WiteError::InvalidFormat(
        "memory remap missing index: " + index.to_string(),
      )
  }
}

///|
fn rewrite_const_expr_global_indices_raise(
  expr_bytes : Bytes,
  global_index_map : Map[UInt, UInt],
) -> Bytes raise WiteError {
  let spans = parse_instruction_spans_raise(expr_bytes)
  let out : Array[Byte] = []
  for span in spans {
    if span.opcode == 0x23U {
      match decode_span_u32_immediate(expr_bytes, span) {
        Some(index) => {
          out.push(0x23U.to_byte())
          out.append(
            encode_u32_leb128(remap_global_index_raise(index, global_index_map))[:],
          )
        }
        None =>
          raise WiteError::InvalidFormat(
            "failed to decode global.get immediate",
          )
      }
    } else {
      out.append(expr_bytes[span.start:span.end_].to_array())
    }
  }
  Bytes::from_array(out[:])
}

///|
fn parse_global_section_function_refs_raise(
  payload : Bytes,
) -> Array[UInt] raise WiteError {
  let parser = Cursor::new(payload)
  let count = parser.read_u32_leb128()
  let out : Array[UInt] = []
  for _ in 0U..<count {
    ignore(read_val_type_bytes_raise(parser))
    ignore(parser.read_byte())
    let expr = read_const_expr_bytes_raise(parser, payload)
    for index in collect_ref_func_indices_from_expr_raise(expr) {
      push_unique_u32(out, index)
    }
  }
  out
}

///|
fn parse_element_section_function_refs_raise(
  payload : Bytes,
) -> Array[UInt] raise WiteError {
  let parser = Cursor::new(payload)
  let segment_count = parser.read_u32_leb128()
  let out : Array[UInt] = []
  for _ in 0U..<segment_count {
    let flags = parser.read_u32_leb128()
    match flags {
      0U => {
        let offset_expr = read_const_expr_bytes_raise(parser, payload)
        for index in collect_ref_func_indices_from_expr_raise(offset_expr) {
          push_unique_u32(out, index)
        }
        let func_count = parser.read_u32_leb128()
        for _ in 0U..<func_count {
          push_unique_u32(out, parser.read_u32_leb128())
        }
      }
      1U => {
        ignore(parser.read_byte())
        let func_count = parser.read_u32_leb128()
        for _ in 0U..<func_count {
          push_unique_u32(out, parser.read_u32_leb128())
        }
      }
      2U => {
        ignore(parser.read_u32_leb128())
        let offset_expr = read_const_expr_bytes_raise(parser, payload)
        for index in collect_ref_func_indices_from_expr_raise(offset_expr) {
          push_unique_u32(out, index)
        }
        ignore(parser.read_byte())
        let func_count = parser.read_u32_leb128()
        for _ in 0U..<func_count {
          push_unique_u32(out, parser.read_u32_leb128())
        }
      }
      3U => {
        ignore(parser.read_byte())
        let func_count = parser.read_u32_leb128()
        for _ in 0U..<func_count {
          push_unique_u32(out, parser.read_u32_leb128())
        }
      }
      4U => {
        let offset_expr = read_const_expr_bytes_raise(parser, payload)
        for index in collect_ref_func_indices_from_expr_raise(offset_expr) {
          push_unique_u32(out, index)
        }
        let expr_count = parser.read_u32_leb128()
        for _ in 0U..<expr_count {
          let expr = read_const_expr_bytes_raise(parser, payload)
          for index in collect_ref_func_indices_from_expr_raise(expr) {
            push_unique_u32(out, index)
          }
        }
      }
      5U => {
        ignore(read_ref_type_bytes_raise(parser))
        let expr_count = parser.read_u32_leb128()
        for _ in 0U..<expr_count {
          let expr = read_const_expr_bytes_raise(parser, payload)
          for index in collect_ref_func_indices_from_expr_raise(expr) {
            push_unique_u32(out, index)
          }
        }
      }
      6U => {
        ignore(parser.read_u32_leb128())
        let offset_expr = read_const_expr_bytes_raise(parser, payload)
        for index in collect_ref_func_indices_from_expr_raise(offset_expr) {
          push_unique_u32(out, index)
        }
        ignore(read_ref_type_bytes_raise(parser))
        let expr_count = parser.read_u32_leb128()
        for _ in 0U..<expr_count {
          let expr = read_const_expr_bytes_raise(parser, payload)
          for index in collect_ref_func_indices_from_expr_raise(expr) {
            push_unique_u32(out, index)
          }
        }
      }
      7U => {
        ignore(read_ref_type_bytes_raise(parser))
        let expr_count = parser.read_u32_leb128()
        for _ in 0U..<expr_count {
          let expr = read_const_expr_bytes_raise(parser, payload)
          for index in collect_ref_func_indices_from_expr_raise(expr) {
            push_unique_u32(out, index)
          }
        }
      }
      _ =>
        raise WiteError::InvalidFormat(
          "unsupported element segment flags in parser: " + flags.to_string(),
        )
    }
  }
  out
}

///|
fn collect_used_global_indices_from_element_section_raise(
  payload : Bytes,
) -> Array[UInt] raise WiteError {
  let parser = Cursor::new(payload)
  let segment_count = parser.read_u32_leb128()
  let out : Array[UInt] = []
  for _ in 0U..<segment_count {
    let flags = parser.read_u32_leb128()
    match flags {
      0U => {
        let offset_expr = read_const_expr_bytes_raise(parser, payload)
        for index in collect_global_get_indices_from_expr_raise(offset_expr) {
          push_unique_u32(out, index)
        }
        let func_count = parser.read_u32_leb128()
        for _ in 0U..<func_count {
          ignore(parser.read_u32_leb128())
        }
      }
      1U => {
        ignore(parser.read_byte())
        let func_count = parser.read_u32_leb128()
        for _ in 0U..<func_count {
          ignore(parser.read_u32_leb128())
        }
      }
      2U => {
        ignore(parser.read_u32_leb128())
        let offset_expr = read_const_expr_bytes_raise(parser, payload)
        for index in collect_global_get_indices_from_expr_raise(offset_expr) {
          push_unique_u32(out, index)
        }
        ignore(parser.read_byte())
        let func_count = parser.read_u32_leb128()
        for _ in 0U..<func_count {
          ignore(parser.read_u32_leb128())
        }
      }
      3U => {
        ignore(parser.read_byte())
        let func_count = parser.read_u32_leb128()
        for _ in 0U..<func_count {
          ignore(parser.read_u32_leb128())
        }
      }
      4U => {
        let offset_expr = read_const_expr_bytes_raise(parser, payload)
        for index in collect_global_get_indices_from_expr_raise(offset_expr) {
          push_unique_u32(out, index)
        }
        let expr_count = parser.read_u32_leb128()
        for _ in 0U..<expr_count {
          let expr = read_const_expr_bytes_raise(parser, payload)
          for index in collect_global_get_indices_from_expr_raise(expr) {
            push_unique_u32(out, index)
          }
        }
      }
      5U => {
        ignore(read_ref_type_bytes_raise(parser))
        let expr_count = parser.read_u32_leb128()
        for _ in 0U..<expr_count {
          let expr = read_const_expr_bytes_raise(parser, payload)
          for index in collect_global_get_indices_from_expr_raise(expr) {
            push_unique_u32(out, index)
          }
        }
      }
      6U => {
        ignore(parser.read_u32_leb128())
        let offset_expr = read_const_expr_bytes_raise(parser, payload)
        for index in collect_global_get_indices_from_expr_raise(offset_expr) {
          push_unique_u32(out, index)
        }
        ignore(read_ref_type_bytes_raise(parser))
        let expr_count = parser.read_u32_leb128()
        for _ in 0U..<expr_count {
          let expr = read_const_expr_bytes_raise(parser, payload)
          for index in collect_global_get_indices_from_expr_raise(expr) {
            push_unique_u32(out, index)
          }
        }
      }
      7U => {
        ignore(read_ref_type_bytes_raise(parser))
        let expr_count = parser.read_u32_leb128()
        for _ in 0U..<expr_count {
          let expr = read_const_expr_bytes_raise(parser, payload)
          for index in collect_global_get_indices_from_expr_raise(expr) {
            push_unique_u32(out, index)
          }
        }
      }
      _ =>
        raise WiteError::InvalidFormat(
          "unsupported element segment flags in global parser: " +
          flags.to_string(),
        )
    }
  }
  out
}

///|
fn rewrite_global_section_payload_for_index_map_raise(
  payload : Bytes,
  index_map : Map[UInt, UInt],
) -> Bytes raise WiteError {
  let parser = Cursor::new(payload)
  let count = parser.read_u32_leb128()
  let out : Array[Byte] = []
  out.append(encode_u32_leb128(count)[:])
  for _ in 0U..<count {
    let val_type = read_val_type_bytes_raise(parser)
    out.append(val_type[:].to_array())
    let mutability = parser.read_byte()
    out.push(mutability)
    let expr_bytes = read_const_expr_bytes_raise(parser, payload)
    let rewritten = rewrite_const_expr_function_indices_raise(
      expr_bytes, index_map,
    )
    out.append(rewritten[:].to_array())
  }
  Bytes::from_array(out[:])
}

///|
fn rewrite_element_section_payload_for_index_map_raise(
  payload : Bytes,
  index_map : Map[UInt, UInt],
) -> Bytes raise WiteError {
  let parser = Cursor::new(payload)
  let segment_count = parser.read_u32_leb128()
  let out : Array[Byte] = []
  out.append(encode_u32_leb128(segment_count)[:])
  for _ in 0U..<segment_count {
    let flags = parser.read_u32_leb128()
    out.append(encode_u32_leb128(flags)[:])
    match flags {
      0U => {
        let offset_expr = read_const_expr_bytes_raise(parser, payload)
        out.append(
          rewrite_const_expr_function_indices_raise(offset_expr, index_map)[:].to_array(),
        )
        let func_count = parser.read_u32_leb128()
        out.append(encode_u32_leb128(func_count)[:])
        for _ in 0U..<func_count {
          let index = parser.read_u32_leb128()
          out.append(
            encode_u32_leb128(remap_function_index_raise(index, index_map))[:],
          )
        }
      }
      1U => {
        out.push(parser.read_byte())
        let func_count = parser.read_u32_leb128()
        out.append(encode_u32_leb128(func_count)[:])
        for _ in 0U..<func_count {
          let index = parser.read_u32_leb128()
          out.append(
            encode_u32_leb128(remap_function_index_raise(index, index_map))[:],
          )
        }
      }
      2U => {
        let table_index = parser.read_u32_leb128()
        out.append(encode_u32_leb128(table_index)[:])
        let offset_expr = read_const_expr_bytes_raise(parser, payload)
        out.append(
          rewrite_const_expr_function_indices_raise(offset_expr, index_map)[:].to_array(),
        )
        out.push(parser.read_byte())
        let func_count = parser.read_u32_leb128()
        out.append(encode_u32_leb128(func_count)[:])
        for _ in 0U..<func_count {
          let index = parser.read_u32_leb128()
          out.append(
            encode_u32_leb128(remap_function_index_raise(index, index_map))[:],
          )
        }
      }
      3U => {
        out.push(parser.read_byte())
        let func_count = parser.read_u32_leb128()
        out.append(encode_u32_leb128(func_count)[:])
        for _ in 0U..<func_count {
          let index = parser.read_u32_leb128()
          out.append(
            encode_u32_leb128(remap_function_index_raise(index, index_map))[:],
          )
        }
      }
      4U => {
        let offset_expr = read_const_expr_bytes_raise(parser, payload)
        out.append(
          rewrite_const_expr_function_indices_raise(offset_expr, index_map)[:].to_array(),
        )
        let expr_count = parser.read_u32_leb128()
        out.append(encode_u32_leb128(expr_count)[:])
        for _ in 0U..<expr_count {
          let expr_bytes = read_const_expr_bytes_raise(parser, payload)
          out.append(
            rewrite_const_expr_function_indices_raise(expr_bytes, index_map)[:].to_array(),
          )
        }
      }
      5U => {
        out.append(read_ref_type_bytes_raise(parser)[:].to_array())
        let expr_count = parser.read_u32_leb128()
        out.append(encode_u32_leb128(expr_count)[:])
        for _ in 0U..<expr_count {
          let expr_bytes = read_const_expr_bytes_raise(parser, payload)
          out.append(
            rewrite_const_expr_function_indices_raise(expr_bytes, index_map)[:].to_array(),
          )
        }
      }
      6U => {
        let table_index = parser.read_u32_leb128()
        out.append(encode_u32_leb128(table_index)[:])
        let offset_expr = read_const_expr_bytes_raise(parser, payload)
        out.append(
          rewrite_const_expr_function_indices_raise(offset_expr, index_map)[:].to_array(),
        )
        out.append(read_ref_type_bytes_raise(parser)[:].to_array())
        let expr_count = parser.read_u32_leb128()
        out.append(encode_u32_leb128(expr_count)[:])
        for _ in 0U..<expr_count {
          let expr_bytes = read_const_expr_bytes_raise(parser, payload)
          out.append(
            rewrite_const_expr_function_indices_raise(expr_bytes, index_map)[:].to_array(),
          )
        }
      }
      7U => {
        out.append(read_ref_type_bytes_raise(parser)[:].to_array())
        let expr_count = parser.read_u32_leb128()
        out.append(encode_u32_leb128(expr_count)[:])
        for _ in 0U..<expr_count {
          let expr_bytes = read_const_expr_bytes_raise(parser, payload)
          out.append(
            rewrite_const_expr_function_indices_raise(expr_bytes, index_map)[:].to_array(),
          )
        }
      }
      _ =>
        raise WiteError::InvalidFormat(
          "unsupported element segment flags in rewrite: " + flags.to_string(),
        )
    }
  }
  Bytes::from_array(out[:])
}

///|
priv struct GlobalSectionEntry {
  val_type : Bytes
  mutability : Byte
  init_expr : Bytes
  init_global_refs : Array[UInt]
}

///|
fn parse_global_section_entries_with_refs_raise(
  payload : Bytes,
) -> Array[GlobalSectionEntry] raise WiteError {
  let parser = Cursor::new(payload)
  let count = parser.read_u32_leb128()
  let out : Array[GlobalSectionEntry] = []
  for _ in 0U..<count {
    let val_type = read_val_type_bytes_raise(parser)
    let mutability = parser.read_byte()
    let init_expr = read_const_expr_bytes_raise(parser, payload)
    out.push({
      val_type,
      mutability,
      init_expr,
      init_global_refs: collect_global_get_indices_from_expr_raise(init_expr),
    })
  }
  out
}

///|
fn rewrite_global_section_payload_for_keep_local_and_global_index_map_raise(
  payload : Bytes,
  keep_local : Array[Bool],
  global_index_map : Map[UInt, UInt],
) -> Bytes raise WiteError {
  let entries = parse_global_section_entries_with_refs_raise(payload)
  if entries.length() != keep_local.length() {
    raise WiteError::InvalidFormat(
      "global section length mismatch: global=" +
      entries.length().to_string() +
      " keep=" +
      keep_local.length().to_string(),
    )
  }
  let kept_entries : Array[GlobalSectionEntry] = []
  for i in 0..<entries.length() {
    if keep_local[i] {
      kept_entries.push(entries[i])
    }
  }
  let out : Array[Byte] = []
  out.append(encode_u32_leb128(kept_entries.length().reinterpret_as_uint())[:])
  for entry in kept_entries {
    out.append(entry.val_type[:].to_array())
    out.push(entry.mutability)
    out.append(
      rewrite_const_expr_global_indices_raise(entry.init_expr, global_index_map)[:].to_array(),
    )
  }
  Bytes::from_array(out[:])
}

///|
fn rewrite_global_section_payload_for_local_order_and_global_index_map_raise(
  payload : Bytes,
  local_order : Array[UInt],
  global_index_map : Map[UInt, UInt],
) -> Bytes raise WiteError {
  let entries = parse_global_section_entries_with_refs_raise(payload)
  if entries.length() != local_order.length() {
    raise WiteError::InvalidFormat(
      "global section length mismatch for reorder: global=" +
      entries.length().to_string() +
      " order=" +
      local_order.length().to_string(),
    )
  }
  let out : Array[Byte] = []
  out.append(encode_u32_leb128(local_order.length().reinterpret_as_uint())[:])
  for old_local_index_u in local_order {
    let old_local_index = UInt::reinterpret_as_int(old_local_index_u)
    if old_local_index < 0 || old_local_index >= entries.length() {
      raise WiteError::InvalidFormat(
        "global reorder index out of range: " + old_local_index_u.to_string(),
      )
    }
    let entry = entries[old_local_index]
    out.append(entry.val_type[:].to_array())
    out.push(entry.mutability)
    out.append(
      rewrite_const_expr_global_indices_raise(entry.init_expr, global_index_map)[:].to_array(),
    )
  }
  Bytes::from_array(out[:])
}

///|
fn parse_memory_section_entries_raise(
  payload : Bytes,
) -> Array[Bytes] raise WiteError {
  let parser = Cursor::new(payload)
  let count = parser.read_u32_leb128()
  let out : Array[Bytes] = []
  for _ in 0U..<count {
    let start = parser.get_pos()
    parse_limits(parser)
    let end_ = parser.get_pos()
    out.push(payload[start:end_].to_bytes())
  }
  out
}

///|
fn rewrite_memory_section_payload_for_keep_local_raise(
  payload : Bytes,
  keep_local : Array[Bool],
) -> Bytes raise WiteError {
  let entries = parse_memory_section_entries_raise(payload)
  if entries.length() != keep_local.length() {
    raise WiteError::InvalidFormat(
      "memory section length mismatch: memory=" +
      entries.length().to_string() +
      " keep=" +
      keep_local.length().to_string(),
    )
  }
  let kept_entries : Array[Bytes] = []
  for i in 0..<entries.length() {
    if keep_local[i] {
      kept_entries.push(entries[i])
    }
  }
  let out : Array[Byte] = []
  out.append(encode_u32_leb128(kept_entries.length().reinterpret_as_uint())[:])
  for entry in kept_entries {
    out.append(entry[:].to_array())
  }
  Bytes::from_array(out[:])
}

///|
fn rewrite_memory_section_payload_for_local_order_raise(
  payload : Bytes,
  local_order : Array[UInt],
) -> Bytes raise WiteError {
  let entries = parse_memory_section_entries_raise(payload)
  if entries.length() != local_order.length() {
    raise WiteError::InvalidFormat(
      "memory section length mismatch for reorder: memory=" +
      entries.length().to_string() +
      " order=" +
      local_order.length().to_string(),
    )
  }
  let out : Array[Byte] = []
  out.append(encode_u32_leb128(local_order.length().reinterpret_as_uint())[:])
  for old_local_index_u in local_order {
    let old_local_index = UInt::reinterpret_as_int(old_local_index_u)
    if old_local_index < 0 || old_local_index >= entries.length() {
      raise WiteError::InvalidFormat(
        "memory reorder index out of range: " + old_local_index_u.to_string(),
      )
    }
    out.append(entries[old_local_index][:].to_array())
  }
  Bytes::from_array(out[:])
}

///|
fn parse_table_section_entries_raise(
  payload : Bytes,
) -> Array[Bytes] raise WiteError {
  let parser = Cursor::new(payload)
  let count = parser.read_u32_leb128()
  let out : Array[Bytes] = []
  for _ in 0U..<count {
    let start = parser.get_pos()
    ignore(read_ref_type_bytes_raise(parser))
    parse_limits(parser)
    let end_ = parser.get_pos()
    out.push(payload[start:end_].to_bytes())
  }
  out
}

///|
fn rewrite_table_section_payload_for_keep_local_raise(
  payload : Bytes,
  keep_local : Array[Bool],
) -> Bytes raise WiteError {
  let entries = parse_table_section_entries_raise(payload)
  if entries.length() != keep_local.length() {
    raise WiteError::InvalidFormat(
      "table section length mismatch: table=" +
      entries.length().to_string() +
      " keep=" +
      keep_local.length().to_string(),
    )
  }
  let out : Array[Byte] = []
  let mut kept_count = 0U
  let kept_entries : Array[Bytes] = []
  for i in 0..<entries.length() {
    if keep_local[i] {
      kept_entries.push(entries[i])
      kept_count += 1U
    }
  }
  out.append(encode_u32_leb128(kept_count)[:])
  for entry in kept_entries {
    out.append(entry[:].to_array())
  }
  Bytes::from_array(out[:])
}

///|
fn remap_table_index_raise(
  index : UInt,
  table_index_map : Map[UInt, UInt],
) -> UInt raise WiteError {
  match table_index_map.get(index) {
    Some(v) => v
    None =>
      raise WiteError::InvalidFormat(
        "table remap missing index: " + index.to_string(),
      )
  }
}

///|
fn remap_element_segment_index_raise(
  index : UInt,
  element_index_map : Map[UInt, UInt],
) -> UInt raise WiteError {
  match element_index_map.get(index) {
    Some(v) => v
    None =>
      raise WiteError::InvalidFormat(
        "element segment remap missing index: " + index.to_string(),
      )
  }
}

///|
fn remap_data_segment_index_raise(
  index : UInt,
  data_index_map : Map[UInt, UInt],
) -> UInt raise WiteError {
  match data_index_map.get(index) {
    Some(v) => v
    None =>
      raise WiteError::InvalidFormat(
        "data segment remap missing index: " + index.to_string(),
      )
  }
}

///|
fn make_identity_index_map(count : UInt) -> Map[UInt, UInt] {
  let out : Map[UInt, UInt] = {}
  for i in 0U..<count {
    out.set(i, i)
  }
  out
}

///|
priv struct ImportKindCounts {
  table_count : UInt
  memory_count : UInt
  global_count : UInt
}

///|
fn count_import_kinds(entries : Array[ImportSectionEntry]) -> ImportKindCounts {
  let mut table_count = 0U
  let mut memory_count = 0U
  let mut global_count = 0U
  for entry in entries {
    match entry.kind {
      1U => table_count += 1U
      2U => memory_count += 1U
      3U => global_count += 1U
      _ => ()
    }
  }
  { table_count, memory_count, global_count }
}

///|
fn count_reordered_local_indices(local_order : Array[UInt]) -> UInt {
  let mut moved = 0U
  for i in 0..<local_order.length() {
    if local_order[i] != i.reinterpret_as_uint() {
      moved += 1U
    }
  }
  moved
}

///|
fn increment_index_count_in_array(counts : Array[UInt], index : UInt) -> Unit {
  let pos = UInt::reinterpret_as_int(index)
  if pos >= 0 && pos < counts.length() {
    counts[pos] += 1U
  }
}

///|
fn index_count_in_array(counts : Array[UInt], index : UInt) -> UInt {
  let pos = UInt::reinterpret_as_int(index)
  if pos < 0 || pos >= counts.length() {
    return 0U
  }
  counts[pos]
}

///|
fn collect_used_table_indices_from_instruction_raise(
  instr_bytes : Bytes,
  spans : Array[InstrSpan],
) -> Array[UInt] raise WiteError {
  let out : Array[UInt] = []
  for span in spans {
    match span.opcode {
      0x11U => {
        if span.end_ <= span.start + 1 {
          raise WiteError::InvalidFormat("invalid call_indirect immediate")
        }
        let imm = instr_bytes[span.start + 1:span.end_].to_bytes()
        let parser = Cursor::new(imm)
        ignore(parser.read_u32_leb128())
        push_unique_u32(out, parser.read_u32_leb128())
      }
      0x25U | 0x26U =>
        match decode_span_u32_immediate(instr_bytes, span) {
          Some(index) => push_unique_u32(out, index)
          None =>
            raise WiteError::InvalidFormat(
              "failed to decode table index immediate",
            )
        }
      0xfcU => {
        if span.end_ <= span.start + 1 {
          raise WiteError::InvalidFormat("invalid 0xfc immediate")
        }
        let imm = instr_bytes[span.start + 1:span.end_].to_bytes()
        let parser = Cursor::new(imm)
        let subopcode = parser.read_u32_leb128()
        match subopcode {
          12U => {
            ignore(parser.read_u32_leb128())
            push_unique_u32(out, parser.read_u32_leb128())
          }
          14U => {
            push_unique_u32(out, parser.read_u32_leb128())
            push_unique_u32(out, parser.read_u32_leb128())
          }
          15U | 16U | 17U => push_unique_u32(out, parser.read_u32_leb128())
          _ => ()
        }
      }
      _ => ()
    }
  }
  out
}

///|
fn collect_used_table_indices_from_code_section(
  payload : Bytes,
) -> Array[UInt]? {
  let result = try? {
    let out : Array[UInt] = []
    let bodies = parse_code_bodies(payload)
    for body in bodies {
      let prefix_end = parse_local_decl_prefix_end(body)
      let instr_bytes = body[prefix_end:body.length()].to_bytes()
      let spans = parse_instruction_spans_raise(instr_bytes)
      for
        index in collect_used_table_indices_from_instruction_raise(
          instr_bytes, spans,
        ) {
        push_unique_u32(out, index)
      }
    }
    out
  }
  match result {
    Ok(v) => Some(v)
    Err(_) => None
  }
}

///|
fn opcode_fd_uses_memory(subopcode : UInt) -> Bool {
  (subopcode >= 0x00U && subopcode <= 0x0bU) ||
  (subopcode >= 0x54U && subopcode <= 0x5bU) ||
  subopcode == 0x5cU ||
  subopcode == 0x5dU
}

///|
fn collect_used_global_indices_from_instruction_raise(
  instr_bytes : Bytes,
  spans : Array[InstrSpan],
) -> Array[UInt] raise WiteError {
  let out : Array[UInt] = []
  for span in spans {
    if span.opcode == 0x23U || span.opcode == 0x24U {
      match decode_span_u32_immediate(instr_bytes, span) {
        Some(index) => push_unique_u32(out, index)
        None =>
          raise WiteError::InvalidFormat(
            "failed to decode global index immediate",
          )
      }
    }
  }
  out
}

///|
fn collect_used_memory_indices_from_instruction_raise(
  instr_bytes : Bytes,
  spans : Array[InstrSpan],
) -> Array[UInt] raise WiteError {
  let out : Array[UInt] = []
  for span in spans {
    match span.opcode {
      0x28U..=0x3eU => push_unique_u32(out, 0U)
      0x3fU | 0x40U =>
        match decode_span_u32_immediate(instr_bytes, span) {
          Some(index) => push_unique_u32(out, index)
          None =>
            raise WiteError::InvalidFormat(
              "failed to decode memory.size/memory.grow immediate",
            )
        }
      0xfcU => {
        if span.end_ <= span.start + 1 {
          raise WiteError::InvalidFormat("invalid 0xfc immediate")
        }
        let imm = instr_bytes[span.start + 1:span.end_].to_bytes()
        let parser = Cursor::new(imm)
        let subopcode = parser.read_u32_leb128()
        match subopcode {
          8U => {
            ignore(parser.read_u32_leb128())
            push_unique_u32(out, parser.read_u32_leb128())
          }
          10U => {
            push_unique_u32(out, parser.read_u32_leb128())
            push_unique_u32(out, parser.read_u32_leb128())
          }
          11U => push_unique_u32(out, parser.read_u32_leb128())
          _ => ()
        }
      }
      0xfdU => {
        if span.end_ <= span.start + 1 {
          raise WiteError::InvalidFormat("invalid 0xfd immediate")
        }
        let imm = instr_bytes[span.start + 1:span.end_].to_bytes()
        let parser = Cursor::new(imm)
        if opcode_fd_uses_memory(parser.read_u32_leb128()) {
          push_unique_u32(out, 0U)
        }
      }
      _ => ()
    }
  }
  out
}

///|
fn collect_used_global_indices_from_code_section(
  payload : Bytes,
) -> Array[UInt]? {
  let result = try? {
    let out : Array[UInt] = []
    let bodies = parse_code_bodies(payload)
    for body in bodies {
      let prefix_end = parse_local_decl_prefix_end(body)
      let instr_bytes = body[prefix_end:body.length()].to_bytes()
      let spans = parse_instruction_spans_raise(instr_bytes)
      for
        index in collect_used_global_indices_from_instruction_raise(
          instr_bytes, spans,
        ) {
        push_unique_u32(out, index)
      }
    }
    out
  }
  match result {
    Ok(v) => Some(v)
    Err(_) => None
  }
}

///|
fn collect_used_memory_indices_from_code_section(
  payload : Bytes,
) -> Array[UInt]? {
  let result = try? {
    let out : Array[UInt] = []
    let bodies = parse_code_bodies(payload)
    for body in bodies {
      let prefix_end = parse_local_decl_prefix_end(body)
      let instr_bytes = body[prefix_end:body.length()].to_bytes()
      let spans = parse_instruction_spans_raise(instr_bytes)
      for
        index in collect_used_memory_indices_from_instruction_raise(
          instr_bytes, spans,
        ) {
        push_unique_u32(out, index)
      }
    }
    out
  }
  match result {
    Ok(v) => Some(v)
    Err(_) => None
  }
}

///|
fn rewrite_instruction_module_indices_raise(
  instr_bytes : Bytes,
  spans : Array[InstrSpan],
  table_index_map : Map[UInt, UInt],
  memory_index_map : Map[UInt, UInt],
  global_index_map : Map[UInt, UInt],
  element_index_map : Map[UInt, UInt],
  data_index_map : Map[UInt, UInt],
) -> Bytes raise WiteError {
  let out : Array[Byte] = []
  for span in spans {
    match span.opcode {
      0x11U => {
        if span.end_ <= span.start + 1 {
          raise WiteError::InvalidFormat("invalid call_indirect immediate")
        }
        let imm = instr_bytes[span.start + 1:span.end_].to_bytes()
        let parser = Cursor::new(imm)
        let type_index = parser.read_u32_leb128()
        let table_index = parser.read_u32_leb128()
        out.push(0x11U.to_byte())
        out.append(encode_u32_leb128(type_index)[:])
        out.append(
          encode_u32_leb128(
            remap_table_index_raise(table_index, table_index_map),
          )[:],
        )
      }
      0x23U | 0x24U =>
        match decode_span_u32_immediate(instr_bytes, span) {
          Some(index) => {
            out.push(span.opcode.to_byte())
            out.append(
              encode_u32_leb128(
                remap_global_index_raise(index, global_index_map),
              )[:],
            )
          }
          None =>
            raise WiteError::InvalidFormat(
              "failed to decode global index immediate",
            )
        }
      0x25U | 0x26U =>
        match decode_span_u32_immediate(instr_bytes, span) {
          Some(index) => {
            out.push(span.opcode.to_byte())
            out.append(
              encode_u32_leb128(remap_table_index_raise(index, table_index_map))[:],
            )
          }
          None =>
            raise WiteError::InvalidFormat(
              "failed to decode table index immediate",
            )
        }
      0x28U..=0x3eU => {
        if remap_memory_index_raise(0U, memory_index_map) != 0U {
          raise WiteError::InvalidFormat(
            "implicit memory index remapped to non-zero",
          )
        }
        out.append(instr_bytes[span.start:span.end_].to_array())
      }
      0x3fU | 0x40U =>
        match decode_span_u32_immediate(instr_bytes, span) {
          Some(index) => {
            out.push(span.opcode.to_byte())
            out.append(
              encode_u32_leb128(
                remap_memory_index_raise(index, memory_index_map),
              )[:],
            )
          }
          None =>
            raise WiteError::InvalidFormat(
              "failed to decode memory.size/memory.grow immediate",
            )
        }
      0xfcU => {
        if span.end_ <= span.start + 1 {
          raise WiteError::InvalidFormat("invalid 0xfc immediate")
        }
        let imm = instr_bytes[span.start + 1:span.end_].to_bytes()
        let parser = Cursor::new(imm)
        let subopcode = parser.read_u32_leb128()
        let rest_start = parser.get_pos()
        out.push(0xfcU.to_byte())
        out.append(encode_u32_leb128(subopcode)[:])
        match subopcode {
          8U => {
            let data_index = parser.read_u32_leb128()
            let memory_index = parser.read_u32_leb128()
            out.append(
              encode_u32_leb128(
                remap_data_segment_index_raise(data_index, data_index_map),
              )[:],
            )
            out.append(
              encode_u32_leb128(
                remap_memory_index_raise(memory_index, memory_index_map),
              )[:],
            )
          }
          9U => {
            let data_index = parser.read_u32_leb128()
            out.append(
              encode_u32_leb128(
                remap_data_segment_index_raise(data_index, data_index_map),
              )[:],
            )
          }
          10U => {
            let dst_memory = parser.read_u32_leb128()
            let src_memory = parser.read_u32_leb128()
            out.append(
              encode_u32_leb128(
                remap_memory_index_raise(dst_memory, memory_index_map),
              )[:],
            )
            out.append(
              encode_u32_leb128(
                remap_memory_index_raise(src_memory, memory_index_map),
              )[:],
            )
          }
          11U => {
            let memory_index = parser.read_u32_leb128()
            out.append(
              encode_u32_leb128(
                remap_memory_index_raise(memory_index, memory_index_map),
              )[:],
            )
          }
          12U => {
            let elem_index = parser.read_u32_leb128()
            let table_index = parser.read_u32_leb128()
            out.append(
              encode_u32_leb128(
                remap_element_segment_index_raise(elem_index, element_index_map),
              )[:],
            )
            out.append(
              encode_u32_leb128(
                remap_table_index_raise(table_index, table_index_map),
              )[:],
            )
          }
          13U => {
            let elem_index = parser.read_u32_leb128()
            out.append(
              encode_u32_leb128(
                remap_element_segment_index_raise(elem_index, element_index_map),
              )[:],
            )
          }
          14U => {
            let dst_table = parser.read_u32_leb128()
            let src_table = parser.read_u32_leb128()
            out.append(
              encode_u32_leb128(
                remap_table_index_raise(dst_table, table_index_map),
              )[:],
            )
            out.append(
              encode_u32_leb128(
                remap_table_index_raise(src_table, table_index_map),
              )[:],
            )
          }
          15U | 16U | 17U => {
            let table_index = parser.read_u32_leb128()
            out.append(
              encode_u32_leb128(
                remap_table_index_raise(table_index, table_index_map),
              )[:],
            )
          }
          _ => out.append(imm[rest_start:imm.length()].to_array())
        }
      }
      _ => out.append(instr_bytes[span.start:span.end_].to_array())
    }
  }
  Bytes::from_array(out[:])
}

///|
fn rewrite_code_body_for_module_index_map_raise(
  body : Bytes,
  table_index_map : Map[UInt, UInt],
  memory_index_map : Map[UInt, UInt],
  global_index_map : Map[UInt, UInt],
  element_index_map : Map[UInt, UInt],
  data_index_map : Map[UInt, UInt],
) -> Bytes raise WiteError {
  let prefix_end = parse_local_decl_prefix_end(body)
  let instr_bytes = body[prefix_end:body.length()].to_bytes()
  let spans = parse_instruction_spans_raise(instr_bytes)
  let rewritten_instr = rewrite_instruction_module_indices_raise(
    instr_bytes, spans, table_index_map, memory_index_map, global_index_map, element_index_map,
    data_index_map,
  )
  let out : Array[Byte] = body[0:prefix_end].to_array()
  out.append(rewritten_instr[:].to_array())
  Bytes::from_array(out[:])
}

///|
fn rewrite_code_section_payload_for_module_index_map_raise(
  payload : Bytes,
  table_index_map : Map[UInt, UInt],
  memory_index_map : Map[UInt, UInt],
  global_index_map : Map[UInt, UInt],
  element_index_map : Map[UInt, UInt],
  data_index_map : Map[UInt, UInt],
) -> Bytes raise WiteError {
  let bodies = parse_code_bodies(payload)
  let out : Array[Byte] = []
  out.append(encode_u32_leb128(bodies.length().reinterpret_as_uint())[:])
  for body in bodies {
    let rewritten = rewrite_code_body_for_module_index_map_raise(
      body, table_index_map, memory_index_map, global_index_map, element_index_map,
      data_index_map,
    )
    out.append(encode_u32_leb128(rewritten.length().reinterpret_as_uint())[:])
    out.append(rewritten[:].to_array())
  }
  Bytes::from_array(out[:])
}

///|
fn rewrite_export_section_payload_for_module_index_maps_raise(
  payload : Bytes,
  table_index_map : Map[UInt, UInt],
  memory_index_map : Map[UInt, UInt],
  global_index_map : Map[UInt, UInt],
) -> (Bytes, UInt) raise WiteError {
  let parser = Cursor::new(payload)
  let export_count = parser.read_u32_leb128()
  let out : Array[Byte] = []
  let mut kept_count = 0U
  let mut removed_count = 0U
  for _ in 0U..<export_count {
    let name = read_name_bytes(parser)
    let kind = parser.read_byte().to_uint()
    let index = parser.read_u32_leb128()
    let mapped = match kind {
      1U =>
        match table_index_map.get(index) {
          Some(v) => Some(v)
          None => None
        }
      2U =>
        match memory_index_map.get(index) {
          Some(v) => Some(v)
          None => None
        }
      3U =>
        match global_index_map.get(index) {
          Some(v) => Some(v)
          None => None
        }
      _ => Some(index)
    }
    match mapped {
      Some(remapped) => {
        kept_count += 1U
        append_name_bytes(out, name)
        out.push(kind.to_byte())
        out.append(encode_u32_leb128(remapped)[:])
      }
      None => removed_count += 1U
    }
  }
  let encoded : Array[Byte] = []
  encoded.append(encode_u32_leb128(kept_count)[:])
  encoded.append(out[:])
  (Bytes::from_array(encoded[:]), removed_count)
}

///|
fn read_function_index_vector_bytes_raise(
  parser : Cursor,
) -> Bytes raise WiteError {
  let start = parser.get_pos()
  let count = parser.read_u32_leb128()
  for _ in 0U..<count {
    ignore(parser.read_u32_leb128())
  }
  let end_ = parser.get_pos()
  parser.bytes[start:end_].to_bytes()
}

///|
fn rewrite_const_expr_vector_global_indices_raise(
  parser : Cursor,
  payload : Bytes,
  global_index_map : Map[UInt, UInt],
) -> Bytes raise WiteError {
  let count = parser.read_u32_leb128()
  let out : Array[Byte] = []
  out.append(encode_u32_leb128(count)[:])
  for _ in 0U..<count {
    let expr = read_const_expr_bytes_raise(parser, payload)
    out.append(
      rewrite_const_expr_global_indices_raise(expr, global_index_map)[:].to_array(),
    )
  }
  Bytes::from_array(out[:])
}

///|
fn rewrite_element_section_payload_for_table_index_map_raise(
  payload : Bytes,
  table_index_map : Map[UInt, UInt],
  global_index_map : Map[UInt, UInt],
) -> (Bytes, UInt, Map[UInt, UInt]) raise WiteError {
  let parser = Cursor::new(payload)
  let segment_count = parser.read_u32_leb128()
  let kept_segments : Array[Bytes] = []
  let element_index_map : Map[UInt, UInt] = {}
  let mut removed_segment_count = 0U
  for old_segment_index in 0U..<segment_count {
    let flags = parser.read_u32_leb128()
    let segment_out : Array[Byte] = []
    let mut keep_segment = true
    match flags {
      0U => {
        let offset_expr = read_const_expr_bytes_raise(parser, payload)
        let function_indices = read_function_index_vector_bytes_raise(parser)
        if table_index_map.get(0U) is None {
          keep_segment = false
        } else {
          segment_out.append(encode_u32_leb128(0U)[:])
          segment_out.append(
            rewrite_const_expr_global_indices_raise(
              offset_expr, global_index_map,
            )[:].to_array(),
          )
          segment_out.append(function_indices[:].to_array())
        }
      }
      1U => {
        let elem_kind = parser.read_byte()
        let function_indices = read_function_index_vector_bytes_raise(parser)
        segment_out.append(encode_u32_leb128(1U)[:])
        segment_out.push(elem_kind)
        segment_out.append(function_indices[:].to_array())
      }
      2U => {
        let table_index = parser.read_u32_leb128()
        let offset_expr = read_const_expr_bytes_raise(parser, payload)
        let elem_kind = parser.read_byte()
        let function_indices = read_function_index_vector_bytes_raise(parser)
        match table_index_map.get(table_index) {
          Some(remapped) => {
            segment_out.append(encode_u32_leb128(2U)[:])
            segment_out.append(encode_u32_leb128(remapped)[:])
            segment_out.append(
              rewrite_const_expr_global_indices_raise(
                offset_expr, global_index_map,
              )[:].to_array(),
            )
            segment_out.push(elem_kind)
            segment_out.append(function_indices[:].to_array())
          }
          None => keep_segment = false
        }
      }
      3U => {
        let elem_kind = parser.read_byte()
        let function_indices = read_function_index_vector_bytes_raise(parser)
        segment_out.append(encode_u32_leb128(3U)[:])
        segment_out.push(elem_kind)
        segment_out.append(function_indices[:].to_array())
      }
      4U => {
        let offset_expr = read_const_expr_bytes_raise(parser, payload)
        let exprs = rewrite_const_expr_vector_global_indices_raise(
          parser, payload, global_index_map,
        )
        if table_index_map.get(0U) is None {
          keep_segment = false
        } else {
          segment_out.append(encode_u32_leb128(4U)[:])
          segment_out.append(
            rewrite_const_expr_global_indices_raise(
              offset_expr, global_index_map,
            )[:].to_array(),
          )
          segment_out.append(exprs[:].to_array())
        }
      }
      5U => {
        let ref_type = read_ref_type_bytes_raise(parser)
        let exprs = rewrite_const_expr_vector_global_indices_raise(
          parser, payload, global_index_map,
        )
        segment_out.append(encode_u32_leb128(5U)[:])
        segment_out.append(ref_type[:].to_array())
        segment_out.append(exprs[:].to_array())
      }
      6U => {
        let table_index = parser.read_u32_leb128()
        let offset_expr = read_const_expr_bytes_raise(parser, payload)
        let ref_type = read_ref_type_bytes_raise(parser)
        let exprs = rewrite_const_expr_vector_global_indices_raise(
          parser, payload, global_index_map,
        )
        match table_index_map.get(table_index) {
          Some(remapped) => {
            segment_out.append(encode_u32_leb128(6U)[:])
            segment_out.append(encode_u32_leb128(remapped)[:])
            segment_out.append(
              rewrite_const_expr_global_indices_raise(
                offset_expr, global_index_map,
              )[:].to_array(),
            )
            segment_out.append(ref_type[:].to_array())
            segment_out.append(exprs[:].to_array())
          }
          None => keep_segment = false
        }
      }
      7U => {
        let ref_type = read_ref_type_bytes_raise(parser)
        let exprs = rewrite_const_expr_vector_global_indices_raise(
          parser, payload, global_index_map,
        )
        segment_out.append(encode_u32_leb128(7U)[:])
        segment_out.append(ref_type[:].to_array())
        segment_out.append(exprs[:].to_array())
      }
      _ =>
        raise WiteError::InvalidFormat(
          "unsupported element segment flags in table rewrite: " +
          flags.to_string(),
        )
    }
    if keep_segment {
      element_index_map.set(
        old_segment_index,
        kept_segments.length().reinterpret_as_uint(),
      )
      kept_segments.push(Bytes::from_array(segment_out[:]))
    } else {
      removed_segment_count += 1U
    }
  }
  let out : Array[Byte] = []
  out.append(encode_u32_leb128(kept_segments.length().reinterpret_as_uint())[:])
  for segment in kept_segments {
    out.append(segment[:].to_array())
  }
  (Bytes::from_array(out[:]), removed_segment_count, element_index_map)
}

///|
fn read_data_init_bytes_raise(
  parser : Cursor,
  payload : Bytes,
) -> Bytes raise WiteError {
  let start = parser.get_pos()
  let size_u = parser.read_u32_leb128()
  let size = UInt::reinterpret_as_int(size_u)
  if size < 0 {
    raise WiteError::InvalidFormat("data init size overflow")
  }
  parser.skip(size)
  let end_ = parser.get_pos()
  payload[start:end_].to_bytes()
}

///|
fn collect_used_memory_and_global_indices_from_data_section_raise(
  payload : Bytes,
) -> (Array[UInt], Array[UInt]) raise WiteError {
  let parser = Cursor::new(payload)
  let segment_count = parser.read_u32_leb128()
  let memory_indices : Array[UInt] = []
  let global_indices : Array[UInt] = []
  for _ in 0U..<segment_count {
    let flags = parser.read_u32_leb128()
    match flags {
      0U => {
        push_unique_u32(memory_indices, 0U)
        let offset_expr = read_const_expr_bytes_raise(parser, payload)
        for index in collect_global_get_indices_from_expr_raise(offset_expr) {
          push_unique_u32(global_indices, index)
        }
        ignore(read_data_init_bytes_raise(parser, payload))
      }
      1U => ignore(read_data_init_bytes_raise(parser, payload))
      2U => {
        let memory_index = parser.read_u32_leb128()
        push_unique_u32(memory_indices, memory_index)
        let offset_expr = read_const_expr_bytes_raise(parser, payload)
        for index in collect_global_get_indices_from_expr_raise(offset_expr) {
          push_unique_u32(global_indices, index)
        }
        ignore(read_data_init_bytes_raise(parser, payload))
      }
      _ =>
        raise WiteError::InvalidFormat(
          "unsupported data segment flags in parser: " + flags.to_string(),
        )
    }
  }
  (memory_indices, global_indices)
}

///|
fn rewrite_data_section_payload_for_memory_global_index_map_raise(
  payload : Bytes,
  memory_index_map : Map[UInt, UInt],
  global_index_map : Map[UInt, UInt],
) -> (Bytes, UInt, Map[UInt, UInt]) raise WiteError {
  let parser = Cursor::new(payload)
  let segment_count = parser.read_u32_leb128()
  let kept_segments : Array[Bytes] = []
  let data_index_map : Map[UInt, UInt] = {}
  let mut removed_segment_count = 0U
  for old_segment_index in 0U..<segment_count {
    let flags = parser.read_u32_leb128()
    let segment_out : Array[Byte] = []
    let mut keep_segment = true
    match flags {
      0U => {
        let offset_expr = read_const_expr_bytes_raise(parser, payload)
        let data_init = read_data_init_bytes_raise(parser, payload)
        match memory_index_map.get(0U) {
          Some(remapped_memory_index) =>
            if remapped_memory_index == 0U {
              segment_out.append(encode_u32_leb128(0U)[:])
              segment_out.append(
                rewrite_const_expr_global_indices_raise(
                  offset_expr, global_index_map,
                )[:].to_array(),
              )
              segment_out.append(data_init[:].to_array())
            } else {
              segment_out.append(encode_u32_leb128(2U)[:])
              segment_out.append(encode_u32_leb128(remapped_memory_index)[:])
              segment_out.append(
                rewrite_const_expr_global_indices_raise(
                  offset_expr, global_index_map,
                )[:].to_array(),
              )
              segment_out.append(data_init[:].to_array())
            }
          None => keep_segment = false
        }
      }
      1U => {
        let data_init = read_data_init_bytes_raise(parser, payload)
        segment_out.append(encode_u32_leb128(1U)[:])
        segment_out.append(data_init[:].to_array())
      }
      2U => {
        let memory_index = parser.read_u32_leb128()
        let offset_expr = read_const_expr_bytes_raise(parser, payload)
        let data_init = read_data_init_bytes_raise(parser, payload)
        match memory_index_map.get(memory_index) {
          Some(remapped_memory_index) => {
            segment_out.append(encode_u32_leb128(2U)[:])
            segment_out.append(encode_u32_leb128(remapped_memory_index)[:])
            segment_out.append(
              rewrite_const_expr_global_indices_raise(
                offset_expr, global_index_map,
              )[:].to_array(),
            )
            segment_out.append(data_init[:].to_array())
          }
          None => keep_segment = false
        }
      }
      _ =>
        raise WiteError::InvalidFormat(
          "unsupported data segment flags in rewrite: " + flags.to_string(),
        )
    }
    if keep_segment {
      data_index_map.set(
        old_segment_index,
        kept_segments.length().reinterpret_as_uint(),
      )
      kept_segments.push(Bytes::from_array(segment_out[:]))
    } else {
      removed_segment_count += 1U
    }
  }
  let out : Array[Byte] = []
  out.append(encode_u32_leb128(kept_segments.length().reinterpret_as_uint())[:])
  for segment in kept_segments {
    out.append(segment[:].to_array())
  }
  (Bytes::from_array(out[:]), removed_segment_count, data_index_map)
}

