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

