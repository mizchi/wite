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
  let instr_bytes = body_bytes[prefix_end:body_bytes.length()].to_owned()
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
fn parse_local_get_param_index_instr(instr : Bytes) -> UInt? {
  if instr.length() == 0 || instr[0] != 0x20U.to_byte() {
    return None
  }
  if !is_single_instruction_with_opcode(instr, 0x20U) {
    return None
  }
  decode_u32_leb128_bytes(instr[1:instr.length()].to_owned())
}

///|
fn is_single_instruction_with_opcode(instr : Bytes, opcode : UInt) -> Bool {
  if instr.length() == 0 {
    return false
  }
  let expr : Array[Byte] = instr.to_array()
  expr.push(0x0bU.to_byte())
  let spans = match parse_instruction_spans(Bytes::from_array(expr[:])) {
    Some(v) => v
    None => return false
  }
  spans.length() == 2 &&
  spans[0].opcode == opcode &&
  spans[0].start == 0 &&
  spans[0].end_ == instr.length() &&
  spans[1].opcode == 0x0bU &&
  spans[1].start == instr.length() &&
  spans[1].end_ == instr.length() + 1
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
  let instr_bytes = body_bytes[prefix_end:body_bytes.length()].to_owned()
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
      instr_bytes[spans[i].start:spans[i].end_].to_owned(),
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
fn parse_forward_call_target_with_const_arg_instrs(
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
  let instr_bytes = body_bytes[prefix_end:body_bytes.length()].to_owned()
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
  let target_arg_instrs : Array[Bytes] = []
  let mut expected_param_index = 0
  let mut const_count = 0U
  for i in 0..<call_pos {
    let span = spans[i]
    if span.opcode == 0x20U {
      match decode_span_u32_immediate(instr_bytes, span) {
        Some(local_index) =>
          if local_index != expected_param_index.reinterpret_as_uint() {
            return None
          } else {
            expected_param_index += 1
          }
        None => return None
      }
    } else if span.opcode == 0x41U ||
      span.opcode == 0x42U ||
      span.opcode == 0x43U ||
      span.opcode == 0x44U {
      const_count += 1U
    } else {
      return None
    }
    target_arg_instrs.push(instr_bytes[span.start:span.end_].to_owned())
  }
  if expected_param_index != wrapper_param_count_i || const_count == 0U {
    return None
  }
  decode_span_u32_immediate(instr_bytes, spans[call_pos]).map(target => {
    (target, target_arg_instrs)
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
  let gc_type_canonical_map : Map[UInt, UInt] = Map([])
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
fn const_arg_instrs_need_scratch_locals(
  target_arg_instrs : Array[Bytes],
  wrapper_param_count : UInt,
) -> Bool {
  let wrapper_param_count_i = UInt::reinterpret_as_int(wrapper_param_count)
  if wrapper_param_count_i < 0 {
    return false
  }
  if target_arg_instrs.length() < wrapper_param_count_i {
    return false
  }
  for i in 0..<wrapper_param_count_i {
    match parse_local_get_param_index_instr(target_arg_instrs[i]) {
      Some(local_index) =>
        if local_index != i.reinterpret_as_uint() {
          return true
        }
      None => return true
    }
  }
  for i in wrapper_param_count_i..<target_arg_instrs.length() {
    if appended_i32_const_instr_type(target_arg_instrs[i]) is None {
      return true
    }
  }
  false
}

///|
fn collect_single_byte_local_types_from_params(
  param_types : Array[Bytes],
) -> Array[Byte]? {
  let out : Array[Byte] = []
  for param_type in param_types {
    if param_type.length() != 1 {
      return None
    }
    out.push(param_type[0])
  }
  Some(out)
}

///|
fn count_const_arg_instrs(target_arg_instrs : Array[Bytes]) -> UInt {
  let mut count = 0U
  for instr in target_arg_instrs {
    if appended_i32_const_instr_type(instr) is Some(_) {
      count += 1U
    }
  }
  count
}

///|
fn can_const_forward_with_arg_instrs_to_target(
  wrapper_type : FunctionTypeEntry,
  target_type : FunctionTypeEntry,
  target_arg_instrs : Array[Bytes],
  gc_type_canonical_map : Map[UInt, UInt],
) -> Bool {
  let target_param_count = target_type.params.length().reinterpret_as_uint()
  if target_param_count != target_arg_instrs.length().reinterpret_as_uint() {
    return false
  }
  if !function_type_results_equal_with_gc_canonical_map(
      wrapper_type, target_type, gc_type_canonical_map,
    ) {
    return false
  }
  let used_params = make_bool_array(wrapper_type.params.length(), false)
  for i in 0..<target_arg_instrs.length() {
    match parse_local_get_param_index_instr(target_arg_instrs[i]) {
      Some(local_index) => {
        let local_pos = UInt::reinterpret_as_int(local_index)
        if local_pos < 0 || local_pos >= wrapper_type.params.length() {
          return false
        }
        if used_params[local_pos] {
          return false
        }
        if !type_bytes_equal_with_gc_canonical_map(
            wrapper_type.params[local_pos],
            target_type.params[i],
            gc_type_canonical_map,
          ) {
          return false
        }
        used_params[local_pos] = true
      }
      None => {
        let const_type = match
          appended_i32_const_instr_type(target_arg_instrs[i]) {
          Some(v) => v
          None => return false
        }
        if !type_bytes_equal_with_gc_canonical_map(
            const_type,
            target_type.params[i],
            gc_type_canonical_map,
          ) {
          return false
        }
      }
    }
  }
  for used in used_params {
    if !used {
      return false
    }
  }
  if count_const_arg_instrs(target_arg_instrs) == 0U {
    return false
  }
  true
}

///|
fn appended_i32_const_instr_type(instr : Bytes) -> Bytes? {
  if instr.length() == 0 {
    return None
  }
  match instr[0].to_uint() {
    0x41U =>
      if is_single_instruction_with_opcode(instr, 0x41U) {
        [0x7fU.to_byte()] |> Bytes::from_array |> Some
      } else {
        None
      }
    0x42U =>
      if is_single_instruction_with_opcode(instr, 0x42U) {
        [0x7eU.to_byte()] |> Bytes::from_array |> Some
      } else {
        None
      }
    0x43U =>
      if is_single_instruction_with_opcode(instr, 0x43U) {
        [0x7dU.to_byte()] |> Bytes::from_array |> Some
      } else {
        None
      }
    0x44U =>
      if is_single_instruction_with_opcode(instr, 0x44U) {
        [0x7cU.to_byte()] |> Bytes::from_array |> Some
      } else {
        None
      }
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
  target_arg_instrs : Array[Bytes]
  wrapper_param_count : UInt
  wrapper_param_local_types : Array[Byte]
  uses_scratch_locals : Bool
}

///|
let cfp_const_hint_custom_section_name = "wite.cfp_const_hints"

///|
fn is_cfp_const_hint_custom_section(section : RawSection) -> Bool {
  section.section_id == 0U &&
  section.custom_name.unwrap_or("") == cfp_const_hint_custom_section_name
}

///|
fn collect_cfp_const_hint_entries_and_section_stats(
  bytes : Bytes,
  sections : Array[RawSection],
) -> (Array[(UInt, UInt, Array[Bytes])], UInt, UInt, UInt) {
  let entries : Array[(UInt, UInt, Array[Bytes])] = []
  let mut section_count = 0U
  let mut unknown_version_section_count = 0U
  let mut malformed_section_count = 0U
  for section in sections {
    if !is_cfp_const_hint_custom_section(section) {
      continue
    }
    section_count += 1U
    let payload = bytes[section.payload_start:section.section_end].to_owned()
    let prefix_end = try parse_custom_section_name_prefix_end(payload) catch {
      _ => {
        malformed_section_count += 1U
        continue
      }
    } noraise {
      v => v
    }
    let body = payload[prefix_end:payload.length()].to_owned()
    let cursor = Cursor::new(body)
    let version = try cursor.read_u32_leb128() catch {
      _ => {
        malformed_section_count += 1U
        continue
      }
    } noraise {
      v => v
    }
    if version != 1U {
      unknown_version_section_count += 1U
      continue
    }
    let entry_count = try cursor.read_u32_leb128() catch {
      _ => {
        malformed_section_count += 1U
        continue
      }
    } noraise {
      v => v
    }
    let entry_count_i = UInt::reinterpret_as_int(entry_count)
    if entry_count_i < 0 {
      malformed_section_count += 1U
      continue
    }
    let section_entries : Array[(UInt, UInt, Array[Bytes])] = []
    let mut malformed = false
    for _ in 0..<entry_count_i {
      let wrapper_index = try cursor.read_u32_leb128() catch {
        _ => {
          malformed = true
          break
        }
      } noraise {
        v => v
      }
      let target_index = try cursor.read_u32_leb128() catch {
        _ => {
          malformed = true
          break
        }
      } noraise {
        v => v
      }
      let arg_count = try cursor.read_u32_leb128() catch {
        _ => {
          malformed = true
          break
        }
      } noraise {
        v => v
      }
      let arg_count_i = UInt::reinterpret_as_int(arg_count)
      if arg_count_i < 0 {
        malformed = true
        break
      }
      let target_arg_instrs : Array[Bytes] = []
      for _ in 0..<arg_count_i {
        let instr_len_u = try cursor.read_u32_leb128() catch {
          _ => {
            malformed = true
            break
          }
        } noraise {
          v => v
        }
        let instr_len = UInt::reinterpret_as_int(instr_len_u)
        if instr_len < 0 || cursor.get_pos() + instr_len > body.length() {
          malformed = true
          break
        }
        let instr_start = cursor.get_pos()
        let instr_end = instr_start + instr_len
        target_arg_instrs.push(body[instr_start:instr_end].to_owned())
        cursor.set_pos(instr_end)
      }
      if malformed {
        break
      }
      section_entries.push((wrapper_index, target_index, target_arg_instrs))
    }
    if malformed || !cursor.eof() {
      malformed_section_count += 1U
      continue
    }
    entries.append(section_entries[:])
  }
  (
    entries, section_count, unknown_version_section_count, malformed_section_count,
  )
}

///|
pub fn parse_cfp_const_hint_entries(
  bytes : Bytes,
  sections : Array[RawSection],
) -> Array[(UInt, UInt, Array[Bytes])] {
  let (entries, _, _, _) = collect_cfp_const_hint_entries_and_section_stats(
    bytes, sections,
  )
  entries
}

///|
pub fn collect_cfp_const_hint_section_stats(
  bytes : Bytes,
  sections : Array[RawSection],
) -> (UInt, UInt, UInt) {
  let (_, section_count, unknown_version_section_count, malformed_section_count) = collect_cfp_const_hint_entries_and_section_stats(
    bytes, sections,
  )
  (section_count, unknown_version_section_count, malformed_section_count)
}
