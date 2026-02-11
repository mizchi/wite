///|
fn read_import_name_bytes_raise(
  parser : Cursor,
  context : String,
) -> Bytes raise WiteError {
  let name_len_u = parser.read_u32_leb128()
  let name_len = UInt::reinterpret_as_int(name_len_u)
  if name_len < 0 {
    raise WiteError::InvalidFormat("import name length overflow in " + context)
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
fn append_import_name_key(out : Array[Byte], name : Bytes) -> Unit {
  ignore(
    out
    ..append(encode_u32_leb128(name.length().reinterpret_as_uint())[:])
    ..append(name[:].to_array()),
  )
}

///|
fn build_function_import_dedupe_key_raise(
  entry_bytes : Bytes,
  function_type_raw_by_index : Map[UInt, Bytes],
) -> Bytes raise WiteError {
  let parser = Cursor::new(entry_bytes)
  let module_name = read_import_name_bytes_raise(parser, "dup-import module")
  let field_name = read_import_name_bytes_raise(parser, "dup-import field")
  let kind = parser.read_byte().to_uint()
  if kind != 0U {
    raise WiteError::InvalidFormat(
      "non-function import entry in function dedupe key",
    )
  }
  let type_index = parser.read_u32_leb128()
  if !parser.eof() {
    raise WiteError::InvalidFormat("trailing bytes in function import entry")
  }
  let type_raw = match function_type_raw_by_index.get(type_index) {
    Some(v) => v
    None =>
      raise WiteError::InvalidFormat(
        "missing type index for function import dedupe: " +
        type_index.to_string(),
      )
  }
  let out : Array[Byte] = []
  append_import_name_key(out, module_name)
  append_import_name_key(out, field_name)
  out.push(0x00U.to_byte())
  out.append(encode_u32_leb128(type_raw.length().reinterpret_as_uint())[:])
  out.append(type_raw[:].to_array())
  Bytes::from_array(out[:])
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
  let mut type_section_payload : Bytes? = None
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
      1U => type_section_payload = Some(payload)
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
  let function_type_raw_by_index : Map[UInt, Bytes] = {}
  if type_section_payload is Some(payload) {
    let type_entries = parse_type_section_entries_with_refs_raise(
      payload, "dup-imports",
    )
    for i in 0..<type_entries.length() {
      function_type_raw_by_index.set(
        i.reinterpret_as_uint(),
        type_entries[i].raw,
      )
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
  let unique_function_import_keys : Array[Bytes] = []
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
        let entry_key = build_function_import_dedupe_key_raise(
          entry.bytes,
          function_type_raw_by_index,
        )
        let mut canonical = entry.kind_index
        let mut found = false
        for i in 0..<unique_function_import_keys.length() {
          if bytes_equal(unique_function_import_keys[i], entry_key) {
            canonical = unique_function_import_indices[i]
            found = true
            break
          }
        }
        if !found {
          unique_function_import_keys.push(entry_key)
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
        if !found {
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
        if !found {
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
        if !found {
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
    if !keep_function_imports[i_pos] {
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
    if !keep_table_imports[i_pos] {
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
    if !keep_memory_imports[i_pos] {
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
    if !keep_global_imports[i_pos] {
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
    Some(payload) => payload |> parse_vec_count |> make_identity_index_map
    None => make_identity_index_map(0U)
  }
  let data_index_map = match data_section_payload {
    Some(payload) => payload |> parse_vec_count |> make_identity_index_map
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
pub(all) struct DirectizeApplyResult {
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
pub fn apply_directize_raise(
  bytes : Bytes,
) -> DirectizeApplyResult raise WiteError {
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
  if !has_table_entry {
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
          if global_i32_const_map.get(index) is Some(value) {
            let replacement : Array[Byte] = [0x41U.to_byte()]
            replacement.append(encode_nonnegative_i32_leb128(value)[:])
            if replacement.length() <= span.end_ - span.start {
              out.append(replacement[:])
              rewritten_global_get_count += 1U
              continue
            }
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
  if code_payload is Some(payload) {
    collect_global_usage_counts_from_code_section_raise(payload, usage_counts)
  }
  if export_payload is Some(payload) {
    for index in parse_export_global_indices(payload) {
      increment_index_count_in_array(usage_counts, index)
    }
  }
  if element_payload is Some(payload) {
    for index in collect_used_global_indices_from_element_section_raise(payload) {
      increment_index_count_in_array(usage_counts, index)
    }
  }
  if data_payload is Some(payload) {
    let (_, global_indices) = collect_used_memory_and_global_indices_from_data_section_raise(
      payload,
    )
    for index in global_indices {
      increment_index_count_in_array(usage_counts, index)
    }
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
    Some(payload) => payload |> parse_vec_count |> make_identity_index_map
    None => make_identity_index_map(0U)
  }
  let data_index_map = match data_payload {
    Some(payload) => payload |> parse_vec_count |> make_identity_index_map
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
  if export_payload is Some(payload) {
    for index in parse_export_memory_indices(payload) {
      push_unique_u32(used_memory_indices, index)
    }
  }
  if code_payload is Some(payload) {
    match collect_used_memory_indices_from_code_section(payload) {
      Some(indices) =>
        for index in indices {
          push_unique_u32(used_memory_indices, index)
        }
      None => return { bytes, reordered_local_count: 0U }
    }
  }
  if data_payload is Some(payload) {
    let (memory_indices, _) = collect_used_memory_and_global_indices_from_data_section_raise(
      payload,
    )
    for index in memory_indices {
      push_unique_u32(used_memory_indices, index)
    }
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
    if a_used && !b_used {
      -1
    } else if !a_used && b_used {
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
    Some(payload) => payload |> parse_vec_count |> make_identity_index_map
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
