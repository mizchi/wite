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
fn parse_prefixed_opcode_subopcode(
  instr_bytes : Bytes,
  span : InstrSpan,
) -> UInt? {
  if span.opcode != 0xfcU && span.opcode != 0xfdU {
    return None
  }
  if span.end_ <= span.start + 1 {
    return None
  }
  let parser = Cursor::new(instr_bytes)
  parser.set_pos(span.start + 1)
  let result = try? parser.read_u32_leb128()
  match result {
    Ok(v) => if parser.get_pos() <= span.end_ { Some(v) } else { None }
    Err(_) => None
  }
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
fn append_i32_const_small_signed(out : Array[Byte], value : Int) -> Unit {
  out.push(0x41U.to_byte())
  let encoded = if value < 0 { value + 128 } else { value }
  out.push(encoded.to_byte())
}

///|
fn append_i32_const_nonnegative(out : Array[Byte], value : UInt) -> Unit {
  out.push(0x41U.to_byte())
  out.append(encode_nonnegative_i32_leb128(value)[:])
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
  let max_nonnegative_i32 = 0x7fffffffU
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
      match decode_i32_const_nonnegative_from_span(instr_bytes, spans[i]) {
        Some(lhs) =>
          match
            decode_i32_const_nonnegative_from_span(instr_bytes, spans[i + 1]) {
            Some(rhs) =>
              if lhs <= max_nonnegative_i32 &&
                rhs <= max_nonnegative_i32 &&
                lhs <= max_nonnegative_i32 - rhs {
                let sum = lhs + rhs
                let original_len = spans[i].end_ -
                  spans[i].start +
                  (spans[i + 1].end_ - spans[i + 1].start) +
                  1
                let folded_imm = encode_nonnegative_i32_leb128(sum)
                let folded_len = 1 + folded_imm.length()
                if folded_len < original_len {
                  append_i32_const_nonnegative(out, sum)
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
fn eval_i32_const_cmp_nonnegative(
  lhs : UInt,
  rhs : UInt,
  opcode : UInt,
) -> UInt? {
  match opcode {
    0x46U => Some(if lhs == rhs { 1U } else { 0U })
    0x47U => Some(if lhs != rhs { 1U } else { 0U })
    0x48U | 0x49U => Some(if lhs < rhs { 1U } else { 0U })
    0x4aU | 0x4bU => Some(if lhs > rhs { 1U } else { 0U })
    0x4cU | 0x4dU => Some(if lhs <= rhs { 1U } else { 0U })
    0x4eU | 0x4fU => Some(if lhs >= rhs { 1U } else { 0U })
    _ => None
  }
}

///|
fn apply_precompute_i32_const_cmp(instr_bytes : Bytes) -> Bytes {
  let spans = match parse_instruction_spans(instr_bytes) {
    Some(v) => v
    None => return instr_bytes
  }
  let out : Array[Byte] = []
  let mut i = 0
  while i < spans.length() {
    if i + 2 < spans.length() &&
      spans[i].opcode == 0x41U &&
      spans[i + 1].opcode == 0x41U {
      match decode_i32_const_nonnegative_from_span(instr_bytes, spans[i]) {
        Some(lhs) =>
          match
            decode_i32_const_nonnegative_from_span(instr_bytes, spans[i + 1]) {
            Some(rhs) =>
              match
                eval_i32_const_cmp_nonnegative(lhs, rhs, spans[i + 2].opcode) {
                Some(value) => {
                  let original_len = spans[i].end_ -
                    spans[i].start +
                    (spans[i + 1].end_ - spans[i + 1].start) +
                    1
                  if 2 < original_len {
                    append_i32_const_small(out, value)
                    i += 3
                    continue
                  }
                }
                None => ()
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
fn is_memory_load_opcode(opcode : UInt) -> Bool {
  opcode == 0x28U || // i32.load
  opcode == 0x29U || // i64.load
  opcode == 0x2aU || // f32.load
  opcode == 0x2bU || // f64.load
  opcode == 0x2cU || // i32.load8_s
  opcode == 0x2dU || // i32.load8_u
  opcode == 0x2eU || // i32.load16_s
  opcode == 0x2fU || // i32.load16_u
  opcode == 0x30U || // i64.load8_s
  opcode == 0x31U || // i64.load8_u
  opcode == 0x32U || // i64.load16_s
  opcode == 0x33U || // i64.load16_u
  opcode == 0x34U || // i64.load32_s
  opcode == 0x35U // i64.load32_u
}

///|
fn decode_memory_memarg_from_span(
  instr_bytes : Bytes,
  span : InstrSpan,
) -> (UInt, UInt)? {
  if not(is_memory_load_opcode(span.opcode)) || span.end_ <= span.start + 1 {
    return None
  }
  let parser = Cursor::new(instr_bytes)
  parser.set_pos(span.start + 1)
  let align_result = try? parser.read_u32_leb128()
  let align = match align_result {
    Ok(v) => v
    Err(_) => return None
  }
  let offset_result = try? parser.read_u32_leb128()
  let offset = match offset_result {
    Ok(v) => v
    Err(_) => return None
  }
  if parser.get_pos() != span.end_ {
    return None
  }
  Some((align, offset))
}

///|
fn append_memory_load_with_memarg(
  out : Array[Byte],
  opcode : UInt,
  align : UInt,
  offset : UInt,
) -> Unit {
  out.push(opcode.to_byte())
  out.append(encode_u32_leb128(align)[:])
  out.append(encode_u32_leb128(offset)[:])
}

///|
fn apply_precompute_i32_add_into_load_offset(instr_bytes : Bytes) -> Bytes {
  let max_u32 = 0xffffffffU
  let spans = match parse_instruction_spans(instr_bytes) {
    Some(v) => v
    None => return instr_bytes
  }
  let out : Array[Byte] = []
  let mut i = 0
  while i < spans.length() {
    if i + 3 < spans.length() &&
      is_optimize_instructions_i32_get_opcode(spans[i].opcode) &&
      spans[i + 1].opcode == 0x41U &&
      spans[i + 2].opcode == 0x6aU &&
      is_memory_load_opcode(spans[i + 3].opcode) {
      match decode_i32_const_nonnegative_from_span(instr_bytes, spans[i + 1]) {
        Some(addend) =>
          match decode_memory_memarg_from_span(instr_bytes, spans[i + 3]) {
            Some((align, offset)) =>
              if addend <= max_u32 - offset {
                let new_offset = offset + addend
                let rewritten_load_len = 1 +
                  encode_u32_leb128(align).length() +
                  encode_u32_leb128(new_offset).length()
                let original_len = spans[i].end_ -
                  spans[i].start +
                  (spans[i + 1].end_ - spans[i + 1].start) +
                  1 +
                  (spans[i + 3].end_ - spans[i + 3].start)
                let rewritten_len = spans[i].end_ -
                  spans[i].start +
                  rewritten_load_len
                if rewritten_len < original_len {
                  out.append(
                    instr_bytes[spans[i].start:spans[i].end_].to_array(),
                  )
                  append_memory_load_with_memarg(
                    out,
                    spans[i + 3].opcode,
                    align,
                    new_offset,
                  )
                  i += 4
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
      match decode_i32_const_small_signed_from_span(instr_bytes, spans[i]) {
        Some(value) => {
          append_i32_const_small(out, if value == 0 { 1U } else { 0U })
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
fn known_local_const_unknown_sentinel() -> Int {
  2147483647
}

///|
fn known_local_const_get(known : Map[UInt, Int], local_index : UInt) -> Int? {
  match known.get(local_index) {
    Some(value) =>
      if value == known_local_const_unknown_sentinel() {
        None
      } else {
        Some(value)
      }
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
  let mut known_local_consts : Map[UInt, Int] = {}
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
                append_i32_const_small_signed(out, value)
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
          let mut assigned_const : Int? = None
          if i > 0 {
            assigned_const = decode_i32_const_small_signed_from_span(
              instr_bytes,
              spans[i - 1],
            )
          }
          match assigned_const {
            Some(value) => known_local_consts.set(local_index, value)
            None =>
              known_local_consts.set(
                local_index,
                known_local_const_unknown_sentinel(),
              )
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
      match decode_i32_const_small_signed_from_span(instr_bytes, spans[i]) {
        Some(0) => {
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
      current_bytes = apply_precompute_i32_add_into_load_offset(current_bytes)
      current_bytes = apply_precompute_i32_const_cmp(current_bytes)
      current_bytes = apply_precompute_i32_identity_ops(current_bytes)
      current_bytes = apply_precompute_i32_eqz_const(current_bytes)
      current_bytes = apply_precompute_i32_double_eqz_br_if(current_bytes)
      current_bytes = apply_precompute_local_const_propagation(current_bytes)
      current_bytes = apply_precompute_i32_add(current_bytes)
      current_bytes = apply_precompute_i32_add_into_load_offset(current_bytes)
      current_bytes = apply_precompute_i32_const_cmp(current_bytes)
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
pub fn parse_local_decl_prefix_end(body_bytes : Bytes) -> Int raise WiteError {
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
