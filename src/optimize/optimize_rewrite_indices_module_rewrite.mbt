///|
fn collect_call_indirect_table_indices_from_instruction_raise(
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
      let parser = Cursor::new(imm)
      ignore(parser.read_u32_leb128())
      let table_index = parser.read_u32_leb128()
      if !parser.eof() {
        raise WiteError::InvalidFormat(
          "call_indirect immediate has trailing bytes",
        )
      }
      push_unique_u32(out, table_index)
    }
  }
  out
}

///|
pub fn collect_call_indirect_table_indices_from_code_section(
  payload : Bytes,
) -> Array[UInt]? {
  let result = try? ({
    let out : Array[UInt] = []
    let bodies = parse_code_bodies(payload)
    for body in bodies {
      let prefix_end = parse_local_decl_prefix_end(body)
      let instr_bytes = body[prefix_end:body.length()].to_bytes()
      let spans = parse_instruction_spans_raise(instr_bytes)
      for
        index in collect_call_indirect_table_indices_from_instruction_raise(
          instr_bytes, spans,
        ) {
        push_unique_u32(out, index)
      }
    }
    out
  })
  match result {
    Ok(v) => Some(v)
    Err(_) => None
  }
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
  let result = try? ({
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
  })
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
  let result = try? ({
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
  })
  match result {
    Ok(v) => Some(v)
    Err(_) => None
  }
}

///|
fn collect_used_memory_indices_from_code_section(
  payload : Bytes,
) -> Array[UInt]? {
  let result = try? ({
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
  })
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
        ignore(
          out
          ..push(0x11U.to_byte())
          ..append(encode_u32_leb128(type_index)[:])
          ..append(
            encode_u32_leb128(
              remap_table_index_raise(table_index, table_index_map),
            )[:],
          ),
        )
      }
      0x23U | 0x24U =>
        match decode_span_u32_immediate(instr_bytes, span) {
          Some(index) =>
            ignore(
              out
              ..push(span.opcode.to_byte())
              ..append(
                encode_u32_leb128(
                  remap_global_index_raise(index, global_index_map),
                )[:],
              ),
            )
          None =>
            raise WiteError::InvalidFormat(
              "failed to decode global index immediate",
            )
        }
      0x25U | 0x26U =>
        match decode_span_u32_immediate(instr_bytes, span) {
          Some(index) =>
            ignore(
              out
              ..push(span.opcode.to_byte())
              ..append(
                encode_u32_leb128(
                  remap_table_index_raise(index, table_index_map),
                )[:],
              ),
            )
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
          Some(index) =>
            ignore(
              out
              ..push(span.opcode.to_byte())
              ..append(
                encode_u32_leb128(
                  remap_memory_index_raise(index, memory_index_map),
                )[:],
              ),
            )
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
        ignore(
          out..push(0xfcU.to_byte())..append(encode_u32_leb128(subopcode)[:]),
        )
        match subopcode {
          8U => {
            let data_index = parser.read_u32_leb128()
            let memory_index = parser.read_u32_leb128()
            ignore(
              out
              ..append(
                encode_u32_leb128(
                  remap_data_segment_index_raise(data_index, data_index_map),
                )[:],
              )
              ..append(
                encode_u32_leb128(
                  remap_memory_index_raise(memory_index, memory_index_map),
                )[:],
              ),
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
            ignore(
              out
              ..append(
                encode_u32_leb128(
                  remap_memory_index_raise(dst_memory, memory_index_map),
                )[:],
              )
              ..append(
                encode_u32_leb128(
                  remap_memory_index_raise(src_memory, memory_index_map),
                )[:],
              ),
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
            ignore(
              out
              ..append(
                encode_u32_leb128(
                  remap_element_segment_index_raise(
                    elem_index, element_index_map,
                  ),
                )[:],
              )
              ..append(
                encode_u32_leb128(
                  remap_table_index_raise(table_index, table_index_map),
                )[:],
              ),
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
            ignore(
              out
              ..append(
                encode_u32_leb128(
                  remap_table_index_raise(dst_table, table_index_map),
                )[:],
              )
              ..append(
                encode_u32_leb128(
                  remap_table_index_raise(src_table, table_index_map),
                )[:],
              ),
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
    ignore(
      out
      ..append(encode_u32_leb128(rewritten.length().reinterpret_as_uint())[:])
      ..append(rewritten[:].to_array()),
    )
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
      1U => table_index_map.get(index).map(v => v)
      2U => memory_index_map.get(index).map(v => v)
      3U => global_index_map.get(index).map(v => v)
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
