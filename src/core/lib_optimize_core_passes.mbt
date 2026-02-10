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
fn parse_function_type_indices(payload : Bytes) -> Array[UInt] raise WiteError {
  let parser = Cursor::new(payload)
  let count = parser.read_u32_leb128()
  let out : Array[UInt] = []
  for _ in 0U..<count {
    out.push(parser.read_u32_leb128())
  }
  out
}

///|
priv struct ParsedTypeSectionEntry {
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
fn parse_type_section_entries_with_refs_raise(
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
priv struct FunctionTypeEntry {
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
fn parse_function_type_entry_from_raw_raise(
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
fn parse_function_type_param_count_from_raw_raise(
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
fn is_dae_pure_producer_opcode(opcode : UInt) -> Bool {
  is_drop_elidable_producer_opcode(opcode)
}

///|
fn is_dae_pure_i32_unary_opcode(opcode : UInt) -> Bool {
  opcode == 0x45U || opcode == 0x67U || opcode == 0x68U || opcode == 0x69U
}

///|
fn is_dae_pure_i32_binary_opcode(opcode : UInt) -> Bool {
  opcode == 0x46U ||
  opcode == 0x47U ||
  opcode == 0x48U ||
  opcode == 0x49U ||
  opcode == 0x4aU ||
  opcode == 0x4bU ||
  opcode == 0x4cU ||
  opcode == 0x4dU ||
  opcode == 0x4eU ||
  opcode == 0x4fU ||
  opcode == 0x50U ||
  opcode == 0x51U ||
  opcode == 0x52U ||
  opcode == 0x53U ||
  opcode == 0x54U ||
  opcode == 0x55U ||
  opcode == 0x56U ||
  opcode == 0x57U ||
  opcode == 0x58U ||
  opcode == 0x59U ||
  opcode == 0x5aU ||
  opcode == 0x5bU ||
  opcode == 0x5cU ||
  opcode == 0x5dU ||
  opcode == 0x5eU ||
  opcode == 0x5fU ||
  opcode == 0x60U ||
  opcode == 0x61U ||
  opcode == 0x62U ||
  opcode == 0x63U ||
  opcode == 0x64U ||
  opcode == 0x65U ||
  opcode == 0x66U ||
  opcode == 0x6aU ||
  opcode == 0x6bU ||
  opcode == 0x6cU ||
  opcode == 0x71U ||
  opcode == 0x72U ||
  opcode == 0x73U ||
  opcode == 0x74U ||
  opcode == 0x75U ||
  opcode == 0x76U ||
  opcode == 0x77U ||
  opcode == 0x78U
}

///|
fn rewrite_instruction_for_dae_raise(
  instr_bytes : Bytes,
  spans : Array[InstrSpan],
) -> (Bytes, UInt) {
  let out : Array[Byte] = []
  let mut removed_instr_count = 0U
  let mut i = 0
  while i < spans.length() {
    if i + 3 < spans.length() &&
      is_dae_pure_producer_opcode(spans[i].opcode) &&
      is_dae_pure_producer_opcode(spans[i + 1].opcode) &&
      is_dae_pure_i32_binary_opcode(spans[i + 2].opcode) &&
      spans[i + 3].opcode == 0x1aU {
      removed_instr_count += 4U
      i += 4
      continue
    }
    if i + 2 < spans.length() &&
      is_dae_pure_producer_opcode(spans[i].opcode) &&
      is_dae_pure_i32_unary_opcode(spans[i + 1].opcode) &&
      spans[i + 2].opcode == 0x1aU {
      removed_instr_count += 3U
      i += 3
      continue
    }
    if i + 1 < spans.length() &&
      is_dae_pure_producer_opcode(spans[i].opcode) &&
      spans[i + 1].opcode == 0x1aU {
      removed_instr_count += 2U
      i += 2
      continue
    }
    out.append(instr_bytes[spans[i].start:spans[i].end_].to_array())
    i += 1
  }
  (Bytes::from_array(out[:]), removed_instr_count)
}

///|
fn apply_dae_instruction_bytes_raise(
  instr_bytes : Bytes,
) -> (Bytes, UInt) raise WiteError {
  let mut current = instr_bytes
  let mut removed_instr_count = 0U
  let mut rounds = 0
  while rounds < 16 {
    let spans = parse_instruction_spans_raise(current)
    let (rewritten, removed) = rewrite_instruction_for_dae_raise(current, spans)
    if removed == 0U {
      break
    }
    current = rewritten
    removed_instr_count += removed
    rounds += 1
  }
  (current, removed_instr_count)
}

///|
priv struct DaeApplyResult {
  bytes : Bytes
  removed_instr_count : UInt
}

///|
fn apply_dae_optimizing(bytes : Bytes) -> DaeApplyResult {
  let result = try? apply_dae_optimizing_raise(bytes)
  match result {
    Ok(v) => v
    Err(_) => { bytes, removed_instr_count: 0U }
  }
}

///|
fn apply_dae_optimizing_raise(bytes : Bytes) -> DaeApplyResult raise WiteError {
  let sections = parse_core_sections_raise(bytes)
  let mut code_section_payload : Bytes? = None
  for section in sections {
    if section.section_id == 10U {
      code_section_payload = Some(
        bytes[section.payload_start:section.section_end].to_bytes(),
      )
      break
    }
  }
  let code_payload = match code_section_payload {
    Some(v) => v
    None => return { bytes, removed_instr_count: 0U }
  }
  let code_bodies = parse_code_bodies(code_payload)
  let rewritten_bodies : Array[Bytes] = []
  let mut removed_instr_count = 0U
  for body in code_bodies {
    let prefix_end = parse_local_decl_prefix_end(body)
    let instr_bytes = body[prefix_end:body.length()].to_bytes()
    let (rewritten_instr, removed) = apply_dae_instruction_bytes_raise(
      instr_bytes,
    )
    removed_instr_count += removed
    if removed > 0U {
      let rewritten_body : Array[Byte] = body[0:prefix_end].to_array()
      rewritten_body.append(rewritten_instr[:].to_array())
      rewritten_bodies.push(Bytes::from_array(rewritten_body[:]))
    } else {
      rewritten_bodies.push(body)
    }
  }
  if removed_instr_count == 0U {
    return { bytes, removed_instr_count: 0U }
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
  { bytes: Bytes::from_array(out[:]), removed_instr_count }
}

///|
fn is_const_opcode(opcode : UInt) -> Bool {
  opcode == 0x41U || opcode == 0x42U || opcode == 0x43U || opcode == 0x44U
}

///|
fn is_drop_elidable_producer_opcode(opcode : UInt) -> Bool {
  is_const_opcode(opcode) ||
  opcode == 0x20U ||
  opcode == 0x23U ||
  opcode == 0xd0U ||
  opcode == 0xd2U
}

///|
fn is_drop_elidable_producer_span(
  instr_bytes : Bytes,
  span : InstrSpan,
) -> Bool {
  if is_drop_elidable_producer_opcode(span.opcode) || span.opcode == 0x3fU {
    return true
  }
  if span.opcode == 0xfcU {
    match parse_prefixed_opcode_subopcode(instr_bytes, span) {
      Some(16U) => return true
      _ => ()
    }
  }
  false
}

///|
fn is_block_start_opcode(opcode : UInt) -> Bool {
  opcode == 0x02U || opcode == 0x03U || opcode == 0x04U
}

///|
fn is_branch_opcode(opcode : UInt) -> Bool {
  opcode == 0x0cU || opcode == 0x0dU || opcode == 0x0eU
}

///|
fn decode_span_u32_immediate(instr_bytes : Bytes, span : InstrSpan) -> UInt? {
  decode_u32_leb128_range(instr_bytes, span.start + 1, span.end_)
}

///|
fn decode_nonnegative_i32_leb128_bytes(bytes : Bytes) -> UInt? {
  if bytes.length() == 0 || bytes.length() > 5 {
    return None
  }
  let last = bytes[bytes.length() - 1].to_uint()
  if (last & 0x80U) != 0U {
    return None
  }
  if (last & 0x40U) != 0U {
    return None
  }
  decode_u32_leb128_bytes(bytes)
}

///|
fn decode_i32_const_nonnegative_from_span(
  instr_bytes : Bytes,
  span : InstrSpan,
) -> UInt? {
  if span.opcode != 0x41U || span.end_ <= span.start + 1 {
    return None
  }
  let imm = instr_bytes[span.start + 1:span.end_].to_bytes()
  decode_nonnegative_i32_leb128_bytes(imm)
}

///|
fn decode_i32_const_small_nonnegative_from_span(
  instr_bytes : Bytes,
  span : InstrSpan,
) -> UInt? {
  if span.end_ != span.start + 2 {
    return None
  }
  match decode_i32_const_nonnegative_from_span(instr_bytes, span) {
    Some(value) => if value <= 63U { Some(value) } else { None }
    None => None
  }
}

///|
fn decode_i32_const_small_signed_from_span(
  instr_bytes : Bytes,
  span : InstrSpan,
) -> Int? {
  if span.opcode != 0x41U || span.end_ != span.start + 2 {
    return None
  }
  let raw = instr_bytes[span.start + 1].to_uint()
  if (raw & 0x80U) != 0U {
    return None
  }
  if (raw & 0x40U) == 0U {
    Some(raw.reinterpret_as_int())
  } else {
    Some(raw.reinterpret_as_int() - 128)
  }
}

///|
fn decode_local_index_immediate_from_span(
  instr_bytes : Bytes,
  span : InstrSpan,
) -> UInt? {
  if span.opcode != 0x20U && span.opcode != 0x21U && span.opcode != 0x22U {
    return None
  }
  decode_span_u32_immediate(instr_bytes, span)
}

///|
fn instr_spans_to_bytes(instr_bytes : Bytes, spans : Array[InstrSpan]) -> Bytes {
  let out : Array[Byte] = []
  for span in spans {
    out.append(instr_bytes[span.start:span.end_].to_array())
  }
  Bytes::from_array(out[:])
}

///|
fn append_i32_const_small(out : Array[Byte], value : UInt) -> Unit {
  out.push(0x41U.to_byte())
  out.push(value.to_byte())
}

///|
fn is_i32_shift_rotate_opcode(opcode : UInt) -> Bool {
  opcode == 0x74U || // i32.shl
  opcode == 0x75U || // i32.shr_s
  opcode == 0x76U || // i32.shr_u
  opcode == 0x77U || // i32.rotl
  opcode == 0x78U // i32.rotr
}

///|
fn is_optimize_instructions_i32_identity_opcode(
  rhs_const : UInt,
  opcode : UInt,
) -> Bool {
  if is_i32_shift_rotate_opcode(opcode) && rhs_const % 32U == 0U {
    return true
  }
  match rhs_const {
    0U =>
      opcode == 0x6aU || // i32.add
      opcode == 0x6bU || // i32.sub
      opcode == 0x72U || // i32.or
      opcode == 0x73U || // i32.xor
      is_i32_shift_rotate_opcode(opcode)
    1U => opcode == 0x6cU // i32.mul
    _ => false
  }
}

///|
fn apply_optimize_instructions_i32_identity_ops(instr_bytes : Bytes) -> Bytes {
  let spans = match parse_instruction_spans(instr_bytes) {
    Some(v) => v
    None => return instr_bytes
  }
  let out : Array[Byte] = []
  let mut i = 0
  while i < spans.length() {
    if i + 1 < spans.length() && spans[i].opcode == 0x41U {
      match decode_i32_const_small_signed_from_span(instr_bytes, spans[i]) {
        Some(-1) =>
          if spans[i + 1].opcode == 0x71U {
            i += 2
            continue
          }
        _ => ()
      }
    }
    if i + 1 < spans.length() && spans[i].opcode == 0x41U {
      match
        decode_i32_const_small_nonnegative_from_span(instr_bytes, spans[i]) {
        Some(rhs_const) =>
          if is_optimize_instructions_i32_identity_opcode(
              rhs_const,
              spans[i + 1].opcode,
            ) {
            i += 2
            continue
          }
        None => ()
      }
    }
    out.append(instr_bytes[spans[i].start:spans[i].end_].to_array())
    i += 1
  }
  Bytes::from_array(out[:])
}

///|
fn is_optimize_instructions_i32_get_opcode(opcode : UInt) -> Bool {
  opcode == 0x20U || opcode == 0x23U
}

///|
fn apply_optimize_instructions_i32_const_cmp_bitwise(
  instr_bytes : Bytes,
) -> Bytes {
  let spans = match parse_instruction_spans(instr_bytes) {
    Some(v) => v
    None => return instr_bytes
  }
  let out : Array[Byte] = []
  let mut i = 0
  while i < spans.length() {
    if i + 2 < spans.length() &&
      is_optimize_instructions_i32_get_opcode(spans[i].opcode) &&
      spans[i + 1].opcode == 0x41U {
      let lhs = instr_bytes[spans[i].start:spans[i].end_]
      match
        decode_i32_const_small_nonnegative_from_span(instr_bytes, spans[i + 1]) {
        Some(0U) =>
          match spans[i + 2].opcode {
            0x71U
            // i32.and
            | 0x49U => { // i32.lt_u
              append_i32_const_small(out, 0U)
              i += 3
              continue
            }
            0x4fU => { // i32.ge_u
              append_i32_const_small(out, 1U)
              i += 3
              continue
            }
            0x46U | 0x4dU => { // i32.eq / i32.le_u => i32.eqz
              out.append(lhs.to_array())
              out.push(0x45U.to_byte())
              i += 3
              continue
            }
            0x47U | 0x4bU => { // i32.ne / i32.gt_u => i32.eqz; i32.eqz
              out.append(lhs.to_array())
              out.push(0x45U.to_byte())
              out.push(0x45U.to_byte())
              i += 3
              continue
            }
            _ => ()
          }
        _ => ()
      }
      match decode_i32_const_small_signed_from_span(instr_bytes, spans[i + 1]) {
        Some(-1) =>
          if spans[i + 2].opcode == 0x71U {
            // x & -1 => x
            out.append(lhs.to_array())
            i += 3
            continue
          }
        _ => ()
      }
    }
    if i + 2 < spans.length() &&
      spans[i].opcode == 0x41U &&
      is_optimize_instructions_i32_get_opcode(spans[i + 1].opcode) {
      let rhs = instr_bytes[spans[i + 1].start:spans[i + 1].end_]
      match
        decode_i32_const_small_nonnegative_from_span(instr_bytes, spans[i]) {
        Some(0U) =>
          match spans[i + 2].opcode {
            0x71U
            // i32.and
            | 0x6cU
            // i32.mul
            | 0x74U
            // i32.shl
            | 0x75U
            // i32.shr_s
            | 0x76U
            // i32.shr_u
            | 0x77U
            // i32.rotl
            | 0x78U => { // i32.rotr
              append_i32_const_small(out, 0U)
              i += 3
              continue
            }
            0x6aU | 0x72U | 0x73U => {
              // 0 + x / 0 | x / 0 ^ x => x
              out.append(rhs.to_array())
              i += 3
              continue
            }
            0x46U => { // 0 == x => x.eqz
              out.append(rhs.to_array())
              out.push(0x45U.to_byte())
              i += 3
              continue
            }
            0x47U => { // 0 != x => x.eqz; i32.eqz
              out.append(rhs.to_array())
              out.push(0x45U.to_byte())
              out.push(0x45U.to_byte())
              i += 3
              continue
            }
            _ => ()
          }
        Some(1U) =>
          if spans[i + 2].opcode == 0x6cU {
            // 1 * x => x
            out.append(rhs.to_array())
            i += 3
            continue
          }
        _ => ()
      }
      match decode_i32_const_small_signed_from_span(instr_bytes, spans[i]) {
        Some(-1) =>
          match spans[i + 2].opcode {
            0x71U => {
              // -1 & x => x
              out.append(rhs.to_array())
              i += 3
              continue
            }
            0x72U => {
              // -1 | x => -1
              out.append(instr_bytes[spans[i].start:spans[i].end_].to_array())
              i += 3
              continue
            }
            _ => ()
          }
        _ => ()
      }
    }
    out.append(instr_bytes[spans[i].start:spans[i].end_].to_array())
    i += 1
  }
  Bytes::from_array(out[:])
}

///|
fn apply_optimize_instructions_same_local_get_pair(
  instr_bytes : Bytes,
) -> Bytes {
  let spans = match parse_instruction_spans(instr_bytes) {
    Some(v) => v
    None => return instr_bytes
  }
  let out : Array[Byte] = []
  let mut i = 0
  while i < spans.length() {
    if i + 2 < spans.length() &&
      spans[i].opcode == 0x20U &&
      spans[i + 1].opcode == 0x20U {
      match decode_local_index_immediate_from_span(instr_bytes, spans[i]) {
        Some(first_local) =>
          match
            decode_local_index_immediate_from_span(instr_bytes, spans[i + 1]) {
            Some(second_local) =>
              if first_local == second_local {
                match spans[i + 2].opcode {
                  0x71U | 0x72U => {
                    // local.get x; local.get x; i32.and/or => local.get x
                    out.append(
                      instr_bytes[spans[i].start:spans[i].end_].to_array(),
                    )
                    i += 3
                    continue
                  }
                  0x46U | 0x4cU | 0x4dU | 0x4eU | 0x4fU => {
                    // x==x / x<=x / x>=x => 1
                    append_i32_const_small(out, 1U)
                    i += 3
                    continue
                  }
                  0x47U | 0x48U | 0x49U | 0x4aU | 0x4bU | 0x6bU | 0x73U => {
                    // x!=x / x<x / x>x / x-x / x^x => 0
                    append_i32_const_small(out, 0U)
                    i += 3
                    continue
                  }
                  _ => ()
                }
              }
            None => ()
          }
        None => ()
      }
    }
    out.append(instr_bytes[spans[i].start:spans[i].end_].to_array())
    i += 1
  }
  Bytes::from_array(out[:])
}

///|
fn apply_precompute_i32_add(instr_bytes : Bytes) -> Bytes {
  let spans = match parse_instruction_spans(instr_bytes) {
    Some(v) => v
    None => return instr_bytes
  }
  let out : Array[Byte] = []
  let mut i = 0
  while i < spans.length() {
    if i + 2 < spans.length() &&
      spans[i].opcode == 0x41U &&
      spans[i + 1].opcode == 0x41U &&
      spans[i + 2].opcode == 0x6aU {
      match
        decode_i32_const_small_nonnegative_from_span(instr_bytes, spans[i]) {
        Some(lhs) =>
          match
            decode_i32_const_small_nonnegative_from_span(
              instr_bytes,
              spans[i + 1],
            ) {
            Some(rhs) => {
              let sum = lhs + rhs
              if sum <= 63U {
                out.push(0x41U.to_byte())
                out.push(sum.to_byte())
                i += 3
                continue
              }
            }
            None => ()
          }
        None => ()
      }
    }
    out.append(instr_bytes[spans[i].start:spans[i].end_].to_array())
    i += 1
  }
  Bytes::from_array(out[:])
}

///|
fn apply_precompute_i32_identity_ops(instr_bytes : Bytes) -> Bytes {
  apply_optimize_instructions_i32_identity_ops(instr_bytes)
}

///|
fn apply_precompute_i32_eqz_const(instr_bytes : Bytes) -> Bytes {
  let spans = match parse_instruction_spans(instr_bytes) {
    Some(v) => v
    None => return instr_bytes
  }
  let out : Array[Byte] = []
  let mut i = 0
  while i < spans.length() {
    if i + 1 < spans.length() &&
      spans[i].opcode == 0x41U &&
      spans[i + 1].opcode == 0x45U {
      match
        decode_i32_const_small_nonnegative_from_span(instr_bytes, spans[i]) {
        Some(value) => {
          append_i32_const_small(out, if value == 0U { 1U } else { 0U })
          i += 2
          continue
        }
        None => ()
      }
    }
    out.append(instr_bytes[spans[i].start:spans[i].end_].to_array())
    i += 1
  }
  Bytes::from_array(out[:])
}

///|
fn apply_precompute_i32_double_eqz_br_if(instr_bytes : Bytes) -> Bytes {
  let spans = match parse_instruction_spans(instr_bytes) {
    Some(v) => v
    None => return instr_bytes
  }
  let out : Array[Byte] = []
  let mut i = 0
  while i < spans.length() {
    if i + 2 < spans.length() &&
      spans[i].opcode == 0x45U &&
      spans[i + 1].opcode == 0x45U &&
      spans[i + 2].opcode == 0x0dU {
      out.append(instr_bytes[spans[i + 2].start:spans[i + 2].end_].to_array())
      i += 3
      continue
    }
    out.append(instr_bytes[spans[i].start:spans[i].end_].to_array())
    i += 1
  }
  Bytes::from_array(out[:])
}

///|
fn is_local_const_propagation_barrier(opcode : UInt) -> Bool {
  opcode == 0x00U || // unreachable
  opcode == 0x02U || // block
  opcode == 0x03U || // loop
  opcode == 0x04U || // if
  opcode == 0x05U || // else
  opcode == 0x0bU || // end
  opcode == 0x0cU || // br
  opcode == 0x0dU || // br_if
  opcode == 0x0eU || // br_table
  opcode == 0x0fU
}

///|
fn known_local_const_get(known : Map[UInt, UInt], local_index : UInt) -> UInt? {
  match known.get(local_index) {
    Some(value) => if value == 0xffffffffU { None } else { Some(value) }
    None => None
  }
}

///|
fn apply_precompute_local_const_propagation(instr_bytes : Bytes) -> Bytes {
  let spans = match parse_instruction_spans(instr_bytes) {
    Some(v) => v
    None => return instr_bytes
  }
  let out : Array[Byte] = []
  let mut known_local_consts : Map[UInt, UInt] = {}
  for i in 0..<spans.length() {
    let span = spans[i]
    if span.opcode == 0x20U {
      match decode_local_index_immediate_from_span(instr_bytes, span) {
        Some(local_index) => {
          let mut adjacent_set_same_local = false
          if i > 0 && spans[i - 1].opcode == 0x21U {
            match
              decode_local_index_immediate_from_span(instr_bytes, spans[i - 1]) {
              Some(prev_set_index) =>
                if prev_set_index == local_index {
                  adjacent_set_same_local = true
                }
              None => ()
            }
          }
          if not(adjacent_set_same_local) {
            match known_local_const_get(known_local_consts, local_index) {
              Some(value) => {
                append_i32_const_small(out, value)
                if is_local_const_propagation_barrier(span.opcode) {
                  known_local_consts = {}
                }
                continue
              }
              None => ()
            }
          }
        }
        None => ()
      }
    } else if span.opcode == 0x21U || span.opcode == 0x22U {
      match decode_local_index_immediate_from_span(instr_bytes, span) {
        Some(local_index) => {
          let mut assigned_const : UInt? = None
          if i > 0 {
            assigned_const = decode_i32_const_small_nonnegative_from_span(
              instr_bytes,
              spans[i - 1],
            )
          }
          match assigned_const {
            Some(value) => known_local_consts.set(local_index, value)
            None => known_local_consts.set(local_index, 0xffffffffU)
          }
        }
        None => ()
      }
    }
    out.append(instr_bytes[span.start:span.end_].to_array())
    if is_local_const_propagation_barrier(span.opcode) {
      known_local_consts = {}
    }
  }
  Bytes::from_array(out[:])
}

///|
fn apply_precompute_br_if_const(instr_bytes : Bytes) -> Bytes {
  let spans = match parse_instruction_spans(instr_bytes) {
    Some(v) => v
    None => return instr_bytes
  }
  let out : Array[Byte] = []
  let mut i = 0
  while i < spans.length() {
    if i + 1 < spans.length() &&
      spans[i].opcode == 0x41U &&
      spans[i + 1].opcode == 0x0dU {
      match
        decode_i32_const_small_nonnegative_from_span(instr_bytes, spans[i]) {
        Some(0U) => {
          i += 2
          continue
        }
        Some(_) =>
          if spans[i + 1].end_ > spans[i + 1].start + 1 {
            out.push(0x0cU.to_byte())
            out.append(
              instr_bytes[spans[i + 1].start + 1:spans[i + 1].end_].to_array(),
            )
            i += 2
            continue
          }
        None => ()
      }
    }
    out.append(instr_bytes[spans[i].start:spans[i].end_].to_array())
    i += 1
  }
  Bytes::from_array(out[:])
}

///|
fn apply_simplify_local_set_get_to_tee(instr_bytes : Bytes) -> Bytes {
  let spans = match parse_instruction_spans(instr_bytes) {
    Some(v) => v
    None => return instr_bytes
  }
  let out : Array[Byte] = []
  let mut i = 0
  while i < spans.length() {
    if i + 1 < spans.length() &&
      spans[i].opcode == 0x21U &&
      spans[i + 1].opcode == 0x20U {
      match decode_local_index_immediate_from_span(instr_bytes, spans[i]) {
        Some(set_index) =>
          match
            decode_local_index_immediate_from_span(instr_bytes, spans[i + 1]) {
            Some(get_index) =>
              if set_index == get_index && spans[i].end_ > spans[i].start + 1 {
                out.push(0x22U.to_byte())
                out.append(
                  instr_bytes[spans[i].start + 1:spans[i].end_].to_array(),
                )
                i += 2
                continue
              }
            None => ()
          }
        None => ()
      }
    }
    out.append(instr_bytes[spans[i].start:spans[i].end_].to_array())
    i += 1
  }
  Bytes::from_array(out[:])
}

///|
fn apply_simplify_local_get_set_noop(instr_bytes : Bytes) -> Bytes {
  let spans = match parse_instruction_spans(instr_bytes) {
    Some(v) => v
    None => return instr_bytes
  }
  let out : Array[Byte] = []
  let mut i = 0
  while i < spans.length() {
    if i + 1 < spans.length() &&
      spans[i].opcode == 0x20U &&
      spans[i + 1].opcode == 0x21U {
      match decode_local_index_immediate_from_span(instr_bytes, spans[i]) {
        Some(get_index) =>
          match
            decode_local_index_immediate_from_span(instr_bytes, spans[i + 1]) {
            Some(set_index) =>
              if get_index == set_index {
                i += 2
                continue
              }
            None => ()
          }
        None => ()
      }
    }
    out.append(instr_bytes[spans[i].start:spans[i].end_].to_array())
    i += 1
  }
  Bytes::from_array(out[:])
}

///|
fn apply_simplify_local_get_tee_to_get(instr_bytes : Bytes) -> Bytes {
  let spans = match parse_instruction_spans(instr_bytes) {
    Some(v) => v
    None => return instr_bytes
  }
  let out : Array[Byte] = []
  let mut i = 0
  while i < spans.length() {
    if i + 1 < spans.length() &&
      spans[i].opcode == 0x20U &&
      spans[i + 1].opcode == 0x22U {
      match decode_local_index_immediate_from_span(instr_bytes, spans[i]) {
        Some(get_index) =>
          match
            decode_local_index_immediate_from_span(instr_bytes, spans[i + 1]) {
            Some(tee_index) =>
              if get_index == tee_index {
                out.append(instr_bytes[spans[i].start:spans[i].end_].to_array())
                i += 2
                continue
              }
            None => ()
          }
        None => ()
      }
    }
    out.append(instr_bytes[spans[i].start:spans[i].end_].to_array())
    i += 1
  }
  Bytes::from_array(out[:])
}

///|
fn apply_local_cse_get_set_get(instr_bytes : Bytes) -> Bytes {
  let spans = match parse_instruction_spans(instr_bytes) {
    Some(v) => v
    None => return instr_bytes
  }
  let out : Array[Byte] = []
  let mut i = 0
  while i < spans.length() {
    if i + 2 < spans.length() &&
      spans[i].opcode == 0x20U &&
      spans[i + 1].opcode == 0x21U &&
      spans[i + 2].opcode == 0x20U {
      match decode_local_index_immediate_from_span(instr_bytes, spans[i]) {
        Some(first_get_index) =>
          match
            decode_local_index_immediate_from_span(instr_bytes, spans[i + 2]) {
            Some(second_get_index) =>
              if first_get_index == second_get_index &&
                spans[i + 1].end_ > spans[i + 1].start + 1 {
                out.append(instr_bytes[spans[i].start:spans[i].end_].to_array())
                out.push(0x22U.to_byte())
                out.append(
                  instr_bytes[spans[i + 1].start + 1:spans[i + 1].end_].to_array(),
                )
                i += 3
                continue
              }
            None => ()
          }
        None => ()
      }
    }
    out.append(instr_bytes[spans[i].start:spans[i].end_].to_array())
    i += 1
  }
  Bytes::from_array(out[:])
}

///|
fn apply_simplify_local_tee_drop_to_set(instr_bytes : Bytes) -> Bytes {
  let spans = match parse_instruction_spans(instr_bytes) {
    Some(v) => v
    None => return instr_bytes
  }
  let out : Array[Byte] = []
  let mut i = 0
  while i < spans.length() {
    if i + 1 < spans.length() &&
      spans[i].opcode == 0x22U &&
      spans[i + 1].opcode == 0x1aU &&
      spans[i].end_ > spans[i].start + 1 {
      out.push(0x21U.to_byte())
      out.append(instr_bytes[spans[i].start + 1:spans[i].end_].to_array())
      i += 2
      continue
    }
    out.append(instr_bytes[spans[i].start:spans[i].end_].to_array())
    i += 1
  }
  Bytes::from_array(out[:])
}

///|
fn apply_rse_local_tee_set_same(instr_bytes : Bytes) -> Bytes {
  let spans = match parse_instruction_spans(instr_bytes) {
    Some(v) => v
    None => return instr_bytes
  }
  let out : Array[Byte] = []
  let mut i = 0
  while i < spans.length() {
    if i + 1 < spans.length() &&
      spans[i].opcode == 0x22U &&
      spans[i + 1].opcode == 0x21U {
      match decode_local_index_immediate_from_span(instr_bytes, spans[i]) {
        Some(tee_index) =>
          match
            decode_local_index_immediate_from_span(instr_bytes, spans[i + 1]) {
            Some(set_index) =>
              if tee_index == set_index && spans[i].end_ > spans[i].start + 1 {
                out.push(0x21U.to_byte())
                out.append(
                  instr_bytes[spans[i].start + 1:spans[i].end_].to_array(),
                )
                i += 2
                continue
              }
            None => ()
          }
        None => ()
      }
    }
    out.append(instr_bytes[spans[i].start:spans[i].end_].to_array())
    i += 1
  }
  Bytes::from_array(out[:])
}

///|
fn apply_basic_peephole_to_spans(
  instr_bytes : Bytes,
  spans : Array[InstrSpan],
  config : OptimizeConfig,
) -> Array[InstrSpan] {
  let out : Array[InstrSpan] = []
  let mut i = 0
  while i < spans.length() {
    let span = spans[i]
    if config.peephole_remove_nop && span.opcode == 0x01U {
      i += 1
      continue
    }
    if config.peephole_remove_const_drop &&
      i + 1 < spans.length() &&
      is_drop_elidable_producer_span(instr_bytes, span) &&
      spans[i + 1].opcode == 0x1aU {
      i += 2
      continue
    }
    out.push(span)
    i += 1
  }
  out
}

///|
fn apply_vacuum_to_spans(spans : Array[InstrSpan]) -> Array[InstrSpan] {
  let out : Array[InstrSpan] = []
  let mut dead = false
  let mut dead_depth = 0
  for span in spans {
    if dead {
      match span.opcode {
        0x02U | 0x03U | 0x04U => dead_depth += 1
        0x05U =>
          if dead_depth == 0 {
            out.push(span)
            dead = false
          }
        0x0bU =>
          if dead_depth == 0 {
            out.push(span)
            dead = false
          } else {
            dead_depth -= 1
          }
        _ => ()
      }
      continue
    }
    out.push(span)
    if span.opcode == 0x00U || span.opcode == 0x0fU || span.opcode == 0x0cU {
      dead = true
      dead_depth = 0
    }
  }
  out
}

///|
fn compute_matching_end_indices(spans : Array[InstrSpan]) -> Map[Int, Int] {
  let out : Map[Int, Int] = {}
  let stack : Array[Int] = []
  for i in 0..<spans.length() {
    let opcode = spans[i].opcode
    if is_block_start_opcode(opcode) {
      stack.push(i)
    } else if opcode == 0x0bU && stack.length() > 0 {
      let start = stack[stack.length() - 1]
      ignore(stack.pop())
      out.set(start, i)
    }
  }
  out
}

///|
fn has_branch_between(
  spans : Array[InstrSpan],
  start : Int,
  end_ : Int,
) -> Bool {
  for i in start..<end_ {
    if is_branch_opcode(spans[i].opcode) {
      return true
    }
  }
  false
}

///|
fn apply_merge_blocks_to_spans(spans : Array[InstrSpan]) -> Array[InstrSpan] {
  let matching_end = compute_matching_end_indices(spans)
  let remove : Array[Bool] = []
  for _ in 0..<spans.length() {
    remove.push(false)
  }
  for i in 0..<spans.length() {
    let opcode = spans[i].opcode
    if opcode == 0x02U || opcode == 0x03U {
      match matching_end.get(i) {
        Some(end_index) =>
          if not(has_branch_between(spans, i + 1, end_index)) {
            remove[i] = true
            remove[end_index] = true
          }
        None => ()
      }
    }
  }
  let out : Array[InstrSpan] = []
  for i in 0..<spans.length() {
    if not(remove[i]) {
      out.push(spans[i])
    }
  }
  out
}

///|
fn apply_remove_unused_brs_to_spans(
  instr_bytes : Bytes,
  spans : Array[InstrSpan],
) -> Array[InstrSpan] {
  let out : Array[InstrSpan] = []
  let label_stack : Array[Int] = [1]
  for i in 0..<spans.length() {
    let span = spans[i]
    let top_label = if label_stack.length() > 0 {
      label_stack[label_stack.length() - 1]
    } else {
      1
    }
    let mut remove_current = false
    if span.opcode == 0x0cU &&
      i + 1 < spans.length() &&
      spans[i + 1].opcode == 0x0bU &&
      top_label != 2 {
      if decode_span_u32_immediate(instr_bytes, span) is Some(0U) {
        remove_current = true
      }
    }
    if not(remove_current) {
      out.push(span)
    }
    match span.opcode {
      0x02U => label_stack.push(1)
      0x03U => label_stack.push(2)
      0x04U => label_stack.push(1)
      0x0bU => if label_stack.length() > 0 { ignore(label_stack.pop()) }
      _ => ()
    }
  }
  out
}

///|
fn optimize_instruction_bytes(
  instr_bytes : Bytes,
  config : OptimizeConfig,
) -> Bytes {
  let mut current_bytes = instr_bytes
  if config.enable_peephole {
    let mut local_simplify_round = 0
    while local_simplify_round < 6 {
      let before_local_simplify = current_bytes
      current_bytes = apply_precompute_i32_add(current_bytes)
      current_bytes = apply_precompute_i32_identity_ops(current_bytes)
      current_bytes = apply_precompute_i32_eqz_const(current_bytes)
      current_bytes = apply_precompute_i32_double_eqz_br_if(current_bytes)
      current_bytes = apply_precompute_local_const_propagation(current_bytes)
      current_bytes = apply_precompute_i32_add(current_bytes)
      current_bytes = apply_precompute_i32_double_eqz_br_if(current_bytes)
      current_bytes = apply_precompute_br_if_const(current_bytes)
      current_bytes = apply_optimize_instructions_i32_identity_ops(
        current_bytes,
      )
      current_bytes = apply_optimize_instructions_i32_const_cmp_bitwise(
        current_bytes,
      )
      current_bytes = apply_optimize_instructions_same_local_get_pair(
        current_bytes,
      )
      current_bytes = apply_simplify_local_set_get_to_tee(current_bytes)
      current_bytes = apply_simplify_local_tee_drop_to_set(current_bytes)
      current_bytes = apply_rse_local_tee_set_same(current_bytes)
      current_bytes = apply_simplify_local_get_set_noop(current_bytes)
      current_bytes = apply_simplify_local_get_tee_to_get(current_bytes)
      current_bytes = apply_local_cse_get_set_get(current_bytes)
      current_bytes = apply_simplify_local_tee_drop_to_set(current_bytes)
      current_bytes = apply_rse_local_tee_set_same(current_bytes)
      if bytes_equal(before_local_simplify, current_bytes) {
        break
      }
      local_simplify_round += 1
    }
  }
  let spans = match parse_instruction_spans(current_bytes) {
    Some(v) => v
    None => return current_bytes
  }
  let mut current = spans.copy()
  if config.enable_vacuum {
    current = apply_vacuum_to_spans(current)
  }
  if config.peephole_remove_nop || config.peephole_remove_const_drop {
    current = apply_basic_peephole_to_spans(current_bytes, current, config)
  }
  if config.enable_remove_unused_brs {
    current = apply_remove_unused_brs_to_spans(current_bytes, current)
  }
  if config.enable_merge_blocks {
    current = apply_merge_blocks_to_spans(current)
  }
  if config.enable_vacuum {
    current = apply_vacuum_to_spans(current)
  }
  instr_spans_to_bytes(current_bytes, current)
}

///|
priv struct LocalDeclPrefixParseResult {
  prefix_end : Int
  local_types : Array[Byte]
}

///|
fn parse_local_decl_prefix_raise(
  body_bytes : Bytes,
) -> LocalDeclPrefixParseResult raise WiteError {
  let parser = Cursor::new(body_bytes)
  let local_group_count = parser.read_u32_leb128()
  let local_types : Array[Byte] = []
  for _ in 0U..<local_group_count {
    let count = parser.read_u32_leb128()
    let val_type = parser.read_byte()
    for _ in 0U..<count {
      local_types.push(val_type)
    }
  }
  { prefix_end: parser.get_pos(), local_types }
}

///|
fn parse_local_decl_prefix_end(body_bytes : Bytes) -> Int raise WiteError {
  parse_local_decl_prefix_raise(body_bytes).prefix_end
}

///|
fn encode_local_decl_prefix_from_local_types(
  local_types : Array[Byte],
) -> Bytes {
  let out : Array[Byte] = []
  if local_types.length() == 0 {
    out.append(encode_u32_leb128(0U)[:])
    return Bytes::from_array(out[:])
  }
  let counts : Array[UInt] = []
  let values : Array[Byte] = []
  let mut current = local_types[0]
  let mut current_count = 1U
  for i in 1..<local_types.length() {
    let v = local_types[i]
    if v == current {
      current_count += 1U
    } else {
      counts.push(current_count)
      values.push(current)
      current = v
      current_count = 1U
    }
  }
  counts.push(current_count)
  values.push(current)
  out.append(encode_u32_leb128(counts.length().reinterpret_as_uint())[:])
  for i in 0..<counts.length() {
    out.append(encode_u32_leb128(counts[i])[:])
    out.push(values[i])
  }
  Bytes::from_array(out[:])
}

///|
fn optimize_code_body_bytes(
  body_bytes : Bytes,
  config : OptimizeConfig,
) -> Bytes {
  let prefix_result = try? parse_local_decl_prefix_end(body_bytes)
  let prefix_end = match prefix_result {
    Ok(v) => v
    Err(_) => return body_bytes
  }
  let instr_bytes = body_bytes[prefix_end:body_bytes.length()].to_bytes()
  let optimized_instr = optimize_instruction_bytes(instr_bytes, config)
  if optimized_instr.length() >= instr_bytes.length() {
    return body_bytes
  }
  let out : Array[Byte] = body_bytes[0:prefix_end].to_array()
  out.append(optimized_instr[:].to_array())
  Bytes::from_array(out[:])
}

///|
fn optimize_code_section_payload_raise(
  payload : Bytes,
  config : OptimizeConfig,
) -> Bytes raise WiteError {
  let parser = Cursor::new(payload)
  let body_count = parser.read_u32_leb128()
  let bodies : Array[Bytes] = []
  for _ in 0U..<body_count {
    let body_size_u = parser.read_u32_leb128()
    let body_size = UInt::reinterpret_as_int(body_size_u)
    if body_size < 0 {
      raise WiteError::InvalidFormat("code body size overflow")
    }
    let start = parser.get_pos()
    let end_ = start + body_size
    if end_ > payload.length() {
      raise WiteError::UnexpectedEof
    }
    let body_bytes = payload[start:end_].to_bytes()
    bodies.push(optimize_code_body_bytes(body_bytes, config))
    parser.set_pos(end_)
  }
  let out : Array[Byte] = []
  out.append(encode_u32_leb128(body_count)[:])
  for body in bodies {
    out.append(encode_u32_leb128(body.length().reinterpret_as_uint())[:])
    out.append(body[:].to_array())
  }
  Bytes::from_array(out[:])
}

///|
fn optimize_code_section_payload(
  payload : Bytes,
  config : OptimizeConfig,
) -> Bytes {
  let result = try? optimize_code_section_payload_raise(payload, config)
  match result {
    Ok(v) => v
    Err(_) => payload
  }
}

///|
fn collect_used_local_indices_from_instruction_raise(
  instr_bytes : Bytes,
  spans : Array[InstrSpan],
) -> Array[UInt] raise WiteError {
  let out : Array[UInt] = []
  for span in spans {
    if span.opcode == 0x20U || span.opcode == 0x21U || span.opcode == 0x22U {
      match decode_span_u32_immediate(instr_bytes, span) {
        Some(index) => push_unique_u32(out, index)
        None =>
          raise WiteError::InvalidFormat(
            "failed to decode local immediate in coalesce-locals",
          )
      }
    }
  }
  out
}

///|
fn rewrite_instruction_local_indices_for_coalesce_raise(
  instr_bytes : Bytes,
  spans : Array[InstrSpan],
  param_count : UInt,
  local_index_map : Map[UInt, UInt],
) -> Bytes raise WiteError {
  let out : Array[Byte] = []
  for span in spans {
    if span.opcode == 0x20U || span.opcode == 0x21U || span.opcode == 0x22U {
      if span.end_ <= span.start + 1 {
        raise WiteError::InvalidFormat("invalid local immediate")
      }
      let imm = instr_bytes[span.start + 1:span.end_].to_bytes()
      let old_index = match decode_u32_leb128_bytes(imm) {
        Some(v) => v
        None =>
          raise WiteError::InvalidFormat(
            "failed to decode local index immediate in coalesce-locals",
          )
      }
      let new_index = if old_index < param_count {
        old_index
      } else {
        match local_index_map.get(old_index) {
          Some(v) => v
          None =>
            raise WiteError::InvalidFormat(
              "coalesce-locals remap missing local index: " +
              old_index.to_string(),
            )
        }
      }
      out.push(span.opcode.to_byte())
      out.append(encode_u32_leb128(new_index)[:])
    } else {
      out.append(instr_bytes[span.start:span.end_].to_array())
    }
  }
  Bytes::from_array(out[:])
}

///|
priv struct CoalesceLocalsApplyResult {
  bytes : Bytes
  removed_local_count : UInt
}

///|
fn apply_coalesce_locals_raise(
  bytes : Bytes,
) -> CoalesceLocalsApplyResult raise WiteError {
  let sections = parse_core_sections_raise(bytes)
  let mut type_section_payload : Bytes? = None
  let mut function_section_payload : Bytes? = None
  let mut code_section_payload : Bytes? = None
  for section in sections {
    let payload = bytes[section.payload_start:section.section_end].to_bytes()
    match section.section_id {
      1U => type_section_payload = Some(payload)
      3U => function_section_payload = Some(payload)
      10U => code_section_payload = Some(payload)
      _ => ()
    }
  }
  let type_payload = match type_section_payload {
    Some(v) => v
    None => return { bytes, removed_local_count: 0U }
  }
  let function_payload = match function_section_payload {
    Some(v) => v
    None => return { bytes, removed_local_count: 0U }
  }
  let code_payload = match code_section_payload {
    Some(v) => v
    None => return { bytes, removed_local_count: 0U }
  }
  let function_type_indices = parse_function_type_indices(function_payload)
  let code_bodies = parse_code_bodies(code_payload)
  if function_type_indices.length() != code_bodies.length() {
    raise WiteError::InvalidFormat(
      "function/code section count mismatch for coalesce-locals: function=" +
      function_type_indices.length().to_string() +
      " code=" +
      code_bodies.length().to_string(),
    )
  }
  let type_entries = parse_function_type_entries_raise(
    type_payload, "coalesce-locals",
  )
  let rewritten_code_bodies = code_bodies.copy()
  let mut removed_local_count = 0U
  for i in 0..<code_bodies.length() {
    let type_index = function_type_indices[i]
    let type_pos = UInt::reinterpret_as_int(type_index)
    if type_pos < 0 || type_pos >= type_entries.length() {
      raise WiteError::InvalidFormat(
        "type index out of range in coalesce-locals: " + type_index.to_string(),
      )
    }
    let param_count = type_entries[type_pos].params
      .length()
      .reinterpret_as_uint()
    let body = code_bodies[i]
    let prefix = parse_local_decl_prefix_raise(body)
    if prefix.local_types.length() == 0 {
      continue
    }
    let instr_bytes = body[prefix.prefix_end:body.length()].to_bytes()
    let spans = parse_instruction_spans_raise(instr_bytes)
    let used_local_indices = collect_used_local_indices_from_instruction_raise(
      instr_bytes, spans,
    )
    let kept_local_types : Array[Byte] = []
    let local_index_map : Map[UInt, UInt] = {}
    let mut next_local = 0U
    for j in 0..<prefix.local_types.length() {
      let old_local_index = param_count + j.reinterpret_as_uint()
      if used_local_indices.contains(old_local_index) {
        let new_local_index = param_count + next_local
        local_index_map.set(old_local_index, new_local_index)
        kept_local_types.push(prefix.local_types[j])
        next_local += 1U
      }
    }
    if kept_local_types.length() == prefix.local_types.length() {
      continue
    }
    removed_local_count += (prefix.local_types.length() -
    kept_local_types.length()).reinterpret_as_uint()
    let rewritten_instr = rewrite_instruction_local_indices_for_coalesce_raise(
      instr_bytes, spans, param_count, local_index_map,
    )
    let rewritten_prefix = encode_local_decl_prefix_from_local_types(
      kept_local_types,
    )
    let rewritten_body : Array[Byte] = rewritten_prefix[:].to_array()
    rewritten_body.append(rewritten_instr[:].to_array())
    rewritten_code_bodies[i] = Bytes::from_array(rewritten_body[:])
  }
  if removed_local_count == 0U {
    return { bytes, removed_local_count }
  }
  let rewritten_code_payload = encode_code_section_payload_from_bodies(
    rewritten_code_bodies,
  )
  let out : Array[Byte] = bytes[0:8].to_array()
  for section in sections {
    if section.section_id == 10U {
      append_encoded_section(out, 10U, rewritten_code_payload)
    } else {
      out.append(bytes[section.section_start:section.section_end].to_array())
    }
  }
  { bytes: Bytes::from_array(out[:]), removed_local_count }
}

///|
fn apply_duplicate_import_elimination(
  bytes : Bytes,
) -> DuplicateImportElimApplyResult {
  let result = try? apply_duplicate_import_elimination_raise(bytes)
  match result {
    Ok(v) => v
    Err(_) =>
      {
        bytes,
        removed_import_count: 0U,
        removed_function_import_count: 0U,
        removed_table_import_count: 0U,
        removed_memory_import_count: 0U,
        removed_global_import_count: 0U,
        dropped_name_section: false,
      }
  }
}

///|
fn apply_duplicate_import_elimination_raise(
  bytes : Bytes,
) -> DuplicateImportElimApplyResult raise WiteError {
  let sections = parse_core_sections_raise(bytes)
  let mut import_section_payload : Bytes? = None
  let mut function_section_payload : Bytes? = None
  let mut table_section_payload : Bytes? = None
  let mut memory_section_payload : Bytes? = None
  let mut global_section_payload : Bytes? = None
  let mut element_section_payload : Bytes? = None
  let mut data_section_payload : Bytes? = None
  for section in sections {
    let payload = bytes[section.payload_start:section.section_end].to_bytes()
    match section.section_id {
      2U => import_section_payload = Some(payload)
      3U => function_section_payload = Some(payload)
      4U => table_section_payload = Some(payload)
      5U => memory_section_payload = Some(payload)
      6U => global_section_payload = Some(payload)
      9U => element_section_payload = Some(payload)
      11U => data_section_payload = Some(payload)
      _ => ()
    }
  }
  let import_payload = match import_section_payload {
    Some(v) => v
    None =>
      return {
        bytes,
        removed_import_count: 0U,
        removed_function_import_count: 0U,
        removed_table_import_count: 0U,
        removed_memory_import_count: 0U,
        removed_global_import_count: 0U,
        dropped_name_section: false,
      }
  }
  let import_entries = parse_import_section_entries_raise(import_payload)
  if import_entries.length() <= 1 {
    return {
      bytes,
      removed_import_count: 0U,
      removed_function_import_count: 0U,
      removed_table_import_count: 0U,
      removed_memory_import_count: 0U,
      removed_global_import_count: 0U,
      dropped_name_section: false,
    }
  }
  let mut imported_function_count = 0U
  let mut imported_table_count = 0U
  let mut imported_memory_count = 0U
  let mut imported_global_count = 0U
  for entry in import_entries {
    match entry.kind {
      0U => imported_function_count += 1U
      1U => imported_table_count += 1U
      2U => imported_memory_count += 1U
      3U => imported_global_count += 1U
      _ => ()
    }
  }
  let keep_function_imports : Array[Bool] = []
  for _ in 0U..<imported_function_count {
    keep_function_imports.push(true)
  }
  let keep_table_imports : Array[Bool] = []
  for _ in 0U..<imported_table_count {
    keep_table_imports.push(true)
  }
  let keep_memory_imports : Array[Bool] = []
  for _ in 0U..<imported_memory_count {
    keep_memory_imports.push(true)
  }
  let keep_global_imports : Array[Bool] = []
  for _ in 0U..<imported_global_count {
    keep_global_imports.push(true)
  }
  let unique_function_import_entries : Array[Bytes] = []
  let unique_function_import_indices : Array[UInt] = []
  let canonical_function_import_index : Map[UInt, UInt] = {}
  let unique_table_import_entries : Array[Bytes] = []
  let unique_table_import_indices : Array[UInt] = []
  let canonical_table_import_index : Map[UInt, UInt] = {}
  let unique_memory_import_entries : Array[Bytes] = []
  let unique_memory_import_indices : Array[UInt] = []
  let canonical_memory_import_index : Map[UInt, UInt] = {}
  let unique_global_import_entries : Array[Bytes] = []
  let unique_global_import_indices : Array[UInt] = []
  let canonical_global_import_index : Map[UInt, UInt] = {}
  let mut removed_function_import_count = 0U
  let mut removed_table_import_count = 0U
  let mut removed_memory_import_count = 0U
  let mut removed_global_import_count = 0U
  for entry in import_entries {
    match entry.kind {
      0U => {
        let mut canonical = entry.kind_index
        let mut found = false
        for i in 0..<unique_function_import_entries.length() {
          if bytes_equal(unique_function_import_entries[i], entry.bytes) {
            canonical = unique_function_import_indices[i]
            found = true
            break
          }
        }
        if not(found) {
          unique_function_import_entries.push(entry.bytes)
          unique_function_import_indices.push(entry.kind_index)
        }
        canonical_function_import_index.set(entry.kind_index, canonical)
        if canonical != entry.kind_index {
          let old_pos = UInt::reinterpret_as_int(entry.kind_index)
          if old_pos < 0 || old_pos >= keep_function_imports.length() {
            raise WiteError::InvalidFormat(
              "function import dedupe index out of range",
            )
          }
          keep_function_imports[old_pos] = false
          removed_function_import_count += 1U
        }
      }
      1U => {
        let mut canonical = entry.kind_index
        let mut found = false
        for i in 0..<unique_table_import_entries.length() {
          if bytes_equal(unique_table_import_entries[i], entry.bytes) {
            canonical = unique_table_import_indices[i]
            found = true
            break
          }
        }
        if not(found) {
          unique_table_import_entries.push(entry.bytes)
          unique_table_import_indices.push(entry.kind_index)
        }
        canonical_table_import_index.set(entry.kind_index, canonical)
        if canonical != entry.kind_index {
          let old_pos = UInt::reinterpret_as_int(entry.kind_index)
          if old_pos < 0 || old_pos >= keep_table_imports.length() {
            raise WiteError::InvalidFormat(
              "table import dedupe index out of range",
            )
          }
          keep_table_imports[old_pos] = false
          removed_table_import_count += 1U
        }
      }
      2U => {
        let mut canonical = entry.kind_index
        let mut found = false
        for i in 0..<unique_memory_import_entries.length() {
          if bytes_equal(unique_memory_import_entries[i], entry.bytes) {
            canonical = unique_memory_import_indices[i]
            found = true
            break
          }
        }
        if not(found) {
          unique_memory_import_entries.push(entry.bytes)
          unique_memory_import_indices.push(entry.kind_index)
        }
        canonical_memory_import_index.set(entry.kind_index, canonical)
        if canonical != entry.kind_index {
          let old_pos = UInt::reinterpret_as_int(entry.kind_index)
          if old_pos < 0 || old_pos >= keep_memory_imports.length() {
            raise WiteError::InvalidFormat(
              "memory import dedupe index out of range",
            )
          }
          keep_memory_imports[old_pos] = false
          removed_memory_import_count += 1U
        }
      }
      3U => {
        let mut canonical = entry.kind_index
        let mut found = false
        for i in 0..<unique_global_import_entries.length() {
          if bytes_equal(unique_global_import_entries[i], entry.bytes) {
            canonical = unique_global_import_indices[i]
            found = true
            break
          }
        }
        if not(found) {
          unique_global_import_entries.push(entry.bytes)
          unique_global_import_indices.push(entry.kind_index)
        }
        canonical_global_import_index.set(entry.kind_index, canonical)
        if canonical != entry.kind_index {
          let old_pos = UInt::reinterpret_as_int(entry.kind_index)
          if old_pos < 0 || old_pos >= keep_global_imports.length() {
            raise WiteError::InvalidFormat(
              "global import dedupe index out of range",
            )
          }
          keep_global_imports[old_pos] = false
          removed_global_import_count += 1U
        }
      }
      _ => ()
    }
  }
  let removed_import_count = removed_function_import_count +
    removed_table_import_count +
    removed_memory_import_count +
    removed_global_import_count
  if removed_import_count == 0U {
    return {
      bytes,
      removed_import_count: 0U,
      removed_function_import_count: 0U,
      removed_table_import_count: 0U,
      removed_memory_import_count: 0U,
      removed_global_import_count: 0U,
      dropped_name_section: false,
    }
  }
  let local_function_count = match function_section_payload {
    Some(payload) => parse_vec_count(payload)
    None => 0U
  }
  let local_table_count = match table_section_payload {
    Some(payload) =>
      parse_table_section_entries_raise(payload).length().reinterpret_as_uint()
    None => 0U
  }
  let local_memory_count = match memory_section_payload {
    Some(payload) =>
      parse_memory_section_entries_raise(payload).length().reinterpret_as_uint()
    None => 0U
  }
  let local_global_count = match global_section_payload {
    Some(payload) =>
      parse_global_section_entries_with_refs_raise(payload)
      .length()
      .reinterpret_as_uint()
    None => 0U
  }
  let function_index_map : Map[UInt, UInt] = {}
  let mut kept_function_import_count = 0U
  for i in 0U..<imported_function_count {
    let i_pos = UInt::reinterpret_as_int(i)
    if i_pos < 0 || i_pos >= keep_function_imports.length() {
      raise WiteError::InvalidFormat(
        "function import keep index out of range in dedupe map",
      )
    }
    if keep_function_imports[i_pos] {
      function_index_map.set(i, kept_function_import_count)
      kept_function_import_count += 1U
    }
  }
  for i in 0U..<imported_function_count {
    let i_pos = UInt::reinterpret_as_int(i)
    if i_pos < 0 || i_pos >= keep_function_imports.length() {
      raise WiteError::InvalidFormat(
        "function import keep index out of range in dedupe map canonical",
      )
    }
    if not(keep_function_imports[i_pos]) {
      let canonical = match canonical_function_import_index.get(i) {
        Some(v) => v
        None => i
      }
      function_index_map.set(
        i,
        remap_function_index_raise(canonical, function_index_map),
      )
    }
  }
  for i in 0U..<local_function_count {
    let old_index = imported_function_count + i
    function_index_map.set(old_index, kept_function_import_count + i)
  }
  let table_index_map : Map[UInt, UInt] = {}
  let mut kept_table_import_count = 0U
  for i in 0U..<imported_table_count {
    let i_pos = UInt::reinterpret_as_int(i)
    if i_pos < 0 || i_pos >= keep_table_imports.length() {
      raise WiteError::InvalidFormat(
        "table import keep index out of range in dedupe map",
      )
    }
    if keep_table_imports[i_pos] {
      table_index_map.set(i, kept_table_import_count)
      kept_table_import_count += 1U
    }
  }
  for i in 0U..<imported_table_count {
    let i_pos = UInt::reinterpret_as_int(i)
    if i_pos < 0 || i_pos >= keep_table_imports.length() {
      raise WiteError::InvalidFormat(
        "table import keep index out of range in dedupe map canonical",
      )
    }
    if not(keep_table_imports[i_pos]) {
      let canonical = match canonical_table_import_index.get(i) {
        Some(v) => v
        None => i
      }
      table_index_map.set(
        i,
        remap_table_index_raise(canonical, table_index_map),
      )
    }
  }
  for i in 0U..<local_table_count {
    let old_index = imported_table_count + i
    table_index_map.set(old_index, kept_table_import_count + i)
  }
  let memory_index_map : Map[UInt, UInt] = {}
  let mut kept_memory_import_count = 0U
  for i in 0U..<imported_memory_count {
    let i_pos = UInt::reinterpret_as_int(i)
    if i_pos < 0 || i_pos >= keep_memory_imports.length() {
      raise WiteError::InvalidFormat(
        "memory import keep index out of range in dedupe map",
      )
    }
    if keep_memory_imports[i_pos] {
      memory_index_map.set(i, kept_memory_import_count)
      kept_memory_import_count += 1U
    }
  }
  for i in 0U..<imported_memory_count {
    let i_pos = UInt::reinterpret_as_int(i)
    if i_pos < 0 || i_pos >= keep_memory_imports.length() {
      raise WiteError::InvalidFormat(
        "memory import keep index out of range in dedupe map canonical",
      )
    }
    if not(keep_memory_imports[i_pos]) {
      let canonical = match canonical_memory_import_index.get(i) {
        Some(v) => v
        None => i
      }
      memory_index_map.set(
        i,
        remap_memory_index_raise(canonical, memory_index_map),
      )
    }
  }
  for i in 0U..<local_memory_count {
    let old_index = imported_memory_count + i
    memory_index_map.set(old_index, kept_memory_import_count + i)
  }
  let global_index_map : Map[UInt, UInt] = {}
  let mut kept_global_import_count = 0U
  for i in 0U..<imported_global_count {
    let i_pos = UInt::reinterpret_as_int(i)
    if i_pos < 0 || i_pos >= keep_global_imports.length() {
      raise WiteError::InvalidFormat(
        "global import keep index out of range in dedupe map",
      )
    }
    if keep_global_imports[i_pos] {
      global_index_map.set(i, kept_global_import_count)
      kept_global_import_count += 1U
    }
  }
  for i in 0U..<imported_global_count {
    let i_pos = UInt::reinterpret_as_int(i)
    if i_pos < 0 || i_pos >= keep_global_imports.length() {
      raise WiteError::InvalidFormat(
        "global import keep index out of range in dedupe map canonical",
      )
    }
    if not(keep_global_imports[i_pos]) {
      let canonical = match canonical_global_import_index.get(i) {
        Some(v) => v
        None => i
      }
      global_index_map.set(
        i,
        remap_global_index_raise(canonical, global_index_map),
      )
    }
  }
  for i in 0U..<local_global_count {
    let old_index = imported_global_count + i
    global_index_map.set(old_index, kept_global_import_count + i)
  }
  let keep_local_functions : Array[Bool] = []
  for _ in 0U..<local_function_count {
    keep_local_functions.push(true)
  }
  let keep_local_globals : Array[Bool] = []
  for _ in 0U..<local_global_count {
    keep_local_globals.push(true)
  }
  let element_index_map = match element_section_payload {
    Some(payload) => make_identity_index_map(parse_vec_count(payload))
    None => make_identity_index_map(0U)
  }
  let data_index_map = match data_section_payload {
    Some(payload) => make_identity_index_map(parse_vec_count(payload))
    None => make_identity_index_map(0U)
  }
  let (rewritten_import_payload, removed_by_rewrite) = rewrite_import_section_payload_for_keep_kinds_raise(
    import_payload, keep_function_imports, keep_table_imports, keep_memory_imports,
    keep_global_imports,
  )
  let out : Array[Byte] = bytes[0:8].to_array()
  let mut dropped_name_section = false
  for section in sections {
    let payload = bytes[section.payload_start:section.section_end].to_bytes()
    match section.section_id {
      2U =>
        if parse_vec_count(rewritten_import_payload) > 0U {
          append_encoded_section(out, 2U, rewritten_import_payload)
        }
      6U => {
        let rewritten_function = rewrite_global_section_payload_for_index_map_raise(
          payload, function_index_map,
        )
        let rewritten = rewrite_global_section_payload_for_keep_local_and_global_index_map_raise(
          rewritten_function, keep_local_globals, global_index_map,
        )
        if parse_vec_count(rewritten) > 0U {
          append_encoded_section(out, 6U, rewritten)
        }
      }
      7U => {
        let rewritten_function = rewrite_export_section_payload_for_dce_raise(
          payload, function_index_map,
        )
        let (rewritten, _) = rewrite_export_section_payload_for_module_index_maps_raise(
          rewritten_function, table_index_map, memory_index_map, global_index_map,
        )
        if parse_vec_count(rewritten) > 0U {
          append_encoded_section(out, 7U, rewritten)
        }
      }
      8U =>
        append_encoded_section(
          out,
          8U,
          rewrite_start_section_payload_for_dce_raise(
            payload, function_index_map,
          ),
        )
      9U => {
        let rewritten_function = rewrite_element_section_payload_for_index_map_raise(
          payload, function_index_map,
        )
        let (rewritten, _, _) = rewrite_element_section_payload_for_table_index_map_raise(
          rewritten_function, table_index_map, global_index_map,
        )
        if parse_vec_count(rewritten) > 0U {
          append_encoded_section(out, 9U, rewritten)
        }
      }
      10U => {
        let rewritten_function = rewrite_code_section_payload_for_dce_raise(
          payload, keep_local_functions, function_index_map,
        )
        let rewritten = rewrite_code_section_payload_for_module_index_map_raise(
          rewritten_function, table_index_map, memory_index_map, global_index_map,
          element_index_map, data_index_map,
        )
        if parse_vec_count(rewritten) > 0U {
          append_encoded_section(out, 10U, rewritten)
        }
      }
      11U => {
        let (rewritten, _, _) = rewrite_data_section_payload_for_memory_global_index_map_raise(
          payload, memory_index_map, global_index_map,
        )
        if parse_vec_count(rewritten) > 0U {
          append_encoded_section(out, 11U, rewritten)
        }
      }
      0U =>
        match section.custom_name {
          Some(name) =>
            if name == "name" && removed_function_import_count > 0U {
              dropped_name_section = true
            } else {
              out.append(
                bytes[section.section_start:section.section_end].to_array(),
              )
            }
          None =>
            out.append(
              bytes[section.section_start:section.section_end].to_array(),
            )
        }
      _ =>
        out.append(bytes[section.section_start:section.section_end].to_array())
    }
  }
  {
    bytes: Bytes::from_array(out[:]),
    removed_import_count: removed_by_rewrite,
    removed_function_import_count,
    removed_table_import_count,
    removed_memory_import_count,
    removed_global_import_count,
    dropped_name_section,
  }
}

///|
fn decode_const_expr_i32_const_nonnegative_offset_raise(
  expr_bytes : Bytes,
) -> UInt? raise WiteError {
  let spans = parse_instruction_spans_raise(expr_bytes)
  if spans.length() != 2 {
    return None
  }
  if spans[1].opcode != 0x0bU {
    return None
  }
  decode_i32_const_nonnegative_from_span(expr_bytes, spans[0])
}

///|
fn collect_static_table_function_map_from_element_section_raise(
  payload : Bytes,
  target_table_index : UInt,
) -> Map[UInt, UInt]? raise WiteError {
  let parser = Cursor::new(payload)
  let segment_count = parser.read_u32_leb128()
  let table_map : Map[UInt, UInt] = {}
  for _ in 0U..<segment_count {
    let flags = parser.read_u32_leb128()
    let (table_index, offset_expr, function_count) = match flags {
      0U => {
        let offset_expr = read_const_expr_bytes_raise(parser, payload)
        let function_count = parser.read_u32_leb128()
        (0U, offset_expr, function_count)
      }
      2U => {
        let table_index = parser.read_u32_leb128()
        let offset_expr = read_const_expr_bytes_raise(parser, payload)
        if parser.read_byte().to_uint() != 0U {
          return None
        }
        let function_count = parser.read_u32_leb128()
        (table_index, offset_expr, function_count)
      }
      _ => return None
    }
    let offset = match
      decode_const_expr_i32_const_nonnegative_offset_raise(offset_expr) {
      Some(v) => v
      None => return None
    }
    for i in 0U..<function_count {
      let function_index = parser.read_u32_leb128()
      if table_index == target_table_index {
        let slot = offset + i
        if slot < offset {
          return None
        }
        match table_map.get(slot) {
          Some(prev) => if prev != function_index { return None }
          None => table_map.set(slot, function_index)
        }
      }
    }
  }
  Some(table_map)
}

///|
fn has_disallowed_table_ops_in_instruction_raise(
  instr_bytes : Bytes,
  spans : Array[InstrSpan],
) -> Bool raise WiteError {
  for span in spans {
    match span.opcode {
      0x25U | 0x26U => return true
      0xfcU => {
        if span.end_ <= span.start + 1 {
          raise WiteError::InvalidFormat("invalid 0xfc immediate in directize")
        }
        let imm = instr_bytes[span.start + 1:span.end_].to_bytes()
        let parser = Cursor::new(imm)
        let subopcode = parser.read_u32_leb128()
        if subopcode >= 12U && subopcode <= 17U {
          return true
        }
      }
      _ => ()
    }
  }
  false
}

///|
fn rewrite_instruction_call_indirect_to_direct_raise(
  instr_bytes : Bytes,
  spans : Array[InstrSpan],
  table_map : Map[UInt, UInt],
  function_type_by_index : Array[UInt],
) -> (Bytes, UInt) raise WiteError {
  let out : Array[Byte] = []
  let mut rewritten_call_count = 0U
  let mut i = 0
  while i < spans.length() {
    if i + 1 < spans.length() &&
      spans[i].opcode == 0x41U &&
      spans[i + 1].opcode == 0x11U {
      match decode_i32_const_nonnegative_from_span(instr_bytes, spans[i]) {
        Some(slot) =>
          if spans[i + 1].end_ > spans[i + 1].start + 1 {
            let imm = instr_bytes[spans[i + 1].start + 1:spans[i + 1].end_].to_bytes()
            match decode_call_indirect_immediate(imm) {
              Some((type_index, table_index)) =>
                if table_index == 0U {
                  match table_map.get(slot) {
                    Some(target) => {
                      let target_pos = UInt::reinterpret_as_int(target)
                      if target_pos >= 0 &&
                        target_pos < function_type_by_index.length() &&
                        function_type_by_index[target_pos] == type_index {
                        out.push(0x10U.to_byte())
                        out.append(encode_u32_leb128(target)[:])
                        rewritten_call_count += 1U
                        i += 2
                        continue
                      }
                    }
                    None => ()
                  }
                }
              None =>
                raise WiteError::InvalidFormat(
                  "failed to decode call_indirect immediate in directize",
                )
            }
          }
        None => ()
      }
    }
    out.append(instr_bytes[spans[i].start:spans[i].end_].to_array())
    i += 1
  }
  (Bytes::from_array(out[:]), rewritten_call_count)
}

///|
fn rewrite_code_section_payload_for_directize_raise(
  payload : Bytes,
  table_map : Map[UInt, UInt],
  function_type_by_index : Array[UInt],
) -> (Bytes, UInt) raise WiteError {
  let bodies = parse_code_bodies(payload)
  let rewritten_bodies : Array[Bytes] = []
  let mut rewritten_call_count = 0U
  for body in bodies {
    let prefix_end = parse_local_decl_prefix_end(body)
    let instr_bytes = body[prefix_end:body.length()].to_bytes()
    let spans = parse_instruction_spans_raise(instr_bytes)
    let (rewritten_instr, rewritten_count) = rewrite_instruction_call_indirect_to_direct_raise(
      instr_bytes, spans, table_map, function_type_by_index,
    )
    rewritten_call_count += rewritten_count
    if rewritten_count > 0U {
      let rewritten_body : Array[Byte] = body[0:prefix_end].to_array()
      rewritten_body.append(rewritten_instr[:].to_array())
      rewritten_bodies.push(Bytes::from_array(rewritten_body[:]))
    } else {
      rewritten_bodies.push(body)
    }
  }
  (
    encode_code_section_payload_from_bodies(rewritten_bodies),
    rewritten_call_count,
  )
}

///|
priv struct DirectizeApplyResult {
  bytes : Bytes
  rewritten_call_count : UInt
}

///|
priv struct SimplifyGlobalsApplyResult {
  bytes : Bytes
  rewritten_global_get_count : UInt
}

///|
priv struct ReorderGlobalsApplyResult {
  bytes : Bytes
  reordered_local_count : UInt
}

///|
priv struct MemoryPackingApplyResult {
  bytes : Bytes
  reordered_local_count : UInt
}

///|
fn apply_directize_raise(bytes : Bytes) -> DirectizeApplyResult raise WiteError {
  let sections = parse_core_sections_raise(bytes)
  let mut import_payload : Bytes? = None
  let mut function_payload : Bytes? = None
  let mut table_payload : Bytes? = None
  let mut element_payload : Bytes? = None
  let mut export_payload : Bytes? = None
  let mut code_payload : Bytes? = None
  let mut imported_table_count = 0U
  for section in sections {
    let payload = bytes[section.payload_start:section.section_end].to_bytes()
    match section.section_id {
      2U => {
        import_payload = Some(payload)
        let entries = parse_import_section_entries_raise(payload)
        for entry in entries {
          if entry.kind == 1U {
            imported_table_count += 1U
          }
        }
      }
      3U => function_payload = Some(payload)
      4U => table_payload = Some(payload)
      7U => export_payload = Some(payload)
      9U => element_payload = Some(payload)
      10U => code_payload = Some(payload)
      _ => ()
    }
  }
  if imported_table_count > 0U {
    return { bytes, rewritten_call_count: 0U }
  }
  let local_table_count = match table_payload {
    Some(payload) =>
      parse_table_section_entries_raise(payload).length().reinterpret_as_uint()
    None => 0U
  }
  if local_table_count != 1U {
    return { bytes, rewritten_call_count: 0U }
  }
  let exported_table_indices = match export_payload {
    Some(payload) => parse_export_table_indices(payload)
    None => []
  }
  if exported_table_indices.length() > 0 {
    return { bytes, rewritten_call_count: 0U }
  }
  let element_payload = match element_payload {
    Some(v) => v
    None => return { bytes, rewritten_call_count: 0U }
  }
  let table_map = match
    collect_static_table_function_map_from_element_section_raise(
      element_payload, 0U,
    ) {
    Some(v) => v
    None => return { bytes, rewritten_call_count: 0U }
  }
  let mut has_table_entry = false
  table_map.each((_, _value) => has_table_entry = true)
  if not(has_table_entry) {
    return { bytes, rewritten_call_count: 0U }
  }
  let function_payload = match function_payload {
    Some(v) => v
    None => return { bytes, rewritten_call_count: 0U }
  }
  let code_payload = match code_payload {
    Some(v) => v
    None => return { bytes, rewritten_call_count: 0U }
  }
  let code_bodies = parse_code_bodies(code_payload)
  for body in code_bodies {
    let prefix_end = parse_local_decl_prefix_end(body)
    let instr_bytes = body[prefix_end:body.length()].to_bytes()
    let spans = parse_instruction_spans_raise(instr_bytes)
    if has_disallowed_table_ops_in_instruction_raise(instr_bytes, spans) {
      return { bytes, rewritten_call_count: 0U }
    }
  }
  let imported_function_type_indices = match import_payload {
    Some(payload) => parse_import_function_type_indices(payload)
    None => []
  }
  let local_function_type_indices = parse_function_type_indices(
    function_payload,
  )
  if local_function_type_indices.length() != code_bodies.length() {
    raise WiteError::InvalidFormat(
      "function/code section count mismatch for directize: function=" +
      local_function_type_indices.length().to_string() +
      " code=" +
      code_bodies.length().to_string(),
    )
  }
  let function_type_by_index = imported_function_type_indices.copy()
  function_type_by_index.append(local_function_type_indices[:])
  let (rewritten_code_payload, rewritten_call_count) = rewrite_code_section_payload_for_directize_raise(
    code_payload, table_map, function_type_by_index,
  )
  if rewritten_call_count == 0U {
    return { bytes, rewritten_call_count }
  }
  let out : Array[Byte] = bytes[0:8].to_array()
  for section in sections {
    if section.section_id == 10U {
      append_encoded_section(out, 10U, rewritten_code_payload)
    } else {
      out.append(bytes[section.section_start:section.section_end].to_array())
    }
  }
  { bytes: Bytes::from_array(out[:]), rewritten_call_count }
}

///|
fn collect_global_usage_counts_from_code_section_raise(
  payload : Bytes,
  counts : Array[UInt],
) -> Unit raise WiteError {
  let bodies = parse_code_bodies(payload)
  for body in bodies {
    let prefix_end = parse_local_decl_prefix_end(body)
    let instr_bytes = body[prefix_end:body.length()].to_bytes()
    let spans = parse_instruction_spans_raise(instr_bytes)
    for span in spans {
      if span.opcode == 0x23U || span.opcode == 0x24U {
        match decode_span_u32_immediate(instr_bytes, span) {
          Some(index) => increment_index_count_in_array(counts, index)
          None =>
            raise WiteError::InvalidFormat(
              "failed to decode global index immediate in reorder-globals",
            )
        }
      }
    }
  }
}

///|
fn rewrite_instruction_global_get_to_i32_const_raise(
  instr_bytes : Bytes,
  spans : Array[InstrSpan],
  global_i32_const_map : Map[UInt, UInt],
) -> (Bytes, UInt) raise WiteError {
  let out : Array[Byte] = []
  let mut rewritten_global_get_count = 0U
  for span in spans {
    if span.opcode == 0x23U {
      match decode_span_u32_immediate(instr_bytes, span) {
        Some(index) =>
          match global_i32_const_map.get(index) {
            Some(value) => {
              let replacement : Array[Byte] = [0x41U.to_byte()]
              replacement.append(encode_nonnegative_i32_leb128(value)[:])
              if replacement.length() <= span.end_ - span.start {
                out.append(replacement[:])
                rewritten_global_get_count += 1U
                continue
              }
            }
            None => ()
          }
        None =>
          raise WiteError::InvalidFormat(
            "failed to decode global.get immediate in simplify-globals",
          )
      }
    }
    out.append(instr_bytes[span.start:span.end_].to_array())
  }
  (Bytes::from_array(out[:]), rewritten_global_get_count)
}

///|
fn rewrite_code_section_payload_for_simplify_globals_raise(
  payload : Bytes,
  global_i32_const_map : Map[UInt, UInt],
) -> (Bytes, UInt) raise WiteError {
  let bodies = parse_code_bodies(payload)
  let rewritten_bodies : Array[Bytes] = []
  let mut rewritten_global_get_count = 0U
  for body in bodies {
    let prefix_end = parse_local_decl_prefix_end(body)
    let instr_bytes = body[prefix_end:body.length()].to_bytes()
    let spans = parse_instruction_spans_raise(instr_bytes)
    let (rewritten_instr, rewritten_count) = rewrite_instruction_global_get_to_i32_const_raise(
      instr_bytes, spans, global_i32_const_map,
    )
    rewritten_global_get_count += rewritten_count
    if rewritten_count > 0U {
      let rewritten_body : Array[Byte] = body[0:prefix_end].to_array()
      rewritten_body.append(rewritten_instr[:].to_array())
      rewritten_bodies.push(Bytes::from_array(rewritten_body[:]))
    } else {
      rewritten_bodies.push(body)
    }
  }
  (
    encode_code_section_payload_from_bodies(rewritten_bodies),
    rewritten_global_get_count,
  )
}

///|
fn apply_simplify_globals_raise(
  bytes : Bytes,
) -> SimplifyGlobalsApplyResult raise WiteError {
  let sections = parse_core_sections_raise(bytes)
  let mut import_payload : Bytes? = None
  let mut global_payload : Bytes? = None
  let mut code_payload : Bytes? = None
  for section in sections {
    let payload = bytes[section.payload_start:section.section_end].to_bytes()
    match section.section_id {
      2U => import_payload = Some(payload)
      6U => global_payload = Some(payload)
      10U => code_payload = Some(payload)
      _ => ()
    }
  }
  let global_payload = match global_payload {
    Some(v) => v
    None => return { bytes, rewritten_global_get_count: 0U }
  }
  let code_payload = match code_payload {
    Some(v) => v
    None => return { bytes, rewritten_global_get_count: 0U }
  }
  let import_entries = match import_payload {
    Some(payload) => parse_import_section_entries_raise(payload)
    None => []
  }
  let imported_global_count = count_import_kinds(import_entries).global_count
  let local_global_entries = parse_global_section_entries_with_refs_raise(
    global_payload,
  )
  if local_global_entries.length() == 0 {
    return { bytes, rewritten_global_get_count: 0U }
  }
  let global_i32_const_map : Map[UInt, UInt] = {}
  let mut candidate_count = 0U
  for i in 0..<local_global_entries.length() {
    let entry = local_global_entries[i]
    if entry.val_type.length() == 1 &&
      entry.val_type[0].to_uint() == 0x7fU &&
      entry.mutability.to_uint() == 0U {
      match
        decode_const_expr_i32_const_nonnegative_offset_raise(entry.init_expr) {
        Some(value) => {
          global_i32_const_map.set(
            imported_global_count + i.reinterpret_as_uint(),
            value,
          )
          candidate_count += 1U
        }
        None => ()
      }
    }
  }
  if candidate_count == 0U {
    return { bytes, rewritten_global_get_count: 0U }
  }
  let (rewritten_code_payload, rewritten_global_get_count) = rewrite_code_section_payload_for_simplify_globals_raise(
    code_payload, global_i32_const_map,
  )
  if rewritten_global_get_count == 0U {
    return { bytes, rewritten_global_get_count: 0U }
  }
  let out : Array[Byte] = bytes[0:8].to_array()
  for section in sections {
    if section.section_id == 10U {
      append_encoded_section(out, 10U, rewritten_code_payload)
    } else {
      out.append(bytes[section.section_start:section.section_end].to_array())
    }
  }
  { bytes: Bytes::from_array(out[:]), rewritten_global_get_count }
}

///|
fn apply_simplify_globals(bytes : Bytes) -> SimplifyGlobalsApplyResult {
  let result = try? apply_simplify_globals_raise(bytes)
  match result {
    Ok(v) => v
    Err(_) => { bytes, rewritten_global_get_count: 0U }
  }
}

///|
fn apply_reorder_globals_raise(
  bytes : Bytes,
) -> ReorderGlobalsApplyResult raise WiteError {
  let sections = parse_core_sections_raise(bytes)
  let mut import_payload : Bytes? = None
  let mut table_payload : Bytes? = None
  let mut memory_payload : Bytes? = None
  let mut global_payload : Bytes? = None
  let mut export_payload : Bytes? = None
  let mut element_payload : Bytes? = None
  let mut code_payload : Bytes? = None
  let mut data_payload : Bytes? = None
  for section in sections {
    let payload = bytes[section.payload_start:section.section_end].to_bytes()
    match section.section_id {
      2U => import_payload = Some(payload)
      4U => table_payload = Some(payload)
      5U => memory_payload = Some(payload)
      6U => global_payload = Some(payload)
      7U => export_payload = Some(payload)
      9U => element_payload = Some(payload)
      10U => code_payload = Some(payload)
      11U => data_payload = Some(payload)
      _ => ()
    }
  }
  let global_payload = match global_payload {
    Some(v) => v
    None => return { bytes, reordered_local_count: 0U }
  }
  let import_entries = match import_payload {
    Some(payload) => parse_import_section_entries_raise(payload)
    None => []
  }
  let import_counts = count_import_kinds(import_entries)
  let imported_table_count = import_counts.table_count
  let imported_memory_count = import_counts.memory_count
  let imported_global_count = import_counts.global_count
  let local_global_entries = parse_global_section_entries_with_refs_raise(
    global_payload,
  )
  if local_global_entries.length() <= 1 {
    return { bytes, reordered_local_count: 0U }
  }
  // Avoid creating potentially invalid forward references across local globals.
  for entry in local_global_entries {
    for dep in entry.init_global_refs {
      if dep >= imported_global_count {
        return { bytes, reordered_local_count: 0U }
      }
    }
  }
  let local_global_count = local_global_entries.length().reinterpret_as_uint()
  let total_global_count = imported_global_count + local_global_count
  let usage_counts : Array[UInt] = []
  for _ in 0U..<total_global_count {
    usage_counts.push(0U)
  }
  match code_payload {
    Some(payload) =>
      collect_global_usage_counts_from_code_section_raise(payload, usage_counts)
    None => ()
  }
  match export_payload {
    Some(payload) =>
      for index in parse_export_global_indices(payload) {
        increment_index_count_in_array(usage_counts, index)
      }
    None => ()
  }
  match element_payload {
    Some(payload) =>
      for
        index in collect_used_global_indices_from_element_section_raise(payload) {
        increment_index_count_in_array(usage_counts, index)
      }
    None => ()
  }
  match data_payload {
    Some(payload) => {
      let (_, global_indices) = collect_used_memory_and_global_indices_from_data_section_raise(
        payload,
      )
      for index in global_indices {
        increment_index_count_in_array(usage_counts, index)
      }
    }
    None => ()
  }
  for entry in local_global_entries {
    for dep in entry.init_global_refs {
      increment_index_count_in_array(usage_counts, dep)
    }
  }
  let local_order : Array[UInt] = []
  for i in 0..<local_global_entries.length() {
    local_order.push(i.reinterpret_as_uint())
  }
  local_order.sort_by((a, b) => {
    let a_count = index_count_in_array(usage_counts, imported_global_count + a)
    let b_count = index_count_in_array(usage_counts, imported_global_count + b)
    if a_count > b_count {
      -1
    } else if a_count < b_count {
      1
    } else if a < b {
      -1
    } else if a > b {
      1
    } else {
      0
    }
  })
  let reordered_local_count = count_reordered_local_indices(local_order)
  if reordered_local_count == 0U {
    return { bytes, reordered_local_count: 0U }
  }
  let global_index_map : Map[UInt, UInt] = {}
  for i in 0U..<imported_global_count {
    global_index_map.set(i, i)
  }
  for new_local_pos in 0..<local_order.length() {
    let old_local_pos = local_order[new_local_pos]
    global_index_map.set(
      imported_global_count + old_local_pos,
      imported_global_count + new_local_pos.reinterpret_as_uint(),
    )
  }
  let local_table_count = match table_payload {
    Some(payload) =>
      parse_table_section_entries_raise(payload).length().reinterpret_as_uint()
    None => 0U
  }
  let local_memory_count = match memory_payload {
    Some(payload) =>
      parse_memory_section_entries_raise(payload).length().reinterpret_as_uint()
    None => 0U
  }
  let table_index_map = make_identity_index_map(
    imported_table_count + local_table_count,
  )
  let memory_index_map = make_identity_index_map(
    imported_memory_count + local_memory_count,
  )
  let element_index_map = match element_payload {
    Some(payload) => make_identity_index_map(parse_vec_count(payload))
    None => make_identity_index_map(0U)
  }
  let data_index_map = match data_payload {
    Some(payload) => make_identity_index_map(parse_vec_count(payload))
    None => make_identity_index_map(0U)
  }
  let out : Array[Byte] = bytes[0:8].to_array()
  for section in sections {
    let payload = bytes[section.payload_start:section.section_end].to_bytes()
    match section.section_id {
      6U => {
        let rewritten = rewrite_global_section_payload_for_local_order_and_global_index_map_raise(
          payload, local_order, global_index_map,
        )
        if parse_vec_count(rewritten) > 0U {
          append_encoded_section(out, 6U, rewritten)
        }
      }
      7U => {
        let (rewritten, _) = rewrite_export_section_payload_for_module_index_maps_raise(
          payload, table_index_map, memory_index_map, global_index_map,
        )
        if parse_vec_count(rewritten) > 0U {
          append_encoded_section(out, 7U, rewritten)
        }
      }
      9U => {
        let (rewritten, _, _) = rewrite_element_section_payload_for_table_index_map_raise(
          payload, table_index_map, global_index_map,
        )
        if parse_vec_count(rewritten) > 0U {
          append_encoded_section(out, 9U, rewritten)
        }
      }
      10U =>
        append_encoded_section(
          out,
          10U,
          rewrite_code_section_payload_for_module_index_map_raise(
            payload, table_index_map, memory_index_map, global_index_map, element_index_map,
            data_index_map,
          ),
        )
      11U => {
        let (rewritten, _, _) = rewrite_data_section_payload_for_memory_global_index_map_raise(
          payload, memory_index_map, global_index_map,
        )
        if parse_vec_count(rewritten) > 0U {
          append_encoded_section(out, 11U, rewritten)
        }
      }
      _ =>
        out.append(bytes[section.section_start:section.section_end].to_array())
    }
  }
  { bytes: Bytes::from_array(out[:]), reordered_local_count }
}

///|
fn apply_reorder_globals(bytes : Bytes) -> ReorderGlobalsApplyResult {
  let result = try? apply_reorder_globals_raise(bytes)
  match result {
    Ok(v) => v
    Err(_) => { bytes, reordered_local_count: 0U }
  }
}

///|
fn is_memory_index_marked_used(used_flags : Array[Bool], index : UInt) -> Bool {
  let pos = UInt::reinterpret_as_int(index)
  pos >= 0 && pos < used_flags.length() && used_flags[pos]
}

///|
fn apply_memory_packing_raise(
  bytes : Bytes,
) -> MemoryPackingApplyResult raise WiteError {
  let sections = parse_core_sections_raise(bytes)
  let mut import_payload : Bytes? = None
  let mut table_payload : Bytes? = None
  let mut memory_payload : Bytes? = None
  let mut global_payload : Bytes? = None
  let mut export_payload : Bytes? = None
  let mut code_payload : Bytes? = None
  let mut data_payload : Bytes? = None
  for section in sections {
    let payload = bytes[section.payload_start:section.section_end].to_bytes()
    match section.section_id {
      2U => import_payload = Some(payload)
      4U => table_payload = Some(payload)
      5U => memory_payload = Some(payload)
      6U => global_payload = Some(payload)
      7U => export_payload = Some(payload)
      10U => code_payload = Some(payload)
      11U => data_payload = Some(payload)
      _ => ()
    }
  }
  let memory_payload = match memory_payload {
    Some(v) => v
    None => return { bytes, reordered_local_count: 0U }
  }
  let import_entries = match import_payload {
    Some(payload) => parse_import_section_entries_raise(payload)
    None => []
  }
  let import_counts = count_import_kinds(import_entries)
  let imported_table_count = import_counts.table_count
  let imported_memory_count = import_counts.memory_count
  let imported_global_count = import_counts.global_count
  let local_memory_entries = parse_memory_section_entries_raise(memory_payload)
  if local_memory_entries.length() <= 1 {
    return { bytes, reordered_local_count: 0U }
  }
  let used_memory_indices : Array[UInt] = []
  match export_payload {
    Some(payload) =>
      for index in parse_export_memory_indices(payload) {
        push_unique_u32(used_memory_indices, index)
      }
    None => ()
  }
  match code_payload {
    Some(payload) =>
      match collect_used_memory_indices_from_code_section(payload) {
        Some(indices) =>
          for index in indices {
            push_unique_u32(used_memory_indices, index)
          }
        None => return { bytes, reordered_local_count: 0U }
      }
    None => ()
  }
  match data_payload {
    Some(payload) => {
      let (memory_indices, _) = collect_used_memory_and_global_indices_from_data_section_raise(
        payload,
      )
      for index in memory_indices {
        push_unique_u32(used_memory_indices, index)
      }
    }
    None => ()
  }
  let total_memory_count = imported_memory_count +
    local_memory_entries.length().reinterpret_as_uint()
  let used_flags : Array[Bool] = []
  for _ in 0U..<total_memory_count {
    used_flags.push(false)
  }
  for index in used_memory_indices {
    let pos = UInt::reinterpret_as_int(index)
    if pos >= 0 && pos < used_flags.length() {
      used_flags[pos] = true
    }
  }
  let local_order : Array[UInt] = []
  let sortable_local_indices : Array[UInt] = []
  let fixed_local_pos = if imported_memory_count == 0U { 0 } else { -1 }
  for i in 0..<local_memory_entries.length() {
    if i == fixed_local_pos {
      local_order.push(i.reinterpret_as_uint())
    } else {
      sortable_local_indices.push(i.reinterpret_as_uint())
    }
  }
  sortable_local_indices.sort_by((a, b) => {
    let a_used = is_memory_index_marked_used(
      used_flags,
      imported_memory_count + a,
    )
    let b_used = is_memory_index_marked_used(
      used_flags,
      imported_memory_count + b,
    )
    if a_used && not(b_used) {
      -1
    } else if not(a_used) && b_used {
      1
    } else if a < b {
      -1
    } else if a > b {
      1
    } else {
      0
    }
  })
  local_order.append(sortable_local_indices[:])
  let reordered_local_count = count_reordered_local_indices(local_order)
  if reordered_local_count == 0U {
    return { bytes, reordered_local_count: 0U }
  }
  let memory_index_map : Map[UInt, UInt] = {}
  for i in 0U..<imported_memory_count {
    memory_index_map.set(i, i)
  }
  for new_local_pos in 0..<local_order.length() {
    let old_local_pos = local_order[new_local_pos]
    memory_index_map.set(
      imported_memory_count + old_local_pos,
      imported_memory_count + new_local_pos.reinterpret_as_uint(),
    )
  }
  if remap_memory_index_raise(0U, memory_index_map) != 0U {
    return { bytes, reordered_local_count: 0U }
  }
  let local_table_count = match table_payload {
    Some(payload) =>
      parse_table_section_entries_raise(payload).length().reinterpret_as_uint()
    None => 0U
  }
  let local_global_count = match global_payload {
    Some(payload) =>
      parse_global_section_entries_with_refs_raise(payload)
      .length()
      .reinterpret_as_uint()
    None => 0U
  }
  let table_index_map = make_identity_index_map(
    imported_table_count + local_table_count,
  )
  let global_index_map = make_identity_index_map(
    imported_global_count + local_global_count,
  )
  let element_index_map = make_identity_index_map(0U)
  let data_index_map = match data_payload {
    Some(payload) => make_identity_index_map(parse_vec_count(payload))
    None => make_identity_index_map(0U)
  }
  let out : Array[Byte] = bytes[0:8].to_array()
  for section in sections {
    let payload = bytes[section.payload_start:section.section_end].to_bytes()
    match section.section_id {
      5U => {
        let rewritten = rewrite_memory_section_payload_for_local_order_raise(
          payload, local_order,
        )
        if parse_vec_count(rewritten) > 0U {
          append_encoded_section(out, 5U, rewritten)
        }
      }
      7U => {
        let (rewritten, _) = rewrite_export_section_payload_for_module_index_maps_raise(
          payload, table_index_map, memory_index_map, global_index_map,
        )
        if parse_vec_count(rewritten) > 0U {
          append_encoded_section(out, 7U, rewritten)
        }
      }
      10U =>
        append_encoded_section(
          out,
          10U,
          rewrite_code_section_payload_for_module_index_map_raise(
            payload, table_index_map, memory_index_map, global_index_map, element_index_map,
            data_index_map,
          ),
        )
      11U => {
        let (rewritten, _, _) = rewrite_data_section_payload_for_memory_global_index_map_raise(
          payload, memory_index_map, global_index_map,
        )
        if parse_vec_count(rewritten) > 0U {
          append_encoded_section(out, 11U, rewritten)
        }
      }
      _ =>
        out.append(bytes[section.section_start:section.section_end].to_array())
    }
  }
  { bytes: Bytes::from_array(out[:]), reordered_local_count }
}

///|
fn apply_memory_packing(bytes : Bytes) -> MemoryPackingApplyResult {
  let result = try? apply_memory_packing_raise(bytes)
  match result {
    Ok(v) => v
    Err(_) => { bytes, reordered_local_count: 0U }
  }
}

///|
fn is_dwarf_custom_section_name(name : String) -> Bool {
  name.has_prefix(".debug_") || name.has_prefix("reloc..debug_")
}

///|
fn is_debug_custom_section_name(name : String) -> Bool {
  name == "sourceMappingURL" ||
  name == "external_debug_info" ||
  is_dwarf_custom_section_name(name)
}

///|
fn keep_custom_section(section : RawSection, config : OptimizeConfig) -> Bool {
  if section.section_id != 0U {
    return true
  }
  let name = match section.custom_name {
    Some(v) => v
    None => ""
  }
  if config.keep_custom_sections.contains(name) {
    return true
  }
  if config.strip_all_custom {
    return false
  }
  if config.strip_name_section && name == "name" {
    return false
  }
  if config.strip_producers_section && name == "producers" {
    return false
  }
  if config.strip_target_features_section && name == "target_features" {
    return false
  }
  if config.strip_dwarf_sections && is_dwarf_custom_section_name(name) {
    return false
  }
  if config.strip_debug_sections && is_debug_custom_section_name(name) {
    return false
  }
  true
}

///|
fn should_optimize_code_section(config : OptimizeConfig) -> Bool {
  config.enable_peephole ||
  config.enable_vacuum ||
  config.enable_merge_blocks ||
  config.enable_remove_unused_brs
}

///|
fn should_remove_unused_types(config : OptimizeConfig) -> Bool {
  config.enable_dce ||
  config.enable_dfe ||
  config.enable_merge_similar_functions ||
  config.enable_remove_unused_module_elements
}

///|
fn should_refine_types(config : OptimizeConfig) -> Bool {
  config.enable_dce ||
  config.enable_dfe ||
  config.enable_merge_similar_functions ||
  config.enable_remove_unused_module_elements
}

///|
fn should_signature_prune(config : OptimizeConfig) -> Bool {
  config.enable_dce ||
  config.enable_dfe ||
  config.enable_merge_similar_functions
}

///|
fn should_duplicate_import_eliminate(config : OptimizeConfig) -> Bool {
  config.enable_dce ||
  config.enable_dfe ||
  config.enable_merge_similar_functions ||
  config.enable_remove_unused_module_elements
}

///|
fn should_simplify_globals(config : OptimizeConfig) -> Bool {
  should_optimize_code_section(config) ||
  config.enable_dce ||
  config.enable_remove_unused_module_elements
}

///|
fn should_reorder_globals(config : OptimizeConfig) -> Bool {
  config.enable_dce || config.enable_remove_unused_module_elements
}

///|
fn should_memory_pack(config : OptimizeConfig) -> Bool {
  config.enable_dce || config.enable_remove_unused_module_elements
}

///|
fn custom_strip_pass_requested(config : OptimizeConfig) -> Bool {
  config.strip_all_custom ||
  config.strip_name_section ||
  config.strip_producers_section ||
  config.strip_target_features_section ||
  config.strip_dwarf_sections ||
  config.strip_debug_sections
}

///|
fn any_optimization_pass_requested(config : OptimizeConfig) -> Bool {
  custom_strip_pass_requested(config) ||
  should_optimize_code_section(config) ||
  config.enable_dce ||
  config.enable_dfe ||
  config.enable_merge_similar_functions ||
  config.enable_remove_unused_module_elements ||
  should_refine_types(config) ||
  should_signature_prune(config) ||
  should_remove_unused_types(config)
}

///|
fn push_reason(reasons : Array[String], reason : String) -> Unit {
  if not(reasons.contains(reason)) {
    reasons.push(reason)
  }
}

///|
fn collect_optimize_no_change_reasons(
  before : Bytes,
  after : Bytes,
  config : OptimizeConfig,
) -> Array[String] {
  let reasons : Array[String] = []
  if before.length() != after.length() {
    return reasons
  }
  if not(bytes_equal(before, after)) {
    reasons.push("size-neutral rewrite only (bytes changed but size unchanged)")
    return reasons
  }
  if not(any_optimization_pass_requested(config)) {
    reasons.push("no optimization pass is enabled in config")
    return reasons
  }
  let sections_result = try? parse_core_sections_raise(before)
  match sections_result {
    Ok(sections) => {
      if custom_strip_pass_requested(config) {
        let mut has_custom_section = false
        let mut has_removable_custom_section = false
        for section in sections {
          if section.section_id == 0U {
            has_custom_section = true
            if not(keep_custom_section(section, config)) {
              has_removable_custom_section = true
            }
          }
        }
        if not(has_custom_section) {
          push_reason(reasons, "no custom section exists for strip passes")
        } else if not(has_removable_custom_section) {
          push_reason(
            reasons, "configured custom-section strip targets were not present",
          )
        }
      }
      if should_optimize_code_section(config) {
        if not(sections.any(s => s.section_id == 10U)) {
          push_reason(reasons, "no code section exists for code-level passes")
        } else {
          push_reason(
            reasons, "code-level passes found no reducible instruction patterns",
          )
        }
      }
    }
    Err(_) =>
      push_reason(
        reasons, "unable to inspect section layout for no-change diagnostics",
      )
  }
  if config.enable_dce {
    match analyze_dce_report(before) {
      Ok(report) =>
        if report.partial {
          push_reason(reasons, "dce skipped: partial call graph")
        } else if report.removable_function_count == 0U {
          push_reason(reasons, "dce found no removable functions")
        }
      Err(_) => push_reason(reasons, "dce analysis failed")
    }
  }
  if reasons.length() == 0 {
    reasons.push("module is already optimized for active passes")
  }
  reasons
}

///|
priv struct OptimizeRoundResult {
  bytes : Bytes
  removed_sections : Array[String]
}

///|
fn optimize_for_size_round_raise(
  bytes : Bytes,
  config : OptimizeConfig,
) -> OptimizeRoundResult raise WiteError {
  let sections = parse_core_sections_raise(bytes)
  let stage1_out : Array[Byte] = bytes[0:8].to_array()
  let removed_sections : Array[String] = []
  for section in sections {
    if section.section_id == 0U && not(keep_custom_section(section, config)) {
      removed_sections.push(section_key(section, false))
    } else if section.section_id == 10U && should_optimize_code_section(config) {
      let payload = bytes[section.payload_start:section.section_end].to_bytes()
      let optimized_payload = optimize_code_section_payload(payload, config)
      append_encoded_section(stage1_out, section.section_id, optimized_payload)
    } else {
      stage1_out.append(
        bytes[section.section_start:section.section_end].to_array(),
      )
    }
  }
  let mut optimized_bytes = Bytes::from_array(stage1_out[:])
  if config.enable_peephole {
    let coalesce = apply_coalesce_locals_raise(optimized_bytes)
    optimized_bytes = coalesce.bytes
    if coalesce.removed_local_count > 0U {
      removed_sections.push(
        "coalesce-locals:removed:" + coalesce.removed_local_count.to_string(),
      )
    }
  }
  if should_duplicate_import_eliminate(config) {
    let duplicate_import_elim = apply_duplicate_import_elimination(
      optimized_bytes,
    )
    optimized_bytes = duplicate_import_elim.bytes
    if duplicate_import_elim.removed_import_count > 0U {
      removed_sections.push(
        "dup-imports:imports:" +
        duplicate_import_elim.removed_import_count.to_string() +
        " funcs:" +
        duplicate_import_elim.removed_function_import_count.to_string() +
        " tables:" +
        duplicate_import_elim.removed_table_import_count.to_string() +
        " memories:" +
        duplicate_import_elim.removed_memory_import_count.to_string() +
        " globals:" +
        duplicate_import_elim.removed_global_import_count.to_string(),
      )
    }
    if duplicate_import_elim.dropped_name_section {
      removed_sections.push("custom:name(dup-imports)")
    }
  }
  if config.enable_dce {
    let dce_cluster_before = optimized_bytes
    let dce_cluster_removed_sections : Array[String] = []
    let directize = apply_directize_raise(optimized_bytes)
    optimized_bytes = directize.bytes
    if directize.rewritten_call_count > 0U {
      dce_cluster_removed_sections.push(
        "directize:calls:" + directize.rewritten_call_count.to_string(),
      )
    }
    let cfp_const = apply_const_call_forwarding_propagation_raise(
      optimized_bytes,
    )
    optimized_bytes = cfp_const.bytes
    if cfp_const.rewritten_call_count > 0U {
      dce_cluster_removed_sections.push(
        "cfp-const:calls:" + cfp_const.rewritten_call_count.to_string(),
      )
    }
    let cfp = apply_call_forwarding_propagation_raise(optimized_bytes)
    optimized_bytes = cfp.bytes
    if cfp.rewritten_call_count > 0U {
      dce_cluster_removed_sections.push(
        "cfp:calls:" + cfp.rewritten_call_count.to_string(),
      )
    }
    let signature_refine = apply_signature_refining_raise(optimized_bytes)
    optimized_bytes = signature_refine.bytes
    if signature_refine.rewritten_call_count > 0U {
      dce_cluster_removed_sections.push(
        "signature-refine:calls:" +
        signature_refine.rewritten_call_count.to_string(),
      )
    }
    let dce = apply_dce_raise(optimized_bytes, config)
    optimized_bytes = dce.bytes
    if dce.removed_function_count > 0U {
      dce_cluster_removed_sections.push(
        "dce:functions:" +
        dce.removed_function_count.to_string() +
        " bodies:" +
        dce.removed_body_bytes.to_string(),
      )
    }
    if dce.dropped_name_section {
      dce_cluster_removed_sections.push("custom:name(dce)")
    }
    let dce_cluster_before_size = dce_cluster_before
      .length()
      .reinterpret_as_uint()
    let dce_cluster_after_size = optimized_bytes.length().reinterpret_as_uint()
    if dce_cluster_after_size > dce_cluster_before_size {
      optimized_bytes = dce_cluster_before
      removed_sections.push(
        "dce-cluster:rollback:size-regress:" +
        dce_cluster_before_size.to_string() +
        "->" +
        dce_cluster_after_size.to_string(),
      )
    } else {
      removed_sections.append(dce_cluster_removed_sections[:])
    }
  }
  if should_refine_types(config) {
    let type_refine = apply_type_refining(optimized_bytes)
    optimized_bytes = type_refine.bytes
    if type_refine.refined_type_count > 0U {
      removed_sections.push(
        "type-refine:types:" + type_refine.refined_type_count.to_string(),
      )
    }
  }
  if should_signature_prune(config) {
    let signature_prune = apply_signature_pruning(optimized_bytes)
    optimized_bytes = signature_prune.bytes
    if signature_prune.pruned_function_count > 0U {
      removed_sections.push(
        "signature-prune:functions:" +
        signature_prune.pruned_function_count.to_string() +
        " params:" +
        signature_prune.pruned_param_count.to_string(),
      )
    }
  }
  if config.enable_dfe {
    let dfe = apply_dfe_raise(optimized_bytes)
    optimized_bytes = dfe.bytes
    if dfe.removed_function_count > 0U {
      removed_sections.push(
        "dfe:functions:" +
        dfe.removed_function_count.to_string() +
        " bodies:" +
        dfe.removed_body_bytes.to_string(),
      )
    }
    if dfe.dropped_name_section {
      removed_sections.push("custom:name(dfe)")
    }
  }
  if config.enable_merge_similar_functions {
    let msf = apply_merge_similar_functions_raise(optimized_bytes)
    optimized_bytes = msf.bytes
    if msf.removed_function_count > 0U {
      removed_sections.push(
        "msf:functions:" +
        msf.removed_function_count.to_string() +
        " bodies:" +
        msf.removed_body_bytes.to_string(),
      )
    }
    if msf.dropped_name_section {
      removed_sections.push("custom:name(msf)")
    }
  }
  if config.enable_remove_unused_module_elements {
    let rume = apply_remove_unused_module_elements(optimized_bytes, config)
    optimized_bytes = rume.bytes
    if rume.removed_import_count > 0U ||
      rume.removed_table_count > 0U ||
      rume.removed_memory_count > 0U ||
      rume.removed_global_count > 0U ||
      rume.removed_element_count > 0U ||
      rume.removed_data_count > 0U ||
      rume.removed_export_count > 0U {
      removed_sections.push(
        "rume:imports:" +
        rume.removed_import_count.to_string() +
        " tables:" +
        rume.removed_table_count.to_string() +
        " memories:" +
        rume.removed_memory_count.to_string() +
        " globals:" +
        rume.removed_global_count.to_string() +
        " elements:" +
        rume.removed_element_count.to_string() +
        " data:" +
        rume.removed_data_count.to_string() +
        " exports:" +
        rume.removed_export_count.to_string(),
      )
    }
  }
  if should_simplify_globals(config) {
    let simplify_globals = apply_simplify_globals(optimized_bytes)
    optimized_bytes = simplify_globals.bytes
    if simplify_globals.rewritten_global_get_count > 0U {
      removed_sections.push(
        "simplify-globals:gets:" +
        simplify_globals.rewritten_global_get_count.to_string(),
      )
    }
  }
  if should_reorder_globals(config) {
    let reorder_globals = apply_reorder_globals(optimized_bytes)
    optimized_bytes = reorder_globals.bytes
    if reorder_globals.reordered_local_count > 0U {
      removed_sections.push(
        "reorder-globals:locals:" +
        reorder_globals.reordered_local_count.to_string(),
      )
    }
  }
  if should_memory_pack(config) {
    let memory_pack = apply_memory_packing(optimized_bytes)
    optimized_bytes = memory_pack.bytes
    if memory_pack.reordered_local_count > 0U {
      removed_sections.push(
        "memory-packing:locals:" + memory_pack.reordered_local_count.to_string(),
      )
    }
  }
  if should_remove_unused_types(config) {
    let remove_unused_types = apply_remove_unused_types(optimized_bytes)
    optimized_bytes = remove_unused_types.bytes
    if remove_unused_types.removed_type_count > 0U {
      removed_sections.push(
        "types:" + remove_unused_types.removed_type_count.to_string(),
      )
    }
  }
  if config.enable_dce {
    let inlining = apply_inlining_optimizing(optimized_bytes)
    optimized_bytes = inlining.bytes
    if inlining.inlined_call_count > 0U {
      removed_sections.push(
        "inlining:calls:" + inlining.inlined_call_count.to_string(),
      )
    }
    let dae = apply_dae_optimizing(optimized_bytes)
    optimized_bytes = dae.bytes
    if dae.removed_instr_count > 0U {
      removed_sections.push("dae:instrs:" + dae.removed_instr_count.to_string())
    }
  }
  { bytes: optimized_bytes, removed_sections }
}

