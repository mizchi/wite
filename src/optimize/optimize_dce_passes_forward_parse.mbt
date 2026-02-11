///|
pub fn bytes_equal(a : Bytes, b : Bytes) -> Bool {
  if a.length() != b.length() {
    return false
  }
  for i in 0..<a.length() {
    if a[i] != b[i] {
      return false
    }
  }
  true
}

///|
fn detect_forward_call_span_position(
  spans : Array[InstrSpan],
  min_prefix_span_count : Int,
) -> Int? {
  if spans.length() < min_prefix_span_count + 2 {
    return None
  }
  let end_pos = spans.length() - 1
  if spans[end_pos].opcode != 0x0bU {
    return None
  }
  let direct_call_pos = end_pos - 1
  if direct_call_pos >= min_prefix_span_count &&
    spans[direct_call_pos].opcode == 0x10U {
    return Some(direct_call_pos)
  }
  if direct_call_pos <= min_prefix_span_count ||
    spans[direct_call_pos].opcode != 0x0fU {
    return None
  }
  let call_pos = direct_call_pos - 1
  if call_pos >= min_prefix_span_count && spans[call_pos].opcode == 0x10U {
    return Some(call_pos)
  }
  None
}

///|
fn parse_forward_call_target_with_param_count(
  body_bytes : Bytes,
  param_count : UInt,
) -> UInt? {
  let prefix_result = try? parse_local_decl_prefix_raise(body_bytes)
  let prefix = match prefix_result {
    Ok(v) => v
    Err(_) => return None
  }
  let prefix_end = prefix.prefix_end
  let param_count_i = UInt::reinterpret_as_int(param_count)
  if param_count_i < 0 {
    return None
  }
  let prefix_end_result = try? parse_local_decl_prefix_end(body_bytes)
  match prefix_end_result {
    Ok(v) => if v != prefix_end { return None }
    Err(_) => return None
  }
  let instr_bytes = body_bytes[prefix_end:body_bytes.length()].to_bytes()
  let spans = match parse_instruction_spans(instr_bytes) {
    Some(v) => v
    None => return None
  }
  let call_pos = match detect_forward_call_span_position(spans, param_count_i) {
    Some(v) => v
    None => return None
  }
  if call_pos != param_count_i {
    return None
  }
  for i in 0..<param_count_i {
    if spans[i].opcode != 0x20U {
      return None
    }
    match decode_span_u32_immediate(instr_bytes, spans[i]) {
      Some(local_index) =>
        if local_index != i.reinterpret_as_uint() {
          return None
        }
      None => return None
    }
  }
  decode_span_u32_immediate(instr_bytes, spans[call_pos])
}

///|
pub(all) struct SignatureRefineAlias {
  target : UInt
  dropped_param_count : UInt
  dropped_result_count : UInt
  appended_i32_const_instrs : Array[Bytes]
}

///|
fn parse_forward_call_target_with_prefix_param_count(
  body_bytes : Bytes,
) -> (UInt, UInt, UInt, Array[Bytes])? {
  let prefix_result = try? parse_local_decl_prefix_raise(body_bytes)
  let prefix = match prefix_result {
    Ok(v) => v
    Err(_) => return None
  }
  let prefix_end = prefix.prefix_end
  let prefix_end_result = try? parse_local_decl_prefix_end(body_bytes)
  match prefix_end_result {
    Ok(v) => if v != prefix_end { return None }
    Err(_) => return None
  }
  let instr_bytes = body_bytes[prefix_end:body_bytes.length()].to_bytes()
  let spans = match parse_instruction_spans(instr_bytes) {
    Some(v) => v
    None => return None
  }
  if spans.length() < 2 {
    return None
  }
  let end_pos = spans.length() - 1
  if spans[end_pos].opcode != 0x0bU {
    return None
  }
  let mut pos = end_pos - 1
  if pos < 0 {
    return None
  }
  if spans[pos].opcode == 0x0fU {
    pos -= 1
  }
  if pos < 0 {
    return None
  }
  let mut dropped_result_count = 0U
  while pos >= 0 && spans[pos].opcode == 0x1aU {
    dropped_result_count += 1U
    pos -= 1
  }
  if pos < 0 || spans[pos].opcode != 0x10U {
    return None
  }
  let call_pos = pos
  let mut forwarded_param_count = 0
  while forwarded_param_count < call_pos {
    if spans[forwarded_param_count].opcode != 0x20U {
      break
    }
    if decode_span_u32_immediate(instr_bytes, spans[forwarded_param_count])
      is Some(local_index) {
      if local_index != forwarded_param_count.reinterpret_as_uint() {
        return None
      }
    } else {
      return None
    }
    forwarded_param_count += 1
  }
  let appended_i32_const_instrs : Array[Bytes] = []
  for i in forwarded_param_count..<call_pos {
    if spans[i].opcode != 0x41U {
      return None
    }
    appended_i32_const_instrs.push(
      instr_bytes[spans[i].start:spans[i].end_].to_bytes(),
    )
  }
  if forwarded_param_count == 0 && appended_i32_const_instrs.length() == 0 {
    return None
  }
  decode_span_u32_immediate(instr_bytes, spans[call_pos]).map(target => {
    (
      target,
      forwarded_param_count.reinterpret_as_uint(),
      dropped_result_count,
      appended_i32_const_instrs,
    )
  })
}

///|
fn parse_forward_call_target_with_appended_i32_consts(
  body_bytes : Bytes,
  wrapper_param_count : UInt,
) -> (UInt, Array[Bytes])? {
  let prefix_result = try? parse_local_decl_prefix_raise(body_bytes)
  let prefix = match prefix_result {
    Ok(v) => v
    Err(_) => return None
  }
  let prefix_end = prefix.prefix_end
  let prefix_end_result = try? parse_local_decl_prefix_end(body_bytes)
  match prefix_end_result {
    Ok(v) => if v != prefix_end { return None }
    Err(_) => return None
  }
  let instr_bytes = body_bytes[prefix_end:body_bytes.length()].to_bytes()
  let spans = match parse_instruction_spans(instr_bytes) {
    Some(v) => v
    None => return None
  }
  let wrapper_param_count_i = UInt::reinterpret_as_int(wrapper_param_count)
  if wrapper_param_count_i < 0 {
    return None
  }
  let call_pos = match
    detect_forward_call_span_position(spans, wrapper_param_count_i) {
    Some(v) => v
    None => return None
  }
  if call_pos <= wrapper_param_count_i {
    return None
  }
  for i in 0..<wrapper_param_count_i {
    if spans[i].opcode != 0x20U {
      return None
    }
    match decode_span_u32_immediate(instr_bytes, spans[i]) {
      Some(local_index) =>
        if local_index != i.reinterpret_as_uint() {
          return None
        }
      None => return None
    }
  }
  let appended_i32_const_instrs : Array[Bytes] = []
  for i in wrapper_param_count_i..<call_pos {
    let span = spans[i]
    if span.opcode != 0x41U &&
      span.opcode != 0x42U &&
      span.opcode != 0x43U &&
      span.opcode != 0x44U {
      return None
    }
    appended_i32_const_instrs.push(instr_bytes[span.start:span.end_].to_bytes())
  }
  if appended_i32_const_instrs.length() == 0 {
    return None
  }
  decode_span_u32_immediate(instr_bytes, spans[call_pos]).map(target => {
    (target, appended_i32_const_instrs)
  })
}

///|
fn function_type_results_equal_with_gc_canonical_map(
  a : FunctionTypeEntry,
  b : FunctionTypeEntry,
  gc_type_canonical_map : Map[UInt, UInt],
) -> Bool {
  if a.results.length() != b.results.length() {
    return false
  }
  for i in 0..<a.results.length() {
    if !type_bytes_equal_with_gc_canonical_map(
        a.results[i],
        b.results[i],
        gc_type_canonical_map,
      ) {
      return false
    }
  }
  true
}

///|
fn is_i32_value_type(value_type : Bytes) -> Bool {
  value_type.length() == 1 && value_type[0] == 0x7fU.to_byte()
}

///|
pub fn collect_gc_type_canonical_map_from_entries_raise(
  parsed_type_entries : Array[ParsedTypeSectionEntry],
) -> Map[UInt, UInt] raise WiteError {
  let gc_type_canonical_map : Map[UInt, UInt] = {}
  for i in 0..<parsed_type_entries.length() {
    let old_type_index = i.reinterpret_as_uint()
    let entry = parsed_type_entries[i]
    if entry.form == 0x60U {
      continue
    }
    let mut canonical = old_type_index
    for j in 0..<i {
      if parsed_type_entries[j].form == entry.form &&
        parsed_type_entries[j].form != 0x60U &&
        gc_type_entries_equal_with_canonical_map_raise(
          entry.raw,
          parsed_type_entries[j].raw,
          gc_type_canonical_map,
        ) {
        canonical = remap_gc_type_index_for_refine(
          j.reinterpret_as_uint(),
          gc_type_canonical_map,
        )
        break
      }
    }
    gc_type_canonical_map.set(old_type_index, canonical)
  }
  gc_type_canonical_map
}

///|
fn can_const_forward_with_appended_i32_to_target(
  wrapper_type : FunctionTypeEntry,
  target_type : FunctionTypeEntry,
  appended_i32_const_instrs : Array[Bytes],
  gc_type_canonical_map : Map[UInt, UInt],
) -> Bool {
  let wrapper_param_count = wrapper_type.params.length().reinterpret_as_uint()
  let target_param_count = target_type.params.length().reinterpret_as_uint()
  let appended_const_count = appended_i32_const_instrs
    .length()
    .reinterpret_as_uint()
  if target_param_count != wrapper_param_count + appended_const_count {
    return false
  }
  if !function_type_results_equal_with_gc_canonical_map(
      wrapper_type, target_type, gc_type_canonical_map,
    ) {
    return false
  }
  for i in 0..<wrapper_type.params.length() {
    if !type_bytes_equal_with_gc_canonical_map(
        wrapper_type.params[i],
        target_type.params[i],
        gc_type_canonical_map,
      ) {
      return false
    }
  }
  for i in 0..<appended_i32_const_instrs.length() {
    let const_type = match
      appended_i32_const_instr_type(appended_i32_const_instrs[i]) {
      Some(v) => v
      None => return false
    }
    let param_index = wrapper_type.params.length() + i
    if !type_bytes_equal_with_gc_canonical_map(
        const_type,
        target_type.params[param_index],
        gc_type_canonical_map,
      ) {
      return false
    }
  }
  true
}

///|
fn appended_i32_const_instr_type(instr : Bytes) -> Bytes? {
  if instr.length() == 0 {
    return None
  }
  match instr[0].to_uint() {
    0x41U => [0x7fU.to_byte()] |> Bytes::from_array |> Some
    0x42U => [0x7eU.to_byte()] |> Bytes::from_array |> Some
    0x43U => [0x7dU.to_byte()] |> Bytes::from_array |> Some
    0x44U => [0x7cU.to_byte()] |> Bytes::from_array |> Some
    _ => None
  }
}

///|
fn function_type_entries_equal_with_gc_canonical_map(
  a : FunctionTypeEntry,
  b : FunctionTypeEntry,
  gc_type_canonical_map : Map[UInt, UInt],
) -> Bool {
  if a.params.length() != b.params.length() ||
    a.results.length() != b.results.length() {
    return false
  }
  for i in 0..<a.params.length() {
    if !type_bytes_equal_with_gc_canonical_map(
        a.params[i],
        b.params[i],
        gc_type_canonical_map,
      ) {
      return false
    }
  }
  for i in 0..<a.results.length() {
    if !type_bytes_equal_with_gc_canonical_map(
        a.results[i],
        b.results[i],
        gc_type_canonical_map,
      ) {
      return false
    }
  }
  true
}

///|
fn can_signature_refine_forward_to_target(
  wrapper_type : FunctionTypeEntry,
  target_type : FunctionTypeEntry,
  forwarded_param_count : UInt,
  appended_i32_const_count : UInt,
  dropped_result_count : UInt,
  gc_type_canonical_map : Map[UInt, UInt],
) -> (UInt, UInt)? {
  let wrapper_param_count = wrapper_type.params.length().reinterpret_as_uint()
  let target_param_count = target_type.params.length().reinterpret_as_uint()
  if forwarded_param_count > wrapper_param_count {
    return None
  }
  if target_param_count != forwarded_param_count + appended_i32_const_count {
    return None
  }
  if wrapper_param_count < target_param_count {
    return None
  }
  let wrapper_result_count = wrapper_type.results.length().reinterpret_as_uint()
  let target_result_count = target_type.results.length().reinterpret_as_uint()
  if target_result_count < wrapper_result_count {
    return None
  }
  let expected_dropped_result_count = target_result_count - wrapper_result_count
  if dropped_result_count != expected_dropped_result_count {
    return None
  }
  let wrapper_result_count_i = UInt::reinterpret_as_int(wrapper_result_count)
  for i in 0..<wrapper_result_count_i {
    if !type_bytes_equal_with_gc_canonical_map(
        wrapper_type.results[i],
        target_type.results[i],
        gc_type_canonical_map,
      ) {
      return None
    }
  }
  let forwarded_param_count_i = UInt::reinterpret_as_int(forwarded_param_count)
  for i in 0..<forwarded_param_count_i {
    if !type_bytes_equal_with_gc_canonical_map(
        wrapper_type.params[i],
        target_type.params[i],
        gc_type_canonical_map,
      ) {
      return None
    }
  }
  let target_param_count_i = UInt::reinterpret_as_int(target_param_count)
  for i in forwarded_param_count_i..<target_param_count_i {
    if !is_i32_value_type(target_type.params[i]) {
      return None
    }
  }
  let dropped_param_count = wrapper_param_count - forwarded_param_count
  if dropped_param_count == 0U &&
    dropped_result_count == 0U &&
    appended_i32_const_count == 0U {
    return None
  }
  Some((dropped_param_count, dropped_result_count))
}

///|
pub(all) struct CfpConstAlias {
  target : UInt
  appended_i32_const_instrs : Array[Bytes]
}
