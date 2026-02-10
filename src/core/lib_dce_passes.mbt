///|
priv struct DceApplyResult {
  bytes : Bytes
  removed_function_count : UInt
  removed_body_bytes : UInt
  dropped_name_section : Bool
}

///|
priv struct DfeApplyResult {
  bytes : Bytes
  removed_function_count : UInt
  removed_body_bytes : UInt
  dropped_name_section : Bool
}

///|
priv struct CfpApplyResult {
  bytes : Bytes
  rewritten_call_count : UInt
}

///|
priv struct CfpConstApplyResult {
  bytes : Bytes
  rewritten_call_count : UInt
}

///|
priv struct SignatureRefineApplyResult {
  bytes : Bytes
  rewritten_call_count : UInt
}

///|
priv struct DuplicateImportElimApplyResult {
  bytes : Bytes
  removed_import_count : UInt
  removed_function_import_count : UInt
  removed_table_import_count : UInt
  removed_memory_import_count : UInt
  removed_global_import_count : UInt
  dropped_name_section : Bool
}

///|
priv struct MsfApplyResult {
  bytes : Bytes
  removed_function_count : UInt
  removed_body_bytes : UInt
  dropped_name_section : Bool
}

///|
priv struct RumeApplyResult {
  bytes : Bytes
  removed_import_count : UInt
  removed_table_count : UInt
  removed_memory_count : UInt
  removed_global_count : UInt
  removed_element_count : UInt
  removed_data_count : UInt
  removed_export_count : UInt
}

///|
priv struct TypeRefineApplyResult {
  bytes : Bytes
  refined_type_count : UInt
}

///|
priv struct RemoveUnusedTypesApplyResult {
  bytes : Bytes
  removed_type_count : UInt
}

///|
priv struct SignaturePruneApplyResult {
  bytes : Bytes
  pruned_function_count : UInt
  pruned_param_count : UInt
}

///|
fn bytes_equal(a : Bytes, b : Bytes) -> Bool {
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
priv struct SignatureRefineAlias {
  target : UInt
  dropped_param_count : UInt
}

///|
fn parse_forward_call_target_with_prefix_param_count(
  body_bytes : Bytes,
) -> (UInt, UInt)? {
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
  let call_pos = match detect_forward_call_span_position(spans, 0) {
    Some(v) => v
    None => return None
  }
  for i in 0..<call_pos {
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
  match decode_span_u32_immediate(instr_bytes, spans[call_pos]) {
    Some(target) => Some((target, call_pos.reinterpret_as_uint()))
    None => None
  }
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
    if span.opcode != 0x41U {
      return None
    }
    appended_i32_const_instrs.push(instr_bytes[span.start:span.end_].to_bytes())
  }
  if appended_i32_const_instrs.length() == 0 {
    return None
  }
  match decode_span_u32_immediate(instr_bytes, spans[call_pos]) {
    Some(target) => Some((target, appended_i32_const_instrs))
    None => None
  }
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
    if not(
        type_bytes_equal_with_gc_canonical_map(
          a.results[i],
          b.results[i],
          gc_type_canonical_map,
        ),
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
fn collect_gc_type_canonical_map_from_entries_raise(
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
  appended_i32_const_count : UInt,
  gc_type_canonical_map : Map[UInt, UInt],
) -> Bool {
  let wrapper_param_count = wrapper_type.params.length().reinterpret_as_uint()
  let target_param_count = target_type.params.length().reinterpret_as_uint()
  if target_param_count != wrapper_param_count + appended_i32_const_count {
    return false
  }
  if not(
      function_type_results_equal_with_gc_canonical_map(
        wrapper_type, target_type, gc_type_canonical_map,
      ),
    ) {
    return false
  }
  for i in 0..<wrapper_type.params.length() {
    if not(
        type_bytes_equal_with_gc_canonical_map(
          wrapper_type.params[i],
          target_type.params[i],
          gc_type_canonical_map,
        ),
      ) {
      return false
    }
  }
  for i in wrapper_type.params.length()..<target_type.params.length() {
    if not(is_i32_value_type(target_type.params[i])) {
      return false
    }
  }
  true
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
    if not(
        type_bytes_equal_with_gc_canonical_map(
          a.params[i],
          b.params[i],
          gc_type_canonical_map,
        ),
      ) {
      return false
    }
  }
  for i in 0..<a.results.length() {
    if not(
        type_bytes_equal_with_gc_canonical_map(
          a.results[i],
          b.results[i],
          gc_type_canonical_map,
        ),
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
  gc_type_canonical_map : Map[UInt, UInt],
) -> UInt? {
  let wrapper_param_count = wrapper_type.params.length().reinterpret_as_uint()
  let target_param_count = target_type.params.length().reinterpret_as_uint()
  if forwarded_param_count != target_param_count {
    return None
  }
  if wrapper_param_count <= target_param_count {
    return None
  }
  if not(
      function_type_results_equal_with_gc_canonical_map(
        wrapper_type, target_type, gc_type_canonical_map,
      ),
    ) {
    return None
  }
  let target_param_count_i = UInt::reinterpret_as_int(target_param_count)
  for i in 0..<target_param_count_i {
    if not(
        type_bytes_equal_with_gc_canonical_map(
          wrapper_type.params[i],
          target_type.params[i],
          gc_type_canonical_map,
        ),
      ) {
      return None
    }
  }
  Some(wrapper_param_count - target_param_count)
}

///|
priv struct CfpConstAlias {
  target : UInt
  appended_i32_const_instrs : Array[Bytes]
}

///|
fn collect_const_call_forwarding_alias_map(
  code_bodies : Array[Bytes],
  imported_function_count : UInt,
  function_type_by_index : Array[UInt],
  function_type_entry_by_type_index : Map[UInt, FunctionTypeEntry],
  gc_type_canonical_map : Map[UInt, UInt],
) -> Map[UInt, CfpConstAlias] {
  let alias_candidate : Map[UInt, CfpConstAlias] = {}
  for i in 0..<code_bodies.length() {
    let old_index = imported_function_count + i.reinterpret_as_uint()
    let old_pos = UInt::reinterpret_as_int(old_index)
    if old_pos < 0 || old_pos >= function_type_by_index.length() {
      continue
    }
    let wrapper_type_index = function_type_by_index[old_pos]
    let wrapper_type = match
      function_type_entry_by_type_index.get(wrapper_type_index) {
      Some(v) => v
      None => continue
    }
    let wrapper_param_count = wrapper_type.params.length().reinterpret_as_uint()
    match
      parse_forward_call_target_with_appended_i32_consts(
        code_bodies[i],
        wrapper_param_count,
      ) {
      Some((target, appended_i32_const_instrs)) =>
        if target != old_index {
          let target_pos = UInt::reinterpret_as_int(target)
          if target_pos >= 0 && target_pos < function_type_by_index.length() {
            let target_type_index = function_type_by_index[target_pos]
            match function_type_entry_by_type_index.get(target_type_index) {
              Some(target_type) =>
                if can_const_forward_with_appended_i32_to_target(
                    wrapper_type,
                    target_type,
                    appended_i32_const_instrs.length().reinterpret_as_uint(),
                    gc_type_canonical_map,
                  ) {
                  alias_candidate.set(old_index, {
                    target,
                    appended_i32_const_instrs,
                  })
                }
              None => ()
            }
          }
        }
      None => ()
    }
  }
  let resolved_alias : Map[UInt, CfpConstAlias] = {}
  for i in 0..<code_bodies.length() {
    let old_index = imported_function_count + i.reinterpret_as_uint()
    match alias_candidate.get(old_index) {
      Some(initial_alias) => {
        let seen : Map[UInt, Bool] = {}
        let mut current_target = initial_alias.target
        let appended_i32_const_instrs = initial_alias.appended_i32_const_instrs.copy()
        let mut valid = true
        while true {
          if current_target == old_index {
            valid = false
            break
          }
          if seen.get(current_target) is Some(_) {
            valid = false
            break
          }
          seen.set(current_target, true)
          match alias_candidate.get(current_target) {
            Some(next_alias) => {
              appended_i32_const_instrs.append(
                next_alias.appended_i32_const_instrs[:],
              )
              current_target = next_alias.target
            }
            None => break
          }
        }
        if valid {
          resolved_alias.set(old_index, {
            target: current_target,
            appended_i32_const_instrs,
          })
        }
      }
      None => ()
    }
  }
  resolved_alias
}

///|
fn collect_call_forwarding_alias_map(
  code_bodies : Array[Bytes],
  imported_function_count : UInt,
  function_type_by_index : Array[UInt],
  function_type_entry_by_type_index : Map[UInt, FunctionTypeEntry],
  function_param_count_by_index : Array[UInt],
  gc_type_canonical_map : Map[UInt, UInt],
) -> Map[UInt, UInt] {
  let alias_candidate : Map[UInt, UInt] = {}
  for i in 0..<code_bodies.length() {
    let old_index = imported_function_count + i.reinterpret_as_uint()
    let old_pos = UInt::reinterpret_as_int(old_index)
    if old_pos < 0 ||
      old_pos >= function_type_by_index.length() ||
      old_pos >= function_param_count_by_index.length() {
      continue
    }
    let param_count = function_param_count_by_index[old_pos]
    match
      parse_forward_call_target_with_param_count(code_bodies[i], param_count) {
      Some(target) =>
        if target != old_index {
          let target_pos = UInt::reinterpret_as_int(target)
          if target_pos >= 0 && target_pos < function_type_by_index.length() {
            let wrapper_type_index = function_type_by_index[old_pos]
            let target_type_index = function_type_by_index[target_pos]
            match function_type_entry_by_type_index.get(wrapper_type_index) {
              Some(wrapper_type) =>
                match function_type_entry_by_type_index.get(target_type_index) {
                  Some(target_type) =>
                    if function_type_entries_equal_with_gc_canonical_map(
                        wrapper_type, target_type, gc_type_canonical_map,
                      ) {
                      alias_candidate.set(old_index, target)
                    }
                  None => ()
                }
              None => ()
            }
          }
        }
      None => ()
    }
  }
  let resolved_alias : Map[UInt, UInt] = {}
  for i in 0..<code_bodies.length() {
    let old_index = imported_function_count + i.reinterpret_as_uint()
    match alias_candidate.get(old_index) {
      Some(initial_target) => {
        let seen : Map[UInt, Bool] = {}
        let mut current = initial_target
        let mut valid = true
        while true {
          if current == old_index {
            valid = false
            break
          }
          if seen.get(current) is Some(_) {
            valid = false
            break
          }
          seen.set(current, true)
          match alias_candidate.get(current) {
            Some(next) => current = next
            None => break
          }
        }
        if valid {
          resolved_alias.set(old_index, current)
        }
      }
      None => ()
    }
  }
  resolved_alias
}

///|
fn rewrite_instruction_calls_for_call_forwarding_raise(
  instr_bytes : Bytes,
  spans : Array[InstrSpan],
  alias_map : Map[UInt, UInt],
) -> (Bytes, UInt) raise WiteError {
  let out : Array[Byte] = []
  let mut rewritten_call_count = 0U
  for span in spans {
    if span.opcode == 0x10U {
      if span.end_ <= span.start + 1 {
        raise WiteError::InvalidFormat("invalid call immediate in cfp")
      }
      let imm = instr_bytes[span.start + 1:span.end_].to_bytes()
      let target = match decode_u32_leb128_bytes(imm) {
        Some(v) => v
        None =>
          raise WiteError::InvalidFormat(
            "failed to decode call immediate in cfp",
          )
      }
      let rewritten_target = match alias_map.get(target) {
        Some(v) => v
        None => target
      }
      if rewritten_target != target &&
        encode_u32_leb128(rewritten_target).length() <=
        encode_u32_leb128(target).length() {
        rewritten_call_count += 1U
        out.push(0x10U.to_byte())
        out.append(encode_u32_leb128(rewritten_target)[:])
      } else {
        out.append(instr_bytes[span.start:span.end_].to_array())
      }
    } else {
      out.append(instr_bytes[span.start:span.end_].to_array())
    }
  }
  (Bytes::from_array(out[:]), rewritten_call_count)
}

///|
fn rewrite_instruction_calls_for_const_call_forwarding_raise(
  instr_bytes : Bytes,
  spans : Array[InstrSpan],
  alias_map : Map[UInt, CfpConstAlias],
) -> (Bytes, UInt) raise WiteError {
  let out : Array[Byte] = []
  let mut rewritten_call_count = 0U
  for span in spans {
    if span.opcode == 0x10U {
      if span.end_ <= span.start + 1 {
        raise WiteError::InvalidFormat("invalid call immediate in cfp-const")
      }
      let imm = instr_bytes[span.start + 1:span.end_].to_bytes()
      let target = match decode_u32_leb128_bytes(imm) {
        Some(v) => v
        None =>
          raise WiteError::InvalidFormat(
            "failed to decode call immediate in cfp-const",
          )
      }
      match alias_map.get(target) {
        Some(alias_info) => {
          for const_instr in alias_info.appended_i32_const_instrs {
            out.append(const_instr[:].to_array())
          }
          out.push(0x10U.to_byte())
          out.append(encode_u32_leb128(alias_info.target)[:])
          rewritten_call_count += 1U
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
fn rewrite_code_section_payload_for_const_call_forwarding_raise(
  payload : Bytes,
  alias_map : Map[UInt, CfpConstAlias],
) -> (Bytes, UInt) raise WiteError {
  let bodies = parse_code_bodies(payload)
  let rewritten_bodies : Array[Bytes] = []
  let mut rewritten_call_count = 0U
  for body in bodies {
    let prefix_end = parse_local_decl_prefix_end(body)
    let instr_bytes = body[prefix_end:body.length()].to_bytes()
    let spans = parse_instruction_spans_raise(instr_bytes)
    let (rewritten_instr, rewritten_count) = rewrite_instruction_calls_for_const_call_forwarding_raise(
      instr_bytes, spans, alias_map,
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
fn apply_const_call_forwarding_propagation_raise(
  bytes : Bytes,
) -> CfpConstApplyResult raise WiteError {
  let sections = parse_core_sections_raise(bytes)
  let mut type_payload : Bytes? = None
  let mut import_payload : Bytes? = None
  let mut function_payload : Bytes? = None
  let mut code_payload : Bytes? = None
  for section in sections {
    let payload = bytes[section.payload_start:section.section_end].to_bytes()
    match section.section_id {
      1U => type_payload = Some(payload)
      2U => import_payload = Some(payload)
      3U => function_payload = Some(payload)
      10U => code_payload = Some(payload)
      _ => ()
    }
  }
  let type_payload = match type_payload {
    Some(v) => v
    None => return { bytes, rewritten_call_count: 0U }
  }
  let function_payload = match function_payload {
    Some(v) => v
    None => return { bytes, rewritten_call_count: 0U }
  }
  let code_payload = match code_payload {
    Some(v) => v
    None => return { bytes, rewritten_call_count: 0U }
  }
  let local_function_type_indices = parse_function_type_indices(
    function_payload,
  )
  let code_bodies = parse_code_bodies(code_payload)
  if local_function_type_indices.length() != code_bodies.length() {
    raise WiteError::InvalidFormat(
      "function/code section count mismatch for cfp-const: function=" +
      local_function_type_indices.length().to_string() +
      " code=" +
      code_bodies.length().to_string(),
    )
  }
  let imported_function_type_indices = match import_payload {
    Some(payload) => parse_import_function_type_indices(payload)
    None => []
  }
  let function_type_by_index = imported_function_type_indices.copy()
  function_type_by_index.append(local_function_type_indices[:])
  let parsed_type_entries = parse_type_section_entries_with_refs_raise(
    type_payload, "cfp-const",
  )
  let gc_type_canonical_map = collect_gc_type_canonical_map_from_entries_raise(
    parsed_type_entries,
  )
  let function_type_entry_by_type_index : Map[UInt, FunctionTypeEntry] = {}
  for i in 0..<parsed_type_entries.length() {
    if parsed_type_entries[i].form == 0x60U {
      function_type_entry_by_type_index.set(
        i.reinterpret_as_uint(),
        parse_function_type_entry_from_raw_raise(
          parsed_type_entries[i].raw,
          "cfp-const",
        ),
      )
    }
  }
  let imported_function_count = imported_function_type_indices
    .length()
    .reinterpret_as_uint()
  let alias_map = collect_const_call_forwarding_alias_map(
    code_bodies, imported_function_count, function_type_by_index, function_type_entry_by_type_index,
    gc_type_canonical_map,
  )
  let mut has_alias = false
  alias_map.each((_, _target) => has_alias = true)
  if not(has_alias) {
    return { bytes, rewritten_call_count: 0U }
  }
  let (rewritten_code_payload, rewritten_call_count) = rewrite_code_section_payload_for_const_call_forwarding_raise(
    code_payload, alias_map,
  )
  if rewritten_call_count == 0U {
    return { bytes, rewritten_call_count: 0U }
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
fn rewrite_code_section_payload_for_call_forwarding_raise(
  payload : Bytes,
  alias_map : Map[UInt, UInt],
) -> (Bytes, UInt) raise WiteError {
  let bodies = parse_code_bodies(payload)
  let rewritten_bodies : Array[Bytes] = []
  let mut rewritten_call_count = 0U
  for body in bodies {
    let prefix_end = parse_local_decl_prefix_end(body)
    let instr_bytes = body[prefix_end:body.length()].to_bytes()
    let spans = parse_instruction_spans_raise(instr_bytes)
    let (rewritten_instr, rewritten_count) = rewrite_instruction_calls_for_call_forwarding_raise(
      instr_bytes, spans, alias_map,
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
fn apply_call_forwarding_propagation_raise(
  bytes : Bytes,
) -> CfpApplyResult raise WiteError {
  let sections = parse_core_sections_raise(bytes)
  let mut type_payload : Bytes? = None
  let mut import_payload : Bytes? = None
  let mut function_payload : Bytes? = None
  let mut code_payload : Bytes? = None
  for section in sections {
    let payload = bytes[section.payload_start:section.section_end].to_bytes()
    match section.section_id {
      1U => type_payload = Some(payload)
      2U => import_payload = Some(payload)
      3U => function_payload = Some(payload)
      10U => code_payload = Some(payload)
      _ => ()
    }
  }
  let type_payload = match type_payload {
    Some(v) => v
    None => return { bytes, rewritten_call_count: 0U }
  }
  let function_payload = match function_payload {
    Some(v) => v
    None => return { bytes, rewritten_call_count: 0U }
  }
  let code_payload = match code_payload {
    Some(v) => v
    None => return { bytes, rewritten_call_count: 0U }
  }
  let local_function_type_indices = parse_function_type_indices(
    function_payload,
  )
  let code_bodies = parse_code_bodies(code_payload)
  if local_function_type_indices.length() != code_bodies.length() {
    raise WiteError::InvalidFormat(
      "function/code section count mismatch for cfp: function=" +
      local_function_type_indices.length().to_string() +
      " code=" +
      code_bodies.length().to_string(),
    )
  }
  let imported_function_type_indices = match import_payload {
    Some(payload) => parse_import_function_type_indices(payload)
    None => []
  }
  let imported_function_count = imported_function_type_indices
    .length()
    .reinterpret_as_uint()
  let parsed_type_entries = parse_type_section_entries_with_refs_raise(
    type_payload, "cfp",
  )
  let type_count_u = parsed_type_entries.length().reinterpret_as_uint()
  let function_type_entry_by_type_index : Map[UInt, FunctionTypeEntry] = {}
  for i in 0..<parsed_type_entries.length() {
    if parsed_type_entries[i].form == 0x60U {
      function_type_entry_by_type_index.set(
        i.reinterpret_as_uint(),
        parse_function_type_entry_from_raw_raise(
          parsed_type_entries[i].raw,
          "cfp",
        ),
      )
    }
  }
  let gc_type_canonical_map = collect_gc_type_canonical_map_from_entries_raise(
    parsed_type_entries,
  )
  let function_type_by_index = imported_function_type_indices.copy()
  function_type_by_index.append(local_function_type_indices[:])
  let function_param_count_by_index : Array[UInt] = []
  for type_index in function_type_by_index {
    if type_index >= type_count_u {
      raise WiteError::InvalidFormat(
        "type index out of range in cfp: " + type_index.to_string(),
      )
    }
    let type_pos = UInt::reinterpret_as_int(type_index)
    if type_pos < 0 || type_pos >= parsed_type_entries.length() {
      raise WiteError::InvalidFormat(
        "type index position out of range in cfp: " + type_index.to_string(),
      )
    }
    if parsed_type_entries[type_pos].form != 0x60U {
      raise WiteError::InvalidFormat(
        "non-function type index used by function in cfp: " +
        type_index.to_string(),
      )
    }
    match function_type_entry_by_type_index.get(type_index) {
      Some(function_type_entry) =>
        function_param_count_by_index.push(
          function_type_entry.params.length().reinterpret_as_uint(),
        )
      None =>
        raise WiteError::InvalidFormat(
          "missing function type entry in cfp: " + type_index.to_string(),
        )
    }
  }
  let alias_map = collect_call_forwarding_alias_map(
    code_bodies, imported_function_count, function_type_by_index, function_type_entry_by_type_index,
    function_param_count_by_index, gc_type_canonical_map,
  )
  let mut has_alias = false
  alias_map.each((_, _target) => has_alias = true)
  if not(has_alias) {
    return { bytes, rewritten_call_count: 0U }
  }
  let (rewritten_code_payload, rewritten_call_count) = rewrite_code_section_payload_for_call_forwarding_raise(
    code_payload, alias_map,
  )
  if rewritten_call_count == 0U {
    return { bytes, rewritten_call_count: 0U }
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
fn collect_signature_refine_alias_map(
  code_bodies : Array[Bytes],
  imported_function_count : UInt,
  function_type_by_index : Array[UInt],
  function_type_entry_by_type_index : Map[UInt, FunctionTypeEntry],
  gc_type_canonical_map : Map[UInt, UInt],
) -> Map[UInt, SignatureRefineAlias] {
  let alias_candidate : Map[UInt, SignatureRefineAlias] = {}
  for i in 0..<code_bodies.length() {
    let old_index = imported_function_count + i.reinterpret_as_uint()
    let old_pos = UInt::reinterpret_as_int(old_index)
    if old_pos < 0 || old_pos >= function_type_by_index.length() {
      continue
    }
    let wrapper_type_index = function_type_by_index[old_pos]
    let wrapper_type = match
      function_type_entry_by_type_index.get(wrapper_type_index) {
      Some(v) => v
      None => continue
    }
    match parse_forward_call_target_with_prefix_param_count(code_bodies[i]) {
      Some((target, forwarded_param_count)) =>
        if target != old_index {
          let target_pos = UInt::reinterpret_as_int(target)
          if target_pos >= 0 && target_pos < function_type_by_index.length() {
            let target_type_index = function_type_by_index[target_pos]
            match function_type_entry_by_type_index.get(target_type_index) {
              Some(target_type) =>
                match
                  can_signature_refine_forward_to_target(
                    wrapper_type, target_type, forwarded_param_count, gc_type_canonical_map,
                  ) {
                  Some(dropped_param_count) =>
                    alias_candidate.set(old_index, {
                      target,
                      dropped_param_count,
                    })
                  None => ()
                }
              None => ()
            }
          }
        }
      None => ()
    }
  }
  let resolved_alias : Map[UInt, SignatureRefineAlias] = {}
  for i in 0..<code_bodies.length() {
    let old_index = imported_function_count + i.reinterpret_as_uint()
    match alias_candidate.get(old_index) {
      Some(initial_alias) => {
        let seen : Map[UInt, Bool] = {}
        let mut current_target = initial_alias.target
        let mut dropped_param_count = initial_alias.dropped_param_count
        let mut valid = true
        while true {
          if current_target == old_index {
            valid = false
            break
          }
          if seen.get(current_target) is Some(_) {
            valid = false
            break
          }
          seen.set(current_target, true)
          match alias_candidate.get(current_target) {
            Some(next_alias) => {
              dropped_param_count += next_alias.dropped_param_count
              current_target = next_alias.target
            }
            None => break
          }
        }
        if valid {
          resolved_alias.set(old_index, {
            target: current_target,
            dropped_param_count,
          })
        }
      }
      None => ()
    }
  }
  resolved_alias
}

///|
fn rewrite_instruction_calls_for_signature_refining_raise(
  instr_bytes : Bytes,
  spans : Array[InstrSpan],
  alias_map : Map[UInt, SignatureRefineAlias],
) -> (Bytes, UInt) raise WiteError {
  let out : Array[Byte] = []
  let mut rewritten_call_count = 0U
  for span in spans {
    if span.opcode == 0x10U {
      if span.end_ <= span.start + 1 {
        raise WiteError::InvalidFormat(
          "invalid call immediate in signature-refine",
        )
      }
      let imm = instr_bytes[span.start + 1:span.end_].to_bytes()
      let target = match decode_u32_leb128_bytes(imm) {
        Some(v) => v
        None =>
          raise WiteError::InvalidFormat(
            "failed to decode call immediate in signature-refine",
          )
      }
      match alias_map.get(target) {
        Some(alias_info) => {
          for _ in 0U..<alias_info.dropped_param_count {
            out.push(0x1aU.to_byte())
          }
          out.push(0x10U.to_byte())
          out.append(encode_u32_leb128(alias_info.target)[:])
          rewritten_call_count += 1U
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
fn rewrite_code_section_payload_for_signature_refining_raise(
  payload : Bytes,
  alias_map : Map[UInt, SignatureRefineAlias],
) -> (Bytes, UInt) raise WiteError {
  let bodies = parse_code_bodies(payload)
  let rewritten_bodies : Array[Bytes] = []
  let mut rewritten_call_count = 0U
  for body in bodies {
    let prefix_end = parse_local_decl_prefix_end(body)
    let instr_bytes = body[prefix_end:body.length()].to_bytes()
    let spans = parse_instruction_spans_raise(instr_bytes)
    let (rewritten_instr, rewritten_count) = rewrite_instruction_calls_for_signature_refining_raise(
      instr_bytes, spans, alias_map,
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
fn apply_signature_refining_raise(
  bytes : Bytes,
) -> SignatureRefineApplyResult raise WiteError {
  let sections = parse_core_sections_raise(bytes)
  let mut type_payload : Bytes? = None
  let mut import_payload : Bytes? = None
  let mut function_payload : Bytes? = None
  let mut code_payload : Bytes? = None
  for section in sections {
    let payload = bytes[section.payload_start:section.section_end].to_bytes()
    match section.section_id {
      1U => type_payload = Some(payload)
      2U => import_payload = Some(payload)
      3U => function_payload = Some(payload)
      10U => code_payload = Some(payload)
      _ => ()
    }
  }
  let type_payload = match type_payload {
    Some(v) => v
    None => return { bytes, rewritten_call_count: 0U }
  }
  let function_payload = match function_payload {
    Some(v) => v
    None => return { bytes, rewritten_call_count: 0U }
  }
  let code_payload = match code_payload {
    Some(v) => v
    None => return { bytes, rewritten_call_count: 0U }
  }
  let local_function_type_indices = parse_function_type_indices(
    function_payload,
  )
  let code_bodies = parse_code_bodies(code_payload)
  if local_function_type_indices.length() != code_bodies.length() {
    raise WiteError::InvalidFormat(
      "function/code section count mismatch for signature-refine: function=" +
      local_function_type_indices.length().to_string() +
      " code=" +
      code_bodies.length().to_string(),
    )
  }
  let imported_function_type_indices = match import_payload {
    Some(payload) => parse_import_function_type_indices(payload)
    None => []
  }
  let parsed_type_entries = parse_type_section_entries_with_refs_raise(
    type_payload, "signature-refine",
  )
  let type_count_u = parsed_type_entries.length().reinterpret_as_uint()
  let gc_type_canonical_map = collect_gc_type_canonical_map_from_entries_raise(
    parsed_type_entries,
  )
  let function_type_entry_by_type_index : Map[UInt, FunctionTypeEntry] = {}
  for i in 0..<parsed_type_entries.length() {
    if parsed_type_entries[i].form == 0x60U {
      let type_index = i.reinterpret_as_uint()
      function_type_entry_by_type_index.set(
        type_index,
        parse_function_type_entry_from_raw_raise(
          parsed_type_entries[i].raw,
          "signature-refine",
        ),
      )
    }
  }
  let function_type_by_index = imported_function_type_indices.copy()
  function_type_by_index.append(local_function_type_indices[:])
  for type_index in function_type_by_index {
    if type_index >= type_count_u {
      raise WiteError::InvalidFormat(
        "type index out of range in signature-refine: " + type_index.to_string(),
      )
    }
    let type_pos = UInt::reinterpret_as_int(type_index)
    if type_pos < 0 || type_pos >= parsed_type_entries.length() {
      raise WiteError::InvalidFormat(
        "type index position out of range in signature-refine: " +
        type_index.to_string(),
      )
    }
    if parsed_type_entries[type_pos].form != 0x60U {
      raise WiteError::InvalidFormat(
        "non-function type index used by function in signature-refine: " +
        type_index.to_string(),
      )
    }
  }
  let imported_function_count = imported_function_type_indices
    .length()
    .reinterpret_as_uint()
  let alias_map = collect_signature_refine_alias_map(
    code_bodies, imported_function_count, function_type_by_index, function_type_entry_by_type_index,
    gc_type_canonical_map,
  )
  let mut has_alias = false
  alias_map.each((_index, _alias) => has_alias = true)
  if not(has_alias) {
    return { bytes, rewritten_call_count: 0U }
  }
  let (rewritten_code_payload, rewritten_call_count) = rewrite_code_section_payload_for_signature_refining_raise(
    code_payload, alias_map,
  )
  if rewritten_call_count == 0U {
    return { bytes, rewritten_call_count: 0U }
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
fn apply_remove_unused_module_elements(
  bytes : Bytes,
  config : OptimizeConfig,
) -> RumeApplyResult {
  let result = try? apply_remove_unused_module_elements_raise(bytes, config)
  match result {
    Ok(v) => v
    Err(_) =>
      {
        bytes,
        removed_import_count: 0U,
        removed_table_count: 0U,
        removed_memory_count: 0U,
        removed_global_count: 0U,
        removed_element_count: 0U,
        removed_data_count: 0U,
        removed_export_count: 0U,
      }
  }
}

///|
fn apply_remove_unused_module_elements_raise(
  bytes : Bytes,
  config : OptimizeConfig,
) -> RumeApplyResult raise WiteError {
  let sections = parse_core_sections_raise(bytes)
  let mut import_section_payload : Bytes? = None
  let mut export_section_payload : Bytes? = None
  let mut table_section_payload : Bytes? = None
  let mut memory_section_payload : Bytes? = None
  let mut global_section_payload : Bytes? = None
  let mut element_section_payload : Bytes? = None
  let mut data_section_payload : Bytes? = None
  let mut import_entries : Array[ImportSectionEntry] = []
  let used_table_indices : Array[UInt] = []
  let used_memory_indices : Array[UInt] = []
  let global_root_indices : Array[UInt] = []
  let mut removed_export_by_name_count = 0U
  let mut analysis_complete = true
  for section in sections {
    let payload = bytes[section.payload_start:section.section_end].to_bytes()
    match section.section_id {
      2U => {
        import_section_payload = Some(payload)
        import_entries = parse_import_section_entries_raise(payload)
      }
      4U => table_section_payload = Some(payload)
      5U => memory_section_payload = Some(payload)
      6U => global_section_payload = Some(payload)
      7U => {
        let mut effective_export_payload = payload
        if config.closed_world &&
          not(config.safe_mode) &&
          config.closed_world_root_exports.length() > 0 {
          let (filtered, removed) = rewrite_export_section_payload_for_keep_names_raise(
            payload,
            config.closed_world_root_exports,
          )
          effective_export_payload = filtered
          removed_export_by_name_count += removed
        }
        export_section_payload = Some(effective_export_payload)
        for index in parse_export_table_indices(effective_export_payload) {
          push_unique_u32(used_table_indices, index)
        }
        for index in parse_export_memory_indices(effective_export_payload) {
          push_unique_u32(used_memory_indices, index)
        }
        for index in parse_export_global_indices(effective_export_payload) {
          push_unique_u32(global_root_indices, index)
        }
      }
      9U => {
        element_section_payload = Some(payload)
        let global_result = try? collect_used_global_indices_from_element_section_raise(
          payload,
        )
        match global_result {
          Ok(indices) =>
            for index in indices {
              push_unique_u32(global_root_indices, index)
            }
          Err(_) => analysis_complete = false
        }
      }
      10U => {
        match collect_used_table_indices_from_code_section(payload) {
          Some(indices) =>
            for index in indices {
              push_unique_u32(used_table_indices, index)
            }
          None => analysis_complete = false
        }
        match collect_used_memory_indices_from_code_section(payload) {
          Some(indices) =>
            for index in indices {
              push_unique_u32(used_memory_indices, index)
            }
          None => analysis_complete = false
        }
        match collect_used_global_indices_from_code_section(payload) {
          Some(indices) =>
            for index in indices {
              push_unique_u32(global_root_indices, index)
            }
          None => analysis_complete = false
        }
      }
      11U => {
        data_section_payload = Some(payload)
        let data_result = try? collect_used_memory_and_global_indices_from_data_section_raise(
          payload,
        )
        match data_result {
          Ok((memory_indices, global_indices)) => {
            for index in memory_indices {
              push_unique_u32(used_memory_indices, index)
            }
            for index in global_indices {
              push_unique_u32(global_root_indices, index)
            }
          }
          Err(_) => analysis_complete = false
        }
      }
      _ => ()
    }
  }
  if not(analysis_complete) {
    return {
      bytes,
      removed_import_count: 0U,
      removed_table_count: 0U,
      removed_memory_count: 0U,
      removed_global_count: 0U,
      removed_element_count: 0U,
      removed_data_count: 0U,
      removed_export_count: 0U,
    }
  }
  let mut imported_table_count = 0U
  let mut imported_memory_count = 0U
  let mut imported_global_count = 0U
  for entry in import_entries {
    match entry.kind {
      1U => imported_table_count += 1U
      2U => imported_memory_count += 1U
      3U => imported_global_count += 1U
      _ => ()
    }
  }
  let keep_import_tables : Array[Bool] = []
  for i in 0U..<imported_table_count {
    keep_import_tables.push(used_table_indices.contains(i))
  }
  let keep_import_memories : Array[Bool] = []
  for i in 0U..<imported_memory_count {
    keep_import_memories.push(used_memory_indices.contains(i))
  }
  let local_table_entries = match table_section_payload {
    Some(payload) => parse_table_section_entries_raise(payload)
    None => []
  }
  let local_memory_entries = match memory_section_payload {
    Some(payload) => parse_memory_section_entries_raise(payload)
    None => []
  }
  let local_global_entries : Array[GlobalSectionEntry] = match
    global_section_payload {
    Some(payload) => parse_global_section_entries_with_refs_raise(payload)
    None => []
  }
  let used_global_indices : Array[UInt] = []
  for index in global_root_indices {
    push_unique_u32(used_global_indices, index)
  }
  let queue : Array[UInt] = used_global_indices.copy()
  let mut queue_index = 0
  while queue_index < queue.length() {
    let current = queue[queue_index]
    queue_index += 1
    if current < imported_global_count {
      continue
    }
    let local_index_u = current - imported_global_count
    let local_index = UInt::reinterpret_as_int(local_index_u)
    if local_index >= 0 && local_index < local_global_entries.length() {
      for dep in local_global_entries[local_index].init_global_refs {
        if not(used_global_indices.contains(dep)) {
          push_unique_u32(used_global_indices, dep)
          queue.push(dep)
        }
      }
    }
  }
  let keep_import_globals : Array[Bool] = []
  for i in 0U..<imported_global_count {
    keep_import_globals.push(used_global_indices.contains(i))
  }
  let table_index_map : Map[UInt, UInt] = {}
  let mut kept_imported_table_count = 0U
  for i in 0U..<imported_table_count {
    let index = UInt::reinterpret_as_int(i)
    if index < 0 || index >= keep_import_tables.length() {
      raise WiteError::InvalidFormat("table import keep index out of range")
    }
    if keep_import_tables[index] {
      table_index_map.set(i, kept_imported_table_count)
      kept_imported_table_count += 1U
    }
  }
  let keep_local_tables : Array[Bool] = []
  let mut kept_local_table_count = 0U
  let mut removed_table_count = 0U
  for i in 0..<local_table_entries.length() {
    let old_index = imported_table_count + i.reinterpret_as_uint()
    if used_table_indices.contains(old_index) {
      keep_local_tables.push(true)
      table_index_map.set(
        old_index,
        kept_imported_table_count + kept_local_table_count,
      )
      kept_local_table_count += 1U
    } else {
      keep_local_tables.push(false)
      removed_table_count += 1U
    }
  }
  let memory_index_map : Map[UInt, UInt] = {}
  let mut kept_imported_memory_count = 0U
  for i in 0U..<imported_memory_count {
    let index = UInt::reinterpret_as_int(i)
    if index < 0 || index >= keep_import_memories.length() {
      raise WiteError::InvalidFormat("memory import keep index out of range")
    }
    if keep_import_memories[index] {
      memory_index_map.set(i, kept_imported_memory_count)
      kept_imported_memory_count += 1U
    }
  }
  let keep_local_memories : Array[Bool] = []
  let mut kept_local_memory_count = 0U
  let mut removed_memory_count = 0U
  for i in 0..<local_memory_entries.length() {
    let old_index = imported_memory_count + i.reinterpret_as_uint()
    if used_memory_indices.contains(old_index) {
      keep_local_memories.push(true)
      memory_index_map.set(
        old_index,
        kept_imported_memory_count + kept_local_memory_count,
      )
      kept_local_memory_count += 1U
    } else {
      keep_local_memories.push(false)
      removed_memory_count += 1U
    }
  }
  let global_index_map : Map[UInt, UInt] = {}
  let mut kept_imported_global_count = 0U
  for i in 0U..<imported_global_count {
    let index = UInt::reinterpret_as_int(i)
    if index < 0 || index >= keep_import_globals.length() {
      raise WiteError::InvalidFormat("global import keep index out of range")
    }
    if keep_import_globals[index] {
      global_index_map.set(i, kept_imported_global_count)
      kept_imported_global_count += 1U
    }
  }
  let keep_local_globals : Array[Bool] = []
  let mut kept_local_global_count = 0U
  let mut removed_global_count = 0U
  for i in 0..<local_global_entries.length() {
    let old_index = imported_global_count + i.reinterpret_as_uint()
    if used_global_indices.contains(old_index) {
      keep_local_globals.push(true)
      global_index_map.set(
        old_index,
        kept_imported_global_count + kept_local_global_count,
      )
      kept_local_global_count += 1U
    } else {
      keep_local_globals.push(false)
      removed_global_count += 1U
    }
  }
  let mut removed_import_count = 0U
  let mut rewritten_import_payload : Bytes? = None
  match import_section_payload {
    Some(payload) => {
      let (rewritten, removed) = rewrite_import_section_payload_for_keep_raise(
        payload, keep_import_tables, keep_import_memories, keep_import_globals,
      )
      rewritten_import_payload = Some(rewritten)
      removed_import_count = removed
    }
    None => ()
  }
  let mut removed_element_count = 0U
  let mut rewritten_element_payload : Bytes? = None
  let element_index_map : Map[UInt, UInt] = {}
  match element_section_payload {
    Some(payload) => {
      let (rewritten, removed_segments, segment_index_map) = rewrite_element_section_payload_for_table_index_map_raise(
        payload, table_index_map, global_index_map,
      )
      rewritten_element_payload = Some(rewritten)
      removed_element_count = removed_segments
      segment_index_map.each((key, value) => element_index_map.set(key, value))
    }
    None => ()
  }
  let mut removed_data_count = 0U
  let mut rewritten_data_payload : Bytes? = None
  let data_index_map : Map[UInt, UInt] = {}
  match data_section_payload {
    Some(payload) => {
      let (rewritten, removed_segments, segment_index_map) = rewrite_data_section_payload_for_memory_global_index_map_raise(
        payload, memory_index_map, global_index_map,
      )
      rewritten_data_payload = Some(rewritten)
      removed_data_count = removed_segments
      segment_index_map.each((key, value) => data_index_map.set(key, value))
    }
    None => ()
  }
  let mut removed_export_count = removed_export_by_name_count
  let mut rewritten_export_payload : Bytes? = None
  match export_section_payload {
    Some(payload) => {
      let (rewritten, removed) = rewrite_export_section_payload_for_module_index_maps_raise(
        payload, table_index_map, memory_index_map, global_index_map,
      )
      rewritten_export_payload = Some(rewritten)
      removed_export_count += removed
    }
    None => ()
  }
  if removed_import_count == 0U &&
    removed_table_count == 0U &&
    removed_memory_count == 0U &&
    removed_global_count == 0U &&
    removed_element_count == 0U &&
    removed_data_count == 0U &&
    removed_export_count == 0U {
    return {
      bytes,
      removed_import_count,
      removed_table_count,
      removed_memory_count,
      removed_global_count,
      removed_element_count,
      removed_data_count,
      removed_export_count,
    }
  }
  let out : Array[Byte] = bytes[0:8].to_array()
  for section in sections {
    let payload = bytes[section.payload_start:section.section_end].to_bytes()
    match section.section_id {
      2U =>
        match rewritten_import_payload {
          Some(rewritten) =>
            if parse_vec_count(rewritten) > 0U {
              append_encoded_section(out, 2U, rewritten)
            }
          None => ()
        }
      4U => {
        let rewritten = rewrite_table_section_payload_for_keep_local_raise(
          payload, keep_local_tables,
        )
        if parse_vec_count(rewritten) > 0U {
          append_encoded_section(out, 4U, rewritten)
        }
      }
      5U => {
        let rewritten = rewrite_memory_section_payload_for_keep_local_raise(
          payload, keep_local_memories,
        )
        if parse_vec_count(rewritten) > 0U {
          append_encoded_section(out, 5U, rewritten)
        }
      }
      6U => {
        let rewritten = rewrite_global_section_payload_for_keep_local_and_global_index_map_raise(
          payload, keep_local_globals, global_index_map,
        )
        if parse_vec_count(rewritten) > 0U {
          append_encoded_section(out, 6U, rewritten)
        }
      }
      7U =>
        match rewritten_export_payload {
          Some(rewritten) =>
            if parse_vec_count(rewritten) > 0U {
              append_encoded_section(out, 7U, rewritten)
            }
          None => ()
        }
      9U =>
        match rewritten_element_payload {
          Some(rewritten) =>
            if parse_vec_count(rewritten) > 0U {
              append_encoded_section(out, 9U, rewritten)
            }
          None =>
            out.append(
              bytes[section.section_start:section.section_end].to_array(),
            )
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
      11U =>
        match rewritten_data_payload {
          Some(rewritten) =>
            if parse_vec_count(rewritten) > 0U {
              append_encoded_section(out, 11U, rewritten)
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
    removed_import_count,
    removed_table_count,
    removed_memory_count,
    removed_global_count,
    removed_element_count,
    removed_data_count,
    removed_export_count,
  }
}

///|
fn apply_type_refining(bytes : Bytes) -> TypeRefineApplyResult {
  let result = try? apply_type_refining_raise(bytes)
  match result {
    Ok(v) => v
    Err(_) => { bytes, refined_type_count: 0U }
  }
}

///|
fn apply_type_refining_raise(
  bytes : Bytes,
) -> TypeRefineApplyResult raise WiteError {
  let sections = parse_core_sections_raise(bytes)
  let mut type_section_payload : Bytes? = None
  for section in sections {
    match section.section_id {
      1U =>
        type_section_payload = Some(
          bytes[section.payload_start:section.section_end].to_bytes(),
        )
      13U =>
        raise WiteError::InvalidFormat(
          "tag section is not supported in type-refine",
        )
      _ => ()
    }
  }
  let type_payload = match type_section_payload {
    Some(v) => v
    None => return { bytes, refined_type_count: 0U }
  }
  let parsed_type_entries = parse_type_section_entries_with_refs_raise(
    type_payload, "type-refine",
  )
  if parsed_type_entries.length() <= 1 {
    return { bytes, refined_type_count: 0U }
  }
  let function_type_entry_by_type_index : Map[UInt, FunctionTypeEntry] = {}
  let gc_type_canonical_map : Map[UInt, UInt] = {}
  for i in 0..<parsed_type_entries.length() {
    let old_type_index = i.reinterpret_as_uint()
    let entry = parsed_type_entries[i]
    if entry.form == 0x60U {
      function_type_entry_by_type_index.set(
        old_type_index,
        parse_function_type_entry_from_raw_raise(entry.raw, "type-refine"),
      )
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
  let keep_types : Array[Bool] = []
  let canonical_function_type_for_old : Map[UInt, UInt] = {}
  let mut refined_type_count = 0U
  for i in 0..<parsed_type_entries.length() {
    let old_type_index = i.reinterpret_as_uint()
    let entry = parsed_type_entries[i]
    if entry.form != 0x60U {
      keep_types.push(true)
      continue
    }
    let current_function_type = match
      function_type_entry_by_type_index.get(old_type_index) {
      Some(v) => v
      None =>
        raise WiteError::InvalidFormat(
          "missing function type entry in type-refine: " +
          old_type_index.to_string(),
        )
    }
    let mut canonical = old_type_index
    for j in 0..<i {
      if parsed_type_entries[j].form != 0x60U {
        continue
      }
      let candidate_type_index = j.reinterpret_as_uint()
      let candidate_function_type = match
        function_type_entry_by_type_index.get(candidate_type_index) {
        Some(v) => v
        None =>
          raise WiteError::InvalidFormat(
            "missing candidate function type entry in type-refine: " +
            candidate_type_index.to_string(),
          )
      }
      if function_type_entries_equal_with_gc_canonical_map(
          current_function_type, candidate_function_type, gc_type_canonical_map,
        ) {
        canonical = candidate_type_index
        break
      }
    }
    if canonical == old_type_index {
      keep_types.push(true)
    } else {
      keep_types.push(false)
      canonical_function_type_for_old.set(old_type_index, canonical)
      refined_type_count += 1U
    }
  }
  let type_index_map : Map[UInt, UInt] = {}
  let mut new_type_count = 0U
  for i in 0..<keep_types.length() {
    if keep_types[i] {
      type_index_map.set(i.reinterpret_as_uint(), new_type_count)
      new_type_count += 1U
    }
  }
  for i in 0..<parsed_type_entries.length() {
    let old_type_index = i.reinterpret_as_uint()
    match canonical_function_type_for_old.get(old_type_index) {
      Some(canonical) =>
        type_index_map.set(
          old_type_index,
          remap_type_index_raise(canonical, type_index_map),
        )
      None => ()
    }
  }
  if refined_type_count == 0U {
    return { bytes, refined_type_count: 0U }
  }
  let out : Array[Byte] = bytes[0:8].to_array()
  for section in sections {
    let payload = bytes[section.payload_start:section.section_end].to_bytes()
    match section.section_id {
      1U => {
        let rewritten = rewrite_type_section_payload_for_keep_raise(
          payload, keep_types,
        )
        if parse_vec_count(rewritten) > 0U {
          append_encoded_section(out, 1U, rewritten)
        }
      }
      2U =>
        append_encoded_section(
          out,
          2U,
          rewrite_import_section_payload_for_type_index_map_raise(
            payload, type_index_map,
          ),
        )
      3U =>
        append_encoded_section(
          out,
          3U,
          rewrite_function_section_payload_for_type_index_map_raise(
            payload, type_index_map,
          ),
        )
      10U =>
        append_encoded_section(
          out,
          10U,
          rewrite_code_section_payload_for_type_index_map_raise(
            payload, type_index_map,
          ),
        )
      _ =>
        out.append(bytes[section.section_start:section.section_end].to_array())
    }
  }
  { bytes: Bytes::from_array(out[:]), refined_type_count }
}

///|
fn apply_signature_pruning(bytes : Bytes) -> SignaturePruneApplyResult {
  let result = try? apply_signature_pruning_raise(bytes)
  match result {
    Ok(v) => v
    Err(_) => { bytes, pruned_function_count: 0U, pruned_param_count: 0U }
  }
}

///|
fn apply_signature_pruning_raise(
  bytes : Bytes,
) -> SignaturePruneApplyResult raise WiteError {
  let sections = parse_core_sections_raise(bytes)
  let mut imported_function_count = 0U
  let mut type_section_payload : Bytes? = None
  let mut function_section_payload : Bytes? = None
  let mut code_section_payload : Bytes? = None
  let protected_function_indices : Array[UInt] = []
  for section in sections {
    let payload = bytes[section.payload_start:section.section_end].to_bytes()
    match section.section_id {
      1U => type_section_payload = Some(payload)
      2U => imported_function_count += parse_import_function_count(payload)
      3U => function_section_payload = Some(payload)
      6U =>
        for index in parse_global_section_function_refs_raise(payload) {
          push_unique_u32(protected_function_indices, index)
        }
      7U => {
        let exports = parse_export_function_names(payload)
        exports.each((index, _names) => push_unique_u32(
          protected_function_indices, index,
        ))
      }
      8U =>
        push_unique_u32(
          protected_function_indices,
          parse_start_function_index(payload),
        )
      9U =>
        for index in parse_element_section_function_refs_raise(payload) {
          push_unique_u32(protected_function_indices, index)
        }
      10U => code_section_payload = Some(payload)
      13U =>
        raise WiteError::InvalidFormat(
          "tag section is not supported in signature-prune",
        )
      _ => ()
    }
  }
  let type_payload = match type_section_payload {
    Some(v) => v
    None => return { bytes, pruned_function_count: 0U, pruned_param_count: 0U }
  }
  let function_payload = match function_section_payload {
    Some(v) => v
    None => return { bytes, pruned_function_count: 0U, pruned_param_count: 0U }
  }
  let code_payload = match code_section_payload {
    Some(v) => v
    None => return { bytes, pruned_function_count: 0U, pruned_param_count: 0U }
  }
  let function_type_indices = parse_function_type_indices(function_payload)
  let code_bodies = parse_code_bodies(code_payload)
  if function_type_indices.length() != code_bodies.length() {
    raise WiteError::InvalidFormat(
      "function/code section count mismatch for signature-prune: function=" +
      function_type_indices.length().to_string() +
      " code=" +
      code_bodies.length().to_string(),
    )
  }
  let parsed_type_entries = parse_type_section_entries_with_refs_raise(
    type_payload, "signature-prune",
  )
  let type_count_u = parsed_type_entries.length().reinterpret_as_uint()
  let function_type_entry_by_type_index : Map[UInt, FunctionTypeEntry] = {}
  for i in 0..<parsed_type_entries.length() {
    if parsed_type_entries[i].form == 0x60U {
      function_type_entry_by_type_index.set(
        i.reinterpret_as_uint(),
        parse_function_type_entry_from_raw_raise(
          parsed_type_entries[i].raw,
          "signature-prune",
        ),
      )
    }
  }
  for type_index in function_type_indices {
    if type_index >= type_count_u {
      raise WiteError::InvalidFormat(
        "type index out of range in signature-prune: " + type_index.to_string(),
      )
    }
    let type_pos = UInt::reinterpret_as_int(type_index)
    if type_pos < 0 || type_pos >= parsed_type_entries.length() {
      raise WiteError::InvalidFormat(
        "type index position out of range in signature-prune: " +
        type_index.to_string(),
      )
    }
    if parsed_type_entries[type_pos].form != 0x60U {
      raise WiteError::InvalidFormat(
        "non-function type index used by function in signature-prune: " +
        type_index.to_string(),
      )
    }
  }
  for index in collect_ref_func_indices_from_code_section_raise(code_payload) {
    push_unique_u32(protected_function_indices, index)
  }
  let rewritten_type_entries : Array[Bytes] = []
  for entry in parsed_type_entries {
    rewritten_type_entries.push(entry.raw)
  }
  let rewritten_function_type_indices = function_type_indices.copy()
  let rewritten_code_bodies = code_bodies.copy()
  let old_param_count_by_local_pos : Map[UInt, UInt] = {}
  let removed_param_count_by_local_pos : Map[UInt, UInt] = {}
  let removed_param_count_by_function : Map[UInt, UInt] = {}
  let mut pruned_function_count = 0U
  let mut pruned_param_count = 0U
  for i in 0..<code_bodies.length() {
    let function_index = imported_function_count + i.reinterpret_as_uint()
    if protected_function_indices.contains(function_index) {
      continue
    }
    let type_index = function_type_indices[i]
    let type_entry = match function_type_entry_by_type_index.get(type_index) {
      Some(v) => v
      None =>
        raise WiteError::InvalidFormat(
          "non-function type index used by function in signature-prune: " +
          type_index.to_string(),
        )
    }
    let old_param_count = type_entry.params.length().reinterpret_as_uint()
    if old_param_count == 0U {
      continue
    }
    let body = code_bodies[i]
    let prefix_end = parse_local_decl_prefix_end(body)
    let instr_bytes = body[prefix_end:body.length()].to_bytes()
    let spans = parse_instruction_spans_raise(instr_bytes)
    let used_param_indices = collect_used_param_indices_from_instruction_raise(
      instr_bytes, spans, old_param_count,
    )
    let removed_param_count = compute_removed_trailing_param_count(
      old_param_count, used_param_indices,
    )
    if removed_param_count == 0U {
      continue
    }
    let new_param_count = old_param_count - removed_param_count
    let new_param_count_i = UInt::reinterpret_as_int(new_param_count)
    if new_param_count_i < 0 || new_param_count_i > type_entry.params.length() {
      raise WiteError::InvalidFormat(
        "invalid param trim count in signature-prune: old=" +
        old_param_count.to_string() +
        " removed=" +
        removed_param_count.to_string(),
      )
    }
    let new_params : Array[Bytes] = []
    for j in 0..<new_param_count_i {
      new_params.push(type_entry.params[j])
    }
    let new_type_entry = encode_function_type_entry(
      new_params,
      type_entry.results,
    )
    let new_type_index = match
      find_type_entry_index(rewritten_type_entries, new_type_entry) {
      Some(v) => v
      None => {
        let idx = rewritten_type_entries.length().reinterpret_as_uint()
        rewritten_type_entries.push(new_type_entry)
        idx
      }
    }
    rewritten_function_type_indices[i] = new_type_index
    let local_pos = i.reinterpret_as_uint()
    old_param_count_by_local_pos.set(local_pos, old_param_count)
    removed_param_count_by_local_pos.set(local_pos, removed_param_count)
    removed_param_count_by_function.set(function_index, removed_param_count)
    pruned_function_count += 1U
    pruned_param_count += removed_param_count
  }
  if pruned_function_count == 0U {
    return { bytes, pruned_function_count: 0U, pruned_param_count: 0U }
  }
  for i in 0..<rewritten_code_bodies.length() {
    let local_pos = i.reinterpret_as_uint()
    match removed_param_count_by_local_pos.get(local_pos) {
      Some(removed_param_count) =>
        if removed_param_count > 0U {
          let old_param_count = match
            old_param_count_by_local_pos.get(local_pos) {
            Some(v) => v
            None =>
              raise WiteError::InvalidFormat(
                "signature-prune local metadata missing",
              )
          }
          rewritten_code_bodies[i] = rewrite_code_body_for_signature_pruning_raise(
            rewritten_code_bodies[i],
            old_param_count,
            removed_param_count,
          )
        }
      None => ()
    }
  }
  for i in 0..<rewritten_code_bodies.length() {
    rewritten_code_bodies[i] = rewrite_code_body_calls_for_signature_pruning_raise(
      rewritten_code_bodies[i],
      removed_param_count_by_function,
    )
  }
  let rewritten_type_payload = encode_type_section_payload(
    rewritten_type_entries,
  )
  let rewritten_function_payload = encode_function_section_payload_from_type_indices(
    rewritten_function_type_indices,
  )
  let rewritten_code_payload = encode_code_section_payload_from_bodies(
    rewritten_code_bodies,
  )
  let out : Array[Byte] = bytes[0:8].to_array()
  for section in sections {
    match section.section_id {
      1U => append_encoded_section(out, 1U, rewritten_type_payload)
      3U => append_encoded_section(out, 3U, rewritten_function_payload)
      10U => append_encoded_section(out, 10U, rewritten_code_payload)
      _ =>
        out.append(bytes[section.section_start:section.section_end].to_array())
    }
  }
  {
    bytes: Bytes::from_array(out[:]),
    pruned_function_count,
    pruned_param_count,
  }
}

///|
fn apply_remove_unused_types(bytes : Bytes) -> RemoveUnusedTypesApplyResult {
  let result = try? apply_remove_unused_types_raise(bytes)
  match result {
    Ok(v) => v
    Err(_) => { bytes, removed_type_count: 0U }
  }
}

///|
fn apply_remove_unused_types_raise(
  bytes : Bytes,
) -> RemoveUnusedTypesApplyResult raise WiteError {
  let sections = parse_core_sections_raise(bytes)
  let mut type_section_payload : Bytes? = None
  let mut import_section_payload : Bytes? = None
  let mut function_section_payload : Bytes? = None
  let mut code_section_payload : Bytes? = None
  for section in sections {
    let payload = bytes[section.payload_start:section.section_end].to_bytes()
    match section.section_id {
      1U => type_section_payload = Some(payload)
      2U => import_section_payload = Some(payload)
      3U => function_section_payload = Some(payload)
      10U => code_section_payload = Some(payload)
      13U =>
        raise WiteError::InvalidFormat(
          "tag section is not supported in remove-unused-types",
        )
      _ => ()
    }
  }
  let type_payload = match type_section_payload {
    Some(v) => v
    None => return { bytes, removed_type_count: 0U }
  }
  let type_entries = parse_type_section_entries_with_refs_raise(
    type_payload, "remove-unused-types",
  )
  if type_entries.length() == 0 {
    return { bytes, removed_type_count: 0U }
  }
  let used_type_indices : Array[UInt] = []
  match import_section_payload {
    Some(payload) =>
      for
        type_index in collect_used_type_indices_from_import_section_raise(
          payload,
        ) {
        push_unique_u32(used_type_indices, type_index)
      }
    None => ()
  }
  match function_section_payload {
    Some(payload) =>
      for type_index in parse_function_type_indices(payload) {
        push_unique_u32(used_type_indices, type_index)
      }
    None => ()
  }
  match code_section_payload {
    Some(payload) =>
      for
        type_index in collect_used_type_indices_from_code_section_raise(payload) {
        push_unique_u32(used_type_indices, type_index)
      }
    None => ()
  }
  let type_count_u = type_entries.length().reinterpret_as_uint()
  for type_index in used_type_indices {
    if type_index >= type_count_u {
      raise WiteError::InvalidFormat(
        "type index out of range in remove-unused-types: " +
        type_index.to_string(),
      )
    }
  }
  let queue = used_type_indices.copy()
  let mut queue_head = 0
  while queue_head < queue.length() {
    let current = queue[queue_head]
    queue_head += 1
    let current_pos = UInt::reinterpret_as_int(current)
    if current_pos < 0 || current_pos >= type_entries.length() {
      raise WiteError::InvalidFormat(
        "type index position out of range in remove-unused-types: " +
        current.to_string(),
      )
    }
    for dep in type_entries[current_pos].referenced_type_indices {
      if dep >= type_count_u {
        raise WiteError::InvalidFormat(
          "referenced type index out of range in remove-unused-types: " +
          dep.to_string(),
        )
      }
      if not(used_type_indices.contains(dep)) {
        push_unique_u32(used_type_indices, dep)
        queue.push(dep)
      }
    }
  }
  let keep_types : Array[Bool] = []
  let type_index_map : Map[UInt, UInt] = {}
  let mut kept_type_count = 0U
  for i in 0..<type_entries.length() {
    let old_type_index = i.reinterpret_as_uint()
    let keep = used_type_indices.contains(old_type_index)
    keep_types.push(keep)
    if keep {
      type_index_map.set(old_type_index, kept_type_count)
      kept_type_count += 1U
    }
  }
  let removed_type_count = type_count_u - kept_type_count
  if removed_type_count == 0U {
    return { bytes, removed_type_count: 0U }
  }
  let out : Array[Byte] = bytes[0:8].to_array()
  for section in sections {
    let payload = bytes[section.payload_start:section.section_end].to_bytes()
    match section.section_id {
      1U => {
        let rewritten = rewrite_type_section_payload_for_keep_raise(
          payload, keep_types,
        )
        if parse_vec_count(rewritten) > 0U {
          append_encoded_section(out, 1U, rewritten)
        }
      }
      2U =>
        append_encoded_section(
          out,
          2U,
          rewrite_import_section_payload_for_type_index_map_raise(
            payload, type_index_map,
          ),
        )
      3U =>
        append_encoded_section(
          out,
          3U,
          rewrite_function_section_payload_for_type_index_map_raise(
            payload, type_index_map,
          ),
        )
      10U =>
        append_encoded_section(
          out,
          10U,
          rewrite_code_section_payload_for_type_index_map_raise(
            payload, type_index_map,
          ),
        )
      _ =>
        out.append(bytes[section.section_start:section.section_end].to_array())
    }
  }
  { bytes: Bytes::from_array(out[:]), removed_type_count }
}

///|
fn apply_dce_raise(
  bytes : Bytes,
  config : OptimizeConfig,
) -> DceApplyResult raise WiteError {
  let export_root_names = export_root_names_from_config(config)
  let call_graph = analyze_call_graph_raise(bytes, export_root_names)
  if call_graph.partial {
    return {
      bytes,
      removed_function_count: 0U,
      removed_body_bytes: 0U,
      dropped_name_section: false,
    }
  }
  let local_count = UInt::reinterpret_as_int(call_graph.local_function_count)
  if local_count < 0 {
    raise WiteError::InvalidFormat("local function count overflow")
  }
  if local_count != call_graph.nodes.length() {
    raise WiteError::InvalidFormat(
      "call graph node length mismatch: expected=" +
      local_count.to_string() +
      " actual=" +
      call_graph.nodes.length().to_string(),
    )
  }
  let keep_local : Array[Bool] = []
  let index_map : Map[UInt, UInt] = {}
  for i in 0U..<call_graph.imported_function_count {
    index_map.set(i, i)
  }
  let mut kept_local_count = 0U
  let mut removed_function_count = 0U
  for node in call_graph.nodes {
    keep_local.push(node.reachable_from_roots)
    if node.reachable_from_roots {
      index_map.set(
        node.function_index,
        call_graph.imported_function_count + kept_local_count,
      )
      kept_local_count += 1U
    } else {
      removed_function_count += 1U
    }
  }
  if removed_function_count == 0U {
    return {
      bytes,
      removed_function_count,
      removed_body_bytes: 0U,
      dropped_name_section: false,
    }
  }
  let sections = parse_core_sections_raise(bytes)
  let out : Array[Byte] = bytes[0:8].to_array()
  let mut dropped_name_section = false
  for section in sections {
    let payload = bytes[section.payload_start:section.section_end].to_bytes()
    match section.section_id {
      3U => {
        let rewritten = rewrite_function_section_payload_for_dce_raise(
          payload, keep_local,
        )
        if parse_vec_count(rewritten) > 0U {
          append_encoded_section(out, 3U, rewritten)
        }
      }
      7U =>
        append_encoded_section(
          out,
          7U,
          rewrite_export_section_payload_for_dce_raise(payload, index_map),
        )
      8U =>
        append_encoded_section(
          out,
          8U,
          rewrite_start_section_payload_for_dce_raise(payload, index_map),
        )
      10U => {
        let rewritten = rewrite_code_section_payload_for_dce_raise(
          payload, keep_local, index_map,
        )
        if parse_vec_count(rewritten) > 0U {
          append_encoded_section(out, 10U, rewritten)
        }
      }
      0U =>
        match section.custom_name {
          Some(name) =>
            if name == "name" {
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
      6U =>
        append_encoded_section(
          out,
          6U,
          rewrite_global_section_payload_for_index_map_raise(payload, index_map),
        )
      9U =>
        append_encoded_section(
          out,
          9U,
          rewrite_element_section_payload_for_index_map_raise(
            payload, index_map,
          ),
        )
      _ =>
        out.append(bytes[section.section_start:section.section_end].to_array())
    }
  }
  {
    bytes: Bytes::from_array(out[:]),
    removed_function_count,
    removed_body_bytes: call_graph.dead_body_bytes,
    dropped_name_section,
  }
}

///|
fn apply_dfe_raise(bytes : Bytes) -> DfeApplyResult raise WiteError {
  let sections = parse_core_sections_raise(bytes)
  let mut imported_function_count = 0U
  let mut function_type_indices : Array[UInt] = []
  let mut code_bodies : Array[Bytes] = []
  for section in sections {
    let payload = bytes[section.payload_start:section.section_end].to_bytes()
    match section.section_id {
      2U => imported_function_count += parse_import_function_count(payload)
      3U => function_type_indices = parse_function_type_indices(payload)
      10U => code_bodies = parse_code_bodies(payload)
      _ => ()
    }
  }
  if function_type_indices.length() != code_bodies.length() {
    raise WiteError::InvalidFormat(
      "function/code section count mismatch for dfe: function=" +
      function_type_indices.length().to_string() +
      " code=" +
      code_bodies.length().to_string(),
    )
  }
  let keep_local : Array[Bool] = []
  let index_map : Map[UInt, UInt] = {}
  for i in 0U..<imported_function_count {
    index_map.set(i, i)
  }
  let mut kept_local_count = 0U
  let mut removed_function_count = 0U
  let mut removed_body_bytes = 0U
  for i in 0..<code_bodies.length() {
    let old_index = imported_function_count + i.reinterpret_as_uint()
    let mut canonical_pos : Int? = None
    for j in 0..<i {
      if keep_local[j] &&
        function_type_indices[j] == function_type_indices[i] &&
        bytes_equal(code_bodies[j], code_bodies[i]) {
        canonical_pos = Some(j)
        break
      }
    }
    match canonical_pos {
      Some(pos) => {
        keep_local.push(false)
        let canonical_old_index = imported_function_count +
          pos.reinterpret_as_uint()
        let canonical_new_index = remap_function_index_raise(
          canonical_old_index, index_map,
        )
        index_map.set(old_index, canonical_new_index)
        removed_function_count += 1U
        removed_body_bytes += code_bodies[i].length().reinterpret_as_uint()
      }
      None => {
        keep_local.push(true)
        index_map.set(old_index, imported_function_count + kept_local_count)
        kept_local_count += 1U
      }
    }
  }
  if removed_function_count == 0U {
    return {
      bytes,
      removed_function_count,
      removed_body_bytes,
      dropped_name_section: false,
    }
  }
  let out : Array[Byte] = bytes[0:8].to_array()
  let mut dropped_name_section = false
  for section in sections {
    let payload = bytes[section.payload_start:section.section_end].to_bytes()
    match section.section_id {
      3U =>
        append_encoded_section(
          out,
          3U,
          rewrite_function_section_payload_for_dce_raise(payload, keep_local),
        )
      7U =>
        append_encoded_section(
          out,
          7U,
          rewrite_export_section_payload_for_dce_raise(payload, index_map),
        )
      8U =>
        append_encoded_section(
          out,
          8U,
          rewrite_start_section_payload_for_dce_raise(payload, index_map),
        )
      10U =>
        append_encoded_section(
          out,
          10U,
          rewrite_code_section_payload_for_dce_raise(
            payload, keep_local, index_map,
          ),
        )
      0U =>
        match section.custom_name {
          Some(name) =>
            if name == "name" {
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
      6U =>
        append_encoded_section(
          out,
          6U,
          rewrite_global_section_payload_for_index_map_raise(payload, index_map),
        )
      9U =>
        append_encoded_section(
          out,
          9U,
          rewrite_element_section_payload_for_index_map_raise(
            payload, index_map,
          ),
        )
      _ =>
        out.append(bytes[section.section_start:section.section_end].to_array())
    }
  }
  {
    bytes: Bytes::from_array(out[:]),
    removed_function_count,
    removed_body_bytes,
    dropped_name_section,
  }
}
