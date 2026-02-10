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
