///|
pub fn parse_instruction_spans(instr_bytes : Bytes) -> Array[InstrSpan]? {
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
pub fn collect_direct_callees(
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
pub fn collect_direct_callees_from_body_raise(
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
