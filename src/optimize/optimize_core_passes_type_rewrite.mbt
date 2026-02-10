///|
fn rewrite_export_section_payload_for_dce_raise(
  payload : Bytes,
  index_map : Map[UInt, UInt],
) -> Bytes raise WiteError {
  let parser = Cursor::new(payload)
  let export_count = parser.read_u32_leb128()
  let kept_entries : Array[Bytes] = []
  for _ in 0U..<export_count {
    let name = read_name_bytes(parser)
    let kind = parser.read_byte().to_uint()
    let index = parser.read_u32_leb128()
    let entry : Array[Byte] = []
    append_name_bytes(entry, name)
    entry.push(kind.to_byte())
    if kind == 0U {
      match index_map.get(index) {
        Some(remapped) => {
          entry.append(encode_u32_leb128(remapped)[:])
          kept_entries.push(Bytes::from_array(entry[:]))
        }
        None => ()
      }
    } else {
      entry.append(encode_u32_leb128(index)[:])
      kept_entries.push(Bytes::from_array(entry[:]))
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
fn rewrite_export_section_payload_for_keep_names_raise(
  payload : Bytes,
  keep_names : Array[String],
) -> (Bytes, UInt) raise WiteError {
  let parser = Cursor::new(payload)
  let export_count = parser.read_u32_leb128()
  let kept_entries : Array[Bytes] = []
  let mut removed_count = 0U
  for _ in 0U..<export_count {
    let name = read_name_bytes(parser)
    let name_string = bytes_to_name_string(name)
    let kind = parser.read_byte().to_uint()
    let index = parser.read_u32_leb128()
    if keep_names.contains(name_string) {
      let entry : Array[Byte] = []
      append_name_bytes(entry, name)
      entry.push(kind.to_byte())
      entry.append(encode_u32_leb128(index)[:])
      kept_entries.push(Bytes::from_array(entry[:]))
    } else {
      removed_count += 1U
    }
  }
  let out : Array[Byte] = []
  out.append(encode_u32_leb128(kept_entries.length().reinterpret_as_uint())[:])
  for entry in kept_entries {
    out.append(entry[:].to_array())
  }
  (Bytes::from_array(out[:]), removed_count)
}

///|
fn rewrite_start_section_payload_for_dce_raise(
  payload : Bytes,
  index_map : Map[UInt, UInt],
) -> Bytes raise WiteError {
  let parser = Cursor::new(payload)
  let start_index = parser.read_u32_leb128()
  let remapped = remap_function_index_raise(start_index, index_map)
  Bytes::from_array(encode_u32_leb128(remapped))
}

///|
pub fn parse_function_type_indices(
  payload : Bytes,
) -> Array[UInt] raise WiteError {
  let parser = Cursor::new(payload)
  let count = parser.read_u32_leb128()
  let out : Array[UInt] = []
  for _ in 0U..<count {
    out.push(parser.read_u32_leb128())
  }
  out
}

///|
pub(all) struct ParsedTypeSectionEntry {
  raw : Bytes
  form : UInt
  referenced_type_indices : Array[UInt]
}

///|
fn maybe_collect_heap_type_ref_index(
  heap_type_bytes : Array[Byte],
  referenced_type_indices : Array[UInt],
) -> Unit {
  if heap_type_bytes.length() == 0 {
    return
  }
  let last = heap_type_bytes[heap_type_bytes.length() - 1].to_uint()
  // Signed heaptype immediates with sign bit set are negative builtins.
  if (last & 0x40U) != 0U {
    return
  }
  match decode_u32_leb128_bytes(Bytes::from_array(heap_type_bytes[:])) {
    Some(type_index) => push_unique_u32(referenced_type_indices, type_index)
    None => ()
  }
}

///|
fn read_heap_type_and_collect_refs_raise(
  parser : Cursor,
  referenced_type_indices : Array[UInt],
  context : String,
) -> Unit raise WiteError {
  let bytes : Array[Byte] = []
  let first = parser.read_byte()
  bytes.push(first)
  if (first & 0x80) != 0 {
    let mut consumed = 1
    while true {
      let b = parser.read_byte()
      bytes.push(b)
      consumed += 1
      if consumed > 5 {
        raise WiteError::InvalidFormat("heap type s33 overflow in " + context)
      }
      if (b & 0x80) == 0 {
        break
      }
    }
  }
  maybe_collect_heap_type_ref_index(bytes, referenced_type_indices)
}

///|
fn read_type_entry_val_type_refs_raise(
  parser : Cursor,
  referenced_type_indices : Array[UInt],
  context : String,
) -> Unit raise WiteError {
  let code = parser.read_byte().to_uint()
  match code {
    0x7fU | 0x7eU | 0x7dU | 0x7cU | 0x7bU | 0x70U | 0x6fU => ()
    0x63U | 0x64U =>
      read_heap_type_and_collect_refs_raise(
        parser, referenced_type_indices, context,
      )
    _ =>
      raise WiteError::InvalidFormat(
        "unsupported value type in " + context + ": " + code.to_string(),
      )
  }
}

///|
fn read_type_entry_storage_type_refs_raise(
  parser : Cursor,
  referenced_type_indices : Array[UInt],
  context : String,
) -> Unit raise WiteError {
  let code = parser.read_byte().to_uint()
  match code {
    0x78U | 0x77U => ()
    0x7fU | 0x7eU | 0x7dU | 0x7cU | 0x7bU | 0x70U | 0x6fU => ()
    0x63U | 0x64U =>
      read_heap_type_and_collect_refs_raise(
        parser, referenced_type_indices, context,
      )
    _ =>
      raise WiteError::InvalidFormat(
        "unsupported storage type in " + context + ": " + code.to_string(),
      )
  }
}

///|
fn read_type_entry_field_type_refs_raise(
  parser : Cursor,
  referenced_type_indices : Array[UInt],
  context : String,
) -> Unit raise WiteError {
  read_type_entry_storage_type_refs_raise(
    parser, referenced_type_indices, context,
  )
  let mutability = parser.read_byte().to_uint()
  if mutability > 1U {
    raise WiteError::InvalidFormat(
      "invalid field mutability in " + context + ": " + mutability.to_string(),
    )
  }
}

///|
pub fn parse_type_section_entries_with_refs_raise(
  payload : Bytes,
  context : String,
) -> Array[ParsedTypeSectionEntry] raise WiteError {
  let parser = Cursor::new(payload)
  let count = parser.read_u32_leb128()
  let out : Array[ParsedTypeSectionEntry] = []
  for _ in 0U..<count {
    let start = parser.get_pos()
    let form = parser.read_byte().to_uint()
    let referenced_type_indices : Array[UInt] = []
    match form {
      0x60U => {
        let param_count = parser.read_u32_leb128()
        for _ in 0U..<param_count {
          read_type_entry_val_type_refs_raise(
            parser, referenced_type_indices, context,
          )
        }
        let result_count = parser.read_u32_leb128()
        for _ in 0U..<result_count {
          read_type_entry_val_type_refs_raise(
            parser, referenced_type_indices, context,
          )
        }
      }
      0x5fU => {
        let field_count = parser.read_u32_leb128()
        for _ in 0U..<field_count {
          read_type_entry_field_type_refs_raise(
            parser, referenced_type_indices, context,
          )
        }
      }
      0x5eU =>
        read_type_entry_field_type_refs_raise(
          parser, referenced_type_indices, context,
        )
      _ =>
        raise WiteError::InvalidFormat(
          "unsupported type form in " + context + ": " + form.to_string(),
        )
    }
    let end_ = parser.get_pos()
    out.push({
      raw: payload[start:end_].to_bytes(),
      form,
      referenced_type_indices,
    })
  }
  out
}

///|
fn parse_type_section_entries_raise(
  payload : Bytes,
) -> Array[Bytes] raise WiteError {
  let parsed = parse_type_section_entries_with_refs_raise(
    payload, "type parser",
  )
  let out : Array[Bytes] = []
  for entry in parsed {
    out.push(entry.raw)
  }
  out
}

///|
pub(all) struct FunctionTypeEntry {
  params : Array[Bytes]
  results : Array[Bytes]
}

///|
fn parse_function_type_entries_raise(
  payload : Bytes,
  context : String,
) -> Array[FunctionTypeEntry] raise WiteError {
  let parser = Cursor::new(payload)
  let count = parser.read_u32_leb128()
  let out : Array[FunctionTypeEntry] = []
  for _ in 0U..<count {
    let form = parser.read_byte().to_uint()
    if form != 0x60U {
      raise WiteError::InvalidFormat(
        "unsupported type form in " + context + ": " + form.to_string(),
      )
    }
    let param_count = parser.read_u32_leb128()
    let params : Array[Bytes] = []
    for _ in 0U..<param_count {
      params.push(read_val_type_bytes_raise(parser))
    }
    let result_count = parser.read_u32_leb128()
    let results : Array[Bytes] = []
    for _ in 0U..<result_count {
      results.push(read_val_type_bytes_raise(parser))
    }
    out.push({ params, results })
  }
  out
}

///|
pub fn parse_function_type_entry_from_raw_raise(
  raw : Bytes,
  context : String,
) -> FunctionTypeEntry raise WiteError {
  let parser = Cursor::new(raw)
  let form = parser.read_byte().to_uint()
  if form != 0x60U {
    raise WiteError::InvalidFormat(
      "unsupported type form in " + context + ": " + form.to_string(),
    )
  }
  let param_count = parser.read_u32_leb128()
  let params : Array[Bytes] = []
  for _ in 0U..<param_count {
    params.push(read_val_type_bytes_raise(parser))
  }
  let result_count = parser.read_u32_leb128()
  let results : Array[Bytes] = []
  for _ in 0U..<result_count {
    results.push(read_val_type_bytes_raise(parser))
  }
  if not(parser.eof()) {
    raise WiteError::InvalidFormat(
      "trailing bytes in function type raw entry in " + context,
    )
  }
  { params, results }
}

///|
pub fn parse_function_type_param_count_from_raw_raise(
  raw : Bytes,
  context : String,
) -> UInt raise WiteError {
  let parser = Cursor::new(raw)
  let form = parser.read_byte().to_uint()
  if form != 0x60U {
    raise WiteError::InvalidFormat(
      "unsupported type form in " + context + ": " + form.to_string(),
    )
  }
  let param_count = parser.read_u32_leb128()
  for _ in 0U..<param_count {
    ignore(read_val_type_bytes_raise(parser))
  }
  let result_count = parser.read_u32_leb128()
  for _ in 0U..<result_count {
    ignore(read_val_type_bytes_raise(parser))
  }
  if not(parser.eof()) {
    raise WiteError::InvalidFormat(
      "trailing bytes in function type raw entry in " + context,
    )
  }
  param_count
}

///|
fn encode_function_type_entry(
  params : Array[Bytes],
  results : Array[Bytes],
) -> Bytes {
  let out : Array[Byte] = [0x60U.to_byte()]
  out.append(encode_u32_leb128(params.length().reinterpret_as_uint())[:])
  for param in params {
    out.append(param[:].to_array())
  }
  out.append(encode_u32_leb128(results.length().reinterpret_as_uint())[:])
  for result in results {
    out.append(result[:].to_array())
  }
  Bytes::from_array(out[:])
}

///|
fn encode_type_section_payload(entries : Array[Bytes]) -> Bytes {
  let out : Array[Byte] = []
  out.append(encode_u32_leb128(entries.length().reinterpret_as_uint())[:])
  for entry in entries {
    out.append(entry[:].to_array())
  }
  Bytes::from_array(out[:])
}

///|
fn find_type_entry_index(entries : Array[Bytes], target : Bytes) -> UInt? {
  for i in 0..<entries.length() {
    if bytes_equal(entries[i], target) {
      return Some(i.reinterpret_as_uint())
    }
  }
  None
}

///|
fn encode_function_section_payload_from_type_indices(
  type_indices : Array[UInt],
) -> Bytes {
  let out : Array[Byte] = []
  out.append(encode_u32_leb128(type_indices.length().reinterpret_as_uint())[:])
  for type_index in type_indices {
    out.append(encode_u32_leb128(type_index)[:])
  }
  Bytes::from_array(out[:])
}

///|
fn encode_code_section_payload_from_bodies(bodies : Array[Bytes]) -> Bytes {
  let out : Array[Byte] = []
  out.append(encode_u32_leb128(bodies.length().reinterpret_as_uint())[:])
  for body in bodies {
    out.append(encode_u32_leb128(body.length().reinterpret_as_uint())[:])
    out.append(body[:].to_array())
  }
  Bytes::from_array(out[:])
}

///|
fn rewrite_type_section_payload_for_keep_raise(
  payload : Bytes,
  keep_types : Array[Bool],
) -> Bytes raise WiteError {
  let entries = parse_type_section_entries_raise(payload)
  if entries.length() != keep_types.length() {
    raise WiteError::InvalidFormat(
      "type section length mismatch: type=" +
      entries.length().to_string() +
      " keep=" +
      keep_types.length().to_string(),
    )
  }
  let kept_entries : Array[Bytes] = []
  for i in 0..<entries.length() {
    if keep_types[i] {
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
fn rewrite_function_section_payload_for_dce_raise(
  payload : Bytes,
  keep_local : Array[Bool],
) -> Bytes raise WiteError {
  let types = parse_function_type_indices(payload)
  if types.length() != keep_local.length() {
    raise WiteError::InvalidFormat(
      "dce function section length mismatch: function=" +
      types.length().to_string() +
      " keep=" +
      keep_local.length().to_string(),
    )
  }
  let kept_types : Array[UInt] = []
  for i in 0..<types.length() {
    if keep_local[i] {
      kept_types.push(types[i])
    }
  }
  let out : Array[Byte] = []
  out.append(encode_u32_leb128(kept_types.length().reinterpret_as_uint())[:])
  for type_index in kept_types {
    out.append(encode_u32_leb128(type_index)[:])
  }
  Bytes::from_array(out[:])
}

///|
fn rewrite_function_section_payload_for_type_index_map_raise(
  payload : Bytes,
  type_index_map : Map[UInt, UInt],
) -> Bytes raise WiteError {
  let parser = Cursor::new(payload)
  let count = parser.read_u32_leb128()
  let out : Array[Byte] = []
  out.append(encode_u32_leb128(count)[:])
  for _ in 0U..<count {
    let old_type = parser.read_u32_leb128()
    out.append(
      encode_u32_leb128(remap_type_index_raise(old_type, type_index_map))[:],
    )
  }
  Bytes::from_array(out[:])
}

///|
fn collect_used_type_indices_from_import_section_raise(
  payload : Bytes,
) -> Array[UInt] raise WiteError {
  let parser = Cursor::new(payload)
  let count = parser.read_u32_leb128()
  let out : Array[UInt] = []
  for _ in 0U..<count {
    ignore(read_name_bytes(parser))
    ignore(read_name_bytes(parser))
    let kind = parser.read_byte().to_uint()
    match kind {
      0U => push_unique_u32(out, parser.read_u32_leb128())
      1U => {
        skip_heap_type(parser)
        parse_limits(parser)
      }
      2U => parse_limits(parser)
      3U => {
        ignore(read_val_type_bytes_raise(parser))
        ignore(parser.read_byte())
      }
      4U =>
        raise WiteError::InvalidFormat(
          "tag import is not supported in remove-unused-types",
        )
      _ =>
        raise WiteError::InvalidFormat(
          "unsupported import descriptor kind in remove-unused-types: " +
          kind.to_string(),
        )
    }
  }
  out
}

///|
fn rewrite_import_section_payload_for_type_index_map_raise(
  payload : Bytes,
  type_index_map : Map[UInt, UInt],
) -> Bytes raise WiteError {
  let parser = Cursor::new(payload)
  let count = parser.read_u32_leb128()
  let out : Array[Byte] = []
  out.append(encode_u32_leb128(count)[:])
  for _ in 0U..<count {
    let module_name = read_name_bytes(parser)
    let field_name = read_name_bytes(parser)
    let kind = parser.read_byte().to_uint()
    append_name_bytes(out, module_name)
    append_name_bytes(out, field_name)
    out.push(kind.to_byte())
    match kind {
      0U => {
        let old_type = parser.read_u32_leb128()
        out.append(
          encode_u32_leb128(remap_type_index_raise(old_type, type_index_map))[:],
        )
      }
      1U => {
        let start = parser.get_pos()
        skip_heap_type(parser)
        parse_limits(parser)
        let end_ = parser.get_pos()
        out.append(payload[start:end_].to_array())
      }
      2U => {
        let start = parser.get_pos()
        parse_limits(parser)
        let end_ = parser.get_pos()
        out.append(payload[start:end_].to_array())
      }
      3U => {
        out.append(read_val_type_bytes_raise(parser)[:].to_array())
        out.push(parser.read_byte())
      }
      4U =>
        raise WiteError::InvalidFormat(
          "tag import is not supported in remove-unused-types",
        )
      _ =>
        raise WiteError::InvalidFormat(
          "unsupported import descriptor kind in remove-unused-types: " +
          kind.to_string(),
        )
    }
  }
  Bytes::from_array(out[:])
}

///|
fn rewrite_instruction_function_indices_raise(
  instr_bytes : Bytes,
  spans : Array[InstrSpan],
  index_map : Map[UInt, UInt],
) -> Bytes raise WiteError {
  let out : Array[Byte] = []
  for span in spans {
    if span.opcode == 0x10U || span.opcode == 0xd2U {
      if span.end_ <= span.start + 1 {
        raise WiteError::InvalidFormat("invalid call/ref.func immediate")
      }
      let imm = instr_bytes[span.start + 1:span.end_].to_bytes()
      let old_index = match decode_u32_leb128_bytes(imm) {
        Some(v) => v
        None =>
          raise WiteError::InvalidFormat(
            "failed to decode function index immediate",
          )
      }
      let new_index = remap_function_index_raise(old_index, index_map)
      out.push(span.opcode.to_byte())
      out.append(encode_u32_leb128(new_index)[:])
    } else {
      out.append(instr_bytes[span.start:span.end_].to_array())
    }
  }
  Bytes::from_array(out[:])
}

///|
fn rewrite_code_body_for_dce_raise(
  body_bytes : Bytes,
  index_map : Map[UInt, UInt],
) -> Bytes raise WiteError {
  let prefix_end = parse_local_decl_prefix_end(body_bytes)
  let instr_bytes = body_bytes[prefix_end:body_bytes.length()].to_bytes()
  let spans = match parse_instruction_spans(instr_bytes) {
    Some(v) => v
    None => raise WiteError::InvalidFormat("unsupported opcode in dce apply")
  }
  let rewritten_instr = rewrite_instruction_function_indices_raise(
    instr_bytes, spans, index_map,
  )
  let out : Array[Byte] = body_bytes[0:prefix_end].to_array()
  out.append(rewritten_instr[:].to_array())
  Bytes::from_array(out[:])
}

///|
fn rewrite_code_section_payload_for_dce_raise(
  payload : Bytes,
  keep_local : Array[Bool],
  index_map : Map[UInt, UInt],
) -> Bytes raise WiteError {
  let bodies = parse_code_bodies(payload)
  if bodies.length() != keep_local.length() {
    raise WiteError::InvalidFormat(
      "dce code section length mismatch: code=" +
      bodies.length().to_string() +
      " keep=" +
      keep_local.length().to_string(),
    )
  }
  let kept_bodies : Array[Bytes] = []
  for i in 0..<bodies.length() {
    if keep_local[i] {
      kept_bodies.push(rewrite_code_body_for_dce_raise(bodies[i], index_map))
    }
  }
  let out : Array[Byte] = []
  out.append(encode_u32_leb128(kept_bodies.length().reinterpret_as_uint())[:])
  for body in kept_bodies {
    out.append(encode_u32_leb128(body.length().reinterpret_as_uint())[:])
    out.append(body[:].to_array())
  }
  Bytes::from_array(out[:])
}

///|
fn decode_call_indirect_immediate(imm : Bytes) -> (UInt, UInt)? {
  let parser = Cursor::new(imm)
  let result = try? {
    let type_index = parser.read_u32_leb128()
    let table_index = parser.read_u32_leb128()
    if not(parser.eof()) {
      raise WiteError::InvalidFormat(
        "call_indirect immediate has trailing bytes",
      )
    }
    (type_index, table_index)
  }
  match result {
    Ok(v) => Some(v)
    Err(_) => None
  }
}

///|
fn collect_used_type_indices_from_instruction_raise(
  instr_bytes : Bytes,
  spans : Array[InstrSpan],
) -> Array[UInt] raise WiteError {
  let out : Array[UInt] = []
  for span in spans {
    if span.opcode == 0x11U {
      if span.end_ <= span.start + 1 {
        raise WiteError::InvalidFormat("invalid call_indirect immediate")
      }
      let imm = instr_bytes[span.start + 1:span.end_].to_bytes()
      match decode_call_indirect_immediate(imm) {
        Some((type_index, _table_index)) => push_unique_u32(out, type_index)
        None =>
          raise WiteError::InvalidFormat(
            "failed to decode call_indirect immediate",
          )
      }
    }
  }
  out
}

///|
fn collect_used_type_indices_from_code_section_raise(
  payload : Bytes,
) -> Array[UInt] raise WiteError {
  let out : Array[UInt] = []
  let bodies = parse_code_bodies(payload)
  for body in bodies {
    let prefix_end = parse_local_decl_prefix_end(body)
    let instr_bytes = body[prefix_end:body.length()].to_bytes()
    let spans = parse_instruction_spans_raise(instr_bytes)
    for
      type_index in collect_used_type_indices_from_instruction_raise(
        instr_bytes, spans,
      ) {
      push_unique_u32(out, type_index)
    }
  }
  out
}

///|
fn rewrite_instruction_type_indices_raise(
  instr_bytes : Bytes,
  spans : Array[InstrSpan],
  type_index_map : Map[UInt, UInt],
) -> Bytes raise WiteError {
  let out : Array[Byte] = []
  for span in spans {
    if span.opcode == 0x11U {
      if span.end_ <= span.start + 1 {
        raise WiteError::InvalidFormat("invalid call_indirect immediate")
      }
      let imm = instr_bytes[span.start + 1:span.end_].to_bytes()
      let (old_type_index, table_index) = match
        decode_call_indirect_immediate(imm) {
        Some(v) => v
        None =>
          raise WiteError::InvalidFormat(
            "failed to decode call_indirect immediate",
          )
      }
      out.push(0x11U.to_byte())
      out.append(
        encode_u32_leb128(
          remap_type_index_raise(old_type_index, type_index_map),
        )[:],
      )
      out.append(encode_u32_leb128(table_index)[:])
    } else {
      out.append(instr_bytes[span.start:span.end_].to_array())
    }
  }
  Bytes::from_array(out[:])
}

///|
fn rewrite_code_body_for_type_index_map_raise(
  body_bytes : Bytes,
  type_index_map : Map[UInt, UInt],
) -> Bytes raise WiteError {
  let prefix_end = parse_local_decl_prefix_end(body_bytes)
  let instr_bytes = body_bytes[prefix_end:body_bytes.length()].to_bytes()
  let spans = parse_instruction_spans_raise(instr_bytes)
  let rewritten_instr = rewrite_instruction_type_indices_raise(
    instr_bytes, spans, type_index_map,
  )
  let out : Array[Byte] = body_bytes[0:prefix_end].to_array()
  out.append(rewritten_instr[:].to_array())
  Bytes::from_array(out[:])
}

///|
fn rewrite_code_section_payload_for_type_index_map_raise(
  payload : Bytes,
  type_index_map : Map[UInt, UInt],
) -> Bytes raise WiteError {
  let bodies = parse_code_bodies(payload)
  let out : Array[Byte] = []
  out.append(encode_u32_leb128(bodies.length().reinterpret_as_uint())[:])
  for body in bodies {
    let rewritten = rewrite_code_body_for_type_index_map_raise(
      body, type_index_map,
    )
    out.append(encode_u32_leb128(rewritten.length().reinterpret_as_uint())[:])
    out.append(rewritten[:].to_array())
  }
  Bytes::from_array(out[:])
}

///|
fn collect_used_param_indices_from_instruction_raise(
  instr_bytes : Bytes,
  spans : Array[InstrSpan],
  param_count : UInt,
) -> Array[UInt] raise WiteError {
  let out : Array[UInt] = []
  for span in spans {
    if span.opcode == 0x20U || span.opcode == 0x21U || span.opcode == 0x22U {
      match decode_span_u32_immediate(instr_bytes, span) {
        Some(local_index) =>
          if local_index < param_count {
            push_unique_u32(out, local_index)
          }
        None =>
          raise WiteError::InvalidFormat(
            "failed to decode local index immediate",
          )
      }
    }
  }
  out
}

///|
fn compute_removed_trailing_param_count(
  param_count : UInt,
  used_param_indices : Array[UInt],
) -> UInt {
  let mut keep_param_count = param_count
  while keep_param_count > 0U {
    let trailing = keep_param_count - 1U
    if used_param_indices.contains(trailing) {
      break
    }
    keep_param_count -= 1U
  }
  param_count - keep_param_count
}

///|
fn remap_local_index_for_signature_pruning_raise(
  local_index : UInt,
  old_param_count : UInt,
  removed_param_count : UInt,
) -> UInt raise WiteError {
  if removed_param_count == 0U {
    return local_index
  }
  if old_param_count < removed_param_count {
    raise WiteError::InvalidFormat(
      "invalid signature-prune param count: old=" +
      old_param_count.to_string() +
      " removed=" +
      removed_param_count.to_string(),
    )
  }
  let kept_param_count = old_param_count - removed_param_count
  if local_index < kept_param_count {
    return local_index
  }
  if local_index < old_param_count {
    raise WiteError::InvalidFormat(
      "signature-prune touched removed param index: " + local_index.to_string(),
    )
  }
  local_index - removed_param_count
}

///|
fn rewrite_instruction_local_indices_for_signature_pruning_raise(
  instr_bytes : Bytes,
  spans : Array[InstrSpan],
  old_param_count : UInt,
  removed_param_count : UInt,
) -> Bytes raise WiteError {
  if removed_param_count == 0U {
    return instr_bytes
  }
  let out : Array[Byte] = []
  for span in spans {
    if span.opcode == 0x20U || span.opcode == 0x21U || span.opcode == 0x22U {
      if span.end_ <= span.start + 1 {
        raise WiteError::InvalidFormat("invalid local immediate")
      }
      let imm = instr_bytes[span.start + 1:span.end_].to_bytes()
      let local_index = match decode_u32_leb128_bytes(imm) {
        Some(v) => v
        None =>
          raise WiteError::InvalidFormat(
            "failed to decode local index immediate",
          )
      }
      let remapped = remap_local_index_for_signature_pruning_raise(
        local_index, old_param_count, removed_param_count,
      )
      out.push(span.opcode.to_byte())
      out.append(encode_u32_leb128(remapped)[:])
    } else {
      out.append(instr_bytes[span.start:span.end_].to_array())
    }
  }
  Bytes::from_array(out[:])
}

///|
fn rewrite_code_body_for_signature_pruning_raise(
  body_bytes : Bytes,
  old_param_count : UInt,
  removed_param_count : UInt,
) -> Bytes raise WiteError {
  if removed_param_count == 0U {
    return body_bytes
  }
  let prefix_end = parse_local_decl_prefix_end(body_bytes)
  let instr_bytes = body_bytes[prefix_end:body_bytes.length()].to_bytes()
  let spans = parse_instruction_spans_raise(instr_bytes)
  let rewritten_instr = rewrite_instruction_local_indices_for_signature_pruning_raise(
    instr_bytes, spans, old_param_count, removed_param_count,
  )
  let out : Array[Byte] = body_bytes[0:prefix_end].to_array()
  out.append(rewritten_instr[:].to_array())
  Bytes::from_array(out[:])
}

///|
fn rewrite_instruction_calls_for_signature_pruning_raise(
  instr_bytes : Bytes,
  spans : Array[InstrSpan],
  removed_param_count_by_function : Map[UInt, UInt],
) -> Bytes raise WiteError {
  let out : Array[Byte] = []
  for span in spans {
    if span.opcode == 0x10U {
      if span.end_ <= span.start + 1 {
        raise WiteError::InvalidFormat("invalid call immediate")
      }
      let imm = instr_bytes[span.start + 1:span.end_].to_bytes()
      let target = match decode_u32_leb128_bytes(imm) {
        Some(v) => v
        None =>
          raise WiteError::InvalidFormat("failed to decode call immediate")
      }
      let removed_param_count = match
        removed_param_count_by_function.get(target) {
        Some(v) => v
        None => 0U
      }
      for _ in 0U..<removed_param_count {
        out.push(0x1aU.to_byte())
      }
      out.append(instr_bytes[span.start:span.end_].to_array())
    } else {
      out.append(instr_bytes[span.start:span.end_].to_array())
    }
  }
  Bytes::from_array(out[:])
}

///|
fn rewrite_code_body_calls_for_signature_pruning_raise(
  body_bytes : Bytes,
  removed_param_count_by_function : Map[UInt, UInt],
) -> Bytes raise WiteError {
  let prefix_end = parse_local_decl_prefix_end(body_bytes)
  let instr_bytes = body_bytes[prefix_end:body_bytes.length()].to_bytes()
  let spans = parse_instruction_spans_raise(instr_bytes)
  let rewritten_instr = rewrite_instruction_calls_for_signature_pruning_raise(
    instr_bytes, spans, removed_param_count_by_function,
  )
  let out : Array[Byte] = body_bytes[0:prefix_end].to_array()
  out.append(rewritten_instr[:].to_array())
  Bytes::from_array(out[:])
}

///|
fn is_single_val_type(val_type : Bytes, expected_code : UInt) -> Bool {
  val_type.length() == 1 && val_type[0].to_uint() == expected_code
}

///|
fn is_const_opcode_compatible_with_result(
  opcode : UInt,
  result_type : Bytes,
) -> Bool {
  match opcode {
    0x41U => is_single_val_type(result_type, 0x7fU)
    0x42U => is_single_val_type(result_type, 0x7eU)
    0x43U => is_single_val_type(result_type, 0x7dU)
    0x44U => is_single_val_type(result_type, 0x7cU)
    _ => false
  }
}

///|
fn extract_inlining_replacement_instr_raise(
  body_bytes : Bytes,
  type_entry : FunctionTypeEntry,
) -> Bytes? raise WiteError {
  let prefix = parse_local_decl_prefix_raise(body_bytes)
  if prefix.local_types.length() > 0 {
    return None
  }
  let instr_bytes = body_bytes[prefix.prefix_end:body_bytes.length()].to_bytes()
  let spans = parse_instruction_spans_raise(instr_bytes)
  if type_entry.params.length() == 0 &&
    type_entry.results.length() == 0 &&
    spans.length() == 1 &&
    spans[0].opcode == 0x0bU {
    return Some(Bytes::from_array([]))
  }
  if spans.length() == 2 && spans[1].opcode == 0x0bU {
    if type_entry.params.length() == 1 &&
      type_entry.results.length() == 1 &&
      bytes_equal(type_entry.params[0], type_entry.results[0]) &&
      spans[0].opcode == 0x20U &&
      decode_local_index_immediate_from_span(instr_bytes, spans[0]) == Some(0U) {
      return Some(Bytes::from_array([]))
    }
    if type_entry.params.length() == 0 &&
      type_entry.results.length() == 1 &&
      is_const_opcode_compatible_with_result(
        spans[0].opcode,
        type_entry.results[0],
      ) {
      return Some(instr_bytes[spans[0].start:spans[0].end_].to_bytes())
    }
  }
  None
}

///|
fn rewrite_instruction_calls_for_inlining_raise(
  instr_bytes : Bytes,
  spans : Array[InstrSpan],
  replacement_by_function_index : Map[UInt, Bytes],
) -> (Bytes, UInt) raise WiteError {
  let out : Array[Byte] = []
  let mut rewritten_call_count = 0U
  for span in spans {
    if span.opcode == 0x10U {
      if span.end_ <= span.start + 1 {
        raise WiteError::InvalidFormat("invalid call immediate in inlining")
      }
      let imm = instr_bytes[span.start + 1:span.end_].to_bytes()
      let target = match decode_u32_leb128_bytes(imm) {
        Some(v) => v
        None =>
          raise WiteError::InvalidFormat(
            "failed to decode call immediate in inlining",
          )
      }
      match replacement_by_function_index.get(target) {
        Some(replacement) => {
          let call_span_len = (span.end_ - span.start).reinterpret_as_uint()
          let replacement_len = replacement.length().reinterpret_as_uint()
          if replacement_len <= call_span_len {
            out.append(replacement[:].to_array())
            rewritten_call_count += 1U
          } else {
            out.append(instr_bytes[span.start:span.end_].to_array())
          }
        }
        None => out.append(instr_bytes[span.start:span.end_].to_array())
      }
    } else {
      out.append(instr_bytes[span.start:span.end_].to_array())
    }
  }
  (Bytes::from_array(out[:]), rewritten_call_count)
}

///|
priv struct InliningApplyResult {
  bytes : Bytes
  inlined_call_count : UInt
}

///|
fn apply_inlining_optimizing(bytes : Bytes) -> InliningApplyResult {
  let result = try? apply_inlining_optimizing_raise(bytes)
  match result {
    Ok(v) => v
    Err(_) => { bytes, inlined_call_count: 0U }
  }
}

///|
fn apply_inlining_optimizing_raise(
  bytes : Bytes,
) -> InliningApplyResult raise WiteError {
  let sections = parse_core_sections_raise(bytes)
  let mut type_section_payload : Bytes? = None
  let mut function_section_payload : Bytes? = None
  let mut code_section_payload : Bytes? = None
  let mut imported_function_count = 0U
  for section in sections {
    let payload = bytes[section.payload_start:section.section_end].to_bytes()
    match section.section_id {
      1U => type_section_payload = Some(payload)
      2U => imported_function_count += parse_import_function_count(payload)
      3U => function_section_payload = Some(payload)
      10U => code_section_payload = Some(payload)
      _ => ()
    }
  }
  let type_payload = match type_section_payload {
    Some(v) => v
    None => return { bytes, inlined_call_count: 0U }
  }
  let function_payload = match function_section_payload {
    Some(v) => v
    None => return { bytes, inlined_call_count: 0U }
  }
  let code_payload = match code_section_payload {
    Some(v) => v
    None => return { bytes, inlined_call_count: 0U }
  }
  let type_entries = parse_function_type_entries_raise(type_payload, "inlining")
  let function_type_indices = parse_function_type_indices(function_payload)
  let code_bodies = parse_code_bodies(code_payload)
  if function_type_indices.length() != code_bodies.length() {
    raise WiteError::InvalidFormat(
      "function/code section count mismatch for inlining: function=" +
      function_type_indices.length().to_string() +
      " code=" +
      code_bodies.length().to_string(),
    )
  }
  let type_count_u = type_entries.length().reinterpret_as_uint()
  let replacement_by_function_index : Map[UInt, Bytes] = {}
  for i in 0..<code_bodies.length() {
    let type_index = function_type_indices[i]
    if type_index >= type_count_u {
      raise WiteError::InvalidFormat(
        "type index out of range in inlining: " + type_index.to_string(),
      )
    }
    let type_pos = UInt::reinterpret_as_int(type_index)
    if type_pos < 0 || type_pos >= type_entries.length() {
      raise WiteError::InvalidFormat(
        "type index position out of range in inlining: " +
        type_index.to_string(),
      )
    }
    match
      extract_inlining_replacement_instr_raise(
        code_bodies[i],
        type_entries[type_pos],
      ) {
      Some(replacement) =>
        replacement_by_function_index.set(
          imported_function_count + i.reinterpret_as_uint(),
          replacement,
        )
      None => ()
    }
  }
  let mut has_candidate = false
  replacement_by_function_index.each((_, _) => has_candidate = true)
  if not(has_candidate) {
    return { bytes, inlined_call_count: 0U }
  }
  let rewritten_bodies : Array[Bytes] = []
  let mut inlined_call_count = 0U
  for body in code_bodies {
    let prefix_end = parse_local_decl_prefix_end(body)
    let instr_bytes = body[prefix_end:body.length()].to_bytes()
    let spans = parse_instruction_spans_raise(instr_bytes)
    let (rewritten_instr, rewritten_call_count) = rewrite_instruction_calls_for_inlining_raise(
      instr_bytes, spans, replacement_by_function_index,
    )
    inlined_call_count += rewritten_call_count
    if rewritten_call_count > 0U {
      let rewritten_body : Array[Byte] = body[0:prefix_end].to_array()
      rewritten_body.append(rewritten_instr[:].to_array())
      rewritten_bodies.push(Bytes::from_array(rewritten_body[:]))
    } else {
      rewritten_bodies.push(body)
    }
  }
  if inlined_call_count == 0U {
    return { bytes, inlined_call_count: 0U }
  }
  let rewritten_code_payload = encode_code_section_payload_from_bodies(
    rewritten_bodies,
  )
  let out : Array[Byte] = bytes[0:8].to_array()
  for section in sections {
    if section.section_id == 10U {
      append_encoded_section(out, 10U, rewritten_code_payload)
    } else {
      out.append(bytes[section.section_start:section.section_end].to_array())
    }
  }
  { bytes: Bytes::from_array(out[:]), inlined_call_count }
}

///|
