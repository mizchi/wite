///|
pub fn make_bool_array(length : Int, value : Bool) -> Array[Bool] {
  let out : Array[Bool] = []
  for _ in 0..<length {
    out.push(value)
  }
  out
}

///|
pub fn is_visited_function_index(visited : Array[Bool], index : UInt) -> Bool {
  let pos = UInt::reinterpret_as_int(index)
  if pos < 0 || pos >= visited.length() {
    false
  } else {
    visited[pos]
  }
}

///|
pub fn mark_visited_function_index(visited : Array[Bool], index : UInt) -> Bool {
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
        Some(index) =>
          ignore(
            out
            ..push(0x23U.to_byte())
            ..append(
              encode_u32_leb128(
                remap_global_index_raise(index, global_index_map),
              )[:],
            ),
          )
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
pub fn parse_global_section_function_refs_raise(
  payload : Bytes,
) -> Array[UInt] raise WiteError {
  let parser = Cursor::new(payload)
  let count = parser.read_u32_leb128()
  let out : Array[UInt] = []
  for _ in 0U..<count {
    parser |> read_val_type_bytes_raise |> ignore
    ignore(parser.read_byte())
    let expr = read_const_expr_bytes_raise(parser, payload)
    for index in collect_ref_func_indices_from_expr_raise(expr) {
      push_unique_u32(out, index)
    }
  }
  out
}

///|
fn map_push_unique_u32_array(
  grouped : Map[UInt, Array[UInt]],
  key : UInt,
  value : UInt,
) -> Unit {
  match grouped.get(key) {
    Some(prev) =>
      if !prev.contains(value) {
        let next = prev.copy()
        next.push(value)
        grouped.set(key, next)
      }
    None => grouped.set(key, [value])
  }
}

///|
pub fn parse_element_section_table_function_refs_raise(
  payload : Bytes,
) -> Map[UInt, Array[UInt]] raise WiteError {
  let parser = Cursor::new(payload)
  let segment_count = parser.read_u32_leb128()
  let grouped : Map[UInt, Array[UInt]] = {}
  for _ in 0U..<segment_count {
    let flags = parser.read_u32_leb128()
    match flags {
      0U => {
        let offset_expr = read_const_expr_bytes_raise(parser, payload)
        for index in collect_ref_func_indices_from_expr_raise(offset_expr) {
          map_push_unique_u32_array(grouped, 0U, index)
        }
        let func_count = parser.read_u32_leb128()
        for _ in 0U..<func_count {
          map_push_unique_u32_array(grouped, 0U, parser.read_u32_leb128())
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
        let table_index = parser.read_u32_leb128()
        let offset_expr = read_const_expr_bytes_raise(parser, payload)
        for index in collect_ref_func_indices_from_expr_raise(offset_expr) {
          map_push_unique_u32_array(grouped, table_index, index)
        }
        ignore(parser.read_byte())
        let func_count = parser.read_u32_leb128()
        for _ in 0U..<func_count {
          map_push_unique_u32_array(
            grouped,
            table_index,
            parser.read_u32_leb128(),
          )
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
        for index in collect_ref_func_indices_from_expr_raise(offset_expr) {
          map_push_unique_u32_array(grouped, 0U, index)
        }
        let expr_count = parser.read_u32_leb128()
        for _ in 0U..<expr_count {
          let expr = read_const_expr_bytes_raise(parser, payload)
          for index in collect_ref_func_indices_from_expr_raise(expr) {
            map_push_unique_u32_array(grouped, 0U, index)
          }
        }
      }
      5U => {
        parser |> read_ref_type_bytes_raise |> ignore
        let expr_count = parser.read_u32_leb128()
        for _ in 0U..<expr_count {
          ignore(read_const_expr_bytes_raise(parser, payload))
        }
      }
      6U => {
        let table_index = parser.read_u32_leb128()
        let offset_expr = read_const_expr_bytes_raise(parser, payload)
        for index in collect_ref_func_indices_from_expr_raise(offset_expr) {
          map_push_unique_u32_array(grouped, table_index, index)
        }
        parser |> read_ref_type_bytes_raise |> ignore
        let expr_count = parser.read_u32_leb128()
        for _ in 0U..<expr_count {
          let expr = read_const_expr_bytes_raise(parser, payload)
          for index in collect_ref_func_indices_from_expr_raise(expr) {
            map_push_unique_u32_array(grouped, table_index, index)
          }
        }
      }
      7U => {
        parser |> read_ref_type_bytes_raise |> ignore
        let expr_count = parser.read_u32_leb128()
        for _ in 0U..<expr_count {
          ignore(read_const_expr_bytes_raise(parser, payload))
        }
      }
      _ =>
        raise WiteError::InvalidFormat(
          "unsupported element segment flags in table parser: " +
          flags.to_string(),
        )
    }
  }
  grouped
}

///|
pub fn parse_element_section_function_refs_raise(
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
        parser |> read_ref_type_bytes_raise |> ignore
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
        parser |> read_ref_type_bytes_raise |> ignore
        let expr_count = parser.read_u32_leb128()
        for _ in 0U..<expr_count {
          let expr = read_const_expr_bytes_raise(parser, payload)
          for index in collect_ref_func_indices_from_expr_raise(expr) {
            push_unique_u32(out, index)
          }
        }
      }
      7U => {
        parser |> read_ref_type_bytes_raise |> ignore
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
        parser |> read_ref_type_bytes_raise |> ignore
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
        parser |> read_ref_type_bytes_raise |> ignore
        let expr_count = parser.read_u32_leb128()
        for _ in 0U..<expr_count {
          let expr = read_const_expr_bytes_raise(parser, payload)
          for index in collect_global_get_indices_from_expr_raise(expr) {
            push_unique_u32(out, index)
          }
        }
      }
      7U => {
        parser |> read_ref_type_bytes_raise |> ignore
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
