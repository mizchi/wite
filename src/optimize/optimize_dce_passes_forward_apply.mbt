///|
pub fn collect_const_call_forwarding_alias_map(
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
      parse_forward_call_target_with_const_arg_instrs(
        code_bodies[i],
        wrapper_param_count,
      ) {
      Some((target, target_arg_instrs)) =>
        if target != old_index {
          let target_pos = UInt::reinterpret_as_int(target)
          if target_pos >= 0 && target_pos < function_type_by_index.length() {
            let target_type_index = function_type_by_index[target_pos]
            match function_type_entry_by_type_index.get(target_type_index) {
              Some(target_type) =>
                if can_const_forward_with_arg_instrs_to_target(
                    wrapper_type, target_type, target_arg_instrs, gc_type_canonical_map,
                  ) {
                  let uses_scratch_locals = const_arg_instrs_need_scratch_locals(
                    target_arg_instrs, wrapper_param_count,
                  )
                  let wrapper_param_local_types = match
                    collect_single_byte_local_types_from_params(
                      wrapper_type.params,
                    ) {
                    Some(v) => v
                    None => []
                  }
                  if !uses_scratch_locals ||
                    wrapper_param_local_types.length().reinterpret_as_uint() ==
                    wrapper_param_count {
                    alias_candidate.set(old_index, {
                      target,
                      target_arg_instrs,
                      wrapper_param_count,
                      wrapper_param_local_types,
                      uses_scratch_locals,
                    })
                  }
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
        let mut target_arg_instrs = initial_alias.target_arg_instrs.copy()
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
              match
                compose_const_call_forwarding_arg_instrs(
                  target_arg_instrs,
                  next_alias.target_arg_instrs,
                ) {
                Some(composed) => target_arg_instrs = composed
                None => {
                  valid = false
                  break
                }
              }
              current_target = next_alias.target
            }
            None => break
          }
        }
        if valid {
          let uses_scratch_locals = const_arg_instrs_need_scratch_locals(
            target_arg_instrs,
            initial_alias.wrapper_param_count,
          )
          if uses_scratch_locals &&
            initial_alias.wrapper_param_local_types
            .length()
            .reinterpret_as_uint() !=
            initial_alias.wrapper_param_count {
            continue
          }
          resolved_alias.set(old_index, {
            target: current_target,
            target_arg_instrs,
            wrapper_param_count: initial_alias.wrapper_param_count,
            wrapper_param_local_types: initial_alias.wrapper_param_local_types,
            uses_scratch_locals,
          })
        }
      }
      None => ()
    }
  }
  resolved_alias
}

///|
fn compose_const_call_forwarding_arg_instrs(
  current_target_arg_instrs : Array[Bytes],
  next_target_arg_instrs : Array[Bytes],
) -> Array[Bytes]? {
  let composed : Array[Bytes] = []
  for next_instr in next_target_arg_instrs {
    match parse_local_get_param_index_instr(next_instr) {
      Some(local_index) => {
        let local_pos = UInt::reinterpret_as_int(local_index)
        if local_pos < 0 || local_pos >= current_target_arg_instrs.length() {
          return None
        }
        composed.push(current_target_arg_instrs[local_pos])
      }
      None =>
        if appended_i32_const_instr_type(next_instr) is Some(_) {
          composed.push(next_instr)
        } else {
          return None
        }
    }
  }
  Some(composed)
}

///|
fn collect_direct_call_count_by_const_alias_raise(
  code_bodies : Array[Bytes],
  alias_map : Map[UInt, CfpConstAlias],
) -> Map[UInt, UInt] raise WiteError {
  let counts : Map[UInt, UInt] = {}
  for body in code_bodies {
    let prefix_end = parse_local_decl_prefix_end(body)
    let instr_bytes = body[prefix_end:body.length()].to_bytes()
    let spans = parse_instruction_spans_raise(instr_bytes)
    for span in spans {
      if span.opcode != 0x10U {
        continue
      }
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
        Some(_) => {
          let next = match counts.get(target) {
            Some(v) => v + 1U
            None => 1U
          }
          counts.set(target, next)
        }
        None => ()
      }
    }
  }
  counts
}

///|
fn estimate_scratch_const_call_forwarding_growth(
  alias_info : CfpConstAlias,
) -> UInt {
  let mut forwarded_param_ref_count = 0U
  let mut const_arg_bytes = 0U
  for instr in alias_info.target_arg_instrs {
    match parse_local_get_param_index_instr(instr) {
      Some(_) => forwarded_param_ref_count += 1U
      None => const_arg_bytes += instr.length().reinterpret_as_uint()
    }
  }
  forwarded_param_ref_count * 4U + const_arg_bytes
}

///|
fn scratch_const_call_forwarding_is_profitable(
  alias_info : CfpConstAlias,
  call_count : UInt,
  wrapper_body_bytes : UInt,
) -> Bool {
  let estimated_growth = estimate_scratch_const_call_forwarding_growth(
    alias_info,
  )
  let removable_bytes = wrapper_body_bytes + 2U
  call_count * estimated_growth <= removable_bytes
}

///|
pub fn collect_call_forwarding_alias_map(
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
            if function_type_entry_by_type_index.get(wrapper_type_index)
              is Some(wrapper_type) {
              if function_type_entry_by_type_index.get(target_type_index)
                is Some(target_type) {
                if function_type_entries_equal_with_gc_canonical_map(
                    wrapper_type, target_type, gc_type_canonical_map,
                  ) {
                  alias_candidate.set(old_index, target)
                }
              }
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
      if rewritten_target != target {
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
  caller_param_count : UInt,
  caller_base_local_types : Array[Byte],
) -> (Bytes, UInt, Array[Byte]) raise WiteError {
  let out : Array[Byte] = []
  let mut rewritten_call_count = 0U
  let added_local_types : Array[Byte] = []
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
          let replacement = if alias_info.uses_scratch_locals {
            let replacement = build_const_call_forwarding_replacement_raise(
              alias_info, caller_param_count, caller_base_local_types, added_local_types,
            )
            added_local_types.append(alias_info.wrapper_param_local_types[:])
            replacement
          } else {
            build_append_only_const_call_forwarding_replacement(alias_info)
          }
          out.append(replacement[:].to_array())
          rewritten_call_count += 1U
        }
        None => out.append(instr_bytes[span.start:span.end_].to_array())
      }
    } else {
      out.append(instr_bytes[span.start:span.end_].to_array())
    }
  }
  (Bytes::from_array(out[:]), rewritten_call_count, added_local_types)
}

///|
fn build_append_only_const_call_forwarding_replacement(
  alias_info : CfpConstAlias,
) -> Bytes {
  let out : Array[Byte] = []
  let wrapper_param_count_i = UInt::reinterpret_as_int(
    alias_info.wrapper_param_count,
  )
  for i in wrapper_param_count_i..<alias_info.target_arg_instrs.length() {
    out.append(alias_info.target_arg_instrs[i][:].to_array())
  }
  out.push(0x10U.to_byte())
  out.append(encode_u32_leb128(alias_info.target)[:])
  Bytes::from_array(out[:])
}

///|
fn build_const_call_forwarding_replacement_raise(
  alias_info : CfpConstAlias,
  caller_param_count : UInt,
  caller_base_local_types : Array[Byte],
  added_local_types : Array[Byte],
) -> Bytes raise WiteError {
  if alias_info.wrapper_param_local_types.length().reinterpret_as_uint() !=
    alias_info.wrapper_param_count {
    raise WiteError::InvalidFormat("missing scratch local types in cfp-const")
  }
  let temp_local_indices : Array[UInt] = []
  let temp_local_start = caller_param_count +
    caller_base_local_types.length().reinterpret_as_uint() +
    added_local_types.length().reinterpret_as_uint()
  for i in 0..<alias_info.wrapper_param_local_types.length() {
    temp_local_indices.push(temp_local_start + i.reinterpret_as_uint())
  }
  let out : Array[Byte] = []
  let mut i = temp_local_indices.length()
  while i > 0 {
    i -= 1
    ignore(
      out
      ..push(0x21U.to_byte())
      ..append(encode_u32_leb128(temp_local_indices[i])[:]),
    )
  }
  for target_arg_instr in alias_info.target_arg_instrs {
    match parse_local_get_param_index_instr(target_arg_instr) {
      Some(local_index) => {
        let local_pos = UInt::reinterpret_as_int(local_index)
        if local_pos < 0 || local_pos >= temp_local_indices.length() {
          raise WiteError::InvalidFormat(
            "cfp-const temp local index out of range",
          )
        }
        out.push(0x20U.to_byte())
        out.append(encode_u32_leb128(temp_local_indices[local_pos])[:])
      }
      None => out.append(target_arg_instr[:].to_array())
    }
  }
  out.push(0x10U.to_byte())
  out.append(encode_u32_leb128(alias_info.target)[:])
  Bytes::from_array(out[:])
}

///|
fn rewrite_code_section_payload_for_const_call_forwarding_raise(
  payload : Bytes,
  alias_map : Map[UInt, CfpConstAlias],
  local_function_param_counts : Array[UInt],
) -> (Bytes, UInt) raise WiteError {
  let bodies = parse_code_bodies(payload)
  if bodies.length() != local_function_param_counts.length() {
    raise WiteError::InvalidFormat(
      "body/param count mismatch for cfp-const rewrite: body=" +
      bodies.length().to_string() +
      " params=" +
      local_function_param_counts.length().to_string(),
    )
  }
  let rewritten_bodies : Array[Bytes] = []
  let mut rewritten_call_count = 0U
  for i in 0..<bodies.length() {
    let body = bodies[i]
    let prefix = parse_local_decl_prefix_raise(body)
    let instr_bytes = body[prefix.prefix_end:body.length()].to_bytes()
    let spans = parse_instruction_spans_raise(instr_bytes)
    let (rewritten_instr, rewritten_count, added_local_types) = rewrite_instruction_calls_for_const_call_forwarding_raise(
      instr_bytes,
      spans,
      alias_map,
      local_function_param_counts[i],
      prefix.local_types,
    )
    rewritten_call_count += rewritten_count
    if rewritten_count > 0U {
      let rewritten_body : Array[Byte] = []
      if added_local_types.length() == 0 {
        rewritten_body.append(body[0:prefix.prefix_end].to_array())
      } else {
        let rewritten_local_types = prefix.local_types.copy()
        rewritten_local_types.append(added_local_types[:])
        rewritten_body.append(
          encode_local_decl_prefix_from_local_types(rewritten_local_types)[:].to_array(),
        )
      }
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
fn apply_const_call_forwarding_propagation_raise_with_sections(
  bytes : Bytes,
  sections : Array[RawSection],
) -> CfpConstApplyResult raise WiteError {
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
  let local_function_param_counts : Array[UInt] = []
  for type_index in local_function_type_indices {
    match function_type_entry_by_type_index.get(type_index) {
      Some(type_entry) =>
        local_function_param_counts.push(
          type_entry.params.length().reinterpret_as_uint(),
        )
      None =>
        raise WiteError::InvalidFormat(
          "type index out of range in cfp-const: " + type_index.to_string(),
        )
    }
  }
  let alias_map = collect_const_call_forwarding_alias_map(
    code_bodies, imported_function_count, function_type_by_index, function_type_entry_by_type_index,
    gc_type_canonical_map,
  )
  let mut has_alias = false
  alias_map.each((_, _target) => has_alias = true)
  if !has_alias {
    return { bytes, rewritten_call_count: 0U }
  }
  let direct_call_count_by_target = collect_direct_call_count_by_const_alias_raise(
    code_bodies, alias_map,
  )
  let filtered_alias_map : Map[UInt, CfpConstAlias] = {}
  for i in 0..<code_bodies.length() {
    let old_index = imported_function_count + i.reinterpret_as_uint()
    match alias_map.get(old_index) {
      Some(alias_info) =>
        if !alias_info.uses_scratch_locals ||
          scratch_const_call_forwarding_is_profitable(
            alias_info,
            direct_call_count_by_target.get(old_index).unwrap_or(0U),
            code_bodies[i].length().reinterpret_as_uint(),
          ) {
          filtered_alias_map.set(old_index, alias_info)
        }
      None => ()
    }
  }
  let mut has_filtered_alias = false
  filtered_alias_map.each((_, _target) => has_filtered_alias = true)
  if !has_filtered_alias {
    return { bytes, rewritten_call_count: 0U }
  }
  let (rewritten_code_payload, rewritten_call_count) = rewrite_code_section_payload_for_const_call_forwarding_raise(
    code_payload, filtered_alias_map, local_function_param_counts,
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
fn apply_call_forwarding_propagation_raise_with_sections(
  bytes : Bytes,
  sections : Array[RawSection],
) -> CfpApplyResult raise WiteError {
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
  if !has_alias {
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
pub fn collect_signature_refine_alias_map(
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
      Some(
        (
          target,
          forwarded_param_count,
          dropped_result_count,
          appended_i32_const_instrs,
        )
      ) =>
        if target != old_index {
          let target_pos = UInt::reinterpret_as_int(target)
          if target_pos >= 0 && target_pos < function_type_by_index.length() {
            let target_type_index = function_type_by_index[target_pos]
            if function_type_entry_by_type_index.get(target_type_index)
              is Some(target_type) {
              if can_signature_refine_forward_to_target(
                  wrapper_type,
                  target_type,
                  forwarded_param_count,
                  appended_i32_const_instrs.length().reinterpret_as_uint(),
                  dropped_result_count,
                  gc_type_canonical_map,
                )
                is Some((dropped_param_count, dropped_result_count)) {
                alias_candidate.set(old_index, {
                  target,
                  dropped_param_count,
                  dropped_result_count,
                  appended_i32_const_instrs,
                })
              }
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
        let mut dropped_result_count = initial_alias.dropped_result_count
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
              dropped_param_count += next_alias.dropped_param_count
              dropped_result_count += next_alias.dropped_result_count
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
            dropped_param_count,
            dropped_result_count,
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
          for const_instr in alias_info.appended_i32_const_instrs {
            out.append(const_instr[:].to_array())
          }
          out.push(0x10U.to_byte())
          out.append(encode_u32_leb128(alias_info.target)[:])
          for _ in 0U..<alias_info.dropped_result_count {
            out.push(0x1aU.to_byte())
          }
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
fn apply_signature_refining_raise_with_sections(
  bytes : Bytes,
  sections : Array[RawSection],
) -> SignatureRefineApplyResult raise WiteError {
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
  if !has_alias {
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
