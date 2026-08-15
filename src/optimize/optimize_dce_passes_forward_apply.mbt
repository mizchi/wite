///|
pub fn collect_const_call_forwarding_alias_map(
  code_bodies : Array[Bytes],
  imported_function_count : UInt,
  function_type_by_index : Array[UInt],
  function_type_entry_by_type_index : Map[UInt, FunctionTypeEntry],
  gc_type_canonical_map : Map[UInt, UInt],
) -> Map[UInt, CfpConstAlias] {
  let alias_candidate : Map[UInt, CfpConstAlias] = Map([])
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
  let resolved_alias : Map[UInt, CfpConstAlias] = Map([])
  for i in 0..<code_bodies.length() {
    let old_index = imported_function_count + i.reinterpret_as_uint()
    match alias_candidate.get(old_index) {
      Some(initial_alias) => {
        let seen : Map[UInt, Bool] = Map([])
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
fn validate_const_call_forwarding_hint_entry(
  wrapper_index : UInt,
  target : UInt,
  target_arg_instrs : Array[Bytes],
  imported_function_count : UInt,
  function_type_by_index : Array[UInt],
  function_type_entry_by_type_index : Map[UInt, FunctionTypeEntry],
  gc_type_canonical_map : Map[UInt, UInt],
) -> (CfpConstAlias?, String?) {
  if wrapper_index < imported_function_count {
    return (None, Some("wrapper-not-local"))
  }
  if target == wrapper_index {
    return (None, Some("self-target"))
  }
  let wrapper_pos = UInt::reinterpret_as_int(wrapper_index)
  let target_pos = UInt::reinterpret_as_int(target)
  if wrapper_pos < 0 || wrapper_pos >= function_type_by_index.length() {
    return (None, Some("wrapper-index-out-of-range"))
  }
  if target_pos < 0 || target_pos >= function_type_by_index.length() {
    return (None, Some("target-index-out-of-range"))
  }
  let wrapper_type_index = function_type_by_index[wrapper_pos]
  let target_type_index = function_type_by_index[target_pos]
  let wrapper_type = match
    function_type_entry_by_type_index.get(wrapper_type_index) {
    Some(v) => v
    None => return (None, Some("wrapper-type-missing"))
  }
  let target_type = match
    function_type_entry_by_type_index.get(target_type_index) {
    Some(v) => v
    None => return (None, Some("target-type-missing"))
  }
  if !can_const_forward_with_arg_instrs_to_target(
      wrapper_type, target_type, target_arg_instrs, gc_type_canonical_map,
    ) {
    return (None, Some("recipe-type-mismatch"))
  }
  let wrapper_param_count = wrapper_type.params.length().reinterpret_as_uint()
  let uses_scratch_locals = const_arg_instrs_need_scratch_locals(
    target_arg_instrs, wrapper_param_count,
  )
  let wrapper_param_local_types = match
    collect_single_byte_local_types_from_params(wrapper_type.params) {
    Some(v) => v
    None => []
  }
  if uses_scratch_locals &&
    wrapper_param_local_types.length().reinterpret_as_uint() !=
    wrapper_param_count {
    return (None, Some("scratch-local-types-unsupported"))
  }
  (
    Some({
      target,
      target_arg_instrs,
      wrapper_param_count,
      wrapper_param_local_types,
      uses_scratch_locals,
    }),
    None,
  )
}

///|
pub fn collect_const_call_forwarding_hint_alias_map(
  bytes : Bytes,
  sections : Array[RawSection],
  imported_function_count : UInt,
  function_type_by_index : Array[UInt],
  function_type_entry_by_type_index : Map[UInt, FunctionTypeEntry],
  gc_type_canonical_map : Map[UInt, UInt],
) -> Map[UInt, CfpConstAlias] {
  let alias_map : Map[UInt, CfpConstAlias] = Map([])
  for entry in parse_cfp_const_hint_entries(bytes, sections) {
    let (wrapper_index, target, target_arg_instrs) = entry
    match
      validate_const_call_forwarding_hint_entry(
        wrapper_index, target, target_arg_instrs, imported_function_count, function_type_by_index,
        function_type_entry_by_type_index, gc_type_canonical_map,
      ) {
      (Some(alias_info), _) => alias_map.set(wrapper_index, alias_info)
      _ => ()
    }
  }
  alias_map
}

///|
fn compare_cfp_const_hint_reject_reason_count(
  a : CfpConstHintRejectReasonCount,
  b : CfpConstHintRejectReasonCount,
) -> Int {
  if a.count > b.count {
    -1
  } else if a.count < b.count {
    1
  } else {
    a.reason.compare(b.reason)
  }
}

///|
pub fn collect_const_call_forwarding_hint_reject_reason_counts(
  bytes : Bytes,
  sections : Array[RawSection],
  imported_function_count : UInt,
  function_type_by_index : Array[UInt],
  function_type_entry_by_type_index : Map[UInt, FunctionTypeEntry],
  gc_type_canonical_map : Map[UInt, UInt],
) -> Array[CfpConstHintRejectReasonCount] {
  let counts : Map[String, UInt] = Map([])
  for entry in parse_cfp_const_hint_entries(bytes, sections) {
    let (wrapper_index, target, target_arg_instrs) = entry
    match
      validate_const_call_forwarding_hint_entry(
        wrapper_index, target, target_arg_instrs, imported_function_count, function_type_by_index,
        function_type_entry_by_type_index, gc_type_canonical_map,
      ) {
      (_, Some(reason)) => {
        let prev = counts.get(reason).unwrap_or(0U)
        counts.set(reason, prev + 1U)
      }
      _ => ()
    }
  }
  let out : Array[CfpConstHintRejectReasonCount] = []
  counts.each((reason, count) => out.push({ reason, count }))
  out.sort_by(compare_cfp_const_hint_reject_reason_count)
  out
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
  let counts : Map[UInt, UInt] = Map([])
  for body in code_bodies {
    let prefix_end = parse_local_decl_prefix_end(body)
    let instr_bytes = body[prefix_end:body.length()].to_owned()
    let spans = parse_instruction_spans_raise(instr_bytes)
    for span in spans {
      if span.opcode != 0x10U {
        continue
      }
      if span.end_ <= span.start + 1 {
        raise WiteError::InvalidFormat("invalid call immediate in cfp-const")
      }
      let imm = instr_bytes[span.start + 1:span.end_].to_owned()
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
priv struct CfpConstSpecializeApplyResult {
  bytes : Bytes
  rewritten_call_count : UInt
  specialized_function_count : UInt
}

///|
priv struct ConstTargetSpecializePlan {
  target : UInt
  wrapper_type_index : UInt
  rewritten_target_body : Bytes
  rewritten_wrapper_body : Bytes
}

///|
pub fn collect_direct_call_count_by_function_raise(
  code_bodies : Array[Bytes],
) -> Map[UInt, UInt] raise WiteError {
  let counts : Map[UInt, UInt] = Map([])
  for body in code_bodies {
    let prefix_end = parse_local_decl_prefix_end(body)
    let instr_bytes = body[prefix_end:body.length()].to_owned()
    let spans = parse_instruction_spans_raise(instr_bytes)
    for span in spans {
      if span.opcode != 0x10U {
        continue
      }
      if span.end_ <= span.start + 1 {
        raise WiteError::InvalidFormat(
          "invalid call immediate in cfp-const-specialize",
        )
      }
      let imm = instr_bytes[span.start + 1:span.end_].to_owned()
      let target = match decode_u32_leb128_bytes(imm) {
        Some(v) => v
        None =>
          raise WiteError::InvalidFormat(
            "failed to decode call immediate in cfp-const-specialize",
          )
      }
      let next = match counts.get(target) {
        Some(v) => v + 1U
        None => 1U
      }
      counts.set(target, next)
    }
  }
  counts
}

///|
fn rewrite_instruction_local_indices_for_const_target_specialize_raise(
  instr_bytes : Bytes,
  spans : Array[InstrSpan],
  old_param_count : UInt,
  forwarded_param_index_by_old_param : Map[UInt, UInt],
  temp_local_index_by_old_param : Map[UInt, UInt],
) -> Bytes raise WiteError {
  let out : Array[Byte] = []
  for span in spans {
    if span.opcode == 0x20U || span.opcode == 0x21U || span.opcode == 0x22U {
      if span.end_ <= span.start + 1 {
        raise WiteError::InvalidFormat(
          "invalid local immediate in cfp-const-specialize",
        )
      }
      let imm = instr_bytes[span.start + 1:span.end_].to_owned()
      let local_index = match decode_u32_leb128_bytes(imm) {
        Some(v) => v
        None =>
          raise WiteError::InvalidFormat(
            "failed to decode local immediate in cfp-const-specialize",
          )
      }
      if local_index < old_param_count {
        let remapped = match
          forwarded_param_index_by_old_param.get(local_index) {
          Some(v) => v
          None =>
            match temp_local_index_by_old_param.get(local_index) {
              Some(v) => v
              None =>
                raise WiteError::InvalidFormat(
                  "missing param remap in cfp-const-specialize",
                )
            }
        }
        ignore(
          out
          ..push(span.opcode.to_byte())
          ..append(encode_u32_leb128(remapped)[:]),
        )
      } else {
        out.append(instr_bytes[span.start:span.end_].to_array())
      }
    } else {
      out.append(instr_bytes[span.start:span.end_].to_array())
    }
  }
  Bytes::from_array(out[:])
}

///|
fn build_const_target_specialized_body_raise(
  body_bytes : Bytes,
  target_arg_instrs : Array[Bytes],
) -> Bytes raise WiteError {
  let prefix = parse_local_decl_prefix_raise(body_bytes)
  let instr_bytes = body_bytes[prefix.prefix_end:body_bytes.length()].to_owned()
  let spans = parse_instruction_spans_raise(instr_bytes)
  let old_param_count = target_arg_instrs.length().reinterpret_as_uint()
  let forwarded_param_index_by_old_param : Map[UInt, UInt] = Map([])
  let temp_local_index_by_old_param : Map[UInt, UInt] = Map([])
  let temp_local_types : Array[Byte] = []
  let mut wrapper_param_count = 0U
  for instr in target_arg_instrs {
    if parse_local_get_param_index_instr(instr) is Some(_) {
      wrapper_param_count += 1U
    }
  }
  for i in 0..<target_arg_instrs.length() {
    let old_param_index = i.reinterpret_as_uint()
    match parse_local_get_param_index_instr(target_arg_instrs[i]) {
      Some(local_index) =>
        forwarded_param_index_by_old_param.set(old_param_index, local_index)
      None => {
        let const_type = match
          appended_i32_const_instr_type(target_arg_instrs[i]) {
          Some(v) => v
          None =>
            raise WiteError::InvalidFormat(
              "unsupported const arg in cfp-const-specialize",
            )
        }
        if const_type.length() != 1 {
          raise WiteError::InvalidFormat(
            "unexpected const type width in cfp-const-specialize",
          )
        }
        let temp_local_index = wrapper_param_count +
          temp_local_types.length().reinterpret_as_uint()
        temp_local_index_by_old_param.set(old_param_index, temp_local_index)
        temp_local_types.push(const_type[0])
      }
    }
  }
  let rewritten_instr = rewrite_instruction_local_indices_for_const_target_specialize_raise(
    instr_bytes, spans, old_param_count, forwarded_param_index_by_old_param, temp_local_index_by_old_param,
  )
  let rewritten_local_types = temp_local_types.copy()
  rewritten_local_types.append(prefix.local_types[:])
  let rewritten_prefix = encode_local_decl_prefix_from_local_types(
    rewritten_local_types,
  )
  let out : Array[Byte] = rewritten_prefix[:].to_array()
  for i in 0..<target_arg_instrs.length() {
    let old_param_index = i.reinterpret_as_uint()
    match temp_local_index_by_old_param.get(old_param_index) {
      Some(temp_local_index) => {
        out.append(target_arg_instrs[i][:].to_array())
        out.push(0x21U.to_byte())
        out.append(encode_u32_leb128(temp_local_index)[:])
      }
      None => ()
    }
  }
  out.append(rewritten_instr[:].to_array())
  Bytes::from_array(out[:])
}

///|
fn build_direct_forwarding_wrapper_body(
  wrapper_param_count : UInt,
  target : UInt,
) -> Bytes {
  let out : Array[Byte] = [0x00]
  for i in 0U..<wrapper_param_count {
    out.push(0x20U.to_byte())
    out.append(encode_u32_leb128(i)[:])
  }
  out.push(0x10U.to_byte())
  out.append(encode_u32_leb128(target)[:])
  out.push(0x0bU.to_byte())
  Bytes::from_array(out[:])
}

///|
fn validate_const_target_specialize_hint_alias_raise(
  wrapper_index : UInt,
  alias_info : CfpConstAlias,
  code_bodies : Array[Bytes],
  imported_function_count : UInt,
  function_type_by_index : Array[UInt],
  function_type_entry_by_type_index : Map[UInt, FunctionTypeEntry],
  direct_call_count_by_function : Map[UInt, UInt],
  root_function_indices : Map[UInt, Bool],
  gc_type_canonical_map : Map[UInt, UInt],
) -> String? raise WiteError {
  if root_function_indices.get(wrapper_index) is Some(_) {
    return Some("wrapper-root")
  }
  let wrapper_local_index = wrapper_index - imported_function_count
  let wrapper_local_pos = UInt::reinterpret_as_int(wrapper_local_index)
  if wrapper_local_pos < 0 || wrapper_local_pos >= code_bodies.length() {
    return Some("wrapper-body-missing")
  }
  let wrapper_pos = UInt::reinterpret_as_int(wrapper_index)
  if wrapper_pos < 0 || wrapper_pos >= function_type_by_index.length() {
    return Some("wrapper-index-out-of-range")
  }
  let wrapper_type_index = function_type_by_index[wrapper_pos]
  let wrapper_type = match
    function_type_entry_by_type_index.get(wrapper_type_index) {
    Some(v) => v
    None => return Some("wrapper-type-missing")
  }
  let wrapper_prefix = parse_local_decl_prefix_raise(
    code_bodies[wrapper_local_pos],
  )
  if wrapper_prefix.local_types.length() > 0 {
    return Some("wrapper-has-locals")
  }
  let target = alias_info.target
  if target == wrapper_index {
    return Some("self-target")
  }
  if root_function_indices.get(target) is Some(_) {
    return Some("target-root")
  }
  if direct_call_count_by_function.get(target).unwrap_or(0U) != 1U {
    return Some("target-direct-callers!=1")
  }
  if target < imported_function_count {
    return Some("target-not-local")
  }
  let target_pos = UInt::reinterpret_as_int(target)
  if target_pos < 0 || target_pos >= function_type_by_index.length() {
    return Some("target-index-out-of-range")
  }
  let target_local_index = target - imported_function_count
  let target_local_pos = UInt::reinterpret_as_int(target_local_index)
  if target_local_pos < 0 || target_local_pos >= code_bodies.length() {
    return Some("target-body-missing")
  }
  let target_type_index = function_type_by_index[target_pos]
  let target_type = match
    function_type_entry_by_type_index.get(target_type_index) {
    Some(v) => v
    None => return Some("target-type-missing")
  }
  let wrapper_param_count = wrapper_type.params.length().reinterpret_as_uint()
  let uses_scratch_locals = const_arg_instrs_need_scratch_locals(
    alias_info.target_arg_instrs,
    wrapper_param_count,
  )
  if !uses_scratch_locals {
    return Some("scratch-not-needed")
  }
  let wrapper_call_count = direct_call_count_by_function
    .get(wrapper_index)
    .unwrap_or(0U)
  if scratch_const_call_forwarding_is_profitable(
      {
        target,
        target_arg_instrs: alias_info.target_arg_instrs,
        wrapper_param_count,
        wrapper_param_local_types: [],
        uses_scratch_locals,
      },
      wrapper_call_count,
      code_bodies[wrapper_local_pos].length().reinterpret_as_uint(),
    ) {
    return Some("cfp-const-still-profitable")
  }
  if !can_const_forward_with_arg_instrs_to_target(
      wrapper_type,
      target_type,
      alias_info.target_arg_instrs,
      gc_type_canonical_map,
    ) {
    return Some("recipe-type-mismatch")
  }
  let build_result = try? build_const_target_specialized_body_raise(
    code_bodies[target_local_pos],
    alias_info.target_arg_instrs,
  )
  match build_result {
    Ok(_) => None
    Err(_) => Some("specialize-build-invalid")
  }
}

///|
pub fn collect_const_target_specialize_hint_analysis_raise(
  code_bodies : Array[Bytes],
  imported_function_count : UInt,
  function_type_by_index : Array[UInt],
  function_type_entry_by_type_index : Map[UInt, FunctionTypeEntry],
  hint_alias_map : Map[UInt, CfpConstAlias],
  direct_call_count_by_function : Map[UInt, UInt],
  root_function_indices : Map[UInt, Bool],
  gc_type_canonical_map : Map[UInt, UInt],
) -> (UInt, Array[CfpConstHintRejectReasonCount]) raise WiteError {
  let mut candidate_count = 0U
  let counts : Map[String, UInt] = Map([])
  hint_alias_map.each((wrapper_index, alias_info) => {
    match
      validate_const_target_specialize_hint_alias_raise(
        wrapper_index, alias_info, code_bodies, imported_function_count, function_type_by_index,
        function_type_entry_by_type_index, direct_call_count_by_function, root_function_indices,
        gc_type_canonical_map,
      ) {
      Some(reason) => {
        let prev = counts.get(reason).unwrap_or(0U)
        counts.set(reason, prev + 1U)
      }
      None => candidate_count += 1U
    }
  })
  let out : Array[CfpConstHintRejectReasonCount] = []
  counts.each((reason, count) => out.push({ reason, count }))
  out.sort_by(compare_cfp_const_hint_reject_reason_count)
  (candidate_count, out)
}

///|
fn collect_const_target_specialize_plan_raise(
  code_bodies : Array[Bytes],
  imported_function_count : UInt,
  function_type_by_index : Array[UInt],
  function_type_entry_by_type_index : Map[UInt, FunctionTypeEntry],
  hint_alias_map : Map[UInt, CfpConstAlias],
  direct_call_count_by_function : Map[UInt, UInt],
  root_function_indices : Map[UInt, Bool],
  gc_type_canonical_map : Map[UInt, UInt],
) -> Map[UInt, ConstTargetSpecializePlan] raise WiteError {
  let plans : Map[UInt, ConstTargetSpecializePlan] = Map([])
  for i in 0..<code_bodies.length() {
    let wrapper_index = imported_function_count + i.reinterpret_as_uint()
    if root_function_indices.get(wrapper_index) is Some(_) {
      continue
    }
    let wrapper_pos = UInt::reinterpret_as_int(wrapper_index)
    if wrapper_pos < 0 || wrapper_pos >= function_type_by_index.length() {
      continue
    }
    let wrapper_type_index = function_type_by_index[wrapper_pos]
    let wrapper_type = match
      function_type_entry_by_type_index.get(wrapper_type_index) {
      Some(v) => v
      None => continue
    }
    let wrapper_prefix = parse_local_decl_prefix_raise(code_bodies[i])
    if wrapper_prefix.local_types.length() > 0 {
      continue
    }
    let wrapper_param_count = wrapper_type.params.length().reinterpret_as_uint()
    let target_and_arg_instrs = match hint_alias_map.get(wrapper_index) {
      Some(alias_info) =>
        Some((alias_info.target, alias_info.target_arg_instrs))
      None =>
        parse_forward_call_target_with_const_arg_instrs(
          code_bodies[i],
          wrapper_param_count,
        )
    }
    match target_and_arg_instrs {
      Some((target, target_arg_instrs)) => {
        if target == wrapper_index ||
          root_function_indices.get(target) is Some(_) ||
          direct_call_count_by_function.get(target).unwrap_or(0U) != 1U {
          continue
        }
        if target < imported_function_count {
          continue
        }
        let target_pos = UInt::reinterpret_as_int(target)
        if target_pos < 0 || target_pos >= function_type_by_index.length() {
          continue
        }
        let target_local_index = target - imported_function_count
        let target_local_pos = UInt::reinterpret_as_int(target_local_index)
        if target_local_pos < 0 || target_local_pos >= code_bodies.length() {
          continue
        }
        let target_type_index = function_type_by_index[target_pos]
        let target_type = match
          function_type_entry_by_type_index.get(target_type_index) {
          Some(v) => v
          None => continue
        }
        let uses_scratch_locals = const_arg_instrs_need_scratch_locals(
          target_arg_instrs, wrapper_param_count,
        )
        if !uses_scratch_locals {
          continue
        }
        let wrapper_call_count = direct_call_count_by_function
          .get(wrapper_index)
          .unwrap_or(0U)
        if scratch_const_call_forwarding_is_profitable(
            {
              target,
              target_arg_instrs,
              wrapper_param_count,
              wrapper_param_local_types: [],
              uses_scratch_locals,
            },
            wrapper_call_count,
            code_bodies[i].length().reinterpret_as_uint(),
          ) {
          continue
        }
        if !can_const_forward_with_arg_instrs_to_target(
            wrapper_type, target_type, target_arg_instrs, gc_type_canonical_map,
          ) {
          continue
        }
        let rewritten_target_body = build_const_target_specialized_body_raise(
          code_bodies[target_local_pos],
          target_arg_instrs,
        )
        let rewritten_wrapper_body = build_direct_forwarding_wrapper_body(
          wrapper_param_count, target,
        )
        plans.set(wrapper_index, {
          target,
          wrapper_type_index,
          rewritten_target_body,
          rewritten_wrapper_body,
        })
      }
      None => ()
    }
  }
  plans
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
  let alias_candidate : Map[UInt, UInt] = Map([])
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
  let resolved_alias : Map[UInt, UInt] = Map([])
  for i in 0..<code_bodies.length() {
    let old_index = imported_function_count + i.reinterpret_as_uint()
    match alias_candidate.get(old_index) {
      Some(initial_target) => {
        let seen : Map[UInt, Bool] = Map([])
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
      let imm = instr_bytes[span.start + 1:span.end_].to_owned()
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
      let imm = instr_bytes[span.start + 1:span.end_].to_owned()
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
    let instr_bytes = body[prefix.prefix_end:body.length()].to_owned()
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
fn apply_const_call_forwarding_target_specialization_raise_with_sections(
  bytes : Bytes,
  sections : Array[RawSection],
  config : OptimizeConfig,
) -> CfpConstSpecializeApplyResult raise WiteError {
  let mut type_payload : Bytes? = None
  let mut import_payload : Bytes? = None
  let mut function_payload : Bytes? = None
  let mut code_payload : Bytes? = None
  for section in sections {
    let payload = bytes[section.payload_start:section.section_end].to_owned()
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
    None =>
      return { bytes, rewritten_call_count: 0U, specialized_function_count: 0U }
  }
  let function_payload = match function_payload {
    Some(v) => v
    None =>
      return { bytes, rewritten_call_count: 0U, specialized_function_count: 0U }
  }
  let code_payload = match code_payload {
    Some(v) => v
    None =>
      return { bytes, rewritten_call_count: 0U, specialized_function_count: 0U }
  }
  let local_function_type_indices = parse_function_type_indices(
    function_payload,
  )
  let code_bodies = parse_code_bodies(code_payload)
  if local_function_type_indices.length() != code_bodies.length() {
    raise WiteError::InvalidFormat(
      "function/code section count mismatch for cfp-const-specialize: function=" +
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
    type_payload, "cfp-const-specialize",
  )
  let gc_type_canonical_map = collect_gc_type_canonical_map_from_entries_raise(
    parsed_type_entries,
  )
  let function_type_entry_by_type_index : Map[UInt, FunctionTypeEntry] = Map([])
  for i in 0..<parsed_type_entries.length() {
    if parsed_type_entries[i].form == 0x60U {
      function_type_entry_by_type_index.set(
        i.reinterpret_as_uint(),
        parse_function_type_entry_from_raw_raise(
          parsed_type_entries[i].raw,
          "cfp-const-specialize",
        ),
      )
    }
  }
  let imported_function_count = imported_function_type_indices
    .length()
    .reinterpret_as_uint()
  let call_graph = try analyze_call_graph_raise(bytes, None) catch {
    _ =>
      return { bytes, rewritten_call_count: 0U, specialized_function_count: 0U }
  } noraise {
    v => v
  }
  if call_graph.partial {
    return { bytes, rewritten_call_count: 0U, specialized_function_count: 0U }
  }
  let root_function_indices : Map[UInt, Bool] = Map([])
  for index in call_graph.roots {
    root_function_indices.set(index, true)
  }
  let direct_call_count_by_function = collect_direct_call_count_by_function_raise(
    code_bodies,
  )
  let hint_alias_map = if config.enable_experimental_cfp_const_hints {
    collect_const_call_forwarding_hint_alias_map(
      bytes, sections, imported_function_count, function_type_by_index, function_type_entry_by_type_index,
      gc_type_canonical_map,
    )
  } else {
    {}
  }
  let plan_map = collect_const_target_specialize_plan_raise(
    code_bodies, imported_function_count, function_type_by_index, function_type_entry_by_type_index,
    hint_alias_map, direct_call_count_by_function, root_function_indices, gc_type_canonical_map,
  )
  let mut specialized_function_count = 0U
  let wrapper_to_target : Map[UInt, UInt] = Map([])
  let rewritten_local_function_type_indices = local_function_type_indices.copy()
  let rewritten_code_bodies = code_bodies.copy()
  for i in 0..<code_bodies.length() {
    let wrapper_index = imported_function_count + i.reinterpret_as_uint()
    match plan_map.get(wrapper_index) {
      Some(plan) => {
        wrapper_to_target.set(wrapper_index, plan.target)
        specialized_function_count += 1U
        let target_local_pos = UInt::reinterpret_as_int(
          plan.target - imported_function_count,
        )
        if target_local_pos < 0 ||
          target_local_pos >= rewritten_code_bodies.length() {
          raise WiteError::InvalidFormat(
            "target local index out of range in cfp-const-specialize",
          )
        }
        rewritten_local_function_type_indices[target_local_pos] = plan.wrapper_type_index
        rewritten_code_bodies[target_local_pos] = plan.rewritten_target_body
        rewritten_code_bodies[i] = plan.rewritten_wrapper_body
      }
      None => ()
    }
  }
  if specialized_function_count == 0U {
    return { bytes, rewritten_call_count: 0U, specialized_function_count: 0U }
  }
  let rewritten_function_payload = encode_function_section_payload_from_type_indices(
    rewritten_local_function_type_indices,
  )
  let interim_code_payload = encode_code_section_payload_from_bodies(
    rewritten_code_bodies,
  )
  let (rewritten_code_payload, rewritten_call_count) = rewrite_code_section_payload_for_call_forwarding_raise(
    interim_code_payload, wrapper_to_target,
  )
  if rewritten_call_count == 0U {
    return { bytes, rewritten_call_count: 0U, specialized_function_count: 0U }
  }
  let out : Array[Byte] = bytes[0:8].to_array()
  for section in sections {
    if config.enable_experimental_cfp_const_hints &&
      is_cfp_const_hint_custom_section(section) {
      continue
    } else if section.section_id == 3U {
      append_encoded_section(out, 3U, rewritten_function_payload)
    } else if section.section_id == 10U {
      append_encoded_section(out, 10U, rewritten_code_payload)
    } else {
      out.append(bytes[section.section_start:section.section_end].to_array())
    }
  }
  {
    bytes: Bytes::from_array(out[:]),
    rewritten_call_count,
    specialized_function_count,
  }
}

///|
fn apply_const_call_forwarding_propagation_raise_with_sections(
  bytes : Bytes,
  sections : Array[RawSection],
  config : OptimizeConfig,
) -> CfpConstApplyResult raise WiteError {
  let mut type_payload : Bytes? = None
  let mut import_payload : Bytes? = None
  let mut function_payload : Bytes? = None
  let mut code_payload : Bytes? = None
  for section in sections {
    let payload = bytes[section.payload_start:section.section_end].to_owned()
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
  let function_type_entry_by_type_index : Map[UInt, FunctionTypeEntry] = Map([])
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
  let hint_alias_map = if config.enable_experimental_cfp_const_hints {
    collect_const_call_forwarding_hint_alias_map(
      bytes, sections, imported_function_count, function_type_by_index, function_type_entry_by_type_index,
      gc_type_canonical_map,
    )
  } else {
    {}
  }
  let merged_alias_map = alias_map.copy()
  hint_alias_map.each((wrapper_index, alias_info) => {
    if merged_alias_map.get(wrapper_index) is None {
      merged_alias_map.set(wrapper_index, alias_info)
    }
  })
  let mut has_alias = false
  merged_alias_map.each((_, _target) => has_alias = true)
  if !has_alias {
    return { bytes, rewritten_call_count: 0U }
  }
  let direct_call_count_by_target = collect_direct_call_count_by_const_alias_raise(
    code_bodies, merged_alias_map,
  )
  let filtered_alias_map : Map[UInt, CfpConstAlias] = Map([])
  for i in 0..<code_bodies.length() {
    let old_index = imported_function_count + i.reinterpret_as_uint()
    match merged_alias_map.get(old_index) {
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
    if config.enable_experimental_cfp_const_hints &&
      is_cfp_const_hint_custom_section(section) {
      continue
    } else if section.section_id == 10U {
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
    let instr_bytes = body[prefix_end:body.length()].to_owned()
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
    let payload = bytes[section.payload_start:section.section_end].to_owned()
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
  let function_type_entry_by_type_index : Map[UInt, FunctionTypeEntry] = Map([])
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
  let alias_candidate : Map[UInt, SignatureRefineAlias] = Map([])
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
  let resolved_alias : Map[UInt, SignatureRefineAlias] = Map([])
  for i in 0..<code_bodies.length() {
    let old_index = imported_function_count + i.reinterpret_as_uint()
    match alias_candidate.get(old_index) {
      Some(initial_alias) => {
        let seen : Map[UInt, Bool] = Map([])
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
      let imm = instr_bytes[span.start + 1:span.end_].to_owned()
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
    let instr_bytes = body[prefix_end:body.length()].to_owned()
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
    let payload = bytes[section.payload_start:section.section_end].to_owned()
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
  let function_type_entry_by_type_index : Map[UInt, FunctionTypeEntry] = Map([])
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
