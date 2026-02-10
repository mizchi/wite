///|
fn apply_merge_similar_functions_raise(
  bytes : Bytes,
) -> MsfApplyResult raise WiteError {
  let sections = parse_core_sections_raise(bytes)
  let mut type_payload : Bytes? = None
  let mut imported_function_type_indices : Array[UInt] = []
  let mut local_function_type_indices : Array[UInt] = []
  let mut code_bodies : Array[Bytes] = []
  for section in sections {
    let payload = bytes[section.payload_start:section.section_end].to_bytes()
    match section.section_id {
      1U => type_payload = Some(payload)
      2U =>
        imported_function_type_indices = parse_import_function_type_indices(
          payload,
        )
      3U => local_function_type_indices = parse_function_type_indices(payload)
      10U => code_bodies = parse_code_bodies(payload)
      _ => ()
    }
  }
  if local_function_type_indices.length() != code_bodies.length() {
    raise WiteError::InvalidFormat(
      "function/code section count mismatch for msf: function=" +
      local_function_type_indices.length().to_string() +
      " code=" +
      code_bodies.length().to_string(),
    )
  }
  let imported_function_count = imported_function_type_indices
    .length()
    .reinterpret_as_uint()
  let function_type_by_index = imported_function_type_indices.copy()
  function_type_by_index.append(local_function_type_indices[:])
  let function_param_count_by_index : Array[UInt] = []
  if function_type_by_index.length() > 0 {
    let type_payload = match type_payload {
      Some(v) => v
      None => raise WiteError::InvalidFormat("type section is missing for msf")
    }
    let parsed_type_entries = parse_type_section_entries_with_refs_raise(
      type_payload, "msf",
    )
    let type_count_u = parsed_type_entries.length().reinterpret_as_uint()
    for type_index in function_type_by_index {
      if type_index >= type_count_u {
        raise WiteError::InvalidFormat(
          "type index out of range in msf: " + type_index.to_string(),
        )
      }
      let type_pos = UInt::reinterpret_as_int(type_index)
      if type_pos < 0 || type_pos >= parsed_type_entries.length() {
        raise WiteError::InvalidFormat(
          "type index position out of range in msf: " + type_index.to_string(),
        )
      }
      if parsed_type_entries[type_pos].form != 0x60U {
        raise WiteError::InvalidFormat(
          "non-function type index used by function in msf: " +
          type_index.to_string(),
        )
      }
      function_param_count_by_index.push(
        parse_function_type_param_count_from_raw_raise(
          parsed_type_entries[type_pos].raw,
          "msf",
        ),
      )
    }
  }
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
          if target_pos >= 0 &&
            target_pos < function_type_by_index.length() &&
            function_type_by_index[old_pos] ==
            function_type_by_index[target_pos] {
            alias_candidate.set(old_index, target)
          }
        }
      None => ()
    }
  }
  let keep_local : Array[Bool] = []
  let resolved_target_for_local : Array[UInt?] = []
  for i in 0..<local_function_type_indices.length() {
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
          keep_local.push(false)
          resolved_target_for_local.push(Some(current))
        } else {
          keep_local.push(true)
          resolved_target_for_local.push(None)
        }
      }
      None => {
        keep_local.push(true)
        resolved_target_for_local.push(None)
      }
    }
  }
  let index_map : Map[UInt, UInt] = {}
  for i in 0U..<imported_function_count {
    index_map.set(i, i)
  }
  let mut kept_local_count = 0U
  for i in 0..<keep_local.length() {
    if keep_local[i] {
      index_map.set(
        imported_function_count + i.reinterpret_as_uint(),
        imported_function_count + kept_local_count,
      )
      kept_local_count += 1U
    }
  }
  let mut removed_function_count = 0U
  let mut removed_body_bytes = 0U
  for i in 0..<resolved_target_for_local.length() {
    match resolved_target_for_local[i] {
      Some(target_old_index) => {
        let old_index = imported_function_count + i.reinterpret_as_uint()
        let target_new_index = remap_function_index_raise(
          target_old_index, index_map,
        )
        index_map.set(old_index, target_new_index)
        removed_function_count += 1U
        removed_body_bytes += code_bodies[i].length().reinterpret_as_uint()
      }
      None => ()
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

///|
pub fn unique_sorted(xs : Array[String]) -> Array[String] {
  let out = xs.copy()
  out.sort()
  out.dedup()
  out
}

///|
pub fn merge_root_names(
  base : Array[String],
  extra : Array[String],
) -> Array[String] {
  let merged = base.copy()
  merged.append(extra[:])
  unique_sorted(merged)
}

///|
pub fn clone_optimize_config(
  config : OptimizeConfig,
  pass_rounds? : UInt = config.pass_rounds,
  closed_world_root_exports? : Array[String] = config.closed_world_root_exports,
) -> OptimizeConfig {
  make_optimize_config(
    strip_all_custom=config.strip_all_custom,
    strip_name_section=config.strip_name_section,
    strip_producers_section=config.strip_producers_section,
    strip_debug_sections=config.strip_debug_sections,
    strip_dwarf_sections=config.strip_dwarf_sections,
    strip_target_features_section=config.strip_target_features_section,
    keep_custom_sections=config.keep_custom_sections,
    pass_rounds~,
    enable_peephole=config.enable_peephole,
    peephole_remove_nop=config.peephole_remove_nop,
    peephole_remove_const_drop=config.peephole_remove_const_drop,
    enable_vacuum=config.enable_vacuum,
    enable_merge_blocks=config.enable_merge_blocks,
    enable_remove_unused_brs=config.enable_remove_unused_brs,
    enable_dce=config.enable_dce,
    enable_dfe=config.enable_dfe,
    enable_merge_similar_functions=config.enable_merge_similar_functions,
    enable_remove_unused_module_elements=config.enable_remove_unused_module_elements,
    closed_world=config.closed_world,
    closed_world_root_exports~,
    safe_mode=config.safe_mode,
  )
}
