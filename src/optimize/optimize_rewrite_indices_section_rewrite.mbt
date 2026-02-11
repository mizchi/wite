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
    ignore(
      out
      ..append(entry.val_type[:].to_array())
      ..push(entry.mutability)
      ..append(
        rewrite_const_expr_global_indices_raise(
          entry.init_expr,
          global_index_map,
        )[:].to_array(),
      ),
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
    ignore(
      out
      ..append(entry.val_type[:].to_array())
      ..push(entry.mutability)
      ..append(
        rewrite_const_expr_global_indices_raise(
          entry.init_expr,
          global_index_map,
        )[:].to_array(),
      ),
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
    parser |> read_ref_type_bytes_raise |> ignore
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
